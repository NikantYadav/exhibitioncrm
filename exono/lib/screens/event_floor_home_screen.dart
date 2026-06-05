import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'log_interaction_screen.dart';

class EventFloorPriorityTarget {
  final int rank;
  final String name;
  final String subtitle;
  final String booth;

  const EventFloorPriorityTarget({
    required this.rank,
    required this.name,
    required this.subtitle,
    required this.booth,
  });
}

class EventFloorHomeData {
  final String title;
  final String venueLabel;
  final String hallLabel;
  final String targetReachLabel;
  final String scannedCountLabel;
  final String targetsLeftLabel;
  final String pendingFollowUpsLabel;
  final List<EventFloorPriorityTarget> priorityTargets;

  const EventFloorHomeData({
    required this.title,
    required this.venueLabel,
    required this.hallLabel,
    required this.targetReachLabel,
    required this.scannedCountLabel,
    required this.targetsLeftLabel,
    required this.pendingFollowUpsLabel,
    required this.priorityTargets,
  });
}

class EventFloorHomeScreen extends StatelessWidget {
  static const Color _background = Color(0xFF080808);
  static const Color _surface = Color(0xFF141313);
  static const Color _surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color _surfaceContainerHighest = Color(0xFF353434);
  static const Color _outlineVariant = Color(0xFF444748);
  static const Color _primary = Colors.white;
  static const Color _onPrimary = Color(0xFF2F3131);
  static const Color _onSurfaceVariant = Color(0xFFC4C7C8);
  static const Color _error = Color(0xFFFFB4AB);

  final EventFloorHomeData data;
  final ValueChanged<int>? onNavigateTab;

  const EventFloorHomeScreen({
    super.key,
    required this.data,
    this.onNavigateTab,
  });

  void _navigate(BuildContext context, int index) {
    Navigator.of(context).pop();
    onNavigateTab?.call(index);
  }

  void _showUiOnlyMessage(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label is UI-only for now.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 180),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroCard(context),
                        const SizedBox(height: 24),
                        _buildPriorityTargetsSection(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 64),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => showLogInteractionSheet(context),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: _onPrimary,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
            label: Text(
              'LOG INTERACTION',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(color: _outlineVariant.withValues(alpha: 0.30)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 20,
            icon: const Icon(Icons.menu, color: _primary),
          ),
          Expanded(
            child: Center(
              child: Text(
                'EXONO',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  color: _primary,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showUiOnlyMessage(context, 'Notifications'),
            splashRadius: 20,
            icon: const Icon(Icons.notifications, color: _primary),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.04),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -10,
            top: -10,
            child: Icon(
              Icons.apartment_rounded,
              size: 180,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 120),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _error,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'LIVE NOW',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.3,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  data.title.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                    color: _primary,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: _onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${data.venueLabel} • ${data.hallLabel}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: _onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: _outlineVariant.withValues(alpha: 0.20),
                      ),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 560;
                      final children = [
                        _buildStatTile('Target Reach', data.targetReachLabel),
                        _buildStatTile('Scanned', data.scannedCountLabel),
                        _buildStatTile('Targets Left', data.targetsLeftLabel),
                        _buildStatTile(
                          'Pending Follow-Ups',
                          data.pendingFollowUpsLabel,
                        ),
                      ];

                      if (wide) {
                        return Row(
                          children: [
                            for (int i = 0; i < children.length; i++) ...[
                              Expanded(child: children[i]),
                              if (i < children.length - 1)
                                const SizedBox(width: 16),
                            ],
                          ],
                        );
                      }

                      return GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 2.2,
                        children: children,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: _onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _primary,
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityTargetsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Priority Targets',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showUiOnlyMessage(context, 'View target list'),
              style: TextButton.styleFrom(
                foregroundColor: _onSurfaceVariant,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'VIEW LIST',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...data.priorityTargets.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == data.priorityTargets.length - 1 ? 0 : 12,
            ),
            child: _buildPriorityRow(context, item),
          );
        }),
      ],
    );
  }

  Widget _buildPriorityRow(
    BuildContext context,
    EventFloorPriorityTarget item,
  ) {
    return InkWell(
      onTap: () => _showUiOnlyMessage(context, 'Target profile'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceContainerLow.withValues(alpha: 0.50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _outlineVariant.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _outlineVariant),
              ),
              child: Text(
                '${item.rank}',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _outlineVariant),
                  ),
                  child: Text(
                    item.booth.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Icon(
                  Icons.chevron_right,
                  color: _onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.90),
        border: Border(
          top: BorderSide(color: _outlineVariant.withValues(alpha: 0.20)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomItem(
              icon: Icons.gps_fixed,
              label: 'Targets',
              active: false,
              onTap: () => _navigate(context, 0),
            ),
            _buildBottomItem(
              icon: Icons.group_outlined,
              label: 'Contacts',
              active: false,
              onTap: () => _navigate(context, 3),
            ),
            Transform.translate(
              offset: const Offset(0, -10),
              child: InkWell(
                onTap: () => _navigate(context, 2),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _surface, width: 4),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: _onPrimary,
                    size: 28,
                  ),
                ),
              ),
            ),
            _buildBottomItem(
              icon: Icons.event,
              label: 'Events',
              active: true,
              onTap: () => Navigator.of(context).pop(),
            ),
            _buildBottomItem(
              icon: Icons.person_outline,
              label: 'Profile',
              active: false,
              onTap: () => _navigate(context, 5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomItem({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? _primary : _onSurfaceVariant, size: 22),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: active ? _primary : _onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
