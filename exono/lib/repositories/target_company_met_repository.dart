import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'synced_repository.dart';

/// Per-user company "met" state, synced so the live floor can read it offline.
/// Mirrors the server `target_company_met` table (see events.ts /targets/:id/met).
class TargetCompanyMetRepository
    extends SyncedRepository<TargetCompanyMetTableData, $TargetCompanyMetTableTable> {
  TargetCompanyMetRepository(super.db);

  @override
  String get tableName => 'target_company_met';

  @override
  TableInfo<$TargetCompanyMetTableTable, TargetCompanyMetTableData> get table =>
      db.targetCompanyMetTable;

  @override
  Insertable<TargetCompanyMetTableData> companionFromJson(Map<String, dynamic> json) {
    return TargetCompanyMetTableCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String?),
      eventId: Value(json['event_id'] as String?),
      targetId: Value(json['target_id'] as String?),
      met: Value(json['met'] as bool? ?? true),
      createdAt: Value(json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null),
      updatedAt: Value(DateTime.parse(json['updated_at'] as String)),
      deletedAt: Value(json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null),
    );
  }

  /// Met flags for one event, keyed by target_id. Only rows flagged met=true
  /// are returned, matching the backend's `companyMetSet` (filter on met).
  Future<Map<String, bool>> metByTargetForEvent(String eventId) async {
    final rows = await (db.select(db.targetCompanyMetTable)
          ..where((t) => t.eventId.equals(eventId) & t.deletedAt.isNull()))
        .get();
    return {for (final r in rows) if (r.targetId != null) r.targetId!: r.met};
  }
}
