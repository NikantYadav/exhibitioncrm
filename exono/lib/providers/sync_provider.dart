import 'package:flutter/widgets.dart';

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
///     opens Realtime subscriptions.
///   - [stop] on logout: closes Realtime subscriptions and wipes the local
///     cache so a different login on the same device can't read stale rows.
///   - [resume] on app foreground: re-runs catchUp to backfill anything
///     missed while Realtime was suspended (mobile OSes can drop socket
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

  SyncProvider() {
    WidgetsBinding.instance.addObserver(this);
    // Let the direct-API company-name resolver persist fetched rows locally.
    CompanyNameResolver.repo = companies;
  }

  /// Runs catchUp on every repository (companies first, since contacts and
  /// target_companies embed company data the UI may want immediately) and
  /// opens Realtime subscriptions for the given user. Safe to call again for
  /// the same user (e.g. on resume) — catchUp is idempotent.
  Future<void> start(String userId) async {
    _userId = userId;
    await catchUpAll();
    if (!_started) {
      for (final repo in _realtimeRepos) {
        repo.subscribeRealtime(userId);
      }
      _started = true;
    }
  }

  /// Re-syncs without touching Realtime subscriptions — call on app resume.
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
    final response = await ApiService.getSyncDelta(since: since, tables: tables);
    final serverTime = response['server_time'] as String;
    final data = response['data'] as Map<String, dynamic>;

    for (final repo in _realtimeRepos) {
      await repo.applyTableDelta(data[repo.tableName] as Map<String, dynamic>?);
      await repo.storeLastSyncedAt(serverTime);
    }
    await companies.applyTableDelta(data[companies.tableName] as Map<String, dynamic>?);
    await companies.storeLastSyncedAt(serverTime);
  }

  /// Closes Realtime subscriptions and wipes the local cache. Call on logout.
  Future<void> stop() async {
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
    for (final repo in _realtimeRepos) {
      repo.dispose();
    }
    db.close();
    super.dispose();
  }
}
