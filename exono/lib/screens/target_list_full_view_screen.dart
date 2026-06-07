import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_filter_row.dart';
import '../widgets/app_section_label.dart';
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
  ExonoColors get _c => AppTheme.colorsOf(context);

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
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 20,
            icon: Icon(Icons.arrow_back, color: _c.textPrimary),
          ),
          const SizedBox(width: 4),
          Text(
            'EXONO',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: _c.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _showUiOnlyMessage('Notifications'),
            splashRadius: 20,
            icon: Icon(Icons.notifications, color: _c.textPrimary),
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.8,
                  color: _c.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.eventTitle,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: _c.textPrimary,
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
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.8,
                color: _c.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.countLabel,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _c.textPrimary,
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
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _c.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 720;

          final filters = AppFilterRow(
            filters: _filters,
            selected: _selectedFilter,
            onSelect: (f) => setState(() => _selectedFilter = f),
          );

          final sort = Container(
            height: 44,
            width: stacked ? double.infinity : 220,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: _c.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _c.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSort,
                dropdownColor: _c.surfaceAlt,
                icon: Icon(Icons.expand_more, color: _c.textMuted),
                isExpanded: true,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _c.textPrimary,
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
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No targets match the current filters.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _c.textMuted,
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
      child: AppCard(
        radius: 16,
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
                decoration: BoxDecoration(
                  color: _c.background,
                  border: Border(top: BorderSide(color: _c.border)),
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _c.textMuted,
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: item.isMet ? _c.textMuted : _c.textPrimary,
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
                        AppChip.label(item.booth),
                        Text(
                          item.sector.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.0,
                            color: _c.textMuted,
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: _c.textMuted,
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
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.qr_code_scanner, color: _c.textPrimary, size: 22),
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
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _c.textMuted,
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  color: item.isMet ? _c.textMuted : _c.textPrimary,
                  decoration: item.isMet ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  AppChip.label(item.booth),
                  Text(
                    item.sector.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                      color: _c.textMuted,
                    ),
                  ),
                  if (item.isMet) AppChip.status('MET', color: _c.textPrimary),
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
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.qr_code_scanner, color: _c.textPrimary, size: 22),
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
        AppSectionLabel('Prep Notes', letterSpacing: 1.4),
        const SizedBox(height: 12),
        Text(
          item.prepNotes.join(' '),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: _c.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedSideSection(_FullTargetItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionLabel('Contact Intensity'),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 4,
            color: _c.border,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: item.relationshipStrength,
              child: ColoredBox(color: _c.accent),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Relationship depth based on interactions',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.italic,
            color: _c.textMuted,
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
              backgroundColor: item.isMet ? Colors.transparent : _c.textPrimary,
              foregroundColor: item.isMet ? _c.textPrimary : _c.background,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: item.isMet
                    ? BorderSide(color: _c.textPrimary)
                    : BorderSide.none,
              ),
            ),
            child: Text(
              item.isMet ? 'VIEW MEETING SUMMARY' : 'ADD NOTE',
              style: const TextStyle(
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
          color: item.isMet ? _c.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: item.isMet ? _c.textPrimary : _c.borderStrong),
        ),
        child: item.isMet
            ? Icon(Icons.check, size: 14, color: _c.background)
            : null,
      ),
    );
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
