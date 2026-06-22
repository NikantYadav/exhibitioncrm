import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../config/app_theme.dart';
import '../db/app_database.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_checkbox.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_section_label.dart';
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

  bool _showUpcoming = true;
  String _searchQuery = '';

  Map<String, Map<String, dynamic>> _eventStats = {};
  final Set<String> _statsLoadedFor = {};

  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _eventNameController.dispose();
    _locationController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _searchController.dispose();
    super.dispose();
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

                final events = snapshot.data!.map(Event.fromDrift).toList();
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
                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
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
    final daysUntil = isOngoing ? 0 : _daysUntil(event.startDate);
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
                color: context.theme.colors.error.withValues(alpha: 0.18),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.theme.colors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LIVE NOW',
                    style: context.theme.typography.xs.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: context.theme.colors.error,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Floor is open',
                    style: context.theme.typography.xs.copyWith(
                      color: context.theme.colors.error.withValues(alpha: 0.7),
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
                        style: context.theme.typography.lg.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
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
                _buildMetaRow(Icons.calendar_today_outlined, _formatDateRange(event.startDate, event.endDate)),
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
                      style: context.theme.typography.lg.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: context.theme.colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildMetaRow(
                      Icons.calendar_today_outlined,
                      [
                        _formatDateRange(event.startDate, event.endDate),
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
          Row(
            children: [
              _buildStatCell('Contacts', '$totalContacts', context.theme.colors.foreground),
              _buildStatDivider(),
              _buildStatCell('Pending', '$pending',
                  pending > 0 ? context.theme.colors.primary : context.theme.colors.mutedForeground),
              _buildStatDivider(),
              _buildStatCell('Skipped', '$skipped',
                  skipped > 0 ? context.theme.colors.error : context.theme.colors.mutedForeground),
              _buildStatDivider(),
              _buildStatCell('Done', '$done',
                  done > 0 ? _c.success : context.theme.colors.mutedForeground),
            ],
          ),
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

  Widget _buildStatCell(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: context.theme.typography.lg.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          AppSectionLabel(label),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 28,
      color: context.theme.colors.border,
      margin: const EdgeInsets.symmetric(horizontal: 4),
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
            style: context.theme.typography.xs.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
            overflow: TextOverflow.ellipsis,
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

    showAppSheet(
      context: context,
      builder: (sheetContext) => _NewEventSheet(
        nameController: _eventNameController,
        locationController: _locationController,
        startDateController: _startDateController,
        endDateController: _endDateController,
        colors: _c,
        onSave: (isOneDay) => _saveEvent(sheetContext, isOneDay),
        onCancel: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  Future<void> _saveEvent(BuildContext sheetContext, bool isOneDay) async {
    final name = _eventNameController.text.trim();
    if (name.isEmpty) {
      showAppToast(sheetContext, 'Event name is required.');
      return;
    }

    final startText = _startDateController.text;
    final startDate = startText.isNotEmpty
        ? '${startText}T00:00:00.000Z'
        : DateTime.now().toIso8601String();

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (DateTime.parse(startDate).isBefore(today)) {
      showAppToast(sheetContext, 'Event start date cannot be in the past.');
      return;
    }

    final endDate = isOneDay
        ? null
        : (_endDateController.text.isNotEmpty
            ? '${_endDateController.text}T00:00:00.000Z'
            : null);

    try {
      await ApiService.createEvent({
        'name': name,
        'location': _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        'start_date': startDate,
        'end_date': endDate,
      });

      if (sheetContext.mounted) { Navigator.of(sheetContext).pop(); }
      if (mounted) { await context.read<SyncProvider>().events.catchUp(); }

      if (mounted) { showAppToast(context, 'Event created successfully.'); }
    } on UnauthorizedException { rethrow; } catch (_) {
      if (sheetContext.mounted) { showAppToast(sheetContext, 'Server error — please try again.'); }
    }
  }

  void _showEditEventSheet(Event event) {
    _eventNameController.text = event.name;
    _locationController.text = event.location ?? '';
    _startDateController.text =
        '${event.startDate.year}-${event.startDate.month.toString().padLeft(2, '0')}-${event.startDate.day.toString().padLeft(2, '0')}';
    _endDateController.text = event.endDate != null
        ? '${event.endDate!.year}-${event.endDate!.month.toString().padLeft(2, '0')}-${event.endDate!.day.toString().padLeft(2, '0')}'
        : '';

    showAppSheet(
      context: context,
      builder: (sheetContext) => _NewEventSheet(
        nameController: _eventNameController,
        locationController: _locationController,
        startDateController: _startDateController,
        endDateController: _endDateController,
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
    final name = _eventNameController.text.trim();
    if (name.isEmpty) {
      showAppToast(sheetContext, 'Event name is required.');
      return;
    }
    final startText = _startDateController.text;
    final startDate = startText.isNotEmpty ? '${startText}T00:00:00.000Z' : null;

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (startDate != null && DateTime.parse(startDate).isBefore(today)) {
      showAppToast(sheetContext, 'Event start date cannot be in the past.');
      return;
    }

    final endDate = isOneDay
        ? null
        : (_endDateController.text.isNotEmpty ? '${_endDateController.text}T00:00:00.000Z' : null);

    try {
      await ApiService.updateEvent(eventId, {
        'name': name,
        'location': _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        'start_date': startDate,
        'end_date': endDate,
      });
      if (sheetContext.mounted) { Navigator.of(sheetContext).pop(); }
      if (mounted) { await context.read<SyncProvider>().events.catchUp(); }
      if (mounted) { showAppToast(context, 'Event updated.'); }
    } on UnauthorizedException { rethrow; } catch (_) {
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
                  _formatDateRange(event.startDate, event.endDate),
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

  Widget _buildSkeletonLoader() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
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
