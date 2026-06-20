import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme.dart';
import '../db/app_database.dart';
import '../providers/sync_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_header.dart';
import '../widgets/app_section_label.dart';
import '../widgets/skeleton_loader.dart';
import '../utils/screen_logger.dart';

class CompanyDetailScreen extends StatefulWidget {
  final String companyId;
  const CompanyDetailScreen({super.key, required this.companyId});

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  // Enrichment
  bool _isEnriching = false;
  String? _enrichError;
  bool _autoEnrichTried = false;

  // Talking points (briefing)
  bool _isGenerating = false;
  String? _briefingError;
  List<String> _talkingPointsOverride = const [];

  late final SyncProvider _sync;

  @override
  void initState() {
    super.initState();
    _sync = context.read<SyncProvider>();
  }

  // Runs on first open if not yet enriched, or if previous attempt failed.
  Future<void> _autoEnrich(CompaniesTableData? company) async {
    if (_autoEnrichTried || company == null) return;
    if (company.enrichedAt != null && !company.enrichmentFailed) return; // already enriched successfully
    _autoEnrichTried = true;

    setState(() { _isEnriching = true; _enrichError = null; });
    try {
      await ApiService.enrichCompany(widget.companyId);
      await _sync.companies.catchUp();
      if (mounted) setState(() => _isEnriching = false);
    } on UnauthorizedException { rethrow; } catch (e) {
      if (mounted) {
        setState(() {
          _isEnriching = false;
          _enrichError = 'Could not load company details. Will retry next visit.';
        });
      }
    }
  }

