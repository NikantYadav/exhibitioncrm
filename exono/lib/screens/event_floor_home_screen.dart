import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_section_label.dart';
import 'log_interaction_screen.dart';

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
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 4,
        onNavigate: (i) {
          Navigator.of(context).pop();
          widget.onNavigateTab?.call(i);
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
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
              backgroundColor: _c.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
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
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _c.surface.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(color: _c.border.withValues(alpha: 0.30)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 20,
            icon: Icon(Icons.menu, color: _c.textPrimary),
          ),
          Expanded(
            child: Center(
              child: Text(
                'EXONO',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  color: _c.textPrimary,
                ),
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

  Widget _buildHeroCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _c.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _c.border.withValues(alpha: 0.20)),
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
                        color: _c.destructive,
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
                        color: _c.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.event.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                    color: _c.textPrimary,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: _c.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.event.venue ?? widget.event.location ?? 'Venue'} • ${widget.event.hall ?? 'Main Hall'}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: _c.textMuted,
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
        AppSectionLabel(label, letterSpacing: 1.0),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _c.textPrimary,
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
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._priorityTargets.asMap().entries.map((entry) {
          final index = entry.key;
          final target = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == _priorityTargets.length - 1 ? 0 : 12,
            ),
            child: _buildPriorityRow(context, index + 1, target),
          );
        }),
        if (_priorityTargets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No priority targets for this event.',
              style: TextStyle(fontSize: 14, color: _c.textMuted),
            ),
          ),
      ],
    );
  }

  Widget _buildPriorityRow(
    BuildContext context,
    int rank,
    Map<String, dynamic> target,
  ) {
    final company = target['company'] as Map<String, dynamic>? ?? {};
    final companyName = company['name'] as String? ?? 'Unknown';
    final industry = company['industry'] as String? ?? '';
    final booth = target['booth_location'] as String? ?? 'TBD';

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
                color: _c.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _c.border),
              ),
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _c.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    companyName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    industry,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppChip(booth),
                const SizedBox(height: 6),
                Icon(Icons.chevron_right, color: _c.textMuted, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
