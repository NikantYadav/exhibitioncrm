import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'synced_repository.dart';

class CapturesRepository extends SyncedRepository<CapturesTableData, $CapturesTableTable> {
  CapturesRepository(super.db);

  @override
  String get tableName => 'captures';

  @override
  TableInfo<$CapturesTableTable, CapturesTableData> get table => db.capturesTable;

  @override
  Insertable<CapturesTableData> companionFromJson(Map<String, dynamic> json) {
    String? encodeJson(dynamic value) {
      if (value == null) return null;
      return value is String ? value : jsonEncode(value);
    }

    return CapturesTableCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String?),
      eventId: Value(json['event_id'] as String?),
      contactId: Value(json['contact_id'] as String?),
      captureType: Value(json['capture_type'] as String),
      imageUrl: Value(json['image_url'] as String?),
      rawDataJson: Value(encodeJson(json['raw_data'])),
      extractedDataJson: Value(encodeJson(json['extracted_data'])),
      status: Value(json['status'] as String? ?? 'pending'),
      clientOpId: Value(json['client_op_id'] as String?),
      createdAt: Value(json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null),
      updatedAt: Value(DateTime.parse(json['updated_at'] as String)),
      deletedAt: Value(json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null),
    );
  }
}
