import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_filter_row.dart';
import '../widgets/app_section_label.dart';
import 'offline_mode_screen.dart';
import 'log_interaction_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  final TextEditingController _searchController = TextEditingController();

  late final List<_TargetItem> _targets = [
    _TargetItem(
      company: 'Quantum Financial',
      booth: 'A-12',
      sector: 'FinTech',
      contact: 'David Kim',
      title: 'VP Strategy',
      score: 88,
      relationshipStrength: 0.68,
      objective: 'Open a cross-border compliance data discussion.',
      overview:
          'Cross-border financial infrastructure provider focused on compliance automation and settlement visibility for institutional operators.',
      productsServices:
          'Regulatory reporting platform, treasury workflow tooling, cross-border compliance APIs',
      prepNotes: const [
        'Recently shifted budget into applied infrastructure tooling.',
        'Interested in tighter regulatory reporting flows for EU expansion.',
        'Lead with operational reliability rather than broad AI messaging.',
      ],
    ),
    _TargetItem(
      company: 'Nexus Group',
      booth: 'B-04',
      sector: 'SaaS',
      contact: 'Sarah Chen',
      title: 'Head of Partnerships',
      score: 92,
      relationshipStrength: 0.75,
      objective: 'Explore integration partnership opportunities.',
      overview:
          'Leading provider of cloud-based enterprise resource planning solutions focusing on AI-driven supply chain optimization.',
      productsServices:
          'Nexus Cloud ERP, Nexus AI Analytics, Supply Chain Predictor',
      prepNotes: const [
        'Recently raised Series C funding.',
        'Looking to expand into EU markets.',
        'Exploring Blockchain integration.',
      ],
      isVip: true,
      isExpanded: true,
    ),
    _TargetItem(
      company: 'Apex Ventures',
      booth: 'C-21',
      sector: 'VC',
      contact: 'Marcus Thorne',
      title: 'Partner',
      score: 64,
      relationshipStrength: 0.49,
      objective: 'Reconnect around enterprise infrastructure allocation.',
      overview:
          'Early-growth investment firm backing enterprise software, data infrastructure, and operational AI companies.',
      productsServices:
          'Growth capital, strategic partner network, enterprise GTM advisory',
      prepNotes: const [
        'Prefers concise commercial framing.',
        'Strong signal around strategic partner intros this quarter.',
      ],
    ),
    _TargetItem(
      company: 'Ironclad Security',
      booth: 'D-01',
      sector: 'CyberSec',
      contact: 'Elena Rostova',
      title: 'CTO',
      score: 45,
      relationshipStrength: 0.31,
      objective: 'Secondary booth stop if traffic opens later in the day.',
      overview:
          'Security infrastructure company focused on zero-trust controls for distributed enterprise environments.',
      productsServices:
          'Identity enforcement, policy orchestration, device trust monitoring',
      prepNotes: const [
        'Low urgency target.',
        'Angle toward zero-trust deployment controls.',
      ],
      isMet: true,
    ),
    _TargetItem(
      company: 'Lumina X',
      booth: 'E-55',
      sector: 'AI Hardware',
      contact: 'Dr. Alan Turing',
      title: 'CEO',
      score: 95,
      relationshipStrength: 0.84,
      objective:
          'Position EXONO as the orchestration layer for field deployments.',
      overview:
          'Edge AI hardware company building deployment-ready acceleration systems for industrial and field robotics.',
      productsServices:
          'Inference accelerators, ruggedized compute modules, orchestration-ready edge kits',
      prepNotes: const [
        'Expect executive-level conversation, fast and strategic.',
        'High-value opportunity if demo conversation lands well.',
      ],
      isVip: true,
    ),
  ];

  final List<String> _filters = const ['All', 'Not Met', 'Met'];

  String _selectedFilter = 'All';
  String _searchQuery = '';

  List<_TargetItem> get _visibleTargets {
    final query = _searchQuery.trim().toLowerCase();

    return _targets.where((target) {
      final matchesQuery =
          query.isEmpty ||
          target.company.toLowerCase().contains(query) ||
          target.contact.toLowerCase().contains(query) ||
          target.booth.toLowerCase().contains(query) ||
          target.sector.toLowerCase().contains(query);

      final matchesFilter = switch (_selectedFilter) {
        'All' => true,
        'Not Met' => !target.isMet,
        'Met' => target.isMet,
        _ => true,
      };

      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showUiOnlyMessage(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label is UI-only for now.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateTo(int index) {
    widget.onNavigateTab?.call(index);
  }

  void _toggleExpanded(_TargetItem target) {
    setState(() {
      target.isExpanded = !target.isExpanded;
    });
  }

  void _toggleMet(_TargetItem target, bool value) {
    setState(() {
      target.isMet = value;
      if (value) {
        target.isExpanded = false;
      }
    });
  }

  void _openOfflineMode() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            OfflineModeScreen(onNavigateTab: widget.onNavigateTab),
      ),
    );
  }

  void _openTargetListFullView() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Full target list is available in Live Event mode.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
    final gridColor = colors.accentGlow.withValues(alpha: 0.28);

    if (!isMobile) {
      return Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: colors.background)),
          Positioned.fill(child: IgnorePointer(child: _BlueprintGrid(lineColor: gridColor))),
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                sliver: SliverList.list(
                  children: [
                    _buildDesktopHeader(colors),
                    const SizedBox(height: 24),
                    _buildFilterShell(colors),
                    const SizedBox(height: 20),
                    ..._buildTargetCards(colors),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildMobileTopBar(colors),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _BlueprintGrid(lineColor: gridColor)),
                  CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                          child: _buildFilterShell(colors),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        sliver: SliverList.list(children: _buildTargetCards(colors)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(ExonoColors colors) {
    return Row(
      children: [
        _buildBrandMark(size: 36, colors: colors),
        const SizedBox(width: 12),
        Text(
          'Targets',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => _showUiOnlyMessage('Search'),
          icon: Icon(Icons.search, color: colors.textSecondary),
        ),
        IconButton(
          onPressed: _openTargetListFullView,
          icon: Icon(Icons.view_agenda_outlined, color: colors.textSecondary),
        ),
        IconButton(
          onPressed: _openOfflineMode,
          icon: Icon(Icons.hub_outlined, color: colors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildMobileTopBar(ExonoColors colors) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.5)),
        ),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Row(
        children: [
          Row(
            children: [
              _buildBrandMark(size: 32, colors: colors),
              const SizedBox(width: 10),
              Text(
                'Targets',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _showUiOnlyMessage('Search'),
            icon: Icon(Icons.search, color: colors.textSecondary, size: 22),
            splashRadius: 20,
          ),
          IconButton(
            onPressed: _openTargetListFullView,
            icon: Icon(Icons.view_agenda_outlined, color: colors.textSecondary, size: 22),
            splashRadius: 20,
          ),
          IconButton(
            onPressed: _openOfflineMode,
            icon: Icon(Icons.hub_outlined, color: colors.textSecondary, size: 22),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildBrandMark({required double size, required ExonoColors colors}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.accent, colors.accentStrong],
        ),
        border: Border.all(color: colors.border.withValues(alpha: 0.35)),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: 0.785398,
              child: Container(
                width: size * 0.34,
                height: size * 0.34,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1.6,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Transform.rotate(
              angle: -0.785398,
              child: Container(
                width: size * 0.34,
                height: size * 0.34,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 1.6,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Container(
              width: size * 0.12,
              height: size * 0.12,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterShell(ExonoColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchField(colors),
          const SizedBox(height: 14),
          AppFilterRow(
            filters: _filters,
            selected: _selectedFilter,
            onSelect: (f) => setState(() => _selectedFilter = f),
            style: AppFilterRowStyle.filled,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(ExonoColors colors) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        cursorColor: colors.accent,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: colors.textPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          prefixIcon: Icon(Icons.search, size: 18, color: colors.textMuted),
          hintText: 'Search companies, people, booths...',
          hintStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: colors.textMuted,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTargetCards(ExonoColors colors) {
    if (_visibleTargets.isEmpty) {
      return [
        AppCard(
          padding: const EdgeInsets.all(20),
          radius: 24,
          child: Text(
            'No targets match the current filters.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
        ),
      ];
    }

    return [
      for (int index = 0; index < _visibleTargets.length; index++) ...[
        _buildTargetCard(_visibleTargets[index], colors),
        if (index < _visibleTargets.length - 1) const SizedBox(height: 8),
      ],
    ];
  }

  Widget _buildTargetCard(_TargetItem target, ExonoColors colors) {
    final isCompleted = target.isMet;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isCompleted ? 0.70 : 1,
      child: AppCard(
        radius: 24,
        borderColor: target.isVip
            ? colors.accent.withValues(alpha: 0.45)
            : colors.border.withValues(alpha: 0.6),
        extraShadow: target.isVip
            ? [BoxShadow(color: colors.accentGlow.withValues(alpha: 0.35), blurRadius: 18, offset: Offset.zero)]
            : null,
        child: Column(
          children: [
            InkWell(
              onTap: () => _toggleExpanded(target),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(24),
                bottom: Radius.circular(target.isExpanded ? 0 : 24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            target.company,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isCompleted ? colors.textMuted : colors.textPrimary,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Booth ${target.booth}',
                                style: TextStyle(fontSize: 12, color: colors.textMuted),
                              ),
                              const SizedBox(width: 6),
                              Text('•', style: TextStyle(fontSize: 12, color: colors.textMuted)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  target.sector,
                                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCheckBox(target, colors),
                        const SizedBox(width: 10),
                        Icon(
                          target.isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: colors.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (target.isExpanded) _buildExpandedSection(target, colors),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedSection(_TargetItem target, ExonoColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: colors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBlock('Company Overview', target.overview, colors: colors),
          const SizedBox(height: 14),
          _buildInfoBlock('Products & Services', target.productsServices, colors: colors),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.accent.withValues(alpha: 0.2)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -20,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        AppSectionLabel('AI Prep Notes', color: colors.accent, letterSpacing: 0.7),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: target.prepNotes
                        .map(
                          (note) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Icon(Icons.circle, size: 5, color: colors.textSecondary),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: colors.textSecondary,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildInfoBlock('Meeting Objective', target.objective, emphasize: true, colors: colors),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.border.withValues(alpha: 0.5))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSectionLabel('Key Contact (Optional)', letterSpacing: 0.8),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.person, size: 16, color: colors.textMuted),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            target.contact,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${target.title} • Strategy Dept',
                            style: TextStyle(fontSize: 11, color: colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.border.withValues(alpha: 0.5))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppSectionLabel('My Notes', letterSpacing: 0.8),
                    ),
                    InkWell(
                      onTap: () => showLogInteractionSheet(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 12, color: colors.accent),
                            const SizedBox(width: 4),
                            Text(
                              'ADD',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: colors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'No notes yet.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.border.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.navigation,
                    label: 'Navigate',
                    onTap: () => _showUiOnlyMessage('Navigate'),
                    isPrimary: true,
                    colors: colors,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.business,
                    label: 'Profile',
                    onTap: () => _navigateTo(5),
                    colors: colors,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.check_circle,
                    label: 'Mark Met',
                    onTap: () => _toggleMet(target, !target.isMet),
                    colors: colors,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBlock(String label, String body, {bool emphasize = false, required ExonoColors colors}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionLabel(label, letterSpacing: 0.8),
        const SizedBox(height: 6),
        Text(
          body,
          style: TextStyle(
            fontSize: 13,
            fontWeight: emphasize ? FontWeight.w500 : FontWeight.w400,
            color: emphasize ? colors.textPrimary : colors.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckBox(_TargetItem target, ExonoColors colors) {
    return InkWell(
      onTap: () => _toggleMet(target, !target.isMet),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: target.isMet ? colors.accent : colors.border),
          color: target.isMet ? colors.accentSoft : Colors.transparent,
        ),
        child: target.isMet
            ? Icon(Icons.check, size: 14, color: colors.accentStrong)
            : null,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ExonoColors colors,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: isPrimary ? colors.accentSoft : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? colors.accent.withValues(alpha: 0.4) : colors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isPrimary ? colors.accentStrong : colors.textPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isPrimary ? colors.accentStrong : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetItem {
  final String company;
  final String booth;
  final String sector;
  final String contact;
  final String title;
  final int score;
  final List<String> prepNotes;
  final double relationshipStrength;
  final String objective;
  final String overview;
  final String productsServices;
  final bool isVip;
  bool isMet;
  bool isExpanded;

  _TargetItem({
    required this.company,
    required this.booth,
    required this.sector,
    required this.contact,
    required this.title,
    required this.score,
    required this.prepNotes,
    required this.relationshipStrength,
    required this.objective,
    required this.overview,
    required this.productsServices,
    this.isVip = false,
    this.isMet = false,
    this.isExpanded = false,
  });
}

class _BlueprintGrid extends StatelessWidget {
  final Color lineColor;

  const _BlueprintGrid({required this.lineColor});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BlueprintGridPainter(lineColor: lineColor),
      child: const SizedBox.expand(),
    );
  }
}

class _BlueprintGridPainter extends CustomPainter {
  final Color lineColor;

  const _BlueprintGridPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    const spacing = 20.0;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlueprintGridPainter old) => old.lineColor != lineColor;
}
