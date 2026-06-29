import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../services/api_service.dart';

/// Base class for the "middleman" between a drift-backed local cache and a
/// Supabase-synced table. Screens talk only to repositories: they read via
/// [watchAll]/[watchById] (drift streams, so the UI repaints on any local
/// write with zero manual setState) and never call ApiService or Supabase
/// Realtime directly for synced data. See plan.md §6.
///
/// [T] is the generated drift row type (e.g. `EventsTableData`); [Tbl] is the
/// generated drift table type (e.g. `EventsTable`).
abstract class SyncedRepository<T extends Object, Tbl extends Table> {
  SyncedRepository(this.db);

  final AppDatabase db;

  /// The Postgres/REST table name — used for the `/sync?tables=` query param,
  /// the `sync_state` row key, and the Realtime channel/table filter.
  String get tableName;

  TableInfo<Tbl, T> get table;

  /// Builds a drift companion (for insertOnConflictUpdate) from one row of
  /// the `/sync` JSON payload or a Realtime payload's `newRecord`.
  Insertable<T> companionFromJson(Map<String, dynamic> json);

  Stream<List<T>> watchAll() {
    final query = db.select(table)
      ..where((tbl) => _deletedAtIsNull(tbl))
      ..orderBy([_orderByUpdatedAt]);
    return query.watch();
  }

  Stream<T?> watchById(String id) {
    final query = db.select(table)
      ..where((tbl) => _idEquals(tbl, id) & _deletedAtIsNull(tbl));
    return query.watchSingleOrNull();
  }

  // These three helpers exist because the base class only knows column
  // access through the generated table mixins, which differ per table but
  // all expose `id` and `deletedAt` (every synced table has both per the
  // drift table definitions in lib/db/tables/).
  Expression<bool> _deletedAtIsNull(Tbl tbl) =>
      (tbl as dynamic).deletedAt.isNull();
  Expression<bool> _idEquals(Tbl tbl, String id) =>
      (tbl as dynamic).id.equals(id);
  OrderingTerm _orderByUpdatedAt(Tbl tbl) =>
      OrderingTerm.desc((tbl as dynamic).updatedAt);

  Future<String?> lastSyncedAt() async {
    final row = await (db.select(db.syncStateTable)
          ..where((t) => t.tableName_.equals(tableName)))
        .getSingleOrNull();
    return row?.lastSyncedAt;
  }

  Future<void> storeLastSyncedAt(String serverTime) async {
    await db.into(db.syncStateTable).insertOnConflictUpdate(
          SyncStateTableCompanion.insert(
            tableName_: tableName,
            lastSyncedAt: Value(serverTime),
          ),
        );
  }

  /// Pulls everything changed since the last successful catchUp, upserts
  /// into drift, hard-deletes locally-cached tombstones, then advances
  /// sync_state. Idempotent — safe to call repeatedly (e.g. on every resume).
  ///
  /// Single-table path: used by screen-level callers that intentionally
  /// refresh one table (e.g. after adding a contact). The batched provider
  /// path is [SyncProvider.catchUpAll], which fetches every table in one
  /// request and feeds each delta to [applyTableDelta].
  Future<void> catchUp() async {
    String? since = await lastSyncedAt();
    // Keyset-paginated drain (mirrors SyncProvider.catchUpAll): the backend caps
    // each response and reports `has_more` + `next_since`. Commit the durable
    // `server_time` watermark only on the final page; advance `since` by the
    // cursor between pages. Steady-state deltas finish in one pass.
    const safetyCap = 1000;
    for (var page = 0; page < safetyCap; page++) {
      final response = await ApiService.getSyncDelta(since: since, tables: tableName);
      final hasMore = response['has_more'] == true;
      final tableDelta = (response['data'] as Map<String, dynamic>)[tableName] as Map<String, dynamic>?;
      await applyTableDelta(tableDelta);
      if (!hasMore) {
        await storeLastSyncedAt(response['server_time'] as String);
        break;
      }
      since = response['next_since'] as String;
    }
  }

  /// Applies one table's delta map (`{upserts, deleted_ids}`) from a `/sync`
  /// response. Tolerates a null delta (table absent from the response).
  Future<void> applyTableDelta(Map<String, dynamic>? tableDelta) async {
    if (tableDelta == null) return;
    final upserts = (tableDelta['upserts'] as List).cast<Map<String, dynamic>>();
    final deletedIds = (tableDelta['deleted_ids'] as List).cast<String>();
    await applyDelta(upserts: upserts, deletedIds: deletedIds);
  }

  /// Upserts a batch of rows and hard-deletes tombstoned ids from the local
  /// cache. Exposed separately from [catchUp] so Realtime callbacks can
  /// reuse the same conflict policy for a single row.
  Future<void> applyDelta({
    required List<Map<String, dynamic>> upserts,
    required List<String> deletedIds,
  }) async {
    await db.transaction(() async {
      for (final json in upserts) {
        await _upsertOne(json);
      }
      for (final id in deletedIds) {
        await (db.delete(table)..where((tbl) => _idEquals(tbl, id))).go();
      }
    });
  }

  Future<void> _upsertOne(Map<String, dynamic> json) async {
    final id = json['id'] as String;
    final incomingUpdatedAt = DateTime.parse(json['updated_at'] as String);

    final existing = await (db.select(table)..where((tbl) => _idEquals(tbl, id)))
        .getSingleOrNull();
    if (existing != null) {
      final existingUpdatedAt = (existing as dynamic).updatedAt as DateTime;
      // Last-write-wins by updated_at — guards against a late Realtime echo
      // or out-of-order catchUp page clobbering newer local/optimistic state.
      if (!incomingUpdatedAt.isAfter(existingUpdatedAt)) return;
    }

    await db.into(table).insertOnConflictUpdate(companionFromJson(json));
  }

  Future<void> dispose() async {}
}
