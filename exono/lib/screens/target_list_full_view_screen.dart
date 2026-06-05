import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'log_interaction_screen.dart';

class TargetListItemData {
  final String company;
  final String booth;
  final String sector;
  final String contact;
  final String title;
  final int score;
  final List<String> prepNotes;
  final double relationshipStrength;
  final bool isMet;

  const TargetListItemData({
    required this.company,
    required this.booth,
    required this.sector,
    required this.contact,
    required this.title,
    required this.score,
    required this.prepNotes,
    required this.relationshipStrength,
    required this.isMet,
  });
}

class TargetListFullViewScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  final List<TargetListItemData> items;
  final String eventTitle;
  final String countLabel;

  const TargetListFullViewScreen({
    super.key,
    this.onNavigateTab,
    required this.items,
    required this.eventTitle,
    required this.countLabel,
  });

  @override
  State<TargetListFullViewScreen> createState() =>
      _TargetListFullViewScreenState();
}

class _TargetListFullViewScreenState extends State<TargetListFullViewScreen> {
  static const Color _background = Color(0xFF080808);
  static const Color _surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color _surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color _outlineVariant = Color(0xFF444748);
  static const Color _outline = Color(0xFF8E9192);
  static const Color _primary = Color(0xFFFFFFFF);
  static const Color _onPrimary = Color(0xFF080808);
  static const Color _onSurface = Color(0xFFE5E2E1);
  static const Color _onSurfaceVariant = Color(0xFFC4C7C8);

  final List<String> _filters = const ['All', 'Must Meet', 'Met', 'Remaining'];
  final List<String> _sortOptions = const [
    'Priority: High to Low',
    'Company: A-Z',
    'Booth: Ascending',
  ];

  late final List<_FullTargetItem> _items = widget.items
      .map(
        (item) => _FullTargetItem(
          company: item.company,
          booth: item.booth,
          sector: item.sector,
          contact: item.contact,
          title: item.title,
          score: item.score,
          prepNotes: item.prepNotes,
          relationshipStrength: item.relationshipStrength,
          isMet: item.isMet,
          isExpanded: !item.isMet && item.score >= 85,
        ),
      )
      .toList();

  String _selectedFilter = 'All';
  String _selectedSort = 'Priority: High to Low';

