import 'dart:async';
import 'package:drift/drift.dart' show OrderingMode, OrderingTerm;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../db/app_database.dart';
import '../models/event.dart';
import '../services/api_service.dart';

/// Global singleton that tracks whether an event is currently live.
///
/// Freshness strategy (see also [SyncProvider]):
///   - Idle (no ongoing event): zero network. A drift watch on the locally
///     synced `events` table tells us when an event becomes/stops being
///     ongoing, so we never poll `/live-session` just to learn "nothing's
///     live" — that table is already kept fresh by sync + Realtime.
///   - Live (an event is ongoing): subscribe to Supabase Realtime on the
///     tables that feed the live aggregate and refresh (debounced) on any
///     change, instead of a blind timer. A slow safety-net timer covers any
///     dropped socket.
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

  // Idle gate: a drift watch on `events` decides whether anything is ongoing.
  String? _userId;
  StreamSubscription<List<EventsTableData>>? _ongoingWatch;
  bool _hasOngoing = false;
  // Latest events snapshot + a clock ticker. The "ongoing" condition is
  // time-driven (an upcoming event becomes ongoing when the clock crosses its
  // start time) but the drift watch only fires on table writes — so without a
  // ticker an event that turns live while already in the DB would never flip
  // the home screen into live mode. The ticker re-evaluates against the last
  // snapshot so the boundary is crossed on time, not just on a row change.
  List<EventsTableData> _eventsSnapshot = const [];
  Timer? _ongoingTicker;

  // Live mode: Realtime subscriptions + a debounce + a slow safety-net poll.
  // Tables whose changes affect the live aggregate returned by /live-session.
  static const _liveTables = [
    'captures',
    'event_goals',
    'target_companies',
    'contact_events',
    'contacts',
  ];
  final List<RealtimeChannel> _liveChannels = [];
  Timer? _debounce;
  Timer? _safetyTimer;

  // Goals with an in-flight optimistic edit. While a goal id is pending, a
  // /live-session refresh (which can race ahead of the PATCH commit and return
  // a stale row) must NOT clobber the local value — that caused the 4→3→4
  // flicker on increment. Cleared by the screen on confirmed write, with a TTL
  // safety net so a dropped confirm can't pin a goal forever.
  static const _pendingGoalTtl = Duration(seconds: 8);
  final Map<String, DateTime> _pendingGoals = {};

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

  /// Call once after login. Watches the local `events` table to decide when
  /// an event is ongoing; only then does any network/Realtime work happen.
  Future<void> init(AppDatabase db, String userId) async {
    _userId = userId;
    _ongoingWatch?.cancel();
    _ongoingWatch = _watchEvents(db).listen((events) {
      _eventsSnapshot = events;
      _recomputeOngoing();
    });
    // Re-evaluate the time-driven ongoing condition even when no row changes,
    // so an event that becomes live on its own start time flips home into live
    // mode. 30s is well within the live-floor latency users expect.
    _ongoingTicker?.cancel();
    _ongoingTicker = Timer.periodic(const Duration(seconds: 30), (_) => _recomputeOngoing());
  }

  /// Force a refresh (e.g. after scanning a contact).
  Future<void> refresh() => _refresh();

  /// Emits whether any non-deleted event is ongoing right now, recomputed
  /// whenever the events table changes. Mirrors the backend's ongoing rule
  /// (events.ts getEventStatus/effectiveEnd): now in [start, end], where end is
  /// end_time, the next same-day event's start_time, or end of day.
  Stream<List<EventsTableData>> _watchEvents(AppDatabase db) {
    final query = db.select(db.eventsTable)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc)]);
    return query.watch();
  }

  /// Evaluates the ongoing condition against the latest events snapshot and
  /// routes the result through [_onOngoingChanged]. Called both when the table
  /// changes and on a periodic ticker (the condition is time-driven).
  void _recomputeOngoing() {
    final hasOngoing = _eventsSnapshot.any((e) => _isOngoing(e, _eventsSnapshot));
    _onOngoingChanged(hasOngoing);
  }

  bool _isOngoing(EventsTableData e, List<EventsTableData> all) {
    final now = DateTime.now().toUtc();
    final start = e.startDate.toUtc();
    final rangeStart = e.startTime != null ? _withTime(start, e.startTime!) : start;
    final rangeEnd = _effectiveEnd(e, all);
    return !now.isBefore(rangeStart) && !now.isAfter(rangeEnd);
  }

  // The instant an event's live window ends. Explicit end_time wins; multi-day
  // events run through their end_date end-of-day; an open-ended single-day event
  // runs until the next same-day single-day event's start_time, else end of day.
  DateTime _effectiveEnd(EventsTableData e, List<EventsTableData> all) {
    final start = e.startDate.toUtc();
    if (e.endDate != null) {
      final end = e.endDate!.toUtc();
      return DateTime.utc(end.year, end.month, end.day, 23, 59, 59, 999);
    }
    if (e.endTime != null) {
      return _withTime(start, e.endTime!);
    }
    final myStart = e.startTime != null ? _withTime(start, e.startTime!) : start;
    var boundary = DateTime.utc(start.year, start.month, start.day, 23, 59, 59, 999);
    for (final other in all) {
      if (other.id == e.id || other.endDate != null || other.startTime == null) continue;
      final os = other.startDate.toUtc();
      if (os.year != start.year || os.month != start.month || os.day != start.day) continue;
      final otherStart = _withTime(os, other.startTime!);
      // End one millisecond before the next event so the two windows never both
      // contain that instant. Mirrors the backend effectiveEnd rule.
      if (otherStart.isAfter(myStart) && !otherStart.isAfter(boundary)) {
        boundary = otherStart.subtract(const Duration(milliseconds: 1));
      }
    }
    return boundary;
  }

  // Combines an event date (UTC) with an "HH:mm" time-of-day as UTC wall-clock.
  DateTime _withTime(DateTime date, String time) {
    final parts = time.split(':');
    return DateTime.utc(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Drift watch crossed the ongoing boundary: enter or leave live mode.
  void _onOngoingChanged(bool hasOngoing) {
    if (hasOngoing == _hasOngoing) {
      // No boundary crossed, but this may still be the first emission from
      // the watch — without it, idle (never-live) accounts would never flip
      // `_initialized` and the home skeleton would spin forever.
      if (!_initialized) {
        _initialized = true;
        notifyListeners();
      }
      return;
    }
    _hasOngoing = hasOngoing;
    if (hasOngoing) {
      _enterLiveMode();
    } else {
      _leaveLiveMode();
    }
  }

  void _enterLiveMode() {
    _refresh();
    _subscribeLiveRealtime();
    // Safety net in case a Realtime socket is dropped in the background.
    _safetyTimer ??= Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
  }

  void _leaveLiveMode() {
    _teardownLiveRealtime();
    _safetyTimer?.cancel();
    _safetyTimer = null;
    _debounce?.cancel();
    _debounce = null;
    // Clear stale live state; surface the next upcoming event instead.
    _refresh();
  }

  void _subscribeLiveRealtime() {
    final userId = _userId;
    if (userId == null || _liveChannels.isNotEmpty) return;
    final client = Supabase.instance.client;
    for (final table in _liveTables) {
      final channel = client
          .channel('live:$table:user=$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (_) => _scheduleRefresh(),
          )
          .subscribe();
      _liveChannels.add(channel);
    }
  }

  void _teardownLiveRealtime() {
    for (final channel in _liveChannels) {
      channel.unsubscribe();
    }
    _liveChannels.clear();
  }

  /// Coalesces a burst of Realtime row events (e.g. several captures landing
  /// at once) into a single /live-session refresh.
  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _refresh);
  }

  Future<void> _refresh() async {
    _isLoadingLive = true;
    if (!_initialized) notifyListeners();

    try {
      final session = await ApiService.getLiveSession();
      final event = session?['event'] as Event?;

      if (event != null) {
        final liveData = session!['liveData'] as Map<String, dynamic>;
        final captures = session['captures'] as List<Map<String, dynamic>>;
        _liveEvent = event;
        _liveStats = liveData['stats'] as Map<String, dynamic>?;
        _liveGoals = _mergePendingGoals(
          List<Map<String, dynamic>>.from(liveData['goals'] as List? ?? []),
        );
        _liveTargets = List<Map<String, dynamic>>.from(liveData['targets'] as List? ?? []);
        _targetContacts = List<Map<String, dynamic>>.from(liveData['target_contacts'] as List? ?? []);
        _scannedContacts = captures;
        _nextEvent = null;
      } else {
        _liveEvent = null;
        _liveStats = null;
        _liveGoals = [];
        _liveTargets = [];
        _targetContacts = [];
        _scannedContacts = [];
        _nextEvent = session?['nextEvent'] as Event?;
      }
    } catch (_) {
      _liveEvent = null;
      _liveStats = null;
      _liveGoals = [];
      _liveTargets = [];
      _targetContacts = [];
      _scannedContacts = [];
      _nextEvent = null;
    }

    _isLoadingLive = false;
    _initialized = true;
    notifyListeners();
  }

  /// Overlays the locally-held value for any goal with an in-flight optimistic
  /// edit onto a freshly-fetched goal list, so a refresh that raced ahead of
  /// the PATCH commit can't revert it. Expired pending entries (TTL) are
  /// dropped so a lost confirm can't pin a goal indefinitely.
  List<Map<String, dynamic>> _mergePendingGoals(List<Map<String, dynamic>> fetched) {
    if (_pendingGoals.isEmpty) return fetched;
    final now = DateTime.now();
    _pendingGoals.removeWhere((_, t) => now.difference(t) > _pendingGoalTtl);
    if (_pendingGoals.isEmpty) return fetched;
    return [
      for (final g in fetched)
        if (!_pendingGoals.containsKey(g['id']))
          g
        else ...[
          () {
            final local = _liveGoals.firstWhere((l) => l['id'] == g['id'], orElse: () => g);
            // The server has caught up to our optimistic value — the write
            // committed, so stop guarding this goal and accept the fetched row.
            if (g['current'] == local['current']) {
              _pendingGoals.remove(g['id']);
              return g;
            }
            return local;
          }(),
        ],
    ];
  }

  // ── Mutable operations forwarded from screens ─────────────────────────────

  void updateGoalLocally(Map<String, dynamic> updated) {
    final idx = _liveGoals.indexWhere((g) => g['id'] == updated['id']);
    if (idx != -1) {
      _pendingGoals[updated['id'] as String] = DateTime.now();
      _liveGoals = List.from(_liveGoals)..[idx] = updated;
      notifyListeners();
    }
  }

  void revertGoal(Map<String, dynamic> original) {
    _pendingGoals.remove(original['id']);
    updateGoalLocally(original);
    _pendingGoals.remove(original['id']);
  }

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
    _ongoingWatch?.cancel();
    _ongoingTicker?.cancel();
    _safetyTimer?.cancel();
    _debounce?.cancel();
    _teardownLiveRealtime();
    super.dispose();
  }
}
