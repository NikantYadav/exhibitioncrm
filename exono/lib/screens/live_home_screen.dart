import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/event.dart';
import '../providers/live_event_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_filter_row.dart';
import '../widgets/app_header.dart';
import '../widgets/app_section_label.dart';
import 'app_shell.dart';
import 'event_target_screen.dart';
import 'live_target_person_screen.dart';
import 'log_interaction_screen.dart';

/// Standalone live event floor screen — the full workspace shown when an event
/// is ongoing.  Launched via the home auto-redirect and the LiveBar tap.
class LiveHomeScreen extends StatefulWidget {
  const LiveHomeScreen({super.key});

  @override
  State<LiveHomeScreen> createState() => _LiveHomeScreenState();
}

class _LiveHomeScreenState extends State<LiveHomeScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  // Local overrides & UI state
  final Map<String, bool> _targetMetOverrides = {};
  final Set<String> _expandedTargetIds = {};
  final Set<String> _expandedScannedIds = {};
  final TextEditingController _targetSearchCtrl = TextEditingController();
  String _targetSearch = '';
  String _targetFilter = 'All';
  String _scannedSearch = '';
  String _activeTab = 'targets';

  @override
  void initState() {
    super.initState();
    captureReturnSignal.addListener(_onCaptureReturn);
  }

  @override
  void dispose() {
    captureReturnSignal.removeListener(_onCaptureReturn);
    _targetSearchCtrl.dispose();
    super.dispose();
  }

  void _onCaptureReturn() {
    context.read<LiveEventProvider>().refresh();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  bool _isTargetMet(Map<String, dynamic> t) {
    final id = t['id'] as String? ?? '';
    return _targetMetOverrides.containsKey(id)
        ? _targetMetOverrides[id]!
        : (t['status'] as String?) == 'met';
  }

  List<Map<String, dynamic>> _filteredTargets(List<Map<String, dynamic>> targets) {
    final q = _targetSearch.toLowerCase();
    return targets.where((t) {
      if ((t['contact_id'] as String?) == null) return false;
      final name = (t['name'] as String? ?? '').toLowerCase();
      final company = (t['company_name'] as String? ?? '').toLowerCase();
      final booth = (t['booth'] as String? ?? '').toLowerCase();
      final matchesSearch = q.isEmpty || name.contains(q) || company.contains(q) || booth.contains(q);
      final matchesFilter = switch (_targetFilter) {
        'Met' => _isTargetMet(t),
        'Not Met' => !_isTargetMet(t),
        _ => true,
      };
      return matchesSearch && matchesFilter;
    }).toList()
      ..sort((a, b) {
        final aName = (a['name'] as String? ?? a['company_name'] as String? ?? '').toLowerCase();
        final bName = (b['name'] as String? ?? b['company_name'] as String? ?? '').toLowerCase();
        return aName.compareTo(bName);
      });
  }

  // ── Goal actions ───────────────────────────────────────────────────────────

  Future<void> _toggleCheckboxGoal(Map<String, dynamic> goal, Event event, LiveEventProvider lep) async {
    final newVal = (goal['current'] as int) == 1 ? 0 : 1;
    final updated = {...goal, 'current': newVal};
    lep.updateGoalLocally(updated);
    try {
      await ApiService.updateEventGoal(event.id, goal['id'] as String, {'current': newVal});
    } catch (_) {
      lep.revertGoal(goal);
    }
  }

  Future<void> _incrementGoal(Map<String, dynamic> goal, Event event, LiveEventProvider lep) async {
    final newVal = ((goal['current'] as int) + 1).clamp(0, goal['total'] as int);
    final updated = {...goal, 'current': newVal};
    lep.updateGoalLocally(updated);
    try {
      await ApiService.updateEventGoal(event.id, goal['id'] as String, {'current': newVal});
    } catch (_) {
      lep.revertGoal(goal);
    }
  }

  Future<void> _deleteGoal(Map<String, dynamic> goal, Event event, LiveEventProvider lep) async {
    lep.removeGoalLocally(goal['id'] as String);
    try {
      await ApiService.deleteEventGoal(event.id, goal['id'] as String);
    } catch (_) {
      lep.addGoalLocally(goal);
      _toast('Failed to delete goal');
    }
  }

  Future<void> _showAddGoalSheet(Event event, LiveEventProvider lep) async {
    final labelCtrl = TextEditingController();
    final totalCtrl = TextEditingController(text: '1');
    bool isCheckbox = false;
    final c = _c;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                  hintText: isCheckbox ? 'e.g. Visit the sponsor booth' : 'e.g. Meet 5 VCs',
                  hintStyle: TextStyle(color: c.textMuted),
                  filled: true, fillColor: c.surfaceAlt,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.border),
                ),
                child: Stack(children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    alignment: isCheckbox ? Alignment.centerLeft : Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(999)),
                      ),
                    ),
                  ),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => isCheckbox = true),
                        behavior: HitTestBehavior.opaque,
                        child: Center(child: Text('Checkbox', style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: isCheckbox ? (c.isDark ? c.textPrimary : Colors.white) : c.textMuted))),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => isCheckbox = false),
                        behavior: HitTestBehavior.opaque,
                        child: Center(child: Text('Counted', style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: !isCheckbox ? (c.isDark ? c.textPrimary : Colors.white) : c.textMuted))),
                      ),
                    ),
                  ]),
                ]),
              ),
              if (!isCheckbox) ...[
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
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final label = labelCtrl.text.trim();
                    if (label.isEmpty) return;
                    final total = isCheckbox ? 0 : (int.tryParse(totalCtrl.text.trim()) ?? 1);
                    Navigator.pop(ctx);
                    try {
                      final newGoal = await ApiService.createEventGoal(event.id, label, total);
                      if (mounted) lep.addGoalLocally(newGoal);
                    } catch (_) {
                      if (mounted) _toast('Failed to add goal');
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: (c.isDark ? c.textPrimary : c.background),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('ADD GOAL', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Target actions ─────────────────────────────────────────────────────────

  Future<void> _toggleTargetMet(Map<String, dynamic> target, Event event, LiveEventProvider lep) async {
    final id = target['id'] as String? ?? '';
    if (id.isEmpty) return;
    final nowMet = !_isTargetMet(target);
    setState(() {
      _targetMetOverrides[id] = nowMet;
      if (nowMet) _expandedTargetIds.remove(id);
    });
    try {
      await ApiService.updateTargetStatus(event.id, id, nowMet ? 'met' : 'not_contacted');
      lep.updateTargetStatusLocally(id, nowMet ? 'met' : 'not_contacted');
    } catch (_) {
      if (mounted) {
        setState(() => _targetMetOverrides.remove(id));
        _toast('Failed to update target status');
      }
    }
  }

  Future<void> _addContactAsTarget(Event event, LiveEventProvider lep) async {
    final contacts = await ApiService.getContacts();
    if (!mounted) return;

    final existingCompanyIds = lep.liveTargets
        .map((t) => t['company_id'] as String?)
        .whereType<String>()
        .toSet();

    final eligible = contacts
        .where((c) => c.companyId != null && c.companyId!.isNotEmpty && !existingCompanyIds.contains(c.companyId))
        .toList();

    if (eligible.isEmpty) {
      _toast('All your contacts are already in the target list.');
      return;
    }

    final picked = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactPickerSheet(contacts: eligible, colors: _c),
    );

    if (picked == null || !mounted) return;
    final companyId = picked['company_id'] as String;
    final companyName = picked['company_name'] as String;
    final contactId = picked['contact_id'] as String?;
    final contactName = picked['contact_name'] as String?;

    if (contactId == null) {
      _toast('Contact has no ID — cannot add.');
      return;
    }

    try {
      await ApiService.addContactToEvent(event.id, contactId);
      lep.addTargetLocally({
        'id': contactId,
        'name': contactName ?? companyName,
        'job_title': picked['job_title'] ?? '',
        'company_name': companyName,
        'company_id': companyId,
        'contact_id': contactId,
        'booth': '',
        'status': 'not_contacted',
        'priority': 'medium',
        'talking_points': '',
        'notes': '',
      });
      _toast('${contactName ?? companyName} added to targets.');
    } catch (_) {
      _toast('Failed to add target.');
    }
  }

  Future<void> _deleteTarget(Map<String, dynamic> target, Event event, LiveEventProvider lep) async {
    final id = target['id'] as String? ?? '';
    final contactId = target['contact_id'] as String?;
    final name = target['name'] as String? ?? 'Target';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _c.surface,
        title: Text('Remove Target', style: TextStyle(color: _c.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Remove $name from targets?', style: TextStyle(color: _c.textSecondary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: TextStyle(color: _c.textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Remove', style: TextStyle(color: _c.destructive, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      if (contactId != null && contactId == id) {
        await ApiService.removeContactFromEvent(event.id, contactId);
      } else {
        await ApiService.deleteEventTarget(event.id, id);
        if (contactId != null) {
          try { await ApiService.removeContactFromEvent(event.id, contactId); } catch (_) {}
        }
      }
      lep.removeTargetLocally(id);
      _expandedTargetIds.remove(id);
    } catch (_) {
      _toast('Failed to remove target.');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<LiveEventProvider>(
      builder: (context, lep, _) {
        final event = lep.liveEvent;
        if (event == null) {
          // Event ended — go back to home
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && context.canPop()) context.pop();
            else if (mounted) context.go('/');
          });
          return const SizedBox.shrink();
        }

        return Scaffold(
          backgroundColor: _c.background,
          bottomNavigationBar: AppBottomNav(
            selectedIndex: 0,
            onNavigate: (index) {
              if (index == 2) {
                context.push('/capture').then((_) {
                  captureReturnSignal.value++;
                });
              } else {
                final paths = {0: '/', 1: '/events', 3: '/contacts', 7: '/chat-history'};
                context.go(paths[index] ?? '/');
              }
            },
          ),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                AppHeader(
                  onNotificationPressed: () => _toast('Notifications coming soon.'),
                  actionWidget: IconButton(
                    onPressed: () => context.go('/'),
                    icon: Icon(Icons.arrow_back_rounded, color: _c.textPrimary, size: 22),
                    tooltip: 'Back',
                  ),
                ),
                Expanded(child: _buildBody(event, lep)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(Event event, LiveEventProvider lep) {
    final scanned = lep.scannedContacts.length;
    final targetsLeft = lep.liveTargets.where((t) => !_isTargetMet(t)).length;
    final metTargets = lep.liveTargets.where((t) => _isTargetMet(t)).length;
    final totalTargets = scanned + metTargets;

    final location = [event.venue, event.hall]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' • ');

    return RefreshIndicator(
      color: _c.accent,
      backgroundColor: _c.surface,
      onRefresh: lep.refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLiveBanner(event, location),
            const SizedBox(height: 12),
            _buildStatGrid(scanned, targetsLeft, totalTargets),
            const SizedBox(height: 24),
            _buildGoalsSection(event, lep),
            const SizedBox(height: 24),
            _buildTargetsSection(event, lep),
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
              Icon(Icons.location_on_outlined, size: 14, color: _c.accent),
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

  Widget _buildStatGrid(int scanned, int targetsLeft, int totalTargets) {
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(16),
      radius: 14,
      child: Row(children: [
        Expanded(child: _statColumn(Icons.qr_code_scanner_rounded, '$scanned', 'SCANNED')),
        Container(width: 1, height: 48, color: _c.border.withValues(alpha: 0.3)),
        Expanded(child: _statColumn(Icons.people_outline_rounded, '$targetsLeft', 'TARGETS LEFT')),
        Container(width: 1, height: 48, color: _c.border.withValues(alpha: 0.3)),
        Expanded(child: _statColumn(Icons.flag_outlined, '$totalTargets', 'TOTAL')),
      ]),
    );
  }

  Widget _statColumn(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: _c.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: _c.accent),
        ),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _c.textPrimary, height: 1)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.7, color: _c.textMuted),
            textAlign: TextAlign.center),
      ],
    );
  }

  // ── Goals ──────────────────────────────────────────────────────────────────

  Widget _buildGoalsSection(Event event, LiveEventProvider lep) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          AppSectionLabel('Goal Progress'),
          const Spacer(),
          GestureDetector(
            onTap: () => _showAddGoalSheet(event, lep),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _c.accent.withValues(alpha: 0.5)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 12, color: _c.accent),
                const SizedBox(width: 4),
                Text('ADD GOAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: _c.accent)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (lep.liveGoals.isEmpty)
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(children: [
              Icon(Icons.flag_outlined, size: 20, color: _c.accent),
              const SizedBox(width: 12),
              Expanded(child: Text('No goals yet — tap ADD GOAL to create one.',
                  style: TextStyle(fontSize: 13, color: _c.textMuted, height: 1.4))),
            ]),
          )
        else
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(children: [
              for (int i = 0; i < lep.liveGoals.length; i++) ...[
                _buildGoalRow(lep.liveGoals[i], event, lep),
                if (i < lep.liveGoals.length - 1) ...[
                  Divider(color: _c.border.withValues(alpha: 0.4), height: 1),
                  const SizedBox(height: 4),
                ],
              ],
            ]),
          ),
      ],
    );
  }

  Widget _buildGoalRow(Map<String, dynamic> goal, Event event, LiveEventProvider lep) {
    final current = goal['current'] as int;
    final total = goal['total'] as int;
    final isCheckbox = total == 0;
    final isComplete = isCheckbox ? current == 1 : (total > 0 && current >= total);
    final progress = (!isCheckbox && total > 0) ? (current / total).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: _c.surface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: _c.border, borderRadius: BorderRadius.circular(2))),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: _c.destructive),
                title: Text('Delete goal', style: TextStyle(color: _c.destructive)),
                onTap: () { Navigator.pop(context); _deleteGoal(goal, event, lep); },
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
              GestureDetector(
                onTap: isCheckbox ? () => _toggleCheckboxGoal(goal, event, lep) : null,
                child: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isComplete ? _c.success : Colors.transparent,
                    border: Border.all(color: isComplete ? _c.success : _c.border, width: 1.5),
                  ),
                  child: isComplete
                      ? Icon(Icons.check_rounded, size: 11, color: (_c.isDark ? _c.textPrimary : _c.background))
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(goal['label'] as String, style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500,
                  color: isComplete ? _c.success : _c.textPrimary,
                  decoration: isComplete ? TextDecoration.lineThrough : null,
                  decorationColor: _c.success))),
              const SizedBox(width: 10),
              if (isCheckbox)
                GestureDetector(
                  onTap: () => _toggleCheckboxGoal(goal, event, lep),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isComplete ? _c.success.withValues(alpha: 0.10) : _c.accentSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(isComplete ? 'DONE' : 'MARK DONE', style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.4,
                        color: isComplete ? _c.success : _c.accent)),
                  ),
                )
              else
                GestureDetector(
                  onTap: isComplete ? null : () => _incrementGoal(goal, event, lep),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isComplete ? _c.success.withValues(alpha: 0.10) : _c.accentSoft,
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
            if (!isCheckbox) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: _c.surfaceElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(isComplete ? _c.success : _c.accent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Targets / Scanned / Companies tabs ─────────────────────────────────────

  Widget _buildTargetsSection(Event event, LiveEventProvider lep) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: _c.surfaceAlt,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _c.border),
              ),
              child: Stack(children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: _activeTab == 'targets'
                      ? Alignment.centerLeft
                      : _activeTab == 'scanned'
                          ? Alignment.center
                          : Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 1 / 3,
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: _c.accent, borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                ),
                Row(children: [
                  _tabItem('targets', 'Targets',
                      '${lep.liveTargets.where((t) => (t['contact_id'] as String?) != null).length}'),
                  _tabItem('scanned', 'Scanned', '${lep.scannedContacts.length}'),
                  _tabItem('companies', 'Companies', '${lep.liveTargets.length}'),
                ]),
              ]),
            ),
          ),
          if (_activeTab == 'targets') ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _addContactAsTarget(event, lep),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(color: _c.accentSoft, borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_add_outlined, size: 13, color: _c.accent),
                  const SizedBox(width: 5),
                  Text('ADD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: _c.accent)),
                ]),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 16),
        if (_activeTab == 'targets')
          _buildLiveTargetsList(event, lep)
        else if (_activeTab == 'scanned')
          _buildScannedList(lep)
        else
          _buildCompaniesList(event, lep),
      ],
    );
  }

  Widget _tabItem(String tab, String label, String count) {
    final isActive = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = tab),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: isActive ? (_c.isDark ? _c.textPrimary : Colors.white) : _c.textMuted)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withValues(alpha: 0.25) : _c.accentSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(count, style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: isActive ? (_c.isDark ? _c.textPrimary : Colors.white) : _c.accent)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildLiveTargetsList(Event event, LiveEventProvider lep) {
    final visible = _filteredTargets(lep.liveTargets);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
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
              child: Icon(Icons.search_rounded, size: 18, color: _c.accent),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            filled: true, fillColor: _c.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.accent)),
          ),
        ),
        const SizedBox(height: 10),
        AppFilterRow(
          filters: const ['All', 'Not Met', 'Met'],
          selected: _targetFilter,
          onSelect: (f) => setState(() => _targetFilter = f),
          style: AppFilterRowStyle.filled,
        ),
        const SizedBox(height: 14),
        if (lep.liveTargets.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Center(child: Column(children: [
              Icon(Icons.people_outline_rounded, color: _c.accent, size: 32),
              const SizedBox(height: 10),
              Text('No targets yet for this event.', style: TextStyle(color: _c.textMuted, fontSize: 13)),
            ])),
          )
        else if (visible.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.search_off_rounded, color: _c.accent, size: 20),
              const SizedBox(width: 12),
              Text('No targets match.', style: TextStyle(fontSize: 13, color: _c.textMuted)),
            ]),
          )
        else
          Column(children: [
            for (int i = 0; i < visible.length; i++) ...[
              _buildTargetCard(visible[i], i + 1, event, lep),
              if (i < visible.length - 1) const SizedBox(height: 8),
            ],
          ]),
      ],
    );
  }

  Widget _buildTargetCard(Map<String, dynamic> target, int rank, Event event, LiveEventProvider lep) {
    final id = target['id'] as String? ?? '';
    final name = target['name'] as String? ?? '';
    final jobTitle = target['job_title'] as String? ?? '';
    final companyName = target['company_name'] as String? ?? '';
    final booth = target['booth'] as String? ?? '';
    final priority = target['priority'] as String? ?? 'low';
    final contactId = target['contact_id'] as String?;
    final isMet = _isTargetMet(target);
    final isExpanded = _expandedTargetIds.contains(id);

    return AppCard(
      radius: AppTheme.radiusCard,
      elevated: isExpanded,
      borderColor: priority == 'high'
          ? _c.destructive.withValues(alpha: 0.40)
          : priority == 'medium'
              ? _c.accent.withValues(alpha: 0.22)
              : null,
      child: Column(children: [
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
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(rank.toString().padLeft(2, '0'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _c.textMuted)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name.isNotEmpty ? name : companyName, style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2,
                      color: isMet ? _c.textMuted : _c.textPrimary)),
                  const SizedBox(height: 3),
                  Text([if (jobTitle.isNotEmpty) jobTitle, if (companyName.isNotEmpty) companyName].join(', '),
                      style: TextStyle(fontSize: 12, color: _c.textMuted), overflow: TextOverflow.ellipsis),
                  if (booth.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    AppChip.label('BOOTH $booth'),
                  ],
                ]),
              ),
              const SizedBox(width: 8),
              Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 18, color: _c.textMuted),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _toggleTargetMet(target, event, lep),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: isMet ? _c.success.withValues(alpha: 0.12) : _c.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: isMet ? _c.success : _c.border, width: 1.5),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 13, color: isMet ? _c.success : _c.textMuted),
                    const SizedBox(width: 5),
                    Text(isMet ? 'MET' : 'MARK MET', style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6,
                        color: isMet ? _c.success : _c.textMuted)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        if (isExpanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: _c.surfaceAlt,
              border: Border(top: BorderSide(color: _c.border)),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusCard)),
            ),
            child: Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => showLogInteractionSheet(context,
                      contactId: contactId, initialMode: event.name,
                      onSaved: () => lep.refresh()),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                  label: const Text('LOG INTERACTION', maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false),
                  style: FilledButton.styleFrom(
                    backgroundColor: _c.accent,
                    foregroundColor: (_c.isDark ? _c.textPrimary : _c.background),
                    minimumSize: const Size.fromHeight(42),
                    iconSize: 14,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (contactId != null && contactId.isNotEmpty) {
                      context.push('/contacts/$contactId');
                    } else {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => LiveTargetPersonScreen(event: event, target: target)));
                    }
                  },
                  icon: Icon(Icons.person_outline_rounded, size: 14, color: _c.accent),
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
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _deleteTarget(target, event, lep),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _c.destructive,
                  side: BorderSide(color: _c.destructive.withValues(alpha: 0.4)),
                  minimumSize: const Size(42, 42),
                  maximumSize: const Size(42, 42),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Icon(Icons.delete_outline_rounded, size: 18, color: _c.destructive),
              ),
            ]),
          ),
      ]),
    );
  }

  // ── Scanned contacts ───────────────────────────────────────────────────────

  Widget _buildScannedList(LiveEventProvider lep) {
    final filtered = lep.scannedContacts.where((c) {
      if (_scannedSearch.isEmpty) return true;
      final contact = c['contact'] as Map<String, dynamic>?;
      if (contact == null) return false;
      final q = _scannedSearch.toLowerCase();
      final first = (contact['first_name'] as String? ?? '').toLowerCase();
      final last = (contact['last_name'] as String? ?? '').toLowerCase();
      final company = (contact['company_name'] as String? ?? '').toLowerCase();
      return first.contains(q) || last.contains(q) || company.contains(q);
    }).toList()
      ..sort((a, b) {
        final ac = a['contact'] as Map<String, dynamic>? ?? {};
        final bc = b['contact'] as Map<String, dynamic>? ?? {};
        final aName = '${ac['first_name'] ?? ''} ${ac['last_name'] ?? ''}'.trim().toLowerCase();
        final bName = '${bc['first_name'] ?? ''} ${bc['last_name'] ?? ''}'.trim().toLowerCase();
        return aName.compareTo(bName);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        TextField(
          style: TextStyle(fontSize: 13, color: _c.textPrimary),
          cursorColor: _c.accent,
          onChanged: (v) => setState(() => _scannedSearch = v),
          decoration: InputDecoration(
            hintText: 'Search scanned contacts…',
            hintStyle: TextStyle(fontSize: 13, color: _c.textMuted),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(Icons.search_rounded, size: 18, color: _c.accent),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            filled: true, fillColor: _c.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.accent)),
          ),
        ),
        const SizedBox(height: 14),
        if (lep.scannedContacts.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Center(child: Column(children: [
              Icon(Icons.qr_code_scanner_rounded, color: _c.accent, size: 32),
              const SizedBox(height: 10),
              Text('No contacts scanned yet.', style: TextStyle(color: _c.textMuted, fontSize: 13)),
            ])),
          )
        else if (filtered.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.search_off_rounded, color: _c.accent, size: 20),
              const SizedBox(width: 12),
              Text('No scanned contacts match.', style: TextStyle(fontSize: 13, color: _c.textMuted)),
            ]),
          )
        else
          ...filtered.map((capture) => _buildScannedCard(capture)),
      ],
    );
  }

  Widget _buildScannedCard(Map<String, dynamic> capture) {
    final contact = capture['contact'] as Map<String, dynamic>? ?? {};
    final contactId = contact['id'] as String? ?? '';
    final firstName = contact['first_name'] as String? ?? '';
    final lastName = contact['last_name'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();
    final company = contact['company_name'] as String? ?? '';
    final jobTitle = contact['job_title'] as String? ?? '';
    final email = contact['email'] as String? ?? '';
    final phone = contact['phone'] as String? ?? '';
    final createdAt = capture['created_at'] as String?;
    final initials = (firstName.isNotEmpty ? firstName[0] : '') + (lastName.isNotEmpty ? lastName[0] : '');
    final isExpanded = _expandedScannedIds.contains(contactId);

    String timeAgo = '';
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt).toLocal();
        final diff = DateTime.now().difference(date);
        if (diff.isNegative || diff.inSeconds < 60) timeAgo = 'just now';
        else if (diff.inMinutes < 60) timeAgo = '${diff.inMinutes}m ago';
        else if (diff.inHours < 24) timeAgo = '${diff.inHours}h ago';
        else timeAgo = '${diff.inDays}d ago';
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        radius: AppTheme.radiusCard,
        elevated: isExpanded,
        child: Column(children: [
          InkWell(
            onTap: contactId.isEmpty ? null : () => setState(() {
              if (isExpanded) _expandedScannedIds.remove(contactId);
              else _expandedScannedIds.add(contactId);
            }),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusCard),
              bottom: isExpanded ? Radius.zero : Radius.circular(AppTheme.radiusCard),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _c.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _c.accent),
                  ),
                  child: Text(initials.toUpperCase(),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _c.accent)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(fullName.isNotEmpty ? fullName : 'Unknown',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _c.textPrimary)),
                    if (jobTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(jobTitle, style: TextStyle(fontSize: 13, color: _c.textSecondary)),
                    ],
                    if (company.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(company, style: TextStyle(fontSize: 12, color: _c.textMuted)),
                    ],
                  ]),
                ),
                if (timeAgo.isNotEmpty)
                  Text(timeAgo, style: TextStyle(fontSize: 11, color: _c.textMuted, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
          if (isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: _c.surfaceAlt,
                border: Border(top: BorderSide(color: _c.border)),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusCard)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (email.isNotEmpty) ...[
                  Row(children: [
                    Icon(Icons.email_outlined, size: 16, color: _c.accent),
                    const SizedBox(width: 8),
                    Expanded(child: Text(email, style: TextStyle(fontSize: 13, color: _c.textSecondary))),
                  ]),
                  const SizedBox(height: 8),
                ],
                if (phone.isNotEmpty) ...[
                  Row(children: [
                    Icon(Icons.phone_outlined, size: 16, color: _c.accent),
                    const SizedBox(width: 8),
                    Expanded(child: Text(phone, style: TextStyle(fontSize: 13, color: _c.textSecondary))),
                  ]),
                  const SizedBox(height: 12),
                ],
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: FilledButton.icon(
                      onPressed: () => showLogInteractionSheet(context, contactId: contactId),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                      label: const Text('LOG INTERACTION'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _c.accent,
                        foregroundColor: (_c.isDark ? _c.textPrimary : _c.background),
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: contactId.isEmpty ? null : () => context.push('/contacts/$contactId'),
                      icon: Icon(Icons.person_outline_rounded, size: 14, color: _c.accent),
                      label: const Text('PROFILE'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _c.textPrimary,
                        side: BorderSide(color: _c.border),
                        minimumSize: const Size.fromHeight(42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
        ]),
      ),
    );
  }

  // ── Companies ──────────────────────────────────────────────────────────────

  Widget _buildCompaniesList(Event event, LiveEventProvider lep) {
    if (lep.liveTargets.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        child: Center(child: Column(children: [
          Icon(Icons.business_outlined, color: _c.accent, size: 32),
          const SizedBox(height: 10),
          Text('No target companies for this event.', style: TextStyle(color: _c.textMuted, fontSize: 13)),
        ])),
      );
    }
    return Column(
      children: [
        for (int i = 0; i < lep.liveTargets.length; i++) ...[
          _buildCompanyCard(lep.liveTargets[i], event),
          if (i < lep.liveTargets.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildCompanyCard(Map<String, dynamic> target, Event event) {
    final companyName = target['company_name'] as String? ?? '';
    final booth = target['booth'] as String? ?? '';
    final priority = target['priority'] as String? ?? 'medium';
    final initials = companyName.length >= 2 ? companyName.substring(0, 2).toUpperCase() : companyName.toUpperCase();

    return AppCard(
      radius: AppTheme.radiusCard,
      borderColor: priority == 'high'
          ? _c.destructive.withValues(alpha: 0.35)
          : priority == 'medium'
              ? _c.accent.withValues(alpha: 0.20)
              : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _c.accentSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _c.border),
            ),
            child: Text(initials, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _c.accent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(companyName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _c.textPrimary)),
              if (booth.isNotEmpty) ...[const SizedBox(height: 4), AppChip.label('BOOTH $booth')],
            ]),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              final targetId = target['id'] as String? ?? '';
              if (targetId.isEmpty) return;
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EventTargetScreen(event: event, targetId: targetId)));
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _c.accent,
              side: BorderSide(color: _c.accent.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
            ),
            child: const Text('VIEW'),
          ),
        ]),
      ),
    );
  }
}

