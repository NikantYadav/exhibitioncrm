import 'package:drift/drift.dart';

class EmailDraftsTable extends Table {
  @override
  String get tableName => 'email_drafts';

  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get contactId => text().nullable()();
  TextColumn get eventId => text().nullable()();
  TextColumn get emailType => text()();
  TextColumn get subject => text().nullable()();
  TextColumn get body => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  DateTimeColumn get sentAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
