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

  /// Minimum spacing between successive transcription calls, so a backlog of
  /// queued voice notes doesn't burst the transcribe endpoint when the device
  /// reconnects. Ops sync sequentially, so this is enforced per-call.
  static const Duration _transcribeMinInterval = Duration(seconds: 3);
  DateTime? _lastTranscribeAt;

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
    // A manual Retry requeues the op as 'retry_manual'. That pass bypasses the
    // attempts cap and does not increment the counter, so user-initiated retries
    // never count toward the automatic-retry limit.
    final isManualRetry = op.status == 'retry_manual';

    if (!isManualRetry && op.attempts >= _maxAttempts) {
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
        case 'log_voice_note':
          serverId = await _syncVoiceNote(op);
        case 'create_event':
          serverId = await _syncEvent(op);
        case 'update_event_goal':
          await _syncUpdateEventGoal(op);
        case 'update_target_contact_status':
          await _syncUpdateTargetContactStatus(op);
        default:
          // Unknown op type — mark failed, don't retry.
          await OfflineQueue.markFailed(op.id, 'Unknown op_type: ${op.opType}');
          return;
      }

      await OfflineQueue.markDone(op.id, serverId: serverId);
      await OfflineQueue.deleteImageAfterSync(op);
      await OfflineQueue.deleteAudioAfterSync(op);
    } on _NeedsReview catch (e) {
      // A likely duplicate was detected at sync time. Park the op; the user
      // resolves it via a notification (see OfflineProvider).
      await OfflineQueue.markNeedsReview(op.id, e.dupesJson);
    } on _PermanentError catch (e) {
      await OfflineQueue.markFailed(op.id, e.message);
    } catch (e) {
      // Transient error.
      if (isManualRetry) {
        // The user triggered this pass; it doesn't count toward the cap. Park
        // it back as failed (no increment) so the Retry button shows again.
        await OfflineQueue.markFailedNoIncrement(op.id, e.toString());
      } else if (op.attempts + 1 >= _maxAttempts) {
        // The op's attempts counter was already checked at the top of this
        // method; bumping past the cap marks it failed.
        await OfflineQueue.markFailed(op.id, e.toString());
      } else {
        // Otherwise it returns to pending (with attempts incremented) for the
        // next sync pass.
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

    // Persist the AI-enriched fields back to the op so that, if it gets parked
    // for review below, the notification (and a later "create new") shows the
    // real extracted contact data rather than the original empty payload.
    payload['extractedData'] = extractedData;
    await OfflineQueue.updatePayload(op.id, payload);

    // Duplicate detection deferred to sync time (needs network). If a likely
    // match exists, park for user review instead of creating. Skipped when the
    // user already chose "create as new" from a dedup notification.
    if (payload['skipDuplicateCheck'] != true) {
      await _guardDuplicate(
        name: (extractedData['name'] ?? '').toString().trim().isNotEmpty
            ? extractedData['name'].toString()
            : '${extractedData['first_name'] ?? ''} ${extractedData['last_name'] ?? ''}'.trim(),
        email: extractedData['email']?.toString(),
        phone: extractedData['phone']?.toString(),
      );
    }

    final result = await ApiService.createCapture(
      captureType: captureType,
      imageData: imageData,
      rawText: payload['rawText'] as String?,
      extractedData: extractedData,
      eventId: eventId,
      meetingContext: payload['meetingContext'] as String?,
      idempotencyKey: op.id,
    );
    return result['data']?['id'] as String?;
  }

  Future<String?> _syncContact(OutboxOp op) async {
    final p = op.payload;
    await _guardDuplicate(
      name: (p['name'] ?? '').toString().trim().isNotEmpty
          ? p['name'].toString()
          : '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim(),
      email: p['email']?.toString(),
      phone: p['phone']?.toString(),
    );

    final contact = await ApiService.createContact(
      op.payload,
      idempotencyKey: op.id,
    );
    return contact.id;
  }

  /// Runs the server duplicate check. Throws [_NeedsReview] (carrying the match
  /// list as JSON) when duplicates are found so the op gets parked. Check
  /// failures are swallowed so they don't block the create.
  Future<void> _guardDuplicate({
    required String name,
    String? email,
    String? phone,
  }) async {
    if (name.isEmpty && (email?.isEmpty ?? true) && (phone?.isEmpty ?? true)) {
      return;
    }
    try {
      final result = await ApiService.checkDuplicateContacts(
        name: name,
        email: email ?? '',
        phone: phone ?? '',
      );
      if (result['has_duplicates'] == true) {
        final dupes = result['data'] as List? ?? [];
        if (dupes.isNotEmpty) {
          throw _NeedsReview(jsonEncode(dupes));
        }
      }
    } on _NeedsReview {
      rethrow;
    } catch (_) {
      // Duplicate check failed (network/transient) — proceed with create.
    }
  }

  /// Backend enum for interaction_type. Free-text modes fall back to 'manual'.
  static const _allowedInteractionTypes = {
    'manual', 'email', 'call', 'meeting', 'capture', 'event_link', 'note',
  };

  /// Coerces a stored type to a value the backend accepts. Older queued ops may
  /// hold a free-text mode (e.g. 'coffee_chat') that predates the screen-side
  /// fix; normalize it here so the replay doesn't 400.
  static String _safeType(String? type) {
    final t = (type ?? '').toLowerCase();
    return _allowedInteractionTypes.contains(t) ? t : 'manual';
  }

  /// Ensures a stored date is a backend-valid RFC3339 timestamp WITH timezone.
  /// Older ops stored a local ISO string with no 'Z'/offset (rejected by Zod);
  /// re-parse and emit UTC. Returns null if absent/unparseable (server defaults).
  static String? _safeDate(String? date) {
    if (date == null || date.isEmpty) return null;
    final parsed = DateTime.tryParse(date);
    return parsed?.toUtc().toIso8601String();
  }

  Future<String?> _syncInteraction(OutboxOp op) async {
    final payload = op.payload;
    final result = await ApiService.logInteraction(
      contactId: payload['contactId'] as String,
      eventId: payload['eventId'] as String?,
      type: _safeType(payload['type'] as String?),
      summary: payload['summary'] as String? ?? '',
      interactionDate: _safeDate(payload['interactionDate'] as String?),
      details: payload['details'] as Map<String, dynamic>?,
      idempotencyKey: op.id,
    );
    return result['data']?['id'] as String?;
  }

  /// Replays a deferred voice note: creates the interaction (idempotent), then
  /// transcribes the saved audio under a rate limit and patches the summary.
  /// A transcription failure is non-fatal — the interaction is still created
  /// with its placeholder summary, so the op is considered done.
  Future<String?> _syncVoiceNote(OutboxOp op) async {
    final payload = op.payload;
    final durationSeconds = payload['durationSeconds'] as int? ?? 0;

    final result = await ApiService.logInteraction(
      contactId: payload['contactId'] as String,
      eventId: payload['eventId'] as String?,
      type: 'voice_note',
      summary: 'Voice note - transcript pending...',
      interactionDate: _safeDate(payload['interactionDate'] as String?),
      details: {'duration_seconds': durationSeconds, 'has_audio': true},
      idempotencyKey: op.id,
    );
    final interactionId = result['data']?['id'] as String?;

    final audioBytes = await OfflineQueue.readAudio(op);
    if (interactionId != null && audioBytes != null) {
      try {
        await _throttleTranscription();
        final transcript =
            await ApiService.transcribeAudio(base64Encode(audioBytes));
        if (transcript.isNotEmpty) {
          await ApiService.updateInteraction(interactionId, {
            'summary': transcript,
            'details': {
              'duration_seconds': durationSeconds,
              'has_audio': true,
              'transcript': transcript,
            },
          });
        }
      } catch (_) {
        // Transcription failed (rate limit / transient). The interaction is
        // already saved with its placeholder; don't fail the whole op.
      }
    }

    return interactionId;
  }

  /// Spaces transcription calls by [_transcribeMinInterval] to avoid bursting
  /// the endpoint when a backlog of voice notes syncs at once.
  Future<void> _throttleTranscription() async {
    final last = _lastTranscribeAt;
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < _transcribeMinInterval) {
        await Future.delayed(_transcribeMinInterval - elapsed);
      }
    }
    _lastTranscribeAt = DateTime.now();
  }

  Future<String?> _syncEvent(OutboxOp op) async {
    final event = await ApiService.createEvent(
      op.payload,
      idempotencyKey: op.id,
    );
    return event.id;
  }

  Future<void> _syncUpdateEventGoal(OutboxOp op) async {
    final eventId = op.payload['eventId'] as String;
    final goalId = op.payload['goalId'] as String;
    final data = Map<String, dynamic>.from(op.payload)
      ..remove('eventId')
      ..remove('goalId');
    await ApiService.updateEventGoal(eventId, goalId, data);
  }

  Future<void> _syncUpdateTargetContactStatus(OutboxOp op) async {
    final eventId = op.payload['eventId'] as String;
    final contactId = op.payload['contactId'] as String;
    final status = op.payload['status'] as String;
    await ApiService.updateTargetContactStatus(eventId, contactId, status);
  }

}

class _PermanentError {
  final String message;
  _PermanentError(this.message);
}

/// Thrown during sync when a duplicate contact is detected, so the op is parked
/// as 'needs_review' rather than created. Carries the matches as a JSON string.
class _NeedsReview implements Exception {
  final String dupesJson;
  _NeedsReview(this.dupesJson);
}
