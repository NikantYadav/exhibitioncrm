import 'package:drift/drift.dart';

import '../db/app_database.dart';
import 'synced_repository.dart';

/// A target_companies row joined with its company, mirroring the API's
/// `select('*, company:companies(*)')` shape used by GET /events/:id/targets.
class TargetCompanyRow {
  final TargetCompaniesTableData target;
  final CompaniesTableData? company;

  TargetCompanyRow({required this.target, this.company});

  String get id => target.id;
  String? get boothLocation => target.boothLocation;
  String get companyName => company?.name ?? 'Unknown';
}

class TargetCompaniesRepository extends SyncedRepository<TargetCompaniesTableData, $TargetCompaniesTableTable> {
  TargetCompaniesRepository(super.db);

  @override
  String get tableName => 'target_companies';

  @override
  TableInfo<$TargetCompaniesTableTable, TargetCompaniesTableData> get table => db.targetCompaniesTable;

  @override
  Insertable<TargetCompaniesTableData> companionFromJson(Map<String, dynamic> json) {
    return TargetCompaniesTableCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String?),
      eventId: Value(json['event_id'] as String?),
      companyId: Value(json['company_id'] as String?),
      priority: Value(json['priority'] as String? ?? 'medium'),
      boothLocation: Value(json['booth_location'] as String?),
      talkingPoints: Value(json['talking_points'] as String?),
      notes: Value(json['notes'] as String?),
      status: Value(json['status'] as String? ?? 'not_contacted'),
      useNotesForBriefing: Value(json['use_notes_for_briefing'] as bool? ?? false),
      createdAt: Value(json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null),
      updatedAt: Value(DateTime.parse(json['updated_at'] as String)),
      deletedAt: Value(json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null),
    );
  }

  /// Target companies for one event, joined with company details, ordered
  /// by priority (text sort, matching the backend's `.order('priority')`).
  Stream<List<TargetCompanyRow>> watchByEventWithCompany(String eventId) {
    final query = db.select(db.targetCompaniesTable).join([
      leftOuterJoin(db.companiesTable, db.companiesTable.id.equalsExp(db.targetCompaniesTable.companyId)),
    ])
      ..where(db.targetCompaniesTable.eventId.equals(eventId) & db.targetCompaniesTable.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(db.targetCompaniesTable.priority)]);

    return query.watch().map((rows) => rows.map((row) {
          return TargetCompanyRow(
            target: row.readTable(db.targetCompaniesTable),
            company: row.readTableOrNull(db.companiesTable),
          );
        }).toList());
  }
}
