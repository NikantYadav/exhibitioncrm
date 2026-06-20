import 'package:flutter/widgets.dart';

import '../db/app_database.dart';
import '../repositories/captures_repository.dart';
import '../repositories/companies_repository.dart';
import '../repositories/contact_events_repository.dart';
import '../repositories/contacts_repository.dart';
import '../repositories/email_drafts_repository.dart';
import '../repositories/event_goals_repository.dart';
import '../repositories/events_repository.dart';
import '../repositories/interactions_repository.dart';
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
  ];

  bool _started = false;
  String? _userId;

  SyncProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Runs catchUp on every repository (companies first, since contacts and
  /// target_companies embed company data the UI may want immediately) and
  /// opens Realtime subscriptions for the given user. Safe to call again for
  /// the same user (e.g. on resume) — catchUp is idempotent.
  Future<void> start(String userId) async {
    _userId = userId;
    await companies.catchUp();
    for (final repo in _realtimeRepos) {
      await repo.catchUp();
    }
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
    await companies.catchUp();
    for (final repo in _realtimeRepos) {
      await repo.catchUp();
    }
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
