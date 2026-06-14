import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/event.dart';
import '../services/api_service.dart';

/// Global singleton that tracks whether an event is currently live.
/// Polls the backend every 60 seconds. Screens listen via ChangeNotifier.
class LiveEventProvider extends ChangeNotifier {
  Event? _liveEvent;
  Event? _nextEvent;
  Map<String, dynamic>? _liveStats;
  List<Map<String, dynamic>> _liveGoals = [];
  List<Map<String, dynamic>> _liveTargets = [];
  List<Map<String, dynamic>> _targetContacts = [];
  List<Map<String, dynamic>> _scannedContacts = [];

  bool _isLoadingLive = false;
  bool _initialized = false;

  Timer? _pollTimer;

  Event? get liveEvent => _liveEvent;
  Event? get nextEvent => _nextEvent;
  Map<String, dynamic>? get liveStats => _liveStats;
  List<Map<String, dynamic>> get liveGoals => List.unmodifiable(_liveGoals);
  List<Map<String, dynamic>> get liveTargets => List.unmodifiable(_liveTargets);
  List<Map<String, dynamic>> get targetContacts => List.unmodifiable(_targetContacts);
  List<Map<String, dynamic>> get scannedContacts => List.unmodifiable(_scannedContacts);

  bool get isLive => _liveEvent != null;
  bool get isLoadingLive => _isLoadingLive;
  bool get initialized => _initialized;

  int get targetsLeft => _targetContacts.where((t) => (t['status'] as String?) != 'met').length;

  /// Call once after login. Starts polling.
  Future<void> init() async {
    await _refresh();
    _pollTimer ??= Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
  }

  /// Force a refresh (e.g. after scanning a contact).
  Future<void> refresh() => _refresh();

  Future<void> _refresh() async {
    // Try to fetch live event
    try {
      _isLoadingLive = true;
      if (!_initialized) notifyListeners();

      final event = await ApiService.getOngoingEvent();
      final data = await ApiService.getLiveEventData(event.id);
      final captures = await ApiService.getEventCaptures(event.id);

      _liveEvent = event;
      _liveStats = data['stats'] as Map<String, dynamic>?;
      _liveGoals = List<Map<String, dynamic>>.from(data['goals'] as List? ?? []);
      _liveTargets = List<Map<String, dynamic>>.from(data['targets'] as List? ?? []);
      _targetContacts = List<Map<String, dynamic>>.from(data['target_contacts'] as List? ?? []);
      _scannedContacts = captures;
    } catch (_) {
      // No live event
      _liveEvent = null;
      _liveStats = null;
      _liveGoals = [];
      _liveTargets = [];
      _targetContacts = [];
      _scannedContacts = [];
    }

    // Try to fetch next upcoming event (only when not live)
    if (_liveEvent == null) {
      try {
        _nextEvent = await ApiService.getNextUpcomingEvent();
      } catch (_) {
        _nextEvent = null;
      }
    }

    _isLoadingLive = false;
    _initialized = true;
    notifyListeners();
  }

  // ── Mutable operations forwarded from screens ─────────────────────────────

  void updateGoalLocally(Map<String, dynamic> updated) {
    final idx = _liveGoals.indexWhere((g) => g['id'] == updated['id']);
    if (idx != -1) {
      _liveGoals = List.from(_liveGoals)..[idx] = updated;
      notifyListeners();
    }
  }

  void revertGoal(Map<String, dynamic> original) => updateGoalLocally(original);

  void addGoalLocally(Map<String, dynamic> goal) {
    _liveGoals = [..._liveGoals, goal];
    notifyListeners();
  }

  void removeGoalLocally(String goalId) {
    _liveGoals = _liveGoals.where((g) => g['id'] != goalId).toList();
    notifyListeners();
  }

  void updateTargetStatusLocally(String targetId, String status) {
    final idx = _liveTargets.indexWhere((t) => t['id'] == targetId);
    if (idx != -1) {
      final updated = List<Map<String, dynamic>>.from(_liveTargets);
      updated[idx] = {...updated[idx], 'status': status};
      _liveTargets = updated;
      notifyListeners();
    }
  }

  void addTargetLocally(Map<String, dynamic> target) {
    _liveTargets = [..._liveTargets, target];
    notifyListeners();
  }

  void removeTargetLocally(String targetId) {
    _liveTargets = _liveTargets.where((t) => t['id'] != targetId).toList();
    notifyListeners();
  }

  void addTargetContactLocally(Map<String, dynamic> contact) {
    _targetContacts = [..._targetContacts, contact];
    notifyListeners();
  }

  void removeTargetContactLocally(String contactId) {
    _targetContacts = _targetContacts.where((c) => c['contact_id'] != contactId).toList();
    notifyListeners();
  }

  void updateTargetContactStatusLocally(String contactId, String status) {
    final idx = _targetContacts.indexWhere((c) => c['contact_id'] == contactId);
    if (idx != -1) {
      final updated = List<Map<String, dynamic>>.from(_targetContacts);
      updated[idx] = {...updated[idx], 'status': status};
      _targetContacts = updated;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
