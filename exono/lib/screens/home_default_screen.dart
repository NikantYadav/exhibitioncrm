import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_header.dart';
import '../widgets/app_section_label.dart';
import '../widgets/app_filter_row.dart';
import 'live_target_person_screen.dart';
import 'log_interaction_screen.dart';

class HomeDefaultScreen extends StatefulWidget {
  const HomeDefaultScreen({super.key});

  @override
  State<HomeDefaultScreen> createState() => _HomeDefaultScreenState();
}

class _HomeDefaultScreenState extends State<HomeDefaultScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  bool _isLiveEvent = false;
  bool _isLoadingLiveEvent = false;

  // Live event state
  Event? _liveEvent;
  Map<String, dynamic>? _liveStats;
  List<Map<String, dynamic>> _liveGoals = [];
  List<Map<String, dynamic>> _liveTargets = [];

  // Target list state
  String _targetSearch = '';
  String _targetFilter = 'All';
  final TextEditingController _targetSearchCtrl = TextEditingController();
  final Set<String> _expandedTargetIds = {};
  final Map<String, bool> _targetMetOverrides = {};

  // Quick AI state
  final List<Map<String, String>> _aiMessages = [];
  bool _aiLoading = false;
  final TextEditingController _aiQueryCtrl = TextEditingController();

  Future<void> _toggleLiveEvent() async {
    if (_isLiveEvent) {
      setState(() { _isLiveEvent = false; });
      return;
    }
    setState(() { _isLoadingLiveEvent = true; });
    try {
      final event = await ApiService.getOngoingEvent();
      await _fetchLiveData(event);
      if (mounted) setState(() { _isLiveEvent = true; _isLoadingLiveEvent = false; });
    } catch (e) {
      if (mounted) {
        setState(() { _isLoadingLiveEvent = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: _c.destructive,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _fetchLiveData(Event event) async {
    final data = await ApiService.getLiveEventData(event.id);
    if (!mounted) return;
    setState(() {
      _liveEvent = event;
      _liveStats = data['stats'] as Map<String, dynamic>;
      _liveGoals = List<Map<String, dynamic>>.from(data['goals'] as List);
      _liveTargets = List<Map<String, dynamic>>.from(data['targets'] as List);
      // Reset local overrides so fresh data is authoritative
      _targetMetOverrides.clear();
      _expandedTargetIds.clear();
    });
  }

  Future<void> _refreshLiveData() async {
    if (_liveEvent == null) return;
    try { await _fetchLiveData(_liveEvent!); } catch (_) {}
  }

  Future<void> _incrementGoal(Map<String, dynamic> goal) async {
    final eventId = _liveEvent?.id;
    if (eventId == null) return;
    final newVal = ((goal['current'] as int) + 1).clamp(0, goal['total'] as int);
    // Optimistic update
    setState(() {
      final idx = _liveGoals.indexWhere((g) => g['id'] == goal['id']);
      if (idx != -1) _liveGoals[idx] = {..._liveGoals[idx], 'current': newVal};
    });
    try {
      await ApiService.updateEventGoal(eventId, goal['id'] as String, {'current': newVal});
    } catch (_) {
      // Revert
      setState(() {
        final idx = _liveGoals.indexWhere((g) => g['id'] == goal['id']);
        if (idx != -1) _liveGoals[idx] = {..._liveGoals[idx], 'current': goal['current']};
      });
    }
  }

  Future<void> _showAddGoalSheet() async {
    final eventId = _liveEvent?.id;
    if (eventId == null) return;
    final labelCtrl = TextEditingController();
    final totalCtrl = TextEditingController(text: '1');
    final c = _c;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Goal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 20),
            TextField(
              controller: labelCtrl,
              autofocus: true,
              style: TextStyle(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Goal label (e.g. Meet 5 VCs)',
                hintStyle: TextStyle(color: c.textMuted),
                filled: true, fillColor: c.surfaceAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: totalCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'Target count',
                hintStyle: TextStyle(color: c.textMuted),
                filled: true, fillColor: c.surfaceAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final label = labelCtrl.text.trim();
                  final total = int.tryParse(totalCtrl.text.trim()) ?? 1;
                  if (label.isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    final newGoal = await ApiService.createEventGoal(eventId, label, total);
                    if (mounted) setState(() { _liveGoals.add(newGoal); });
                  } catch (e) {
                    if (mounted) _toast('Failed to add goal');
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: (_c.isDark ? _c.textPrimary : _c.background),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ADD GOAL', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteGoal(Map<String, dynamic> goal) async {
    final eventId = _liveEvent?.id;
    if (eventId == null) return;
    setState(() { _liveGoals.removeWhere((g) => g['id'] == goal['id']); });
    try {
      await ApiService.deleteEventGoal(eventId, goal['id'] as String);
    } catch (_) {
      if (mounted) {
        setState(() { _liveGoals.add(goal); });
        _toast('Failed to delete goal');
      }
    }
  }

  Future<void> _sendAiQuery() async {
    final question = _aiQueryCtrl.text.trim();
    final eventId = _liveEvent?.id;
    if (question.isEmpty || eventId == null) return;
    _aiQueryCtrl.clear();
    setState(() {
      _aiMessages.add({'role': 'user', 'content': question});
      _aiLoading = true;
    });
    try {
      final answer = await ApiService.askEventQuestion(eventId, question);
      if (mounted) setState(() { _aiMessages.add({'role': 'assistant', 'content': answer}); });
    } catch (_) {
      if (mounted) setState(() { _aiMessages.add({'role': 'assistant', 'content': 'Sorry, I couldn\'t answer that right now.'}); });
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  final List<String> _promptChips = const [
    'Draft follow-up for Sarah',
    'Analyze recent event leads',
    'Network health report',
  ];

  final List<_InsightCardData> _insights = const [
    _InsightCardData(
      title: 'David Chen',
      subtitle: 'Last active at Tech Summit • 12 days ago',
      avatarLabel: 'DC',
      actionPrimary: 'Draft Follow-Up',
      actionSecondary: 'More',
      icon: Icons.person_outline_rounded,
    ),
    _InsightCardData(
      title: 'Cloud Architecture Cluster',
      subtitle: '5 new contacts found in shared circles',
      avatarLabel: 'CL',
      actionPrimary: 'Ask AI Strategy',
      actionSecondary: 'View Cluster',
      icon: Icons.hub_rounded,
      useIconAvatar: true,
    ),
    _InsightCardData(
      title: 'Sarah Jenkins',
      subtitle: 'Mentioned "Q3 Expansion" in LinkedIn post',
      avatarLabel: 'SJ',
      actionPrimary: 'Draft Follow-Up',
      actionSecondary: 'Signal',
      icon: Icons.bolt_rounded,
    ),
  ];

  final List<_EventCardData> _events = const [
    _EventCardData('OCT', '24', 'SaaS Connect 2024', 'Networking Lounge • 10:00 AM'),
    _EventCardData('OCT', '27', 'Private Equity Mixer', 'The Ritz-Carlton • 6:30 PM'),
    _EventCardData('NOV', '02', 'Growth Leaders Dinner', 'Aria Suite • 8:00 PM'),
  ];

  @override
  void dispose() {
    _targetSearchCtrl.dispose();
    _aiQueryCtrl.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  bool _isTargetMet(Map<String, dynamic> t) {
    final id = t['id'] as String? ?? '';
    return _targetMetOverrides.containsKey(id)
        ? _targetMetOverrides[id]!
        : (t['status'] as String?) == 'met';
  }

  List<Map<String, dynamic>> get _filteredTargets {
    final q = _targetSearch.toLowerCase();
    final filtered = _liveTargets.where((t) {
      final name = (t['name'] as String? ?? '').toLowerCase();
      final company = (t['company_name'] as String? ?? '').toLowerCase();
      final booth = (t['booth'] as String? ?? '').toLowerCase();
      final matchesSearch = q.isEmpty ||
          name.contains(q) || company.contains(q) || booth.contains(q);
      final priority = t['priority'] as String? ?? 'low';
      final matchesFilter = switch (_targetFilter) {
        'Met' => _isTargetMet(t),
        'Not Met' => !_isTargetMet(t),
        'High' => priority == 'high',
        'Medium' => priority == 'medium',
        _ => true,
      };
      return matchesSearch && matchesFilter;
    }).toList();
    return filtered;
  }

  Future<void> _toggleTargetMet(Map<String, dynamic> target) async {
    final id = target['id'] as String? ?? '';
    final eventId = _liveEvent?.id;
    if (eventId == null || id.isEmpty) return;
    final nowMet = !_isTargetMet(target);
    setState(() {
      _targetMetOverrides[id] = nowMet;
      if (nowMet) _expandedTargetIds.remove(id);
    });
    try {
      await ApiService.updateTargetStatus(
          eventId, id, nowMet ? 'met' : 'not_contacted');
    } catch (_) {
      if (mounted) {
        setState(() => _targetMetOverrides.remove(id));
        _toast('Failed to update target status');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              onNotificationPressed: () => _toast('Notifications are UI-only for now.'),
              actionIcon: Icons.bolt_rounded,
              actionTooltip: _isLiveEvent ? 'Exit live event' : 'Enter live event',
              onActionPressed: _toggleLiveEvent,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _isLiveEvent ? _buildLiveEventBody() : _buildNoEventBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ─── NO-EVENT BODY ──────────────────────────────────────────────────────────

  Widget _buildNoEventBody() {
    final auth = context.watch<AuthProvider>();
    final firstName = auth.displayName.trim().split(RegExp(r'\s+')).first;

    return SingleChildScrollView(
      key: const ValueKey('no-event'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good Morning, $firstName',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.0,
              color: _c.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your professional network is ready.',
            style: TextStyle(fontSize: 14, color: _c.textMuted, height: 1.4),
          ),
          const SizedBox(height: 24),
          _buildAiCard(),
          const SizedBox(height: 24),
          AppSectionLabel('Today\'s Priorities'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPriorityTile(
                  icon: Icons.schedule_rounded,
                  value: '3',
                  label: 'Follow-ups Due',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPriorityTile(
                  icon: Icons.history_rounded,
                  value: '4',
                  label: 'Contacts to Reconnect',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppSectionLabel('Network Insights'),
          const SizedBox(height: 12),
          ..._insights.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildInsightCard(item),
            ),
          ),
          const SizedBox(height: 12),
          AppSectionLabel('Upcoming Events'),
          const SizedBox(height: 12),
          ..._events.map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildEventCard(event),
            ),
          ),
        ],
      ),
    );
  }

  void _openChat({String? initialMessage}) {
    if (initialMessage != null) {
      context.push('/chat?msg=${Uri.encodeComponent(initialMessage)}');
    } else {
      context.push('/chat');
    }
  }

  Widget _buildAiCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.all(20),
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _c.accentSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        size: 16, color: _c.accent),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Assistant',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _c.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _c.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _c.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Tappable search bar
              GestureDetector(
                onTap: () => _openChat(),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: _c.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _c.border),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Icon(Icons.search_rounded, color: _c.textMuted, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search contacts, events, or ask anything…',
                          style: TextStyle(fontSize: 13, color: _c.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(Icons.mic_none_rounded,
                            color: _c.border, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Prompt chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _promptChips
                    .map(
                      (prompt) => GestureDetector(
                        onTap: () => _openChat(initialMessage: prompt),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: _c.border),
                          ),
                          child: Text(
                            prompt,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _c.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => showLogInteractionSheet(context),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            label: const Text(
              'LOG INTERACTION',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _c.accent,
              foregroundColor: (_c.isDark ? _c.textPrimary : _c.background),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityTile({required IconData icon, required String value, required String label}) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 12,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _c.textPrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _c.textPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _c.textPrimary, height: 1),
              ),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _c.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(_InsightCardData item) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      radius: 16,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _c.surfaceAlt,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _c.border),
                ),
                alignment: Alignment.center,
                child: item.useIconAvatar
                    ? Icon(item.icon, color: _c.textMuted, size: 22)
                    : Text(
                        item.avatarLabel,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _c.textPrimary),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _c.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _c.textMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _toast('${item.actionPrimary} is UI-only for now.'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _c.textPrimary,
                    side: BorderSide(color: _c.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(item.actionPrimary, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => _toast('${item.actionSecondary} is UI-only for now.'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _c.textPrimary,
                  side: BorderSide(color: _c.border),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(item.actionSecondary, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(_EventCardData event) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 12,
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(border: Border(right: BorderSide(color: _c.border))),
            child: Column(
              children: [
                Text(
                  event.month,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: _c.textMuted),
                ),
                const SizedBox(height: 4),
                Text(event.day, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _c.textPrimary, height: 1)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _c.textPrimary)),
                const SizedBox(height: 4),
                Text(event.subtitle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _c.textMuted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── LIVE EVENT BODY ─────────────────────────────────────────────────────────

  Widget _buildLiveEventBody() {
    if (_isLoadingLiveEvent) {
      return Center(
        key: const ValueKey('live-loading'),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: _c.accent, strokeWidth: 2),
          const SizedBox(height: 16),
          Text('Loading live event…', style: TextStyle(color: _c.textMuted, fontSize: 14)),
        ]),
      );
    }

    final event = _liveEvent;
    if (event == null) return const SizedBox.shrink();

    final stats = _liveStats;
    final reach = stats?['target_reach'] as int? ?? 0;
    final scanned = stats?['scanned'] as int? ?? 0;
    final targetsLeft = stats?['targets_left'] as int? ?? 0;
    final followUps = stats?['pending_follow_ups'] as int? ?? 0;

    final location = [event.venue, event.hall]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' • ');

    return RefreshIndicator(
      color: _c.accent,
      backgroundColor: _c.surface,
      onRefresh: _refreshLiveData,
      child: SingleChildScrollView(
        key: const ValueKey('live-event'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLiveBanner(event, location),
            const SizedBox(height: 12),
            _buildLiveStatGrid(reach, scanned, targetsLeft, followUps),
            const SizedBox(height: 24),
            _buildLiveGoalsSection(),
            const SizedBox(height: 24),
            _buildQuickAiSection(),
            const SizedBox(height: 24),
            _buildLiveTargetsSection(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => showLogInteractionSheet(context),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('LOG INTERACTION',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                style: FilledButton.styleFrom(
                  backgroundColor: _c.accent,
                  foregroundColor: (_c.isDark ? _c.textPrimary : _c.background),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveBanner(Event event, String location) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: AppTheme.radiusCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _PulsingDot(color: _c.destructive),
            const SizedBox(width: 8),
            Text('LIVE NOW', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                letterSpacing: 1.6, color: _c.destructive)),
          ]),
          const SizedBox(height: 14),
          Text(event.name, style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800,
              letterSpacing: -0.6, color: _c.textPrimary, height: 1.1)),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.location_on_outlined, size: 14, color: _c.textMuted),
              const SizedBox(width: 6),
              Expanded(child: Text(location,
                  style: TextStyle(fontSize: 13, color: _c.textMuted),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveStatGrid(int reach, int scanned, int targetsLeft, int followUps) {
    return Column(children: [
      Row(children: [
        Expanded(child: _buildLiveStatTile(Icons.show_chart_rounded, _c.accent, '$reach%', 'TARGET REACH')),
        const SizedBox(width: 10),
        Expanded(child: _buildLiveStatTile(Icons.qr_code_scanner_rounded, _c.success, '$scanned', 'SCANNED')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _buildLiveStatTile(Icons.people_outline_rounded, _c.textSecondary, '$targetsLeft', 'TARGETS LEFT')),
        const SizedBox(width: 10),
        Expanded(child: _buildLiveStatTile(Icons.mark_email_unread_outlined, _c.destructive, '$followUps', 'FOLLOW-UPS')),
      ]),
    ]);
  }

  Widget _buildLiveStatTile(IconData icon, Color color, String value, String label) {
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(14),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800,
              color: _c.textPrimary, height: 1)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700,
              letterSpacing: 0.7, color: _c.textMuted)),
        ],
      ),
    );
  }

  Widget _buildLiveGoalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          AppSectionLabel('Goal Progress'),
          const Spacer(),
          GestureDetector(
            onTap: _showAddGoalSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _c.accent.withValues(alpha: 0.5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 12, color: _c.accent),
                const SizedBox(width: 4),
                Text('ADD GOAL', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    letterSpacing: 1.0, color: _c.accent)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (_liveGoals.isEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(children: [
              Icon(Icons.flag_outlined, size: 20, color: _c.textMuted),
              const SizedBox(width: 12),
              Expanded(child: Text(
                  'No goals yet — tap ADD GOAL to create one.',
                  style: TextStyle(fontSize: 13, color: _c.textMuted, height: 1.4))),
            ]),
          )
        else
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(children: [
              for (int i = 0; i < _liveGoals.length; i++) ...[
                _buildGoalRow(_liveGoals[i]),
                if (i < _liveGoals.length - 1) ...[
                  Divider(color: _c.border.withValues(alpha: 0.4), height: 1),
                  const SizedBox(height: 4),
                ],
              ],
            ]),
          ),
      ],
    );
  }

  Widget _buildLiveTargetsSection() {
    final visible = _filteredTargets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          AppSectionLabel('Targets'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _c.accentSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('${_liveTargets.length}', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: _c.accent)),
          ),
        ]),
        const SizedBox(height: 12),
        // Search
        TextField(
          controller: _targetSearchCtrl,
          style: TextStyle(fontSize: 13, color: _c.textPrimary),
          cursorColor: _c.accent,
          onChanged: (v) => setState(() => _targetSearch = v),
          decoration: InputDecoration(
            hintText: 'Search companies, people, booths…',
            hintStyle: TextStyle(fontSize: 13, color: _c.textMuted),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(Icons.search_rounded, size: 18, color: _c.textMuted),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            filled: true,
            fillColor: _c.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _c.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _c.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _c.accent)),
          ),
        ),
        const SizedBox(height: 10),
        // Filters
        AppFilterRow(
          filters: const ['All', 'Not Met', 'Met', 'High', 'Medium'],
          selected: _targetFilter,
          onSelect: (f) => setState(() => _targetFilter = f),
          style: AppFilterRowStyle.filled,
        ),
        const SizedBox(height: 14),
        // Target list
        if (_liveTargets.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Center(child: Column(children: [
              Icon(Icons.people_outline_rounded, color: _c.textMuted, size: 32),
              const SizedBox(height: 10),
              Text('No targets yet for this event.',
                  style: TextStyle(color: _c.textMuted, fontSize: 13)),
            ])),
          )
        else if (visible.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.search_off_rounded, color: _c.textMuted, size: 20),
              const SizedBox(width: 12),
              Text('No targets match.', style: TextStyle(fontSize: 13, color: _c.textMuted)),
            ]),
          )
        else
          Column(children: [
            for (int i = 0; i < visible.length; i++) ...[
              _buildTargetCard(visible[i], i + 1),
              if (i < visible.length - 1) const SizedBox(height: 8),
            ],
          ]),
      ],
    );
  }

  Widget _buildQuickAiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 13, color: _c.accent),
          const SizedBox(width: 7),
          AppSectionLabel('Quick AI', color: _c.accent),
        ]),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Message history (max last 6)
            if (_aiMessages.isNotEmpty) ...[
              for (final msg in _aiMessages.reversed.take(6).toList().reversed)
                _buildAiMessage(msg),
              const SizedBox(height: 8),
              Divider(color: _c.border.withValues(alpha: 0.5), height: 1),
              const SizedBox(height: 8),
            ],
            // Input row
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _aiQueryCtrl,
                  onSubmitted: (_) => _sendAiQuery(),
                  style: TextStyle(fontSize: 13, color: _c.textPrimary),
                  cursorColor: _c.accent,
                  decoration: InputDecoration(
                    hintText: 'Ask about this event…',
                    hintStyle: TextStyle(fontSize: 13, color: _c.textMuted),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true, fillColor: _c.surfaceAlt,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(color: _c.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(color: _c.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(color: _c.accent)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _aiLoading ? null : _sendAiQuery,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _aiLoading ? _c.surfaceElevated : _c.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: _aiLoading
                      ? Padding(
                          padding: const EdgeInsets.all(11),
                          child: CircularProgressIndicator(strokeWidth: 2, color: _c.textMuted))
                      : Icon(Icons.arrow_upward_rounded,
                          size: 18, color: _c.isDark ? _c.textPrimary : _c.background),
                ),
              ),
            ]),
          ]),
        ),
      ],
    );
  }

  Widget _buildAiMessage(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: _c.accentSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.auto_awesome_rounded, size: 12, color: _c.accent),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isUser ? _c.accentSoft : _c.surfaceAlt,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isUser ? 14 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 14),
                ),
              ),
              child: Text(msg['content'] ?? '', style: TextStyle(
                  fontSize: 13,
                  color: isUser ? _c.accent : _c.textSecondary,
                  height: 1.45)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalRow(Map<String, dynamic> goal) {
    final current = goal['current'] as int;
    final total = goal['total'] as int;
    final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
    final isComplete = progress >= 1.0;

    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: _c.surface,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: _c.border, borderRadius: BorderRadius.circular(2))),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: _c.destructive),
                title: Text('Delete goal', style: TextStyle(color: _c.destructive)),
                onTap: () { Navigator.pop(context); _deleteGoal(goal); },
              ),
            ]),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isComplete ? _c.success : Colors.transparent,
                  border: Border.all(
                    color: isComplete ? _c.success : _c.border, width: 1.5),
                ),
                child: isComplete
                    ? Icon(Icons.check_rounded, size: 11, color: (_c.isDark ? _c.textPrimary : _c.background))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(goal['label'] as String, style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500,
                  color: isComplete ? _c.success : _c.textPrimary,
                  decoration: isComplete ? TextDecoration.lineThrough : null,
                  decorationColor: _c.success))),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: isComplete ? null : () => _incrementGoal(goal),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isComplete
                        ? _c.success.withValues(alpha: 0.10)
                        : _c.accentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (!isComplete) ...[
                      Icon(Icons.add_rounded, size: 12, color: _c.accent),
                      const SizedBox(width: 4),
                    ],
                    Text('$current / $total', style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: isComplete ? _c.success : _c.accent)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                backgroundColor: _c.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(
                    isComplete ? _c.success : _c.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetCard(Map<String, dynamic> target, int rank) {
    final id = target['id'] as String? ?? '';
    final name = target['name'] as String? ?? '';
    final jobTitle = target['job_title'] as String? ?? '';
    final companyName = target['company_name'] as String? ?? '';
    final booth = target['booth'] as String? ?? '';
    final priority = target['priority'] as String? ?? 'low';
    final isMet = _isTargetMet(target);
    final isExpanded = _expandedTargetIds.contains(id);
    final priorityColor = switch (priority) {
      'high' => _c.destructive,
      'medium' => _c.accent,
      _ => _c.textMuted,
    };
    final priorityLabel = switch (priority) {
      'high' => 'HIGH',
      'medium' => 'MED',
      _ => 'LOW',
    };

    return AppCard(
      radius: AppTheme.radiusCard,
      elevated: isExpanded,
      borderColor: priority == 'high'
          ? _c.destructive.withValues(alpha: 0.40)
          : priority == 'medium'
              ? _c.accent.withValues(alpha: 0.22)
              : null,
      child: Column(children: [
        // ── Header ──
        InkWell(
          onTap: id.isEmpty ? null : () => setState(() {
            if (isExpanded) { _expandedTargetIds.remove(id); }
            else { _expandedTargetIds.add(id); }
          }),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusCard),
            bottom: isExpanded ? Radius.zero : Radius.circular(AppTheme.radiusCard),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Priority badge + rank
              Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(priorityLabel, style: TextStyle(
                      fontSize: 8, fontWeight: FontWeight.w800,
                      letterSpacing: 0.7, color: priorityColor)),
                ),
                const SizedBox(height: 5),
                Text(rank.toString().padLeft(2, '0'), style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: _c.textMuted)),
              ]),
              const SizedBox(width: 12),
              // Name + subtitle + tags
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    name.isNotEmpty ? name : companyName,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: isMet ? _c.textMuted : _c.textPrimary),
                  ),
                  if (jobTitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(jobTitle, style: TextStyle(fontSize: 12, color: _c.textMuted),
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    if (companyName.isNotEmpty) ...[
                      AppChip.label(companyName),
                      const SizedBox(width: 6),
                    ],
                    if (booth.isNotEmpty) ...[
                      AppChip.label('BOOTH $booth'),
                      const SizedBox(width: 6),
                    ],
                    const Spacer(),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18, color: _c.textMuted),
                  ]),
                ]),
              ),
              const SizedBox(width: 10),
              // Met toggle
              GestureDetector(
                onTap: () => _toggleTargetMet(target),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isMet ? _c.success.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isMet ? _c.success : _c.border,
                      width: 1.5,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (isMet) ...[
                      Icon(Icons.check_rounded, size: 12, color: _c.success),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      isMet ? 'MET' : 'MARK\nMET',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: isMet ? _c.success : _c.textMuted,
                          height: 1.2),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        // ── Expanded actions ──
        if (isExpanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: _c.surfaceAlt,
              border: Border(top: BorderSide(color: _c.border)),
              borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(AppTheme.radiusCard)),
            ),
            child: Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => showLogInteractionSheet(context),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                  label: const Text('LOG'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _c.accent,
                    foregroundColor: (_c.isDark ? _c.textPrimary : _c.background),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _liveEvent == null ? null : () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => LiveTargetPersonScreen(
                          event: _liveEvent!, target: target),
                    ));
                  },
                  icon: Icon(Icons.person_outline_rounded, size: 14, color: _c.textPrimary),
                  label: const Text('PROFILE'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _c.textPrimary,
                    side: BorderSide(color: _c.border),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

// ─── Pulsing dot ─────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1.0, end: 0.35).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

// ─── Data models ─────────────────────────────────────────────────────────────

class _InsightCardData {
  final String title;
  final String subtitle;
  final String avatarLabel;
  final String actionPrimary;
  final String actionSecondary;
  final IconData icon;
  final bool useIconAvatar;

  const _InsightCardData({
    required this.title,
    required this.subtitle,
    required this.avatarLabel,
    required this.actionPrimary,
    required this.actionSecondary,
    required this.icon,
    this.useIconAvatar = false,
  });
}

class _EventCardData {
  final String month;
  final String day;
  final String title;
  final String subtitle;
  const _EventCardData(this.month, this.day, this.title, this.subtitle);
}

