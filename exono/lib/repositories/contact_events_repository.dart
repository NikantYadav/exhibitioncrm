import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../services/company_name_resolver.dart';
import 'combine_latest.dart';
import 'synced_repository.dart';

/// Flattened shape mirroring `GET /events/:id/follow-ups` — a scanned
/// contact (via contact_events or captures, deduped) joined with its
/// company and latest email draft for this event.
class FollowUpRow {
  final String contactId;
  final String firstName;
  final String? lastName;
  final String? email;
  final String? jobTitle;
  final String followUpStatus;
  final String? companyId;
  final String? companyName;
  final String? draftSubject;
  final String? draftBody;

  FollowUpRow({
    required this.contactId,
    required this.firstName,
    this.lastName,
    this.email,
    this.jobTitle,
    required this.followUpStatus,
    this.companyId,
    this.companyName,
    this.draftSubject,
    this.draftBody,
  });
}

/// Flattened shape mirroring `GET /events/:id/contacts` — a contact_events
/// row joined to its contact (and the contact's company, for display only).
class TargetContactRow {
  final String id;
  final String contactId;
  final String name;
  final String jobTitle;
  final String? companyId;
  final String companyName;
  final String status;
  final String? notes;

  TargetContactRow({
    required this.id,
    required this.contactId,
    required this.name,
    required this.jobTitle,
    this.companyId,
    required this.companyName,
    required this.status,
    this.notes,
  });
}

class ContactEventsRepository extends SyncedRepository<ContactEventsTableData, $ContactEventsTableTable> {
  ContactEventsRepository(super.db);

  @override
  String get tableName => 'contact_events';

  @override
  TableInfo<$ContactEventsTableTable, ContactEventsTableData> get table => db.contactEventsTable;

  @override
  Insertable<ContactEventsTableData> companionFromJson(Map<String, dynamic> json) {
    return ContactEventsTableCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String?),
      contactId: Value(json['contact_id'] as String),
      eventId: Value(json['event_id'] as String),
      status: Value(json['status'] as String? ?? 'not_contacted'),
      notes: Value(json['notes'] as String?),
      talkingPoints: Value(json['talking_points'] as String?),
      createdAt: Value(json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null),
      updatedAt: Value(DateTime.parse(json['updated_at'] as String)),
      deletedAt: Value(json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null),
    );
  }

  /// Target contacts for one event, joined with contact + company names.
  /// Drops rows whose linked contact was soft-deleted (left join can't
  /// filter the embedded row inline), mirroring the backend's app-code
  /// post-filter for this same query in events.ts.
  Stream<List<TargetContactRow>> watchByEventWithContact(String eventId) {
    final query = db.select(db.contactEventsTable).join([
      leftOuterJoin(db.contactsTable, db.contactsTable.id.equalsExp(db.contactEventsTable.contactId)),
      leftOuterJoin(db.companiesTable, db.companiesTable.id.equalsExp(db.contactsTable.companyId)),
    ])
      ..where(db.contactEventsTable.eventId.equals(eventId) & db.contactEventsTable.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(db.contactEventsTable.createdAt)]);

    return query.watch().map((rows) => rows
        .where((row) => row.readTableOrNull(db.contactsTable)?.deletedAt == null)
        .map((row) {
          final ce = row.readTable(db.contactEventsTable);
          final contact = row.readTableOrNull(db.contactsTable);
          final company = row.readTableOrNull(db.companiesTable);
          if (company == null && contact?.companyId != null) {
            CompanyNameResolver.resolve(contact!.companyId);
          }
          return TargetContactRow(
            id: ce.id,
            contactId: ce.contactId,
            name: contact != null ? '${contact.firstName} ${contact.lastName ?? ''}'.trim() : '',
            jobTitle: contact?.jobTitle ?? '',
            companyId: contact?.companyId,
            companyName: company?.name ?? '',
            status: ce.status,
            notes: ce.notes,
          );
        }).toList());
  }

  /// Scanned contacts for an event (via contact_events OR captures with
  /// status 'completed', deduped by contact id) joined with company and
  /// latest email draft for this event — mirrors `GET /events/:id/follow-ups`.
  /// Note: the backend also fetches target_companies for an "unmet targets"
  /// feature but never adds them to the response (dead code) — every row
  /// returned by that endpoint always has a non-null contact, so this drift
  /// version only needs to mirror the scanned-contact merge, not targets.
  Stream<List<FollowUpRow>> watchFollowUps(String eventId) {
    final viaContactEvents = db.select(db.contactEventsTable).join([
      innerJoin(db.contactsTable, db.contactsTable.id.equalsExp(db.contactEventsTable.contactId)),
    ])
      ..where(db.contactEventsTable.eventId.equals(eventId) &
          db.contactEventsTable.deletedAt.isNull() &
          db.contactsTable.deletedAt.isNull());

    final viaCaptures = db.select(db.capturesTable).join([
      innerJoin(db.contactsTable, db.contactsTable.id.equalsExp(db.capturesTable.contactId)),
    ])
      ..where(db.capturesTable.eventId.equals(eventId) &
          db.capturesTable.status.equals('completed') &
          db.capturesTable.contactId.isNotNull() &
          db.capturesTable.deletedAt.isNull() &
          db.contactsTable.deletedAt.isNull());

    final draftsQuery = db.select(db.emailDraftsTable)
      ..where((t) => t.eventId.equals(eventId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    final contactsStream1 = viaContactEvents.watch().map((rows) => rows.map((r) => r.readTable(db.contactsTable)).toList());
    final contactsStream2 = viaCaptures.watch().map((rows) => rows.map((r) => r.readTable(db.contactsTable)).toList());
    final mergedContacts = combineLatest2(contactsStream1, contactsStream2, (List<ContactsTableData> a, List<ContactsTableData> b) {
      final byId = <String, ContactsTableData>{};
      for (final c in [...a, ...b]) {
        byId.putIfAbsent(c.id, () => c);
      }
      return byId.values.toList();
    });

    final companiesStream = db.select(db.companiesTable).watch();
    final draftsStream = draftsQuery.watch();

    return combineLatest3(mergedContacts, companiesStream, draftsStream,
        (List<ContactsTableData> contacts, List<CompaniesTableData> companies, List<EmailDraftsTableData> drafts) {
      final companiesById = {for (final c in companies) c.id: c};
      final latestDraftByContact = <String, EmailDraftsTableData>{};
      for (final d in drafts) {
        if (d.contactId != null) latestDraftByContact.putIfAbsent(d.contactId!, () => d);
      }

      return contacts.map((c) {
        final company = c.companyId != null ? companiesById[c.companyId] : null;
        if (company == null && c.companyId != null) {
          CompanyNameResolver.resolve(c.companyId);
        }
        final draft = latestDraftByContact[c.id];
        return FollowUpRow(
          contactId: c.id,
          firstName: c.firstName,
          lastName: c.lastName,
          email: c.email,
          jobTitle: c.jobTitle,
          followUpStatus: c.followUpStatus,
          companyId: c.companyId,
          companyName: company?.name,
          draftSubject: draft?.subject,
          draftBody: draft?.body,
        );
      }).toList();
    });
  }
}
