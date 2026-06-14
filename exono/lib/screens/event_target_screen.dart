import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../config/app_theme.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_header.dart';
import '../widgets/app_section_label.dart';
import '../widgets/app_feedback.dart';
import '../widgets/skeleton_loader.dart';
import '../utils/screen_logger.dart';

class EventTargetScreen extends StatefulWidget {
  final Event event;
  final String targetId;
  const EventTargetScreen({super.key, required this.event, required this.targetId});
  @override
  State<EventTargetScreen> createState() => _EventTargetScreenState();
}

class _EventTargetScreenState extends State<EventTargetScreen> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  Map<String, dynamic> _target = {};
  bool _isLoadingTarget = true;
  bool _isLoadingContacts = true;
  List<Map<String, dynamic>> _contacts = [];

  bool _isEnriching = false;
  String? _enrichError;

  bool _isGenerating = false;
  String? _briefingError;
  List<String> _talkingPoints = [];
  bool _useNotesForBriefing = false;

  bool _editingBooth = false;
  bool _editingNotes = false;
  late TextEditingController _boothCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _boothCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _loadTarget();
  }

  Future<void> _loadTarget() async {
    try {
      final data = await ApiService.getEventTarget(widget.event.id, widget.targetId);
      if (!mounted) return;
      setState(() {
        _target = data;
        _isLoadingTarget = false;
        _boothCtrl.text = _target['booth_location'] as String? ?? '';
        _notesCtrl.text = _target['notes'] as String? ?? '';
        _useNotesForBriefing = _target['use_notes_for_briefing'] as bool? ?? false;
        final raw = _target['talking_points'] as String?;
        if (raw != null && raw.trim().isNotEmpty) {
          _talkingPoints = raw.split('\n').where((s) => s.trim().isNotEmpty).toList();
        }
      });
      _loadContacts();
      _autoEnrich();
    } catch (_) {
      if (mounted) setState(() => _isLoadingTarget = false);
    }
  }

  @override
  void dispose() {
    _boothCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _company => (_target['company'] as Map<String, dynamic>?) ?? {};
  String get _companyId => _company['id'] as String? ?? '';
  String get _companyName => _company['name'] as String? ?? 'Unknown';
  String get _industry => _company['industry'] as String? ?? '';

  Future<void> _autoEnrich() async {
    if (_companyId.isEmpty) return;
    final enrichedAt = _company['enriched_at'] as String?;
    final failed = _company['enrichment_failed'] as bool? ?? false;
    if (enrichedAt != null && !failed) return;

    setState(() { _isEnriching = true; _enrichError = null; });
    try {
      final updated = await ApiService.enrichCompany(_companyId);
      if (mounted) { setState(() {
        _target = {..._target, 'company': updated};
        _isEnriching = false;
      }); }
    } catch (_) {
      if (mounted) { setState(() {
        _isEnriching = false;
        _enrichError = 'Could not load company details. Will retry next visit.';
      }); }
    }
  }

  Future<void> _generateBriefing() async {
    if (_companyId.isEmpty) return;
    setState(() { _isGenerating = true; _briefingError = null; _talkingPoints = []; });
    try {
      final notes = _useNotesForBriefing ? (_target['notes'] as String?) : null;
      final points = await ApiService.generateCompanyBriefing(_companyId, notes: notes);
      if (mounted) { setState(() { _talkingPoints = List<String>.from(points); _isGenerating = false; }); }
    } catch (_) {
      if (mounted) { setState(() {
        _isGenerating = false;
        _briefingError = 'Could not generate talking points. Please try again.';
      }); }
    }
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await ApiService.getTargetContacts(widget.event.id, _target['id'] as String);
      final targetContacts = await ApiService.getEventTargetContacts(widget.event.id);
      final targetContactIds = targetContacts.map((c) => c['contact_id'] as String?).whereType<String>().toSet();
      final tagged = contacts.map((c) => {
        ...c,
        'is_target_contact': targetContactIds.contains(c['id'] as String?),
      }).toList();
      setState(() { _contacts = tagged; _isLoadingContacts = false; });
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
      if (mounted) showAppToast(context, 'Failed to save booth.');
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
      if (_useNotesForBriefing && notes.isNotEmpty) {
        await _generateBriefing();
      }
    } catch (_) {
      if (mounted) showAppToast(context, 'Failed to save notes.');
    }
  }

  Future<void> _toggleTargetContact(Map<String, dynamic> contact) async {
    final contactId = contact['id'] as String;
    final isTarget = contact['is_target_contact'] as bool? ?? false;
    try {
      if (isTarget) {
        await ApiService.removeContactFromEvent(widget.event.id, contactId);
      } else {
        await ApiService.addContactToEvent(widget.event.id, contactId);
      }
      setState(() {
        final idx = _contacts.indexWhere((c) => c['id'] == contactId);
        if (idx != -1) { _contacts[idx] = {..._contacts[idx], 'is_target_contact': !isTarget}; }
      });
    } catch (_) {
      if (mounted) showAppToast(context, 'Failed to update target contact.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingTarget) {
      return ColoredBox(
        color: context.theme.colors.background,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              FHeader.nested(
                title: const SizedBox.shrink(),
                prefixes: [
                  AppHeaderActionButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(child: _buildSkeletonLoader()),
            ],
          ),
        ),
      );
    }

    final co = _company;
    final booth = _target['booth_location'] as String?;
    final desc = co['description'] as String? ?? '';
    final products = co['products_services'] as String? ?? '';
    final location = co['location'] as String? ?? '';
    final website = co['website'] as String? ?? '';
    final headquarters = co['headquarters'] as String? ?? '';
    final employeeCount = co['employee_count'] as String? ?? '';
    final foundedYear = co['founded_year'] as String? ?? '';
    final ticker = co['ticker_symbol'] as String? ?? '';
    final size = co['company_size'] as String? ?? '';
    final initials = _companyName.length >= 2
        ? _companyName.substring(0, 2).toUpperCase()
        : _companyName.toUpperCase();

    return ColoredBox(
      color: context.theme.colors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            FHeader.nested(
              title: const SizedBox.shrink(),
              prefixes: [
                AppHeaderActionButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => Navigator.of(context).pop(_target),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Company hero card ──────────────────────────────────────
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      radius: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppAvatar(initials: initials, size: 56),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_companyName, style: context.theme.typography.xl.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4, color: context.theme.colors.foreground)),
                                    if (_industry.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(_industry, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
                                    ],
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        if (booth != null && booth.isNotEmpty) AppChip.label('BOOTH $booth'),
                                        if (ticker.isNotEmpty) AppChip.label(ticker),
                                        if (size.isNotEmpty) AppChip.label('${size.toUpperCase()} EMP'),
                                        if (foundedYear.isNotEmpty) AppChip.label('EST. $foundedYear'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (_isEnriching) ...[
                            const SizedBox(height: 14),
                            Row(children: [
                              const SizedBox(width: 12, height: 12, child: FCircularProgress()),
                              const SizedBox(width: 8),
                              Text('Loading company details…', style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground, fontStyle: FontStyle.italic)),
                            ]),
                          ] else if (_enrichError != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoBanner(_enrichError!, isError: true),
                          ] else if (headquarters.isNotEmpty || employeeCount.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(height: 1, color: context.theme.colors.border.withValues(alpha: 0.5)),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 16,
                              runSpacing: 10,
                              children: [
                                if (headquarters.isNotEmpty) _statItem(Icons.location_on_outlined, headquarters),
                                if (employeeCount.isNotEmpty) _statItem(Icons.people_outline_rounded, employeeCount),
                              ],
                            ),
                          ],

                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(height: 1, color: context.theme.colors.border.withValues(alpha: 0.5)),
                            const SizedBox(height: 14),
                            Text(desc, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground, height: 1.55)),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Details card ───────────────────────────────────────────
                    if (location.isNotEmpty || website.isNotEmpty || products.isNotEmpty)
                      AppCard(
                        padding: const EdgeInsets.all(20),
                        radius: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppSectionLabel('Details'),
                            const SizedBox(height: 14),
                            if (location.isNotEmpty) _infoRow(Icons.location_on_outlined, location),
                            if (website.isNotEmpty) _infoRow(Icons.language_rounded, website),
                            if (products.isNotEmpty) ...[
                              if (location.isNotEmpty || website.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(height: 1, color: context.theme.colors.border.withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                              ],
                              AppSectionLabel('Products & Services'),
                              const SizedBox(height: 8),
                              Text(products, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground, height: 1.5)),
                            ],
                          ],
                        ),
                      ),

                    if (location.isNotEmpty || website.isNotEmpty || products.isNotEmpty)
                      const SizedBox(height: 16),

                    // ── Overview: Booth + Notes ────────────────────────────────
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      radius: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSectionLabel('Overview'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 18, color: _c.accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _editingBooth
                                    ? AppInput(
                                        controller: _boothCtrl,
                                        hintText: 'e.g. A-12',
                                      )
                                    : Text(
                                        (booth != null && booth.isNotEmpty) ? booth : 'Booth not set',
                                        style: context.theme.typography.sm.copyWith(
                                          color: (booth != null && booth.isNotEmpty)
                                              ? context.theme.colors.foreground
                                              : context.theme.colors.mutedForeground,
                                        ),
                                      ),
                              ),
                              if (_editingBooth) ...[
                                const SizedBox(width: 8),
                                AppButton(label: 'Save', variant: ButtonVariant.ghost, size: ButtonSize.sm, onPressed: _saveBooth),
                                AppButton(label: 'Cancel', variant: ButtonVariant.ghost, size: ButtonSize.sm, onPressed: () => setState(() => _editingBooth = false)),
                              ] else
                                AppButton(
                                  variant: ButtonVariant.ghost,
                                  size: ButtonSize.sm,
                                  onPressed: () => setState(() => _editingBooth = true),
                                  child: Icon(Icons.edit_outlined, size: 18, color: _c.accent),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.notes_outlined, size: 18, color: _c.accent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _editingNotes
                                    ? AppInput(
                                        controller: _notesCtrl,
                                        maxLines: 4,
                                        hintText: 'Add notes about this company...',
                                      )
                                    : Text(
                                        (_target['notes'] as String?)?.isNotEmpty == true
                                            ? _target['notes'] as String
                                            : 'No notes yet',
                                        style: context.theme.typography.sm.copyWith(
                                          color: (_target['notes'] as String?)?.isNotEmpty == true
                                              ? context.theme.colors.foreground
                                              : context.theme.colors.mutedForeground,
                                          height: 1.5,
                                        ),
                                      ),
                              ),
                              if (_editingNotes) ...[
                                const SizedBox(width: 8),
                                Column(children: [
                                  AppButton(label: 'Save', variant: ButtonVariant.ghost, size: ButtonSize.sm, onPressed: _saveNotes),
                                  AppButton(label: 'Cancel', variant: ButtonVariant.ghost, size: ButtonSize.sm, onPressed: () => setState(() => _editingNotes = false)),
                                ]),
                              ] else
                                AppButton(
                                  variant: ButtonVariant.ghost,
                                  size: ButtonSize.sm,
                                  onPressed: () => setState(() => _editingNotes = true),
                                  child: Icon(Icons.edit_outlined, size: 18, color: _c.accent),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Contacts ──────────────────────────────────────────────
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      radius: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: AppSectionLabel('Contacts')),
                            if (!_isLoadingContacts && _contacts.any((c) => (c['is_target_contact'] as bool?) == true))
                              Text(
                                '${_contacts.where((c) => (c['is_target_contact'] as bool?) == true).length} TARGETED',
                                style: context.theme.typography.xs.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.2, color: _c.accent),
                              ),
                          ]),
                          const SizedBox(height: 12),
                          if (_isLoadingContacts)
                            Column(children: [
                              _buildContactSkeleton(),
                              const SizedBox(height: 12),
                              _buildContactSkeleton(),
                            ])
                          else if (_contacts.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text('No contacts found for this company.', style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
                            )
                          else
                            ..._contacts.map((c) => _buildContactRow(c)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── AI Research ───────────────────────────────────────────
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      radius: 20,
                      borderColor: _c.accent.withValues(alpha: 0.3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.auto_awesome, size: 16, color: _c.accent),
                            const SizedBox(width: 8),
                            Expanded(child: AppSectionLabel('AI Research', color: _c.accent)),
                          ]),
                          const SizedBox(height: 16),
                          if ((_target['notes'] as String?)?.isNotEmpty == true) ...[
                            GestureDetector(
                              onTap: () async {
                                final newVal = !_useNotesForBriefing;
                                setState(() => _useNotesForBriefing = newVal);
                                _target = {..._target, 'use_notes_for_briefing': newVal};
                                try {
                                  await ApiService.updateEventTarget(widget.event.id, _target['id'] as String, {'use_notes_for_briefing': newVal});
                                } catch (_) {}
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _useNotesForBriefing ? _c.accentSoft : _c.surfaceAlt,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _useNotesForBriefing ? _c.accent.withValues(alpha: 0.5) : context.theme.colors.border,
                                  ),
                                ),
                                child: Row(children: [
                                  Icon(
                                    Icons.notes_rounded,
                                    size: 15,
                                    color: _useNotesForBriefing ? _c.accent : context.theme.colors.mutedForeground,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Include my notes',
                                          style: context.theme.typography.sm.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: _useNotesForBriefing ? _c.accent : context.theme.colors.foreground,
                                          ),
                                        ),
                                        Text(
                                          'Feed your notes to the AI when generating',
                                          style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 36,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: _useNotesForBriefing ? _c.accent : _c.surfaceElevated,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: AnimatedAlign(
                                      duration: const Duration(milliseconds: 180),
                                      curve: Curves.easeInOut,
                                      alignment: _useNotesForBriefing ? Alignment.centerRight : Alignment.centerLeft,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        margin: const EdgeInsets.symmetric(horizontal: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          AppButton(
                            label: _isGenerating ? 'GENERATING...' : (_talkingPoints.isEmpty ? 'GENERATE AI BRIEFING' : 'REGENERATE'),
                            fullWidth: true,
                            variant: ButtonVariant.primary,
                            isLoading: _isGenerating,
                            prefixIcon: _isGenerating ? null : const Icon(Icons.auto_awesome, size: 16),
                            onPressed: _isGenerating ? null : _generateBriefing,
                          ),
                          if (_briefingError != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoBanner(_briefingError!, isError: true),
                          ],
                          if (_talkingPoints.isNotEmpty && !_isGenerating) ...[
                            const SizedBox(height: 20),
                            Container(height: 1, color: context.theme.colors.border.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            AppSectionLabel('Talking Points', color: _c.accent),
                            const SizedBox(height: 14),
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
                                    child: Text('${e.key + 1}', style: context.theme.typography.xs.copyWith(fontWeight: FontWeight.w700, color: _c.accent)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(e.value, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground, height: 1.5))),
                                ],
                              ),
                            )),
                          ] else if (!_isGenerating) ...[
                            const SizedBox(height: 14),
                            Text('Generate an AI briefing to get talking points for your next meeting.',
                                style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
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

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SkeletonLoader(width: 56, height: 56, borderRadius: BorderRadius.circular(14)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SkeletonLoader(width: 160, height: 20, borderRadius: BorderRadius.circular(6)),
                      const SizedBox(height: 8),
                      SkeletonLoader(width: 100, height: 14, borderRadius: BorderRadius.circular(4)),
                      const SizedBox(height: 12),
                      Row(children: [
                        SkeletonLoader(width: 60, height: 22, borderRadius: BorderRadius.circular(999)),
                        const SizedBox(width: 6),
                        SkeletonLoader(width: 72, height: 22, borderRadius: BorderRadius.circular(999)),
                      ]),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),
                Container(height: 1, color: context.theme.colors.border.withValues(alpha: 0.4)),
                const SizedBox(height: 14),
                Row(children: [
                  SkeletonLoader(width: 110, height: 13, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(width: 20),
                  SkeletonLoader(width: 90, height: 13, borderRadius: BorderRadius.circular(4)),
                ]),
                const SizedBox(height: 16),
                Container(height: 1, color: context.theme.colors.border.withValues(alpha: 0.4)),
                const SizedBox(height: 14),
                SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 6),
                SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 6),
                SkeletonLoader(width: 200, height: 13, borderRadius: BorderRadius.circular(4)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(20),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 60, height: 11, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 14),
                Row(children: [
                  SkeletonLoader(width: 16, height: 16, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(width: 10),
                  SkeletonLoader(width: 140, height: 13, borderRadius: BorderRadius.circular(4)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  SkeletonLoader(width: 16, height: 16, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(width: 10),
                  SkeletonLoader(width: 180, height: 13, borderRadius: BorderRadius.circular(4)),
                ]),
                const SizedBox(height: 14),
                Container(height: 1, color: context.theme.colors.border.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                SkeletonLoader(width: 120, height: 11, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 8),
                SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 6),
                SkeletonLoader(width: 220, height: 13, borderRadius: BorderRadius.circular(4)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(20),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 70, height: 11, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 16),
                Row(children: [
                  SkeletonLoader(width: 18, height: 18, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(width: 10),
                  SkeletonLoader(width: 120, height: 14, borderRadius: BorderRadius.circular(4)),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  SkeletonLoader(width: 18, height: 18, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(width: 10),
                  SkeletonLoader(width: 90, height: 14, borderRadius: BorderRadius.circular(4)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(20),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 70, height: 11, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 14),
                _buildContactSkeleton(),
                const SizedBox(height: 12),
                _buildContactSkeleton(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(20),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 90, height: 11, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 16),
                SkeletonLoader(width: double.infinity, height: 40, borderRadius: BorderRadius.circular(10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: context.theme.colors.mutedForeground),
      const SizedBox(width: 5),
      Text(label, style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground)),
    ]);
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: _c.accent),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground))),
      ]),
    );
  }

  Widget _buildInfoBanner(String message, {bool isError = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (isError ? _c.destructive : _c.accent).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (isError ? _c.destructive : _c.accent).withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.info_outline, size: 14, color: isError ? _c.destructive : _c.accent),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: context.theme.typography.xs.copyWith(color: isError ? _c.destructive : context.theme.colors.mutedForeground, height: 1.4))),
      ]),
    );
  }

  Widget _buildContactRow(Map<String, dynamic> contact) {
    final isTarget = contact['is_target_contact'] as bool? ?? false;
    final firstName = contact['first_name'] as String? ?? '';
    final lastName = contact['last_name'] as String? ?? '';
    final jobTitle = contact['job_title'] as String? ?? '';
    final initials = (firstName.isNotEmpty ? firstName[0] : '') + (lastName.isNotEmpty ? lastName[0] : '');

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(children: [
        AppAvatar(initials: initials.toUpperCase().isNotEmpty ? initials.toUpperCase() : '?', size: 36, done: isTarget),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$firstName $lastName'.trim(), style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w500, color: context.theme.colors.foreground)),
            if (jobTitle.isNotEmpty)
              Text(jobTitle, style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground)),
          ]),
        ),
        GestureDetector(
          onTap: () => _toggleTargetContact(contact),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isTarget ? _c.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isTarget ? _c.accent : context.theme.colors.border),
            ),
            child: Text(
              isTarget ? 'TARGETED' : 'ADD TARGET',
              style: context.theme.typography.xs.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2, color: isTarget ? _c.accent : context.theme.colors.mutedForeground),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildContactSkeleton() {
    return Row(children: [
      SkeletonLoader(width: 36, height: 36, borderRadius: BorderRadius.circular(999)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SkeletonLoader(width: double.infinity, height: 14, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 6),
          SkeletonLoader(width: 120, height: 12, borderRadius: BorderRadius.circular(4)),
        ]),
      ),
      const SizedBox(width: 10),
      SkeletonLoader(width: 60, height: 28, borderRadius: BorderRadius.circular(8)),
    ]);
  }
}
