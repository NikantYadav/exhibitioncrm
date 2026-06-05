import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'log_interaction_screen.dart';
import 'main_screen.dart';

class HomeDefaultScreen extends StatefulWidget {
  const HomeDefaultScreen({super.key});

  @override
  State<HomeDefaultScreen> createState() => _HomeDefaultScreenState();
}

class _HomeDefaultScreenState extends State<HomeDefaultScreen> {
  static const Color _background = Color(0xFF141313);
  static const Color _surface = Color(0xFF201F1F);
  static const Color _surfaceLow = Color(0xFF1C1B1B);
  static const Color _surfaceLowest = Color(0xFF0E0E0E);
  static const Color _outlineVariant = Color(0xFF444748);
  static const Color _primary = Colors.white;
  static const Color _onSurface = Color(0xFFE5E2E1);
  static const Color _onSurfaceVariant = Color(0xFFC4C7C8);

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
      subtitle: 'Mentioned “Q3 Expansion” in LinkedIn post',
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
      backgroundColor: _background,
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
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.0,
                        color: _primary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your professional network is ready.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAiCard(),
                    const SizedBox(height: 24),
                    Text(
                      'Today\'s Priorities'.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: _onSurfaceVariant,
                      ),
                    ),
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
                    Text(
                      'Network Insights'.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: _onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._insights.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildInsightCard(item),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Upcoming Events'.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: _onSurfaceVariant,
                      ),
                    ),
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
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: _background,
        border: Border(bottom: BorderSide(color: _outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.menu_rounded, color: _primary, size: 22),
          const SizedBox(width: 14),
          Text(
            'EXONO',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: _primary,
              height: 1,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () =>
                _showUiOnlyMessage('Notifications are UI-only for now.'),
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: _primary,
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surfaceLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _outlineVariant),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -8,
                top: -12,
                child: Icon(
                  Icons.psychology_alt_rounded,
                  size: 120,
                  color: _primary.withValues(alpha: 0.08),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXONO AI INTELLIGENCE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'How can I assist your network today?',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.8,
                      color: _primary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _outlineVariant),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        const Icon(
                          Icons.search_rounded,
                          color: _onSurfaceVariant,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onSubmitted: (value) {
                              if (value.trim().isEmpty) return;
                              _showUiOnlyMessage(
                                'Search for “${value.trim()}” is UI-only for now.',
                              );
                            },
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: _onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search contacts, notes, or ask AI...',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 14,
                                color: _onSurfaceVariant,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _showUiOnlyMessage(
                            'Voice input is UI-only for now.',
                          ),
                          icon: const Icon(
                            Icons.mic_none_rounded,
                            color: _onSurfaceVariant,
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
                                border: Border.all(color: _outlineVariant),
                              ),
                              child: Text(
                                prompt,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: _onSurfaceVariant,
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
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: _background,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primary, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(_InsightCardData item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _outlineVariant),
                ),
                alignment: Alignment.center,
                child: item.useIconAvatar
                    ? Icon(item.icon, color: _onSurfaceVariant, size: 22)
                    : Text(
                        item.avatarLabel,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _primary,
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
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _onSurfaceVariant,
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
                    foregroundColor: _primary,
                    side: const BorderSide(color: _outlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    item.actionPrimary,
                    style: GoogleFonts.inter(
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
                  foregroundColor: _primary,
                  side: const BorderSide(color: _outlineVariant),
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
                  style: GoogleFonts.inter(
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.only(right: 12),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: _outlineVariant)),
            ),
            child: Column(
              children: [
                Text(
                  event.month,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: _onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.day,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _primary,
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
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _onSurfaceVariant,
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

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _background,
        border: Border(top: BorderSide(color: _outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              Expanded(
                child: _buildBottomItem(
                  icon: Icons.track_changes_outlined,
                  label: 'Targets',
                  isActive: true,
                  onTap: () =>
                      Navigator.of(context).pushReplacementNamed('/main'),
                ),
              ),
              Expanded(
                child: _buildBottomItem(
                  icon: Icons.group_outlined,
                  label: 'Contacts',
                  onTap: () => _showUiOnlyMessage(
                    'Contacts shortcut returns to the main shell in this preview.',
                  ),
                ),
              ),
              SizedBox(
                width: 78,
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -18),
                    child: InkWell(
                      onTap: () =>
                          _showUiOnlyMessage('Scanner is UI-only for now.'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x80000000),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: _background,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _buildBottomItem(
                  icon: Icons.calendar_today_outlined,
                  label: 'Events',
                  onTap: () => _showUiOnlyMessage(
                    'Events shortcut returns to the main shell in this preview.',
                  ),
                ),
              ),
              Expanded(
                child: _buildBottomItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const MainScreen(initialIndex: 5),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomItem({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: isActive ? _primary : _onSurfaceVariant),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? _primary : _onSurfaceVariant,
              height: 1,
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