// ── Pulsing dot ───────────────────────────────────────────────────────────────

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
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(width: 7, height: 7, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    );
  }
}

// ── Contact picker sheet ──────────────────────────────────────────────────────

class _ContactPickerSheet extends StatefulWidget {
  final List<dynamic> contacts;
  final ExonoColors colors;
  const _ContactPickerSheet({required this.contacts, required this.colors});
  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final filtered = widget.contacts.where((contact) {
      final name = '${contact.firstName} ${contact.lastName ?? ''}'.toLowerCase();
      final company = (contact.company?.name ?? '').toLowerCase();
      final q = _search.toLowerCase();
      return q.isEmpty || name.contains(q) || company.contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 36, height: 4,
          decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add Contact as Target',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _search = v),
              style: TextStyle(fontSize: 13, color: c.textPrimary),
              cursorColor: c.accent,
              decoration: InputDecoration(
                hintText: 'Search contacts…',
                hintStyle: TextStyle(fontSize: 13, color: c.textMuted),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(Icons.search_rounded, size: 18, color: c.accent),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true, fillColor: c.surfaceAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.accent)),
              ),
            ),
          ]),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('No contacts found.', style: TextStyle(color: c.textMuted, fontSize: 13)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => Divider(color: c.border.withValues(alpha: 0.5), height: 1),
                  itemBuilder: (_, i) {
                    final contact = filtered[i];
                    final name = '${contact.firstName} ${contact.lastName ?? ''}'.trim();
                    final company = contact.company?.name ?? '';
                    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text(initials,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.accent))),
                      ),
                      title: Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
                      subtitle: company.isNotEmpty
                          ? Text(company, style: TextStyle(fontSize: 11, color: c.textMuted))
                          : null,
                      onTap: () => Navigator.of(context).pop({
                        'company_id': contact.companyId,
                        'company_name': company,
                        'contact_id': contact.id,
                        'contact_name': name,
                        'job_title': contact.jobTitle ?? '',
                      }),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
