import 'package:flutter/material.dart';

import '../config/app_theme.dart';
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

  late final TextEditingController _eventNameController;
  late final TextEditingController _locationController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  String _selectedCategory = 'SaaS';

  @override
  void initState() {
    super.initState();
    _eventNameController = TextEditingController();
    _locationController = TextEditingController();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _locationController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  static const List<_UpcomingEventData> _upcomingEvents = [
    _UpcomingEventData(
      category: 'Flagship Summit',
      title: 'Global Tech Summit 2024',
      date: 'Oct 14 - 18, 2024',
      location: 'San Francisco, CA',
      progress: 0.60,
      floorData: EventFloorHomeData(
        title: 'Tech Summit 2024',
        venueLabel: 'Convention Center',
        hallLabel: 'Hall 4',
        targetReachLabel: '84%',
        scannedCountLabel: '142',
        targetsLeftLabel: '12',
        pendingFollowUpsLabel: '08',
        priorityTargets: [
          EventFloorPriorityTarget(
            rank: 1,
            name: 'Sarah Jenkins',
            subtitle: 'VP Growth, NeoStream',
            booth: 'Booth 402',
          ),
          EventFloorPriorityTarget(
            rank: 2,
            name: 'Marcus Thorne',
            subtitle: 'CTO, CloudScale Systems',
            booth: 'Booth 12B',
          ),
          EventFloorPriorityTarget(
            rank: 3,
            name: 'Elena Rodriguez',
            subtitle: 'Managing Director, Futura',
            booth: 'Booth 219',
          ),
        ],
      ),
      prepData: PreEventPrepData(
        shortTitle: 'Global Tech Summit',
        title: 'Global Tech Summit 2024',
        countdownLabel: 'In 12 Days',
        location: 'San Francisco, CA',
        dateRange: 'Oct 14 — Oct 18',
        researchedTargets: 24,
        totalTargets: 40,
        progress: 0.60,
        targets: [
          PrepTargetCompany(
            initials: 'NV',
            name: 'Novatech Systems',
            booth: '#402',
            tags: ['Enterprise AI', 'Germany'],
            industry: 'Industrial Automation Specialists',
            talkingPoints: [
              "Released 'Titan-9' chipsets last month; mention integration with legacy ERP systems for immediate credibility.",
              'CEO Marcus Vane emphasized "Sustainable Scale" in a recent earnings call; align the pitch with their carbon-neutral goals.',
              'Currently expanding into EMEA markets; EXONO\'s logistics module addresses their Berlin bottleneck.',
            ],
            imageUrl:
                'https://lh3.googleusercontent.com/aida-public/AB6AXuDidlz0O7qGyU5ovGeQchh-EXW8sxZeVP1z3XE75Ew9Ktf-B497_pTnusJ01EI0Pah5w98JJZ5v3HN2UNpd5sOBxnX_69P5V_KR8B4B-vhKCc5jd7BSwGTPhxAOeysoqhZK-3ll3CMK00FtXIttOj1WgIk8cayDdQUYwIWtpAD09byCUJ9lIudPdCWS96voeQZ7XWro3iq1ZAhsCZuPID4I3W4cU8b8V9C5MnyLkjLS-tt5z5O3Mlnc4x6sW0PDOZlEieqdhUT81mQ',
          ),
          PrepTargetCompany(
            initials: 'LX',
            name: 'Lumina X',
            booth: '#118',
            tags: ['Robotics', 'Japan'],
            industry: 'Next-gen Robotics Platform',
            talkingPoints: [
              'Lead with field-orchestration efficiency for distributed robotic fleets.',
              'They are evaluating North America expansion partners after the Osaka launch.',
              'Keep examples tactile and operations-focused rather than speculative AI positioning.',
            ],
            imageUrl:
                'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80',
          ),
          PrepTargetCompany(
            initials: 'SD',
            name: 'SkyData Corp',
            booth: '#922',
            tags: ['Cloud Infra', 'USA'],
            industry: 'Cloud Infrastructure Operator',
            talkingPoints: [
              'Their current talking point is lowering latency across multi-region workloads.',
              'Reference EXONO\'s edge-handshake architecture and deployment visibility.',
              'Best entry point is through cost predictability and resilience metrics.',
            ],
            imageUrl:
                'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=300&q=80',
          ),
        ],
      ),
    ),
    _UpcomingEventData(
      category: 'SaaS & Enterprise',
      title: 'Money20/20',
      date: 'Oct 22 - 25, 2024',
      location: 'Las Vegas, NV',
      progress: 0.40,
      prepData: PreEventPrepData(
        shortTitle: 'Money20/20',
        title: 'Money20/20 2024',
        countdownLabel: 'In 18 Days',
        location: 'Las Vegas, NV',
        dateRange: 'Oct 22 — Oct 25',
        researchedTargets: 11,
        totalTargets: 32,
        progress: 0.34,
        targets: [
          PrepTargetCompany(
            initials: 'QF',
            name: 'Quantum Finance',
            booth: '#A12',
            tags: ['FinTech', 'USA'],
            industry: 'Payments Infrastructure',
            talkingPoints: [
              'They are prioritizing transaction monitoring modernization this quarter.',
              'Lead with compliance observability instead of generic AI acceleration.',
              'Reference how EXONO reduces operational drag for high-volume event pipelines.',
            ],
            imageUrl:
                'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&w=300&q=80',
          ),
          PrepTargetCompany(
            initials: 'AC',
            name: 'Atlas Capital',
            booth: '#B09',
            tags: ['Investor', 'UK'],
            industry: 'Growth Investment Firm',
            talkingPoints: [
              'They favor concise commercial traction narratives.',
              'Bring customer expansion proof-points, not product taxonomy.',
            ],
            imageUrl:
                'https://images.unsplash.com/photo-1504593811423-6dd665756598?auto=format&fit=crop&w=300&q=80',
          ),
        ],
      ),
    ),
    _UpcomingEventData(
      category: 'AI & Research',
      title: 'NeurIPS 2024',
      date: 'Dec 10 - 15, 2024',
      location: 'Vancouver, Canada',
      progress: 0.12,
      prepData: PreEventPrepData(
        shortTitle: 'NeurIPS',
        title: 'NeurIPS 2024',
        countdownLabel: 'In 58 Days',
        location: 'Vancouver, Canada',
        dateRange: 'Dec 10 — Dec 15',
        researchedTargets: 4,
        totalTargets: 28,
        progress: 0.12,
        targets: [
          PrepTargetCompany(
            initials: 'OR',
            name: 'Open Research Labs',
            booth: '#N07',
            tags: ['Research', 'Canada'],
            industry: 'Applied ML Research Group',
            talkingPoints: [
              'Strong angle around reproducible deployment and experiment handoff.',
              'They have publicly discussed inference governance in production settings.',
            ],
            imageUrl:
                'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80',
          ),
        ],
      ),
    ),
  ];

  static const List<_PastEventData> _pastEvents = [
    _PastEventData(
      title: 'CES 2024',
      dateLocation: 'Jan 9 - 12, 2024 • Las Vegas, NV',
      contactsScanned: 89,
      followUpCompletion: 0.65,
    ),
    _PastEventData(
      title: 'Mobile World Congress',
      dateLocation: 'Feb 26 - 29, 2024 • Barcelona, Spain',
      contactsScanned: 54,
      followUpCompletion: 0.48,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _c.background,
      child: Column(
        children: [
          AppHeader(
            onNotificationPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications are UI-only for now.'), behavior: SnackBarBehavior.floating),
            ),
            actionIcon: Icons.add_rounded,
            actionTooltip: 'Add Event',
            onActionPressed: _showNewEventForm,
          ),
          Expanded(
            child: SingleChildScrollView(
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
                  ] else ...[
                    ..._pastEvents.map(
                      (event) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildPastEventCard(event),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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
          '12 TOTAL SCHEDULED EVENTS',
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
                    offset: Offset(0, 6),
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

  Widget _buildUpcomingEventCard(_UpcomingEventData event) {
    final progressPercent = (event.progress * 100).round();

    return InkWell(
      onTap: event.floorData == null ? null : () => _openEventFloor(event),
      borderRadius: BorderRadius.circular(28),
      child: AppCard(
        padding: const EdgeInsets.all(24),
        radius: 28,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppChip(event.category),
                    if (event.floorData != null) ...[
                      const SizedBox(height: 10),
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
                    ],
                  ],
                ),
                const Spacer(),
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
            const SizedBox(height: 24),
            Text(
              event.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: _c.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildUpcomingMetaRow(Icons.calendar_today_outlined, event.date),
            const SizedBox(height: 10),
            _buildUpcomingMetaRow(Icons.location_on_outlined, event.location),
            const SizedBox(height: 28),
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
                  widthFactor: event.progress,
                  child: Container(color: _c.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () => _openPrepScreen(event),
                style: FilledButton.styleFrom(
                  backgroundColor: _c.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'PREPARE',
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
      ),
    );
  }

  Widget _buildPastEventCard(_PastEventData event) {
    final completionPercent = (event.followUpCompletion * 100).round();

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
                        event.title,
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
            event.dateLocation,
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
                    '${event.contactsScanned}',
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
                          '$completionPercent%',
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
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: event.followUpCompletion,
                          child: Container(color: _c.textPrimary),
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
                      _showUiOnlyMessage('View contacts for ${event.title}'),
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
                  onPressed: () => _openFollowUpQueue(),
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

  void _openFollowUpQueue() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FollowUpsScreen(
          onNavigateTab: widget.onNavigateTab,
        ),
      ),
    );
  }

  void _openPrepScreen(_UpcomingEventData event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PreEventPrepScreen(
          data: event.prepData,
          onNavigateTab: widget.onNavigateTab,
        ),
      ),
    );
  }

  void _openEventFloor(_UpcomingEventData event) {
    if (event.floorData == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventFloorHomeScreen(
          data: event.floorData!,
          onNavigateTab: widget.onNavigateTab,
        ),
      ),
    );
  }

  void _showNewEventSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildNewEventSheet(),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    );
  }

  Widget _buildNewEventSheet() {
    const List<String> categories = [
      'SaaS',
      'Fintech',
      'AI',
      'Healthcare',
      'Energy',
      'Manufacturing',
      'Other',
    ];

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
                  decoration: BoxDecoration(
                    color: _c.border,
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
                    'New Event',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.48,
                      color: _c.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fill in the details to schedule a new industry gathering.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _c.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildFormField(
                    label: 'Event Name',
                    controller: _eventNameController,
                    placeholder: 'e.g. AI Innovation Summit 2024',
                  ),
                  const SizedBox(height: 18),
                  _buildFormField(
                    label: 'Location',
                    controller: _locationController,
                    placeholder: 'Search for a venue or city',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateField(
                          label: 'Start Date',
                          controller: _startDateController,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDateField(
                          label: 'End Date',
                          controller: _endDateController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildCategoryDropdown(categories),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showUiOnlyMessage('Event created');
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _c.textPrimary,
                        foregroundColor: _c.background,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                        ),
                      ),
                      child: const Text('SAVE EVENT'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _c.textSecondary,
                        side: BorderSide(color: _c.border),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.6,
                        ),
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _c.textPrimary,
          ),
          cursorColor: _c.accent,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _c.border,
            ),
            prefixIcon: icon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(icon, size: 20, color: _c.textSecondary),
                  )
                : null,
            prefixIconConstraints:
                icon != null ? const BoxConstraints(minWidth: 0) : null,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _c.accent),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: _c.surface,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
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
          readOnly: true,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _c.textPrimary,
          ),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2024),
              lastDate: DateTime(2026),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: _c.accent,
                      surface: _c.surface,
                      onSurface: _c.textPrimary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              controller.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            }
          },
          decoration: InputDecoration(
            hintText: 'YYYY-MM-DD',
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _c.border,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: _c.textSecondary,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _c.accent),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: _c.surface,
          ),
          cursorColor: _c.accent,
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(List<String> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.4,
            color: _c.textSecondary,
            height: 1.33,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButton<String>(
            value: _selectedCategory,
            items: categories
                .map(
                  (cat) => DropdownMenuItem(
                    value: cat,
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _c.textPrimary,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedCategory = value);
              }
            },
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _c.textPrimary,
            ),
            dropdownColor: _c.surface,
            icon: Icon(Icons.expand_more, color: _c.textSecondary),
            isExpanded: true,
            underline: const SizedBox(),
          ),
        ),
      ],
    );
  }

  void _showEventActionsSheet(_UpcomingEventData event) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildEventActionsSheet(),
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    );
  }

  Widget _buildEventActionsSheet() {
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
                    _showUiOnlyMessage('Edit event');
                  },
                ),
                const SizedBox(height: 4),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share Event',
                  onTap: () {
                    Navigator.of(context).pop();
                    _showUiOnlyMessage('Share event');
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: _c.border.withValues(alpha: 0.5), height: 1),
                ),
                _buildActionButton(
                  icon: Icons.delete_outlined,
                  label: 'Delete Event',
                  isDestructive: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    _showUiOnlyMessage('Delete event');
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

class _UpcomingEventData {
  final String category;
  final String title;
  final String date;
  final String location;
  final double progress;
  final EventFloorHomeData? floorData;
  final PreEventPrepData prepData;

  const _UpcomingEventData({
    required this.category,
    required this.title,
    required this.date,
    required this.location,
    required this.progress,
    this.floorData,
    required this.prepData,
  });
}

class _PastEventData {
  final String title;
  final String dateLocation;
  final int contactsScanned;
  final double followUpCompletion;

  const _PastEventData({
    required this.title,
    required this.dateLocation,
    required this.contactsScanned,
    required this.followUpCompletion,
  });
}
