import 'package:flutter/material.dart';
import '../utils/safe_area_insets.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../db/app_database.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../models/event.dart';
import '../providers/sync_provider.dart';
import '../repositories/contact_events_repository.dart';
import '../repositories/target_companies_repository.dart';
import '../services/api_service.dart';
import '../services/company_name_resolver.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_header.dart';
import '../widgets/app_section_label.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_sheet_content.dart';
import '../widgets/skeleton_loader.dart';
import '../utils/screen_logger.dart';
import 'app_shell.dart' show navBarHide, navBarShow;

class TargetCompanyPrepScreen extends StatefulWidget {
  final Event event;
  final String targetId;
  const TargetCompanyPrepScreen({super.key, required this.event, required this.targetId});
  @override
  State<TargetCompanyPrepScreen> createState() => _TargetCompanyPrepScreenState();
}

class _TargetCompanyPrepScreenState extends State<TargetCompanyPrepScreen> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  late final SyncProvider _sync;
  late final TargetCompaniesRepository _targetsRepo;

  bool _isEnriching = false;
  String? _enrichError;

  bool _isGenerating = false;
  String? _briefingError;
  List<String> _talkingPoints = [];
  bool _useNotesForBriefing = false;
  bool _autoEnrichTried = false;

  bool _editingBooth = false;
  bool _editingNotes = false;
  late TextEditingController _boothCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _briefingFocusCtrl;
  final FocusNode _briefingFocusNode = FocusNode();
  final GlobalKey _briefingFieldKey = GlobalKey();
  final ScrollController _bodyScrollCtrl = ScrollController();
  bool _isReenriching = false;
  bool? _lowConfidence;

  @override
  void initState() {
    super.initState();
    // Pushed full-screen into the shell's nested navigator, so the shell's
    // bottom nav + live bar would otherwise stay mounted underneath. Hide them
    // while this screen is open (restored in dispose).
    navBarHide();
    _boothCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _briefingFocusCtrl = TextEditingController();
    _briefingFocusNode.addListener(_onBriefingFocusChange);
    _sync = context.read<SyncProvider>();
    _targetsRepo = _sync.targetCompanies;
  }

  void _onBriefingFocusChange() {
    if (!_briefingFocusNode.hasFocus) return;
    // ensureVisible measures against the full viewport (which extends behind the
    // keyboard), so it under-scrolls. Compute the scroll manually: bring the
    // bottom of the keyed group above the keyboard with a small gap.
    // Wait past the keyboard slide-in so MediaQuery.viewInsets is settled.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || !_briefingFocusNode.hasFocus) return;
      final ctx = _briefingFieldKey.currentContext;
      if (ctx == null || !ctx.mounted || !_bodyScrollCtrl.hasClients) return;

      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) return;
      final groupTop = box.localToGlobal(Offset.zero).dy;
      final groupBottom = groupTop + box.size.height;

      final screenH = MediaQuery.sizeOf(context).height;
      final keyboardTop = screenH - MediaQuery.of(context).viewInsets.bottom;
      const gap = 16.0;

      final overflow = groupBottom - (keyboardTop - gap);
      if (overflow <= 0) return; // already fully visible

      final target = (_bodyScrollCtrl.offset + overflow)
          .clamp(0.0, _bodyScrollCtrl.position.maxScrollExtent);
      _bodyScrollCtrl.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    navBarShow();
    _boothCtrl.dispose();
    _notesCtrl.dispose();
    _briefingFocusCtrl.dispose();
    _briefingFocusNode.removeListener(_onBriefingFocusChange);
    _briefingFocusNode.dispose();
    _bodyScrollCtrl.dispose();
    super.dispose();
  }

  void _syncControllersWith(TargetCompanyRow target) {
    if (!_editingBooth) _boothCtrl.text = target.target.boothLocation ?? '';
    if (!_editingNotes) _notesCtrl.text = target.target.notes ?? '';
    _useNotesForBriefing = target.target.useNotesForBriefing;
    final raw = target.target.talkingPoints;
    if (raw != null && raw.trim().isNotEmpty && _talkingPoints.isEmpty) {
      _talkingPoints = raw.split('\n').where((s) => s.trim().isNotEmpty).toList();
    }
  }

  Future<void> _autoEnrich(CompaniesTableData? company) async {
    if (_autoEnrichTried || company == null) return;
    if (company.enrichedAt != null && !company.enrichmentFailed) return;
    _autoEnrichTried = true;

    setState(() { _isEnriching = true; _enrichError = null; });
    try {
      final result = await ApiService.enrichCompany(company.id);
      await _sync.companies.upsertOne(result);
      final enrichedName = result['name'] as String?;
      if (enrichedName != null && enrichedName.isNotEmpty) {
        CompanyNameResolver.update(company.id, enrichedName);
      }
      if (mounted) {
        setState(() {
          _isEnriching = false;
          final confidence = result['enrichment_confidence'] as String?;
          _lowConfidence = confidence == 'low';
        });
      }
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) { setState(() {
        _isEnriching = false;
        _enrichError = 'Could not load company details. Will retry next visit.';
      }); }
    }
  }

  Future<void> _showCorrectCompanySheet(CompaniesTableData company) async {
    final industryCtrl = TextEditingController(text: company.industry ?? '');
    final locationCtrl = TextEditingController(text: company.location ?? '');
    final websiteCtrl = TextEditingController(text: company.website ?? '');

    await showAppSheet(
      context: context,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          String? websiteError;
          bool isSubmitting = false;

          String? validateWebsite(String val) {
            if (val.isEmpty) return null;
            final uri = Uri.tryParse(val);
            return (uri == null || !uri.hasScheme || !uri.host.contains('.'))
                ? 'Enter a valid URL (e.g. https://samtac.ae)'
                : null;
          }

          return AppSheetContent(
            title: 'Correct Company Details',
            subtitle: 'Add industry, country, or website so the AI can find the right company.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppInput(
                  controller: industryCtrl,
                  labelText: 'Industry (optional)',
                  hintText: 'e.g. Boilers & Heating, Logistics',
                ),
                const SizedBox(height: 12),
                AppInput(
                  controller: locationCtrl,
                  labelText: 'Country / City (optional)',
                  hintText: 'e.g. UAE, Dubai',
                ),
                const SizedBox(height: 12),
                AppInput(
                  controller: websiteCtrl,
                  labelText: 'Website (optional)',
                  hintText: 'e.g. https://samtac.ae',
                  keyboardType: TextInputType.url,
                  error: websiteError,
                  onChanged: (_) => setSheetState(() { websiteError = validateWebsite(websiteCtrl.text.trim()); }),
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'SAVE & RE-RESEARCH',
                  fullWidth: true,
                  variant: ButtonVariant.primary,
                  isLoading: isSubmitting,
                  onPressed: () async {
                    final we = validateWebsite(websiteCtrl.text.trim());
                    if (we != null) { setSheetState(() => websiteError = we); return; }
                    setSheetState(() => isSubmitting = true);
                    final industry = industryCtrl.text.trim();
                    final location = locationCtrl.text.trim();
                    final website = websiteCtrl.text.trim();
                    try {
                      final patch = <String, dynamic>{
                        'industry': industry.isEmpty ? null : industry,
                        'location': location.isEmpty ? null : location,
                        'website': website.isEmpty ? null : website,
                      };
                      await ApiService.patchCompany(company.id, patch);
                      if (!sheetCtx.mounted) return;
                      Navigator.of(sheetCtx).pop();
                      if (!mounted) return;
                      setState(() { _isReenriching = true; _enrichError = null; });
                      final result = await ApiService.enrichCompany(company.id, force: true);
                      await _sync.companies.upsertOne(result);
                      final reenrichedName = result['name'] as String?;
                      if (reenrichedName != null && reenrichedName.isNotEmpty) {
                        CompanyNameResolver.update(company.id, reenrichedName);
                      }
                      if (mounted) {
                        setState(() {
                          _isReenriching = false;
                          final confidence = result['enrichment_confidence'] as String?;
                          _lowConfidence = confidence == 'low';
                        });
                      }
                    } on UnauthorizedException { rethrow; } catch (_) {
                      setSheetState(() => isSubmitting = false);
                      if (mounted) { setState(() { _isReenriching = false; _enrichError = 'Re-research failed. Please try again.'; }); }
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
    // Defer one frame: the sheet's exit animation is still running when the
    // await returns, so the FTextField (and its managed control) is briefly
    // still mounted and depends on these controllers. Synchronous disposal
    // throws `_dependents.isEmpty is not true`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      industryCtrl.dispose();
      locationCtrl.dispose();
      websiteCtrl.dispose();
    });
  }

  Future<void> _generateBriefing(String companyId, String? notes) async {
    setState(() { _isGenerating = true; _briefingError = null; _talkingPoints = []; });
    try {
      final focus = _briefingFocusCtrl.text.trim();
      final points = await ApiService.generateCompanyBriefing(
        companyId,
        notes: _useNotesForBriefing ? notes : null,
        focus: focus.isNotEmpty ? focus : null,
      );
      if (mounted) { setState(() { _talkingPoints = List<String>.from(points); _isGenerating = false; }); }
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) { setState(() {
        _isGenerating = false;
        _briefingError = 'Could not generate talking points. Please try again.';
      }); }
    }
  }

  Future<void> _saveBooth() async {
    final booth = _boothCtrl.text.trim();
    try {
      await ApiService.updateEventTarget(widget.event.id, widget.targetId, {'booth_location': booth.isEmpty ? null : booth});
      await _targetsRepo.catchUp();
      if (mounted) setState(() => _editingBooth = false);
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) showAppToast(context, 'Failed to save booth.');
    }
  }

  String get _briefingText => _talkingPoints
      .asMap()
      .entries
      .map((e) => '${e.key + 1}. ${e.value}')
      .join('\n');

  bool get _briefingInNotes =>
      _talkingPoints.isNotEmpty && _notesCtrl.text.contains(_briefingText);

  Future<void> _addBriefingToNotes(String companyId) async {
    final briefingText = _briefingText;
    final existing = _notesCtrl.text.trim();
    final merged = existing.isEmpty ? briefingText : '$existing\n\n$briefingText';
    _notesCtrl.text = merged;
    try {
      await ApiService.updateEventTarget(widget.event.id, widget.targetId, {'notes': merged});
      await _targetsRepo.catchUp();
      if (mounted) { setState(() {}); showAppToast(context, 'Briefing added to notes.'); }
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) showAppToast(context, 'Failed to save notes.');
    }
  }

  Future<void> _saveNotes(String companyId) async {
    final notes = _notesCtrl.text.trim();
    try {
      await ApiService.updateEventTarget(widget.event.id, widget.targetId, {'notes': notes.isEmpty ? null : notes});
      await _targetsRepo.catchUp();
      if (mounted) setState(() => _editingNotes = false);
      if (_useNotesForBriefing && notes.isNotEmpty) {
        await _generateBriefing(companyId, notes);
      }
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) showAppToast(context, 'Failed to save notes.');
    }
  }

  Future<void> _toggleTargetContact(String contactId, bool isTarget) async {
    try {
      if (isTarget) {
        await ApiService.removeContactFromEvent(widget.event.id, contactId);
      } else {
        await ApiService.addContactToEvent(widget.event.id, contactId);
      }
      await _sync.contactEvents.catchUp();
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) showAppToast(context, 'Failed to update target contact.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TargetCompanyRow>>(
      stream: _targetsRepo.watchByEventWithCompany(widget.event.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
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

        final target = snapshot.data!.where((t) => t.id == widget.targetId).firstOrNull;
        if (target == null) {
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
                  Expanded(
                    child: Center(
                      child: Text('Target not found.', style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        _syncControllersWith(target);
        final company = target.company;
        WidgetsBinding.instance.addPostFrameCallback((_) => _autoEnrich(company));

        final booth = target.target.boothLocation;
        final desc = company?.description ?? '';
        final products = company?.productsServices ?? '';
        final location = company?.location ?? '';
        final website = company?.website ?? '';
        final headquarters = company?.headquarters ?? '';
        final employeeCount = company?.employeeCount ?? '';
        final foundedYear = company?.foundedYear ?? '';
        final ticker = company?.tickerSymbol ?? '';
        final size = company?.companySize ?? '';
        final resolvedCompanyId = company?.id ?? target.target.companyId;
        final companyName = CompanyNameResolver.cached(resolvedCompanyId) ?? target.companyName;
        final industry = company?.industry ?? '';
        final companyId = company?.id ?? '';
        final initials = companyName.length >= 2
            ? companyName.substring(0, 2).toUpperCase()
            : companyName.toUpperCase();

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
                Expanded(
                  child: SingleChildScrollView(
                controller: _bodyScrollCtrl,
                padding: EdgeInsets.fromLTRB(16, 20, 16, bottomScrollInset(context) + MediaQuery.of(context).viewInsets.bottom),
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
                                    CompanyName(companyId: resolvedCompanyId, fallback: companyName, style: context.theme.typography.xl.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.15, color: context.theme.colors.foreground)),
                                    if (industry.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(industry, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
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

                          if (_isEnriching || _isReenriching) ...[
                            const SizedBox(height: 16),
                            Row(children: [
                              SkeletonLoader(width: 110, height: 13, borderRadius: BorderRadius.circular(4)),
                              const SizedBox(width: 16),
                              SkeletonLoader(width: 90, height: 13, borderRadius: BorderRadius.circular(4)),
                            ]),
                            const SizedBox(height: 12),
                            SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                            const SizedBox(height: 6),
                            SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                            const SizedBox(height: 6),
                            SkeletonLoader(width: 200, height: 13, borderRadius: BorderRadius.circular(4)),
                          ] else if (_enrichError != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoBanner(_enrichError!, isError: true),
                          ] else if (company != null && company.enrichedAt != null) ...[
                            const SizedBox(height: 14),
                            if (_lowConfidence == true) ...[
                              _buildInfoBanner('AI could not confirm this company — details may be wrong. Add more context to fix this.', isWarning: true),
                              const SizedBox(height: 10),
                            ],
                            GestureDetector(
                              onTap: () => _showCorrectCompanySheet(company),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _c.isDark ? Colors.white : _c.accent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.tune_rounded, size: 13, color: _c.isDark ? _c.accent : Colors.white),
                                    const SizedBox(width: 5),
                                    Text('Not the right company?', style: context.theme.typography.xs.copyWith(color: _c.isDark ? _c.accent : Colors.white, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          if ((headquarters.isNotEmpty || employeeCount.isNotEmpty) && !_isEnriching && _enrichError == null || desc.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            ..._dividedRows([
                              if ((headquarters.isNotEmpty || employeeCount.isNotEmpty) && !_isEnriching && _enrichError == null)
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 10,
                                  children: [
                                    if (headquarters.isNotEmpty) _statItem(Icons.location_on_outlined, headquarters),
                                    if (employeeCount.isNotEmpty) _statItem(Icons.people_outline_rounded, employeeCount),
                                  ],
                                ),
                              if (desc.isNotEmpty)
                                Text(desc, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground, height: 1.55)),
                            ]),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Products & Services card ────────────────────────────────
                    if (location.isNotEmpty || website.isNotEmpty || products.isNotEmpty)
                      AppCard(
                        padding: const EdgeInsets.all(20),
                        radius: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppSectionLabel('Products & Services'),
                            const SizedBox(height: 14),
                            ..._dividedRows([
                              if (location.isNotEmpty) Row(children: [
                                Icon(Icons.location_on_outlined, size: 16, color: _c.accent),
                                const SizedBox(width: 10),
                                Expanded(child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground))),
                              ]),
                              if (website.isNotEmpty) Row(children: [
                                Icon(Icons.language_rounded, size: 16, color: _c.accent),
                                const SizedBox(width: 10),
                                Expanded(child: Text(website, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground))),
                              ]),
                              if (products.isNotEmpty)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 16, color: _c.accent),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(products,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground, height: 1.55)),
                                    ),
                                  ],
                                ),
                            ]),
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
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.theme.typography.sm.copyWith(
                                          color: (booth != null && booth.isNotEmpty)
                                              ? context.theme.colors.foreground
                                              : context.theme.colors.mutedForeground,
                                        ),
                                      ),
                              ),
                              if (_editingBooth) ...[
                                const SizedBox(width: 8),
                                AppButton(label: 'Save', variant: ButtonVariant.secondary, size: ButtonSize.sm, onPressed: _saveBooth),
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
                                        (target.target.notes?.isNotEmpty ?? false)
                                            ? target.target.notes!
                                            : 'No notes yet',
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.theme.typography.sm.copyWith(
                                          color: (target.target.notes?.isNotEmpty ?? false)
                                              ? context.theme.colors.foreground
                                              : context.theme.colors.mutedForeground,
                                          height: 1.5,
                                        ),
                                      ),
                              ),
                              if (_editingNotes) ...[
                                const SizedBox(width: 8),
                                Column(children: [
                                  AppButton(label: 'Save', variant: ButtonVariant.secondary, size: ButtonSize.sm, onPressed: () => _saveNotes(companyId)),
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
                    _buildContactsPanel(companyId),

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
                          if (target.target.notes?.isNotEmpty ?? false) ...[
                            GestureDetector(
                              onTap: () async {
                                final newVal = !_useNotesForBriefing;
                                setState(() => _useNotesForBriefing = newVal);
                                try {
                                  await ApiService.updateEventTarget(widget.event.id, widget.targetId, {'use_notes_for_briefing': newVal});
                                  await _targetsRepo.catchUp();
                                } on UnauthorizedException { rethrow; } catch (_) {}
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
                                          color: context.theme.colors.background,
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
                          Column(
                            key: _briefingFieldKey,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppInput(
                                controller: _briefingFocusCtrl,
                                focusNode: _briefingFocusNode,
                                hint: 'Steer the AI, e.g. their recent funding, hiring plans, pricing',
                                maxLines: 2,
                                minLines: 1,
                                enabled: !_isGenerating,
                                textCapitalization: TextCapitalization.sentences,
                              ),
                              const SizedBox(height: 12),
                              AppButton(
                                label: _isGenerating ? 'GENERATING...' : (_talkingPoints.isEmpty ? 'GENERATE AI BRIEFING' : 'REGENERATE'),
                                fullWidth: true,
                                variant: ButtonVariant.primary,
                                isLoading: _isGenerating,
                                prefixIcon: _isGenerating ? null : const Icon(Icons.auto_awesome, size: 16),
                                onPressed: _isGenerating ? null : () => _generateBriefing(companyId, target.target.notes),
                              ),
                            ],
                          ),
                          if (_briefingError != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoBanner(_briefingError!, isError: true),
                          ],
                          if (_talkingPoints.isNotEmpty && !_isGenerating) ...[
                            const SizedBox(height: 24),
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
                            const SizedBox(height: 16),
                            AppButton(
                              label: _briefingInNotes ? 'ALREADY IN NOTES' : 'ADD TO NOTES',
                              fullWidth: true,
                              variant: ButtonVariant.secondary,
                              prefixIcon: Icon(
                                _briefingInNotes ? Icons.check_rounded : Icons.notes_rounded,
                                size: 16,
                              ),
                              onPressed: _briefingInNotes ? null : () => _addBriefingToNotes(companyId),
                            ),
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
      },
    );
  }

  Widget _buildContactsPanel(String companyId) {
    if (companyId.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionLabel('Contacts'),
            const SizedBox(height: 12),
            Text('No contacts found for this company.', style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
          ],
        ),
      );
    }
    return StreamBuilder<List<ContactsTableData>>(
      stream: _sync.contacts.watchByCompany(companyId),
      builder: (context, contactsSnapshot) {
        return StreamBuilder<List<TargetContactRow>>(
          stream: _sync.contactEvents.watchByEventWithContact(widget.event.id),
          builder: (context, targetContactsSnapshot) {
            final contacts = contactsSnapshot.data;
            final targetContactIds = (targetContactsSnapshot.data ?? const <TargetContactRow>[])
                .map((tc) => tc.contactId)
                .toSet();

            return AppCard(
              padding: const EdgeInsets.all(20),
              radius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: AppSectionLabel('Contacts')),
                    if (contacts != null && contacts.any((c) => targetContactIds.contains(c.id)))
                      AppChip.label('${contacts.where((c) => targetContactIds.contains(c.id)).length} TARGETED'),
                  ]),
                  const SizedBox(height: 12),
                  if (contacts == null)
                    Column(children: [
                      _buildContactSkeleton(),
                      const SizedBox(height: 12),
                      _buildContactSkeleton(),
                    ])
                  else if (contacts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('No contacts found for this company.', style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
                    )
                  else
                    ...contacts.map((c) => _buildContactRow(c, targetContactIds.contains(c.id))),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSkeletonLoader() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 20, 16, bottomScrollInset(context)),
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
                Row(children: [
                  SkeletonLoader(width: 110, height: 13, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(width: 20),
                  SkeletonLoader(width: 90, height: 13, borderRadius: BorderRadius.circular(4)),
                ]),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
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
      Icon(icon, size: 14, color: _c.accent),
      const SizedBox(width: 5),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground)),
    ]);
  }

  List<Widget> _dividedRows(List<Widget> rows) {
    return [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(height: 1, color: context.theme.colors.border.withValues(alpha: 0.18)),
        ),
        rows[i],
      ],
    ];
  }

  Widget _buildInfoBanner(String message, {bool isError = false, bool isWarning = false}) {
    final color = isError ? _c.destructive : isWarning ? const Color(0xFFB45309) : _c.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : isWarning ? Icons.warning_amber_rounded : Icons.info_outline, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: context.theme.typography.xs.copyWith(color: isError ? _c.destructive : context.theme.colors.mutedForeground, height: 1.4))),
      ]),
    );
  }

  Widget _buildContactRow(ContactsTableData contact, bool isTarget) {
    final firstName = contact.firstName;
    final lastName = contact.lastName ?? '';
    final jobTitle = contact.jobTitle ?? '';
    final initials = (firstName.isNotEmpty ? firstName[0] : '') + (lastName.isNotEmpty ? lastName[0] : '');

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(children: [
        AppAvatar(initials: initials.toUpperCase().isNotEmpty ? initials.toUpperCase() : '?', size: 36, done: isTarget),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$firstName $lastName'.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w500, color: context.theme.colors.foreground)),
            if (jobTitle.isNotEmpty)
              Text(jobTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground)),
          ]),
        ),
        AppButton(
          label: isTarget ? 'Targeted' : 'Add Target',
          variant: isTarget ? ButtonVariant.secondary : ButtonVariant.outline,
          size: ButtonSize.sm,
          onPressed: () => _toggleTargetContact(contact.id, isTarget),
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