  Future<void> _generateBriefing() async {
    setState(() { _isGenerating = true; _briefingError = null; });
    try {
      final points = await ApiService.generateCompanyBriefing(widget.companyId);
      await _sync.companies.catchUp();
      if (mounted) {
        setState(() {
          _talkingPointsOverride = List<String>.from(points);
          _isGenerating = false;
        });
      }
    } on UnauthorizedException { rethrow; } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _briefingError = 'Could not generate talking points. Please try again.';
        });
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CompaniesTableData?>(
      stream: _sync.companies.watchById(widget.companyId),
      builder: (context, snapshot) {
        final company = snapshot.data;
        if (company != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _autoEnrich(company));
        }
        return ColoredBox(
          color: context.theme.colors.background,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(company),
                Expanded(
                  child: !snapshot.hasData
                      ? _buildLoadingState()
                      : company == null
                          ? _buildNotFoundState()
                          : _buildBody(company),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader(CompaniesTableData? company) {
    return AppHeader(
      title: company?.name ?? 'Company',
      onBack: () => context.canPop() ? context.pop() : context.go('/contacts'),
      showProfile: false,
      trailing: company?.website?.isNotEmpty == true
          ? AppButton(
              onPressed: () => _launchUrl(company!.website!),
              variant: ButtonVariant.ghost,
              size: ButtonSize.sm,
              child: Icon(Icons.open_in_browser_rounded, size: 20, color: _c.accent),
            )
          : null,
    );
  }

  // ── Loading skeleton ──────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      child: Column(
        children: [
          _skeletonCard(
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(width: 56, height: 56, borderRadius: BorderRadius.circular(14)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLoader(width: double.infinity, height: 20, borderRadius: BorderRadius.circular(5)),
                          const SizedBox(height: 8),
                          SkeletonLoader(width: 140, height: 13, borderRadius: BorderRadius.circular(4)),
                          const SizedBox(height: 10),
                          SkeletonLoader(width: 100, height: 22, borderRadius: BorderRadius.circular(4)),
                        ],
                      ),
                    ),
                  ],
                ),
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
          _skeletonCard(
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 80, height: 11, borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: 14),
                _skeletonInfoRow(),
                _skeletonInfoRow(),
                const SizedBox(height: 16),
                SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 6),
                SkeletonLoader(width: 220, height: 13, borderRadius: BorderRadius.circular(4)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _skeletonCard(
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 80, height: 11, borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: 14),
                _contactSkeleton(),
                const SizedBox(height: 12),
                _contactSkeleton(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _skeletonCard(
            radius: 20,
            accent: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonLoader(width: 16, height: 16, borderRadius: BorderRadius.circular(4)),
                    const SizedBox(width: 8),
                    SkeletonLoader(width: 100, height: 11, borderRadius: BorderRadius.circular(3)),
                  ],
                ),
                const SizedBox(height: 16),
                SkeletonLoader(width: double.infinity, height: 48, borderRadius: BorderRadius.circular(999)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: _c.destructive, size: 40),
            const SizedBox(height: 12),
            Text('Company not found', style: context.theme.typography.lg.copyWith(color: context.theme.colors.foreground, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── Main body ─────────────────────────────────────────────────────────────────

  Widget _buildBody(CompaniesTableData co) {
    final name           = co.name;
    final industry       = co.industry ?? '';
    final location       = co.location ?? '';
    final website        = co.website ?? '';
    final size           = co.companySize ?? '';
    final desc           = co.description ?? '';
    final products       = co.productsServices ?? '';
    final headquarters   = co.headquarters ?? '';
    final employeeCount  = co.employeeCount ?? '';
    final foundedYear    = co.foundedYear ?? '';
    final linkedinUrl    = co.linkedinUrl ?? '';
    final ticker         = co.tickerSymbol ?? '';
    final talkingPoints  = _talkingPointsOverride.isNotEmpty
        ? _talkingPointsOverride
        : (co.talkingPointsJson != null
            ? (jsonDecode(co.talkingPointsJson!) as List).cast<String>()
            : const <String>[]);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Hero card ──────────────────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(20),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppAvatar(
                      initials: name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase(),
                      size: 56,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: context.theme.typography.xl.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4, color: context.theme.colors.foreground)),
                          if (industry.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(industry, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
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

                // Enrichment stat row
                if (_isEnriching) ...[
                  const SizedBox(height: 14),
                  _buildEnrichingIndicator(),
                ] else if (_enrichError != null) ...[
                  const SizedBox(height: 12),
                  _buildEnrichError(),
                ] else if (headquarters.isNotEmpty || employeeCount.isNotEmpty || foundedYear.isNotEmpty) ...[
                  const SizedBox(height: 16),
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
                  Text(desc, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground, height: 1.55)),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Details card ───────────────────────────────────────────────────
          if (location.isNotEmpty || website.isNotEmpty || linkedinUrl.isNotEmpty || products.isNotEmpty)
            AppCard(
              padding: const EdgeInsets.all(20),
              radius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSectionLabel('Details'),
                  const SizedBox(height: 14),
                  if (location.isNotEmpty) _infoRow(Icons.location_on_outlined, location, null),
                  if (website.isNotEmpty) _infoRow(Icons.language_rounded, website, () => _launchUrl(website)),
                  if (linkedinUrl.isNotEmpty) _infoRow(Icons.link_rounded, 'LinkedIn', () => _launchUrl(linkedinUrl)),
                  if (products.isNotEmpty) ...[
                    if (location.isNotEmpty || website.isNotEmpty || linkedinUrl.isNotEmpty)
                      const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 17, color: _c.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(products,
                              style: context.theme.typography.sm.copyWith(color: context.theme.colors.foreground, height: 1.5)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 16),

          // ── Contacts card ──────────────────────────────────────────────────
          StreamBuilder<List<ContactsTableData>>(
            stream: _sync.contacts.watchByCompany(widget.companyId),
            builder: (context, snapshot) {
              final contacts = snapshot.data;
              return AppCard(
                padding: const EdgeInsets.all(20),
                radius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: AppSectionLabel('Contacts')),
                        if (contacts != null && contacts.isNotEmpty)
                          Text('${contacts.length} TOTAL',
                              style: context.theme.typography.xs.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.2, color: _c.accent)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (contacts == null)
                      Column(children: [_contactSkeleton(), const SizedBox(height: 12), _contactSkeleton()])
                    else if (contacts.isEmpty)
                      Text('No contacts found for this company.', style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground))
                    else
                      ...contacts.map(_buildContactRow),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // ── AI Research card ───────────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(20),
            radius: 20,
            borderColor: _c.accent.withValues(alpha: 0.3),
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

                // Generate / regenerate button
                AppButton(
                  label: _isGenerating ? 'GENERATING...' : (talkingPoints.isEmpty ? 'GENERATE AI BRIEFING' : 'REGENERATE'),
                  onPressed: _isGenerating ? null : _generateBriefing,
                  variant: ButtonVariant.primary,
                  fullWidth: true,
                  isLoading: _isGenerating,
                ),

                // Error
                if (_briefingError != null) ...[
                  const SizedBox(height: 12),
                  _buildBriefingError(),
                ],

                // Talking Points section
                if (talkingPoints.isNotEmpty && !_isGenerating) ...[
                  const SizedBox(height: 20),
                  AppSectionLabel('Talking Points', color: _c.accent),
                  const SizedBox(height: 14),
                  ...talkingPoints.asMap().entries.map((e) => Padding(
                    padding: EdgeInsets.only(bottom: e.key < talkingPoints.length - 1 ? 14 : 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(top: 1),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: _c.accentSoft, borderRadius: BorderRadius.circular(6)),
                          child: Text('${e.key + 1}',
                              style: context.theme.typography.xs.copyWith(fontWeight: FontWeight.w700, color: _c.accent)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(e.value,
                              style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground, height: 1.5)),
                        ),
                      ],
                    ),
                  )),
                ] else if (!_isGenerating && talkingPoints.isEmpty) ...[
                  const SizedBox(height: 14),
                  Text('Generate an AI briefing to get talking points for your next meeting.',
                      style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────────

  Widget _buildEnrichingIndicator() {
    return Row(
      children: [
        const SizedBox(
          width: 12,
          height: 12,
          child: FCircularProgress(),
        ),
        const SizedBox(width: 8),
        Text('Loading company details…', style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground, fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildEnrichError() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _c.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _c.destructive.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: _c.destructive),
          const SizedBox(width: 8),
          Expanded(child: Text(_enrichError!, style: context.theme.typography.xs.copyWith(color: _c.destructive, height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildBriefingError() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _c.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _c.destructive.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 14, color: _c.destructive),
          const SizedBox(width: 8),
          Expanded(child: Text(_briefingError!, style: context.theme.typography.xs.copyWith(color: _c.destructive, height: 1.4))),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _c.accent),
        const SizedBox(width: 5),
        Text(label, style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground)),
      ],
    );
  }

  Widget _infoRow(IconData icon, String value, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 17, color: _c.accent),
            const SizedBox(width: 12),
            Expanded(child: Text(value, style: context.theme.typography.sm.copyWith(color: context.theme.colors.foreground), overflow: TextOverflow.ellipsis)),
            if (onTap != null) Icon(Icons.chevron_right, size: 16, color: _c.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(ContactsTableData contact) {
    final firstName = contact.firstName;
    final lastName  = contact.lastName ?? '';
    final jobTitle  = contact.jobTitle ?? '';
    final contactId = contact.id;
    final initials  = (firstName.isNotEmpty ? firstName[0] : '') + (lastName.isNotEmpty ? lastName[0] : '');

    return GestureDetector(
      onTap: contactId.isNotEmpty ? () => context.push('/contacts/$contactId') : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            AppAvatar(initials: initials, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$firstName $lastName'.trim(), style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w600, color: context.theme.colors.foreground)),
                  if (jobTitle.isNotEmpty) Text(jobTitle, style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: _c.accent),
          ],
        ),
      ),
    );
  }

  // ── Skeleton helpers ──────────────────────────────────────────────────────────

  Widget _skeletonCard({required Widget child, double radius = 20, bool accent = false}) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: radius,
      borderColor: accent ? _c.accent.withValues(alpha: 0.3) : null,
      child: child,
    );
  }

  Widget _skeletonInfoRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SkeletonLoader(width: 17, height: 17, borderRadius: BorderRadius.circular(4)),
          const SizedBox(width: 12),
          SkeletonLoader(width: 160, height: 13, borderRadius: BorderRadius.circular(4)),
        ],
      ),
    );
  }

  Widget _contactSkeleton() {
    return Row(
      children: [
        SkeletonLoader(width: 38, height: 38, borderRadius: BorderRadius.circular(999)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLoader(width: double.infinity, height: 14, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 6),
              SkeletonLoader(width: 120, height: 12, borderRadius: BorderRadius.circular(4)),
            ],
          ),
        ),
      ],
    );
  }
}
