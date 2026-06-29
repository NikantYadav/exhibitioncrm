import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../db/app_database.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../services/offline/connectivity_service.dart';

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
  List<Map<String, dynamic>> _liveGoals = [];
  List<Map<String, dynamic>> _liveTargets = [];
  List<Map<String, dynamic>> _targetContacts = [];
  List<Map<String, dynamic>> _scannedContacts = [];

  bool _isLoadingLive = false;
  bool _initialized = false;

  // Idle gate: a drift watch on `events` decides whether anything is ongoing.
  AppDatabase? _db;
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

  // Live mode: debounce + a slow safety-net poll.
  // Realtime wake-up is now driven by SyncProvider's single broadcast channel
  // via [onSyncPoke] — no per-table postgres_changes channels needed here.
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
    _db = db;
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
    // Safety net in case the socket is dropped in the background.
    // Realtime wake-up comes via SyncProvider.onSyncPoke (see main.dart wiring).
    _safetyTimer ??= Timer.periodic(const Duration(seconds: 60), (_) => _refresh());
  }

  void _leaveLiveMode() {
    _safetyTimer?.cancel();
    _safetyTimer = null;
    _debounce?.cancel();
    _debounce = null;
    // Clear stale live state; surface the next upcoming event instead.
    _refresh();
  }

  /// Called by SyncProvider on every debounced sync poke (after catchUpAll).
  /// Only triggers a live refresh when an event is actually ongoing so idle
  /// accounts do not fire /live-session on every unrelated table write.
  void onSyncPoke() {
    if (_hasOngoing) { _scheduleRefresh(); }
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

    // Offline (or a cold launch with no network): the /live-session endpoint is
    // unreachable, so assemble the live session from the locally-synced drift
    // tables instead of clearing state and bouncing home. The events table
    // already tells us which event is ongoing (that drives _hasOngoing), so we
    // can rebuild the same aggregate the screen reads.
    if (!ConnectivityService().isOnline) {
      await _refreshFromLocal();
      return;
    }

    try {
      final session = await ApiService.getLiveSession();
      final event = session?['event'] as Event?;

      if (event != null) {
        final liveData = session!['liveData'] as Map<String, dynamic>;
        final captures = session['captures'] as List<Map<String, dynamic>>;
        _liveEvent = event;
        _liveGoals = _mergePendingGoals(
          List<Map<String, dynamic>>.from(liveData['goals'] as List? ?? []),
        );
        _liveTargets = List<Map<String, dynamic>>.from(liveData['targets'] as List? ?? []);
        _targetContacts = List<Map<String, dynamic>>.from(liveData['target_contacts'] as List? ?? []);
        _scannedContacts = captures;
        _nextEvent = null;
      } else {
        _liveEvent = null;

        _liveGoals = [];
        _liveTargets = [];
        _targetContacts = [];
        _scannedContacts = [];
        _nextEvent = session?['nextEvent'] as Event?;
      }
    } catch (_) {
      // The request failed despite reporting online (flaky connection, server
      // error). If an event is ongoing per the local events table, fall back to
      // the local aggregate rather than clearing the live floor.
      if (_hasOngoing) {
        await _refreshFromLocal();
        return;
      }
      _liveEvent = null;
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

  /// Builds the live session from the local drift tables — the offline / failed
  /// -request path. Mirrors the shape the backend /live-session returns (see
  /// events.ts) so [LiveHomeScreen] reads it identically. Per-user company
  /// `met` state lives only on the server (target_company_met), so offline
  /// targets surface as not-met; the screen's local overrides still apply.
  Future<void> _refreshFromLocal() async {
    final db = _db;
    if (db == null) {
      _isLoadingLive = false;
      _initialized = true;
      notifyListeners();
      return;
    }

    try {
      final ongoing = _eventsSnapshot
          .where((e) => _isOngoing(e, _eventsSnapshot))
          .toList();
      if (ongoing.isEmpty) {
        _liveEvent = null;

        _liveGoals = [];
        _liveTargets = [];
        _targetContacts = [];
        _scannedContacts = [];
        _nextEvent = null;
        _isLoadingLive = false;
        _initialized = true;
        notifyListeners();
        return;
      }

      final eventRow = ongoing.first;
      final eventId = eventRow.id;
      _liveEvent = Event.fromDrift(eventRow);

      // Goals.
      final goalRows = await (db.select(db.eventGoalsTable)
            ..where((t) => t.eventId.equals(eventId) & t.deletedAt.isNull()))
          .get();
      _liveGoals = _mergePendingGoals([
        for (final g in goalRows)
          {'id': g.id, 'label': g.label, 'current': g.current, 'total': g.total},
      ]);

      // Per-user "met" flags for this event's company targets (synced table).
      final metRows = await (db.select(db.targetCompanyMetTable)
            ..where((t) => t.eventId.equals(eventId) & t.deletedAt.isNull()))
          .get();
      final metByTarget = {
        for (final r in metRows)
          if (r.targetId != null) r.targetId!: r.met,
      };

      // Target companies (joined with company name).
      final targetJoin = await (db.select(db.targetCompaniesTable).join([
        leftOuterJoin(db.companiesTable,
            db.companiesTable.id.equalsExp(db.targetCompaniesTable.companyId)),
      ])
            ..where(db.targetCompaniesTable.eventId.equals(eventId) &
                db.targetCompaniesTable.deletedAt.isNull()))
          .get();
      _liveTargets = [
        for (final row in targetJoin)
          () {
            final t = row.readTable(db.targetCompaniesTable);
            final co = row.readTableOrNull(db.companiesTable);
            return <String, dynamic>{
              'id': t.id,
              'company_id': t.companyId,
              'company_name': co?.name ?? '',
              'booth': t.boothLocation ?? '',
              'status': t.status,
              'priority': t.priority,
              'talking_points': t.talkingPoints ?? '',
              'notes': t.notes ?? '',
              'use_notes_for_briefing': t.useNotesForBriefing,
              'met': metByTarget[t.id] ?? false,
            };
          }(),
      ];

      // Target contacts (contact_events joined with contact + company).
      final contactJoin = await (db.select(db.contactEventsTable).join([
        leftOuterJoin(db.contactsTable,
            db.contactsTable.id.equalsExp(db.contactEventsTable.contactId)),
        leftOuterJoin(db.companiesTable,
            db.companiesTable.id.equalsExp(db.contactsTable.companyId)),
      ])
            ..where(db.contactEventsTable.eventId.equals(eventId) &
                db.contactEventsTable.deletedAt.isNull()))
          .get();
      _targetContacts = [
        for (final row in contactJoin)
          if (row.readTableOrNull(db.contactsTable)?.deletedAt == null)
            () {
              final ce = row.readTable(db.contactEventsTable);
              final c = row.readTableOrNull(db.contactsTable);
              final co = row.readTableOrNull(db.companiesTable);
              return <String, dynamic>{
                'id': ce.id,
                'contact_id': ce.contactId,
                'name': c != null
                    ? '${c.firstName} ${c.lastName ?? ''}'.trim()
                    : '',
                'job_title': c?.jobTitle ?? '',
                'company_name': co?.name ?? '',
                'status': ce.status,
                'notes': ce.notes ?? '',
                'talking_points': ce.talkingPoints ?? '',
              };
            }(),
      ];

      // Scanned captures (completed, with a linked contact), joined with
      // contact + company — mirrors the /live-session captures shape.
      final captureJoin = await (db.select(db.capturesTable).join([
        leftOuterJoin(db.contactsTable,
            db.contactsTable.id.equalsExp(db.capturesTable.contactId)),
        leftOuterJoin(db.companiesTable,
            db.companiesTable.id.equalsExp(db.contactsTable.companyId)),
      ])
            ..where(db.capturesTable.eventId.equals(eventId) &
                db.capturesTable.deletedAt.isNull()))
          .get();
      _scannedContacts = [
        for (final row in captureJoin)
          () {
            final cap = row.readTable(db.capturesTable);
            final c = row.readTableOrNull(db.contactsTable);
            final co = row.readTableOrNull(db.companiesTable);
            return <String, dynamic>{
              'id': cap.id,
              'created_at': cap.createdAt?.toIso8601String(),
              'status': cap.status,
              'extracted_data': cap.extractedDataJson != null
                  ? jsonDecode(cap.extractedDataJson!)
                  : null,
              'contact': (c == null || c.deletedAt != null)
                  ? null
                  : <String, dynamic>{
                      'id': c.id,
                      'first_name': c.firstName,
                      'last_name': c.lastName,
                      'job_title': c.jobTitle,
                      'email': c.email,
                      'phone': c.phone,
                      'company_name': co?.name ?? '',
                    },
            };
          }(),
      ];

      _nextEvent = null;
    } catch (_) {
      // Local read failed — leave any existing state untouched rather than
      // wiping a working live floor.
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

  /// Per-user "met" toggle for a company target (live optimistic update).
  void updateTargetCompanyMetLocally(String targetId, bool met) {
    final idx = _liveTargets.indexWhere((t) => t['id'] == targetId);
    if (idx != -1) {
      final updated = List<Map<String, dynamic>>.from(_liveTargets);
      updated[idx] = {...updated[idx], 'met': met};
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
    super.dispose();
  }
}
