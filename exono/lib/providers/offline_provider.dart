import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;

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
  StreamSubscription<bool>? _connectivitySub;

  SyncState get state => _state;
  int get pendingCount => _pendingCount;
  bool get isOnline => _state != SyncState.offline;

  Future<void> initialize() async {
    if (kIsWeb) return;

    await ConnectivityService().initialize();
    _state = ConnectivityService().isOnline ? SyncState.online : SyncState.offline;
    _pendingCount = await OfflineQueue.pendingCount();
    notifyListeners();

    _connectivitySub = ConnectivityService().onStatusChange.listen((online) async {
      if (online) {
        await _onCameOnline();
      } else {
        _state = SyncState.offline;
        _pendingCount = await OfflineQueue.pendingCount();
        notifyListeners();
      }
    });
  }

  Future<void> _onCameOnline() async {
    _pendingCount = await OfflineQueue.pendingCount();
    if (_pendingCount == 0) {
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

    await SyncService().sync();

    _pendingCount = await OfflineQueue.pendingCount();
    _state = SyncState.online;
    notifyListeners();
  }

  /// Call this after enqueueing an op so the badge count updates immediately.
  Future<void> refreshPendingCount() async {
    if (kIsWeb) return;
    _pendingCount = await OfflineQueue.pendingCount();
    notifyListeners();
  }

  /// Manually trigger sync (e.g. pull-to-refresh while online).
  Future<void> triggerSync() async {
    if (kIsWeb || _state == SyncState.offline) return;
    await _onCameOnline();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
}
