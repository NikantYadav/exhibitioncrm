import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const Color _background = Color(0xFF080808);
  static const Color _surfaceContainerLow = Color(0xFF0C0C0C);
  static const Color _outline = Color(0x1AFFFFFF);
  static const Color _primary = Color(0xFFFFFFFF);
  static const Color _onPrimary = Color(0xFF000000);
  static const Color _onSurfaceVariant = Color(0xFFA3A3A3);

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
            decoration: const BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(top: BorderSide(color: _outline)),
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
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _outline)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'EDIT SECTORS',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: _primary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 20,
                        icon: const Icon(Icons.close, color: _onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _outline)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    cursorColor: _primary,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _primary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search sectors...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _onSurfaceVariant,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: _onSurfaceVariant,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: _surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _outline),
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
                          label: Text(
                            'ADD CUSTOM SECTOR',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.8,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primary,
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
                  decoration: const BoxDecoration(
                    color: _background,
                    border: Border(top: BorderSide(color: _outline)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.of(context).pop(_selected.toList()),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        disabledBackgroundColor: Colors.black.withValues(
                          alpha: 0.40,
                        ),
                        foregroundColor: _primary,
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
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: _primary,
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
          color: isSelected ? _primary : _background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? _primary : Colors.white.withValues(alpha: 0.20),
          ),
        ),
        child: Text(
          sector,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? _onPrimary : _primary,
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
        return AlertDialog(
          backgroundColor: _background,
          title: Text(
            'Add custom sector',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _primary,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            cursorColor: _primary,
            style: GoogleFonts.inter(color: _primary),
            decoration: InputDecoration(
              hintText: 'e.g. Mobility',
              hintStyle: GoogleFonts.inter(color: _onSurfaceVariant),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _outline),
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
                backgroundColor: _primary,
                foregroundColor: _onPrimary,
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
