import 'package:drift/drift.dart';

class EventGoalsTable extends Table {
  @override
  String get tableName => 'event_goals';

  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get eventId => text()();
  TextColumn get label => text()();
  IntColumn get current => integer().withDefault(const Constant(0))();
  IntColumn get total => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
