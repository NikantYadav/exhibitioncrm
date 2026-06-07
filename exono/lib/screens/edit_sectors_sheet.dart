import 'package:flutter/material.dart';

import '../config/app_theme.dart';

Future<List<String>?> showEditSectorsSheet(
  BuildContext context, {
  required List<String> initialSelection,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.50),
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
                        icon: Icon(Icons.close, color: _c.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: _c.border)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    cursorColor: _c.textPrimary,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _c.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search sectors...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _c.textMuted,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: _c.textMuted,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: _c.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _c.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _c.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.30),
                        ),
                      ),
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
                        OutlinedButton.icon(
                          onPressed: _addCustomSector,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text(
                            'ADD CUSTOM SECTOR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.8,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _c.textPrimary,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.20),
                            ),
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
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
                    child: FilledButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.of(context).pop(_selected.toList()),
                      style: FilledButton.styleFrom(
                        backgroundColor: _c.textPrimary,
                        disabledBackgroundColor: _c.textPrimary.withValues(
                          alpha: 0.40,
                        ),
                        foregroundColor: _c.textPrimary,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.20),
                          ),
                        ),
                      ),
                      child: Text(
                        'SAVE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: _c.textPrimary,
                        ),
                      ),
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
    final newSector = await showDialog<String>(
      context: context,
      builder: (context) {
        final _c = AppTheme.colorsOf(context);
        return AlertDialog(
          backgroundColor: _c.background,
          title: Text(
            'Add custom sector',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _c.textPrimary,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            cursorColor: _c.textPrimary,
            style: TextStyle(color: _c.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Mobility',
              hintStyle: TextStyle(color: _c.textMuted),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.30),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              style: FilledButton.styleFrom(
                backgroundColor: _c.textPrimary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        );
      },
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
