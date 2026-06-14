import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

/// Wraps connectivity_plus with a reachability probe.
///
/// connectivity_plus only reports interface (wifi/cellular), not actual
/// reachability. We do a lightweight GET /health before declaring online.
/// While offline, a 15-second timer re-probes so we catch the case where
/// the interface stays connected but the server was temporarily unreachable.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;
  ConnectivityService._();

  bool _isOnline = true;
  bool _initialized = false;
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _retryTimer;

  bool get isOnline => kIsWeb ? true : _isOnline;
  Stream<bool> get onStatusChange => _controller.stream;

  Future<void> initialize() async {
    if (kIsWeb) return;

    // Idempotent: re-initialise cleanly instead of stacking listeners.
    await _sub?.cancel();

    // Determine initial state from the interface, then refine with a probe.
    final results = await Connectivity().checkConnectivity();
    await _evaluate(results, emit: false);
    _initialized = true;

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      _evaluate(results, emit: true);
    });
  }

  /// Resolves online/offline from the interface state plus a reachability probe,
  /// updating [_isOnline] and (optionally) emitting on change.
  Future<void> _evaluate(List<ConnectivityResult> results, {required bool emit}) async {
    final hasInterface = results.any((r) => r != ConnectivityResult.none);

    bool online;
    if (!hasInterface) {
      // No network interface at all — definitively offline.
      online = false;
    } else {
      // Interface present. Probe the server, but don't let a single slow/failed
      // probe flip a connected device offline — retry a couple of times first.
      online = await _probeWithRetries();
    }

    final changed = online != _isOnline;
    _isOnline = online;
    _updateRetryTimer();
    if (emit && changed) _controller.add(_isOnline);
  }

  /// While offline, poll every 15 s so we detect server recovery even when
  /// the network interface never changes (e.g. captive portal becomes routable).
  void _updateRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (!_isOnline) {
      _retryTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
        final results = await Connectivity().checkConnectivity();
        if (results.every((r) => r == ConnectivityResult.none)) return;
        final nowOnline = await _probeWithRetries();
        if (nowOnline && !_isOnline) {
          _isOnline = true;
          _retryTimer?.cancel();
          _retryTimer = null;
          _controller.add(true);
        }
      });
    }
  }

  Future<bool> checkNow() async {
    if (kIsWeb) return true;
    if (!_initialized) {
      await initialize();
      return _isOnline;
    }
    final results = await Connectivity().checkConnectivity();
    await _evaluate(results, emit: true);
    return _isOnline;
  }

  /// Probes /health up to 3 times with short backoff. A connected interface
  /// shouldn't be declared offline on the first transient failure.
  Future<bool> _probeWithRetries() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (await _probe()) return true;
      if (attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
    }
    return false;
  }

  Future<bool> _probe() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/health'))
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _retryTimer?.cancel();
    _sub?.cancel();
    _controller.close();
  }
}
