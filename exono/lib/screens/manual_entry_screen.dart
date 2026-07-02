import 'package:flutter/material.dart';
import '../utils/safe_area_insets.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import '../providers/live_event_provider.dart';

import '../config/app_theme.dart';
import '../models/event.dart';
import '../providers/offline_provider.dart';
import '../providers/sync_provider.dart';
import '../services/api_service.dart';
import '../services/offline/write_gateway.dart';
import '../widgets/additional_details_editor.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_checkbox.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_header.dart';
import '../widgets/app_input.dart';
import '../widgets/app_section_label.dart';
import '../utils/screen_logger.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class ManualEntryResult {
  final String savedName;
  const ManualEntryResult(this.savedName);
}

class _ManualEntryScreenState extends State<ManualEntryScreen> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  static bool _isValidEmail(String email) {
    final atIdx = email.indexOf('@');
    if (atIdx < 1) return false;
    return email.indexOf('.', atIdx) > atIdx + 1;
  }

  static bool _isValidUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

  // ── Controllers ────────────────────────────────────────────
  final _fnCtrl      = TextEditingController();
  final _lnCtrl      = TextEditingController();
  final _coCtrl      = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _titleCtrl   = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _notesCtrl   = TextEditingController();

  // ── Focus (drives the active-row accent tint per field) ─────
  final _fnFocus      = FocusNode();
  final _lnFocus      = FocusNode();
  final _coFocus      = FocusNode();
  final _titleFocus   = FocusNode();
  final _emailFocus   = FocusNode();
  final _phoneFocus   = FocusNode();
  final _linkedinFocus = FocusNode();

  // ── State ──────────────────────────────────────────────────
  List<Event> _events    = [];
  String?     _eventId;
  bool        _isPriority = false;
  final _meetContextCtrl = TextEditingController();
  final _detailsController = AdditionalDetailsController();
  bool        _isSaving  = false;
  bool        _saved     = false;
  // Dedup (online only — offline dedup goes through notifications).
  bool        _showDedup = false;
  List<Map<String, dynamic>> _dupes = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
    for (final node in [_fnFocus, _lnFocus, _coFocus, _titleFocus, _emailFocus, _phoneFocus, _linkedinFocus]) {
      node.addListener(_onFocusChange);
    }
  }

  void _onFocusChange() => setState(() {});

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
    _fnFocus.dispose();
    _lnFocus.dispose();
    _coFocus.dispose();
    _titleFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _linkedinFocus.dispose();
    _meetContextCtrl.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    final rows = await context.read<SyncProvider>().events.watchAll().first;
    if (!mounted) return;
    final events = rows.map(Event.fromDrift).toList();
    // When an event is live, auto-select it for manual entry — universal rule
    // across capture/contact actions.
    final liveEvent = context.read<LiveEventProvider>().liveEvent;
    setState(() {
      _events = events;
      if (liveEvent != null && events.any((e) => e.id == liveEvent.id)) {
        _eventId = liveEvent.id;
      }
    });
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16, 20, 16,
                    bottomScrollInset(context, margin: 110) +
                        MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAvatarRow(),
                      const SizedBox(height: 20),
                      _buildPersonalWorkGrid(),
                      const SizedBox(height: 24),
                      AppSectionLabel('Contact Info'),
                      const SizedBox(height: 10),
                      _buildContactInfoCard(),
                      const SizedBox(height: 24),
                      AdditionalDetailsEditor(controller: _detailsController),
                      const SizedBox(height: 24),
                      AppSectionLabel('Event'),
                      const SizedBox(height: 10),
                      _buildEventSelector(),
                      if (_eventId == null) ...[
                        const SizedBox(height: 10),
                        AppInput(
                          controller: _meetContextCtrl,
                          label: 'How did you meet? (optional)',
                        ),
                      ],
                      const SizedBox(height: 14),
                      AppCheckbox(
                        value: _isPriority,
                        label: 'Mark as Priority',
                        description: 'Surface this contact at the top of your follow-ups.',
                        onChanged: (v) => setState(() => _isPriority = v),
                      ),
                      const SizedBox(height: 24),
                      AppSectionLabel('Notes'),
                      const SizedBox(height: 10),
                      AppInput(
                        controller: _notesCtrl,
                        maxLines: 5,
                        hint: 'Key takeaways, context, or follow-up items…',
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
    return ColoredBox(
      color: context.theme.colors.background,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.theme.colors.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              AppHeaderActionButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'NEW CONTACT',
                    style: context.theme.typography.sm.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                      color: context.theme.colors.foreground,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Enter details manually',
                    style: context.theme.typography.xs.copyWith(
                      color: context.theme.colors.mutedForeground),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: _c.accent, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Avatar (auto-derived initials) ───────────────────────────

  Widget _buildAvatarRow() {
    final fn = _fnCtrl.text;
    final ln = _lnCtrl.text;
    final initials = (fn.isNotEmpty ? fn[0] : '') + (ln.isNotEmpty ? ln[0] : '');
    return Center(
      child: AppAvatar(initials: initials.isEmpty ? '?' : initials.toUpperCase(), size: 64),
    );
  }

  // ── Personal & work grid ────────────────────────────────────

  Widget _buildPersonalWorkGrid() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionLabel('First Name'),
              const SizedBox(height: 6),
              AppInput(
                controller: _fnCtrl,
                focusNode: _fnFocus,
                hint: 'Jane',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              AppSectionLabel('Company'),
              const SizedBox(height: 6),
              AppInput(controller: _coCtrl, focusNode: _coFocus, hint: 'Acme Corp'),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionLabel('Last Name'),
              const SizedBox(height: 6),
              AppInput(
                controller: _lnCtrl,
                focusNode: _lnFocus,
                hint: 'Doe',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              AppSectionLabel('Title'),
              const SizedBox(height: 6),
              AppInput(controller: _titleCtrl, focusNode: _titleFocus, hint: 'Director'),
            ],
          ),
        ),
      ],
    );
  }

  // ── Contact info card ────────────────────────────────────────

  Widget _buildContactInfoCard() {
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionLabel('Email'),
          const SizedBox(height: 6),
          AppInput(
            controller: _emailCtrl,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress,
            hint: 'jane.doe@example.com',
          ),
          const SizedBox(height: 16),
          AppSectionLabel('Phone'),
          const SizedBox(height: 6),
          AppInput(
            controller: _phoneCtrl,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            hint: '+1 (555) 000-0000',
          ),
          const SizedBox(height: 16),
          AppSectionLabel('LinkedIn'),
          const SizedBox(height: 6),
          AppInput(
            controller: _linkedinCtrl,
            focusNode: _linkedinFocus,
            keyboardType: TextInputType.url,
            hint: 'linkedin.com/in/...',
          ),
        ],
      ),
    );
  }

  Widget _buildEventSelector() {
    final selectedName = _eventId == null
        ? 'No event'
        : _events.firstWhere((e) => e.id == _eventId, orElse: () => _events.first).name;
    return GestureDetector(
      onTap: _showEventPickerSheet,
      child: Container(
        decoration: BoxDecoration(
          color: _c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.theme.colors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.event_outlined, size: 15, color: _c.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.theme.typography.sm.copyWith(
                  color: _eventId == null
                      ? context.theme.colors.mutedForeground
                      : context.theme.colors.foreground,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: _c.accent, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _showEventPickerSheet() async {
    await showAppSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _eventOptionTile(
                          label: 'No event',
                          selected: _eventId == null,
                          onTap: () {
                            setState(() => _eventId = null);
                            Navigator.of(ctx).pop();
                          },
                        ),
                        for (final e in _events)
                          _eventOptionTile(
                            label: e.name,
                            selected: _eventId == e.id,
                            onTap: () {
                              setState(() => _eventId = e.id);
                              Navigator.of(ctx).pop();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _eventOptionTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AppCard(
          radius: 14,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check_rounded, color: _c.accent, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── Save button ────────────────────────────────────────────

  Widget _buildSaveButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 14, 16,
        bottomBarInset(context, extra: 14),
      ),
      decoration: BoxDecoration(
        color: context.theme.colors.background,
        border: Border(top: BorderSide(color: context.theme.colors.border)),
      ),
      child: AppButton(
        label: _saved ? 'CONTACT SAVED' : 'SAVE CONTACT',
        fullWidth: true,
        size: ButtonSize.lg,
        variant: ButtonVariant.primary,
        isLoading: _isSaving,
        onPressed: (_isSaving || _saved) ? null : _save,
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────

  Future<void> _save() async {
    final fn = _fnCtrl.text.trim();
    final ln = _lnCtrl.text.trim();
    final name = '$fn $ln'.trim();
    if (name.isEmpty) {
      showAppToast(context, 'Enter at least a name');
      return;
    }
    if (fn.length > 100) {
      showAppToast(context, 'First name must be 100 characters or fewer');
      return;
    }
    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty && !_isValidEmail(email)) {
      showAppToast(context, 'Please enter a valid email address');
      return;
    }
    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty && phone.length > 30) {
      showAppToast(context, 'Phone number must be 30 characters or fewer');
      return;
    }
    final linkedin = _linkedinCtrl.text.trim();
    if (linkedin.isNotEmpty && !_isValidUrl(linkedin)) {
      showAppToast(context, 'LinkedIn URL must start with http:// or https://');
      return;
    }
    setState(() => _isSaving = true);
    try {
      // Skip duplicate check when offline — go straight to queue.
      if (context.read<OfflineProvider>().isOnline) {
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
        } catch (_) {
          // Duplicate check failed — proceed to save anyway.
        }
      }
      if (!mounted) return;
      await _doSave();
    } on UnauthorizedException { rethrow; } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showAppToast(context, 'Failed to save contact');
    }
  }

  Future<void> _doSave() async {
    try {
      final fn = _fnCtrl.text.trim();
      final ln = _lnCtrl.text.trim();
      final result = await WriteGateway().createCapture(
        captureType: 'manual',
        rawText: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        eventId: _eventId,
        meetingContext: _eventId == null ? _meetContextCtrl.text.trim() : null,
        extractedData: {
          'first_name':   fn,
          'last_name':    ln,
          'name':         '$fn $ln'.trim(),
          'company':      _coCtrl.text.trim(),
          'email':        _emailCtrl.text.trim(),
          'phone':        _phoneCtrl.text.trim(),
          'job_title':    _titleCtrl.text.trim(),
          'linkedin_url': _linkedinCtrl.text.trim(),
          'is_priority':  _isPriority,
          if (_detailsController.toMap().isNotEmpty)
            'scanned_details': _detailsController.toMap(),
        },
      );
      if (!mounted) return;

      if (result.savedOffline) {
        context.read<OfflineProvider>().refreshPendingCount();
        showAppToast(context, 'Saved offline - will sync when online');
        Navigator.of(context).pop(ManualEntryResult('$fn $ln'.trim()));
        return;
      }

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
    } on UnauthorizedException { rethrow; } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saved    = false;
      });
      showAppToast(context, 'Failed to save contact');
    }
  }

  Future<void> _resolveDuplicateAndSave({required bool merge}) async {
    setState(() {
      _showDedup = false;
      _isSaving  = true;
    });
    await _doSave();
  }

  // ── Dedup sheet (online flow — offline dedup is handled via notifications) ──

  Widget _buildDedupSheet() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.6)),
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: ColoredBox(
              color: context.theme.colors.background,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: context.theme.colors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: _c.accent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Possible duplicate detected',
                                  style: context.theme.typography.lg.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: context.theme.colors.foreground,
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_dupes.first['first_name'] ?? ''} ${_dupes.first['last_name'] ?? ''}'.trim(),
                                    style: context.theme.typography.sm.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: context.theme.colors.foreground,
                                    ),
                                  ),
                                  if (_dupes.first['email'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _dupes.first['email'] as String,
                                      style: context.theme.typography.sm.copyWith(
                                        color: context.theme.colors.mutedForeground,
                                      ),
                                    ),
                                  ],
                                  if (_dupes.first['company'] != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      (_dupes.first['company'] as Map?)?['name'] ?? '',
                                      style: context.theme.typography.xs.copyWith(
                                        color: context.theme.colors.mutedForeground,
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
                      20, 0, 20, bottomBarInset(context, extra: 16),
                    ),
                    child: Column(
                      children: [
                        _dedupAction(
                          'MERGE WITH EXISTING',
                          primary: true,
                          onTap: () => _resolveDuplicateAndSave(merge: true),
                        ),
                        const SizedBox(height: 10),
                        _dedupAction(
                          'CREATE AS NEW CONTACT',
                          onTap: () => _resolveDuplicateAndSave(merge: false),
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'CANCEL',
                          variant: ButtonVariant.ghost,
                          fullWidth: true,
                          onPressed: () => setState(() => _showDedup = false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
    return AppButton(
      label: label,
      fullWidth: true,
      variant: primary ? ButtonVariant.primary : ButtonVariant.secondary,
      onPressed: onTap,
    );
  }

}
