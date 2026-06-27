import 'package:drift/drift.dart';

/// Per-user "met" toggle for a company target. Distinct from the shared
/// target_companies.status — this is the current user's own met flag. Synced
/// so the live floor can show met state offline (see LiveEventProvider).
class TargetCompanyMetTable extends Table {
  @override
  String get tableName => 'target_company_met';

  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get eventId => text().nullable()();
  TextColumn get targetId => text().nullable()();
  BoolColumn get met => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
