import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:drift/drift.dart';

import 'connection/connection.dart';
import 'tables/events_table.dart';
import 'tables/contacts_table.dart';
import 'tables/captures_table.dart';
import 'tables/target_companies_table.dart';
import 'tables/contact_events_table.dart';
import 'tables/event_goals_table.dart';
import 'tables/email_drafts_table.dart';
import 'tables/interactions_table.dart';
import 'tables/companies_table.dart';
import 'tables/follow_ups_table.dart';
import 'tables/target_company_met_table.dart';
import 'tables/sync_state_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  EventsTable,
  ContactsTable,
  CapturesTable,
  TargetCompaniesTable,
  ContactEventsTable,
  EventGoalsTable,
  EmailDraftsTable,
  InteractionsTable,
  CompaniesTable,
  FollowUpsTable,
  TargetCompanyMetTable,
  SyncStateTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @visibleForTesting
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(companiesTable, companiesTable.headquarters);
            await m.addColumn(companiesTable, companiesTable.employeeCount);
            await m.addColumn(companiesTable, companiesTable.foundedYear);
            await m.addColumn(companiesTable, companiesTable.linkedinUrl);
            await m.addColumn(companiesTable, companiesTable.tickerSymbol);
            await m.addColumn(companiesTable, companiesTable.enrichedAt);
            await m.addColumn(companiesTable, companiesTable.enrichmentFailed);
          }
          if (from < 3) {
            await m.addColumn(companiesTable, companiesTable.talkingPointsJson);
          }
          if (from < 4) {
            await m.addColumn(eventsTable, eventsTable.startTime);
            await m.addColumn(eventsTable, eventsTable.endTime);
          }
          if (from < 5) {
            await m.createTable(followUpsTable);
          }
          if (from < 6) {
            // Drop the retired follow_up_urgency column. SQLite 3.35+ (bundled
            // with current sqlite3_flutter_libs) supports DROP COLUMN directly.
            await customStatement('ALTER TABLE contacts DROP COLUMN follow_up_urgency');
          }
          if (from < 7) {
            await m.createTable(targetCompanyMetTable);
          }
        },
      );

  static QueryExecutor _openConnection() => openConnection();

  // Drops and recreates every synced table's local cache; called on logout
  // so a different login on the same device can't read a prior user's rows.
  Future<void> wipeAll() async {
    await transaction(() async {
      await delete(eventsTable).go();
      await delete(contactsTable).go();
      await delete(capturesTable).go();
      await delete(targetCompaniesTable).go();
      await delete(contactEventsTable).go();
      await delete(eventGoalsTable).go();
      await delete(emailDraftsTable).go();
      await delete(interactionsTable).go();
      await delete(companiesTable).go();
      await delete(syncStateTable).go();
    });
  }
}
