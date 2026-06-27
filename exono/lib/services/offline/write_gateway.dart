import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../api_service.dart';
import 'connectivity_service.dart';
import 'offline_queue.dart';

/// Routes write operations through the API when online, or into the offline
/// outbox when offline. Screens call the gateway; they don't check connectivity.
class WriteGateway {
  static final WriteGateway _instance = WriteGateway._();
  factory WriteGateway() => _instance;
  WriteGateway._();

  bool get isOnline => ConnectivityService().isOnline;

  // Set once at login (same pattern as LiveEventProvider.init).
  AppDatabase? _db;
  String? _userId;

  void init(AppDatabase db, String userId) {
    _db = db;
    _userId = userId;
  }

  // ── Capture ───────────────────────────────────────────────────────────────

  /// Save a scan/manual capture.
  ///
  /// If offline and [imageBytes] provided, saves to disk and defers AI.
  /// Returns [WriteResult] with [savedOffline] flag.
  Future<WriteResult> createCapture({
    required String captureType,
    String? imageData,
    Uint8List? imageBytes,
    String? rawText,
    Map<String, dynamic>? extractedData,
    String? eventId,
    String? meetingContext,
    /// When true the sync-time duplicate check is skipped — used after the user
    /// has explicitly chosen "create as new" from a dedup notification.
    bool skipDuplicateCheck = false,
  }) async {
    if (isOnline) {
      // Online callers may pass raw bytes (camera/upload) instead of a base64
      // string; encode them so the image reaches the backend and gets stored.
      final onlineImageData = imageData ?? (imageBytes != null ? base64Encode(imageBytes) : null);
      final result = await ApiService.createCapture(
        captureType: captureType,
        imageData: onlineImageData,
        rawText: rawText,
        extractedData: extractedData,
        eventId: eventId,
        meetingContext: meetingContext,
      );
      return WriteResult(data: result);
    }

    final opId = await OfflineQueue.enqueue(
      opType: 'create_capture',
      payload: {
        'captureType': captureType,
        'rawText': rawText,
        'extractedData': extractedData ?? {},
        'eventId': eventId,
        if (meetingContext != null && meetingContext.isNotEmpty) 'meetingContext': meetingContext,
        'skipDuplicateCheck': skipDuplicateCheck,
      },
      imageBytes: imageBytes,
      eventId: eventId,
    );
    return WriteResult(savedOffline: true, offlineOpId: opId);
  }

  // ── Contact ───────────────────────────────────────────────────────────────

  Future<WriteResult> createContact(Map<String, dynamic> contactData) async {
    if (isOnline) {
      final contact = await ApiService.createContact(contactData);
      return WriteResult(data: {'id': contact.id});
    }

    final opId = await OfflineQueue.enqueue(
      opType: 'create_contact',
      payload: contactData,
    );
    return WriteResult(savedOffline: true, offlineOpId: opId);
  }

  // ── Interaction ───────────────────────────────────────────────────────────

  Future<WriteResult> logInteraction({
    required String contactId,
    String? eventId,
    required String type,
    required String summary,
    String? interactionDate,
    Map<String, dynamic>? details,
  }) async {
    if (isOnline) {
      final result = await ApiService.logInteraction(
        contactId: contactId,
        eventId: eventId,
        type: type,
        summary: summary,
        interactionDate: interactionDate,
        details: details,
      );
      return WriteResult(data: result);
    }

    final opId = await OfflineQueue.enqueue(
      opType: 'log_interaction',
      payload: {
        'contactId': contactId,
        'eventId': eventId,
        'type': type,
        'summary': summary,
        'interactionDate': interactionDate,
        'details': details,
      },
      eventId: eventId,
    );
    return WriteResult(savedOffline: true, offlineOpId: opId);
  }

  /// Save a voice-note interaction.
  ///
  /// Online: posts the interaction immediately and returns its id so the caller
  /// can fire-and-forget transcription. Offline: persists [audioBytes] to disk
  /// and queues the interaction; both the create and the transcription are
  /// deferred to sync time (see SyncService._syncVoiceNote).
  Future<WriteResult> logVoiceNote({
    required String contactId,
    String? eventId,
    required Uint8List audioBytes,
    String? interactionDate,
    required int durationSeconds,
  }) async {
    if (isOnline) {
      final result = await ApiService.logInteraction(
        contactId: contactId,
        eventId: eventId,
        type: 'voice_note',
        summary: 'Voice note - transcript pending...',
        interactionDate: interactionDate,
        details: {'duration_seconds': durationSeconds, 'has_audio': true},
      );
      return WriteResult(data: result);
    }

    final opId = await OfflineQueue.enqueue(
      opType: 'log_voice_note',
      payload: {
        'contactId': contactId,
        'eventId': eventId,
        'interactionDate': interactionDate,
        'durationSeconds': durationSeconds,
      },
      audioBytes: audioBytes,
      eventId: eventId,
    );
    return WriteResult(savedOffline: true, offlineOpId: opId);
  }

