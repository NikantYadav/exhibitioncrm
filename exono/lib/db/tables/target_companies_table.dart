import 'package:drift/drift.dart';

class TargetCompaniesTable extends Table {
  @override
  String get tableName => 'target_companies';

  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get eventId => text().nullable()();
  TextColumn get companyId => text().nullable()();
  TextColumn get priority => text().withDefault(const Constant('medium'))();
  TextColumn get boothLocation => text().nullable()();
  TextColumn get talkingPoints => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('not_contacted'))();
  BoolColumn get useNotesForBriefing => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
