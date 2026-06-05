import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'offline_mode_screen.dart';
import 'target_list_full_view_screen.dart';
import 'log_interaction_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color _background = Color(0xFF000000);
  static const Color _surface = Color(0xFF121315);
  static const Color _surfaceContainerLow = Color(0xFF1B1C1D);
  static const Color _surfaceContainerHigh = Color(0xFF292A2B);
  static const Color _surfaceContainerHighest = Color(0xFF343536);
  static const Color _outline = Color(0xFF8B90A0);
  static const Color _primary = Color(0xFFADC6FF);
  static const Color _onPrimary = Color(0xFF002E69);
  static const Color _onSurface = Color(0xFFE3E2E3);
  static const Color _onSurfaceVariant = Color(0xFFC1C6D7);
  static const Color _muted = Color(0xFF8E8E93);
  static const Color _aiPurple = Color(0xFFDFD1FF);
  static const Color _cardBackground = Color(0xFF08090A);

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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TargetListFullViewScreen(
          onNavigateTab: widget.onNavigateTab,
          eventTitle: 'Global Fintech Expo 2024',
          countLabel: '${_targets.length} / 120',
          items: _targets
              .map(
                (target) => TargetListItemData(
                  company: target.company,
                  booth: target.booth,
                  sector: target.sector,
                  contact: target.contact,
                  title: target.title,
                  score: target.score,
                  prepNotes: target.prepNotes,
                  relationshipStrength: target.relationshipStrength,
                  isMet: target.isMet,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (!isMobile) {
      return Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: _background)),
          const Positioned.fill(child: IgnorePointer(child: _BlueprintGrid())),
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                sliver: SliverList.list(
                  children: [
                    _buildDesktopHeader(),
                    const SizedBox(height: 24),
                    _buildFilterShell(),
                    const SizedBox(height: 20),
                    ..._buildTargetCards(),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return ColoredBox(
      color: _background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildMobileTopBar(),
            Expanded(
              child: Stack(
                children: [
                  const Positioned.fill(child: _BlueprintGrid()),
                  CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                          child: _buildFilterShell(),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 140),
                        sliver: SliverList.list(children: _buildTargetCards()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Row(
      children: [
        _buildBrandMark(size: 36),
        const SizedBox(width: 12),
        Text(
          'Targets',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: _primary,
            letterSpacing: -0.4,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => _showUiOnlyMessage('Search'),
          icon: const Icon(Icons.search, color: _onSurfaceVariant),
        ),
        IconButton(
          onPressed: _openTargetListFullView,
          icon: const Icon(
            Icons.view_agenda_outlined,
            color: _onSurfaceVariant,
          ),
        ),
        IconButton(
          onPressed: _openOfflineMode,
          icon: const Icon(Icons.hub_outlined, color: _onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildMobileTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      child: Row(
        children: [
          Row(
            children: [
              _buildBrandMark(size: 32),
              const SizedBox(width: 10),
              Text(
                'Targets',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _showUiOnlyMessage('Search'),
            icon: const Icon(Icons.search, color: _onSurfaceVariant, size: 22),
            splashRadius: 20,
          ),
          IconButton(
            onPressed: _openTargetListFullView,
            icon: const Icon(
              Icons.view_agenda_outlined,
              color: _onSurfaceVariant,
              size: 22,
            ),
            splashRadius: 20,
          ),
          IconButton(
            onPressed: _openOfflineMode,
            icon: const Icon(
              Icons.hub_outlined,
              color: _onSurfaceVariant,
              size: 22,
            ),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildBrandMark({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        color: const Color(0xFF0F1012),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    color: Colors.white.withValues(alpha: 0.18),
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
                    color: _primary.withValues(alpha: 0.60),
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
                color: _primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterShell() {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      decoration: BoxDecoration(
        color: _background.withValues(alpha: 0.90),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchField(),
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isActive = filter == _selectedFilter;
                return InkWell(
                  onTap: () => setState(() => _selectedFilter = filter),
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: isActive ? _primary : _surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isActive
                            ? _primary.withValues(alpha: 0.30)
                            : Colors.white.withValues(alpha: 0.10),
                      ),
                      boxShadow: isActive
                          ? const [
                              BoxShadow(
                                color: Color(0x33ADC6FF),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      filter.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.9,
                        color: isActive ? _onPrimary : _onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        cursorColor: _primary,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: _onSurface,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          prefixIcon: const Icon(Icons.search, size: 18, color: _muted),
          hintText: 'Search companies, people, booths...',
          hintStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: _muted,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTargetCards() {
    if (_visibleTargets.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Text(
            'No targets match the current filters.',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _onSurfaceVariant,
            ),
          ),
        ),
      ];
    }

    return [
      for (int index = 0; index < _visibleTargets.length; index++) ...[
        _buildTargetCard(_visibleTargets[index]),
        if (index < _visibleTargets.length - 1) const SizedBox(height: 8),
      ],
    ];
  }

  Widget _buildTargetCard(_TargetItem target) {
    final isCompleted = target.isMet;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isCompleted ? 0.70 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: _cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: target.isVip
                ? _primary.withValues(alpha: 0.40)
                : Colors.white.withValues(alpha: 0.10),
          ),
          boxShadow: [
            const BoxShadow(
              color: Color(0x66000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
            if (target.isVip)
              const BoxShadow(
                color: Color(0x33007AFF),
                blurRadius: 16,
                offset: Offset(0, 0),
              ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => _toggleExpanded(target),
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(8),
                bottom: Radius.circular(target.isExpanded ? 0 : 8),
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
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isCompleted ? _muted : _onSurface,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Booth ${target.booth}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: _muted,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '•',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: _muted,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  target.sector,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: _muted,
                                  ),
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
                        _buildCheckBox(target),
                        const SizedBox(width: 10),
                        Icon(
                          target.isExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: _muted,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (target.isExpanded) _buildExpandedSection(target),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedSection(_TargetItem target) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBlock('Company Overview', target.overview),
          const SizedBox(height: 14),
          _buildInfoBlock('Products & Services', target.productsServices),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -20,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _background,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _aiPurple.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: _aiPurple,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI PREP NOTES',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.7,
                            color: _aiPurple,
                          ),
                        ),
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
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Icon(
                                    Icons.circle,
                                    size: 5,
                                    color: _onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      color: _onSurfaceVariant,
                                      height: 1.4,
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
          _buildInfoBlock(
            'Meeting Objective',
            target.objective,
            emphasize: true,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Key Contact (Optional)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.person, size: 16, color: _muted),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            target.contact,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: _onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${target.title} • Strategy Dept',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: _muted,
                            ),
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
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'My Notes',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: _muted,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => showLogInteractionSheet(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add, size: 12, color: _primary),
                            const SizedBox(width: 4),
                            Text(
                              'ADD',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _primary,
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
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: _onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.navigation,
                    label: 'Navigate',
                    onTap: () => _showUiOnlyMessage('Navigate'),
                    isPrimary: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.business,
                    label: 'Profile',
                    onTap: () => _navigateTo(5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.check_circle,
                    label: 'Mark Met',
                    onTap: () => _toggleMet(target, !target.isMet),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBlock(String label, String body, {bool emphasize = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: _muted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: emphasize ? FontWeight.w500 : FontWeight.w400,
            color: emphasize ? _onSurface : _onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckBox(_TargetItem target) {
    return InkWell(
      onTap: () => _toggleMet(target, !target.isMet),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: target.isMet ? _primary : _outline),
          color: target.isMet
              ? _primary.withValues(alpha: 0.20)
              : Colors.transparent,
        ),
        child: target.isMet
            ? const Icon(Icons.check, size: 16, color: _primary)
            : null,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: isPrimary
              ? _primary.withValues(alpha: 0.10)
              : _surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPrimary
                ? _primary.withValues(alpha: 0.30)
                : Colors.white.withValues(alpha: 0.10),
          ),
          boxShadow: isPrimary
              ? const [BoxShadow(color: Color(0x19007AFF), blurRadius: 10)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isPrimary ? _primary : _onSurface),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isPrimary ? _primary : _onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: SafeArea(
        top: false,
        child: Container(
          height: 76,
          decoration: BoxDecoration(
            color: _surfaceContainerHighest.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.gps_fixed,
                label: 'Targets',
                isActive: true,
                onTap: () => _navigateTo(0),
              ),
              _buildNavItem(
                icon: Icons.group_outlined,
                label: 'Contacts',
                isActive: false,
                onTap: () => _navigateTo(3),
              ),
              Transform.translate(
                offset: const Offset(0, -16),
                child: InkWell(
                  onTap: () => _navigateTo(2),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4DADC6FF),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: _onPrimary,
                      size: 30,
                    ),
                  ),
                ),
              ),
              _buildNavItem(
                icon: Icons.event_outlined,
                label: 'Events',
                isActive: false,
                onTap: () => _navigateTo(1),
              ),
              _buildNavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                isActive: false,
                onTap: () => _navigateTo(5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final color = isActive ? _primary : _muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 64,
        padding: EdgeInsets.symmetric(
          horizontal: 4,
          vertical: isActive ? 8 : 10,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
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
  const _BlueprintGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BlueprintGridPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _BlueprintGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFF000000);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
