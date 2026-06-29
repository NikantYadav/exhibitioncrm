import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/safe_area_insets.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/event.dart';
import '../providers/auth_provider.dart';
import '../providers/live_event_provider.dart';
import '../providers/offline_provider.dart';
import '../providers/sync_provider.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_header.dart';
import '../widgets/app_section_label.dart';
import '../widgets/skeleton_loader.dart';
import 'event_follow_ups_screen.dart';
import 'log_interaction_screen.dart';
import 'pre_event_prep_screen.dart';
import 'sync_issues_screen.dart';
import '../utils/screen_logger.dart';

class HomeDefaultScreen extends StatefulWidget {
  const HomeDefaultScreen({super.key});

  @override
  State<HomeDefaultScreen> createState() => _HomeDefaultScreenState();
}

class _HomeDefaultScreenState extends State<HomeDefaultScreen> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  List<Event> _upcomingEvents = [];
  bool _eventsLoaded = false;

  int? _followUpsDue;

  StreamSubscription? _eventsSub;
  StreamSubscription? _dueSub;

  @override
  void initState() {
    super.initState();
    captureReturnSignalHome.addListener(_onCaptureReturn);
    _subscribeUpcomingEvents();
    _subscribeDueCount();
  }

  // ValueNotifier used to refresh live data after capture
  static final ValueNotifier<int> captureReturnSignalHome = ValueNotifier<int>(0);

  void _onCaptureReturn() {
    context.read<LiveEventProvider>().refresh();
  }

  @override
  void dispose() {
    captureReturnSignalHome.removeListener(_onCaptureReturn);
    _eventsSub?.cancel();
    _dueSub?.cancel();
    super.dispose();
  }

  // The local follow_ups drift stream is the single source of truth for the
  // "Follow-ups Due" stat: it updates the moment an interaction syncs, with no
  // reload, and (unlike the old dashboard API seed) excludes follow-ups on
  // soft-deleted contacts — so the number never flips between two definitions.
  // Pull-to-refresh triggers sync.resume(), which re-pulls follow_ups and the
  // stream re-emits the fresh count automatically.
  void _subscribeDueCount() {
    _dueSub = context.read<SyncProvider>().followUps.watchDueCount().listen((count) {
      if (mounted) setState(() => _followUpsDue = count);
    });
  }

  void _openEvent(Event event) {
    if (event.status == 'ongoing') {
      context.read<LiveEventProvider>().refresh();
      context.go('/live-event');
    } else if (event.status == 'completed') {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => EventFollowUpsScreen(event: event)),
      );
    } else {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => PreEventPrepScreen(event: event)),
      );
    }
  }

  void _subscribeUpcomingEvents() {
    bool firstEmission = true;
    _eventsSub = context.read<SyncProvider>().events.watchAll().listen((rows) {
      if (!mounted) return;
      final all = eventsWithLiveStatus(rows.map(Event.fromDrift).toList());
      final upcoming = all
          .where((e) => e.status == 'upcoming')
          .toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate));
      // Skip only the first emission when the local cache is still completely
      // empty (fires before sync pulls anything). Gate on whether ANY events
      // exist — not on `upcoming` — so a user whose events are all ongoing or
      // past still resolves to "no upcoming events" instead of loading forever.
      if (firstEmission && rows.isEmpty) {
        firstEmission = false;
        return;
      }
      firstEmission = false;
      setState(() {
        _upcomingEvents = upcoming.take(3).toList();
        _eventsLoaded = true;
      });
    });
  }


  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final lep = context.watch<LiveEventProvider>();
    final auth = context.watch<AuthProvider>();
    final firstName = auth.displayName.trim().split(RegExp(r'\s+')).first;

    return ColoredBox(
      color: context.theme.colors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              showNotifications: true,
            ),
            // While live status is resolving, show a skeleton to avoid flash
            if (!lep.initialized)
              Expanded(child: _buildSkeleton())
            else
              Expanded(
                child: RefreshIndicator(
                  color: _c.accent,
                  backgroundColor: context.theme.colors.background,
                  onRefresh: () async {
                    final offline = context.read<OfflineProvider>();
                    final sync = context.read<SyncProvider>();
                    // Re-verify connectivity first so the offline/sync badge
                    // updates immediately on pull-to-refresh.
                    await offline.recheckConnectivity();
                    await Future.wait([
                      lep.refresh(),
                      sync.resume(),
                    ]);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 20, 16, bottomScrollInset(context)),
                    child: lep.isLive
                        ? _buildLiveHome(lep, firstName)
                        : _buildTraditionalHome(lep, firstName),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Skeleton shown while live status is resolving ─────────────────────────

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 20, 16, bottomScrollInset(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(width: 220, height: 28, borderRadius: BorderRadius.circular(6)),
          const SizedBox(height: 10),
          SkeletonLoader(width: 160, height: 14, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 28),
          SkeletonLoader(width: double.infinity, height: 52, borderRadius: BorderRadius.circular(12)),
          const SizedBox(height: 28),
          SkeletonLoader(width: 120, height: 11, borderRadius: BorderRadius.circular(3)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: SkeletonLoader(width: double.infinity, height: 72, borderRadius: BorderRadius.circular(12))),
            const SizedBox(width: 12),
            Expanded(child: SkeletonLoader(width: double.infinity, height: 72, borderRadius: BorderRadius.circular(12))),
          ]),
          const SizedBox(height: 28),
          SkeletonLoader(width: 120, height: 11, borderRadius: BorderRadius.circular(3)),
          const SizedBox(height: 12),
          SkeletonLoader(width: double.infinity, height: 80, borderRadius: BorderRadius.circular(16)),
        ],
      ),
    );
  }

  // ── Live home: live hero at top, traditional below ────────────────────────

  Widget _buildLiveHome(LiveEventProvider lep, String firstName) {
    final event = lep.liveEvent!;
    final location = event.location ?? '';
    final scanned = lep.scannedContacts.length;
    final companiesLeft = lep.liveTargets.where((t) => !(t['met'] as bool? ?? false)).length;
    final contactsLeft = lep.targetContacts.where((t) => (t['status'] as String?) != 'met').length;
    final targetsLeft = companiesLeft + contactsLeft;
    final goalsLeft = lep.liveGoals.where((g) {
      final current = g['current'] as int;
      final total = g['total'] as int;
      return total == 0 ? current != 1 : current < total;
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Live banner ──
        _buildLiveBanner(event, location),
        const SizedBox(height: 12),

        // ── Log interaction (auto-links to the live event in the sheet) ──
        AppButton(
          label: 'LOG INTERACTION',
          prefixIcon: const Icon(Icons.add_circle_outline_rounded, size: 20),
          variant: ButtonVariant.branded,
          fullWidth: true,
          onPressed: () => showLogInteractionSheet(context),
        ),
        const SizedBox(height: 12),

        // ── Stat strip ──
        _buildStatStrip(scanned, targetsLeft, goalsLeft),
        const SizedBox(height: 20),

        // ── Goals (compact) ──
        if (lep.liveGoals.isNotEmpty) ...[
          _buildGoalsCompact(lep),
          const SizedBox(height: 20),
        ],

        // ── CTA: go to full live floor ──
        AppButton(
          label: 'OPEN LIVE FLOOR',
          prefixIcon: const Icon(Icons.open_in_full_rounded, size: 16, color: Colors.white),
          variant: ButtonVariant.primary,
          fullWidth: true,
          onPressed: () => context.push('/live-event'),
        ),

        // ── Divider between live and traditional ──
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(children: [
            Expanded(child: Container(height: 1, color: context.theme.colors.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('BACK AT BASE', style: context.theme.typography.xs.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.4, color: context.theme.colors.mutedForeground)),
            ),
            Expanded(child: Container(height: 1, color: context.theme.colors.border)),
          ]),
        ),

        // ── Traditional home (condensed) ──
        _buildTraditionalHome(lep, firstName, condensed: true),
      ],
    );
  }

  // ── Traditional home ──────────────────────────────────────────────────────

  Widget _buildTraditionalHome(LiveEventProvider lep, String firstName, {bool condensed = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!condensed) ...[
          Text(
            '${_greeting()}, $firstName',
            style: context.theme.typography.xl2.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.0, color: context.theme.colors.foreground, height: 1.1),
          ),
          const SizedBox(height: 28),
          AppButton(
            label: 'LOG INTERACTION',
            prefixIcon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            variant: ButtonVariant.branded,
            fullWidth: true,
            onPressed: () => showLogInteractionSheet(context),
          ),
          const SizedBox(height: 28),
        ],

        // Sync status (only shown when there's offline activity)
        const _SyncSection(),

        // Priorities
        AppSectionLabel("Today's Priorities"),
        const SizedBox(height: 12),
        if (_followUpsDue == null)
          _buildPriorityTileSkeleton()
        else
          _buildPriorityTile(
            icon: Icons.schedule_rounded,
            value: '$_followUpsDue',
            label: 'Follow-ups Due',
            onTap: () => context.go('/follow-ups'),
          ),
        const SizedBox(height: 28),

        // Upcoming events
        AppSectionLabel('Upcoming Events'),
        const SizedBox(height: 12),
        if (!_eventsLoaded)
          _buildEventsPlaceholder()
        else if (_upcomingEvents.isEmpty)
          _buildNoEventsCard()
        else
          ..._upcomingEvents.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildUpcomingEventCard(e),
          )),
      ],
    );
  }

  // ── Live banner ───────────────────────────────────────────────────────────

  Widget _buildLiveBanner(Event event, String location) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: AppTheme.radiusCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _PulsingDot(color: _c.destructive),
            const SizedBox(width: 8),
            Text('LIVE NOW', style: context.theme.typography.xs.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.6, color: _c.destructive)),
          ]),
          const SizedBox(height: 14),
          Text(event.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.theme.typography.xl.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6, color: context.theme.colors.foreground, height: 1.1)),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.location_on_outlined, size: 14, color: _c.accent),
              const SizedBox(width: 6),
              Expanded(child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground))),
            ]),
          ],
          if (event.localStartTime != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.schedule_outlined, size: 14, color: _c.accent),
              const SizedBox(width: 6),
              Text(
                event.localEndTime != null
                    ? '${event.localStartTime} – ${event.localEndTime}'
                    : 'From ${event.localStartTime}',
                style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  // ── Stat strip ────────────────────────────────────────────────────────────

  Widget _buildStatStrip(int scanned, int targetsLeft, int goalsLeft) {
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(16),
      radius: 14,
      child: LayoutBuilder(builder: (context, constraints) {
        // One shared font size for all three labels so they render
        // identically and each fits on a single line. Sized off the
        // longest label against the per-column width (≈1/3 of the card,
        // minus the two 1px dividers).
        const labels = ['SCANNED', 'TARGETS LEFT', 'GOALS LEFT'];
        final cellWidth = (constraints.maxWidth - 2) / 3;
        final labelStyle = context.theme.typography.xs.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: context.theme.colors.mutedForeground);
        var fontSize = labelStyle.fontSize ?? 11;
        for (final label in labels) {
          while (fontSize > 6 &&
              _textWidth(label, labelStyle.copyWith(fontSize: fontSize)) >
                  cellWidth) {
            fontSize -= 0.5;
          }
        }
        final scaledStyle = labelStyle.copyWith(fontSize: fontSize);
        return Row(children: [
          Expanded(child: _statCol(Icons.qr_code_scanner_rounded, '$scanned', 'SCANNED', scaledStyle)),
          Container(width: 1, height: 48, color: context.theme.colors.border.withValues(alpha: 0.3)),
          Expanded(child: _statCol(Icons.people_outline_rounded, '$targetsLeft', 'TARGETS LEFT', scaledStyle)),
          Container(width: 1, height: 48, color: context.theme.colors.border.withValues(alpha: 0.3)),
          Expanded(child: _statCol(Icons.flag_outlined, '$goalsLeft', 'GOALS LEFT', scaledStyle)),
        ]);
      }),
    );
  }

  double _textWidth(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  Widget _statCol(IconData icon, String value, String label, TextStyle labelStyle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: _c.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: _c.accent),
          ),
          const SizedBox(height: 6),
          Text(value, style: context.theme.typography.xl.copyWith(fontWeight: FontWeight.w800, color: context.theme.colors.foreground, height: 1)),
          const SizedBox(height: 3),
          Text(label, style: labelStyle, textAlign: TextAlign.center, maxLines: 1, softWrap: false, overflow: TextOverflow.visible),
        ],
      ),
    );
  }

  // ── Goals compact ─────────────────────────────────────────────────────────

  Widget _buildGoalsCompact(LiveEventProvider lep) {
    final goals = lep.liveGoals.take(3).toList();
    final done = goals.where((g) {
      final current = g['current'] as int;
      final total = g['total'] as int;
      return total == 0 ? current == 1 : current >= total;
    }).length;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            AppSectionLabel('Goal Progress'),
            const Spacer(),
            Text('$done / ${goals.length}', style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w700, color: _c.accent)),
          ]),
          const SizedBox(height: 10),
          for (final goal in goals) _buildGoalRow(goal),
          if (lep.liveGoals.length > 3) ...[
            const SizedBox(height: 6),
            Text('+${lep.liveGoals.length - 3} more', style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground)),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalRow(Map<String, dynamic> goal) {
    final current = goal['current'] as int;
    final total = goal['total'] as int;
    final isCheckbox = total == 0;
    final isComplete = isCheckbox ? current == 1 : (total > 0 && current >= total);
    final progress = (!isCheckbox && total > 0) ? (current / total).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isComplete ? _c.success : Colors.transparent,
            border: Border.all(color: isComplete ? _c.success : context.theme.colors.border, width: 1.5),
          ),
          child: isComplete ? Icon(Icons.check_rounded, size: 9, color: _c.isDark ? context.theme.colors.foreground : context.theme.colors.background) : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(goal['label'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w500, color: isComplete ? context.theme.colors.mutedForeground : context.theme.colors.foreground,
                  decoration: isComplete ? TextDecoration.lineThrough : null, decorationColor: context.theme.colors.mutedForeground)),
              if (!isCheckbox) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(value: progress),
                ),
              ],
            ],
          ),
        ),
        if (!isCheckbox) ...[
          const SizedBox(width: 10),
          Text('$current/$total', style: context.theme.typography.xs.copyWith(fontWeight: FontWeight.w700, color: isComplete ? _c.success : _c.accent)),
        ],
      ]),
    );
  }

  // ── Priority tiles ────────────────────────────────────────────────────────

  Widget _buildPriorityTileSkeleton() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 12,
      child: Row(children: [
        SkeletonLoader(width: 40, height: 40, borderRadius: BorderRadius.circular(10)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SkeletonLoader(width: 48, height: 24, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 6),
          SkeletonLoader(width: 100, height: 11, borderRadius: BorderRadius.circular(4)),
        ])),
      ]),
    );
  }

  Widget _buildPriorityTile({required IconData icon, required String value, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(16),
        radius: 12,
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _c.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: _c.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: context.theme.typography.xl2.copyWith(fontWeight: FontWeight.w700, color: context.theme.colors.foreground, height: 1)),
                const SizedBox(height: 4),
                Text(label, style: context.theme.typography.xs.copyWith(fontWeight: FontWeight.w600, color: context.theme.colors.mutedForeground)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: _c.accent),
        ]),
      ),
    );
  }

  // ── Upcoming events ───────────────────────────────────────────────────────

  Widget _buildUpcomingEventCard(Event event) {
    final months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    final localStart = event.localStartDate;
    final month = months[localStart.month - 1];
    final day = localStart.day.toString();
    final location = event.location ?? '';

    return GestureDetector(
      onTap: () => _openEvent(event),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        radius: 12,
        child: Row(children: [
          Container(
            width: 52,
            padding: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(border: Border(right: BorderSide(color: context.theme.colors.border))),
            child: Column(children: [
              Text(month, style: context.theme.typography.xs.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.0, color: context.theme.colors.mutedForeground)),
              const SizedBox(height: 4),
              Text(day, maxLines: 1, softWrap: false, overflow: TextOverflow.visible, style: context.theme.typography.xl2.copyWith(fontWeight: FontWeight.w700, color: context.theme.colors.foreground, height: 1)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w700, color: context.theme.colors.foreground)),
                if (event.localTimeRange != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.schedule_outlined, size: 12, color: _c.accent),
                    const SizedBox(width: 4),
                    Text(event.localTimeRange!, style: context.theme.typography.xs.copyWith(fontWeight: FontWeight.w500, color: context.theme.colors.mutedForeground, height: 1.4)),
                  ]),
                ],
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.theme.typography.xs.copyWith(fontWeight: FontWeight.w500, color: context.theme.colors.mutedForeground, height: 1.4)),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: _c.accent),
        ]),
      ),
    );
  }

  Widget _buildEventsPlaceholder() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 12,
      child: Row(children: [
        SkeletonLoader(width: 40, height: 40, borderRadius: BorderRadius.circular(10)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 8),
          SkeletonLoader(width: 140, height: 11, borderRadius: BorderRadius.circular(4)),
        ])),
      ]),
    );
  }

  Widget _buildNoEventsCard() {
    return GestureDetector(
      onTap: () => context.go('/events'),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        radius: 12,
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, color: _c.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text('No upcoming events. Tap to add one.', style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground, height: 1.4))),
          Icon(Icons.chevron_right_rounded, size: 18, color: _c.accent),
        ]),
      ),
    );
  }
}

