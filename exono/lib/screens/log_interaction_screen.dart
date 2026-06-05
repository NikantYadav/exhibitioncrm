import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showLogInteractionSheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.60),
    builder: (_) => const _LogInteractionSheet(),
  );

  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Interaction saved to timeline. (UI-only)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _LogInteractionSheet extends StatefulWidget {
  const _LogInteractionSheet();

  @override
  State<_LogInteractionSheet> createState() => _LogInteractionSheetState();
}

class _LogInteractionSheetState extends State<_LogInteractionSheet> {
  static const Color _background = Color(0xFF080808);
  static const Color _surfaceContainerLow = Color(0xFF1C1B1B);

  static const Color _outlineVariant = Color(0xFF444748);
  static const Color _primary = Color(0xFFFFFFFF);
  static const Color _onPrimary = Color(0xFF2F3131);
  static const Color _onSurface = Color(0xFFE5E2E1);
  static const Color _onSurfaceVariant = Color(0xFFC4C7C8);
  static const Color _success = Color(0xFF22C55E);

  final TextEditingController _notesController = TextEditingController();

  final List<String> _interactionTypes = const [
    'Meeting',
    'Call',
    'WhatsApp',
    'Lunch',
    'Video Call',
    'Site Visit',
    'Other',
  ];

  String _selectedType = 'Meeting';
  DateTime _selectedDate = DateTime(2023, 10, 27);
  bool _isSaving = false;
  bool _isSaved = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.92;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
            child: Container(
              decoration: const BoxDecoration(
                color: _background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(
                  top: BorderSide(color: _outlineVariant),
                  left: BorderSide(color: _outlineVariant),
                  right: BorderSide(color: _outlineVariant),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _outlineVariant.withValues(alpha: 0.50),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Log Interaction',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: _primary,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 42,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _interactionTypes.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final type = _interactionTypes[index];
                                final isSelected = type == _selectedType;
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedType = type;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(999),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? _primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: isSelected
                                            ? _primary
                                            : _outlineVariant,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        type,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? _onPrimary
                                              : _onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 30),
                          _buildLabel('DATE'),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 52,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: _surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _outlineVariant),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatDate(_selectedDate),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: _onSurface,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 20,
                                    color: _onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(child: _buildLabel('WHAT HAPPENED?')),
                              const SizedBox(width: 8),
                              _buildRoundIconButton(
                                icon: Icons.mic,
                                onTap: () => _showUiOnlyMessage(
                                  'Voice note capture is UI-only for now.',
                                ),
                              ),
                              const SizedBox(width: 6),
                              _buildRoundIconButton(
                                icon: Icons.attach_file,
                                onTap: () => _showUiOnlyMessage(
                                  'Attachment upload is UI-only for now.',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: _surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _outlineVariant),
                            ),
                            child: TextField(
                              controller: _notesController,
                              minLines: 6,
                              maxLines: 6,
                              cursorColor: _primary,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: _onSurface,
                                height: 1.45,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Type summary or key discussion points...',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: _onSurfaceVariant.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.auto_awesome,
                                  size: 18,
                                  color: _primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'AI will summarize these notes for the executive dashboard.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _saveInteraction,
                        style: FilledButton.styleFrom(
                          backgroundColor: _isSaved ? _success : _primary,
                          foregroundColor: _onPrimary,
                          disabledBackgroundColor: _primary.withValues(
                            alpha: 0.88,
                          ),
                          disabledForegroundColor: _onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _isSaving
                              ? SizedBox(
                                  key: const ValueKey('saving'),
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _onPrimary,
                                  ),
                                )
                              : Row(
                                  key: ValueKey(_isSaved ? 'saved' : 'idle'),
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _isSaved ? 'Saved' : 'Save to Timeline',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: _onPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      _isSaved
                                          ? Icons.check_circle
                                          : Icons.arrow_forward,
                                      size: 20,
                                      color: _onPrimary,
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
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.6,
        color: _onSurfaceVariant,
      ),
    );
  }

  Widget _buildRoundIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, size: 20, color: _onSurfaceVariant),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              surface: _surfaceContainerLow,
              primary: _primary,
              onPrimary: _onPrimary,
              onSurface: _onSurface,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: _background),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveInteraction() async {
    setState(() {
      _isSaving = true;
      _isSaved = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _isSaved = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  void _showUiOnlyMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
