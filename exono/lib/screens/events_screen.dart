import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/safe_area_insets.dart';
import 'package:forui/forui.dart';

import '../config/app_theme.dart';
import '../db/app_database.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_checkbox.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_stat_row.dart';
import '../widgets/app_header.dart';
import '../widgets/app_input.dart';
import '../widgets/skeleton_loader.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/live_event_provider.dart';
import '../providers/offline_provider.dart';

import '../widgets/app_offline_screen.dart';
import 'event_follow_ups_screen.dart';
import 'pre_event_prep_screen.dart';
import '../utils/screen_logger.dart';
import '../providers/sync_provider.dart';

class EventsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const EventsScreen({super.key, this.onNavigateTab});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  static bool _isValidEventName(String name) => name.length <= 200;
  static bool _isValidLocation(String location) => location.length <= 300;

  // Builds a LOCAL DateTime from a "YYYY-MM-DD" date and "HH:mm" time as the
  // user entered them (device timezone), ready to be converted to UTC for storage.
  static DateTime _localInstant(String date, String hm) {
    final d = date.split('-');
    final t = hm.split(':');
    return DateTime(
      int.parse(d[0]), int.parse(d[1]), int.parse(d[2]),
      int.parse(t[0]), int.parse(t[1]),
    );
  }

  static String _utcDateIso(DateTime utc) =>
      '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';

  static String _utcHm(DateTime utc) =>
      '${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}';

  /// Validates the event form and builds the UTC create/update payload from the
  /// controllers. The user enters LOCAL dates/times; this converts each boundary
  /// to a UTC instant and stores a coherent UTC date anchor + UTC "HH:mm".
  /// Returns the payload on success, or an error string to toast on failure.
  ({Map<String, dynamic>? payload, String? error}) _buildEventPayload(bool isOneDay) {
    final name = _eventNameController.text.trim();
    if (name.isEmpty) return (payload: null, error: 'Event name is required.');
    if (!_isValidEventName(name)) {
      return (payload: null, error: 'Event name must be 200 characters or fewer');
    }
    final location = _locationController.text.trim();
    if (location.isNotEmpty && !_isValidLocation(location)) {
      return (payload: null, error: 'Location must be 300 characters or fewer');
    }
    if (_startDateController.text.isEmpty) {
      return (payload: null, error: 'Event start date is required.');
    }

    final startTimeLocal = _startTimeController.text.trim();
    if (startTimeLocal.isEmpty) {
      return (payload: null, error: 'Event start time is required.');
    }
    final endTimeLocal = _endTimeController.text.trim();
    // "HH:mm" strings order correctly as time-of-day under lexical compare.
    if (endTimeLocal.isNotEmpty && endTimeLocal.compareTo(startTimeLocal) <= 0) {
      return (payload: null, error: 'End time must be after start time.');
    }

    final startLocal = _localInstant(_startDateController.text, startTimeLocal);
    // Reject a start instant that's already in the past (5-min grace for the gap
    // between picking and saving). Compared as instants, so timezone-agnostic.
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    if (startLocal.isBefore(cutoff)) {
      return (payload: null, error: 'Event start time cannot be in the past.');
    }

    final startUtc = startLocal.toUtc();
    final startDate = '${_utcDateIso(startUtc)}T00:00:00.000Z';
    final startTime = _utcHm(startUtc);

    String? endDate;
    String? endTime;
    if (!isOneDay && _endDateController.text.isNotEmpty) {
      final endLocalTime = endTimeLocal.isEmpty ? '00:00' : endTimeLocal;
      final endUtc = _localInstant(_endDateController.text, endLocalTime).toUtc();
      endDate = '${_utcDateIso(endUtc)}T00:00:00.000Z';
      if (endTimeLocal.isNotEmpty) endTime = _utcHm(endUtc);
    } else if (endTimeLocal.isNotEmpty) {
      // Single-day with an end time: convert against the start date; if UTC
      // conversion rolls it to the next day, persist that end date too.
      final endUtc = _localInstant(_startDateController.text, endTimeLocal).toUtc();
      endTime = _utcHm(endUtc);
      final endDateIso = '${_utcDateIso(endUtc)}T00:00:00.000Z';
      if (endDateIso != startDate) endDate = endDateIso;
    }

    return (
      payload: {
        'name': name,
        'location': location.isEmpty ? null : location,
        'start_date': startDate,
        'end_date': endDate,
        'start_time': startTime,
        'end_time': endTime,
      },
      error: null,
    );
  }

  bool _showUpcoming = true;
  String _searchQuery = '';

  Map<String, Map<String, dynamic>> _eventStats = {};
  final Set<String> _statsLoadedFor = {};

  // Watches the follow_ups drift table; any change (interaction logged anywhere,
  // status flipped) re-fetches stats for the already-loaded past cards so their
  // Pending/Skipped/Done counts stay live without a manual reload.
  StreamSubscription? _followUpsSub;
  bool _firstFollowUpTick = true;

  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _subscribeFollowUpChanges();
  }

  @override
  void dispose() {
    _followUpsSub?.cancel();
    _eventNameController.dispose();
    _locationController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _subscribeFollowUpChanges() {
    _followUpsSub = context.read<SyncProvider>().followUps.watchAll().listen((_) {
      // Skip the priming emission so we don't double-fetch right after the
      // initial _loadStatsIfNeeded already loaded the visible cards.
      if (_firstFollowUpTick) {
        _firstFollowUpTick = false;
        return;
      }
      _refreshLoadedStats();
    });
  }

  Future<void> _loadStatsIfNeeded(List<Event> events) async {
    final pastEventIds = events.where((e) => e.status == 'completed').map((e) => e.id).toList();
    final missing = pastEventIds.where((id) => !_statsLoadedFor.contains(id)).toList();
    if (missing.isEmpty) return;
    _statsLoadedFor.addAll(missing);
    final statsMap = await ApiService.getEventStatsBatch(missing).catchError((_) => <String, Map<String, dynamic>>{});
    if (!mounted) return;
    setState(() => _eventStats = {..._eventStats, ...statsMap});
  }

  // Re-fetch stats for every past event already on screen. Called when the
  // follow_ups table changes so the past cards' counts update in place.
  Future<void> _refreshLoadedStats() async {
    final ids = _statsLoadedFor.toList();
    if (ids.isEmpty) return;
    final statsMap = await ApiService.getEventStatsBatch(ids)
        .catchError((_) => <String, Map<String, dynamic>>{});
    if (!mounted || statsMap.isEmpty) return;
    setState(() => _eventStats = {..._eventStats, ...statsMap});
  }

  List<Event> _upcomingEvents(List<Event> events) =>
      events.where((e) => e.status == 'upcoming' || e.status == 'ongoing').toList();

  List<Event> _pastEvents(List<Event> events) =>
      events.where((e) => e.status == 'completed').toList();

  List<Event> _filteredUpcoming(List<Event> events) {
    final upcoming = _upcomingEvents(events);
    if (_searchQuery.isEmpty) return upcoming;
    final q = _searchQuery.toLowerCase();
    return upcoming.where((e) =>
      e.name.toLowerCase().contains(q) ||
      (e.location ?? '').toLowerCase().contains(q)
    ).toList();
  }

  List<Event> _filteredPast(List<Event> events) {
    final past = _pastEvents(events);
    if (_searchQuery.isEmpty) return past;
    final q = _searchQuery.toLowerCase();
    return past.where((e) =>
      e.name.toLowerCase().contains(q) ||
      (e.location ?? '').toLowerCase().contains(q)
    ).toList();
  }

  String _formatDateRange(DateTime start, DateTime? end) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final s = '${months[start.month - 1]} ${start.day}';
    if (end == null) return '$s, ${start.year}';
    if (start.month == end.month) return '$s–${end.day}, ${start.year}';
    return '$s – ${months[end.month - 1]} ${end.day}, ${end.year}';
  }

  int _daysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<OfflineProvider>().isOnline;
    if (!isOnline) return const AppOfflineScreen(title: 'Events');

    final eventsRepo = context.read<SyncProvider>().events;

    return ColoredBox(
      color: context.theme.colors.background,
      child: Column(
        children: [
          AppHeader(
            actionIcon: Icons.add_rounded,
            actionTooltip: 'Add Event',
            onActionPressed: _showNewEventSheet,
          ),
          Expanded(
            child: StreamBuilder<List<EventsTableData>>(
              stream: eventsRepo.watchAll(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return _buildSkeletonLoader();

                final events = eventsWithLiveStatus(
                  snapshot.data!.map(Event.fromDrift).toList(),
                );
                _loadStatsIfNeeded(events);

                return RefreshIndicator(
                  onRefresh: eventsRepo.catchUp,
                  color: _c.accent,
                  backgroundColor: context.theme.colors.background,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSearchBar(),
                              const SizedBox(height: 20),
                              _buildTabs(events),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      _buildEventsList(events),
                      SliverToBoxAdapter(child: SizedBox(height: bottomScrollInset(context))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return AppInput(
      hint: 'Search events...',
      controller: _searchController,
      prefixIcon: Icon(Icons.search_rounded, size: 18, color: _c.accent),
      onChanged: (val) => setState(() => _searchQuery = val),
    );
  }

  Widget _buildTabs(List<Event> events) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _c.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.theme.colors.border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: _showUpcoming ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: context.theme.colors.background,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: Row(
              children: [
                _buildTabButton(label: 'Upcoming', count: _upcomingEvents(events).length, isActive: _showUpcoming),
                const SizedBox(width: 4),
                _buildTabButton(label: 'Past', count: _pastEvents(events).length, isActive: !_showUpcoming),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({required String label, required int count, required bool isActive}) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          _showUpcoming = label == 'Upcoming';
          _searchQuery = '';
          _searchController.clear();
        }),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                style: context.theme.typography.sm.copyWith(
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? context.theme.colors.foreground : context.theme.colors.mutedForeground,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive ? context.theme.colors.primary.withValues(alpha: 0.12) : context.theme.colors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: context.theme.typography.xs.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isActive ? context.theme.colors.primary : context.theme.colors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventsList(List<Event> allEvents) {
    if (_showUpcoming) {
      final events = _filteredUpcoming(allEvents);
      if (events.isEmpty) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildEmptyState(
              icon: Icons.event_outlined,
              title: _searchQuery.isEmpty ? 'No upcoming events' : 'No results found',
              description: _searchQuery.isEmpty
                  ? 'Create your first event to get started tracking your networking.'
                  : 'Try a different search term.',
              showAction: _searchQuery.isEmpty,
            ),
          ),
        );
      }
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(
          itemCount: events.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 14),
          itemBuilder: (_, i) => _buildUpcomingEventCard(events[i]),
        ),
      );
    } else {
      final events = _filteredPast(allEvents);
      if (events.isEmpty) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildEmptyState(
              icon: Icons.history_rounded,
              title: _searchQuery.isEmpty ? 'No past events' : 'No results found',
              description: _searchQuery.isEmpty
                  ? 'Completed events will appear here.'
                  : 'Try a different search term.',
              showAction: false,
            ),
          ),
        );
      }
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(
          itemCount: events.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 14),
          itemBuilder: (_, i) => _buildPastEventCard(events[i]),
        ),
      );
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
    bool showAction = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.theme.colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 34, color: context.theme.colors.primary.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: context.theme.typography.lg.copyWith(
              fontWeight: FontWeight.w600,
              color: context.theme.colors.foreground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground),
            textAlign: TextAlign.center,
          ),
          if (showAction) ...[
            const SizedBox(height: 24),
            AppButton(
              label: 'Create Event',
              prefixIcon: Icon(Icons.add_rounded, size: 18, color: _c.accent),
              variant: ButtonVariant.outline,
              onPressed: _showNewEventSheet,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpcomingEventCard(Event event) {
    final isOngoing = event.status == 'ongoing';
    final daysUntil = isOngoing ? 0 : _daysUntil(event.localStartDate);
    final isToday = daysUntil == 0 && !isOngoing;
    final isTomorrow = daysUntil == 1;

    return AppCard(
      padding: const EdgeInsets.all(0),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isOngoing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: context.theme.colors.error,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LIVE NOW',
                    style: context.theme.typography.xs.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Floor is open',
                    style: context.theme.typography.xs.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            )
          else if (isToday || isTomorrow || daysUntil <= 7)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: context.theme.colors.primary.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: _c.accent),
                  const SizedBox(width: 6),
                  Text(
                    isToday ? 'TODAY' : isTomorrow ? 'TOMORROW' : 'IN $daysUntil DAYS',
                    style: context.theme.typography.xs.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: context.theme.colors.primary,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        event.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.typography.lg.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          height: 1.05,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showEventActionsSheet(event),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Icon(Icons.more_vert_rounded, color: _c.accent, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildMetaRow(Icons.calendar_today_outlined, _formatDateRange(event.localStartDate, event.endDate)),
                if (event.localTimeRange != null) ...[
                  const SizedBox(height: 6),
                  _buildMetaRow(Icons.schedule_outlined, event.localTimeRange!),
                ],
                const SizedBox(height: 6),
                _buildMetaRow(Icons.location_on_outlined, event.location ?? 'Location TBD'),
                if (!isOngoing && daysUntil > 7) ...[
                  const SizedBox(height: 6),
                  _buildMetaRow(Icons.hourglass_empty_rounded, '$daysUntil days away'),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: isOngoing ? 'ENTER LIVE FLOOR' : 'PREPARE',
                        variant: ButtonVariant.primary,
                        fullWidth: true,
                        onPressed: () => isOngoing ? _openEventFloor(event) : _openPrepScreen(event),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastEventCard(Event event) {
    final stats = _eventStats[event.id] ?? {};
    final totalContacts = (stats['total_contacts'] as num?)?.toInt() ?? 0;
    final pending = (stats['follow_ups_needed'] as num?)?.toInt() ?? 0;
    final skipped = (stats['follow_ups_skipped'] as num?)?.toInt() ?? 0;
    final done = (stats['follow_ups_done'] as num?)?.toInt() ?? 0;
    final followUpPct = totalContacts > 0 ? (done / totalContacts).clamp(0.0, 1.0) : 0.0;
    final pctLabel = '${(followUpPct * 100).round()}%';
    final isComplete = followUpPct >= 1.0 && totalContacts > 0;
    final barColor = isComplete ? _c.success : context.theme.colors.primary;

    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.typography.lg.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        height: 1.05,
                        color: context.theme.colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildMetaRow(
                      Icons.calendar_today_outlined,
                      [
                        _formatDateRange(event.localStartDate, event.endDate),
                        if (event.localTimeRange != null) event.localTimeRange!,
                        if (event.location != null) event.location!,
                      ].join(' · '),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showEventActionsSheet(event),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.more_vert_rounded, color: _c.accent, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Follow-up progress',
                  style: context.theme.typography.xs.copyWith(
                    color: context.theme.colors.mutedForeground,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Text(
                pctLabel,
                style: context.theme.typography.xs.copyWith(
                  fontWeight: FontWeight.w700,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 6,
              color: _c.surfaceElevated,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: followUpPct,
                  child: Container(
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          AppStatRow(stats: [
            AppStat(value: '$totalContacts', label: 'Contacts'),
            AppStat(
                value: '$pending',
                label: 'Pending',
                valueColor: pending > 0
                    ? context.theme.colors.primary
                    : context.theme.colors.mutedForeground),
            AppStat(
                value: '$skipped',
                label: 'Skipped',
                valueColor: skipped > 0
                    ? context.theme.colors.error
                    : context.theme.colors.mutedForeground),
            AppStat(
                value: '$done',
                label: 'Done',
                valueColor:
                    done > 0 ? _c.success : context.theme.colors.mutedForeground),
          ]),
          const SizedBox(height: 14),
          AppButton(
            label: 'FOLLOW-UP QUEUE',
            prefixIcon: Icon(Icons.checklist_rounded, size: 18, color: _c.accent),
            variant: isComplete ? ButtonVariant.secondary : ButtonVariant.primary,
            fullWidth: true,
            onPressed: () => _openFollowUpQueue(event),
          ),
        ],
      ),
    );
  }


  Widget _buildMetaRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: _c.accent, size: 14),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.theme.typography.xs.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openFollowUpQueue(Event event) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventFollowUpsScreen(
          onNavigateTab: widget.onNavigateTab,
          event: event,
        ),
      ),
    );
    if (!mounted) return;
    final updated = await ApiService.getEventStats(event.id).catchError((e) => <String, dynamic>{});
    if (!mounted) return;
    setState(() => _eventStats[event.id] = updated);
  }

  void _openPrepScreen(Event event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PreEventPrepScreen(
          event: event,
          onNavigateTab: widget.onNavigateTab,
        ),
      ),
    );
  }

  void _openEventFloor(Event event) {
    context.read<LiveEventProvider>().refresh();
    context.go('/live-event');
  }

  void _showNewEventSheet() {
    _eventNameController.clear();
    _locationController.clear();
    _startDateController.clear();
    _endDateController.clear();
    _startTimeController.clear();
    _endTimeController.clear();

    showAppSheet(
      context: context,
      builder: (sheetContext) => _NewEventSheet(
        nameController: _eventNameController,
        locationController: _locationController,
        startDateController: _startDateController,
        endDateController: _endDateController,
        startTimeController: _startTimeController,
        endTimeController: _endTimeController,
        colors: _c,
        onSave: (isOneDay) => _saveEvent(sheetContext, isOneDay),
        onCancel: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  Future<void> _saveEvent(BuildContext sheetContext, bool isOneDay) async {
    final built = _buildEventPayload(isOneDay);
    if (built.payload == null) {
      showAppToast(sheetContext, built.error!);
      return;
    }

    try {
      await ApiService.createEvent(built.payload!);

      if (sheetContext.mounted) { Navigator.of(sheetContext).pop(); }
      if (mounted) { await context.read<SyncProvider>().events.catchUp(); }

      if (mounted) { showAppToast(context, 'Event created successfully.'); }
    } on UnauthorizedException { rethrow; }
    on EventOverlapException catch (e) {
      if (sheetContext.mounted) { showAppToast(sheetContext, e.message); }
    } on EventValidationException catch (e) {
      if (sheetContext.mounted) { showAppToast(sheetContext, e.message); }
    } catch (_) {
      if (sheetContext.mounted) { showAppToast(sheetContext, 'Server error — please try again.'); }
    }
  }

  void _showEditEventSheet(Event event) {
    _eventNameController.text = event.name;
    _locationController.text = event.location ?? '';
    // Show local dates/times (storage is UTC; the user edits in their own zone).
    final localStart = event.localStartDate;
    _startDateController.text =
        '${localStart.year}-${localStart.month.toString().padLeft(2, '0')}-${localStart.day.toString().padLeft(2, '0')}';
    if (event.endDate != null) {
      final localEnd = event.endDate!.toLocal();
      _endDateController.text =
          '${localEnd.year}-${localEnd.month.toString().padLeft(2, '0')}-${localEnd.day.toString().padLeft(2, '0')}';
    } else {
      _endDateController.text = '';
    }
    _startTimeController.text = event.localStartTime ?? '';
    _endTimeController.text = event.localEndTime ?? '';

    showAppSheet(
      context: context,
      builder: (sheetContext) => _NewEventSheet(
        nameController: _eventNameController,
        locationController: _locationController,
        startDateController: _startDateController,
        endDateController: _endDateController,
        startTimeController: _startTimeController,
        endTimeController: _endTimeController,
        colors: _c,
        title: 'Edit Event',
        saveLabel: 'SAVE CHANGES',
        initialIsOneDay: event.endDate == null,
        onSave: (isOneDay) => _updateEvent(sheetContext, event.id, isOneDay),
        onCancel: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  Future<void> _updateEvent(BuildContext sheetContext, String eventId, bool isOneDay) async {
    final built = _buildEventPayload(isOneDay);
    if (built.payload == null) {
      showAppToast(sheetContext, built.error!);
      return;
    }

    try {
      await ApiService.updateEvent(eventId, built.payload!);
      if (sheetContext.mounted) { Navigator.of(sheetContext).pop(); }
      if (mounted) { await context.read<SyncProvider>().events.catchUp(); }
      if (mounted) { showAppToast(context, 'Event updated.'); }
    } on UnauthorizedException { rethrow; }
    on EventOverlapException catch (e) {
      if (sheetContext.mounted) { showAppToast(sheetContext, e.message); }
    } on EventValidationException catch (e) {
      if (sheetContext.mounted) { showAppToast(sheetContext, e.message); }
    } catch (_) {
      if (sheetContext.mounted) { showAppToast(sheetContext, 'Server error — please try again.'); }
    }
  }

  void _showEventActionsSheet(Event event) {
    showAppSheet(
      context: context,
      builder: (ctx) => _buildEventActionsContent(ctx, event),
    );
  }

  Widget _buildEventActionsContent(BuildContext ctx, Event event) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.theme.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  event.name,
                  textAlign: TextAlign.center,
                  style: context.theme.typography.sm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.theme.colors.foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    _formatDateRange(event.localStartDate, event.endDate),
                    if (event.localTimeRange != null) event.localTimeRange!,
                  ].join(' · '),
                  textAlign: TextAlign.center,
                  style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  label: 'Edit Event',
                  prefixIcon: Icon(Icons.edit_outlined, size: 18, color: _c.accent),
                  variant: ButtonVariant.secondary,
                  fullWidth: true,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showEditEventSheet(event);
                  },
                ),
                if (event.status == 'ongoing') ...[
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'Stop Live Event',
                    prefixIcon: Icon(Icons.stop_circle_outlined, size: 18, color: _c.destructive),
                    variant: ButtonVariant.outline,
                    fullWidth: true,
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _stopLiveEvent(event);
                    },
                  ),
                ],
                const SizedBox(height: 8),
                AppButton(
                  label: 'Delete Event',
                  prefixIcon: Icon(Icons.delete_outline_rounded, size: 18, color: _c.destructive),
                  variant: ButtonVariant.destructive,
                  fullWidth: true,
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final eventsRepo = context.read<SyncProvider>().events;
                    final confirmed = await showAppConfirmDialog(
                      context: context,
                      title: 'Delete Event',
                      message: 'Are you sure you want to delete "${event.name}"? This cannot be undone.',
                      confirmLabel: 'Delete',
                      destructive: true,
                    );
                    if (confirmed != true) return;
                    try {
                      await ApiService.deleteEvent(event.id);
                      await eventsRepo.catchUp();
                      if (mounted) {
                        showAppToast(context, 'Event deleted.');
                      }
                    } on UnauthorizedException { rethrow; } catch (e) {
                      if (mounted) { showAppToast(context, 'Failed to delete event.'); }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Ends a currently-live event by setting its end boundary to "now" (local),
  // so computeEventStatus flips it to 'completed'. For a multi-day event we also
  // pin end_date to today; single-day events just get an end_time.
  Future<void> _stopLiveEvent(Event event) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Stop Live Event',
      message: 'End "${event.name}" now? Its floor will close and it will move to past events.',
      confirmLabel: 'Stop Event',
      destructive: true,
    );
    if (confirmed != true) return;

    final now = DateTime.now();
    final endTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    // The backend's end_time validation requires start_time in the same payload
    // (the patch schema validates in isolation, so it can't see the stored
    // start_time). Open-ended events have no start_time — anchor them to midnight.
    final startTime = event.startTime ?? '00:00';
    final updates = <String, dynamic>{
      'start_time': startTime,
      'end_time': endTime,
    };
    if (event.endDate != null) {
      updates['end_date'] =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }

    try {
      await ApiService.updateEvent(event.id, updates);
      if (!mounted) return;
      await context.read<SyncProvider>().events.catchUp();
      if (!mounted) return;
      context.read<LiveEventProvider>().refresh();
      showAppToast(context, 'Live event ended.');
    } on UnauthorizedException {
      rethrow;
    } on EventValidationException catch (e) {
      if (mounted) { showAppToast(context, e.message); }
    } catch (e) {
      if (mounted) { showAppToast(context, 'Failed to stop event.'); }
    }
  }

  Widget _buildSkeletonLoader() {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 24, 16, bottomScrollInset(context)),
      children: [
        SkeletonLoader(
          width: 200,
          height: 28,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 8),
        SkeletonLoader(
          width: 240,
          height: 14,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: SkeletonLoader(width: double.infinity, height: 62, borderRadius: BorderRadius.circular(16))),
            const SizedBox(width: 10),
            Expanded(child: SkeletonLoader(width: double.infinity, height: 62, borderRadius: BorderRadius.circular(16))),
          ],
        ),
        const SizedBox(height: 20),
        SkeletonLoader(
          width: double.infinity,
          height: 52,
          borderRadius: BorderRadius.circular(14),
        ),
        const SizedBox(height: 16),
        SkeletonLoader(
          width: double.infinity,
          height: 44,
          borderRadius: BorderRadius.circular(10),
        ),
        const SizedBox(height: 16),
        SkeletonLoader(
          width: double.infinity,
          height: 48,
          borderRadius: BorderRadius.circular(14),
        ),
        const SizedBox(height: 20),
        const SkeletonCard(),
        const SizedBox(height: 14),
        const SkeletonCard(),
        const SizedBox(height: 14),
        const SkeletonCard(),
      ],
    );
  }
}

