import 'dart:typed_data';

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
  }) async {
    if (isOnline) {
      final result = await ApiService.createCapture(
        captureType: captureType,
        imageData: imageData,
        rawText: rawText,
        extractedData: extractedData,
        eventId: eventId,
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
