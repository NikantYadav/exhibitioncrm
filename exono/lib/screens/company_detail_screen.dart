import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_section_label.dart';
import '../widgets/skeleton_loader.dart';

class CompanyDetailScreen extends StatefulWidget {
  final String companyId;
  const CompanyDetailScreen({super.key, required this.companyId});

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  Map<String, dynamic>? _company;
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;
  bool _isLoadingContacts = true;
  String? _error;

  // Enrichment
  bool _isEnriching = false;
  String? _enrichError;

  // Talking points (briefing)
  bool _isGenerating = false;
  String? _briefingError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final company = await ApiService.getCompany(widget.companyId);
      if (!mounted) return;
      setState(() { _company = company; _isLoading = false; });
      _loadContacts();
      _autoEnrich(company);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await ApiService.getCompanyContacts(widget.companyId);
      if (mounted) setState(() { _contacts = contacts; _isLoadingContacts = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingContacts = false);
    }
  }

  // Runs on first open if not yet enriched, or if previous attempt failed.
  Future<void> _autoEnrich(Map<String, dynamic> company) async {
    final enrichedAt = company['enriched_at'] as String?;
    final failed = company['enrichment_failed'] as bool? ?? false;
    if (enrichedAt != null && !failed) return; // already enriched successfully

    setState(() { _isEnriching = true; _enrichError = null; });
    try {
      final updated = await ApiService.enrichCompany(widget.companyId);
      if (mounted) setState(() { _company = updated; _isEnriching = false; });
    } catch (e) {
      if (mounted) setState(() {
        _isEnriching = false;
        _enrichError = 'Could not load company details. Will retry next visit.';
      });
    }
  }

  Future<void> _generateBriefing() async {
    setState(() { _isGenerating = true; _briefingError = null; });
    try {
      final points = await ApiService.generateCompanyBriefing(widget.companyId);
      if (mounted) setState(() {
        _company = {...?_company, 'talking_points': points};
        _isGenerating = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _isGenerating = false;
        _briefingError = 'Could not generate talking points. Please try again.';
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _error != null
                      ? _buildErrorState()
                      : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _c.background,
        border: Border(bottom: BorderSide(color: _c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/contacts'),
            icon: Icon(Icons.arrow_back_rounded, color: _c.accent, size: 22),
            splashRadius: 20,
            tooltip: 'Back',
          ),
          Expanded(
            child: Text(
              _company?['name'] as String? ?? 'Company',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _c.textPrimary, letterSpacing: -0.3),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if ((_company?['website'] as String?)?.isNotEmpty == true)
            IconButton(
              onPressed: () => _launchUrl(_company!['website'] as String),
              icon: Icon(Icons.open_in_browser_rounded, color: _c.accent, size: 20),
              splashRadius: 20,
              tooltip: 'Open website',
            ),
        ],
      ),
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
                Container(height: 1, color: _c.border.withValues(alpha: 0.4)),
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
          _skeletonCard(
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 80, height: 11, borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: 14),
                _skeletonInfoRow(),
                _skeletonInfoRow(),
                const SizedBox(height: 4),
                Container(height: 1, color: _c.border.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: _c.destructive, size: 40),
            const SizedBox(height: 12),
            Text('Could not load company', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 6),
            Text(_error ?? '', style: TextStyle(color: _c.textMuted, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _load,
              style: OutlinedButton.styleFrom(side: BorderSide(color: _c.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
              child: Text('RETRY', style: TextStyle(color: _c.accent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main body ─────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    final co = _company!;
    final name           = co['name']              as String? ?? '';
    final industry       = co['industry']          as String? ?? '';
    final location       = co['location']          as String? ?? '';
    final website        = co['website']           as String? ?? '';
    final size           = co['company_size']      as String? ?? '';
    final desc           = co['description']       as String? ?? '';
    final products       = co['products_services'] as String? ?? '';
    final headquarters   = co['headquarters']      as String? ?? '';
    final employeeCount  = co['employee_count']    as String? ?? '';
    final foundedYear    = co['founded_year']      as String? ?? '';
    final linkedinUrl    = co['linkedin_url']      as String? ?? '';
    final ticker         = co['ticker_symbol']     as String? ?? '';
    final talkingPoints  = (co['talking_points'] as List?)?.cast<String>() ?? [];

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
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _c.accentSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _c.border),
                      ),
                      child: Text(
                        name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase(),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _c.accent, letterSpacing: -0.3),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: _c.textPrimary)),
                          if (industry.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(industry, style: TextStyle(fontSize: 13, color: _c.textMuted)),
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
                  Container(height: 1, color: _c.border.withValues(alpha: 0.5)),
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
                  Container(height: 1, color: _c.border.withValues(alpha: 0.5)),
                  const SizedBox(height: 14),
                  Text(desc, style: TextStyle(fontSize: 13, color: _c.textSecondary, height: 1.55)),
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
                    if (location.isNotEmpty || website.isNotEmpty || linkedinUrl.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(height: 1, color: _c.border.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                    ],
                    AppSectionLabel('Products & Services'),
                    const SizedBox(height: 8),
                    Text(products, style: TextStyle(fontSize: 13, color: _c.textSecondary, height: 1.5)),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 16),

          // ── Contacts card ──────────────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(20),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: AppSectionLabel('Contacts')),
                    if (!_isLoadingContacts && _contacts.isNotEmpty)
                      Text('${_contacts.length} TOTAL',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: _c.accent)),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoadingContacts)
                  Column(children: [_contactSkeleton(), const SizedBox(height: 12), _contactSkeleton()])
                else if (_contacts.isEmpty)
                  Text('No contacts found for this company.', style: TextStyle(fontSize: 14, color: _c.textMuted))
                else
                  ..._contacts.map(_buildContactRow),
              ],
            ),
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
                      _isGenerating ? 'GENERATING...' : (talkingPoints.isEmpty ? 'GENERATE AI BRIEFING' : 'REGENERATE'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.6),
                    ),
                  ),
                ),

                // Error
                if (_briefingError != null) ...[
                  const SizedBox(height: 12),
                  _buildBriefingError(),
                ],

                // Talking Points section
                if (talkingPoints.isNotEmpty && !_isGenerating) ...[
                  const SizedBox(height: 20),
                  Container(height: 1, color: _c.border.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
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
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _c.accent)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(e.value,
                              style: TextStyle(fontSize: 13, color: _c.textSecondary, height: 1.5)),
                        ),
                      ],
                    ),
                  )),
                ] else if (!_isGenerating && talkingPoints.isEmpty) ...[
                  const SizedBox(height: 14),
                  Text('Generate an AI briefing to get talking points for your next meeting.',
                      style: TextStyle(fontSize: 13, color: _c.textMuted)),
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
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: _c.accent),
        ),
        const SizedBox(width: 8),
        Text('Loading company details…', style: TextStyle(fontSize: 12, color: _c.textMuted, fontStyle: FontStyle.italic)),
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
          Expanded(child: Text(_enrichError!, style: TextStyle(fontSize: 12, color: _c.destructive, height: 1.4))),
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
          Expanded(child: Text(_briefingError!, style: TextStyle(fontSize: 12, color: _c.destructive, height: 1.4))),
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
        Text(label, style: TextStyle(fontSize: 12, color: _c.textSecondary)),
      ],
    );
  }

  Widget _infoRow(IconData icon, String value, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Icon(icon, size: 17, color: _c.accent),
            const SizedBox(width: 12),
            Expanded(child: Text(value, style: TextStyle(fontSize: 14, color: _c.textPrimary), overflow: TextOverflow.ellipsis)),
            if (onTap != null) Icon(Icons.chevron_right, size: 16, color: _c.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(Map<String, dynamic> contact) {
    final firstName = contact['first_name'] as String? ?? '';
    final lastName  = contact['last_name']  as String? ?? '';
    final jobTitle  = contact['job_title']  as String? ?? '';
    final contactId = contact['id']         as String? ?? '';
    final initials  = (firstName.isNotEmpty ? firstName[0] : '') + (lastName.isNotEmpty ? lastName[0] : '');

    return InkWell(
      onTap: contactId.isNotEmpty ? () => context.push('/contacts/$contactId') : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _c.accentSoft, borderRadius: BorderRadius.circular(999), border: Border.all(color: _c.border)),
              child: Text(initials.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _c.accent)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$firstName $lastName'.trim(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _c.textPrimary)),
                  if (jobTitle.isNotEmpty) Text(jobTitle, style: TextStyle(fontSize: 12, color: _c.textMuted)),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: accent ? _c.accent.withValues(alpha: 0.3) : _c.border),
      ),
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
