import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_card.dart';
import '../widgets/app_section_label.dart';
import 'log_interaction_screen.dart';

class HomeDefaultScreen extends StatefulWidget {
  const HomeDefaultScreen({super.key});

  @override
  State<HomeDefaultScreen> createState() => _HomeDefaultScreenState();
}

class _HomeDefaultScreenState extends State<HomeDefaultScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  final TextEditingController _searchController = TextEditingController();

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
    _EventCardData(
      'OCT',
      '24',
      'SaaS Connect 2024',
      'Networking Lounge • 10:00 AM',
    ),
    _EventCardData(
      'OCT',
      '27',
      'Private Equity Mixer',
      'The Ritz-Carlton • 6:30 PM',
    ),
    _EventCardData(
      'NOV',
      '02',
      'Growth Leaders Dinner',
      'Aria Suite • 8:00 PM',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showUiOnlyMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final firstName = auth.displayName.trim().split(RegExp(r'\s+')).first;

    return Scaffold(
      backgroundColor: _c.background,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 4,
        onNavigate: (i) => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _c.textMuted,
                        height: 1.4,
                      ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: _c.background,
        border: Border(bottom: BorderSide(color: _c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.menu_rounded, color: _c.textPrimary, size: 22),
          const SizedBox(width: 14),
          Text(
            'EXONO',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: _c.textPrimary,
              height: 1,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () =>
                _showUiOnlyMessage('Notifications are UI-only for now.'),
            icon: Icon(
              Icons.notifications_none_rounded,
              color: _c.textPrimary,
              size: 22,
            ),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildAiCard() {
    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(20),
          radius: 16,
          child: Stack(
            children: [
              Positioned(
                right: -8,
                top: -12,
                child: Icon(
                  Icons.psychology_alt_rounded,
                  size: 120,
                  color: _c.textPrimary.withValues(alpha: 0.08),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXONO AI INTELLIGENCE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: _c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'How can I assist your network today?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.8,
                      color: _c.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: _c.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _c.border),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        Icon(
                          Icons.search_rounded,
                          color: _c.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onSubmitted: (value) {
                              if (value.trim().isEmpty) return;
                              _showUiOnlyMessage(
                                'Search for "${value.trim()}" is UI-only for now.',
                              );
                            },
                            style: TextStyle(
                              fontSize: 14,
                              color: _c.textSecondary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search contacts, notes, or ask AI...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: _c.textMuted,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showUiOnlyMessage(
                            'Voice input is UI-only for now.',
                          ),
                          icon: Icon(
                            Icons.mic_none_rounded,
                            color: _c.textMuted,
                            size: 20,
                          ),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _promptChips
                        .map(
                          (prompt) => InkWell(
                            onTap: () {
                              setState(() => _searchController.text = prompt);
                            },
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: _c.border),
                              ),
                              child: Text(
                                prompt,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _c.textMuted,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
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
            label: Text(
              'LOG INTERACTION',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _c.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityTile({
    required IconData icon,
    required String value,
    required String label,
  }) {
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
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _c.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _c.textMuted,
                ),
              ),
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _c.textPrimary,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _c.textMuted,
                        height: 1.4,
                      ),
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
                  onPressed: () => _showUiOnlyMessage(
                    '${item.actionPrimary} is UI-only for now.',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _c.textPrimary,
                    side: BorderSide(color: _c.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    item.actionPrimary,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => _showUiOnlyMessage(
                  '${item.actionSecondary} is UI-only for now.',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _c.textPrimary,
                  side: BorderSide(color: _c.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  item.actionSecondary,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: _c.border)),
            ),
            child: Column(
              children: [
                Text(
                  event.month,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: _c.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.day,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _c.textPrimary,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _c.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
