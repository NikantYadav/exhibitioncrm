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
    Uint8List? audioBytes,
    String? eventId,
  }) async {
    final id = _uuid.v4();
    String? imageRef;
    String? audioRef;

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

    if (audioBytes != null) {
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${dir.path}/offline_audio');
      if (!audioDir.existsSync()) {
        audioDir.createSync(recursive: true);
      }
      final file = File('${audioDir.path}/$id.m4a');
      await file.writeAsBytes(audioBytes);
      audioRef = '$id.m4a';
    }

    final db = await LocalDb.db;
    await db.insert('outbox', {
      'id': id,
      'op_type': opType,
      'payload': jsonEncode(payload),
      'image_ref': imageRef,
      'audio_ref': audioRef,
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
      // 'retry_manual' ops were requeued by the user via the Retry button. They
      // sync like pending ops but bypass the attempts cap for one pass and don't
      // increment the counter (see SyncService._processOp).
      where: "status IN ('pending', 'retry_manual')",
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
    // needs_review ops are surfaced as notifications, not counted as pending.
    final result = await db.rawQuery(
      "SELECT COUNT(*) as c FROM outbox WHERE status NOT IN ('done', 'needs_review')",
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// Ops still eligible to sync (not done, not permanently failed, not parked
  /// for review). Used to decide whether another sync pass is worthwhile.
  static Future<int> retryableCount() async {
    final db = await LocalDb.db;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as c FROM outbox WHERE status NOT IN ('done', 'failed', 'needs_review')",
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// Ops parked because sync detected a likely duplicate; resolved by the user
  /// via a notification.
  static Future<List<OutboxOp>> needsReview() async {
    final db = await LocalDb.db;
    final rows = await db.query(
      'outbox',
      where: "status = 'needs_review'",
      orderBy: 'created_at ASC',
    );
    return rows.map(_fromRow).toList();
  }

  /// Parks an op for user review, storing the duplicate matches as JSON.
  static Future<void> markNeedsReview(String id, String reviewDataJson) async {
    final db = await LocalDb.db;
    await db.update(
      'outbox',
      {'status': 'needs_review', 'review_data': reviewDataJson},
      where: 'id = ?',
      whereArgs: [id],
    );
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

  /// Marks an op failed WITHOUT incrementing its attempts counter. Used for the
  /// failure of a manual-retry pass, so a user-initiated Retry never counts
  /// against the automatic-retry cap.
  static Future<void> markFailedNoIncrement(String id, String error) async {
    final db = await LocalDb.db;
    await db.update(
      'outbox',
      {'status': 'failed', 'last_error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Overwrites an op's payload (e.g. to persist AI-enriched fields back before
  /// parking it for review, so the notification shows real data).
  static Future<void> updatePayload(String id, Map<String, dynamic> payload) async {
    final db = await LocalDb.db;
    await db.update(
      'outbox',
      {'payload': jsonEncode(payload)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Resets an op to pending and increments its attempt counter so transient
  /// failures eventually hit [_maxAttempts] instead of retrying forever.
  static Future<void> resetToPending(String id, {String? error}) async {
    final db = await LocalDb.db;
    final rows = await db.query('outbox', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final current = rows.first['attempts'] as int? ?? 0;
    await db.update(
      'outbox',
      {'status': 'pending', 'attempts': current + 1, 'last_error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Requeues every failed op for a manual retry: status -> 'retry_manual',
  /// error cleared. The attempts counter is left untouched on purpose — a manual
  /// Retry runs one pass that bypasses the cap and does not count toward it
  /// (see SyncService._processOp). Returns the number of ops requeued.
  static Future<int> retryAllFailed() async {
    final db = await LocalDb.db;
    return db.update(
      'outbox',
      {'status': 'retry_manual', 'last_error': null},
      where: "status = 'failed'",
    );
  }

  /// Requeues a single failed op for a manual retry. Same semantics as
  /// [retryAllFailed] but scoped to one op — attempts is left untouched so the
  /// retry bypasses and doesn't count toward the automatic cap.
  static Future<void> retryFailed(String id) async {
    final db = await LocalDb.db;
    await db.update(
      'outbox',
      {'status': 'retry_manual', 'last_error': null},
      where: "id = ? AND status = 'failed'",
      whereArgs: [id],
    );
  }

  static Future<void> delete(String id) async {
    final db = await LocalDb.db;
    await db.delete('outbox', where: 'id = ?', whereArgs: [id]);
    // Best-effort blob cleanup.
    try {
      final dir = await getApplicationDocumentsDirectory();
      final image = File('${dir.path}/offline_images/$id.jpg');
      if (image.existsSync()) image.deleteSync();
      final audio = File('${dir.path}/offline_audio/$id.m4a');
      if (audio.existsSync()) audio.deleteSync();
    } catch (_) {}
  }

  static Future<void> _deleteImageForOp(String opId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/offline_images/$opId.jpg');
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  static Future<void> _deleteAudioForOp(String opId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/offline_audio/$opId.m4a');
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

  /// Reads the saved audio bytes for an op (returns null if none).
  static Future<Uint8List?> readAudio(OutboxOp op) async {
    if (op.audioRef == null) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/offline_audio/${op.audioRef}');
      if (!file.existsSync()) return null;
      return file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteImageAfterSync(OutboxOp op) => _deleteImageForOp(op.id);

  static Future<void> deleteAudioAfterSync(OutboxOp op) => _deleteAudioForOp(op.id);

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
      audioRef: row['audio_ref'] as String?,
      eventId: row['event_id'] as String?,
      status: row['status'] as String,
      attempts: row['attempts'] as int? ?? 0,
      lastError: row['last_error'] as String?,
      createdAt: row['created_at'] as int,
      serverId: row['server_id'] as String?,
      reviewData: row['review_data'] as String?,
    );
  }
}
