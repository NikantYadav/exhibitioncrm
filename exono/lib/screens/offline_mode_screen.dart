import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_filter_row.dart';
import '../widgets/app_section_label.dart';

class OfflineModeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const OfflineModeScreen({super.key, this.onNavigateTab});

  @override
  State<OfflineModeScreen> createState() => _OfflineModeScreenState();
}

class _OfflineModeScreenState extends State<OfflineModeScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  static const Color _pending = Color(0xFFFACC15);


  final List<String> _filters = const ['All', 'Must Meet', 'Met', 'Remaining'];
  String _selectedFilter = 'All';

  late final List<_OfflineTarget> _targets = [
    _OfflineTarget(
      indexLabel: '01',
      company: 'Aether Systems',
      booth: 'B-04',
      tags: const ['AI & Robotics'],
      notes:
          'Review Series B funding status and core NLP architecture milestones.',
      isMet: false,
      isExpanded: true,
    ),
    _OfflineTarget(
      indexLabel: '02',
      company: 'Lumina Labs',
      booth: 'C-12',
      tags: const ['Photonics'],
      notes: 'Will sync when reconnected',
      isMet: true,
      isExpanded: false,
    ),
    _OfflineTarget(
      indexLabel: '03',
      company: 'Helix Motion',
      booth: 'D-08',
      tags: const ['Industrial AI'],
      notes: 'Confirm operating footprint across Nordic logistics hubs.',
      isMet: false,
      isExpanded: false,
    ),
  ];

  int get _pendingSyncCount => 14;

  List<_OfflineTarget> get _visibleTargets {
    return _targets.where((target) {
      return switch (_selectedFilter) {
        'All' => true,
        'Must Meet' => !target.isMet && target.indexLabel == '01',
        'Met' => target.isMet,
        'Remaining' => !target.isMet,
        _ => true,
      };
    }).toList();
  }

  void _showUiOnlyMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _toggleTarget(_OfflineTarget target) {
    setState(() => target.isExpanded = !target.isExpanded);
  }

  void _toggleMet(_OfflineTarget target) {
    setState(() {
      target.isMet = !target.isMet;
      if (target.isMet) {
        target.isExpanded = false;
      }
    });
    _showUiOnlyMessage('Offline status stored locally.');
  }

  void _navigate(int index) {
    Navigator.of(context).pop();
    widget.onNavigateTab?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 4,
        onNavigate: _navigate,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildStatusBanner(),
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPreEventCacheCard(),
                        const SizedBox(height: 24),
                        _buildHeaderSection(),
                        const SizedBox(height: 14),
                        _buildFilterRow(),
                        const SizedBox(height: 16),
                        ..._buildTargetCards(),
                        const SizedBox(height: 36),
                        _buildOfflineFooterNote(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _c.surfaceAlt,
        border: Border(bottom: BorderSide(color: _c.border)),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, color: _c.accent, size: 16),
              const SizedBox(width: 8),
              Text(
                'Offline',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: _c.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _pending,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_pendingSyncCount PENDING SYNC',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: _c.textMuted,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'SYNC: 2M AGO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: _c.textMuted.withValues(alpha: 0.40),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => _showUiOnlyMessage('Refresh attempted.'),
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.refresh, color: _c.accent, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _c.background,
        border: Border(bottom: BorderSide(color: _c.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.menu, color: _c.accent, size: 22),
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
          Icon(Icons.notifications, color: _c.accent, size: 22),
        ],
      ),
    );
  }

  Widget _buildPreEventCacheCard() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 16,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _c.surfaceAlt,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.cloud_download_outlined,
              color: _c.textMuted,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pre-Event Cache',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _c.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'CACHE ALL TARGET DATA FOR UPCOMING EVENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                    color: _c.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => _showUiOnlyMessage('Cache download started.'),
            style: FilledButton.styleFrom(
              backgroundColor: _c.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'DOWNLOAD',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Web Summit 2026',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _c.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '14 TARGETS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.8,
                  color: _c.textMuted,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () => _showUiOnlyMessage('Sort by booth'),
          style: TextButton.styleFrom(
            foregroundColor: _c.textMuted,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.sort, size: 16),
          label: const Text(
            'SORT BY BOOTH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    return AppFilterRow(
      filters: _filters,
      selected: _selectedFilter,
      onSelect: (f) => setState(() => _selectedFilter = f),
    );
  }

  List<Widget> _buildTargetCards() {
    if (_visibleTargets.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _c.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _c.border),
          ),
          child: Text(
            'No cached targets match the current filter.',
            style: TextStyle(fontSize: 14, color: _c.textMuted),
          ),
        ),
      ];
    }

    return [
      for (int i = 0; i < _visibleTargets.length; i++) ...[
        _buildTargetCard(_visibleTargets[i]),
        if (i < _visibleTargets.length - 1) const SizedBox(height: 16),
      ],
    ];
  }

  Widget _buildTargetCard(_OfflineTarget target) {
    final isMet = target.isMet;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: isMet ? 0.5 : 1,
      child: AppCard(
        radius: 16,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        target.indexLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _c.borderStrong,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              target.company,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isMet ? _c.textMuted : _c.textSecondary,
                                decoration: isMet
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            AppChip.label('BOOTH ${target.booth}'),
                            if (isMet) AppChip.status('MET', color: _c.textSecondary),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: isMet
                                  ? Text(
                                      'Will sync when reconnected',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        fontStyle: FontStyle.italic,
                                        color: _c.textMuted,
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: target.tags
                                          .map((t) => AppChip(t))
                                          .toList(),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _toggleTarget(target),
                              borderRadius: BorderRadius.circular(999),
                              child: AnimatedRotation(
                                duration: const Duration(milliseconds: 160),
                                turns: target.isExpanded ? 0.5 : 0,
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.expand_more,
                                    color: _c.textMuted,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => _toggleMet(target),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isMet ? _c.textSecondary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isMet ? _c.textSecondary : _c.border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.check,
                        size: 18,
                        color: isMet ? _c.surface : Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (target.isExpanded && !isMet)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  color: _c.surfaceElevated.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(top: BorderSide(color: _c.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionLabel('Prepared Notes'),
                    const SizedBox(height: 10),
                    Text(
                      target.notes,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _c.textMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showUiOnlyMessage('Add interaction'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _c.textSecondary,
                          side: BorderSide(color: _c.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.note_add_outlined, size: 18),
                        label: const Text(
                          'ADD INTERACTION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
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

  Widget _buildOfflineFooterNote() {
    return Text(
      'Viewing cached data from last sync. New contacts and AI features unavailable offline.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: _c.textMuted.withValues(alpha: 0.70),
        height: 1.45,
      ),
    );
  }
}

class _OfflineTarget {
  final String indexLabel;
  final String company;
  final String booth;
  final List<String> tags;
  final String notes;
  bool isMet;
  bool isExpanded;

  _OfflineTarget({
    required this.indexLabel,
    required this.company,
    required this.booth,
    required this.tags,
    required this.notes,
    required this.isMet,
    required this.isExpanded,
  });
}
