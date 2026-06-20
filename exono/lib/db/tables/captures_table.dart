import 'package:drift/drift.dart';

class CapturesTable extends Table {
  @override
  String get tableName => 'captures';

  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get eventId => text().nullable()();
  TextColumn get contactId => text().nullable()();
  TextColumn get captureType => text()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get rawDataJson => text().nullable()();
  TextColumn get extractedDataJson => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get clientOpId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
