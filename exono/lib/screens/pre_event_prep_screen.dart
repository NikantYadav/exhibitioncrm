import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PreEventPrepScreen extends StatefulWidget {
  final PreEventPrepData data;
  final ValueChanged<int>? onNavigateTab;

  const PreEventPrepScreen({super.key, required this.data, this.onNavigateTab});

  @override
  State<PreEventPrepScreen> createState() => _PreEventPrepScreenState();
}

class _PreEventPrepScreenState extends State<PreEventPrepScreen> {
  static const Color _background = Color(0xFF080808);
  static const Color _surfaceContainerLowest = Color(0xFF0E0E0E);
  static const Color _surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color _surfaceContainer = Color(0xFF201F1F);
  static const Color _surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color _surfaceContainerHighest = Color(0xFF353434);
  static const Color _outlineVariant = Color(0xFF444748);
  static const Color _primary = Colors.white;
  static const Color _onPrimary = Color(0xFF2F3131);
  static const Color _onSurface = Color(0xFFE5E2E1);
  static const Color _onSurfaceVariant = Color(0xFFC4C7C8);
  static const Color _glassPanel = Color(0xFF0C0C0C);

  final TextEditingController _searchController = TextEditingController();
  late PrepTargetCompany _selectedCompany = widget.data.targets.first;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PrepTargetCompany> get _filteredTargets {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.data.targets;

    return widget.data.targets.where((target) {
      return target.name.toLowerCase().contains(query) ||
          target.industry.toLowerCase().contains(query) ||
          target.booth.toLowerCase().contains(query) ||
          target.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  void _showUiOnlyMessage(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label is UI-only for now.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleBottomNav(int index) {
    Navigator.of(context).pop();
    widget.onNavigateTab?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderSection(),
                        const SizedBox(height: 32),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 960;
                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: _buildTargetListPanel(),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 5,
                                    child: _buildAiResearchPanel(),
                                  ),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                _buildTargetListPanel(),
                                const SizedBox(height: 16),
                                _buildAiResearchPanel(),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildAskAiButton(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _background.withValues(alpha: 0.80),
        border: const Border(bottom: BorderSide(color: _outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 20,
            icon: const Icon(Icons.arrow_back, color: _primary, size: 22),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.data.shortTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: _primary,
                height: 1,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showUiOnlyMessage('Notifications'),
            splashRadius: 20,
            icon: const Icon(Icons.notifications, color: _primary, size: 22),
          ),
          IconButton(
            onPressed: () => _showUiOnlyMessage('Settings'),
            splashRadius: 20,
            icon: const Icon(
              Icons.settings_outlined,
              color: _primary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, size: 14, color: _onPrimary),
                  const SizedBox(width: 8),
                  Text(
                    widget.data.countdownLabel.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.4,
                      color: _onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.data.title,
              style: GoogleFonts.inter(
                fontSize: isWide ? 32 : 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                color: _primary,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: _onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.data.location.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.1,
                        color: _onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: _onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.data.dateRange.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.1,
                        color: _onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

        final right = SizedBox(
          width: isWide ? 320 : double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Research Progress',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.4,
                        color: _onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.data.researchedTargets} of ${widget.data.totalTargets} Targets',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 4,
                  color: _surfaceContainerHighest,
                  child: FractionallySizedBox(
                    widthFactor: widget.data.progress,
                    alignment: Alignment.centerLeft,
                    child: const ColoredBox(color: _primary),
                  ),
                ),
              ),
            ],
          ),
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: left),
              const SizedBox(width: 24),
              right,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [left, const SizedBox(height: 20), right],
        );
      },
    );
  }

