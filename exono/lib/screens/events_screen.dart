import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import 'event_floor_home_screen.dart';
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
    );
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
        onPressed: () => _showUiOnlyMessage('New Event'),
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
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFB4AB),
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
                  onTap: () => _showUiOnlyMessage('Event actions'),
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
                  onPressed: () =>
                      _showUiOnlyMessage('Follow-up queue for ${event.title}'),
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
