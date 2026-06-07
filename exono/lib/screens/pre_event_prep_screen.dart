import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_section_label.dart';

class PreEventPrepScreen extends StatefulWidget {
  final PreEventPrepData data;
  final ValueChanged<int>? onNavigateTab;

  const PreEventPrepScreen({super.key, required this.data, this.onNavigateTab});

  @override
  State<PreEventPrepScreen> createState() => _PreEventPrepScreenState();
}

class _PreEventPrepScreenState extends State<PreEventPrepScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

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
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _c.background.withValues(alpha: 0.80),
        border: Border(bottom: BorderSide(color: _c.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 20,
            icon: Icon(Icons.arrow_back, color: _c.textPrimary, size: 22),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.data.shortTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                color: _c.textPrimary,
                height: 1,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showUiOnlyMessage('Notifications'),
            splashRadius: 20,
            icon: Icon(Icons.notifications, color: _c.textPrimary, size: 22),
          ),
          IconButton(
            onPressed: () => _showUiOnlyMessage('Settings'),
            splashRadius: 20,
            icon: Icon(
              Icons.settings_outlined,
              color: _c.textPrimary,
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
                color: _c.textPrimary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer, size: 14, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    widget.data.countdownLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.4,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.data.title,
              style: TextStyle(
                fontSize: isWide ? 32 : 24,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                color: _c.textPrimary,
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
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: _c.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.data.location.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.1,
                        color: _c.textMuted,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: _c.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.data.dateRange.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.1,
                        color: _c.textMuted,
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
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.4,
                        color: _c.textMuted,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.data.researchedTargets} of ${widget.data.totalTargets} Targets',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _c.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 4,
                  color: _c.surfaceElevated,
                  child: FractionallySizedBox(
                    widthFactor: widget.data.progress,
                    alignment: Alignment.centerLeft,
                    child: ColoredBox(color: _c.accent),
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _c.textPrimary,
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
          Container(height: 1, color: _c.border),
          if (targets.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'No attending companies match that search.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _c.textMuted,
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
          color: filled ? _c.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: filled ? _c.accent : _c.border),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: filled ? Colors.white : _c.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
                color: filled ? Colors.white : _c.textMuted,
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
              ? _c.surface.withValues(alpha: 0.90)
              : Colors.transparent,
          border: Border(bottom: BorderSide(color: _c.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _c.surfaceAlt,
                border: Border.all(color: _c.border),
              ),
              child: Text(
                target.initials,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _c.textPrimary,
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _c.textPrimary,
                        ),
                      ),
                      AppChip.label('BOOTH ${target.booth}'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: target.tags.map((tag) => AppChip(tag)).toList(),
                  ),
                ],
              ),
            ),
            AnimatedSlide(
              duration: const Duration(milliseconds: 160),
              offset: isSelected ? const Offset(0.15, 0) : Offset.zero,
              child: Icon(
                Icons.chevron_right,
                color: _c.textMuted,
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
              Icon(Icons.auto_awesome, color: _c.textPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                'AI Research',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _c.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: _c.surfaceAlt,
              border: Border.all(color: _c.border),
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
              cursorColor: _c.textPrimary,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _c.textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search any attending company...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _c.textMuted.withValues(alpha: 0.50),
                ),
                prefixIcon: Icon(Icons.search, color: _c.textMuted),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.all(20),
            radius: 16,
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
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: _c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedCompany.industry,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: _c.textMuted,
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
                        color: _c.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _c.border),
                      ),
                      child: Text(
                        _selectedCompany.initials,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _c.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AppSectionLabel('AI Talking Points', letterSpacing: 1.4),
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
                          color: _c.textPrimary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            point,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: _c.textSecondary,
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
                      foregroundColor: _c.textPrimary,
                      side: BorderSide(color: _c.textPrimary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'GENERATE DETAILED BRIEFING',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2.0,
                        color: _c.textPrimary,
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
    return AppCard(
      padding: padding,
      radius: 16,
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
          color: _c.textPrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _c.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 30,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Icon(Icons.auto_awesome, size: 30, color: _c.background),
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
