import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'synced_repository.dart';

class EmailDraftsRepository extends SyncedRepository<EmailDraftsTableData, $EmailDraftsTableTable> {
  EmailDraftsRepository(super.db);

  @override
  String get tableName => 'email_drafts';

  @override
  TableInfo<$EmailDraftsTableTable, EmailDraftsTableData> get table => db.emailDraftsTable;

  @override
  Insertable<EmailDraftsTableData> companionFromJson(Map<String, dynamic> json) {
    return EmailDraftsTableCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String?),
      contactId: Value(json['contact_id'] as String?),
      eventId: Value(json['event_id'] as String?),
      emailType: Value(json['email_type'] as String),
      subject: Value(json['subject'] as String?),
      body: Value(json['body'] as String?),
      status: Value(json['status'] as String? ?? 'draft'),
      sentAt: Value(json['sent_at'] != null ? DateTime.parse(json['sent_at'] as String) : null),
      createdAt: Value(json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null),
      updatedAt: Value(DateTime.parse(json['updated_at'] as String)),
      deletedAt: Value(json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null),
    );
  }
}
