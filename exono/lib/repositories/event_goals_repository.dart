import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'synced_repository.dart';

class EventGoalsRepository extends SyncedRepository<EventGoalsTableData, $EventGoalsTableTable> {
  EventGoalsRepository(super.db);

  @override
  String get tableName => 'event_goals';

  @override
  TableInfo<$EventGoalsTableTable, EventGoalsTableData> get table => db.eventGoalsTable;

  @override
  Insertable<EventGoalsTableData> companionFromJson(Map<String, dynamic> json) {
    return EventGoalsTableCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String?),
      eventId: Value(json['event_id'] as String),
      label: Value(json['label'] as String),
      current: Value(json['current'] as int? ?? 0),
      total: Value(json['total'] as int? ?? 1),
      createdAt: Value(json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null),
      updatedAt: Value(DateTime.parse(json['updated_at'] as String)),
      deletedAt: Value(json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null),
    );
  }
}
