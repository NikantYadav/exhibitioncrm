import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_feedback.dart';
import '../models/event.dart';
import '../providers/live_event_provider.dart';
import '../providers/sync_provider.dart';
import '../services/api_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_filter_row.dart';
import '../widgets/app_header.dart';
import '../widgets/app_input.dart';
import '../widgets/app_section_label.dart';
import 'app_shell.dart';
import 'target_company_prep_screen.dart';
import 'log_interaction_screen.dart';
import '../utils/screen_logger.dart';

/// Standalone live event floor screen — the full workspace shown when an event
/// is ongoing.  Launched via the home auto-redirect and the LiveBar tap.
class LiveHomeScreen extends StatefulWidget {
  const LiveHomeScreen({super.key});

  @override
  State<LiveHomeScreen> createState() => _LiveHomeScreenState();
}

class _LiveHomeScreenState extends State<LiveHomeScreen> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  // Local overrides & UI state
  final Map<String, bool> _targetContactMetOverrides = {};
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
    showAppToast(context, msg);
  }

  bool _isTargetContactMet(Map<String, dynamic> t) {
    final contactId = t['contact_id'] as String? ?? '';
    return _targetContactMetOverrides.containsKey(contactId)
        ? _targetContactMetOverrides[contactId]!
        : (t['status'] as String?) == 'met';
  }

  List<Map<String, dynamic>> _filteredTargetContacts(List<Map<String, dynamic>> contacts) {
    final q = _targetSearch.toLowerCase();
    return contacts.where((t) {
      final name = (t['name'] as String? ?? '').toLowerCase();
      final company = (t['company_name'] as String? ?? '').toLowerCase();
      final matchesSearch = q.isEmpty || name.contains(q) || company.contains(q);
      final matchesFilter = switch (_targetFilter) {
        'Met' => _isTargetContactMet(t),
        'Not Met' => !_isTargetContactMet(t),
        _ => true,
      };
      return matchesSearch && matchesFilter;
    }).toList()
      ..sort((a, b) {
        final aName = (a['name'] as String? ?? '').toLowerCase();
        final bName = (b['name'] as String? ?? '').toLowerCase();
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
    } on UnauthorizedException { rethrow; } catch (_) {
      lep.revertGoal(goal);
    }
  }

  Future<void> _incrementGoal(Map<String, dynamic> goal, Event event, LiveEventProvider lep) async {
    final newVal = ((goal['current'] as int) + 1).clamp(0, goal['total'] as int);
    final updated = {...goal, 'current': newVal};
    lep.updateGoalLocally(updated);
    try {
      await ApiService.updateEventGoal(event.id, goal['id'] as String, {'current': newVal});
    } on UnauthorizedException { rethrow; } catch (_) {
      lep.revertGoal(goal);
    }
  }

  Future<void> _deleteGoal(Map<String, dynamic> goal, Event event, LiveEventProvider lep) async {
    lep.removeGoalLocally(goal['id'] as String);
    try {
      await ApiService.deleteEventGoal(event.id, goal['id'] as String);
    } on UnauthorizedException { rethrow; } catch (_) {
      lep.addGoalLocally(goal);
      _toast('Failed to delete goal');
    }
  }

  Future<void> _showAddGoalSheet(Event event, LiveEventProvider lep) async {
    final labelCtrl = TextEditingController();
    final totalCtrl = TextEditingController(text: '1');
    bool isCheckbox = false;
    final c = _c;

    await showAppSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          top: false,
          child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Goal', style: context.theme.typography.lg.copyWith(fontWeight: FontWeight.w700, color: context.theme.colors.foreground)),
              const SizedBox(height: 20),
              AppInput(
                controller: labelCtrl,
                autofocus: true,
                hint: isCheckbox ? 'e.g. Visit the sponsor booth' : 'e.g. Meet 5 VCs',
              ),
              const SizedBox(height: 16),
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: context.theme.colors.border),
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
                        child: Center(child: Text('Checkbox', style: context.theme.typography.sm.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isCheckbox ? (c.isDark ? context.theme.colors.foreground : Colors.white) : context.theme.colors.mutedForeground))),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => isCheckbox = false),
                        behavior: HitTestBehavior.opaque,
                        child: Center(child: Text('Counted', style: context.theme.typography.sm.copyWith(
                            fontWeight: FontWeight.w600,
                            color: !isCheckbox ? (c.isDark ? context.theme.colors.foreground : Colors.white) : context.theme.colors.mutedForeground))),
                      ),
                    ),
                  ]),
                ]),
              ),
              if (!isCheckbox) ...[
                const SizedBox(height: 12),
                AppInput(
                  controller: totalCtrl,
                  keyboardType: TextInputType.number,
                  hint: 'Target count',
                ),
              ],
              const SizedBox(height: 20),
              AppButton(
                label: 'ADD GOAL',
                fullWidth: true,
                variant: ButtonVariant.primary,
                onPressed: () async {
                  final label = labelCtrl.text.trim();
                  if (label.isEmpty) return;
                  final total = isCheckbox ? 0 : (int.tryParse(totalCtrl.text.trim()) ?? 1);
                  Navigator.pop(ctx);
                  try {
                    final newGoal = await ApiService.createEventGoal(event.id, label, total);
                    if (mounted) lep.addGoalLocally(newGoal);
                  } on UnauthorizedException { rethrow; } catch (_) {
                    if (mounted) _toast('Failed to add goal');
                  }
                },
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  // ── Target actions ─────────────────────────────────────────────────────────

  Future<void> _toggleTargetContactMet(Map<String, dynamic> target, Event event, LiveEventProvider lep) async {
    final contactId = target['contact_id'] as String? ?? '';
    if (contactId.isEmpty) return;
    final nowMet = !_isTargetContactMet(target);
    setState(() {
      _targetContactMetOverrides[contactId] = nowMet;
      if (nowMet) _expandedTargetIds.remove(contactId);
    });
    try {
      await ApiService.updateTargetContactStatus(event.id, contactId, nowMet ? 'met' : 'not_contacted');
      lep.updateTargetContactStatusLocally(contactId, nowMet ? 'met' : 'not_contacted');
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) {
        setState(() => _targetContactMetOverrides.remove(contactId));
        _toast('Failed to update target status');
      }
    }
  }

  Future<void> _markTargetContactMet(String contactId, Event event, LiveEventProvider lep) async {
    final isAlreadyTarget = lep.targetContacts.any((t) => t['contact_id'] == contactId);
    if (!isAlreadyTarget) return;
    final alreadyMet = _targetContactMetOverrides[contactId] ??
        (lep.targetContacts.firstWhere((t) => t['contact_id'] == contactId,
            orElse: () => {})['status'] as String?) == 'met';
    if (alreadyMet) return;
    setState(() {
      _targetContactMetOverrides[contactId] = true;
      _expandedTargetIds.remove(contactId);
    });
    try {
      await ApiService.updateTargetContactStatus(event.id, contactId, 'met');
      lep.updateTargetContactStatusLocally(contactId, 'met');
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) setState(() => _targetContactMetOverrides.remove(contactId));
    }
  }

  Future<void> _addContactAsTarget(Event event, LiveEventProvider lep) async {
    final contacts = await context.read<SyncProvider>().contacts.watchAllWithCompany().first;
    if (!mounted) return;

    final existingContactIds = lep.targetContacts
        .map((t) => t['contact_id'] as String?)
        .whereType<String>()
        .toSet();

    final eligible = contacts
        .where((c) => !existingContactIds.contains(c.id))
        .toList();

    if (eligible.isEmpty) {
      _toast('All your contacts are already in the target list.');
      return;
    }

    final picked = await showAppSheet<dynamic>(
      context: context,
      builder: (_) => _ContactPickerSheet(contacts: eligible, colors: _c),
    );

    if (picked == null || !mounted) return;
    final contactId = picked['contact_id'] as String?;
    final contactName = picked['contact_name'] as String?;
    final companyName = picked['company_name'] as String? ?? '';

    if (contactId == null) {
      _toast('Contact has no ID — cannot add.');
      return;
    }

    try {
      await ApiService.addContactToEvent(event.id, contactId);
      lep.addTargetContactLocally({
        'contact_id': contactId,
        'name': contactName ?? '',
        'job_title': picked['job_title'] ?? '',
        'company_name': companyName,
        'status': 'not_contacted',
        'notes': '',
        'talking_points': '',
      });
      _toast('${contactName ?? companyName} added to targets.');
    } on UnauthorizedException { rethrow; } catch (_) {
      _toast('Failed to add target.');
    }
  }

  Future<void> _deleteTargetContact(Map<String, dynamic> target, Event event, LiveEventProvider lep) async {
    final contactId = target['contact_id'] as String? ?? '';
    final name = target['name'] as String? ?? 'Target';

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Remove Target',
      message: 'Remove $name from targets?',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiService.removeContactFromEvent(event.id, contactId);
      lep.removeTargetContactLocally(contactId);
      _expandedTargetIds.remove(contactId);
    } on UnauthorizedException { rethrow; } catch (_) {
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
            if (mounted && context.canPop()) { context.pop(); }
            else if (mounted) { context.go('/'); }
          });
          return const SizedBox.shrink();
        }

        return Scaffold(
          backgroundColor: context.theme.colors.background,
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
                  actionWidget: AppHeaderActionButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => context.go('/'),
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
    final targetsLeft = lep.targetContacts.where((t) => !_isTargetContactMet(t)).length;
    final goalsLeft = lep.liveGoals.where((g) => (g['status'] as String?) != 'completed').length;

    final location = event.location ?? '';

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
            _buildStatGrid(scanned, targetsLeft, goalsLeft),
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
            Text('LIVE NOW', style: context.theme.typography.xs.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6, color: _c.destructive)),
          ]),
          const SizedBox(height: 14),
          Text(event.name, style: context.theme.typography.xl.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6, color: context.theme.colors.foreground, height: 1.1)),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.location_on_outlined, size: 14, color: _c.accent),
              const SizedBox(width: 6),
              Expanded(child: Text(location,
                  style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildStatGrid(int scanned, int targetsLeft, int goalsLeft) {
    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(16),
      radius: 14,
      child: Row(children: [
        Expanded(child: _statColumn(Icons.qr_code_scanner_rounded, '$scanned', 'SCANNED')),
        Container(width: 1, height: 48, color: context.theme.colors.border.withValues(alpha: 0.3)),
        Expanded(child: _statColumn(Icons.people_outline_rounded, '$targetsLeft', 'TARGETS LEFT')),
        Container(width: 1, height: 48, color: context.theme.colors.border.withValues(alpha: 0.3)),
        Expanded(child: _statColumn(Icons.flag_outlined, '$goalsLeft', 'GOALS LEFT')),
      ]),
    );
  }

  Widget _statColumn(IconData icon, String value, String label) {
    return SizedBox(
      height: 80,
      child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: _c.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: _c.accent),
        ),
        const SizedBox(height: 6),
        Text(value, style: context.theme.typography.xl.copyWith(fontWeight: FontWeight.w800, color: context.theme.colors.foreground, height: 1)),
        const SizedBox(height: 3),
        Text(label, style: context.theme.typography.xs.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4, color: context.theme.colors.mutedForeground),
            textAlign: TextAlign.center, maxLines: 2),
      ],
    ));
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
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _c.accent.withValues(alpha: 0.5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, size: 12, color: _c.accent),
                  const SizedBox(width: 4),
                  Text('ADD GOAL', style: context.theme.typography.xs.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.0, color: _c.accent)),
                ]),
              ),
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
                  style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground, height: 1.4))),
            ]),
          )
        else
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(children: [
              for (int i = 0; i < lep.liveGoals.length; i++)
                Container(
                  decoration: i.isOdd
                      ? BoxDecoration(color: _c.surfaceAlt, borderRadius: BorderRadius.circular(10))
                      : null,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildGoalRow(lep.liveGoals[i], event, lep),
                ),
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
        showAppSheet(
          context: context,
          builder: (_) => SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: context.theme.colors.border, borderRadius: BorderRadius.circular(2))),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () { Navigator.pop(context); _deleteGoal(goal, event, lep); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Icon(Icons.delete_outline_rounded, color: _c.destructive),
                    const SizedBox(width: 12),
                    Text('Delete goal', style: context.theme.typography.lg.copyWith(color: _c.destructive)),
                  ]),
                ),
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
                    border: Border.all(color: isComplete ? _c.success : context.theme.colors.border, width: 1.5),
                  ),
                  child: isComplete
                      ? Icon(Icons.check_rounded, size: 11, color: (_c.isDark ? context.theme.colors.foreground : _c.background))
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(goal['label'] as String, style: context.theme.typography.sm.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isComplete ? _c.success : context.theme.colors.foreground,
                  decoration: isComplete ? TextDecoration.lineThrough : null,
                  decorationColor: _c.success))),
              Icon(Icons.more_horiz_rounded, size: 14, color: context.theme.colors.mutedForeground),
              const SizedBox(width: 6),
              if (isCheckbox)
                GestureDetector(
                  onTap: () => _toggleCheckboxGoal(goal, event, lep),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isComplete ? _c.success.withValues(alpha: 0.10) : _c.accentSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(isComplete ? 'DONE' : 'MARK DONE', style: context.theme.typography.xs.copyWith(
                          fontWeight: FontWeight.w700, letterSpacing: 0.4,
                          color: isComplete ? _c.success : _c.accent)),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: isComplete ? null : () => _incrementGoal(goal, event, lep),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
                        Text('$current / $total', style: context.theme.typography.sm.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isComplete ? _c.success : _c.accent)),
                      ]),
                    ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _tabItem('targets', 'Targets', '${lep.targetContacts.length}'),
            _tabItem('scanned', 'Scanned', '${lep.scannedContacts.length}'),
            _tabItem('companies', 'Companies', '${lep.liveTargets.length}'),
          ],
        ),
        Container(height: 1, color: context.theme.colors.border),
        const SizedBox(height: 16),
        if (_activeTab == 'targets')
          _buildLiveTargetContactsList(event, lep)
        else if (_activeTab == 'scanned')
          _buildScannedList(event, lep)
        else
          _buildCompaniesList(event, lep),
      ],
    );
  }

  Widget _tabItem(String tab, String label, String count) {
    final isActive = _activeTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? _c.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            label,
            style: context.theme.typography.sm.copyWith(
              fontWeight: FontWeight.w700,
              color: isActive ? _c.accent : context.theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isActive ? _c.accent : _c.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count,
              style: context.theme.typography.xs.copyWith(
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : context.theme.colors.mutedForeground,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildLiveTargetContactsList(Event event, LiveEventProvider lep) {
    final visible = _filteredTargetContacts(lep.targetContacts);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInput(
          controller: _targetSearchCtrl,
          hint: 'Search people, companies…',
          onChanged: (v) => setState(() => _targetSearch = v),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: _c.accent),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AppFilterRow(
                filters: const ['All', 'Not Met', 'Met'],
                selected: _targetFilter,
                onSelect: (f) => setState(() => _targetFilter = f),
                style: AppFilterRowStyle.filled,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _addContactAsTarget(event, lep),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _c.accentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_add_outlined, size: 13, color: _c.accent),
                    const SizedBox(width: 5),
                    Text('ADD', style: context.theme.typography.xs.copyWith(
                        fontWeight: FontWeight.w700, letterSpacing: 0.8, color: _c.accent)),
                  ]),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (lep.targetContacts.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Center(child: Column(children: [
              Icon(Icons.people_outline_rounded, color: _c.accent, size: 32),
              const SizedBox(height: 10),
              Text('No target contacts yet.', style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
            ])),
          )
        else if (visible.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.search_off_rounded, color: _c.accent, size: 20),
              const SizedBox(width: 12),
              Text('No targets match.', style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
            ]),
          )
        else
          Column(children: [
            for (int i = 0; i < visible.length; i++) ...[
              _buildTargetContactCard(visible[i], i + 1, event, lep),
              if (i < visible.length - 1) const SizedBox(height: 8),
            ],
          ]),
      ],
    );
  }

  Widget _buildTargetContactCard(Map<String, dynamic> target, int rank, Event event, LiveEventProvider lep) {
    final contactId = target['contact_id'] as String? ?? '';
    final name = target['name'] as String? ?? '';
    final jobTitle = target['job_title'] as String? ?? '';
    final companyName = target['company_name'] as String? ?? '';
    final isMet = _isTargetContactMet(target);
    final isExpanded = _expandedTargetIds.contains(contactId);
    final initials = name.trim().split(RegExp(r'\s+')).take(2).map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase();

    return AppCard(
      radius: AppTheme.radiusCard,
      elevated: isExpanded,
      child: Column(children: [
        GestureDetector(
          onTap: contactId.isEmpty ? null : () => setState(() {
            if (isExpanded) { _expandedTargetIds.remove(contactId); }
            else { _expandedTargetIds.add(contactId); }
          }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppAvatar(initials: initials.isNotEmpty ? initials : '?', size: 40, done: isMet),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name.isNotEmpty ? name : 'Unknown', style: context.theme.typography.lg.copyWith(
                      fontWeight: FontWeight.w700, letterSpacing: -0.2,
                      color: isMet ? context.theme.colors.mutedForeground : context.theme.colors.foreground)),
                  const SizedBox(height: 3),
                  Text([if (jobTitle.isNotEmpty) jobTitle, if (companyName.isNotEmpty) companyName].join(', '),
                      style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground), overflow: TextOverflow.ellipsis),
                ]),
              ),
              const SizedBox(width: 8),
              Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 18, color: context.theme.colors.mutedForeground),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _toggleTargetContactMet(target, event, lep),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: isMet ? _c.success.withValues(alpha: 0.12) : _c.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: isMet ? _c.success : context.theme.colors.border, width: 1.5),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 13, color: isMet ? _c.success : context.theme.colors.mutedForeground),
                    const SizedBox(width: 5),
                    Text(isMet ? 'MET' : 'MARK MET', style: context.theme.typography.xs.copyWith(
                        fontWeight: FontWeight.w800, letterSpacing: 0.6,
                        color: isMet ? _c.success : context.theme.colors.mutedForeground)),
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
              border: Border(top: BorderSide(color: context.theme.colors.border)),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusCard)),
            ),
            child: Row(children: [
              Expanded(
                child: AppButton(
                  label: 'LOG INTERACTION',
                  prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                  variant: ButtonVariant.branded,
                  onPressed: () => showLogInteractionSheet(context,
                      contactId: contactId.isNotEmpty ? contactId : null,
                      initialMode: event.name,
                      onSaved: () => lep.refresh(),
                      onMarkedMet: () => _markTargetContactMet(contactId, event, lep)),
                ),
              ),
              const SizedBox(width: 8),
              AppButton(
                variant: ButtonVariant.outline,
                onPressed: contactId.isNotEmpty ? () => context.push('/contacts/$contactId') : null,
                child: Icon(Icons.person_outline_rounded, size: 18, color: _c.accent),
              ),
              const SizedBox(width: 8),
              AppButton(
                variant: ButtonVariant.outline,
                onPressed: () => _deleteTargetContact(target, event, lep),
                child: Icon(Icons.delete_outline_rounded, size: 18, color: _c.destructive),
              ),
            ]),
          ),
      ]),
    );
  }

  // ── Scanned contacts ───────────────────────────────────────────────────────

  Widget _buildScannedList(Event event, LiveEventProvider lep) {
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
        AppInput(
          hint: 'Search scanned contacts…',
          onChanged: (v) => setState(() => _scannedSearch = v),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: _c.accent),
        ),
        const SizedBox(height: 14),
        if (lep.scannedContacts.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Center(child: Column(children: [
              Icon(Icons.qr_code_scanner_rounded, color: _c.accent, size: 32),
              const SizedBox(height: 10),
              Text('No contacts scanned yet.', style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
            ])),
          )
        else if (filtered.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.search_off_rounded, color: _c.accent, size: 20),
              const SizedBox(width: 12),
              Text('No scanned contacts match.', style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
            ]),
          )
        else
          ...filtered.map((capture) => _buildScannedCard(capture, event, lep)),
      ],
    );
  }

  Widget _buildScannedCard(Map<String, dynamic> capture, Event event, LiveEventProvider lep) {
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
        if (diff.isNegative || diff.inSeconds < 60) { timeAgo = 'just now'; }
        else if (diff.inMinutes < 60) { timeAgo = '${diff.inMinutes}m ago'; }
        else if (diff.inHours < 24) { timeAgo = '${diff.inHours}h ago'; }
        else { timeAgo = '${diff.inDays}d ago'; }
      } on UnauthorizedException { rethrow; } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        radius: AppTheme.radiusCard,
        elevated: isExpanded,
        child: Column(children: [
          GestureDetector(
            onTap: contactId.isEmpty ? null : () => setState(() {
              if (isExpanded) { _expandedScannedIds.remove(contactId); }
              else { _expandedScannedIds.add(contactId); }
            }),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                AppAvatar(initials: initials),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(fullName.isNotEmpty ? fullName : 'Unknown',
                        style: context.theme.typography.lg.copyWith(fontWeight: FontWeight.w600, color: context.theme.colors.foreground)),
                    if (jobTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(jobTitle, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
                    ],
                    if (company.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(company, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
                    ],
                  ]),
                ),
                if (timeAgo.isNotEmpty)
                  Text(timeAgo, style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
          if (isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: _c.surfaceAlt,
                border: Border(top: BorderSide(color: context.theme.colors.border)),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusCard)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (email.isNotEmpty) ...[
                  Row(children: [
                    Icon(Icons.email_outlined, size: 16, color: _c.accent),
                    const SizedBox(width: 8),
                    Expanded(child: Text(email, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground))),
                  ]),
                  const SizedBox(height: 8),
                ],
                if (phone.isNotEmpty) ...[
                  Row(children: [
                    Icon(Icons.phone_outlined, size: 16, color: _c.accent),
                    const SizedBox(width: 8),
                    Expanded(child: Text(phone, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground))),
                  ]),
                  const SizedBox(height: 12),
                ],
                Row(children: [
                  Expanded(
                    child: AppButton(
                      label: 'LOG INTERACTION',
                      prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                      variant: ButtonVariant.branded,
                      onPressed: () => showLogInteractionSheet(context,
                          contactId: contactId,
                          onMarkedMet: () => _markTargetContactMet(contactId, event, lep)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    variant: ButtonVariant.outline,
                    onPressed: contactId.isEmpty ? null : () => context.push('/contacts/$contactId'),
                    child: Icon(Icons.person_outline_rounded, size: 18, color: _c.accent),
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
          Text('No target companies for this event.', style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
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
              border: Border.all(color: context.theme.colors.border),
            ),
            child: Text(initials, style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w700, color: _c.accent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(companyName, style: context.theme.typography.lg.copyWith(fontWeight: FontWeight.w700, color: context.theme.colors.foreground)),
              if (booth.isNotEmpty) ...[const SizedBox(height: 4), AppChip.label('BOOTH $booth')],
            ]),
          ),
          const SizedBox(width: 8),
          AppButton(
            label: 'VIEW',
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            onPressed: () {
              final targetId = target['id'] as String? ?? '';
              if (targetId.isEmpty) return;
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => TargetCompanyPrepScreen(event: event, targetId: targetId)));
            },
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

    return SafeArea(
      top: false,
      child: SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 36, height: 4,
          decoration: BoxDecoration(color: context.theme.colors.border, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add Contact as Target',
                style: context.theme.typography.lg.copyWith(fontWeight: FontWeight.w700, color: context.theme.colors.foreground)),
            const SizedBox(height: 12),
            AppInput(
              autofocus: true,
              hint: 'Search contacts…',
              onChanged: (v) => setState(() => _search = v),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: c.accent),
            ),
          ]),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('No contacts found.', style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final contact = filtered[i];
                    final name = '${contact.firstName} ${contact.lastName ?? ''}'.trim();
                    final company = contact.company?.name ?? '';
                    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop({
                          'company_id': contact.companyId,
                          'company_name': company,
                          'contact_id': contact.id,
                          'contact_name': name,
                          'job_title': contact.jobTitle ?? '',
                        }),
                        child: AppCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            AppAvatar(initials: initials, size: 40),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(name, style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w600, color: context.theme.colors.foreground)),
                                if (company.isNotEmpty)
                                  Text(company, style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground)),
                              ],
                            )),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    ));
  }
}
