import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;

import '../services/offline/background_sync.dart';
import '../services/offline/connectivity_service.dart';
import '../services/offline/offline_queue.dart';
import '../services/offline/sync_service.dart';

enum SyncState { online, offline, syncing }

/// App-wide offline / sync state.
///
/// Wire into the widget tree via [MultiProvider] in main.dart.
/// Call [initialize] immediately after construction.
class OfflineProvider extends ChangeNotifier {
  SyncState _state = SyncState.online;
  int _pendingCount = 0;
  int _failedCount = 0;
  StreamSubscription<bool>? _connectivitySub;

  SyncState get state => _state;
  int get pendingCount => _pendingCount;
  int get failedCount => _failedCount;
  bool get isOnline => _state != SyncState.offline;
  bool get isSyncing => _state == SyncState.syncing;

  Future<void> initialize() async {
    if (kIsWeb) return;

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

    await _refreshCounts();
    _state = SyncState.online;
    notifyListeners();
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

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
