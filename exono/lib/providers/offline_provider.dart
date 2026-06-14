import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import 'notification_provider.dart';
import '../services/offline/background_sync.dart';
import '../services/offline/connectivity_service.dart';
import '../services/offline/offline_queue.dart';
import '../services/offline/sync_service.dart';

enum SyncState { online, offline, syncing }

/// App-wide offline / sync state.
///
/// Wire into the widget tree via [MultiProvider] in main.dart.
/// Call [initialize] immediately after construction.
class OfflineProvider extends ChangeNotifier with WidgetsBindingObserver {
  SyncState _state = SyncState.online;
  int _pendingCount = 0;
  int _failedCount = 0;
  StreamSubscription<bool>? _connectivitySub;

  void Function(AppNotification notification)? _onNotification;

  /// Wired by the app to forward sync-time duplicate detections into the
  /// NotificationProvider. Setting it also flushes any ops already parked for
  /// review (e.g. by a background sync that ran while the app was closed).
  set onNotification(void Function(AppNotification notification)? cb) {
    _onNotification = cb;
    if (cb != null && !kIsWeb) {
      _emitReviewNotifications();
    }
  }

  SyncState get state => _state;
  int get pendingCount => _pendingCount;
  int get failedCount => _failedCount;
  bool get isOnline => _state != SyncState.offline;
  bool get isSyncing => _state == SyncState.syncing;

  Future<void> initialize() async {
    if (kIsWeb) return;

    WidgetsBinding.instance.addObserver(this);

    await ConnectivityService().initialize();
    _state = ConnectivityService().isOnline ? SyncState.online : SyncState.offline;
    await _refreshCounts();
    notifyListeners();

    _connectivitySub = ConnectivityService().onStatusChange.listen((online) async {
      if (online) {
        await _onCameOnline();
      } else {
        _state = SyncState.offline;
        await _refreshCounts();
        notifyListeners();
      }
    });

    // If we launch already-online with queued ops, drain them now — the stream
    // only fires on a *transition*, so startup would otherwise sit on "PENDING n".
    if (_state == SyncState.online && _pendingCount > 0) {
      await _onCameOnline();
    }
  }

  Future<void> _onCameOnline() async {
    await _refreshCounts();
    if (await OfflineQueue.retryableCount() == 0) {
      // Nothing to sync, but ops parked for review (e.g. by a background sync)
      // may still be waiting — surface them before settling.
      await _emitReviewNotifications();
      _state = SyncState.online;
      notifyListeners();
      return;
    }

    _state = SyncState.syncing;
    notifyListeners();

    SyncService().onProgress = (pending) async {
      _pendingCount = pending;
      notifyListeners();
    };

    // Run sync passes until the queue stops draining. Transient failures reset
    // ops to pending; retrying within the same online window avoids dropping to
    // a misleading "PENDING n" badge while progress is still being made.
    var previous = -1;
    while (true) {
      if (!ConnectivityService().isOnline) break;
      await SyncService().sync();

      final remaining = await OfflineQueue.retryableCount();
      if (remaining == 0 || remaining == previous) break;
      previous = remaining;
    }

    await _emitReviewNotifications();
    await _refreshCounts();
    _state = SyncState.online;
    notifyListeners();
  }

  /// Surfaces ops parked as 'needs_review' during sync as dedup notifications.
  ///
  /// The parked op stays in the DB (the durable source of truth) so the
  /// notification survives a restart; it's only removed when the user resolves
  /// it (merge / create / dismiss) via [resolveReview]. The notification id
  /// equals the op id, so re-emitting is idempotent.
  Future<void> _emitReviewNotifications() async {
    final cb = _onNotification;
    if (cb == null) return;
    final ops = await OfflineQueue.needsReview();
    for (final op in ops) {
      List<Map<String, dynamic>> dupes = const [];
      try {
        final decoded = jsonDecode(op.reviewData ?? '[]') as List;
        dupes = decoded.cast<Map<String, dynamic>>();
      } catch (_) {}

      // Build the pending-contact map from the op payload (capture stores fields
      // under extractedData; create_contact stores them at the top level).
      final payload = op.payload;
      final pending = payload['extractedData'] is Map
          ? Map<String, dynamic>.from(payload['extractedData'] as Map)
          : Map<String, dynamic>.from(payload);

      cb(DedupNotification(
        id: op.id,
        createdAt: DateTime.fromMillisecondsSinceEpoch(op.createdAt),
        dupes: dupes,
        pendingContact: pending,
        eventId: op.eventId,
        rawText: payload['rawText'] as String?,
        source: op.opType == 'create_capture' ? 'capture' : 'manual',
      ));
    }
  }

  /// Removes a resolved review op from the durable queue. Called once the user
  /// has acted on the dedup notification (merge / create / dismiss).
  Future<void> resolveReview(String opId) async {
    if (kIsWeb) return;
    await OfflineQueue.delete(opId);
  }

  Future<void> _refreshCounts() async {
    _pendingCount = await OfflineQueue.pendingCount();
    _failedCount = (await OfflineQueue.failed()).length;
  }

  /// Call this after enqueueing an op so the badge count updates immediately.
  Future<void> refreshPendingCount() async {
    if (kIsWeb) return;
    await _refreshCounts();
    notifyListeners();

    // If something is queued, make sure a background replay is scheduled so it
    // syncs even if the user backgrounds or kills the app before reconnecting.
    if (await OfflineQueue.retryableCount() > 0) {
      await BackgroundSync.scheduleOneOff();
    }
  }

  /// Manually trigger sync (e.g. the home-screen Retry button or pull-to-refresh
  /// while online). Requeues any ops that exhausted their automatic retries so a
  /// manual retry actually re-attempts them.
  Future<void> triggerSync() async {
    if (kIsWeb || _state == SyncState.offline) return;
    await OfflineQueue.retryAllFailed();
    await _onCameOnline();
  }

  /// Forces a fresh connectivity probe and reconciles state. Used on app resume
  /// and as a manual recovery (e.g. the offline screen's retry).
  Future<void> recheckConnectivity() async {
    if (kIsWeb) return;
    final online = await ConnectivityService().checkNow();
    if (online) {
      // Transition into online + drain queue if we were offline.
      if (_state == SyncState.offline) {
        await _onCameOnline();
      } else {
        await _refreshCounts();
        notifyListeners();
      }
    } else {
      _state = SyncState.offline;
      await _refreshCounts();
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On returning to the foreground, re-verify connectivity — the user may
    // have toggled their network while the app was backgrounded, which the
    // connectivity stream can miss.
    if (state == AppLifecycleState.resumed) {
      recheckConnectivity();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    super.dispose();
  }
}
