import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import '../config/app_theme.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_section_label.dart';
import '../widgets/app_header.dart';
import '../widgets/app_input.dart';
import '../widgets/skeleton_loader.dart';
import 'package:go_router/go_router.dart';

import 'event_follow_ups_screen.dart';
import 'pre_event_prep_screen.dart';

class EventsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const EventsScreen({super.key, this.onNavigateTab});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  bool _showUpcoming = true;

  List<Event> _events = [];
  Map<String, Map<String, dynamic>> _eventStats = {};
  bool _isLoading = true;
  String? _error;

  late final TextEditingController _eventNameController;
  late final TextEditingController _locationController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;

  @override
  void initState() {
    super.initState();
    _eventNameController = TextEditingController();
    _locationController = TextEditingController();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
    _loadEvents();
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _locationController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
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
        pastEvents.map((e) => ApiService.getEventStats(e.id).catchError((_) => <String, dynamic>{})),
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

  String _formatDateRange(DateTime start, DateTime? end) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final s = '${months[start.month - 1]} ${start.day}';
    if (end == null) return '$s, ${start.year}';
    if (start.month == end.month) return '$s - ${end.day}, ${start.year}';
    return '$s - ${months[end.month - 1]} ${end.day}, ${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.theme.colors.background,
      child: Column(
        children: [
          AppHeader(
            onNotificationPressed: () => showFToast(
              context: context,
              title: const Text('Notifications are UI-only for now.'),
            ),
            actionIcon: Icons.add_rounded,
            actionTooltip: 'Add Event',
            onActionPressed: _showNewEventForm,
          ),
          Expanded(
            child: _isLoading
                ? _buildSkeletonLoader()
                : _error != null
                    ? _buildErrorState()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 18),
                            _buildNewEventButton(),
                            const SizedBox(height: 26),
                            _buildTabs(),
                            const SizedBox(height: 18),
                            if (_showUpcoming) ...[
                              ..._upcomingEvents.map(
                                (event) => Padding(
                                  padding: const EdgeInsets.only(bottom: 28),
                                  child: _buildUpcomingEventCard(event),
                                ),
                              ),
                              if (_upcomingEvents.isEmpty)
                                _buildEmptyState('No upcoming events scheduled.'),
                            ] else ...[
                              ..._pastEvents.map(
                                (event) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildPastEventCard(event),
                                ),
                              ),
                              if (_pastEvents.isEmpty)
                                _buildEmptyState('No past events found.'),
                            ],
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Failed to load events.',
            style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground),
          ),
          const SizedBox(height: 16),
          FButton(
            variant: FButtonVariant.primary,
            onPress: _loadEvents,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          message,
          style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground),
        ),
      ),
    );
  }

  void _showNewEventForm() {
    _showNewEventSheet();
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Network Hub',
          style: context.theme.typography.xl2.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.48,
            color: context.theme.colors.foreground,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${_events.length} TOTAL SCHEDULED EVENTS',
          style: context.theme.typography.xs.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 3.2,
            color: context.theme.colors.mutedForeground,
          ),
        ),
      ],
    );
  }

  Widget _buildNewEventButton() {
    return SizedBox(
      width: double.infinity,
      child: FButton(
        variant: FButtonVariant.primary,
        onPress: _showNewEventSheet,
        prefix: const Icon(Icons.add, size: 22),
        child: Text(
          'NEW EVENT',
          style: context.theme.typography.xs.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 3.2,
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _c.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.theme.colors.border),
      ),
      child: Row(
        children: [
          _buildTabButton(label: 'UPCOMING', isActive: _showUpcoming),
          const SizedBox(width: 36),
          _buildTabButton(label: 'PAST', isActive: !_showUpcoming),
        ],
      ),
    );
  }

  Widget _buildTabButton({required String label, required bool isActive}) {
    return GestureDetector(
      onTap: () => setState(() => _showUpcoming = label == 'UPCOMING'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? context.theme.colors.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: _c.accentGlow.withValues(alpha: 0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: context.theme.typography.xs.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: isActive ? context.theme.colors.foreground : context.theme.colors.mutedForeground,
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingEventCard(Event event) {
    final isOngoing = event.status == 'ongoing';

    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isOngoing) ...[
            Row(
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
                  'LIVE FLOOR AVAILABLE',
                  style: context.theme.typography.xs.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: context.theme.colors.foreground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  event.name,
                  style: context.theme.typography.xl.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: context.theme.colors.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FButton(
                variant: FButtonVariant.ghost,
                onPress: () => _showEventActionsSheet(event),
                child: Icon(
                  Icons.more_vert,
                  color: context.theme.colors.primary,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildUpcomingMetaRow(
            Icons.calendar_today_outlined,
            _formatDateRange(event.startDate, event.endDate),
          ),
          const SizedBox(height: 8),
          _buildUpcomingMetaRow(
            Icons.location_on_outlined,
            event.location ?? 'Location TBD',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FButton(
              variant: FButtonVariant.primary,
              onPress: () => isOngoing ? _openEventFloor(event) : _openPrepScreen(event),
              child: Text(
                isOngoing ? 'ENTER LIVE FLOOR' : 'PREPARE',
                style: context.theme.typography.xs.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.4,
                ),
              ),
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

    final dateLocation =
        '${_formatDateRange(event.startDate, event.endDate)}${event.location != null ? ' • ${event.location}' : ''}';

    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 28,
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
                    Text(
                      dateLocation,
                      style: context.theme.typography.xs.copyWith(
                        color: context.theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppChip.status('COMPLETED', color: context.theme.colors.secondaryForeground),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppSectionLabel('Follow-Up Completion'),
              ),
              Text(
                '${(followUpPct * 100).round()}%',
                style: context.theme.typography.xs.copyWith(
                  fontWeight: FontWeight.w700,
                  color: followUpPct >= 1.0 ? _c.success : context.theme.colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 5,
              color: _c.surfaceElevated,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: followUpPct,
                  child: Container(
                    decoration: BoxDecoration(
                      color: followUpPct >= 1.0 ? _c.success : context.theme.colors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            radius: 16,
            elevated: true,
            child: Row(
              children: [
                _buildStatCell('Contacts', '$totalContacts', context.theme.colors.foreground),
                _buildStatDivider(),
                _buildStatCell('Pending', '$pending', pending > 0 ? context.theme.colors.primary : context.theme.colors.mutedForeground),
                _buildStatDivider(),
                _buildStatCell('Skipped', '$skipped', skipped > 0 ? context.theme.colors.error : context.theme.colors.mutedForeground),
                _buildStatDivider(),
                _buildStatCell('Done', '$done', done > 0 ? _c.success : context.theme.colors.mutedForeground),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FButton(
              variant: FButtonVariant.primary,
              onPress: () => _openFollowUpQueue(event),
              child: Text(
                'FOLLOW-UP QUEUE',
                style: context.theme.typography.xs.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                ),
              ),
            ),
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

  Widget _buildUpcomingMetaRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: context.theme.colors.primary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: context.theme.typography.sm.copyWith(
              fontWeight: FontWeight.w400,
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
    final updated = await ApiService.getEventStats(event.id).catchError((_) => <String, dynamic>{});
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
    context.go('/live-event');
  }

  void _showNewEventSheet() {
    _eventNameController.clear();
    _locationController.clear();
    _startDateController.clear();
    _endDateController.clear();

    showFSheet(
      context: context,
      side: FLayout.btt,
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
      showFToast(context: sheetContext, title: const Text('Event name is required.'));
      return;
    }

    final startText = _startDateController.text;
    final startDate = startText.isNotEmpty
        ? '${startText}T00:00:00.000Z'
        : DateTime.now().toIso8601String();

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (DateTime.parse(startDate).isBefore(today)) {
      showFToast(context: sheetContext, title: const Text('Event start date cannot be in the past.'));
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

      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      await _loadEvents();

      if (mounted) {
        showFToast(context: context, title: const Text('Event created successfully.'));
      }
    } catch (_) {
      if (sheetContext.mounted) {
        showFToast(context: sheetContext, title: const Text('Server error — please try again.'));
      }
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

    showFSheet(
      context: context,
      side: FLayout.btt,
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
      showFToast(context: sheetContext, title: const Text('Event name is required.'));
      return;
    }
    final startText = _startDateController.text;
    final startDate = startText.isNotEmpty ? '${startText}T00:00:00.000Z' : null;

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    if (startDate != null && DateTime.parse(startDate).isBefore(today)) {
      showFToast(context: sheetContext, title: const Text('Event start date cannot be in the past.'));
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
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      await _loadEvents();
      if (mounted) {
        showFToast(context: context, title: const Text('Event updated.'));
      }
    } catch (_) {
      if (sheetContext.mounted) {
        showFToast(context: sheetContext, title: const Text('Server error — please try again.'));
      }
    }
  }

  void _showEventActionsSheet(Event event) {
    showFSheet(
      context: context,
      side: FLayout.btt,
      builder: (ctx) => _buildEventActionsContent(ctx, event),
    );
  }

  Widget _buildEventActionsContent(BuildContext ctx, Event event) {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.colors.secondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: context.theme.colors.border)),
      ),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                _buildActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit Event',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showEditEventSheet(event);
                  },
                ),
                const SizedBox(height: 4),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share Event',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    final start = event.startDate;
                    final dateStr = event.endDate == null
                        ? '${months[start.month - 1]} ${start.day}, ${start.year}'
                        : '${months[start.month - 1]} ${start.day} - ${months[event.endDate!.month - 1]} ${event.endDate!.day}, ${start.year}';
                    final text = '${event.name}\n$dateStr${event.location != null ? '\n${event.location}' : ''}';
                    Clipboard.setData(ClipboardData(text: text));
                    if (mounted) {
                      showFToast(context: context, title: const Text('Event details copied to clipboard.'));
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: FDivider(),
                ),
                _buildActionButton(
                  icon: Icons.delete_outlined,
                  label: 'Delete Event',
                  isDestructive: true,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await ApiService.deleteEvent(event.id);
                      await _loadEvents();
                      if (mounted) {
                        showFToast(context: context, title: const Text('Event deleted.'));
                      }
                    } catch (e) {
                      if (mounted) {
                        showFToast(context: context, title: Text('Failed to delete event: $e'));
                      }
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

    return FButton(
      variant: FButtonVariant.ghost,
      onPress: onTap,
      prefix: Icon(icon, size: 20, color: color),
      child: Expanded(
        child: Text(
          label,
          style: context.theme.typography.lg.copyWith(
            fontWeight: FontWeight.w400,
            color: color,
          ),
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
        const SizedBox(height: 10),
        SkeletonLoader(
          width: 250,
          height: 12,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 18),
        SkeletonLoader(
          width: double.infinity,
          height: 58,
          borderRadius: BorderRadius.circular(22),
        ),
        const SizedBox(height: 26),
        SkeletonLoader(
          width: double.infinity,
          height: 48,
          borderRadius: BorderRadius.circular(999),
        ),
        const SizedBox(height: 18),
        const SkeletonCard(),
        const SizedBox(height: 28),
        const SkeletonCard(),
        const SizedBox(height: 28),
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

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    IconData? icon,
  }) {
    return AppInput(
      label: label,
      hint: placeholder,
      controller: controller,
      prefixIcon: icon != null ? Icon(icon, size: 20, color: context.theme.colors.primary) : null,
    );
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
    return Container(
      decoration: BoxDecoration(
        color: context.theme.colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: context.theme.colors.border)),
      ),
      child: SingleChildScrollView(
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
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.48,
                      color: context.theme.colors.foreground,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fill in the details to schedule a new event.',
                    style: context.theme.typography.sm.copyWith(
                      fontWeight: FontWeight.w400,
                      color: context.theme.colors.mutedForeground,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildFormField(
                    label: 'Event Name',
                    controller: widget.nameController,
                    placeholder: 'e.g. AI Innovation Summit 2025',
                  ),
                  const SizedBox(height: 18),
                  _buildFormField(
                    label: 'Location',
                    controller: widget.locationController,
                    placeholder: 'Search for a venue or city',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 18),
                  _buildDateField(label: 'Start Date', controller: widget.startDateController),
                  const SizedBox(height: 14),
                  FCheckbox(
                    value: _isOneDay,
                    label: Text(
                      'One-day event',
                      style: context.theme.typography.sm.copyWith(
                        fontWeight: FontWeight.w400,
                        color: context.theme.colors.mutedForeground,
                      ),
                    ),
                    onChange: (val) => setState(() {
                      _isOneDay = val;
                      if (_isOneDay) widget.endDateController.clear();
                    }),
                  ),
                  if (!_isOneDay) ...[
                    const SizedBox(height: 14),
                    _buildDateField(label: 'End Date', controller: widget.endDateController),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FButton(
                      variant: FButtonVariant.primary,
                      onPress: () => widget.onSave(_isOneDay),
                      child: Text(
                        widget.saveLabel,
                        style: context.theme.typography.xs.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FButton(
                      variant: FButtonVariant.outline,
                      onPress: widget.onCancel,
                      child: Text(
                        'CANCEL',
                        style: context.theme.typography.xs.copyWith(
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
