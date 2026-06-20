import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exono/db/app_database.dart';
import 'package:exono/repositories/companies_repository.dart';

void main() {
  late AppDatabase db;
  late CompaniesRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CompaniesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('applyDelta upserts companies and watchAll/watchById surface them', () async {
    await repo.applyDelta(upserts: [
      {
        'id': 'co-1',
        'name': 'Acme Corp',
        'website': 'https://acme.example',
        'industry': 'Manufacturing',
        'description': null,
        'location': 'Berlin',
        'company_size': '50-200',
        'products_services': null,
        'created_at': '2026-06-01T00:00:00.000Z',
        'updated_at': '2026-06-01T00:00:00.000Z',
      }
    ]);

    final all = await repo.watchAll().first;
    expect(all.length, 1);
    expect(all.first.name, 'Acme Corp');

    final byId = await repo.watchById('co-1').first;
    expect(byId?.website, 'https://acme.example');
  });

  test('applyDelta with an empty upserts list is a no-op', () async {
    await repo.applyDelta(upserts: []);
    expect((await repo.watchAll().first).length, 0);
  });

  test('applyDelta upserts (insertAllOnConflictUpdate) overwrites an existing row by id', () async {
    await repo.applyDelta(upserts: [
      {
        'id': 'co-2',
        'name': 'Old Name',
        'website': null,
        'industry': null,
        'description': null,
        'location': null,
        'company_size': null,
        'products_services': null,
        'created_at': null,
        'updated_at': '2026-06-01T00:00:00.000Z',
      }
    ]);

    await repo.applyDelta(upserts: [
      {
        'id': 'co-2',
        'name': 'New Name',
        'website': null,
        'industry': null,
        'description': null,
        'location': null,
        'company_size': null,
        'products_services': null,
        'created_at': null,
        'updated_at': '2026-06-02T00:00:00.000Z',
      }
    ]);

    final all = await repo.watchAll().first;
    expect(all.length, 1);
    expect(all.single.name, 'New Name');
  });
}