// ── Pulsing dot ───────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1.0, end: 0.35).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(width: 7, height: 7, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    );
  }
}

// ── Sync section ──────────────────────────────────────────────────────────────

/// Home-screen card showing offline sync progress. Renders nothing when there's
/// no offline activity (online, no pending, no failed). Tapping opens the full
/// sync-issues screen; while online with pending ops, offers a manual retry.
class _SyncSection extends StatelessWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<OfflineProvider>();
    final c = AppTheme.colorsOf(context);

    final hasActivity = offline.state != SyncState.online ||
        offline.pendingCount > 0 ||
        offline.failedCount > 0;
    if (hasActivity == false) return const SizedBox.shrink();

    final (IconData icon, Color tint, String title, String subtitle) = switch (offline.state) {
      SyncState.offline => (
        Icons.cloud_off_rounded,
        c.textMuted,
        'Offline',
        offline.pendingCount > 0
            ? '${offline.pendingCount} change${offline.pendingCount == 1 ? '' : 's'} waiting to sync'
            : 'Changes will sync when you reconnect',
      ),
      SyncState.syncing => (
        Icons.sync_rounded,
        c.accent,
        'Syncing…',
        '${offline.pendingCount} item${offline.pendingCount == 1 ? '' : 's'} remaining',
      ),
      SyncState.online => offline.failedCount > 0
          ? (
              Icons.error_outline_rounded,
              c.destructive,
              'Sync issues',
              '${offline.failedCount} item${offline.failedCount == 1 ? '' : 's'} failed to sync',
            )
          : (
              Icons.schedule_rounded,
              c.textMuted,
              'Pending sync',
              '${offline.pendingCount} item${offline.pendingCount == 1 ? '' : 's'} queued',
            ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionLabel('Sync'),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SyncIssuesScreen()),
          ),
          child: AppCard(
            elevated: true,
            padding: const EdgeInsets.all(16),
            radius: 14,
            child: Row(
              children: [
                _SyncIcon(icon: icon, tint: tint),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.theme.typography.sm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: context.theme.typography.xs.copyWith(
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                if (offline.state == SyncState.online && offline.pendingCount > 0)
                  AppButton(
                    label: 'RETRY',
                    variant: ButtonVariant.secondary,
                    size: ButtonSize.sm,
                    onPressed: () => context.read<OfflineProvider>().triggerSync(),
                  )
                else if (offline.isSyncing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: FittedBox(fit: BoxFit.contain, child: FCircularProgress()),
                  )
                else
                  Icon(Icons.chevron_right_rounded, size: 18, color: c.accent),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

/// Sync status icon — a static tinted icon container. The syncing motion is
/// conveyed by the loader on the right of the card, so this icon does not spin.
class _SyncIcon extends StatelessWidget {
  final IconData icon;
  final Color tint;
  const _SyncIcon({required this.icon, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: tint),
    );
  }
}
