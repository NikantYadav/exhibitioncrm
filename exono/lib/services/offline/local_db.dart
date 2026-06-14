import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Single sqflite database for all offline data.
/// Tables: outbox, local_contacts.
class LocalDb {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'exono_offline.db');
    return openDatabase(
      path,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // review_data holds the duplicate-match payload when an op is parked
          // as 'needs_review' during sync. Guard against the column already
          // existing (e.g. a build that added it in onCreate before the bump).
          await _addColumnIfMissing(db, 'outbox', 'review_data', 'TEXT');
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE outbox (
            id TEXT PRIMARY KEY,
            op_type TEXT NOT NULL,
            payload TEXT NOT NULL,
            image_ref TEXT,
            event_id TEXT,
            status TEXT NOT NULL DEFAULT 'pending',
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            created_at INTEGER NOT NULL,
            server_id TEXT,
            review_data TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE local_contacts (
            id TEXT PRIMARY KEY,
            first_name TEXT,
            last_name TEXT,
            email TEXT,
            phone TEXT,
            job_title TEXT,
            company TEXT,
            notes TEXT,
            is_synced INTEGER NOT NULL DEFAULT 0,
            pending_op_id TEXT,
            server_id TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  /// Adds [column] to [table] only if it isn't already present, so re-running an
  /// upgrade (or upgrading a DB that already had the column) can't crash.
  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }
}
