import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_header.dart';
import '../widgets/app_section_label.dart';
import 'capture_screen.dart';
import 'chat_screen.dart';
import 'chat_history_screen.dart';
import 'contacts_screen.dart';
import 'events_screen.dart';
import 'log_interaction_screen.dart';
import 'profile_screen.dart';
import 'target_list_full_view_screen.dart';

class HomeDefaultScreen extends StatefulWidget {
  const HomeDefaultScreen({super.key});

  @override
  State<HomeDefaultScreen> createState() => _HomeDefaultScreenState();
}

class _HomeDefaultScreenState extends State<HomeDefaultScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  // AppBottomNav index (0=Home/Targets, 1=Events, 2=Capture, 3=Contacts, 5=Profile)
  int _navIndex = 0;
  bool _isLiveEvent = false;

  void _onNavigate(int index) => setState(() => _navIndex = index);

  // Maps AppBottomNav's sparse index to IndexedStack position
  int get _stackIndex {
    switch (_navIndex) {
      case 1: return 1;
      case 2: return 2;
      case 3: return 3;
      case 5: return 4;
      default: return 0;
    }
  }

  final List<String> _promptChips = const [
    'Draft follow-up for Sarah',
    'Analyze recent event leads',
    'Network health report',
  ];

  final List<_InsightCardData> _insights = const [
    _InsightCardData(
      title: 'David Chen',
      subtitle: 'Last active at Tech Summit • 12 days ago',
      avatarLabel: 'DC',
      actionPrimary: 'Draft Follow-Up',
      actionSecondary: 'More',
      icon: Icons.person_outline_rounded,
    ),
    _InsightCardData(
      title: 'Cloud Architecture Cluster',
      subtitle: '5 new contacts found in shared circles',
      avatarLabel: 'CL',
      actionPrimary: 'Ask AI Strategy',
      actionSecondary: 'View Cluster',
      icon: Icons.hub_rounded,
      useIconAvatar: true,
    ),
    _InsightCardData(
      title: 'Sarah Jenkins',
      subtitle: 'Mentioned "Q3 Expansion" in LinkedIn post',
      avatarLabel: 'SJ',
      actionPrimary: 'Draft Follow-Up',
      actionSecondary: 'Signal',
      icon: Icons.bolt_rounded,
    ),
  ];

  final List<_EventCardData> _events = const [
    _EventCardData('OCT', '24', 'SaaS Connect 2024', 'Networking Lounge • 10:00 AM'),
    _EventCardData('OCT', '27', 'Private Equity Mixer', 'The Ritz-Carlton • 6:30 PM'),
    _EventCardData('NOV', '02', 'Growth Leaders Dinner', 'Aria Suite • 8:00 PM'),
  ];

  static const _liveEvent = _LiveEventData(
    title: 'Tech Summit 2024',
    venue: 'Convention Center',
    hall: 'Hall 4',
    targetReach: '84%',
    scanned: '142',
    targetsLeft: '12',
    pendingFollowUps: '08',
    goals: [
      _GoalItem('Secure 2 Pilot Demos', 2, 2),
      _GoalItem('Meet 5 VCs', 2, 5),
      _GoalItem('Keynote Attendance', 0, 3),
    ],
    targets: [
      _PriorityTarget(rank: 1, name: 'Sarah Jenkins', company: 'VP Growth, NeoStream', booth: 'BOOTH 402'),
      _PriorityTarget(rank: 2, name: 'Marcus Thorne', company: 'CTO, CloudScale Systems', booth: 'BOOTH 12B'),
      _PriorityTarget(rank: 3, name: 'Elena Rodriguez', company: 'Managing Director, Futura', booth: 'BOOTH 219'),
    ],
  );

  @override
  void dispose() {
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _openTargetList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TargetListFullViewScreen(
          onNavigateTab: _onNavigate,
          eventTitle: _liveEvent.title,
          countLabel: '${_liveEvent.targets.length} / 120',
          goals: _liveEvent.goals
              .map((g) => EventGoalData(label: g.label, current: g.current, target: g.total))
              .toList(),
          items: const [
            TargetListItemData(
              company: 'NeoStream',
              booth: 'BOOTH 402',
              sector: 'Growth',
              contact: 'Sarah Jenkins',
              title: 'VP Growth',
              score: 92,
              overview: 'High-growth SaaS platform focused on revenue intelligence and pipeline automation.',
              products: 'NeoStream CRM, Revenue Intelligence Suite, Pipeline AI',
              meetingObjective: 'Explore integration partnership for joint GTM.',
              notes: '',
              prepNotes: [
                'Company is in active vendor evaluation mode — move quickly.',
                'Sarah champions product-led growth; lead with self-serve metrics.',
              ],
              relationshipStrength: 0.55,
              isMet: false,
            ),
            TargetListItemData(
              company: 'CloudScale Systems',
              booth: 'BOOTH 12B',
              sector: 'Infrastructure',
              contact: 'Marcus Thorne',
              title: 'CTO',
              score: 85,
              overview: 'Enterprise cloud infrastructure platform offering managed Kubernetes, observability, and FinOps tooling.',
              products: 'CloudScale K8s, ObserveStack, FinOps Dashboard',
              meetingObjective: 'Discuss technical co-development and API partnership.',
              notes: '',
              prepNotes: [
                'Recently raised Series C — focused on enterprise expansion.',
                'CTO prefers technical depth; avoid high-level pitches.',
              ],
              relationshipStrength: 0.30,
              isMet: false,
            ),
            TargetListItemData(
              company: 'Futura',
              booth: 'BOOTH 219',
              sector: 'Consulting',
              contact: 'Elena Rodriguez',
              title: 'Managing Director',
              score: 78,
              overview: 'Global management consulting firm with a digital transformation practice serving F500 clients.',
              products: 'Digital Transformation Advisory, Data Strategy, AI Ops',
              meetingObjective: 'Position Exono as preferred tool for field intelligence engagements.',
              notes: '',
              prepNotes: [
                'Elena is an executive sponsor for three active transformation projects.',
                'Consulting firms value outcome metrics — lead with ROI data.',
              ],
              relationshipStrength: 0.20,
              isMet: false,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _navIndex,
        onNavigate: _onNavigate,
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _stackIndex,
          children: [
            // Tab 0 — Home
            Column(
              children: [
                AppHeader(
                  onNotificationPressed: () => _toast('Notifications are UI-only for now.'),
                  actionIcon: Icons.bolt_rounded,
                  actionTooltip: _isLiveEvent ? 'Exit live event' : 'Enter live event',
                  onActionPressed: () => setState(() => _isLiveEvent = !_isLiveEvent),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _isLiveEvent ? _buildLiveEventBody() : _buildNoEventBody(),
                  ),
                ),
              ],
            ),
            // Tab 1 — Events
            EventsScreen(onNavigateTab: _onNavigate),
            // Tab 2 — Capture
            CaptureScreen(onNavigateTab: _onNavigate),
            // Tab 3 — Contacts
            ContactsScreen(onNavigateTab: _onNavigate),
            // Tab 4 (nav index 5) — Profile
            ProfileScreen(onNavigateTab: _onNavigate),
          ],
        ),
      ),
    );
  }


  // ─── NO-EVENT BODY ──────────────────────────────────────────────────────────

  Widget _buildNoEventBody() {
    final auth = context.watch<AuthProvider>();
    final firstName = auth.displayName.trim().split(RegExp(r'\s+')).first;

    return SingleChildScrollView(
      key: const ValueKey('no-event'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good Morning, $firstName',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.0,
              color: _c.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your professional network is ready.',
            style: TextStyle(fontSize: 14, color: _c.textMuted, height: 1.4),
          ),
          const SizedBox(height: 24),
          _buildAiCard(),
          const SizedBox(height: 24),
          AppSectionLabel('Today\'s Priorities'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPriorityTile(
                  icon: Icons.schedule_rounded,
                  value: '3',
                  label: 'Follow-ups Due',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPriorityTile(
                  icon: Icons.history_rounded,
                  value: '4',
                  label: 'Contacts to Reconnect',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppSectionLabel('Network Insights'),
          const SizedBox(height: 12),
          ..._insights.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildInsightCard(item),
            ),
          ),
          const SizedBox(height: 12),
          AppSectionLabel('Upcoming Events'),
          const SizedBox(height: 12),
          ..._events.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildEventCard(event),
            ),
          ),
        ],
      ),
    );
  }

  void _openChat({String? initialMessage}) {
    if (initialMessage != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            initialMessage: initialMessage,
            isNewChat: true,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ChatHistoryScreen(),
        ),
      );
    }
  }

  Widget _buildAiCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.all(20),
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _c.accentSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        size: 16, color: _c.accent),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Assistant',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _c.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _c.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _c.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Tappable search bar
              GestureDetector(
                onTap: () => _openChat(),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: _c.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _c.border),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(Icons.search_rounded, color: _c.textMuted, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search contacts, events, or ask anything…',
                          style: TextStyle(fontSize: 13, color: _c.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.mic_none_rounded,
                            color: _c.border, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Prompt chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _promptChips
                    .map(
                      (prompt) => GestureDetector(
                        onTap: () => _openChat(initialMessage: prompt),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: _c.border),
                          ),
                          child: Text(
                            prompt,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _c.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => showLogInteractionSheet(context),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            label: const Text(
              'LOG INTERACTION',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _c.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityTile({required IconData icon, required String value, required String label}) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 12,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _c.textPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _c.textPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _c.textPrimary, height: 1),
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _c.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(_InsightCardData item) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      radius: 16,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _c.surfaceAlt,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _c.border),
                ),
                alignment: Alignment.center,
                child: item.useIconAvatar
                    ? Icon(item.icon, color: _c.textMuted, size: 22)
                    : Text(
                        item.avatarLabel,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _c.textPrimary),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _c.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _c.textMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _toast('${item.actionPrimary} is UI-only for now.'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _c.textPrimary,
                    side: BorderSide(color: _c.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(item.actionPrimary, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => _toast('${item.actionSecondary} is UI-only for now.'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _c.textPrimary,
                  side: BorderSide(color: _c.border),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(item.actionSecondary, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(_EventCardData event) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 12,
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(border: Border(right: BorderSide(color: _c.border))),
            child: Column(
              children: [
                Text(
                  event.month,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: _c.textMuted),
                ),
                const SizedBox(height: 4),
                Text(event.day, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _c.textPrimary, height: 1)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _c.textPrimary)),
                const SizedBox(height: 4),
                Text(event.subtitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _c.textMuted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── LIVE EVENT BODY ─────────────────────────────────────────────────────────

  Widget _buildLiveEventBody() {
    return SingleChildScrollView(
      key: const ValueKey('live-event'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEventBannerCard(),
          const SizedBox(height: 24),
          _buildPriorityTargetsSection(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showLogInteractionSheet(context),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
              label: const Text(
                'LOG INTERACTION',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _c.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventBannerCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: Container(
        decoration: BoxDecoration(
          color: _c.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          border: Border.all(color: _c.border.withValues(alpha: 0.3)),
        ),
        child: Stack(
          children: [
            // Decorative background gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _c.accentSoft.withValues(alpha: 0.3),
                      _c.surface,
                      _c.surfaceAlt,
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ),
                ),
              ),
            ),
            // Faint decorative icon
            Positioned(
              right: -16,
              top: -16,
              child: Icon(
                Icons.apartment_rounded,
                size: 160,
                color: _c.textPrimary.withValues(alpha: 0.04),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live badge
                  Row(
                    children: [
                      _PulsingDot(color: _c.destructive),
                      const SizedBox(width: 8),
                      Text(
                        'LIVE NOW',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.4,
                          color: _c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Event title
                  Text(
                    _liveEvent.title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: _c.textPrimary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Location
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: _c.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        '${_liveEvent.venue} • ${_liveEvent.hall}',
                        style: TextStyle(fontSize: 13, color: _c.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Stats grid
                  _buildStatsGrid(),
                  // Goal progress section
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      children: [
                        Divider(color: _c.border.withValues(alpha: 0.5), height: 1),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppSectionLabel('Goal Progress'),
                            GestureDetector(
                              onTap: _openTargetList,
                              child: Text(
                                'VIEW LIST',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  color: _c.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ..._liveEvent.goals.map(
                          (goal) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildGoalRow(goal),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      _StatItem('Target Reach', _liveEvent.targetReach),
      _StatItem('Scanned', _liveEvent.scanned),
      _StatItem('Targets Left', _liveEvent.targetsLeft),
      _StatItem('Pending Follow-Ups', _liveEvent.pendingFollowUps),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 420;
        if (wide) {
          return Row(
            children: [
              for (int i = 0; i < stats.length; i++) ...[
                Expanded(child: _buildStatTile(stats[i])),
                if (i < stats.length - 1)
                  Container(width: 1, height: 32, margin: const EdgeInsets.symmetric(horizontal: 12), color: _c.border),
              ],
            ],
          );
        }
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 12,
          childAspectRatio: 2.8,
          children: stats.map(_buildStatTile).toList(),
        );
      },
    );
  }

  Widget _buildStatTile(_StatItem stat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stat.label.toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: _c.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          stat.value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _c.textPrimary, height: 1),
        ),
      ],
    );
  }

  Widget _buildGoalRow(_GoalItem goal) {
    final progress = goal.progress;
    final isComplete = progress >= 1.0;
    final isNotStarted = progress == 0;

    final Color barColor = isComplete
        ? _c.success
        : isNotStarted
            ? _c.border
            : _c.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                goal.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isNotStarted ? _c.textMuted : _c.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${goal.current}/${goal.total}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isNotStarted ? _c.textMuted : _c.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: _c.surfaceElevated,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityTargetsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Priority Targets',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: _c.textPrimary),
              ),
            ),
            GestureDetector(
              onTap: _openTargetList,
              child: Text(
                'VIEW LIST',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: _c.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ..._liveEvent.targets.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: i < _liveEvent.targets.length - 1 ? 10 : 0),
            child: _buildTargetRow(item),
          );
        }),
      ],
    );
  }

  Widget _buildTargetRow(_PriorityTarget item) {
    return InkWell(
      onTap: () => _toast('Target profile is UI-only for now.'),
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        radius: AppTheme.radiusCard,
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _c.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _c.border),
              ),
              child: Text(
                '${item.rank}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _c.textPrimary),
              ),
            ),
            const SizedBox(width: 14),
            // Name + company
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _c.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(item.company, style: TextStyle(fontSize: 12, color: _c.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Booth chip + chevron
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppChip.label(item.booth),
                const SizedBox(height: 6),
                Icon(Icons.chevron_right_rounded, color: _c.textMuted, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pulsing dot ─────────────────────────────────────────────────────────────

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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

// ─── Data models ─────────────────────────────────────────────────────────────

class _InsightCardData {
  final String title;
  final String subtitle;
  final String avatarLabel;
  final String actionPrimary;
  final String actionSecondary;
  final IconData icon;
  final bool useIconAvatar;

  const _InsightCardData({
    required this.title,
    required this.subtitle,
    required this.avatarLabel,
    required this.actionPrimary,
    required this.actionSecondary,
    required this.icon,
    this.useIconAvatar = false,
  });
}

class _EventCardData {
  final String month;
  final String day;
  final String title;
  final String subtitle;
  const _EventCardData(this.month, this.day, this.title, this.subtitle);
}

class _LiveEventData {
  final String title;
  final String venue;
  final String hall;
  final String targetReach;
  final String scanned;
  final String targetsLeft;
  final String pendingFollowUps;
  final List<_GoalItem> goals;
  final List<_PriorityTarget> targets;

  const _LiveEventData({
    required this.title,
    required this.venue,
    required this.hall,
    required this.targetReach,
    required this.scanned,
    required this.targetsLeft,
    required this.pendingFollowUps,
    required this.goals,
    required this.targets,
  });
}

class _GoalItem {
  final String label;
  final int current;
  final int total;
  const _GoalItem(this.label, this.current, this.total);
  double get progress => total > 0 ? current / total : 0;
}

class _PriorityTarget {
  final int rank;
  final String name;
  final String company;
  final String booth;
  const _PriorityTarget({required this.rank, required this.name, required this.company, required this.booth});
}

class _StatItem {
  final String label;
  final String value;
  const _StatItem(this.label, this.value);
}
