import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_theme.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_filter_row.dart';
import '../widgets/app_header.dart';
import '../widgets/skeleton_loader.dart';

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

class _FollowUpsScreenState extends State<FollowUpsScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  List<Map<String, dynamic>> _needsFollowup = [];
  List<Map<String, dynamic>> _followedUp    = [];
  List<Map<String, dynamic>> _notContacted  = [];

  // All past/completed events for the event filter
  List<Event> _events = [];
  // null = All events
  String? _selectedEventId;

  bool _loading = true;
  String _activeFilter = 'Pending';

  static const _filters = ['Pending', 'Done', 'New'];

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
        // Only show events that have contacts (past + ongoing)
        _events = allEvents
            .where((e) => e.status == 'completed' || e.status == 'ongoing')
            .toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate));
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) =>
      (raw as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

  // Filter by selected event if one is chosen
  List<Map<String, dynamic>> _filterByEvent(List<Map<String, dynamic>> list) {
    if (_selectedEventId == null) return list;
    return list.where((c) {
      final interactions = (c['interactions'] as List?) ?? [];
      return interactions.any((i) =>
          (i as Map)['event_id']?.toString() == _selectedEventId);
    }).toList();
  }

  List<Map<String, dynamic>> get _activeList {
    final base = switch (_activeFilter) {
      'Done' => _followedUp,
      'New'  => _notContacted,
      _      => _needsFollowup,
    };
    return _filterByEvent(base);
  }

  int get _pendingCount => _filterByEvent(_needsFollowup).length;
  int get _doneCount    => _filterByEvent(_followedUp).length;
  int get _newCount     => _filterByEvent(_notContacted).length;

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
    try {
      final diff = DateTime.now().difference(DateTime.parse(raw).toLocal());
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7)  return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      return '${(diff.inDays / 30).floor()}mo ago';
    } catch (_) { return ''; }
  }

  String _urgencyLabel(String? urgency) => switch (urgency) {
    'high'   => 'URGENT',
    'low'    => 'LOW',
    'medium' => 'MEDIUM',
    _ => '',
  };

  // ── actions ──────────────────────────────────────────────────────────────────

  Future<void> _markFollowedUp(Map<String, dynamic> contact) async {
    final id = contact['id'] as String;
    final updated = {...contact, 'follow_up_status': 'followed_up'};
    // Optimistic update first
    setState(() {
      _needsFollowup.removeWhere((c) => c['id'] == id);
      _notContacted.removeWhere((c) => c['id'] == id);
      _followedUp.insert(0, updated);
    });
    try {
      await ApiService.updateContact(id, {'follow_up_status': 'followed_up'});
    } catch (_) {
      // Revert on failure
      if (mounted) {
        setState(() {
          _followedUp.removeWhere((c) => c['id'] == id);
          _needsFollowup.insert(0, contact);
        });
      }
    }
  }

  Future<void> _markNeedsFollowup(Map<String, dynamic> contact) async {
    final id = contact['id'] as String;
    final updated = {...contact, 'follow_up_status': 'needs_followup'};
    setState(() {
      _followedUp.removeWhere((c) => c['id'] == id);
      _notContacted.removeWhere((c) => c['id'] == id);
      _needsFollowup.insert(0, updated);
    });
    try {
      await ApiService.updateContact(id, {'follow_up_status': 'needs_followup'});
    } catch (_) {
      if (mounted) {
        setState(() {
          _needsFollowup.removeWhere((c) => c['id'] == id);
          _followedUp.insert(0, contact);
        });
      }
    }
  }

  Future<void> _setUrgency(Map<String, dynamic> contact, String urgency) async {
    final id = contact['id'] as String;
    // Update in all three lists optimistically
    void updateList(List<Map<String, dynamic>> list) {
      final idx = list.indexWhere((c) => c['id'] == id);
      if (idx != -1) list[idx] = {...list[idx], 'follow_up_urgency': urgency};
    }
    setState(() {
      updateList(_needsFollowup);
      updateList(_followedUp);
      updateList(_notContacted);
    });
    try {
      await ApiService.updateContact(id, {'follow_up_urgency': urgency});
    } catch (_) {}
  }

  void _showUrgencySheet(Map<String, dynamic> contact) {
    final currentUrgency = contact['follow_up_urgency'] as String? ?? '';
    showAppSheet(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
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
                    color: _c.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Set Urgency',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _c.textPrimary),
              ),
              Text(
                _fullName(contact),
                style: TextStyle(fontSize: 13, color: _c.textMuted),
              ),
              const SizedBox(height: 16),
              for (final opt in [
                ('high',   'Urgent',  Icons.priority_high_rounded, _c.destructive),
                ('medium', 'Medium',  Icons.remove_rounded,        _c.accent),
                ('low',    'Low',     Icons.arrow_downward_rounded, _c.textMuted),
              ]) ...[
                _urgencyOption(
                  contact: contact,
                  value: opt.$1,
                  label: opt.$2,
                  icon: opt.$3,
                  color: opt.$4,
                  isSelected: currentUrgency == opt.$1,
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _urgencyOption({
    required Map<String, dynamic> contact,
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _setUrgency(contact, value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : _c.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.4) : _c.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: _c.textPrimary)),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_rounded, size: 18, color: color),
          ],
        ),
      ),
    );
  }

  void _showEventFilterSheet() {
    showAppSheet(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
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
                    color: _c.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Filter by Event',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _c.textPrimary)),
              const SizedBox(height: 12),
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
                    style: TextStyle(fontSize: 13, color: _c.textMuted)),
                )
              else
                ...(_events.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _eventOption(
                    ctx: ctx,
                    id: e.id,
                    name: e.name,
                    isSelected: _selectedEventId == e.id,
                  ),
                ))),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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
            color: isSelected ? _c.accent.withValues(alpha: 0.4) : _c.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              id == null ? Icons.event_note_rounded : Icons.event_rounded,
              size: 16,
              color: isSelected ? _c.accent : _c.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(name,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: isSelected ? _c.accent : _c.textPrimary),
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
    return Scaffold(
      backgroundColor: _c.background,
      body: DecoratedBox(
        decoration: AppTheme.appBackground(context),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AppHeader(
                onNotificationPressed: () {},
                actionWidget: IconButton(
                  onPressed: () => widget.event != null || widget.eventId != null
                      ? Navigator.of(context).pop()
                      : context.go('/'),
                  icon: Icon(Icons.arrow_back_rounded, color: _c.textPrimary),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: _c.accent,
                  backgroundColor: _c.surface,
                  onRefresh: _load,
                  child: _loading ? _buildSkeleton() : _buildContent(),
                ),
              ),
            ],
          ),
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
        // Filter row + event filter button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: AppFilterRow(
                    filters: _filters,
                    selected: _activeFilter,
                    onSelect: (f) => setState(() => _activeFilter = f),
                  ),
                ),
                if (widget.event == null && widget.eventId == null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _showEventFilterSheet,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _selectedEventId != null
                          ? _c.accentSoft
                          : _c.surfaceAlt,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _selectedEventId != null
                            ? _c.accent.withValues(alpha: 0.5)
                            : _c.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_list_rounded, size: 14,
                          color: _selectedEventId != null ? _c.accent : _c.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          _selectedEventId != null ? 'Event' : 'Event',
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: _selectedEventId != null ? _c.accent : _c.textMuted,
                          ),
                        ),
                        if (_selectedEventId != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(color: _c.accent, shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                ], // end event filter button
              ],
            ),
          ),
        ),
        _activeList.isEmpty
            ? SliverToBoxAdapter(child: _buildEmpty())
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Follow-Ups',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
              letterSpacing: -1.0, color: _c.textPrimary, height: 1.1)),
          const SizedBox(height: 4),
          Text(
            eventName != null
                ? '$eventName · $_pendingCount pending'
                : '$_pendingCount pending · $_doneCount done',
            style: TextStyle(fontSize: 13, color: _c.textMuted),
          ),
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
            Row(children: [
              Expanded(child: _summaryCol('$_pendingCount', 'Pending', _c.accent)),
              _vDivider(),
              Expanded(child: _summaryCol('$_doneCount', 'Done', _c.success)),
              _vDivider(),
              Expanded(child: _summaryCol('$_newCount', 'New', _c.textMuted)),
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
              style: TextStyle(fontSize: 11, color: _c.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _summaryCol(String value, String label, Color valueColor) => Column(children: [
    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
        color: valueColor, height: 1.0)),
    const SizedBox(height: 3),
    Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
        color: _c.textMuted, letterSpacing: 0.3)),
  ]);

  Widget _vDivider() =>
      Container(width: 1, height: 32, color: _c.border.withValues(alpha: 0.5));

  Widget _buildContactCard(Map<String, dynamic> contact) {
    final isDone = (contact['follow_up_status'] as String? ?? '') == 'followed_up';
    final urgency = contact['follow_up_urgency'] as String?;
    final hasUrgency = urgency != null && urgency.isNotEmpty;
    final urgencyLabel = _urgencyLabel(urgency);
    final company = _company(contact);
    final lastTouched = _lastTouched(contact);
    final contactId = contact['id'] as String;

    return GestureDetector(
      onTap: () => context.push('/contacts/$contactId'),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: avatar + info
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDone
                          ? [_c.success.withValues(alpha: 0.18), _c.success.withValues(alpha: 0.08)]
                          : [_c.accent.withValues(alpha: 0.22), _c.accentStrong.withValues(alpha: 0.10)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDone
                          ? _c.success.withValues(alpha: 0.3)
                          : _c.accent.withValues(alpha: 0.25),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isDone
                      ? Icon(Icons.check_rounded, size: 18, color: _c.success)
                      : Text(_initials(contact),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _c.accent)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_fullName(contact),
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: isDone ? _c.textMuted : _c.textPrimary,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor: _c.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis),
                      if (company.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(company,
                          style: TextStyle(fontSize: 12, color: _c.textMuted),
                          overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.access_time_rounded, size: 11, color: _c.textMuted),
                        const SizedBox(width: 4),
                        Text(lastTouched, style: TextStyle(fontSize: 11, color: _c.textMuted)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),

            // Bottom action row — horizontal, full width
            if (!isDone) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: AppButton(
                      label: 'Followed Up',
                      onPressed: () => _markFollowedUp(contact),
                      variant: ButtonVariant.secondary,
                      fullWidth: true,
                      size: ButtonSize.sm,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: hasUrgency ? urgencyLabel : 'Priority',
                      onPressed: () => _showUrgencySheet(contact),
                      variant: ButtonVariant.outline,
                      fullWidth: true,
                      size: ButtonSize.sm,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 10),
              AppButton(
                label: 'Undo',
                onPressed: () => _markNeedsFollowup(contact),
                variant: ButtonVariant.ghost,
                fullWidth: true,
                size: ButtonSize.sm,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final (title, subtitle) = switch (_activeFilter) {
      'Done' => ('None yet', 'Completed follow-ups will appear here.'),
      'New'  => ('All engaged', 'Every contact has been interacted with.'),
      _      => ('All caught up', 'No pending follow-ups right now.'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 0),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline_rounded, size: 48,
            color: _c.success.withValues(alpha: 0.6)),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
            color: _c.textPrimary)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(fontSize: 13, color: _c.textMuted),
            textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // ── Skeleton ──────────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
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