  // ── Event ─────────────────────────────────────────────────────────────────

  Future<WriteResult> createEvent(Map<String, dynamic> eventData) async {
    if (isOnline) {
      final event = await ApiService.createEvent(eventData);
      return WriteResult(data: {'id': event.id});
    }

    final opId = await OfflineQueue.enqueue(
      opType: 'create_event',
      payload: eventData,
    );
    return WriteResult(savedOffline: true, offlineOpId: opId);
  }

  Future<WriteResult> updateEventGoal(
      String eventId, String goalId, Map<String, dynamic> data) async {
    if (isOnline) {
      final result = await ApiService.updateEventGoal(eventId, goalId, data);
      return WriteResult(data: result);
    }

    // Write-through: update the local drift row immediately so the value
    // survives a cold restart before sync.
    final db = _db;
    if (db != null) {
      final now = DateTime.now().toUtc();
      await (db.update(db.eventGoalsTable)..where((t) => t.id.equals(goalId)))
          .write(EventGoalsTableCompanion(
        current: data.containsKey('current') ? Value(data['current'] as int) : const Value.absent(),
        updatedAt: Value(now),
      ));
    }

    final opId = await OfflineQueue.enqueue(
      opType: 'update_event_goal',
      payload: {'eventId': eventId, 'goalId': goalId, ...data},
      eventId: eventId,
    );
    return WriteResult(savedOffline: true, offlineOpId: opId);
  }

  Future<WriteResult> updateTargetContactStatus(
      String eventId, String contactId, String status) async {
    if (isOnline) {
      await ApiService.updateTargetContactStatus(eventId, contactId, status);
      return const WriteResult();
    }

    // Write-through: update contact_events locally so status survives a restart.
    final db = _db;
    if (db != null) {
      final now = DateTime.now().toUtc();
      await (db.update(db.contactEventsTable)
            ..where((t) =>
                t.contactId.equals(contactId) &
                t.eventId.equals(eventId) &
                t.deletedAt.isNull()))
          .write(ContactEventsTableCompanion(
        status: Value(status),
        updatedAt: Value(now),
      ));
    }

    final opId = await OfflineQueue.enqueue(
      opType: 'update_target_contact_status',
      payload: {'eventId': eventId, 'contactId': contactId, 'status': status},
      eventId: eventId,
    );
    return WriteResult(savedOffline: true, offlineOpId: opId);
  }

  Future<WriteResult> updateTargetCompanyMet(
      String eventId, String targetId, bool met) async {
    if (isOnline) {
      await ApiService.updateTargetCompanyMet(eventId, targetId, met);
      return const WriteResult();
    }

    // Write-through: upsert into target_company_met locally. The server uses
    // (user_id, target_id) as the unique key; locally we need a stable uuid id.
    // Look for an existing row first; if none, generate a new id.
    final db = _db;
    final userId = _userId;
    if (db != null && userId != null) {
      final now = DateTime.now().toUtc();
      final existing = await (db.select(db.targetCompanyMetTable)
            ..where((t) =>
                t.userId.equals(userId) &
                t.targetId.equals(targetId) &
                t.deletedAt.isNull()))
          .getSingleOrNull();
      final rowId = existing?.id ?? const Uuid().v4();
      await db.into(db.targetCompanyMetTable).insertOnConflictUpdate(
            TargetCompanyMetTableCompanion(
              id: Value(rowId),
              userId: Value(userId),
              eventId: Value(eventId),
              targetId: Value(targetId),
              met: Value(met),
              createdAt: Value(existing?.createdAt ?? now),
              updatedAt: Value(now),
            ),
          );
    }

    final opId = await OfflineQueue.enqueue(
      opType: 'update_target_company_met',
      payload: {'eventId': eventId, 'targetId': targetId, 'met': met},
      eventId: eventId,
    );
    return WriteResult(savedOffline: true, offlineOpId: opId);
  }
}

class WriteResult {
  final Map<String, dynamic>? data;
  final bool savedOffline;
  final String? offlineOpId;

  const WriteResult({
    this.data,
    this.savedOffline = false,
    this.offlineOpId,
  });
}
