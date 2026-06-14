import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

/// Wraps connectivity_plus with a reachability probe.
///
/// connectivity_plus only reports interface (wifi/cellular), not actual
/// reachability. We do a lightweight GET /health before declaring online.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;
  ConnectivityService._();

  bool _isOnline = true;
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get isOnline => kIsWeb ? true : _isOnline;
  Stream<bool> get onStatusChange => _controller.stream;

  Future<void> initialize() async {
    if (kIsWeb) return;

    // Check initial state.
    final results = await Connectivity().checkConnectivity();
    _isOnline = await _probe(results);

    _sub = Connectivity().onConnectivityChanged.listen((results) async {
      final wasOnline = _isOnline;
      _isOnline = await _probe(results);
      if (_isOnline != wasOnline) {
        _controller.add(_isOnline);
      }
    });
  }

  Future<bool> checkNow() async {
    if (kIsWeb) return true;
    final results = await Connectivity().checkConnectivity();
    _isOnline = await _probe(results);
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
    _sub?.cancel();
    _controller.close();
  }
}
