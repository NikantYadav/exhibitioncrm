import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exono/db/app_database.dart';
import 'package:exono/repositories/events_repository.dart';

void main() {
  late AppDatabase db;
  late EventsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = EventsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('applyDelta upserts new rows and they show up in watchAll', () async {
    await repo.applyDelta(upserts: [
      {
        'id': 'evt-1',
        'user_id': 'user-1',
        'name': 'Electronica',
        'location': 'Munich',
        'start_date': '2026-06-10T00:00:00.000Z',
        'end_date': null,
        'event_type': 'exhibition',
        'created_at': '2026-06-01T00:00:00.000Z',
        'updated_at': '2026-06-01T00:00:00.000Z',
        'deleted_at': null,
      }
    ], deletedIds: []);

    final rows = await repo.watchAll().first;
    expect(rows.length, 1);
    expect(rows.first.name, 'Electronica');
  });

  test('applyDelta excludes soft-deleted rows from watchAll via deleted_ids hard delete', () async {
    await repo.applyDelta(upserts: [
      {
        'id': 'evt-2',
        'user_id': 'user-1',
        'name': 'To be deleted',
        'location': null,
        'start_date': '2026-06-10T00:00:00.000Z',
        'end_date': null,
        'event_type': null,
        'created_at': '2026-06-01T00:00:00.000Z',
        'updated_at': '2026-06-01T00:00:00.000Z',
        'deleted_at': null,
      }
    ], deletedIds: []);

    expect((await repo.watchAll().first).length, 1);

    await repo.applyDelta(upserts: [], deletedIds: ['evt-2']);

    expect((await repo.watchAll().first).length, 0);
  });

  test('last-write-wins: an older incoming updated_at does not clobber a newer local row', () async {
    await repo.applyDelta(upserts: [
      {
        'id': 'evt-3',
        'user_id': 'user-1',
        'name': 'Newer name',
        'location': null,
        'start_date': '2026-06-10T00:00:00.000Z',
        'end_date': null,
        'event_type': null,
        'created_at': '2026-06-01T00:00:00.000Z',
        'updated_at': '2026-06-05T00:00:00.000Z',
        'deleted_at': null,
      }
    ], deletedIds: []);

    // A late echo with an OLDER updated_at should not overwrite.
    await repo.applyDelta(upserts: [
      {
        'id': 'evt-3',
        'user_id': 'user-1',
        'name': 'Stale name',
        'location': null,
        'start_date': '2026-06-10T00:00:00.000Z',
        'end_date': null,
        'event_type': null,
        'created_at': '2026-06-01T00:00:00.000Z',
        'updated_at': '2026-06-02T00:00:00.000Z',
        'deleted_at': null,
      }
    ], deletedIds: []);

    final rows = await repo.watchAll().first;
    expect(rows.single.name, 'Newer name');
  });

  test('watchById returns the row when live, and null after it is tombstoned', () async {
    await repo.applyDelta(upserts: [
      {
        'id': 'evt-4',
        'user_id': 'user-1',
        'name': 'Findable',
        'location': null,
        'start_date': '2026-06-10T00:00:00.000Z',
        'end_date': null,
        'event_type': null,
        'created_at': '2026-06-01T00:00:00.000Z',
        'updated_at': '2026-06-01T00:00:00.000Z',
        'deleted_at': null,
      }
    ], deletedIds: []);

    expect((await repo.watchById('evt-4').first)?.name, 'Findable');

    await repo.applyDelta(upserts: [], deletedIds: ['evt-4']);

    expect(await repo.watchById('evt-4').first, isNull);
  });

  test('sync_state round-trips a per-table last_synced_at value (what catchUp relies on)', () async {
    // Exercises the same drift query shape catchUp() uses internally, since
    // ApiService.getSyncDelta is a static HTTP call with no test seam here.
    expect(
      await (db.select(db.syncStateTable)..where((t) => t.tableName_.equals('events')))
          .getSingleOrNull(),
      isNull,
    );

    await db.into(db.syncStateTable).insertOnConflictUpdate(
          SyncStateTableCompanion.insert(
            tableName_: 'events',
            lastSyncedAt: const Value('2026-06-01T00:00:00.000Z'),
          ),
        );

    final stored = await (db.select(db.syncStateTable)..where((t) => t.tableName_.equals('events')))
        .getSingleOrNull();
    expect(stored?.lastSyncedAt, '2026-06-01T00:00:00.000Z');

    await db.into(db.syncStateTable).insertOnConflictUpdate(
          SyncStateTableCompanion.insert(
            tableName_: 'events',
            lastSyncedAt: const Value('2026-06-02T00:00:00.000Z'),
          ),
        );

    final updated = await (db.select(db.syncStateTable)..where((t) => t.tableName_.equals('events')))
        .getSingleOrNull();
    expect(updated?.lastSyncedAt, '2026-06-02T00:00:00.000Z');
  });

  test('dispose is safe to call when no Realtime channel was ever opened', () async {
    await repo.dispose();
  });
}
