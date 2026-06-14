import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'local_db.dart';
import 'outbox_op.dart';

/// CRUD layer over the `outbox` SQLite table.
class OfflineQueue {
  static const _uuid = Uuid();

  /// Saves [imageBytes] to disk (if provided) and inserts a pending op.
  /// Returns the generated op id (also the idempotency key sent to backend).
  static Future<String> enqueue({
    required String opType,
    required Map<String, dynamic> payload,
    Uint8List? imageBytes,
    String? eventId,
  }) async {
    final id = _uuid.v4();
    String? imageRef;

    if (imageBytes != null) {
      final dir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${dir.path}/offline_images');
      if (!imagesDir.existsSync()) {
        imagesDir.createSync(recursive: true);
      }
      final file = File('${imagesDir.path}/$id.jpg');
      await file.writeAsBytes(imageBytes);
      imageRef = '$id.jpg';
    }

    final db = await LocalDb.db;
    await db.insert('outbox', {
      'id': id,
      'op_type': opType,
      'payload': jsonEncode(payload),
      'image_ref': imageRef,
      'event_id': eventId,
      'status': 'pending',
      'attempts': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    return id;
  }

  /// All ops with status pending or failed, oldest-first.
  static Future<List<OutboxOp>> pending() async {
    final db = await LocalDb.db;
    final rows = await db.query(
      'outbox',
      where: "status != 'done'",
      orderBy: 'created_at ASC',
    );
    return rows.map(_fromRow).toList();
  }

  static Future<List<OutboxOp>> pendingOnly() async {
    final db = await LocalDb.db;
    final rows = await db.query(
      'outbox',
      where: "status = 'pending'",
      orderBy: 'created_at ASC',
    );
    return rows.map(_fromRow).toList();
  }

  static Future<List<OutboxOp>> failed() async {
    final db = await LocalDb.db;
    final rows = await db.query(
      'outbox',
      where: "status = 'failed'",
      orderBy: 'created_at ASC',
    );
    return rows.map(_fromRow).toList();
  }

  static Future<int> pendingCount() async {
    final db = await LocalDb.db;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as c FROM outbox WHERE status != 'done'",
    );
    return (result.first['c'] as int?) ?? 0;
  }

  static Future<void> markSyncing(String id) async {
    final db = await LocalDb.db;
    await db.update(
      'outbox',
      {'status': 'syncing'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> markDone(String id, {String? serverId}) async {
    final db = await LocalDb.db;
    await db.update(
      'outbox',
      {'status': 'done', 'server_id': serverId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> markFailed(String id, String error) async {
    final db = await LocalDb.db;
    final rows = await db.query('outbox', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final current = rows.first['attempts'] as int? ?? 0;
    await db.update(
      'outbox',
      {
        'status': 'failed',
        'attempts': current + 1,
        'last_error': error,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> resetToPending(String id) async {
    final db = await LocalDb.db;
    await db.update(
      'outbox',
      {'status': 'pending', 'last_error': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> delete(String id) async {
    final db = await LocalDb.db;
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
    // Best-effort image cleanup.
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/offline_images/$id.jpg');
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  static Future<void> _deleteImageForOp(String opId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/offline_images/$opId.jpg');
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  /// Reads the saved image bytes for an op (returns null if none).
  static Future<Uint8List?> readImage(OutboxOp op) async {
    if (op.imageRef == null) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/offline_images/${op.imageRef}');
      if (!file.existsSync()) return null;
      return file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteImageAfterSync(OutboxOp op) => _deleteImageForOp(op.id);

  static OutboxOp _fromRow(Map<String, dynamic> row) {
    final payloadStr = row['payload'] as String? ?? '{}';
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(payloadStr) as Map<String, dynamic>;
    } catch (_) {
      payload = {};
    }
    return OutboxOp(
      id: row['id'] as String,
      opType: row['op_type'] as String,
      payload: payload,
      imageRef: row['image_ref'] as String?,
      eventId: row['event_id'] as String?,
      status: row['status'] as String,
      attempts: row['attempts'] as int? ?? 0,
      lastError: row['last_error'] as String?,
      createdAt: row['created_at'] as int,
      serverId: row['server_id'] as String?,
    );
  }
}
