import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'synced_repository.dart';

class InteractionsRepository extends SyncedRepository<InteractionsTableData, $InteractionsTableTable> {
  InteractionsRepository(super.db);

  @override
  String get tableName => 'interactions';

  @override
  TableInfo<$InteractionsTableTable, InteractionsTableData> get table => db.interactionsTable;

  @override
  Insertable<InteractionsTableData> companionFromJson(Map<String, dynamic> json) {
    String? encodeJson(dynamic value) {
      if (value == null) return null;
      return value is String ? value : jsonEncode(value);
    }

    return InteractionsTableCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String?),
      contactId: Value(json['contact_id'] as String?),
      eventId: Value(json['event_id'] as String?),
      interactionType: Value(json['interaction_type'] as String),
      interactionDate: Value(json['interaction_date'] != null
          ? DateTime.parse(json['interaction_date'] as String)
          : null),
      summary: Value(json['summary'] as String?),
      detailsJson: Value(encodeJson(json['details'])),
      createdAt: Value(json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null),
      updatedAt: Value(DateTime.parse(json['updated_at'] as String)),
      deletedAt: Value(json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null),
    );
  }
}
