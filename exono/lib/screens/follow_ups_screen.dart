import 'package:flutter/material.dart';
import '../utils/safe_area_insets.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/offline_provider.dart';
import '../providers/sync_provider.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/app_stat_row.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/log_follow_up_sheet.dart';
import '../widgets/app_filter_row.dart';
import '../widgets/app_header.dart';
import '../widgets/app_offline_screen.dart';
import '../widgets/skeleton_loader.dart';
import '../utils/screen_logger.dart';

class FollowUpsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  final Event? event;
  final String? eventId;

  const FollowUpsScreen({
    super.key,
    this.onNavigateTab,
    this.event,
    this.eventId,
  });

  @override
  State<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends State<FollowUpsScreen> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  List<Map<String, dynamic>> _needsFollowup = [];
  List<Map<String, dynamic>> _followedUp    = [];
  List<Map<String, dynamic>> _notContacted  = [];
  List<Map<String, dynamic>> _skipped       = [];

  // All past/completed events for the event filter
  List<Event> _events = [];
  // null = All events
  String? _selectedEventId;

  bool _loading = true;
  String _activeFilter = 'Pending';
  // Contact id of the currently expanded multi-event card (null = none).
  String? _expandedContactId;

  static const _filters = ['Pending', 'Done', 'New', 'Skipped'];

  @override
  void initState() {
    super.initState();
    // Pre-select the event filter when opened from a specific event context
    if (widget.event != null) _selectedEventId = widget.event!.id;
    if (widget.eventId != null) _selectedEventId = widget.eventId;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getAllFollowUps(),
        ApiService.getEvents(),
      ]);

      final data = results[0] as Map<String, dynamic>;
      final allEvents = results[1] as List<Event>;
      final raw = data['data'] as Map<String, dynamic>? ?? {};

      if (!mounted) return;
      setState(() {
        _needsFollowup = _parseList(raw['needs_followup']);
        _followedUp    = _parseList(raw['followed_up']);
        _notContacted  = _parseList(raw['not_contacted']);
        _skipped       = _parseList(raw['skipped']);
        // Only show events that have contacts (past + ongoing)
        _events = allEvents
            .where((e) => e.status == 'completed' || e.status == 'ongoing')
            .toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate));
        _loading = false;
      });
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) =>
      (raw as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

  // Filter by selected event if one is chosen. A collapsed home card carries its
  // winning record's event_id plus a `records` array of every (contact, event)
  // record — match if any of them is tagged to the selected event.
  List<Map<String, dynamic>> _filterByEvent(List<Map<String, dynamic>> list) {
    if (_selectedEventId == null) return list;
    return list.where((c) {
      if (c['event_id']?.toString() == _selectedEventId) return true;
      final records = (c['records'] as List?) ?? [];
      return records.any((r) => (r as Map)['event_id']?.toString() == _selectedEventId);
    }).toList();
  }

  List<Map<String, dynamic>> get _activeList {
    final base = switch (_activeFilter) {
      'Done'    => _followedUp,
      'New'     => _notContacted,
      'Skipped' => _skipped,
      _         => _needsFollowup,
    };
    final filtered = _filterByEvent(base);
    // Priority contacts (global contacts.is_priority) surface at the top; order
    // is otherwise preserved (stable sort) so the existing recency order holds
    // within each group.
    final sorted = [...filtered]..sort((a, b) {
      final pa = a['is_priority'] == true ? 0 : 1;
      final pb = b['is_priority'] == true ? 0 : 1;
      return pa.compareTo(pb);
    });
    return sorted;
  }

  String? get _selectedEventName {
    if (_selectedEventId == null) return null;
    for (final e in _events) {
      if (e.id == _selectedEventId) return e.name;
    }
    return null;
  }

  int get _pendingCount => _filterByEvent(_needsFollowup).length;
  int get _doneCount    => _filterByEvent(_followedUp).length;
  int get _newCount     => _filterByEvent(_notContacted).length;
  int get _skippedCount => _filterByEvent(_skipped).length;

  // ── helpers ──────────────────────────────────────────────────────────────────

  String _initials(Map<String, dynamic> c) {
    final f = (c['first_name'] as String? ?? '').trim();
    final l = (c['last_name']  as String? ?? '').trim();
    if (f.isEmpty && l.isEmpty) return '?';
    return '${f.isNotEmpty ? f[0] : ''}${l.isNotEmpty ? l[0] : ''}'.toUpperCase();
  }

  String _fullName(Map<String, dynamic> c) =>
      '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'.trim();

  String _company(Map<String, dynamic> c) {
    final co = c['company'];
    return co is Map ? (co['name'] as String? ?? '') : '';
  }

  String _lastTouched(Map<String, dynamic> c) {
    final raw = c['last_interaction'] as String?;
    if (raw == null) return 'Never';
    final rel = _relativeTime(raw);
    return rel.isEmpty ? '' : rel;
  }

  // Relative "Today / 3d ago / 2w ago" label for an ISO timestamp. Empty on
  // null/parse failure.
  String _relativeTime(String? raw) {
    if (raw == null) return '';
    try {
      final diff = DateTime.now().difference(DateTime.parse(raw).toLocal());
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7)  return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      return '${(diff.inDays / 30).floor()}mo ago';
    } on UnauthorizedException { rethrow; } catch (_) { return ''; }
  }

  // Human label for an interaction_type, used as the no-event record's title
  // (in place of a generic "General"). Falls back to "General" when unknown.
  String _interactionMode(String? type) => switch (type) {
    'coffee_chat'     => 'Coffee Chat',
    'call'            => 'Call',
    'meeting'         => 'Meeting',
    'email'           => 'Email',
    'voice_note'      => 'Voice Note',
    'note'            => 'Note',
    'document_upload' => 'Document',
    'follow_up'       => 'Follow-Up',
    'capture'         => 'Capture',
    'manual'          => 'Manual',
    _                 => 'General',
  };

  // ── actions ──────────────────────────────────────────────────────────────────

  // Status rank for "most urgent wins" — mirrors the backend collapse so the
  // optimistic re-bucket matches what a reload would produce.
  static const _statusRank = {'pending': 3, 'new': 2, 'skipped': 1, 'done': 0};

  // Optimistically move ONE record of a contact to [status] and re-bucket the
  // contact's collapsed card across the four lists — no API reload, no skeleton.
  // [extraRecordPatch] lets callers patch other record fields (e.g. the new
  // last-interaction summary) at the same time.
  void _applyRecordStatus(String contactId, String? eventId, String status,
      {Map<String, dynamic>? extraRecordPatch}) {
    // Pull the contact's card out of whichever list it currently lives in.
    Map<String, dynamic>? card;
    for (final list in [_needsFollowup, _followedUp, _notContacted, _skipped]) {
      final idx = list.indexWhere((c) => c['id'] == contactId);
      if (idx != -1) { card = list.removeAt(idx); break; }
    }
    if (card == null) return;

    // Update the matching record (by event_id) in the card's records array.
    final records = ((card['records'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final matchIdx = records.indexWhere((r) => r['event_id']?.toString() == eventId?.toString());
    if (matchIdx != -1) {
      records[matchIdx] = {
        ...records[matchIdx],
        'follow_up_status': status,
        ...?extraRecordPatch,
      };
    }
    card['records'] = records;

    // Winning status drives both the card chip and which list it belongs to.
    final winner = records.isEmpty
        ? status
        : records
            .map((r) => r['follow_up_status'] as String? ?? 'pending')
            .reduce((a, b) => (_statusRank[a] ?? 0) >= (_statusRank[b] ?? 0) ? a : b);
    card['follow_up_status'] = winner;

    final target = switch (winner) {
      'done'    => _followedUp,
      'new'     => _notContacted,
      'skipped' => _skipped,
      _         => _needsFollowup,
    };
    target.insert(0, card);
    setState(() {});
  }

  // Set the status of ONE event-scoped record (from an expanded card row).
  // event_id may be null (the "General" record). Updates in place — no reload.
  Future<void> _setRecordStatus(String contactId, String? eventId, String status) async {
    _applyRecordStatus(contactId, eventId, status);
    // Write through to the local drift cache so the home "Follow-ups Due" stat
    // (driven by watchDueCount) updates immediately, without waiting for the
    // backend write's Realtime echo.
    await context.read<SyncProvider>().followUps
        .setStatusLocal(contactId, status, eventId: eventId, scopeToEvent: true);
    try {
      await ApiService.setFollowUpStatus(contactId, status,
          eventId: eventId, scopeToEvent: true);
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) await _load(); // reconcile on failure
    }
  }

  // Toggle the GLOBAL priority flag on a contact (contacts.is_priority). The
  // global Follow-Ups screen is contact-scoped, so this is never per-event.
  // Optimistically flip every in-memory card for the contact, then write through.
  Future<void> _togglePriority(String contactId, bool next) async {
    setState(() {
      for (final list in [_needsFollowup, _followedUp, _notContacted, _skipped]) {
        for (final c in list) {
          if (c['id'] == contactId) c['is_priority'] = next;
        }
      }
    });
    try {
      await ApiService.setContactPriority(contactId, next);
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) await _load(); // reconcile on failure
    }
  }

  // "Followed Up" from a record row: open the Log Follow-Up sheet (no email
  // checkbox — there's no drafted email on this screen), mark the record done,
  // and log the completion interaction (flagged so it doesn't reopen the record).
  Future<void> _logFollowUp(String contactId, String contactName, String? eventId) async {
    final r = await showLogFollowUpSheet(context: context, name: contactName);
    if (r == null || !mounted) return;

    final label = r.channel == 'manual'
        ? (r.mode.isNotEmpty ? r.mode : 'Manual')
        : switch (r.channel) { 'email' => 'Email', 'call' => 'Call', _ => 'Manual' };
    final summary = r.note.isNotEmpty ? r.note : 'Followed up via $label';
    // Optimistically flip to done and reflect the just-logged interaction.
    _applyRecordStatus(contactId, eventId, 'done', extraRecordPatch: {
      'last_interaction_summary': summary,
      'last_interaction_type': r.channel,
      'last_interaction_date': DateTime.now().toUtc().toIso8601String(),
    });
    // Mirror the done status into the local drift cache so the home stat drops
    // immediately (see _setRecordStatus).
    await context.read<SyncProvider>().followUps
        .setStatusLocal(contactId, 'done', eventId: eventId, scopeToEvent: true);
    try {
      await ApiService.setFollowUpStatus(contactId, 'done',
          eventId: eventId, scopeToEvent: true);
      await ApiService.logInteraction(
        contactId: contactId,
        eventId: eventId,
        type: r.channel,
        summary: summary,
        details: {
          'channel': label,
          'mode': label,
          // Completion log — must not reopen the just-completed follow-up.
          'follow_up_log': true,
        },
      );
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) await _load(); // reconcile on failure
    }
  }

  void _showEventFilterSheet() {
    final searchCtrl = TextEditingController();
    showAppSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          top: false,
          // Adaptive cap: at most 70% of the screen height so the sheet never
          // fills the screen, but shrinks to fit when there are only a few
          // events. The inner list scrolls within this bound on small screens.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: ctx.theme.colors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Filter by Event',
                  style: ctx.theme.typography.lg.copyWith(fontWeight: FontWeight.w700, color: ctx.theme.colors.foreground)),
                const SizedBox(height: 12),
                AppInput(
                  hint: 'Search events...',
                  controller: searchCtrl,
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppTheme.colorsOf(ctx).accent),
                  onChanged: (_) => setSheet(() {}),
                ),
                const SizedBox(height: 12),
                // Scrollable event list — the header/search stay pinned while the
                // options scroll, so a long event list never overflows the sheet.
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _eventOption(
                          ctx: ctx,
                          id: null,
                          name: 'All Events',
                          isSelected: _selectedEventId == null,
                        ),
                        const SizedBox(height: 8),
                        if (_events.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text('No completed events yet.',
                              style: ctx.theme.typography.sm.copyWith(color: ctx.theme.colors.mutedForeground)),
                          )
                        else ...[
                          ...(_events
                            .where((e) => e.name.toLowerCase().contains(searchCtrl.text.toLowerCase()))
                            .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _eventOption(
                                ctx: ctx,
                                id: e.id,
                                name: e.name,
                                isSelected: _selectedEventId == e.id,
                              ),
                            ))),
                          if (_events.isNotEmpty &&
                              _events.where((e) => e.name.toLowerCase().contains(searchCtrl.text.toLowerCase())).isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text('No events match your search.',
                                style: ctx.theme.typography.sm.copyWith(color: ctx.theme.colors.mutedForeground)),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      // Defer dispose to the next frame so the sheet's element subtree (the
      // AppInput depending on this controller) fully unmounts first; disposing
      // synchronously here races teardown and trips the _dependents assertion.
      WidgetsBinding.instance.addPostFrameCallback((_) => searchCtrl.dispose());
    });
  }

  Widget _eventOption({
    required BuildContext ctx,
    required String? id,
    required String name,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        setState(() => _selectedEventId = id);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _c.accentSoft : _c.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _c.accent.withValues(alpha: 0.4) : context.theme.colors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              id == null ? Icons.event_note_rounded : Icons.event_rounded,
              size: 16,
              color: isSelected ? _c.accent : context.theme.colors.mutedForeground,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(name,
              style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w600,
                color: isSelected ? _c.accent : context.theme.colors.foreground),
              overflow: TextOverflow.ellipsis)),
            if (isSelected)
              Icon(Icons.check_rounded, size: 16, color: _c.accent),
          ],
        ),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<OfflineProvider>().isOnline;
    if (!isOnline) return const AppOfflineScreen(title: 'Follow-ups');

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
                  onPressed: () => widget.event != null || widget.eventId != null
                      ? Navigator.of(context).pop()
                      : context.go('/'),
                ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                color: _c.accent,
                backgroundColor: context.theme.colors.background,
                onRefresh: _load,
                child: _loading ? _buildSkeleton() : _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final eventName = _selectedEventId == null
        ? null
        : _events.firstWhere((e) => e.id == _selectedEventId,
            orElse: () => _events.first).name;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(eventName)),
        SliverToBoxAdapter(child: _buildSummaryStrip()),
        // Status filter chips — full-width row (Event filter now lives in the
        // header, so the chips get the whole width and nothing is clipped).
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: AppFilterRow(
              filters: _filters,
              selected: _activeFilter,
              onSelect: (f) => setState(() => _activeFilter = f),
            ),
          ),
        ),
        _activeList.isEmpty
            ? SliverToBoxAdapter(child: _buildEmpty())
            : SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, bottomScrollInset(context)),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildContactCard(_activeList[i]),
                    ),
                    childCount: _activeList.length,
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildHeader(String? eventName) {
    final showEventFilter = widget.event == null && widget.eventId == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Follow-Ups',
                  style: context.theme.typography.xl2.copyWith(fontWeight: FontWeight.w800,
                    letterSpacing: -1.0, color: context.theme.colors.foreground, height: 1.1)),
                const SizedBox(height: 4),
                Text(
                  eventName != null
                      ? '$eventName · $_pendingCount pending'
                      : '$_pendingCount pending · $_doneCount done'
                          '${_skippedCount > 0 ? ' · $_skippedCount skipped' : ''}',
                  style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground),
                ),
              ],
            ),
          ),
          if (showEventFilter) ...[
            const SizedBox(width: 10),
            _EventFilterButton(
              active: _selectedEventId != null,
              label: _selectedEventName ?? 'Event',
              accent: _c.accent,
              accentSoft: _c.accentSoft,
              surfaceAlt: _c.surfaceAlt,
              onTap: _showEventFilterSheet,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryStrip() {
    final total = _pendingCount + _doneCount + _newCount;
    final doneRatio = total > 0 ? _doneCount / total : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppStatRow(dividerHeight: 32, stats: [
              AppStat(value: '$_pendingCount', label: 'Pending', valueColor: _c.accent),
              AppStat(value: '$_doneCount', label: 'Done', valueColor: _c.success),
              AppStat(value: '$_newCount', label: 'New', valueColor: context.theme.colors.mutedForeground),
            ]),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: doneRatio,
                minHeight: 5,
                backgroundColor: _c.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(_c.success),
              ),
            ),
            const SizedBox(height: 6),
            Text('$_doneCount of $total contacts followed up',
              style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground)),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    final status = contact['follow_up_status'] as String? ?? '';
    final isDone = status == 'done';
    final company = _company(contact);
    final designation = (contact['job_title'] as String? ?? '').trim();
    final lastTouched = _lastTouched(contact);
    final contactId = contact['id'] as String;
    // Every card expands into its per-event record rows. The home collapse always
    // nests at least the winning record under `records`; fall back to a synthetic
    // single record built from the contact if it's somehow empty.
    final rawRecords = (contact['records'] as List?) ?? const [];
    final records = rawRecords.isNotEmpty
        ? rawRecords.cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[contact];
    final recordCount = records.length;
    final isExpanded = _expandedContactId == contactId;
    final isPriority = contact['is_priority'] == true;
    // Priority cards use a full accent background, so foreground text/icons flip
    // to the inverted (on-accent) color. Non-priority cards keep theme colors.
    final fg = isPriority ? context.theme.colors.primaryForeground : context.theme.colors.foreground;
    final mutedFg = isPriority
        ? context.theme.colors.primaryForeground.withValues(alpha: 0.75)
        : context.theme.colors.mutedForeground;

    final cardChild = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: avatar + info
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AppAvatar(initials: _initials(contact), done: isDone),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_fullName(contact),
                        maxLines: 2,
                        style: context.theme.typography.sm.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDone ? mutedFg : fg,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor: mutedFg,
                        ),
                        overflow: TextOverflow.ellipsis),
                      if (designation.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(designation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.theme.typography.xs.copyWith(color: mutedFg)),
                      ],
                      if (company.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(company,
                          softWrap: true,
                          style: context.theme.typography.xs.copyWith(
                            color: isPriority ? context.theme.colors.primaryForeground : _c.accent,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          )),
                      ],
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.access_time_rounded, size: 11, color: mutedFg),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            recordCount > 1 ? '$recordCount follow-ups' : lastTouched,
                            style: context.theme.typography.xs.copyWith(color: mutedFg),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                  ),
                ),
                // Priority toggle — star fills when the contact is a priority.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _togglePriority(contactId, !isPriority),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      isPriority ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 22,
                      color: isPriority ? context.theme.colors.primaryForeground : _c.accent,
                    ),
                  ),
                ),
                // Contact detail button — system-themed action button.
                AppHeaderActionButton(
                  icon: Icons.person_outline_rounded,
                  onPressed: () => context.push('/contacts/$contactId'),
                ),
                // Chevron toggle — every card expands into its record rows.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() =>
                      _expandedContactId = isExpanded ? null : contactId),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: isPriority ? context.theme.colors.primaryForeground : _c.accent, size: 22),
                    ),
                  ),
                ),
              ],
            ),

            // Expand into per-event record rows. Each row acts on ONE record.
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  children: [
                    for (final r in records)
                      _buildRecordRow(contactId, _fullName(contact), r),
                  ],
                ),
              ),
          ],
        );

    // Priority cards drop AppCard for a full-accent Container (AppCard can't do
    // a conditional/gradient background); the star + inverted text mark them out.
    if (isPriority) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: _c.accent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: cardChild,
      );
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      radius: 16,
      child: cardChild,
    );
  }

  // One per-event row inside an expanded multi-event contact card. Shows the
  // event label + status and a single action scoped to that one record.
  Widget _buildRecordRow(String contactId, String contactName, Map<String, dynamic> r) {
    final status = r['follow_up_status'] as String? ?? '';
    final eventId = r['event_id'] as String?;
    final eventName = (r['event_name'] as String?)?.trim();
    // Event records show the event name; no-event records show the mode of
    // interaction (e.g. "Coffee Chat", "Voice Note") instead of a generic label.
    final label = (eventName != null && eventName.isNotEmpty)
        ? eventName
        : _interactionMode(r['last_interaction_type'] as String?);

    final (chipText, chipColor) = switch (status) {
      'done'    => ('DONE', _c.success),
      'skipped' => ('SKIPPED', context.theme.colors.mutedForeground),
      'new'     => ('NEW', context.theme.colors.mutedForeground),
      _         => ('PENDING', _c.accent),
    };

    final summary = (r['last_interaction_summary'] as String?)?.trim();
    final when = _relativeTime(r['last_interaction_date'] as String?);

    final isDone = status == 'done';
    final (actionLabel, actionVariant, VoidCallback onAction) = switch (status) {
      'done'    => ('Undo', ButtonVariant.outline, () => _setRecordStatus(contactId, eventId, 'pending')),
      'skipped' => ('To Pending', ButtonVariant.secondary, () => _setRecordStatus(contactId, eventId, 'pending')),
      _         => ('Followed Up', ButtonVariant.primary, () => _logFollowUp(contactId, contactName, eventId)),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _c.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: chipColor.withValues(alpha: 0.22)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status-colored spine — instant visual scan of where this
                // record stands without reading the badge text.
                Container(width: 4, color: chipColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: status pill + relative time.
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: chipColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(chipText,
                                style: context.theme.typography.xs.copyWith(
                                  fontWeight: FontWeight.w700, letterSpacing: 0.5,
                                  color: chipColor, height: 1.0)),
                            ),
                            if (when.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(when,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: context.theme.typography.xs.copyWith(
                                    color: context.theme.colors.mutedForeground)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Event / interaction label — the row's title.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(eventId == null ? Icons.event_note_rounded : Icons.event_rounded,
                                size: 15, color: context.theme.colors.mutedForeground),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(label,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: context.theme.typography.sm.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: context.theme.colors.foreground)),
                            ),
                          ],
                        ),
                        // Last interaction detail — quoted, indented under title.
                        if (summary != null && summary.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(summary,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: context.theme.typography.xs.copyWith(
                              color: context.theme.colors.mutedForeground,
                              height: 1.4)),
                        ],
                        const SizedBox(height: 12),
                        if (status != 'done' && status != 'skipped')
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  label: actionLabel,
                                  onPressed: onAction,
                                  variant: actionVariant,
                                  size: ButtonSize.sm,
                                  prefixIcon: const Icon(Icons.check_circle_outline_rounded),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AppButton(
                                  label: 'Skip',
                                  onPressed: () => _setRecordStatus(contactId, eventId, 'skipped'),
                                  variant: ButtonVariant.outline,
                                  size: ButtonSize.sm,
                                  prefixIcon: const Icon(Icons.skip_next_rounded),
                                ),
                              ),
                            ],
                          )
                        else
                          AppButton(
                            label: actionLabel,
                            onPressed: onAction,
                            variant: actionVariant,
                            size: ButtonSize.sm,
                            fullWidth: true,
                            prefixIcon: isDone
                                ? null
                                : const Icon(Icons.undo_rounded),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final (title, subtitle) = switch (_activeFilter) {
      'Done'    => ('None yet', 'Completed follow-ups will appear here.'),
      'New'     => ('All engaged', 'Every contact has been interacted with.'),
      'Skipped' => ('Nothing skipped', 'Skipped follow-ups will appear here.'),
      _         => ('All caught up', 'No pending follow-ups right now.'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline_rounded, size: 48,
            color: _c.success.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          Text(title, style: context.theme.typography.lg.copyWith(fontWeight: FontWeight.w700,
            color: context.theme.colors.foreground)),
          const SizedBox(height: 6),
          Text(subtitle, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground),
            textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // ── Skeleton ──────────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 20, 16, bottomScrollInset(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader(width: 180, height: 28, borderRadius: BorderRadius.circular(6)),
          const SizedBox(height: 8),
          SkeletonLoader(width: 140, height: 13, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 20),
          _skeletonCard(child: Column(children: [
            Row(children: List.generate(3, (i) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(children: [
                  SkeletonLoader(width: 32, height: 20, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 6),
                  SkeletonLoader(width: 44, height: 10, borderRadius: BorderRadius.circular(3)),
                ]),
              ),
            ))),
            const SizedBox(height: 14),
            SkeletonLoader(width: double.infinity, height: 5, borderRadius: BorderRadius.circular(999)),
          ])),
          const SizedBox(height: 20),
          Row(children: [
            ...List.generate(3, (i) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SkeletonLoader(width: 72, height: 32, borderRadius: BorderRadius.circular(999)),
            )),
            const Spacer(),
            SkeletonLoader(width: 80, height: 32, borderRadius: BorderRadius.circular(999)),
          ]),
          const SizedBox(height: 16),
          for (int i = 0; i < 5; i++) ...[
            _skeletonCard(radius: 16, child: Row(children: [
              SkeletonLoader(width: 44, height: 44, borderRadius: BorderRadius.circular(12)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SkeletonLoader(width: double.infinity, height: 14, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 6),
                SkeletonLoader(width: 100, height: 11, borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: 6),
                SkeletonLoader(width: 72, height: 10, borderRadius: BorderRadius.circular(3)),
              ])),
              const SizedBox(width: 10),
              Column(children: [
                SkeletonLoader(width: 88, height: 30, borderRadius: BorderRadius.circular(999)),
                const SizedBox(height: 6),
                SkeletonLoader(width: 72, height: 26, borderRadius: BorderRadius.circular(999)),
              ]),
            ])),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _skeletonCard({required Widget child, double radius = 20}) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: radius,
      child: child,
    );
  }
}

/// Pill button that opens the event filter sheet. When a specific event is
/// selected it shows that event's name (truncated) so the active filter is
/// legible at a glance, with the Trust Blue accent treatment.
class _EventFilterButton extends StatelessWidget {
  const _EventFilterButton({
    required this.active,
    required this.label,
    required this.accent,
    required this.accentSoft,
    required this.surfaceAlt,
    required this.onTap,
  });

  final bool active;
  final String label;
  final Color accent;
  final Color accentSoft;
  final Color surfaceAlt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? accent : context.theme.colors.mutedForeground;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        constraints: const BoxConstraints(maxWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? accentSoft : surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? accent.withValues(alpha: 0.5)
                : context.theme.colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_rounded, size: 14, color: fg),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.theme.typography.xs.copyWith(
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
            if (active) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

