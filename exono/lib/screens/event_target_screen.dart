import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_header.dart';
import '../widgets/app_section_label.dart';

class EventTargetScreen extends StatefulWidget {
  final Event event;
  final Map<String, dynamic> target;
  const EventTargetScreen({super.key, required this.event, required this.target});
  @override
  State<EventTargetScreen> createState() => _EventTargetScreenState();
}

class _EventTargetScreenState extends State<EventTargetScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  late Map<String, dynamic> _target;
  bool _isGenerating = false;
  bool _isLoadingContacts = true;
  List<Map<String, dynamic>> _contacts = [];

  // Editing state
  bool _editingBooth = false;
  bool _editingNotes = false;
  late TextEditingController _boothCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _target = widget.target;
    _boothCtrl = TextEditingController(text: _target['booth_location'] as String? ?? '');
    _notesCtrl = TextEditingController(text: _target['notes'] as String? ?? '');
    _loadContacts();
  }

  @override
  void dispose() {
    _boothCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _company => (_target['company'] as Map<String, dynamic>?) ?? {};
  String get _companyName => _company['name'] as String? ?? 'Unknown';
  String get _industry => _company['industry'] as String? ?? '';
  String get _status => _target['status'] as String? ?? 'not_contacted';

  List<String> get _talkingPoints {
    final raw = _target['talking_points'] as String?;
    if (raw != null && raw.trim().isNotEmpty) {
      return raw.split('\n').where((s) => s.trim().isNotEmpty).toList();
    }
    return [];
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await ApiService.getTargetContacts(widget.event.id, _target['id'] as String);
      setState(() { _contacts = contacts; _isLoadingContacts = false; });
    } catch (_) {
      setState(() => _isLoadingContacts = false);
    }
  }

  Future<void> _saveBooth() async {
    final booth = _boothCtrl.text.trim();
    try {
      await ApiService.updateEventTarget(widget.event.id, _target['id'] as String, {'booth_location': booth.isEmpty ? null : booth});
      setState(() {
        _target = {..._target, 'booth_location': booth.isEmpty ? null : booth};
        _editingBooth = false;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save booth.'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _saveNotes() async {
    final notes = _notesCtrl.text.trim();
    try {
      await ApiService.updateEventTarget(widget.event.id, _target['id'] as String, {'notes': notes.isEmpty ? null : notes});
      setState(() {
        _target = {..._target, 'notes': notes.isEmpty ? null : notes};
        _editingNotes = false;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save notes.'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _toggleContactLink(Map<String, dynamic> contact) async {
    final contactId = contact['id'] as String;
    final isLinked = contact['linked_to_event'] as bool? ?? false;
    try {
      if (isLinked) {
        await ApiService.unlinkContactFromTarget(widget.event.id, _target['id'] as String, contactId);
      } else {
        await ApiService.linkContactToTarget(widget.event.id, _target['id'] as String, contactId);
      }
      setState(() {
        final idx = _contacts.indexWhere((c) => c['id'] == contactId);
        if (idx != -1) _contacts[idx] = {..._contacts[idx], 'linked_to_event': !isLinked};
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update contact link.'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _generateBriefing() async {
    setState(() => _isGenerating = true);
    try {
      final updated = await ApiService.generateTargetBriefing(widget.event.id, _target['id'] as String);
      setState(() { _target = updated; _isGenerating = false; });
    } catch (_) {
      setState(() => _isGenerating = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to generate briefing.'), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final booth = _target['booth_location'] as String?;

    return Scaffold(
      backgroundColor: _c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              onNotificationPressed: () {},
              actionWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppChip.status(
                    _status.replaceAll('_', ' ').toUpperCase(),
                    color: _status == 'researched' ? _c.success : _c.textMuted,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(_target),
                    icon: Icon(Icons.arrow_back_rounded, color: _c.textPrimary, size: 22),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company header
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      radius: 20,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_companyName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: _c.textPrimary)),
                                if (_industry.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(_industry, style: TextStyle(fontSize: 14, color: _c.textMuted)),
                                ],
                                if (booth != null && booth.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  AppChip.label('BOOTH $booth'),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Overview: Booth + Notes
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      radius: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSectionLabel('Overview'),
                          const SizedBox(height: 16),
                          // Booth row
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 18, color: _c.textMuted),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _editingBooth
                                    ? TextField(
                                        controller: _boothCtrl,
                                        autofocus: true,
                                        style: TextStyle(fontSize: 14, color: _c.textPrimary),
                                        cursorColor: _c.accent,
                                        textCapitalization: TextCapitalization.characters,
                                        decoration: InputDecoration(
                                          hintText: 'e.g. A-12',
                                          hintStyle: TextStyle(color: _c.textMuted),
                                          isDense: true,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _c.border)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _c.accent)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          filled: true,
                                          fillColor: _c.surface,
                                        ),
                                      )
                                    : Text(
                                        (booth != null && booth.isNotEmpty) ? booth : 'Booth not set',
                                        style: TextStyle(fontSize: 14, color: (booth != null && booth.isNotEmpty) ? _c.textSecondary : _c.textMuted),
                                      ),
                              ),
                              if (_editingBooth) ...[
                                const SizedBox(width: 8),
                                TextButton(onPressed: _saveBooth, child: Text('Save', style: TextStyle(color: _c.accent, fontWeight: FontWeight.w600))),
                                TextButton(onPressed: () => setState(() => _editingBooth = false), child: Text('Cancel', style: TextStyle(color: _c.textMuted))),
                              ] else
                                IconButton(
                                  onPressed: () => setState(() => _editingBooth = true),
                                  icon: Icon(Icons.edit_outlined, size: 18, color: _c.textMuted),
                                  splashRadius: 16,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  padding: EdgeInsets.zero,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(color: _c.border, height: 1),
                          const SizedBox(height: 12),
                          // Notes row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.notes_outlined, size: 18, color: _c.textMuted),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _editingNotes
                                    ? TextField(
                                        controller: _notesCtrl,
                                        autofocus: true,
                                        maxLines: 4,
                                        style: TextStyle(fontSize: 14, color: _c.textPrimary),
                                        cursorColor: _c.accent,
                                        decoration: InputDecoration(
                                          hintText: 'Add notes about this company...',
                                          hintStyle: TextStyle(color: _c.textMuted),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _c.border)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _c.accent)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          filled: true,
                                          fillColor: _c.surface,
                                        ),
                                      )
                                    : Text(
                                        (_target['notes'] as String?)?.isNotEmpty == true
                                            ? _target['notes'] as String
                                            : 'No notes yet',
                                        style: TextStyle(fontSize: 14, color: (_target['notes'] as String?)?.isNotEmpty == true ? _c.textSecondary : _c.textMuted, height: 1.5),
                                      ),
                              ),
                              if (_editingNotes) ...[
                                const SizedBox(width: 8),
                                Column(
                                  children: [
                                    TextButton(onPressed: _saveNotes, child: Text('Save', style: TextStyle(color: _c.accent, fontWeight: FontWeight.w600))),
                                    TextButton(onPressed: () => setState(() => _editingNotes = false), child: Text('Cancel', style: TextStyle(color: _c.textMuted))),
                                  ],
                                ),
                              ] else
                                IconButton(
                                  onPressed: () => setState(() => _editingNotes = true),
                                  icon: Icon(Icons.edit_outlined, size: 18, color: _c.textMuted),
                                  splashRadius: 16,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  padding: EdgeInsets.zero,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Contacts
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      radius: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: AppSectionLabel('Contacts')),
                              if (!_isLoadingContacts)
                                Text(
                                  '${_contacts.where((c) => c['linked_to_event'] == true).length} LINKED',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: _c.accent),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_isLoadingContacts)
                            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                          else if (_contacts.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'No contacts found for this company.',
                                style: TextStyle(fontSize: 14, color: _c.textMuted),
                              ),
                            )
                          else
                            ..._contacts.map((contact) => _buildContactRow(contact)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // AI Research
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      radius: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 16, color: _c.accent),
                              const SizedBox(width: 8),
                              Expanded(child: AppSectionLabel('AI Research', color: _c.accent)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _isGenerating ? null : _generateBriefing,
                              style: FilledButton.styleFrom(
                                backgroundColor: _c.accent,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _c.surfaceElevated,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                elevation: 0,
                              ),
                              icon: _isGenerating
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.auto_awesome, size: 16),
                              label: Text(
                                _isGenerating ? 'GENERATING...' : (_talkingPoints.isEmpty ? 'GENERATE AI BRIEFING' : 'REGENERATE'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.6),
                              ),
                            ),
                          ),
                          if (_talkingPoints.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            ..._talkingPoints.asMap().entries.map((e) => Padding(
                              padding: EdgeInsets.only(bottom: e.key < _talkingPoints.length - 1 ? 14 : 0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 22, height: 22,
                                    margin: const EdgeInsets.only(top: 1),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(color: _c.accentSoft, borderRadius: BorderRadius.circular(6)),
                                    child: Text('${e.key + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _c.accent)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(e.value, style: TextStyle(fontSize: 14, color: _c.textSecondary, height: 1.5))),
                                ],
                              ),
                            )),
                          ] else if (!_isGenerating) ...[
                            const SizedBox(height: 16),
                            Text('No briefing yet. Generate one above.', style: TextStyle(fontSize: 13, color: _c.textMuted)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(Map<String, dynamic> contact) {
    final isLinked = contact['linked_to_event'] as bool? ?? false;
    final firstName = contact['first_name'] as String? ?? '';
    final lastName = contact['last_name'] as String? ?? '';
    final jobTitle = contact['job_title'] as String? ?? '';
    final initials = (firstName.isNotEmpty ? firstName[0] : '') + (lastName.isNotEmpty ? lastName[0] : '');

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isLinked ? _c.accentSoft : _c.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: isLinked ? _c.accent : _c.border),
            ),
            child: Text(initials.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isLinked ? _c.accent : _c.textMuted)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$firstName $lastName'.trim(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _c.textPrimary)),
                if (jobTitle.isNotEmpty)
                  Text(jobTitle, style: TextStyle(fontSize: 12, color: _c.textMuted)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _toggleContactLink(contact),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isLinked ? _c.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isLinked ? _c.accent : _c.border),
              ),
              child: Text(
                isLinked ? 'LINKED' : 'LINK',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: isLinked ? _c.accent : _c.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
