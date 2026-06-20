import 'package:drift/drift.dart';

class InteractionsTable extends Table {
  @override
  String get tableName => 'interactions';

  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get contactId => text().nullable()();
  TextColumn get eventId => text().nullable()();
  TextColumn get interactionType => text()();
  DateTimeColumn get interactionDate => dateTime().nullable()();
  TextColumn get summary => text().nullable()();
  TextColumn get detailsJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