  Widget _buildTargetListPanel() {
    final targets = _filteredTargets;

    return _buildGlassPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Target List',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _primary,
                  ),
                ),
              ),
              _buildHeaderAction(
                icon: Icons.upload,
                label: 'Import',
                filled: false,
                onTap: () => _showUiOnlyMessage('Import targets'),
              ),
              const SizedBox(width: 8),
              _buildHeaderAction(
                icon: Icons.add,
                label: 'Add',
                filled: true,
                onTap: () => _showUiOnlyMessage('Add target'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: _outlineVariant),
          if (targets.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'No attending companies match that search.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _onSurfaceVariant,
                ),
              ),
            )
          else
            ...targets.map(_buildTargetRow),
        ],
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: filled ? _primary : _outlineVariant),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: filled ? _onPrimary : _onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
                color: filled ? _onPrimary : _onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetRow(PrepTargetCompany target) {
    final isSelected = target == _selectedCompany;

    return InkWell(
      onTap: () => setState(() => _selectedCompany = target),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? _surfaceContainerLowest.withValues(alpha: 0.90)
              : Colors.transparent,
          border: Border(bottom: BorderSide(color: _outlineVariant)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _surfaceContainer,
                border: Border.all(color: _outlineVariant),
              ),
              child: Text(
                target.initials,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _primary,
                ),
              ),
            ),
            const SizedBox(width: 14),
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
                        target.name,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _outlineVariant),
                        ),
                        child: Text(
                          'BOOTH ${target.booth}'.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: target.tags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _primary.withValues(alpha: 0.20),
                              ),
                            ),
                            child: Text(
                              tag.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _primary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            AnimatedSlide(
              duration: const Duration(milliseconds: 160),
              offset: isSelected ? const Offset(0.15, 0) : Offset.zero,
              child: Icon(
                Icons.chevron_right,
                color: _onSurfaceVariant,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiResearchPanel() {
    return _buildGlassPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: _primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'AI Research',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: _surfaceContainerLow,
              border: Border.all(color: _outlineVariant),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) {
                final filtered = _filteredTargets;
                if (filtered.isNotEmpty &&
                    !filtered.contains(_selectedCompany)) {
                  setState(() => _selectedCompany = filtered.first);
                } else {
                  setState(() {});
                }
              },
              cursorColor: _primary,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _primary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search any attending company...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _onSurfaceVariant.withValues(alpha: 0.50),
                ),
                prefixIcon: const Icon(Icons.search, color: _onSurfaceVariant),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCompany.name,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: _primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedCompany.industry,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: _onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _outlineVariant),
                      ),
                      child: Text(
                        _selectedCompany.initials,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'AI Talking Points',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.4,
                    color: _onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ..._selectedCompany.talkingPoints.map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 7),
                          color: _primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            point,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: _onSurface,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () =>
                        _showUiOnlyMessage('Generate detailed briefing'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: const BorderSide(color: _primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'GENERATE DETAILED BRIEFING',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2.0,
                        color: _primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassPanel({
    required EdgeInsets padding,
    required Widget child,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _glassPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: child,
    );
  }

  Widget _buildAskAiButton() {
    return InkWell(
      onTap: () => _showUiOnlyMessage('Ask EXONO AI'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: _primary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _outlineVariant),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 30,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.auto_awesome, size: 30, color: _background),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: _background.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: _outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomNavItem(
              icon: Icons.gps_fixed,
              isActive: false,
              onTap: () => _handleBottomNav(0),
            ),
            _buildBottomNavItem(
              icon: Icons.contacts_outlined,
              isActive: false,
              onTap: () => _handleBottomNav(3),
            ),
            Transform.translate(
              offset: const Offset(0, -12),
              child: InkWell(
                onTap: () => _handleBottomNav(2),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141313),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _outlineVariant),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 20,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 28,
                    color: _primary,
                  ),
                ),
              ),
            ),
            _buildBottomNavItem(
              icon: Icons.calendar_today,
              isActive: true,
              onTap: () => Navigator.of(context).pop(),
            ),
            _buildBottomNavItem(
              icon: Icons.person_outline,
              isActive: false,
              onTap: () => _handleBottomNav(5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Icon(
        icon,
        size: 24,
        color: isActive ? _primary : _onSurfaceVariant,
      ),
    );
  }
}

class PreEventPrepData {
  final String shortTitle;
  final String title;
  final String countdownLabel;
  final String location;
  final String dateRange;
  final int researchedTargets;
  final int totalTargets;
  final double progress;
  final List<PrepTargetCompany> targets;

  const PreEventPrepData({
    required this.shortTitle,
    required this.title,
    required this.countdownLabel,
    required this.location,
    required this.dateRange,
    required this.researchedTargets,
    required this.totalTargets,
    required this.progress,
    required this.targets,
  });
}

class PrepTargetCompany {
  final String initials;
  final String name;
  final String booth;
  final List<String> tags;
  final String industry;
  final List<String> talkingPoints;
  final String imageUrl;

  const PrepTargetCompany({
    required this.initials,
    required this.name,
    required this.booth,
    required this.tags,
    required this.industry,
    required this.talkingPoints,
    required this.imageUrl,
  });
}
