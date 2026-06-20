import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../models/contact.dart' as model;
import 'synced_repository.dart';

class ContactsRepository extends SyncedRepository<ContactsTableData, $ContactsTableTable> {
  ContactsRepository(super.db);

  @override
  String get tableName => 'contacts';

  @override
  TableInfo<$ContactsTableTable, ContactsTableData> get table => db.contactsTable;

  /// Left-joins each non-deleted contact with its company row (if any),
  /// mirroring the API's embedded `company:companies(...)` select. Companies
  /// has no deleted_at/tombstones (see CompaniesRepository), so no filter
  /// is needed on that side of the join.
  /// Contacts belonging to one company (used by the target-company prep
  /// screen's contact list), non-deleted, ordered by first name.
  Stream<List<ContactsTableData>> watchByCompany(String companyId) {
    final query = db.select(db.contactsTable)
      ..where((t) => t.companyId.equals(companyId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.firstName)]);
    return query.watch();
  }

  /// Single contact left-joined with its company, mirroring GET /contacts/:id.
  Stream<model.Contact?> watchByIdWithCompany(String id) {
    final query = db.select(db.contactsTable).join([
      leftOuterJoin(db.companiesTable, db.companiesTable.id.equalsExp(db.contactsTable.companyId)),
    ])
      ..where(db.contactsTable.id.equals(id) & db.contactsTable.deletedAt.isNull());

    return query.watchSingleOrNull().map((row) {
      if (row == null) return null;
      final contactRow = row.readTable(db.contactsTable);
      final companyRow = row.readTableOrNull(db.companiesTable);
      return model.Contact.fromDrift(
        contactRow,
        company: companyRow != null ? model.Company.fromDrift(companyRow) : null,
      );
    });
  }

  Stream<List<model.Contact>> watchAllWithCompany() {
    final query = db.select(db.contactsTable).join([
      leftOuterJoin(db.companiesTable, db.companiesTable.id.equalsExp(db.contactsTable.companyId)),
    ])
      ..where(db.contactsTable.deletedAt.isNull())
      ..orderBy([OrderingTerm.desc(db.contactsTable.updatedAt)]);

    return query.watch().map((rows) => rows.map((row) {
          final contactRow = row.readTable(db.contactsTable);
          final companyRow = row.readTableOrNull(db.companiesTable);
          return model.Contact.fromDrift(
            contactRow,
            company: companyRow != null ? model.Company.fromDrift(companyRow) : null,
          );
        }).toList());
  }

  @override
  Insertable<ContactsTableData> companionFromJson(Map<String, dynamic> json) {
    String? encodeJson(dynamic value) {
      if (value == null) return null;
      return value is String ? value : jsonEncode(value);
    }

    return ContactsTableCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String?),
      companyId: Value(json['company_id'] as String?),
      firstName: Value(json['first_name'] as String),
      lastName: Value(json['last_name'] as String?),
      email: Value(json['email'] as String?),
      phone: Value(json['phone'] as String?),
      jobTitle: Value(json['job_title'] as String?),
      linkedinUrl: Value(json['linkedin_url'] as String?),
      notes: Value(json['notes'] as String?),
      avatarUrl: Value(json['avatar_url'] as String?),
      followUpStatus: Value(json['follow_up_status'] as String? ?? 'not_contacted'),
      followUpUrgency: Value(json['follow_up_urgency'] as String? ?? 'medium'),
      lastContactedAt: Value(json['last_contacted_at'] != null
          ? DateTime.parse(json['last_contacted_at'] as String)
          : null),
      contactAssetsJson: Value(encodeJson(json['contact_assets'])),
      aiInsightsJson: Value(encodeJson(json['ai_insights'])),
      aiContextSummary: Value(json['ai_context_summary'] as String?),
      createdAt: Value(json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null),
      updatedAt: Value(DateTime.parse(json['updated_at'] as String)),
      deletedAt: Value(json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null),
    );
  }
}
