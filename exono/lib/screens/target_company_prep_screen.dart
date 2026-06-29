import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../utils/markdown_normalize.dart';
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
import '../models/chat_mention.dart';
import '../models/target_note.dart';
import '../widgets/exo_dock_bar.dart';

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
  bool _autoEnrichTried = false;

  bool _editingBooth = false;
  late TextEditingController _boothCtrl;
  final ScrollController _bodyScrollCtrl = ScrollController();
  bool _isReenriching = false;
  bool? _lowConfidence;

  // Stores the most recent target so the Exo "Add to notes" callback can
  // reference it even when it fires outside the StreamBuilder scope.
  TargetCompanyRow? _lastTarget;

  @override
  void initState() {
    super.initState();
    // Pushed full-screen into the shell's nested navigator, so the shell's
    // bottom nav + live bar would otherwise stay mounted underneath. Hide them
    // while this screen is open (restored in dispose). Defer one frame to avoid
    // mutating the notifier during build, and guard on `mounted` so a fast
    // push/pop can't strand a hide token after dispose has already shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) navBarHide(this);
    });
    _boothCtrl = TextEditingController();
    _sync = context.read<SyncProvider>();
    _targetsRepo = _sync.targetCompanies;
  }

  @override
  void dispose() {
    navBarShow(this);
    // Defer one frame: the screen pop animation keeps AppInput briefly mounted
    // after dispose() fires; synchronous disposal throws
    // `_dependents.isEmpty is not true`.
    final boothCtrl = _boothCtrl;
    WidgetsBinding.instance.addPostFrameCallback((_) => boothCtrl.dispose());
    _bodyScrollCtrl.dispose();
    super.dispose();
  }

  void _syncControllersWith(TargetCompanyRow target) {
    _lastTarget = target;
    if (!_editingBooth) _boothCtrl.text = target.target.boothLocation ?? '';
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

  List<TargetNote> _currentNotes(TargetCompanyRow target) =>
      TargetNote.parseList(target.target.notes);

  Future<bool> _addNote(TargetCompanyRow target, String body) async {
    final text = body.trim();
    if (text.isEmpty) { return false; }
    // Server-side atomic append (sends only this note's body) so a concurrent
    // add from the AI agent can't be clobbered by a stale full-array replace.
    try {
      await ApiService.addTargetNote(widget.event.id, widget.targetId, text);
      await _targetsRepo.catchUp();
      return true;
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) showAppToast(context, 'Failed to save note.');
      return false;
    }
  }

  Future<void> _deleteNote(TargetCompanyRow target, String noteId) async {
    // Server-side atomic remove by note id (same anti-clobber rationale).
    try {
      await ApiService.deleteTargetNote(widget.event.id, widget.targetId, noteId);
      await _targetsRepo.catchUp();
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) showAppToast(context, 'Failed to delete note.');
    }
  }

  Future<void> _editNote(TargetCompanyRow target, String noteId, String newBody) async {
    final text = newBody.trim();
    if (text.isEmpty) { return; }
    try {
      await ApiService.updateTargetNote(widget.event.id, widget.targetId, noteId, text);
      await _targetsRepo.catchUp();
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) showAppToast(context, 'Failed to update note.');
    }
  }

  Future<void> _openEditNoteSheet(TargetCompanyRow target, TargetNote note) async {
    final ctrl = TextEditingController(text: note.body);
    final result = await showAppSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: ctx.theme.colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Edit note', style: ctx.theme.typography.lg.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                AppInput(
                  controller: ctrl,
                  hint: 'Edit note... (markdown supported)',
                  minLines: 4,
                  maxLines: 12,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Save changes',
                  fullWidth: true,
                  variant: ButtonVariant.primary,
                  onPressed: () => Navigator.of(ctx).pop(ctrl.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (result != null && result.trim().isNotEmpty && result.trim() != note.body.trim()) {
      await _editNote(target, note.id, result);
    }
  }

  Future<void> _openAddNoteSheet(TargetCompanyRow target) async {
    final ctrl = TextEditingController();
    final result = await showAppSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: ctx.theme.colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Add note', style: ctx.theme.typography.lg.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                AppInput(
                  controller: ctrl,
                  hint: 'Type a note... (markdown supported)',
                  minLines: 4,
                  maxLines: 12,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Save note',
                  fullWidth: true,
                  variant: ButtonVariant.primary,
                  onPressed: () => Navigator.of(ctx).pop(ctrl.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (result != null && result.trim().isNotEmpty) {
      await _addNote(target, result);
    }
  }

  Future<void> _addNoteFromExo(String text) async {
    final t = _lastTarget;
    if (t == null) { return; }
    final ok = await _addNote(t, text);
    if (mounted && ok) showAppToast(context, 'Added to notes.');
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
                  child: Stack(
                    children: [
                  SingleChildScrollView(
                controller: _bodyScrollCtrl,
                padding: EdgeInsets.fromLTRB(16, 20, 16, bottomScrollInset(context, margin: 88) + MediaQuery.of(context).viewInsets.bottom),
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Notes ─────────────────────────────────────────────────
                    _buildNotesCard(target),

                    const SizedBox(height: 16),

                    // ── Contacts ──────────────────────────────────────────────
                    _buildContactsPanel(companyId),

                    SizedBox(height: bottomScrollInset(context, margin: 88)),
                  ],
                ),
              ),
                  if (resolvedCompanyId != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ExoDockBar(
                        entity: ChatMention(
                          type: 'company',
                          id: resolvedCompanyId,
                          displayName: companyName,
                        ),
                        onAddSelectionToNotes: _addNoteFromExo,
                        initialMentions: [
                          ChatMention(
                            type: 'event',
                            id: widget.event.id,
                            displayName: widget.event.name,
                          ),
                        ],
                      ),
                    ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
      },
    );
  }

  Widget _buildNotesCard(TargetCompanyRow target) {
    final notes = _currentNotes(target).reversed.toList();
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: AppSectionLabel('Notes')),
              AppButton(
                variant: ButtonVariant.ghost,
                size: ButtonSize.sm,
                onPressed: () => _openAddNoteSheet(target),
                child: Icon(Icons.add_rounded, size: 20, color: _c.accent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (notes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No notes yet. Add one, or ask Exo about this company.',
                style: context.theme.typography.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                  height: 1.5,
                ),
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < notes.length; i++) ...[
                  if (i > 0) Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(height: 1, color: context.theme.colors.border),
                  ),
                  _NoteCard(
                    note: notes[i],
                    onEdit: () => _openEditNoteSheet(target, notes[i]),
                    onDelete: () => _deleteNote(target, notes[i].id),
                  ),
                ],
              ],
            ),
        ],
      ),
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

