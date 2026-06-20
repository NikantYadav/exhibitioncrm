import 'package:drift/drift.dart';

// Shared lookup table — no user_id, no deleted_at (see plan.md §2b).
// Synced as a referenced lookup only; never deleted locally via tombstone.
class CompaniesTable extends Table {
  @override
  String get tableName => 'companies';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get website => text().nullable()();
  TextColumn get industry => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get companySize => text().nullable()();
  TextColumn get productsServices => text().nullable()();
  TextColumn get headquarters => text().nullable()();
  TextColumn get employeeCount => text().nullable()();
  TextColumn get foundedYear => text().nullable()();
  TextColumn get linkedinUrl => text().nullable()();
  TextColumn get tickerSymbol => text().nullable()();
  DateTimeColumn get enrichedAt => dateTime().nullable()();
  BoolColumn get enrichmentFailed => boolean().withDefault(const Constant(false))();
  TextColumn get talkingPointsJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
