import 'dart:ui';

import 'package:flutter/material.dart';
import '../utils/safe_area_insets.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_input.dart';
import '../widgets/log_follow_up_sheet.dart';

import '../config/app_theme.dart';
import '../models/event.dart';
import '../providers/sync_provider.dart';
import '../repositories/contact_events_repository.dart';
import '../services/api_service.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_filter_row.dart';
import '../widgets/app_header.dart';
import '../widgets/app_section_label.dart';
import '../widgets/skeleton_loader.dart';
import '../utils/screen_logger.dart';
import 'app_shell.dart' show navBarHide, navBarShow;

// ---------------------------------------------------------------------------
// Public screen
// ---------------------------------------------------------------------------

class EventFollowUpsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  final Event? event;
  // Legacy compat — callers that only pass eventId still work
  final String? eventId;

  const EventFollowUpsScreen({
    super.key,
    this.onNavigateTab,
    this.event,
    this.eventId,
  });

  @override
  State<EventFollowUpsScreen> createState() => _EventFollowUpsScreenState();
}

// ---------------------------------------------------------------------------
// Enums / constants
// ---------------------------------------------------------------------------

// No draft tone enum — tones removed

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class _EventFollowUpsScreenState extends State<EventFollowUpsScreen>
    with SingleTickerProviderStateMixin, ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  String get _eventId => widget.event?.id ?? widget.eventId ?? '';

  // Data
  List<FollowUpRow> _followUps = [];
  Map<String, dynamic>? _stats;

  late final SyncProvider _sync;

  // Filter
  static const List<String> _filterOptions = ['All', 'Pending', 'Done', 'Skipped'];
  String _activeFilter = 'All';

  // Expanded composer
  String? _expandedContactId;
  bool _isDraftLoading = false;
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _bodyCtrl;

  @override
  void initState() {
    super.initState();
    // Pushed full-screen into the shell's nested navigator, so the shell's
    // bottom nav + live bar would otherwise stay mounted underneath. Hide them
    // while this screen is open (restored in dispose).
    navBarHide();
    _subjectCtrl = TextEditingController();
    _bodyCtrl = TextEditingController();
    _sync = context.read<SyncProvider>();
    _loadStats();
  }

  @override
  void dispose() {
    navBarShow();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading — only the lightweight aggregate-count summary still hits
  // the API directly; the follow-up list itself streams from drift.
  // ---------------------------------------------------------------------------

  Future<void> _loadStats() async {
    if (_eventId.isEmpty) return;
    try {
      final stats = await ApiService.getEventStats(_eventId);
      if (mounted) setState(() => _stats = stats);
    } on UnauthorizedException { rethrow; } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Derived helpers
  // ---------------------------------------------------------------------------

  bool _isSent(FollowUpRow fu) => fu.followUpStatus == 'done';
  bool _isSkipped(FollowUpRow fu) => fu.followUpStatus == 'skipped';

  List<FollowUpRow> get _filteredFollowUps {
    return _followUps.where((fu) {
      final sent = _isSent(fu);
      switch (_activeFilter) {
        case 'Pending':
          return !sent && !_isSkipped(fu);
        case 'Done':
          return sent;
        case 'Skipped':
          return _isSkipped(fu) && !sent;
        default:
          return true;
      }
    }).toList();
  }

  int get _totalContacts => _followUps.length;
  int get _sentCount => _followUps.where(_isSent).length;
  int get _skippedCount => _followUps.where((fu) => _isSkipped(fu) && !_isSent(fu)).length;
  int get _pendingCount => _followUps.where((fu) => !_isSent(fu) && !_isSkipped(fu)).length;
  double get _completionRate =>
      _totalContacts == 0 ? 0 : _sentCount / _totalContacts;

  String _initials(FollowUpRow fu) {
    final f = fu.firstName;
    final l = fu.lastName ?? '';
    return '${f.isNotEmpty ? f[0] : ''}${l.isNotEmpty ? l[0] : ''}'.toUpperCase();
  }

  String _fullName(FollowUpRow fu) => '${fu.firstName} ${fu.lastName ?? ''}'.trim();

  String _role(FollowUpRow fu) =>
      fu.jobTitle?.isNotEmpty == true ? fu.jobTitle! : 'Contact';


  String _draftSubject(FollowUpRow fu) {
    final saved = fu.draftSubject;
    if (saved != null && saved.isNotEmpty) return saved;
    final companyName = fu.companyName ?? '';
    return companyName.isNotEmpty
        ? 'Following up — ${fu.firstName} from $companyName'
        : 'Following up from our meeting, ${fu.firstName}';
  }

  String _savedDraftBody(FollowUpRow fu) => fu.draftBody ?? '';

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _afterFollowUpWrite() async {
    await _sync.followUps.catchUp();
    await _sync.contacts.catchUp();
    await _sync.emailDrafts.catchUp();
    // The stats strip reads the server aggregate (_stats); refresh it so the
    // Pending/Done/Skipped counts move in step with the freshly-synced list.
    await _loadStats();
  }

  Future<void> _expandComposer(FollowUpRow fu) async {
    final contactId = fu.contactId;
    if (_expandedContactId == contactId) {
      setState(() => _expandedContactId = null);
      return;
    }
    // Show saved draft immediately, then try to generate AI draft if no saved body
    final savedBody = _savedDraftBody(fu);
    setState(() {
      _expandedContactId = contactId;
      _subjectCtrl.text = _draftSubject(fu);
      _bodyCtrl.text = savedBody;
    });
    // Generate AI draft only when no saved body exists
    if (savedBody.isEmpty && _eventId.isNotEmpty && contactId.isNotEmpty) {
      setState(() => _isDraftLoading = true);
      try {
        final draft = await ApiService.generateFollowUpDraft(_eventId, contactId);
        if (mounted && _expandedContactId == contactId) {
          final subject = draft['subject'] ?? '';
          final body = draft['body'] ?? '';
          setState(() {
            if (subject.isNotEmpty) _subjectCtrl.text = subject;
            _bodyCtrl.text = body;
            _isDraftLoading = false;
          });
        }
      } on UnauthorizedException { rethrow; } catch (_) {
        if (mounted) setState(() => _isDraftLoading = false);
      }
    }
  }

  Future<void> _showFollowedUpDialog(FollowUpRow fu) async {
    final contactId = fu.contactId;
    if (contactId.isEmpty) {
      _snack('Cannot log follow-up for a target company without a contact.');
      return;
    }
    // The email body drafted in the composer above — offered to the user as the
    // email they "sent" when channel is Email.
    final draftBody = _bodyCtrl.text.trim();
    final r = await showLogFollowUpSheet(
      context: context,
      name: _fullName(fu),
      hasDraftEmail: draftBody.isNotEmpty,
    );
    if (r == null || !mounted) return;

    setState(() => _expandedContactId = null);
    _snack('Follow-up logged.');
    await ApiService.markFollowUpSent(
      _eventId,
      contactId,
      subject: _subjectCtrl.text.isNotEmpty ? _subjectCtrl.text : null,
      body: _bodyCtrl.text.isNotEmpty ? _bodyCtrl.text : null,
    ).catchError((_) {});
    await _afterFollowUpWrite();
    // Manual channels carry a free-text mode label (e.g. "Coffee Chat") that
    // drives the timeline item title on the contact detail screen.
    final label = r.channel == 'manual'
        ? (r.mode.isNotEmpty ? r.mode : 'Manual')
        : _channelLabel(r.channel);
    final details = <String, dynamic>{
      'channel': label,
      'mode': label,
      // Marks this interaction as the follow-up's completion so the backend does
      // NOT reopen the just-completed follow-up to pending.
      'follow_up_log': true,
      if (r.emailUsed && draftBody.isNotEmpty) 'email': draftBody,
    };
    ApiService.logInteraction(
      contactId: contactId,
      eventId: _eventId.isNotEmpty ? _eventId : null,
      type: r.channel,
      summary: r.note.isNotEmpty ? r.note : 'Followed up via $label',
      details: details,
    ).catchError((_) => <String, dynamic>{});
  }

  String _channelLabel(String channel) => switch (channel) {
    'email' => 'Email',
    'call'  => 'Call',
    _       => 'Manual',
  };

  Future<void> _markSent(String contactId) async {
    setState(() => _expandedContactId = null);
    _snack('Follow-up sent.');
    if (_eventId.isNotEmpty) {
      await ApiService.markFollowUpSent(
        _eventId,
        contactId,
        subject: _subjectCtrl.text.isNotEmpty ? _subjectCtrl.text : null,
        body: _bodyCtrl.text.isNotEmpty ? _bodyCtrl.text : null,
      ).catchError((_) {});
      await _afterFollowUpWrite();
    }
  }

  Future<void> _markSkipped(String contactId) async {
    setState(() => _expandedContactId = null);
    _snack('Contact skipped for now.');
    if (_eventId.isNotEmpty) {
      // Mirror into drift so the home "Follow-ups Due" stat updates live.
      await _sync.followUps.setStatusLocal(contactId, 'skipped',
          eventId: _eventId, scopeToEvent: true);
      await ApiService.skipFollowUp(_eventId, contactId).catchError((_) {});
      await _afterFollowUpWrite();
    }
  }

  Future<void> _unskip(String contactId) async {
    setState(() => _expandedContactId = null);
    _snack('Moved back to pending.');
    if (_eventId.isNotEmpty) {
      // Mirror into drift so the home "Follow-ups Due" stat updates live.
      await _sync.followUps.setStatusLocal(contactId, 'pending',
          eventId: _eventId, scopeToEvent: true);
      await ApiService.unskipFollowUp(_eventId, contactId).catchError((_) {});
      await _afterFollowUpWrite();
    }
  }

  void _snack(String msg) {
    showAppToast(context, msg);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.theme.colors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              eventName: widget.event?.name,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: _eventId.isEmpty
                  ? _buildEmptyState()
                  : StreamBuilder<List<FollowUpRow>>(
                      stream: _sync.followUps.watchFollowUps(_eventId),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          debugPrint('watchFollowUps error: ${snapshot.error}');
                          return _buildEmptyState();
                        }
                        if (!snapshot.hasData) return _buildSkeleton();
                        _followUps = snapshot.data!;
                        return _buildBody();
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Body sections
  // ---------------------------------------------------------------------------

  Widget _buildBody() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _buildSummaryHero(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Follow-Up Queue',
                        style: context.theme.typography.xl.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    _CountBadge(count: _pendingCount, colors: _c),
                  ],
                ),
                const SizedBox(height: 14),
                AppFilterRow(
                  filters: _filterOptions,
                  selected: _activeFilter,
                  onSelect: (f) => setState(() => _activeFilter = f),
                ),
              ],
            ),
          ),
        ),
        if (_filteredFollowUps.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Text(
                  'No contacts match this filter.',
                  style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final fu = _filteredFollowUps[i];
                final key = fu.contactId;
                final isLast = i == _filteredFollowUps.length - 1;
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    16, 0, 16,
                    isLast ? bottomScrollInset(context, margin: 32) : 12,
                  ),
                  child: _ContactFollowUpCard(
                    fu: fu,
                    contactId: key,
                    colors: _c,
                    isExpanded: _expandedContactId == key,
                    isDraftLoading: _isDraftLoading && _expandedContactId == key,
                    isSent: _isSent(fu),
                    isSkipped: _isSkipped(fu),
                    subjectCtrl: _expandedContactId == key ? _subjectCtrl : null,
                    bodyCtrl: _expandedContactId == key ? _bodyCtrl : null,
                    onExpand: () => _expandComposer(fu),
                    onSend: () => _markSent(key),
                    onSkip: () => _markSkipped(key),
                    onUnskip: () => _unskip(key),
                    onFollowedUp: () => _showFollowedUpDialog(fu),
                    initials: _initials(fu),
                    fullName: _fullName(fu),
                    role: _role(fu),
                    companyName: fu.companyName ?? '',
                  ),
                );
              },
              childCount: _filteredFollowUps.length,
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Summary hero
  // ---------------------------------------------------------------------------

  Widget _buildSummaryHero() {
    final eventName = widget.event?.name ?? 'Event';
    final location = widget.event?.location;
    final dateStr = widget.event != null ? _formatDate(widget.event!.localStartDate) : '';

    return AppCard(
      padding: const EdgeInsets.all(24),
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppChip.status('COMPLETED', color: _c.textSecondary),
              const Spacer(),
              AppChip.label(dateStr),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            eventName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.theme.typography.xl2.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: context.theme.colors.foreground,
              height: 1.15,
            ),
          ),
          if (location != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 15, color: _c.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppSectionLabel('Follow-Up Completion'),
                  ),
                  Text(
                    '${(_completionRate * 100).round()}%',
                    style: context.theme.typography.sm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _completionRate == 1 ? _c.success : _c.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _AnimatedProgressBar(value: _completionRate, colors: _c),
            ],
          ),
          const SizedBox(height: 20),
          FDivider(style: FDividerStyleDelta.delta(
              color: context.theme.colors.border,
              padding: EdgeInsetsGeometryDelta.value(EdgeInsets.zero))),
          const SizedBox(height: 18),
          _buildStatsStrip(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Inline stats strip (merged into the hero card)
  // ---------------------------------------------------------------------------

  Widget _buildStatsStrip() {
    // Prefer the server aggregate (matches the events-screen past card), fall
    // back to the live drift-stream counts before stats load.
    final totalCaptures = (_stats?['total_contacts'] as num?)?.toInt() ?? _totalContacts;
    final pending = (_stats?['follow_ups_needed'] as num?)?.toInt() ?? _pendingCount;
    final skipped = (_stats?['follow_ups_skipped'] as num?)?.toInt() ?? _skippedCount;
    final done = (_stats?['follow_ups_done'] as num?)?.toInt() ?? _sentCount;

    return Row(
      children: [
        Expanded(child: _HeroStat(
          value: '$totalCaptures', label: 'Contacts', colors: _c)),
        _heroStatDivider(),
        Expanded(child: _HeroStat(
          value: '$pending', label: 'Pending',
          valueColor: pending > 0 ? _c.accent : null, colors: _c)),
        _heroStatDivider(),
        Expanded(child: _HeroStat(
          value: '$skipped', label: 'Skipped',
          valueColor: skipped > 0 ? context.theme.colors.error : null, colors: _c)),
        _heroStatDivider(),
        Expanded(child: _HeroStat(
          value: '$done', label: 'Done',
          valueColor: done > 0 ? _c.success : null, colors: _c)),
      ],
    );
  }

  Widget _heroStatDivider() => Container(
      width: 1, height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: context.theme.colors.border.withValues(alpha: 0.5));

  // ---------------------------------------------------------------------------
  // Empty / error states
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _c.accentSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.mark_email_read_outlined, size: 34, color: _c.accent),
            ),
            const SizedBox(height: 20),
            Text(
              'All caught up!',
              style: context.theme.typography.xl.copyWith(fontWeight: FontWeight.w700, color: context.theme.colors.foreground),
            ),
            const SizedBox(height: 8),
            Text(
              'No follow-ups are pending for this event.',
              style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Skeleton
  // ---------------------------------------------------------------------------

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero card skeleton
          _skeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonLoader(width: 90, height: 22, borderRadius: BorderRadius.circular(4)),
                    const Spacer(),
                    SkeletonLoader(width: 70, height: 22, borderRadius: BorderRadius.circular(4)),
                  ],
                ),
                const SizedBox(height: 16),
                SkeletonLoader(width: 220, height: 26, borderRadius: BorderRadius.circular(5)),
                const SizedBox(height: 10),
                SkeletonLoader(width: 160, height: 14, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 20),
                SkeletonLoader(width: double.infinity, height: 6, borderRadius: BorderRadius.circular(999)),
                const SizedBox(height: 20),
                SkeletonLoader(width: double.infinity, height: 1, borderRadius: BorderRadius.zero),
                const SizedBox(height: 18),
                // Inline stats strip skeleton
                Row(
                  children: List.generate(4, (i) => Expanded(
                    child: Column(
                      children: [
                        SkeletonLoader(width: 32, height: 26, borderRadius: BorderRadius.circular(4)),
                        const SizedBox(height: 6),
                        SkeletonLoader(width: 48, height: 11, borderRadius: BorderRadius.circular(3)),
                      ],
                    ),
                  )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SkeletonLoader(width: 160, height: 20, borderRadius: BorderRadius.circular(5)),
          const SizedBox(height: 14),
          SkeletonLoader(width: double.infinity, height: 36, borderRadius: BorderRadius.circular(999)),
          const SizedBox(height: 16),
          for (int i = 0; i < 3; i++) ...[
            const SkeletonCard(),
            if (i < 2) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _skeletonCard({required Widget child, double radius = 20}) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: radius,
      child: child,
    );
  }

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ===========================================================================
// Contact follow-up card (self-contained, extracted for readability)
// ===========================================================================

class _ContactFollowUpCard extends StatelessWidget {
  final FollowUpRow fu;
  final String contactId;
  final ExonoColors colors;
  final bool isExpanded;
  final bool isDraftLoading;
  final bool isSent;
  final bool isSkipped;
  final TextEditingController? subjectCtrl;
  final TextEditingController? bodyCtrl;
  final VoidCallback onExpand;
  final VoidCallback onSend;
  final VoidCallback onSkip;
  final VoidCallback onUnskip;
  final VoidCallback onFollowedUp;
  final String initials;
  final String fullName;
  final String role;
  final String companyName;

  const _ContactFollowUpCard({
    required this.fu,
    required this.contactId,
    required this.colors,
    required this.isExpanded,
    required this.isDraftLoading,
    required this.isSent,
    required this.isSkipped,
    required this.subjectCtrl,
    required this.bodyCtrl,
    required this.onExpand,
    required this.onSend,
    required this.onSkip,
    required this.onUnskip,
    required this.onFollowedUp,
    required this.initials,
    required this.fullName,
    required this.role,
    required this.companyName,
  });

  ExonoColors get _c => colors;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      radius: 20,
      borderColor: isSent ? _c.success.withValues(alpha: 0.4) : null,
      child: Column(
        children: [
          // ── Header row (always visible) ─────────────────────────────────
          GestureDetector(
            onTap: (isSent || isSkipped) ? null : onExpand,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AppAvatar(initials: initials, size: 46, done: isSent),
                  const SizedBox(width: 14),
                  // Name + role
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Text(
                                fullName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: context.theme.typography.lg.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: context.theme.colors.foreground,
                                  letterSpacing: -0.2,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            if (isSent) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: AppChip.status('FOLLOWED UP', color: _c.success),
                              ),
                            ] else if (isSkipped) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: AppChip.status('SKIPPED', color: context.theme.colors.mutedForeground),
                              ),
                            ],
                          ],
                        ),
                        if (role.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.theme.typography.xs
                                .copyWith(color: context.theme.colors.mutedForeground)),
                        ],
                        if (companyName.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(companyName,
                            softWrap: true,
                            style: context.theme.typography.xs.copyWith(
                              color: _c.accent,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            )),
                        ],
                      ],
                    ),
                  ),
                  // Contact detail button — quick access to full profile.
                  AppHeaderActionButton(
                    icon: Icons.person_outline_rounded,
                    onPressed: () => context.push('/contacts/$contactId'),
                  ),
                  // Trailing action
                  if (isSent) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle_rounded, color: _c.success, size: 22),
                  ] else if (isSkipped) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: AppButton(
                        label: 'UNSKIP',
                        onPressed: onUnskip,
                        variant: ButtonVariant.secondary,
                        size: ButtonSize.sm,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: _c.accent, size: 18),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // ── Expanded composer ──────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: isExpanded && !isSkipped && !isSent
                ? _buildComposer(context)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick action buttons (Followed Up + Skip)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'FOLLOWED UP',
                  onPressed: onFollowedUp,
                  fullWidth: true,
                ),
              ),
              const SizedBox(width: 10),
              AppButton(
                label: 'SKIP',
                onPressed: onSkip,
                variant: ButtonVariant.outline,
              ),
            ],
          ),
        ),
        // Divider before draft
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Expanded(child: FDivider(style: FDividerStyleDelta.delta(color: context.theme.colors.border, padding: EdgeInsetsGeometryDelta.value(EdgeInsets.zero)))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'OR SEND EMAIL',
                  style: context.theme.typography.xs.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: context.theme.colors.mutedForeground),
                ),
              ),
              Expanded(child: FDivider(style: FDividerStyleDelta.delta(color: context.theme.colors.border, padding: EdgeInsetsGeometryDelta.value(EdgeInsets.zero)))),
            ],
          ),
        ),
        // Email draft
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: AppCard(
            padding: EdgeInsets.zero,
            radius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  decoration: BoxDecoration(
                    color: _c.surfaceAlt.withValues(alpha: 0.4),
                    border: Border(
                      bottom: BorderSide(color: context.theme.colors.border.withValues(alpha: 0.35)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SUBJECT',
                        style: context.theme.typography.xs.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AppInput(
                        controller: subjectCtrl,
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MESSAGE',
                        style: context.theme.typography.xs.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (isDraftLoading)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              SkeletonLoader(width: double.infinity, height: 14),
                              SizedBox(height: 10),
                              SkeletonLoader(width: double.infinity, height: 14),
                              SizedBox(height: 10),
                              SkeletonLoader(width: 220, height: 14),
                              SizedBox(height: 18),
                              SkeletonLoader(width: double.infinity, height: 14),
                              SizedBox(height: 10),
                              SkeletonLoader(width: 160, height: 14),
                            ],
                          ),
                        )
                      else
                        AppInput(
                          controller: bodyCtrl,
                          maxLines: null,
                          minLines: 6,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: AppButton(
                  label: 'SEND',
                  onPressed: onSend,
                  fullWidth: true,
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                label: 'COPY',
                onPressed: () {
                  final subject = subjectCtrl?.text ?? '';
                  final body = bodyCtrl?.text ?? '';
                  Clipboard.setData(ClipboardData(
                      text: subject.isNotEmpty
                          ? 'Subject: $subject\n\n$body'
                          : body));
                  showAppToast(context, 'Draft copied to clipboard.');
                },
                variant: ButtonVariant.outline,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Sub-widgets
// ===========================================================================

class _TopBar extends StatelessWidget {
  final String? eventName;
  final VoidCallback onBack;

  const _TopBar({
    required this.eventName,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.94),
            border: Border(bottom: BorderSide(color: context.theme.colors.border, width: 1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              AppHeaderActionButton(
                icon: Icons.arrow_back_rounded,
                onPressed: onBack,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'FOLLOW-UP QUEUE',
                      style: context.theme.typography.xs.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                        color: context.theme.colors.mutedForeground,
                      ),
                    ),
                    if (eventName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        eventName!,
                        style: context.theme.typography.sm.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: context.theme.colors.foreground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final ExonoColors colors;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.colors,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: context.theme.typography.xl2.copyWith(
            fontWeight: FontWeight.w800,
            color: valueColor ?? context.theme.colors.foreground,
            letterSpacing: -0.5,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        // Shrink-to-fit so labels like "CONTACTS" stay on one line and all four
        // cells align, matching the events-screen past card.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label.toUpperCase(),
            maxLines: 1,
            style: context.theme.typography.xs.copyWith(
              fontWeight: FontWeight.w600,
              color: context.theme.colors.mutedForeground,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final ExonoColors colors;

  const _CountBadge({required this.count, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$count pending',
        style: context.theme.typography.xs.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.accent,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _AnimatedProgressBar extends StatefulWidget {
  final double value;
  final ExonoColors colors;

  const _AnimatedProgressBar({required this.value, required this.colors});

  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _anim = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOut,
  );

  @override
  void didUpdateWidget(_AnimatedProgressBar old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final isComplete = widget.value >= 1.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 6,
        color: c.surfaceElevated,
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, _) => FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (_anim.value * widget.value).clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: isComplete ? c.success : c.accent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

