import 'package:drift/drift.dart';

class SyncStateTable extends Table {
  @override
  String get tableName => 'sync_state';

  TextColumn get tableName_ => text().named('table_name')();
  TextColumn get lastSyncedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {tableName_};
}
