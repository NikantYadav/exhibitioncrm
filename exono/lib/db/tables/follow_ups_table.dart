import 'package:drift/drift.dart';

/// Local mirror of the server `follow_ups` table. One row per
/// (user, contact, event); event_id null = general (no-event) follow-up.
/// status: new | pending | done | skipped.
class FollowUpsTable extends Table {
  @override
  String get tableName => 'follow_ups';

  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get contactId => text()();
  TextColumn get eventId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('new'))();
  TextColumn get channel => text().withDefault(const Constant('email'))();
  DateTimeColumn get lastInteractionAt => dateTime().nullable()();
  DateTimeColumn get doneAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
