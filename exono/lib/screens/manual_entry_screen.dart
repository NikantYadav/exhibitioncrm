import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_section_label.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class ManualEntryResult {
  final String savedName;
  const ManualEntryResult(this.savedName);
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  // ── Controllers ────────────────────────────────────────────
  final _fnCtrl      = TextEditingController();
  final _lnCtrl      = TextEditingController();
  final _coCtrl      = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _titleCtrl   = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _notesCtrl   = TextEditingController();

  // ── State ──────────────────────────────────────────────────
  List<Event> _events    = [];
  String?     _eventId;
  bool        _isSaving  = false;
  bool        _saved     = false;
  bool        _showDedup = false;
  List<Map<String, dynamic>> _dupes = [];
  final List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _fnCtrl.dispose();
    _lnCtrl.dispose();
    _coCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _titleCtrl.dispose();
    _linkedinCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await ApiService.getEvents();
      if (!mounted) return;
      setState(() {
        _events = events;
        if (events.isNotEmpty) _eventId = events.first.id;
      });
    } catch (_) {}
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildIdentityCard(),
                      const SizedBox(height: 20),
                      AppSectionLabel('Work'),
                      const SizedBox(height: 10),
                      _buildWorkCard(),
                      const SizedBox(height: 20),
                      AppSectionLabel('Contact Info'),
                      const SizedBox(height: 10),
                      _buildContactInfoCard(),
                      if (_events.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        AppSectionLabel('Event'),
                        const SizedBox(height: 10),
                        _buildEventSelector(),
                      ],
                      const SizedBox(height: 20),
                      AppSectionLabel('Notes'),
                      const SizedBox(height: 10),
                      _buildNotesCard(),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          AppSectionLabel('Tags'),
                          const Spacer(),
                          GestureDetector(
                            onTap: _showAddTagSheet,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, size: 12, color: _c.accent),
                                const SizedBox(width: 4),
                                Text(
                                  'ADD TAG',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: _c.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_tags.isNotEmpty)
                        _buildTagsRow()
                      else
                        Text(
                          'No tags yet — tap Add Tag to label this contact.',
                          style: TextStyle(fontSize: 12, color: _c.textMuted, height: 1.5),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildSaveButton(),
          ),
          if (_showDedup) _buildDedupSheet(),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Material(
      color: _c.navBackground,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: _c.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _c.textPrimary,
                  size: 18,
                ),
              ),
              const Spacer(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'NEW CONTACT',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                      color: _c.textPrimary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Enter details manually',
                    style: TextStyle(fontSize: 10, color: _c.textMuted),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: _c.textMuted, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Identity card ──────────────────────────────────────────

  Widget _buildIdentityCard() {
    final fn = _fnCtrl.text;
    final ln = _lnCtrl.text;
    final initials = (fn.isNotEmpty ? fn[0] : '') + (ln.isNotEmpty ? ln[0] : '');
    final subtitle = [_titleCtrl.text, _coCtrl.text]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return AppCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      borderColor: _c.border,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_c.accent, _c.accentStrong],
              ),
            ),
            alignment: Alignment.center,
            child: initials.isEmpty
                ? Icon(Icons.person_outline_rounded, color: Colors.white, size: 32)
                : Text(
                    initials.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppChip.label('Manual Entry', color: _c.surfaceElevated, textColor: _c.textMuted),
                const SizedBox(height: 8),
                _inlineField(_fnCtrl, 'First name', fontSize: 22, bold: true),
                const SizedBox(height: 2),
                _inlineField(_lnCtrl, 'Last name', fontSize: 15),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: _c.textMuted, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineField(
    TextEditingController ctrl,
    String hint, {
    double fontSize = 14,
    bool bold = false,
  }) {
    return TextField(
      controller: ctrl,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        color: _c.textPrimary,
      ),
      cursorColor: _c.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: fontSize, color: _c.textMuted),
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  // ── Field cards ────────────────────────────────────────────

  Widget _buildWorkCard() {
    return AppCard(
      elevated: true,
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          _fieldRow(Icons.business_outlined, _coCtrl, 'Company'),
          Divider(height: 1, color: _c.border),
          _fieldRow(Icons.work_outline_rounded, _titleCtrl, 'Job title'),
        ],
      ),
    );
  }

  Widget _buildContactInfoCard() {
    return AppCard(
      elevated: true,
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          _fieldRow(Icons.email_outlined, _emailCtrl, 'Email', kbd: TextInputType.emailAddress),
          Divider(height: 1, color: _c.border),
          _fieldRow(Icons.phone_outlined, _phoneCtrl, 'Phone', kbd: TextInputType.phone),
          Divider(height: 1, color: _c.border),
          _fieldRow(Icons.link_outlined, _linkedinCtrl, 'LinkedIn URL', kbd: TextInputType.url),
        ],
      ),
    );
  }

  Widget _fieldRow(
    IconData icon,
    TextEditingController ctrl,
    String hint, {
    TextInputType? kbd,
  }) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          Icon(icon, size: 15, color: _c.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: kbd,
              style: TextStyle(fontSize: 14, color: _c.textPrimary),
              cursorColor: _c.accent,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 14, color: _c.textMuted),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Event selector ─────────────────────────────────────────

  Widget _buildEventSelector() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.event_outlined, size: 15, color: _c.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _eventId,
                isExpanded: true,
                dropdownColor: _c.surfaceAlt,
                icon: Icon(Icons.expand_more, color: _c.textMuted, size: 18),
                style: TextStyle(fontSize: 14, color: _c.textPrimary),
                hint: Text(
                  'Select event',
                  style: TextStyle(color: _c.textMuted, fontSize: 14),
                ),
                items: _events
                    .map(
                      (e) => DropdownMenuItem(value: e.id, child: Text(e.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _eventId = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Notes ──────────────────────────────────────────────────

  Widget _buildNotesCard() {
    return AppCard(
      elevated: true,
      radius: 20,
      padding: const EdgeInsets.all(4),
      child: TextField(
        controller: _notesCtrl,
        maxLines: 5,
        style: TextStyle(
          fontSize: 14,
          color: _c.textSecondary,
          height: 1.6,
        ),
        cursorColor: _c.accent,
        decoration: InputDecoration(
          hintText: 'Context, talking points, next steps…',
          hintStyle: TextStyle(fontSize: 14, color: _c.textMuted, height: 1.5),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  // ── Tags ───────────────────────────────────────────────────

  Widget _buildTagsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _tags
            .map(
              (tag) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onLongPress: () => setState(() => _tags.remove(tag)),
                  child: AppChip(tag),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _showAddTagSheet() async {
    final ctrl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _c.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'ADD TAG',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: _c.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                elevated: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: TextStyle(fontSize: 14, color: _c.textPrimary),
                  cursorColor: _c.accent,
                  decoration: InputDecoration(
                    hintText: 'e.g. investor, follow-up, warm-lead',
                    hintStyle: TextStyle(fontSize: 14, color: _c.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onSubmitted: (val) {
                    final tag = val.trim();
                    if (tag.isNotEmpty && !_tags.contains(tag)) {
                      setState(() => _tags.add(tag));
                    }
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    final tag = ctrl.text.trim();
                    if (tag.isNotEmpty && !_tags.contains(tag)) {
                      setState(() => _tags.add(tag));
                    }
                    Navigator.of(ctx).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _c.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'ADD',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Save button ────────────────────────────────────────────

  Widget _buildSaveButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 14, 16,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: _c.navBackground,
        border: Border(top: BorderSide(color: _c.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          onPressed: (_isSaving || _saved) ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: _saved ? _c.success : _c.accent,
            disabledBackgroundColor: _saved ? _c.success : _c.surfaceElevated,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusButton),
            ),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _saved ? Icons.check_circle_outline_rounded : Icons.person_add_outlined,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _saved ? 'CONTACT SAVED' : 'SAVE CONTACT',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Dedup sheet ────────────────────────────────────────────

  Widget _buildDedupSheet() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: _c.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _c.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: _c.accent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Possible duplicate detected',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: _c.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_dupes.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            AppSectionLabel('Existing record'),
                            const SizedBox(height: 10),
                            AppCard(
                              elevated: true,
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_dupes.first['first_name'] ?? ''} ${_dupes.first['last_name'] ?? ''}'
                                        .trim(),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _c.textPrimary,
                                    ),
                                  ),
                                  if (_dupes.first['email'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _dupes.first['email'] as String,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _c.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if (_dupes.first['company'] != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      (_dupes.first['company']
                                                  as Map?)?['name'] ??
                                              '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _c.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      MediaQuery.of(context).padding.bottom + 16,
                    ),
                    child: Column(
                      children: [
                        _dedupAction(
                          'MERGE WITH EXISTING',
                          primary: true,
                          onTap: () =>
                              _resolveDuplicateAndSave(merge: true),
                        ),
                        const SizedBox(height: 10),
                        _dedupAction(
                          'CREATE AS NEW CONTACT',
                          onTap: () =>
                              _resolveDuplicateAndSave(merge: false),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () =>
                              setState(() => _showDedup = false),
                          child: Text(
                            'CANCEL',
                            style: TextStyle(
                              fontSize: 11,
                              color: _c.textMuted,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dedupAction(
    String label, {
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: primary ? _c.accent : _c.surfaceElevated,
          foregroundColor: primary ? Colors.white : _c.textSecondary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────

  Future<void> _save() async {
    final fn = _fnCtrl.text.trim();
    final ln = _lnCtrl.text.trim();
    final name = '$fn $ln'.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter at least a name'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final dupResult = await ApiService.checkDuplicateContacts(
        name: name,
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      if (dupResult['has_duplicates'] == true) {
        setState(() {
          _dupes = List<Map<String, dynamic>>.from(
            dupResult['data'] as List? ?? [],
          );
          _isSaving = false;
          _showDedup = true;
        });
        return;
      }
      await _doSave();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save contact'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _doSave() async {
    try {
      final fn = _fnCtrl.text.trim();
      final ln = _lnCtrl.text.trim();
      await ApiService.createCapture(
        captureType: 'manual',
        rawText: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        eventId: _eventId,
        extractedData: {
          'first_name':   fn,
          'last_name':    ln,
          'name':         '$fn $ln'.trim(),
          'company':      _coCtrl.text.trim(),
          'email':        _emailCtrl.text.trim(),
          'phone':        _phoneCtrl.text.trim(),
          'job_title':    _titleCtrl.text.trim(),
          'linkedin_url': _linkedinCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        _saved     = true;
        _isSaving  = false;
        _showDedup = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;
      Navigator.of(context).pop(
        ManualEntryResult('$fn $ln'.trim()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saved    = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save contact'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _resolveDuplicateAndSave({required bool merge}) async {
    setState(() {
      _showDedup = false;
      _isSaving  = true;
    });
    await _doSave();
  }
}