class _NewEventSheet extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController locationController;
  final TextEditingController startDateController;
  final TextEditingController endDateController;
  final TextEditingController startTimeController;
  final TextEditingController endTimeController;
  final ExonoColors colors;
  final void Function(bool isOneDay) onSave;
  final VoidCallback onCancel;
  final String title;
  final String saveLabel;
  final bool initialIsOneDay;

  const _NewEventSheet({
    required this.nameController,
    required this.locationController,
    required this.startDateController,
    required this.endDateController,
    required this.startTimeController,
    required this.endTimeController,
    required this.colors,
    required this.onSave,
    required this.onCancel,
    this.title = 'New Event',
    this.saveLabel = 'SAVE EVENT',
    this.initialIsOneDay = false,
  });

  @override
  State<_NewEventSheet> createState() => _NewEventSheetState();
}

class _NewEventSheetState extends State<_NewEventSheet> {
  bool _isOneDay = false;

  @override
  void initState() {
    super.initState();
    _isOneDay = widget.initialIsOneDay;
  }

  Widget _buildDateField({required String label, required TextEditingController controller}) {
    return AppInput(
      label: label,
      hint: 'YYYY-MM-DD',
      controller: controller,
      readOnly: true,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2024),
          lastDate: DateTime(2030),
          builder: AppTheme.datePickerBuilder,
        );
        if (date != null) {
          controller.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        }
      },
      prefixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.colorsOf(context).accent),
    );
  }

  Widget _buildTimeField({required String label, required TextEditingController controller, String? hint}) {
    return AppInput(
      label: label,
      hint: hint ?? 'HH:mm',
      controller: controller,
      readOnly: true,
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
          builder: AppTheme.datePickerBuilder,
        );
        if (picked != null) {
          controller.text =
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        }
      },
      prefixIcon: Icon(Icons.schedule_outlined, size: 18, color: AppTheme.colorsOf(context).accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.theme.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: context.theme.typography.xl2.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: context.theme.colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fill in the details to schedule a new event.',
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppInput(
                    label: 'Event Name',
                    hint: 'e.g. AI Innovation Summit 2025',
                    controller: widget.nameController,
                  ),
                  const SizedBox(height: 16),
                  AppInput(
                    label: 'Location',
                    hint: 'Venue or city',
                    controller: widget.locationController,
                    prefixIcon: Icon(Icons.location_on_outlined, size: 18, color: AppTheme.colorsOf(context).accent),
                  ),
                  const SizedBox(height: 16),
                  _buildDateField(label: 'Start Date', controller: widget.startDateController),
                  const SizedBox(height: 14),
                  AppCheckbox(
                    value: _isOneDay,
                    label: 'One-day event',
                    onChanged: (val) => setState(() {
                      _isOneDay = val;
                      if (_isOneDay) { widget.endDateController.clear(); }
                    }),
                  ),
                  if (!_isOneDay) ...[
                    const SizedBox(height: 14),
                    _buildDateField(label: 'End Date', controller: widget.endDateController),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTimeField(
                          label: 'Start Time',
                          controller: widget.startTimeController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimeField(
                          label: 'End Time (optional)',
                          controller: widget.endTimeController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Leave end time empty to run until the next event that day, or end of day.',
                    style: context.theme.typography.xs.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: widget.saveLabel,
                    variant: ButtonVariant.primary,
                    fullWidth: true,
                    onPressed: () => widget.onSave(_isOneDay),
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    label: 'CANCEL',
                    variant: ButtonVariant.outline,
                    fullWidth: true,
                    onPressed: widget.onCancel,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
