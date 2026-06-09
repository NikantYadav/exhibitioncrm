import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_section_label.dart';
import '../widgets/skeleton_loader.dart';

class EventFloorHomeScreen extends StatefulWidget {
  final Event event;
  final ValueChanged<int>? onNavigateTab;

  const EventFloorHomeScreen({
    super.key,
    required this.event,
    this.onNavigateTab,
  });

  @override
  State<EventFloorHomeScreen> createState() => _EventFloorHomeScreenState();
}

class _EventFloorHomeScreenState extends State<EventFloorHomeScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _targets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getEventStats(widget.event.id),
        ApiService.getEventTargets(widget.event.id),
      ]);
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        final rawTargets = results[1] as List<Map<String, dynamic>>;
        rawTargets.sort((a, b) {
          const order = {'high': 0, 'medium': 1, 'low': 2};
          final aPrio = order[a['priority']] ?? 3;
          final bPrio = order[b['priority']] ?? 3;
          return aPrio.compareTo(bPrio);
        });
        _targets = rawTargets;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _showUiOnlyMessage(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label is UI-only for now.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _targetReachLabel {
    final total = (_stats?['total_contacts'] as num?)?.toInt() ?? 0;
    final captured = (_stats?['total_captures'] as num?)?.toInt() ?? 0;
    if (total == 0) return 'N/A';
    return '${((captured / total) * 100).round()}%';
  }

  String get _scannedLabel =>
      '${(_stats?['total_captures'] as num?)?.toInt() ?? 0}';

  String get _targetsLeftLabel {
    final total = (_stats?['total_contacts'] as num?)?.toInt() ?? 0;
    final captured = (_stats?['total_captures'] as num?)?.toInt() ?? 0;
    return '${(total - captured).clamp(0, total)}';
  }

  String get _pendingFollowUpsLabel =>
      '${(_stats?['follow_ups_needed'] as num?)?.toInt() ?? 0}';

  List<Map<String, dynamic>> get _priorityTargets => _targets.take(3).toList();

  void _openTargetList(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Full target list is available in Live Event mode.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            if (_isLoading)
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSkeletonLoading(),
              )
            else
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildHeroCard(context),
                    const SizedBox(height: 32),
                    _buildPriorityTargetsSection(context),
                    const SizedBox(height: 64),
                  ],
                ),
              ),
            _buildTopBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _c.destructive.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _c.destructive,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE NOW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _c.destructive,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.event.name,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: _c.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: _c.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.event.location ?? 'Location TBD',
                  style: TextStyle(
                    fontSize: 14,
                    color: _c.textSecondary,
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
                  color: _c.border.withValues(alpha: 0.20),
                ),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 560;
                final children = [
                  _buildStatTile('Target Reach', _targetReachLabel),
                  _buildStatTile('Scanned', _scannedLabel),
                  _buildStatTile('Targets Left', _targetsLeftLabel),
                  _buildStatTile('Pending Follow-Ups', _pendingFollowUpsLabel),
                ];

                if (wide) {
                  return Row(
                    children: [
                      for (int i = 0; i < children.length; i++) ...
                        [
                          Expanded(child: children[i]),
                          if (i < children.length - 1) const SizedBox(width: 16),
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
    );
  }

  Widget _buildStatTile(String label, String value) {
    // Map labels to appropriate icons
    IconData iconData;
    switch (label) {
      case 'Target Reach':
        iconData = Icons.percent_rounded;
        break;
      case 'Scanned':
        iconData = Icons.check_circle_outline_rounded;
        break;
      case 'Targets Left':
        iconData = Icons.people_outline_rounded;
        break;
      case 'Pending Follow-Ups':
        iconData = Icons.mail_outline_rounded;
        break;
      default:
        iconData = Icons.circle_outlined;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _c.accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                iconData,
                size: 16,
                color: _c.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppSectionLabel(label, letterSpacing: 1.0),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _c.textPrimary,
            ),
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
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _c.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _openTargetList(context),
              style: TextButton.styleFrom(
                foregroundColor: _c.textMuted,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'VIEW LIST',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _c.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._priorityTargets.asMap().entries.map((entry) {
          final index = entry.key;
          final target = entry.value;
          final booth = target['booth'] as String? ?? '';

          return Padding(
            padding: EdgeInsets.only(bottom: index < _priorityTargets.length - 1 ? 12 : 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _c.surface.withValues(alpha: 0.5),
                border: Border.all(color: _c.border.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _c.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          target['company_name'] as String? ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AppChip(booth),
                        const SizedBox(height: 6),
                        Icon(Icons.chevron_right, color: _c.textMuted, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _c.surface.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(
            color: _c.border.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            splashRadius: 20,
            icon: Icon(Icons.menu, color: _c.textPrimary),
          ),
          Expanded(
            child: Text(
              'EXONO',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _c.textPrimary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showUiOnlyMessage(context, 'Notifications'),
            splashRadius: 20,
            icon: Icon(Icons.notifications, color: _c.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        AppCard(
          padding: const EdgeInsets.all(24),
          radius: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLoader(
                width: 80,
                height: 24,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(height: 16),
              SkeletonLoader(
                width: 200,
                height: 28,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 12),
              SkeletonLoader(
                width: 250,
                height: 16,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.only(top: 20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: _c.border.withValues(alpha: 0.20)),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 560;
                    final children = [
                      _buildSkeletonStatTile(),
                      _buildSkeletonStatTile(),
                      _buildSkeletonStatTile(),
                      _buildSkeletonStatTile(),
                    ];

                    if (wide) {
                      return Row(
                        children: [
                          for (int i = 0; i < children.length; i++) ...
                            [
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
        const SizedBox(height: 32),
        Text(
          'Priority Targets',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _c.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < 3; i++) ...
          [
            _buildSkeletonPriorityRow(),
            if (i < 2) const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _buildSkeletonStatTile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _c.accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.circle,
                size: 16,
                color: _c.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SkeletonLoader(
                width: 100,
                height: 12,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: SkeletonLoader(
            width: 60,
            height: 24,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonPriorityRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _c.surface.withValues(alpha: 0.5),
        border: Border.all(color: _c.border.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SkeletonLoader(
            width: 40,
            height: 40,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: 150,
                  height: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                SkeletonLoader(
                  width: 80,
                  height: 20,
                  borderRadius: BorderRadius.circular(999),
                ),
              ],
            ),
          ),
          SkeletonLoader(
            width: 20,
            height: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
