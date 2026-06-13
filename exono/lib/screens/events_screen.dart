import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import '../config/app_theme.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_section_label.dart';
import '../widgets/app_header.dart';
import '../widgets/app_input.dart';
import '../widgets/skeleton_loader.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/live_event_provider.dart';

import 'event_follow_ups_screen.dart';
import 'pre_event_prep_screen.dart';
import '../utils/screen_logger.dart';

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

  List<Event> _events = [];
  Map<String, Map<String, dynamic>> _eventStats = {};
  bool _isLoading = true;
  String? _error;

  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _locationController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final events = await ApiService.getEvents();
      final pastEvents = events.where((e) => e.status == 'completed').toList();
      final statsResults = await Future.wait(
        pastEvents.map((e) => ApiService.getEventStats(e.id).catchError((e) => <String, dynamic>{})),
      );
      final statsMap = <String, Map<String, dynamic>>{};
      for (var i = 0; i < pastEvents.length; i++) {
        statsMap[pastEvents[i].id] = statsResults[i];
      }
      setState(() {
        _events = events;
        _eventStats = statsMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Event> get _upcomingEvents =>
      _events.where((e) => e.status == 'upcoming' || e.status == 'ongoing').toList();

  List<Event> get _pastEvents =>
      _events.where((e) => e.status == 'completed').toList();

  List<Event> get _filteredUpcoming {
    if (_searchQuery.isEmpty) return _upcomingEvents;
    final q = _searchQuery.toLowerCase();
    return _upcomingEvents.where((e) =>
      e.name.toLowerCase().contains(q) ||
      (e.location ?? '').toLowerCase().contains(q)
    ).toList();
  }

  List<Event> get _filteredPast {
    if (_searchQuery.isEmpty) return _pastEvents;
    final q = _searchQuery.toLowerCase();
    return _pastEvents.where((e) =>
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
    return ColoredBox(
      color: context.theme.colors.background,
      child: Column(
        children: [
          AppHeader(
            onNotificationPressed: () => showAppToast(context, 'Notifications are UI-only for now.'),
            actionIcon: Icons.add_rounded,
            actionTooltip: 'Add Event',
            onActionPressed: _showNewEventSheet,
          ),
          Expanded(
            child: _isLoading
                ? _buildSkeletonLoader()
                : _error != null
                    ? _buildErrorState()
                    : RefreshIndicator(
                        onRefresh: _loadEvents,
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
                                    _buildTabs(),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ),
                            _buildEventsList(),
                            const SliverToBoxAdapter(child: SizedBox(height: 120)),
                          ],
                        ),
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
      prefixIcon: Icon(Icons.search_rounded, size: 20, color: context.theme.colors.mutedForeground),
      onChanged: (val) => setState(() => _searchQuery = val),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _c.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.theme.colors.border),
      ),
      child: Row(
        children: [
          _buildTabButton(label: 'Upcoming', count: _upcomingEvents.length, isActive: _showUpcoming),
          const SizedBox(width: 4),
          _buildTabButton(label: 'Past', count: _pastEvents.length, isActive: !_showUpcoming),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isActive ? context.theme.colors.background : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
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

  Widget _buildEventsList() {
    if (_showUpcoming) {
      final events = _filteredUpcoming;
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
      final events = _filteredPast;
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.theme.colors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.wifi_off_rounded, size: 36, color: context.theme.colors.error),
          ),
          const SizedBox(height: 20),
          Text(
            'Failed to load events',
            style: context.theme.typography.lg.copyWith(
              fontWeight: FontWeight.w600,
              color: context.theme.colors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check your connection and try again.',
            style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Retry',
            prefixIcon: const Icon(Icons.refresh_rounded, size: 18),
            variant: ButtonVariant.primary,
            onPressed: _loadEvents,
          ),
        ],
      ),
    );
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
              prefixIcon: const Icon(Icons.add_rounded, size: 18),
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
                  Icon(Icons.schedule_rounded, size: 14, color: context.theme.colors.primary),
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
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.more_vert_rounded, color: context.theme.colors.mutedForeground, size: 20),
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
                  child: Icon(Icons.more_vert_rounded, color: context.theme.colors.mutedForeground, size: 20),
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
            prefixIcon: const Icon(Icons.checklist_rounded, size: 18),
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
        Icon(icon, color: context.theme.colors.mutedForeground, size: 14),
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
      await _loadEvents();

      if (mounted) { showAppToast(context, 'Event created successfully.'); }
    } catch (_) {
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
      await _loadEvents();
      if (mounted) { showAppToast(context, 'Event updated.'); }
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
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
                  style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              children: [
                FDivider(),
                _buildActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit Event',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showEditEventSheet(event);
                  },
                ),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Copy Event Details',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    final start = event.startDate;
                    final dateStr = event.endDate == null
                        ? '${months[start.month - 1]} ${start.day}, ${start.year}'
                        : '${months[start.month - 1]} ${start.day} – ${months[event.endDate!.month - 1]} ${event.endDate!.day}, ${start.year}';
                    final text = '${event.name}\n$dateStr${event.location != null ? '\n${event.location}' : ''}';
                    Clipboard.setData(ClipboardData(text: text));
                    if (mounted) { showAppToast(context, 'Event details copied to clipboard.'); }
                  },
                ),
                FDivider(),
                _buildActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete Event',
                  isDestructive: true,
                  onTap: () async {
                    Navigator.of(ctx).pop();
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
                      await _loadEvents();
                      if (mounted) { showAppToast(context, 'Event deleted.'); }
                    } catch (e) {
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? context.theme.colors.error : context.theme.colors.foreground;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: context.theme.typography.lg.copyWith(
                  fontWeight: FontWeight.w400,
                  color: color,
                ),
              ),
            ),
          ],
        ),
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
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: widget.colors.accent,
                surface: widget.colors.surface,
                onSurface: widget.colors.textPrimary,
              ),
            ),
            child: child!,
          ),
        );
        if (date != null) {
          controller.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        }
      },
      prefixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: context.theme.colors.primary),
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
                    prefixIcon: Icon(Icons.location_on_outlined, size: 20, color: context.theme.colors.primary),
                  ),
                  const SizedBox(height: 16),
                  _buildDateField(label: 'Start Date', controller: widget.startDateController),
                  const SizedBox(height: 14),
                  FCheckbox(
                    value: _isOneDay,
                    label: Text(
                      'One-day event',
                      style: context.theme.typography.sm.copyWith(
                        color: context.theme.colors.mutedForeground,
                      ),
                    ),
                    onChange: (val) => setState(() {
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
                    variant: ButtonVariant.ghost,
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
