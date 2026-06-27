import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../services/company_name_resolver.dart';
import 'combine_latest.dart';
import 'contact_events_repository.dart' show FollowUpRow;
import 'synced_repository.dart';

/// Repository for the unified `follow_ups` table. Drives both the global
/// Follow-Ups screen and the per-event Follow-Up Queue from a single source of
/// truth, with one record per (contact, event).
class FollowUpsRepository extends SyncedRepository<FollowUpsTableData, $FollowUpsTableTable> {
  FollowUpsRepository(super.db);

  @override
  String get tableName => 'follow_ups';

  @override
  TableInfo<$FollowUpsTableTable, FollowUpsTableData> get table => db.followUpsTable;

  @override
  Insertable<FollowUpsTableData> companionFromJson(Map<String, dynamic> json) {
    return FollowUpsTableCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String?),
      contactId: Value(json['contact_id'] as String),
      eventId: Value(json['event_id'] as String?),
      status: Value(json['status'] as String? ?? 'new'),
      channel: Value(json['channel'] as String? ?? 'email'),
      lastInteractionAt: Value(json['last_interaction_at'] != null
          ? DateTime.parse(json['last_interaction_at'] as String)
          : null),
      doneAt: Value(json['done_at'] != null ? DateTime.parse(json['done_at'] as String) : null),
      createdAt: Value(json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null),
      updatedAt: Value(DateTime.parse(json['updated_at'] as String)),
      deletedAt: Value(json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null),
    );
  }

  /// Live "Follow-ups Due" count for the home dashboard: distinct contacts with
  /// any follow_up in `new` or `pending` status. Mirrors the backend dashboard
  /// definition so the home stat tracks logged interactions without a reload.
  Stream<int> watchDueCount() {
    final query = db.select(db.followUpsTable).join([
      innerJoin(db.contactsTable, db.contactsTable.id.equalsExp(db.followUpsTable.contactId)),
    ])
      ..where(db.followUpsTable.status.isIn(['new', 'pending']) &
          db.followUpsTable.deletedAt.isNull() &
          db.contactsTable.deletedAt.isNull());

    return query.watch().map((rows) {
      final contactIds = <String>{};
      for (final r in rows) {
        contactIds.add(r.readTable(db.followUpsTable).contactId);
      }
      return contactIds.length;
    });
  }

  /// Per-event follow-up queue: every follow_ups row for [eventId], joined to
  /// its contact + company + latest email draft for this event. Mirrors the
  /// old derived `watchFollowUps` shape but with a real per-event status.
  Stream<List<FollowUpRow>> watchFollowUps(String eventId) {
    final query = db.select(db.followUpsTable).join([
      innerJoin(db.contactsTable, db.contactsTable.id.equalsExp(db.followUpsTable.contactId)),
    ])
      ..where(db.followUpsTable.eventId.equals(eventId) &
          db.followUpsTable.deletedAt.isNull() &
          db.contactsTable.deletedAt.isNull());

    final draftsQuery = db.select(db.emailDraftsTable)
      ..where((t) => t.eventId.equals(eventId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    final rowsStream = query.watch();
    final companiesStream = db.select(db.companiesTable).watch();
    final draftsStream = draftsQuery.watch();

    return combineLatest3(rowsStream, companiesStream, draftsStream,
        (List<TypedResult> rows, List<CompaniesTableData> companies, List<EmailDraftsTableData> drafts) {
      final companiesById = {for (final c in companies) c.id: c};
      final latestDraftByContact = <String, EmailDraftsTableData>{};
      for (final d in drafts) {
        if (d.contactId != null) latestDraftByContact.putIfAbsent(d.contactId!, () => d);
      }

      return rows.map((r) {
        final fu = r.readTable(db.followUpsTable);
        final c = r.readTable(db.contactsTable);
        final company = c.companyId != null ? companiesById[c.companyId] : null;
        if (company == null && c.companyId != null) {
          CompanyNameResolver.resolve(c.companyId!);
        }
        final draft = latestDraftByContact[c.id];
        return FollowUpRow(
          contactId: c.id,
          firstName: c.firstName,
          lastName: c.lastName,
          email: c.email,
          jobTitle: c.jobTitle,
          followUpStatus: fu.status,
          companyId: c.companyId,
          companyName: company?.name,
          draftSubject: draft?.subject,
          draftBody: draft?.body,
        );
      }).toList();
    });
  }
}
