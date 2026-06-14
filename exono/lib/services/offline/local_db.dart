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
      version: 1,
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
            server_id TEXT
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
}
