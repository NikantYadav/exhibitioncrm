import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  int get schemaVersion => 10;

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
          if (from < 8) {
            await m.addColumn(contactsTable, contactsTable.isPriority);
            await m.addColumn(followUpsTable, followUpsTable.isPriority);
          }
          if (from < 9) {
            // notes column meaning changed from raw text to a JSON-encoded
            // array of {id, body, created_at}. Wrap any existing plain-text
            // note into a single-element JSON array; skip NULLs and rows
            // already migrated (starting with '[').
            await customStatement(
              "UPDATE target_companies "
              "SET notes = json_array(json_object('id', id, 'body', notes, 'created_at', "
              "strftime('%Y-%m-%dT%H:%M:%SZ','now'))) "
              "WHERE notes IS NOT NULL AND trim(notes) <> '' "
              "AND substr(trim(notes),1,1) <> '['",
            );
          }
          if (from < 10) {
            await customStatement('ALTER TABLE contacts DROP COLUMN notes');
          }
        },
      );

  static QueryExecutor _openConnection() => openConnection();

  /// Opens the DB, recreating the file from scratch if the SQLCipher key
  /// cannot open it (e.g. the device has a pre-existing plaintext DB from a
  /// version of the app before the C2 encryption migration). The local DB is a
  /// sync cache — deleting it is safe; data re-syncs from the server online.
  static Future<AppDatabase> openOrRecreate() async {
    try {
      final db = AppDatabase();
      // Force Drift to actually open the connection so we discover any
      // SQLCipher key mismatch early, before the caller tries a real query.
      await db.customSelect('SELECT 1').get();
      return db;
    } catch (_) {
      // Best-effort delete of the plaintext file so SQLCipher can start fresh.
      try {
        final dbFolder = await getApplicationDocumentsDirectory();
        final file = File(p.join(dbFolder.path, 'exono_sync.sqlite'));
        if (await file.exists()) await file.delete();
      } catch (_) {
        // If deletion fails, the next open will also fail — nothing more to do.
      }
      return AppDatabase();
    }
  }

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
