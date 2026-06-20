import 'package:drift/drift.dart';

class ContactEventsTable extends Table {
  @override
  String get tableName => 'contact_events';

  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get contactId => text()();
  TextColumn get eventId => text()();
  TextColumn get status => text().withDefault(const Constant('not_contacted'))();
  TextColumn get notes => text().nullable()();
  TextColumn get talkingPoints => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