/// A single note entry: markdown body + timestamp + copy/edit/delete actions.
class _NoteCard extends StatelessWidget {
  final TargetNote note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoteCard({required this.note, required this.onEdit, required this.onDelete});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) { return 'just now'; }
    if (diff.inMinutes < 60) { return '${diff.inMinutes}m ago'; }
    if (diff.inHours < 24) { return '${diff.inHours}h ago'; }
    if (diff.inDays < 7) { return '${diff.inDays}d ago'; }
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    final theme = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownBody(
          data: normalizeMarkdownTables(note.body),
          extensionSet: md.ExtensionSet.gitHubFlavored,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: theme.typography.sm.copyWith(color: theme.colors.foreground, height: 1.55),
            h1: theme.typography.xl.copyWith(color: theme.colors.foreground, fontWeight: FontWeight.w700),
            h2: theme.typography.lg.copyWith(color: theme.colors.foreground, fontWeight: FontWeight.w700),
            h3: theme.typography.sm.copyWith(color: theme.colors.foreground, fontWeight: FontWeight.w700),
            strong: theme.typography.sm.copyWith(color: theme.colors.foreground, fontWeight: FontWeight.w700, height: 1.55),
            em: theme.typography.sm.copyWith(color: theme.colors.foreground, fontStyle: FontStyle.italic, height: 1.55),
            code: theme.typography.sm.copyWith(color: c.accent, fontFamily: 'monospace', backgroundColor: c.accentSoft.withValues(alpha: 0.5)),
            codeblockDecoration: BoxDecoration(
              color: c.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colors.border),
            ),
            tableHead: theme.typography.sm.copyWith(color: theme.colors.foreground, fontWeight: FontWeight.w700),
            tableBody: theme.typography.sm.copyWith(color: theme.colors.foreground, height: 1.5),
            tableBorder: TableBorder.all(color: theme.colors.border, width: 1),
            tableHeadAlign: TextAlign.left,
            tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            blockquote: theme.typography.sm.copyWith(color: theme.colors.mutedForeground, fontStyle: FontStyle.italic, height: 1.55),
            listBullet: theme.typography.sm.copyWith(color: theme.colors.foreground, height: 1.55),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              _timeAgo(note.createdAt),
              style: theme.typography.xs.copyWith(color: theme.colors.mutedForeground),
            ),
            const Spacer(),
            AppButton(
              variant: ButtonVariant.ghost,
              size: ButtonSize.sm,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: note.body));
                showAppToast(context, 'Copied');
              },
              child: Icon(Icons.copy_rounded, size: 15, color: theme.colors.mutedForeground),
            ),
            AppButton(
              variant: ButtonVariant.ghost,
              size: ButtonSize.sm,
              onPressed: onEdit,
              child: Icon(Icons.edit_outlined, size: 15, color: theme.colors.mutedForeground),
            ),
            AppButton(
              variant: ButtonVariant.ghost,
              size: ButtonSize.sm,
              onPressed: () => showAppConfirmDialog(
                context: context,
                title: 'Delete note',
                message: 'This note will be permanently deleted.',
                confirmLabel: 'Delete',
                destructive: true,
              ).then((confirmed) { if (confirmed == true) { onDelete(); } }),
              child: Icon(Icons.delete_outline_rounded, size: 15, color: AppTheme.colorsOf(context).destructive),
            ),
          ],
        ),
      ],
    );
  }
}
