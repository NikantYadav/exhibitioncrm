import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../db/app_database.dart';
import '../services/api_service.dart';
import '../services/company_name_resolver.dart';
import '../repositories/captures_repository.dart';
import '../repositories/companies_repository.dart';
import '../repositories/contact_events_repository.dart';
import '../repositories/contacts_repository.dart';
import '../repositories/email_drafts_repository.dart';
import '../repositories/event_goals_repository.dart';
import '../repositories/events_repository.dart';
import '../repositories/interactions_repository.dart';
import '../repositories/follow_ups_repository.dart';
import '../repositories/target_company_met_repository.dart';
import '../repositories/synced_repository.dart';
import '../repositories/target_companies_repository.dart';

/// Owns the local drift database and every synced repository. Wired into
/// [MultiProvider] in main.dart as a singleton, same lifetime as the app.
///
/// Lifecycle (driven by AuthProvider's auth-state listener in main.dart, the
/// same pattern LiveEventProvider uses):
///   - [start] on login/resume-with-session: runs catchUp on every repo, then
///     opens a single private Broadcast channel for realtime wake-up pokes.
///   - [stop] on logout: closes the channel and wipes the local cache so a
///     different login on the same device can't read stale rows.
///   - [resume] on app foreground: re-runs catchUp to backfill anything
///     missed while the socket was suspended (mobile OSes can drop socket
///     connections in the background).
class SyncProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AppDatabase db = AppDatabase();

  late final EventsRepository events = EventsRepository(db);
  late final ContactsRepository contacts = ContactsRepository(db);
  late final CapturesRepository captures = CapturesRepository(db);
  late final TargetCompaniesRepository targetCompanies = TargetCompaniesRepository(db);
  late final ContactEventsRepository contactEvents = ContactEventsRepository(db);
  late final EventGoalsRepository eventGoals = EventGoalsRepository(db);
  late final EmailDraftsRepository emailDrafts = EmailDraftsRepository(db);
  late final InteractionsRepository interactions = InteractionsRepository(db);
  late final FollowUpsRepository followUps = FollowUpsRepository(db);
  late final TargetCompanyMetRepository targetCompanyMet = TargetCompanyMetRepository(db);
  late final CompaniesRepository companies = CompaniesRepository(db);

  late final List<SyncedRepository> _realtimeRepos = [
    events,
    contacts,
    captures,
    targetCompanies,
    contactEvents,
    eventGoals,
    emailDrafts,
    interactions,
    followUps,
    targetCompanyMet,
  ];

  bool _started = false;
  String? _userId;

  RealtimeChannel? _syncChannel;
  Timer? _broadcastDebounce;

  /// Optional listener notified on each (debounced) sync poke, after catchUpAll
  /// runs. LiveEventProvider sets this to refresh the live aggregate, so the
  /// live floor reacts to the SAME broadcast as the rest of sync — no separate
  /// realtime channels needed during a live event.
  VoidCallback? onSyncPoke;

  SyncProvider() {
    WidgetsBinding.instance.addObserver(this);
    // Let the direct-API company-name resolver persist fetched rows locally.
    CompanyNameResolver.repo = companies;
  }

  /// Runs catchUp on every repository (companies first, since contacts and
  /// target_companies embed company data the UI may want immediately) and
  /// opens the single private Broadcast channel for realtime wake-up pokes.
  /// Safe to call again for the same user (e.g. on resume) — catchUp is idempotent.
  Future<void> start(String userId) async {
    _userId = userId;
    await catchUpAll();
    if (!_started) {
      _subscribeSyncBroadcast(userId);
      _started = true;
    }
  }

  /// Re-syncs without touching the Broadcast channel — call on app resume.
  Future<void> resume() async {
    if (_userId == null) return;
    await catchUpAll();
  }

  /// Fetches every synced table (plus `companies`) in a single `/sync`
  /// request and distributes each table's delta to its repository. Replaces
  /// the old per-repo loop that fired one HTTP request per table.
  ///
  /// One request needs one `since`. Each table keeps its own watermark in
  /// `sync_state`; we use the oldest across all tables so none misses a
  /// change. Tables already past that point harmlessly re-receive a few rows
  /// — `_upsertOne`'s last-write-wins guard drops anything not newer.
  Future<void> catchUpAll() async {
    final watermarks = await Future.wait([
      companies.lastSyncedAt(),
      ..._realtimeRepos.map((r) => r.lastSyncedAt()),
    ]);

    // Oldest watermark; null (never synced) forces a full pull from epoch 0.
    String? since;
    if (!watermarks.contains(null)) {
      since = watermarks.whereType<String>().reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    }

    final tables = [..._realtimeRepos.map((r) => r.tableName), companies.tableName].join(',');

    // Keyset-paginated drain. The backend caps each table per response and
    // reports `has_more` + a `next_since` cursor. We apply each page's rows
    // immediately (so the UI fills in progressively, most-recently-updated rows
    // first), advance `since` to the cursor, and loop until drained. The local
    // watermark (`server_time`) is committed ONLY on the final page — committing
    // it mid-drain would skip every row between the last paged row and now.
    //
    // A first full sync drives this; steady-state deltas finish in one pass
    // (has_more=false), so this is a no-op overhead for them. `_safetyCap` only
    // guards against a misbehaving server looping forever.
    const safetyCap = 1000;
    for (var page = 0; page < safetyCap; page++) {
      final response = await ApiService.getSyncDelta(since: since, tables: tables);
      final serverTime = response['server_time'] as String;
      final hasMore = response['has_more'] == true;
      final data = response['data'] as Map<String, dynamic>;

      // Mid-drain pages advance `since` by the cursor without committing the
      // watermark; the final page commits server_time as the durable watermark.
      final watermark = hasMore ? null : serverTime;

      for (final repo in _realtimeRepos) {
        await repo.applyTableDelta(data[repo.tableName] as Map<String, dynamic>?);
        if (watermark != null) { await repo.storeLastSyncedAt(watermark); }
      }
      await companies.applyTableDelta(data[companies.tableName] as Map<String, dynamic>?);
      if (watermark != null) { await companies.storeLastSyncedAt(watermark); }

      if (!hasMore) break;
      since = response['next_since'] as String;
    }
  }

  /// Single private Broadcast channel carrying per-user "table changed" pokes
  /// emitted by the public.broadcast_sync_change() DB trigger. On any poke we
  /// run the existing catchUpAll() delta-sync (debounced) — Realtime is only a
  /// wake-up signal, not the data path. Replaces the 10 postgres_changes channels.
  void _subscribeSyncBroadcast(String userId) {
    final client = Supabase.instance.client;
    // Hand the current JWT to the realtime socket so the realtime.messages
    // RLS policy can evaluate auth.uid().
    final token = client.auth.currentSession?.accessToken;
    if (token != null) {
      client.realtime.setAuth(token);
    }
    _syncChannel?.unsubscribe();
    _syncChannel = client
        .channel(
          'sync:user=$userId',
          opts: const RealtimeChannelConfig(private: true),
        )
        .onBroadcast(
          event: 'sync',
          callback: (_) => _scheduleBroadcastCatchUp(),
        )
        .subscribe();
  }

  /// Coalesces a burst of pokes (e.g. a multi-row write) into one catchUpAll.
  void _scheduleBroadcastCatchUp() {
    _broadcastDebounce?.cancel();
    _broadcastDebounce = Timer(const Duration(milliseconds: 400), () async {
      await catchUpAll();
      onSyncPoke?.call();
    });
  }

  /// Closes the Broadcast channel and wipes the local cache. Call on logout.
  Future<void> stop() async {
    _broadcastDebounce?.cancel();
    await _syncChannel?.unsubscribe();
    _syncChannel = null;
    for (final repo in _realtimeRepos) {
      await repo.dispose();
    }
    _started = false;
    _userId = null;
    await db.wipeAll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _broadcastDebounce?.cancel();
    _syncChannel?.unsubscribe();
    for (final repo in _realtimeRepos) {
      repo.dispose();
    }
    db.close();
    super.dispose();
  }
}
