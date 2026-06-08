import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_header.dart';
import 'event_floor_home_screen.dart';
import 'follow_ups_screen.dart';
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
      setState(() {
        _events = events;
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
      color: _c.background,
      child: Column(
        children: [
          AppHeader(
            onNotificationPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications are UI-only for now.'),
                behavior: SnackBarBehavior.floating,
              ),
            ),
            actionIcon: Icons.add_rounded,
            actionTooltip: 'Add Event',
            onActionPressed: _showNewEventForm,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
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
            style: TextStyle(fontSize: 16, color: _c.textSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loadEvents,
            style: FilledButton.styleFrom(backgroundColor: _c.accent),
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
          style: TextStyle(fontSize: 14, color: _c.textMuted),
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
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.48,
            color: _c.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${_events.length} TOTAL SCHEDULED EVENTS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 3.2,
            color: _c.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildNewEventButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        onPressed: _showNewEventSheet,
        style: FilledButton.styleFrom(
          backgroundColor: _c.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 22),
            const SizedBox(width: 12),
            Text(
              'NEW EVENT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 3.2,
                color: Colors.white,
              ),
            ),
          ],
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
        border: Border.all(color: _c.border),
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
    return InkWell(
      onTap: () => setState(() => _showUpcoming = label == 'UPCOMING'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? _c.surface : Colors.transparent,
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: isActive ? _c.textPrimary : _c.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingEventCard(Event event) {
    final progress = event.prepProgress ?? 0.0;
    final progressPercent = (progress * 100).round();
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
                    color: _c.destructive,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'LIVE FLOOR AVAILABLE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: _c.textPrimary,
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: _c.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showEventActionsSheet(event),
                child: Icon(
                  Icons.more_vert,
                  color: _c.textSecondary,
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
          Row(
            children: [
              Expanded(
                child: Text(
                  'PREPARATION STATUS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                    color: _c.textSecondary,
                  ),
                ),
              ),
              Text(
                '$progressPercent%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 2,
            color: _c.surfaceElevated,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(color: _c.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: () => isOngoing ? _openEventFloor(event) : _openPrepScreen(event),
              style: FilledButton.styleFrom(
                backgroundColor: _c.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: Text(
                isOngoing ? 'ENTER LIVE FLOOR' : 'PREPARE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.4,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPastEventCard(Event event) {
    final dateLocation =
        '${_formatDateRange(event.startDate, event.endDate)}${event.location != null ? ' • ${event.location}' : ''}';

    return AppCard(
      padding: const EdgeInsets.all(24),
      radius: 28,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        event.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: _c.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppChip('COMPLETED'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            dateLocation,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _c.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONTACTS SCANNED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.1,
                      color: _c.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '0',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: _c.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'FOLLOW-UP COMPLETION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.0,
                              color: _c.textMuted,
                            ),
                          ),
                        ),
                        Text(
                          '0%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _c.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 4,
                      color: _c.border,
                      child: const Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: 0.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      _showUiOnlyMessage('View contacts for ${event.name}'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _c.border),
                    backgroundColor: _c.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'VIEW CONTACTS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.6,
                      color: _c.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openFollowUpQueue(event.id),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _c.accent),
                    backgroundColor: _c.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'FOLLOW-UP QUEUE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.4,
                      color: _c.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingMetaRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: _c.textSecondary, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _c.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  void _openFollowUpQueue(String eventId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FollowUpsScreen(
          onNavigateTab: widget.onNavigateTab,
          eventId: eventId,
        ),
      ),
    );
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventFloorHomeScreen(
          event: event,
          onNavigateTab: widget.onNavigateTab,
        ),
      ),
    );
  }

  void _showNewEventSheet() {
    _eventNameController.clear();
    _locationController.clear();
    _startDateController.clear();
    _endDateController.clear();

    showModalBottomSheet(
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    );
  }

  Future<void> _saveEvent(BuildContext sheetContext, bool isOneDay) async {
    final name = _eventNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(
          content: Text('Event name is required.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final startText = _startDateController.text;
    final startDate = startText.isNotEmpty
        ? '${startText}T00:00:00.000Z'
        : DateTime.now().toIso8601String();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event created successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (sheetContext.mounted) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          const SnackBar(
            content: Text('Server error — please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
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

    showModalBottomSheet(
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
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    );
  }

  Future<void> _updateEvent(BuildContext sheetContext, String eventId, bool isOneDay) async {
    final name = _eventNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        const SnackBar(content: Text('Event name is required.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final startText = _startDateController.text;
    final startDate = startText.isNotEmpty ? '${startText}T00:00:00.000Z' : null;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated.'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (_) {
      if (sheetContext.mounted) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          const SnackBar(content: Text('Server error — please try again.'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _showEventActionsSheet(Event event) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildEventActionsSheet(event),
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    );
  }

  Widget _buildEventActionsSheet(Event event) {
    return Container(
      decoration: BoxDecoration(
        color: _c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: _c.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _c.border,
                borderRadius: BorderRadius.circular(2),
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
                    Navigator.of(context).pop();
                    _showEditEventSheet(event);
                  },
                ),
                const SizedBox(height: 4),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share Event',
                  onTap: () {
                    Navigator.of(context).pop();
                    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    final start = event.startDate;
                    final dateStr = event.endDate == null
                        ? '${months[start.month - 1]} ${start.day}, ${start.year}'
                        : '${months[start.month - 1]} ${start.day} - ${months[event.endDate!.month - 1]} ${event.endDate!.day}, ${start.year}';
                    final text = '${event.name}\n$dateStr${event.location != null ? '\n${event.location}' : ''}';
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Event details copied to clipboard.'), behavior: SnackBarBehavior.floating),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(
                    color: _c.border.withValues(alpha: 0.5),
                    height: 1,
                  ),
                ),
                _buildActionButton(
                  icon: Icons.delete_outlined,
                  label: 'Delete Event',
                  isDestructive: true,
                  onTap: () async {
                    Navigator.of(context).pop();
                    try {
                      await ApiService.deleteEvent(event.id);
                      await _loadEvents();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Event deleted.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to delete event: $e'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
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
    final color = isDestructive ? _c.destructive : _c.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUiOnlyMessage(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label is UI-only for now.'),
        behavior: SnackBarBehavior.floating,
      ),
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
  ExonoColors get _c => widget.colors;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.4,
            color: _c.textSecondary,
            height: 1.33,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(fontSize: 14, color: _c.textPrimary),
          cursorColor: _c.accent,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(fontSize: 14, color: _c.border),
            prefixIcon: icon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(icon, size: 20, color: _c.textSecondary),
                  )
                : null,
            prefixIconConstraints: icon != null ? const BoxConstraints(minWidth: 0) : null,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.accent)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: _c.surface,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({required String label, required TextEditingController controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 2.4, color: _c.textSecondary, height: 1.33),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          style: TextStyle(fontSize: 14, color: _c.textPrimary),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.dark(primary: _c.accent, surface: _c.surface, onSurface: _c.textPrimary),
                ),
                child: child!,
              ),
            );
            if (date != null) {
              controller.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            }
          },
          decoration: InputDecoration(
            hintText: 'YYYY-MM-DD',
            hintStyle: TextStyle(fontSize: 14, color: _c.border),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(Icons.calendar_today_outlined, size: 18, color: _c.textSecondary),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.accent)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: _c.surface,
          ),
          cursorColor: _c.accent,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: _c.border)),
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
                  decoration: BoxDecoration(color: _c.border, borderRadius: BorderRadius.circular(2)),
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
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.48, color: _c.textPrimary, height: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fill in the details to schedule a new event.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: _c.textSecondary, height: 1.5),
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
                  InkWell(
                    onTap: () => setState(() {
                      _isOneDay = !_isOneDay;
                      if (_isOneDay) widget.endDateController.clear();
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _isOneDay ? _c.accent : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _isOneDay ? _c.accent : _c.border, width: 1.5),
                            ),
                            child: _isOneDay
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'One-day event',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: _c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!_isOneDay) ...[
                    const SizedBox(height: 14),
                    _buildDateField(label: 'End Date', controller: widget.endDateController),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => widget.onSave(_isOneDay),
                      style: FilledButton.styleFrom(
                        backgroundColor: _c.textPrimary,
                        foregroundColor: _c.background,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2.0),
                      ),
                      child: Text(widget.saveLabel),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _c.textSecondary,
                        side: BorderSide(color: _c.border),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 1.6),
                      ),
                      child: const Text('CANCEL'),
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
