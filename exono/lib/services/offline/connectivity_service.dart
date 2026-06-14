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
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _retryTimer;

  bool get isOnline => kIsWeb ? true : _isOnline;
  Stream<bool> get onStatusChange => _controller.stream;

  Future<void> initialize() async {
    if (kIsWeb) return;

    // Check initial state.
    final results = await Connectivity().checkConnectivity();
    _isOnline = await _probe(results);
    _updateRetryTimer();

    _sub = Connectivity().onConnectivityChanged.listen((results) async {
      final wasOnline = _isOnline;
      _isOnline = await _probe(results);
      if (_isOnline != wasOnline) {
        _controller.add(_isOnline);
      }
      _updateRetryTimer();
    });
  }

  /// While offline, poll every 15 s so we detect server recovery even when
  /// the network interface never changes (e.g. captive portal becomes routable).
  void _updateRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (!_isOnline) {
      _retryTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
        final results = await Connectivity().checkConnectivity();
        final nowOnline = await _probe(results);
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
    final results = await Connectivity().checkConnectivity();
    final wasOnline = _isOnline;
    _isOnline = await _probe(results);
    if (_isOnline != wasOnline) {
      _controller.add(_isOnline);
    }
    _updateRetryTimer();
    return _isOnline;
  }

  Future<bool> _probe(List<ConnectivityResult> results) async {
    if (results.every((r) => r == ConnectivityResult.none)) return false;
    // Real reachability check against the API /health endpoint.
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/health'))
          .timeout(const Duration(seconds: 5));
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
