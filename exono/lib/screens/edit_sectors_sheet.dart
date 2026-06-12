import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../config/app_theme.dart';
import '../widgets/app_input.dart';

Future<List<String>?> showEditSectorsSheet(
  BuildContext context, {
  required List<String> initialSelection,
}) {
  return showFSheet<List<String>>(
    context: context,
    side: FLayout.btt,
    builder: (_) => _EditSectorsSheet(initialSelection: initialSelection),
  );
}

class _EditSectorsSheet extends StatefulWidget {
  final List<String> initialSelection;

  const _EditSectorsSheet({required this.initialSelection});

  @override
  State<_EditSectorsSheet> createState() => _EditSectorsSheetState();
}

class _EditSectorsSheetState extends State<_EditSectorsSheet> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  final TextEditingController _searchController = TextEditingController();
  final List<String> _allSectors = [
    'Technology',
    'Fintech',
    'Healthcare',
    'Manufacturing',
    'Logistics',
    'Energy',
    'Construction',
    'Retail',
    'Food and Beverage',
    'Aerospace',
    'Defense',
    'Robotics',
    'AI and Data',
    'Infrastructure',
    'Real Estate',
    'Finance',
    'Consulting',
    'Legal',
    'Media',
    'Education',
    'Cloud Infrastructure',
    'Agriculture',
  ];

  late final Set<String> _selected = {...widget.initialSelection};
  String _query = '';

  List<String> get _filteredSectors {
    if (_query.trim().isEmpty) return _allSectors;
    final query = _query.trim().toLowerCase();
    return _allSectors
        .where((sector) => sector.toLowerCase().contains(query))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: mediaQuery.size.height * 0.85,
            decoration: BoxDecoration(
              color: _c.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(top: BorderSide(color: _c.border)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: _c.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'EDIT SECTORS',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: _c.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 20,
                        icon: Icon(Icons.close, color: _c.accent),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: _c.border)),
                  ),
                  child: AppInput(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    hint: 'Search sectors...',
                    prefixIcon: Icon(
                      Icons.search,
                      color: _c.textMuted,
                      size: 20,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _filteredSectors
                              .map((sector) => _buildSectorChip(sector))
                              .toList(),
                        ),
                        const SizedBox(height: 24),
                        FButton(
                          variant: FButtonVariant.outline,
                          onPress: _addCustomSector,
                          prefix: const Icon(Icons.add, size: 18),
                          child: const Text('ADD CUSTOM SECTOR'),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  decoration: BoxDecoration(
                    color: _c.background,
                    border: Border(top: BorderSide(color: _c.border)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FButton(
                      variant: FButtonVariant.primary,
                      onPress: _selected.isEmpty
                          ? null
                          : () => Navigator.of(context).pop(_selected.toList()),
                      child: const Text('SAVE'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectorChip(String sector) {
    final isSelected = _selected.contains(sector);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selected.remove(sector);
          } else {
            _selected.add(sector);
          }
        });
      },
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _c.textPrimary : _c.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? _c.textPrimary : Colors.white.withValues(alpha: 0.20),
          ),
        ),
        child: Text(
          sector,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : _c.textPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _addCustomSector() async {
    final controller = TextEditingController();
    final newSector = await showFDialog<String>(
      context: context,
      builder: (ctx, style, _) => FDialog(
        title: const Text('Add custom sector'),
        body: AppInput(
          controller: controller,
          hint: 'e.g. Mobility',
        ),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FButton(
            variant: FButtonVariant.primary,
            onPress: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newSector == null || newSector.isEmpty) return;

    if (!_allSectors.contains(newSector)) {
      _allSectors.insert(0, newSector);
    }

    setState(() {
      _selected.add(newSector);
      _query = '';
      _searchController.clear();
    });
  }
}
