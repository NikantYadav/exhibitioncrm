import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_section_label.dart';
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
  final EventFloorHomeData data;
  final ValueChanged<int>? onNavigateTab;

  const EventFloorHomeScreen({
    super.key,
    required this.data,
    this.onNavigateTab,
  });

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
    final colors = AppTheme.colorsOf(context);
    return Scaffold(
      backgroundColor: colors.background,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 4,
        onNavigate: (i) {
          Navigator.of(context).pop();
          onNavigateTab?.call(i);
        },
      ),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 64),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => showLogInteractionSheet(context),
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(Icons.chat_bubble_outline, size: 20),
            label: Text(
              'LOG INTERACTION',
              style: TextStyle(
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
    final colors = AppTheme.colorsOf(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.30)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 20,
            icon: Icon(Icons.menu, color: colors.textPrimary),
          ),
          Expanded(
            child: Center(
              child: Text(
                'EXONO',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showUiOnlyMessage(context, 'Notifications'),
            splashRadius: 20,
            icon: Icon(Icons.notifications, color: colors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.20)),
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
                      decoration: BoxDecoration(
                        color: colors.destructive,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'LIVE NOW',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.3,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  data.title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                    color: colors.textPrimary,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${data.venueLabel} • ${data.hallLabel}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: colors.textMuted,
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
                        color: colors.border.withValues(alpha: 0.20),
                      ),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 560;
                      final children = [
                        _buildStatTile(
                          'Target Reach',
                          data.targetReachLabel,
                          colors,
                        ),
                        _buildStatTile(
                          'Scanned',
                          data.scannedCountLabel,
                          colors,
                        ),
                        _buildStatTile(
                          'Targets Left',
                          data.targetsLeftLabel,
                          colors,
                        ),
                        _buildStatTile(
                          'Pending Follow-Ups',
                          data.pendingFollowUpsLabel,
                          colors,
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

  Widget _buildStatTile(String label, String value, ExonoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionLabel(label, letterSpacing: 1.0),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityTargetsSection(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Priority Targets',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showUiOnlyMessage(context, 'View target list'),
              style: TextButton.styleFrom(
                foregroundColor: colors.textMuted,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'VIEW LIST',
                style: TextStyle(
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
    final colors = AppTheme.colorsOf(context);
    return InkWell(
      onTap: () => _showUiOnlyMessage(context, 'Target profile'),
      borderRadius: BorderRadius.circular(12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        radius: 12,
        elevated: true,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                '${item.rank}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppChip(item.booth),
                const SizedBox(height: 6),
                Icon(Icons.chevron_right, color: colors.textMuted, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
