import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../api_service.dart';
import 'connectivity_service.dart';
import 'offline_queue.dart';
import 'outbox_op.dart';

/// Replays pending outbox ops against live backend endpoints.
///
/// Call [sync] whenever connectivity is regained or on app resume.
/// A concurrency guard ensures at most one sync runs at a time.
class SyncService {
  static final SyncService _instance = SyncService._();
  factory SyncService() => _instance;
  SyncService._();

  bool _isSyncing = false;
  void Function(int pending)? onProgress;

  static const int _maxAttempts = 5;

  Future<void> sync() async {
    if (kIsWeb) return;
    if (_isSyncing) return;
    if (!ConnectivityService().isOnline) return;

    _isSyncing = true;
    try {
      await _runSync();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _runSync() async {
    final ops = await OfflineQueue.pendingOnly();
    for (final op in ops) {
      if (!ConnectivityService().isOnline) break;
      await _processOp(op);
    }
  }

  Future<void> _processOp(OutboxOp op) async {
    if (op.attempts >= _maxAttempts) {
      await OfflineQueue.markFailed(op.id, 'Max retry attempts reached');
      return;
    }

    await OfflineQueue.markSyncing(op.id);

    try {
      String? serverId;

      switch (op.opType) {
        case 'create_capture':
          serverId = await _syncCapture(op);
        case 'create_contact':
          serverId = await _syncContact(op);
        case 'log_interaction':
          serverId = await _syncInteraction(op);
        case 'create_event':
          serverId = await _syncEvent(op);
        default:
          // Unknown op type — mark failed, don't retry.
          await OfflineQueue.markFailed(op.id, 'Unknown op_type: ${op.opType}');
          return;
      }

      await OfflineQueue.markDone(op.id, serverId: serverId);
      await OfflineQueue.deleteImageAfterSync(op);
    } on _PermanentError catch (e) {
      await OfflineQueue.markFailed(op.id, e.message);
    } catch (e) {
      // Transient error. The op's attempts counter was already checked at the
      // top of this method; bumping past the cap marks it failed, otherwise it
      // returns to pending (with attempts incremented) for the next sync pass.
      if (op.attempts + 1 >= _maxAttempts) {
        await OfflineQueue.markFailed(op.id, e.toString());
      } else {
        await OfflineQueue.resetToPending(op.id, error: e.toString());
      }
    }
  }

  Future<String?> _syncCapture(OutboxOp op) async {
    final payload = Map<String, dynamic>.from(op.payload);
    final captureType = payload['captureType'] as String? ?? 'manual';
    final eventId = payload['eventId'] as String?;
    Map<String, dynamic> extractedData =
        Map<String, dynamic>.from(payload['extractedData'] as Map? ?? {});

    String? imageData;

    if (op.imageRef != null) {
      final bytes = await OfflineQueue.readImage(op);
      if (bytes != null) {
        imageData = base64Encode(bytes);
        // AI extraction deferred to sync time (client-driven).
        try {
          final aiResult = await ApiService.analyzeCard(imageData);
          final aiData =
              Map<String, dynamic>.from(aiResult['data'] as Map? ?? {});
          // User-entered fields win on conflict.
          for (final entry in aiData.entries) {
            if (!extractedData.containsKey(entry.key) ||
                extractedData[entry.key] == null ||
                extractedData[entry.key].toString().isEmpty) {
              extractedData[entry.key] = entry.value;
            }
          }
        } catch (_) {
          // analyze-card failed — still attempt to save with user-typed fields.
        }
      }
    }

    final result = await ApiService.createCapture(
      captureType: captureType,
      imageData: imageData,
      rawText: payload['rawText'] as String?,
      extractedData: extractedData,
      eventId: eventId,
      idempotencyKey: op.id,
    );
    return result['data']?['id'] as String?;
  }

  Future<String?> _syncContact(OutboxOp op) async {
    final contact = await ApiService.createContact(
      op.payload,
      idempotencyKey: op.id,
    );
    return contact.id;
  }

  Future<String?> _syncInteraction(OutboxOp op) async {
    final payload = op.payload;
    final result = await ApiService.logInteraction(
      contactId: payload['contactId'] as String,
      eventId: payload['eventId'] as String?,
      type: payload['type'] as String? ?? 'meeting',
      summary: payload['summary'] as String? ?? '',
      interactionDate: payload['interactionDate'] as String?,
      idempotencyKey: op.id,
    );
    return result['data']?['id'] as String?;
  }

  Future<String?> _syncEvent(OutboxOp op) async {
    final event = await ApiService.createEvent(
      op.payload,
      idempotencyKey: op.id,
    );
    return event.id;
  }

}

class _PermanentError {
  final String message;
  _PermanentError(this.message);
}