  List<_FullTargetItem> get _visibleItems {
    final filtered = _items.where((item) {
      return switch (_selectedFilter) {
        'All' => true,
        'Must Meet' => !item.isMet && item.score >= 80,
        'Met' => item.isMet,
        'Remaining' => !item.isMet,
        _ => true,
      };
    }).toList();

    switch (_selectedSort) {
      case 'Company: A-Z':
        filtered.sort((a, b) => a.company.compareTo(b.company));
      case 'Booth: Ascending':
        filtered.sort((a, b) => a.booth.compareTo(b.booth));
      default:
        filtered.sort((a, b) => b.score.compareTo(a.score));
    }

    return filtered;
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
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPageHeader(),
                        const SizedBox(height: 24),
                        _buildFilterSortBar(),
                        const SizedBox(height: 24),
                        ..._buildTargetRows(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: _background,
        border: Border(bottom: BorderSide(color: _outlineVariant)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 20,
            icon: const Icon(Icons.arrow_back, color: _primary),
          ),
          const SizedBox(width: 4),
          Text(
            'EXONO',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: _primary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _showUiOnlyMessage('Notifications'),
            splashRadius: 20,
            icon: const Icon(Icons.notifications, color: _primary),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ACTIVE EVENT',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.8,
                  color: _onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.eventTitle,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: _primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'TARGETS',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.8,
                color: _onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.countLabel,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterSortBar() {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _outlineVariant)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 720;

          final filters = SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isActive = filter == _selectedFilter;
                return InkWell(
                  onTap: () => setState(() => _selectedFilter = filter),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isActive ? _primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive ? _primary : _outlineVariant,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      filter,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isActive ? _onPrimary : _onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          );

          final sort = Container(
            height: 44,
            width: stacked ? double.infinity : 220,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0C0C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _outlineVariant),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSort,
                dropdownColor: _surfaceContainerLow,
                icon: const Icon(Icons.expand_more, color: _onSurfaceVariant),
                isExpanded: true,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _primary,
                ),
                items: _sortOptions
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(option, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedSort = value);
                  }
                },
              ),
            ),
          );

          if (stacked) {
            return Column(
              children: [filters, const SizedBox(height: 12), sort],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: filters),
              const SizedBox(width: 16),
              sort,
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildTargetRows() {
    final items = _visibleItems;
    if (items.isEmpty) {
      return [
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surfaceContainerLow,
            border: Border.all(color: _outlineVariant),
          ),
          child: Text(
            'No targets match the current filters.',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _onSurfaceVariant,
            ),
          ),
        ),
      ];
    }

    return [
      for (int index = 0; index < items.length; index++) ...[
        _buildTargetRow(index, items[index]),
        if (index < items.length - 1) const SizedBox(height: 16),
      ],
    ];
  }

  Widget _buildTargetRow(int index, _FullTargetItem item) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: item.isMet ? 0.60 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0C),
          border: Border.all(color: _outlineVariant),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => item.isExpanded = !item.isExpanded),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 760;
                    if (isWide) {
                      return _buildWideRowHeader(index, item);
                    }
                    return _buildCompactRowHeader(index, item);
                  },
                ),
              ),
            ),
            if (item.isExpanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: _background,
                  border: Border(top: BorderSide(color: _outlineVariant)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 760;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildPrepNotesSection(item)),
                          const SizedBox(width: 32),
                          Expanded(child: _buildExpandedSideSection(item)),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPrepNotesSection(item),
                        const SizedBox(height: 20),
                        _buildExpandedSideSection(item),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideRowHeader(int index, _FullTargetItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 32,
          child: Text(
            '${index + 1}'.padLeft(2, '0'),
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.company,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: item.isMet ? _onSurfaceVariant : _primary,
                        decoration: item.isMet
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildBoothChip(item.booth),
                        Text(
                          item.sector.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.0,
                            color: _onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.contact,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.title,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: _onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 92,
                child: Align(
                  alignment: Alignment.center,
                  child: _buildMetToggle(item),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showUiOnlyMessage('Scan target card'),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.qr_code_scanner, color: _primary, size: 22),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactRowHeader(int index, _FullTargetItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Text(
            '${index + 1}'.padLeft(2, '0'),
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.company,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  color: item.isMet ? _onSurfaceVariant : _primary,
                  decoration: item.isMet ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildBoothChip(item.booth),
                  Text(
                    item.sector.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                      color: _onSurfaceVariant,
                    ),
                  ),
                  if (item.isMet) _buildMetPill(),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            _buildMetToggle(item),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _showUiOnlyMessage('Scan target card'),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.qr_code_scanner, color: _primary, size: 22),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrepNotesSection(_FullTargetItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PREP NOTES',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.4,
            color: _onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          item.prepNotes.join(' '),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: _onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedSideSection(_FullTargetItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONTACT INTENSITY',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
            color: _onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 4,
            color: _outlineVariant,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: item.relationshipStrength,
              child: const ColoredBox(color: _primary),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Relationship depth based on interactions',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.italic,
            color: _onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              if (item.isMet) {
                _showUiOnlyMessage('View meeting summary');
                return;
              }

              showLogInteractionSheet(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: item.isMet ? Colors.transparent : _primary,
              foregroundColor: item.isMet ? _primary : _onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: item.isMet
                    ? const BorderSide(color: _primary)
                    : BorderSide.none,
              ),
            ),
            child: Text(
              item.isMet ? 'VIEW MEETING SUMMARY' : 'ADD NOTE',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoothChip(String booth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _outlineVariant),
      ),
      child: Text(
        booth,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: _primary,
        ),
      ),
    );
  }

  Widget _buildMetPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'MET',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: _onPrimary,
        ),
      ),
    );
  }

  Widget _buildMetToggle(_FullTargetItem item) {
    return InkWell(
      onTap: () {
        setState(() {
          item.isMet = !item.isMet;
          if (item.isMet) {
            item.isExpanded = false;
          }
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: item.isMet ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: item.isMet ? _primary : _outline),
        ),
        child: item.isMet
            ? const Icon(Icons.check, size: 14, color: _onPrimary)
            : null,
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: _background.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(color: _outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              icon: Icons.gps_fixed,
              label: 'Targets',
              isActive: true,
              onTap: () {},
            ),
            _buildNavItem(
              icon: Icons.contacts_outlined,
              label: 'Contacts',
              onTap: () => _navigateTo(3),
            ),
            Transform.translate(
              offset: const Offset(0, -12),
              child: InkWell(
                onTap: () => _navigateTo(2),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                    ),
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
                    color: _primary,
                    size: 28,
                  ),
                ),
              ),
            ),
            _buildNavItem(
              icon: Icons.calendar_today_outlined,
              label: 'Events',
              onTap: () => _navigateTo(1),
            ),
            _buildNavItem(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: () => _navigateTo(5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final color = isActive ? _primary : _onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: isActive
              ? const Border(top: BorderSide(color: _primary, width: 2))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.9,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(int index) {
    Navigator.of(context).pop();
    widget.onNavigateTab?.call(index);
  }

  void _showUiOnlyMessage(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label is UI-only for now.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _FullTargetItem {
  final String company;
  final String booth;
  final String sector;
  final String contact;
  final String title;
  final int score;
  final List<String> prepNotes;
  final double relationshipStrength;
  bool isMet;
  bool isExpanded;

  _FullTargetItem({
    required this.company,
    required this.booth,
    required this.sector,
    required this.contact,
    required this.title,
    required this.score,
    required this.prepNotes,
    required this.relationshipStrength,
    required this.isMet,
    required this.isExpanded,
  });
}
