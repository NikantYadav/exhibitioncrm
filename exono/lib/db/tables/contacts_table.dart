import 'package:drift/drift.dart';

class ContactsTable extends Table {
  @override
  String get tableName => 'contacts';

  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get companyId => text().nullable()();
  TextColumn get firstName => text()();
  TextColumn get lastName => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get jobTitle => text().nullable()();
  TextColumn get linkedinUrl => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get followUpStatus => text().withDefault(const Constant('not_contacted'))();
  BoolColumn get isPriority => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastContactedAt => dateTime().nullable()();
  TextColumn get contactAssetsJson => text().nullable()();
  TextColumn get scannedDetailsJson => text().nullable()();
  TextColumn get aiInsightsJson => text().nullable()();
  TextColumn get aiContextSummary => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
