import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../services/api_service.dart';

/// `companies` is a shared lookup table — no `user_id`, no `deleted_at`, and
/// no Realtime (company rows rarely change and aren't user-private). It does
/// not extend SyncedRepository: it's synced only as the referenced subset of
/// companies returned by `/sync`'s `companies` key (see plan.md §2b, §4),
/// never has tombstones, and is never deleted locally via catchUp.
class CompaniesRepository {
  CompaniesRepository(this.db);

  final AppDatabase db;

  Stream<List<CompaniesTableData>> watchAll() => db.select(db.companiesTable).watch();

  Stream<CompaniesTableData?> watchById(String id) {
    final query = db.select(db.companiesTable)..where((tbl) => tbl.id.equals(id));
    return query.watchSingleOrNull();
  }

  /// Upserts the `companies.upserts` slice of a `/sync` response. There are
  /// no `deleted_ids` for this table (always `[]` from the server).
  Future<void> applyDelta({required List<Map<String, dynamic>> upserts}) async {
    if (upserts.isEmpty) return;
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        db.companiesTable,
        upserts.map(_companionFromJson).toList(),
      );
    });
  }

  /// Pulls referenced companies changed since the last successful catchUp.
  /// `companies` shares no Realtime channel, so this is the only freshness
  /// path — call it whenever contacts/target_companies catchUp runs too.
  Future<void> catchUp() async {
    final stateRow = await (db.select(db.syncStateTable)
          ..where((t) => t.tableName_.equals('companies')))
        .getSingleOrNull();
    final since = stateRow?.lastSyncedAt;

    final response = await ApiService.getSyncDelta(since: since, tables: 'companies');
    final serverTime = response['server_time'] as String;
    final delta = (response['data'] as Map<String, dynamic>)['companies'] as Map<String, dynamic>?;

    if (delta != null) {
      final upserts = (delta['upserts'] as List).cast<Map<String, dynamic>>();
      await applyDelta(upserts: upserts);
    }

    await db.into(db.syncStateTable).insertOnConflictUpdate(
          SyncStateTableCompanion.insert(
            tableName_: 'companies',
            lastSyncedAt: Value(serverTime),
          ),
        );
  }

  CompaniesTableCompanion _companionFromJson(Map<String, dynamic> json) {
    return CompaniesTableCompanion(
      id: Value(json['id'] as String),
      name: Value(json['name'] as String),
      website: Value(json['website'] as String?),
      industry: Value(json['industry'] as String?),
      description: Value(json['description'] as String?),
      location: Value(json['location'] as String?),
      companySize: Value(json['company_size'] as String?),
      productsServices: Value(json['products_services'] as String?),
      headquarters: Value(json['headquarters'] as String?),
      employeeCount: Value(json['employee_count'] as String?),
      foundedYear: Value(json['founded_year'] as String?),
      linkedinUrl: Value(json['linkedin_url'] as String?),
      tickerSymbol: Value(json['ticker_symbol'] as String?),
      enrichedAt: Value(json['enriched_at'] != null ? DateTime.parse(json['enriched_at'] as String) : null),
      enrichmentFailed: Value(json['enrichment_failed'] as bool? ?? false),
      talkingPointsJson: Value(json['talking_points'] != null ? jsonEncode(json['talking_points']) : null),
      createdAt: Value(json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null),
      updatedAt: Value(DateTime.parse(json['updated_at'] as String)),
    );
  }
}
