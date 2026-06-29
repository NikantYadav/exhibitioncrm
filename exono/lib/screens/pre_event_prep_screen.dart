import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../utils/safe_area_insets.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../db/app_database.dart';
import '../models/event.dart';
import '../providers/sync_provider.dart';
import '../repositories/contact_events_repository.dart';
import '../repositories/target_companies_repository.dart';
import '../services/api_service.dart';
import '../services/company_name_resolver.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_header.dart';
import '../widgets/app_input.dart';
import '../widgets/add_target_company_sheet.dart';
import '../widgets/create_company_sheet.dart';
import '../widgets/skeleton_loader.dart';
import 'target_company_prep_screen.dart';
import '../utils/screen_logger.dart';
import '../models/chat_mention.dart';
import '../widgets/exo_dock_bar.dart';

class PreEventPrepScreen extends StatefulWidget {
  final Event event;
  final ValueChanged<int>? onNavigateTab;

  const PreEventPrepScreen({super.key, required this.event, this.onNavigateTab});

  @override
  State<PreEventPrepScreen> createState() => _PreEventPrepScreenState();
}

class _PreEventPrepScreenState extends State<PreEventPrepScreen> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  static bool _isValidGoalLabel(String label) => label.length <= 200;

  late final TargetCompaniesRepository _targetsRepo;
  late final ContactEventsRepository _contactEventsRepo;
  late final SyncProvider _sync;

  final _boothCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sync = context.read<SyncProvider>();
    _targetsRepo = _sync.targetCompanies;
    _contactEventsRepo = _sync.contactEvents;
  }

  @override
  void dispose() {
    _boothCtrl.dispose();
    super.dispose();
  }

  Future<void> _addGoal() async {
    final labelCtrl = TextEditingController();
    final totalCtrl = TextEditingController(text: '1');
    // Persistent focus node for the label field. The Counted/Checkbox toggle is
    // a tap *outside* the field, which fires AppInput's onTapOutside -> unfocus
    // and dismisses the keyboard. We hold the node so the toggle can immediately
    // re-request focus, keeping the keyboard up.
    final labelFocus = FocusNode();
    bool isCheckbox = false;

    await showAppSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Add Goal', style: context.theme.typography.lg.copyWith(fontWeight: FontWeight.w700, color: context.theme.colors.foreground)),
              const SizedBox(height: 20),
              AppInput(
                controller: labelCtrl,
                focusNode: labelFocus,
                autofocus: true,
                hintText: isCheckbox ? 'e.g. Visit the sponsor booth' : 'e.g. Meet 5 VCs',
              ),
              const SizedBox(height: 16),
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: _c.surfaceAlt,
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
                        decoration: BoxDecoration(color: _c.accent, borderRadius: BorderRadius.circular(999)),
                      ),
                    ),
                  ),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setModalState(() => isCheckbox = true);
                          _keepLabelFocus(labelFocus);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Center(child: Text('Checkbox',
                            style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w600,
                                color: isCheckbox ? (context.theme.colors.primaryForeground) : context.theme.colors.mutedForeground))),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setModalState(() => isCheckbox = false);
                          _keepLabelFocus(labelFocus);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Center(child: Text('Counted',
                            style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w600,
                                color: !isCheckbox ? (context.theme.colors.primaryForeground) : context.theme.colors.mutedForeground))),
                      ),
                    ),
                  ]),
                ]),
              ),
              // Keep the target-count field permanently in the tree and just
              // collapse its height when in Checkbox mode. Conditionally
              // adding/removing it reshapes the children list, which makes the
              // label field above lose focus and dismisses the keyboard on
              // toggle. AnimatedSize avoids that.
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: isCheckbox
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: AppInput(
                          controller: totalCtrl,
                          keyboardType: TextInputType.number,
                          hintText: 'Target count',
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'ADD GOAL',
                fullWidth: true,
                variant: ButtonVariant.primary,
                onPressed: () async {
                  final label = labelCtrl.text.trim();
                  if (label.isEmpty) return;
                  if (!_isValidGoalLabel(label)) {
                    showAppToast(ctx, 'Goal label must be 200 characters or fewer');
                    return;
                  }
                  int total;
                  if (isCheckbox) {
                    total = 0;
                  } else {
                    final parsed = int.tryParse(totalCtrl.text.trim());
                    if (parsed == null || parsed <= 0) {
                      showAppToast(ctx, 'Please enter a valid target count greater than 0');
                      return;
                    }
                    total = parsed;
                  }
                  Navigator.pop(ctx);
                  try {
                    await ApiService.createEventGoal(widget.event.id, label, total);
                    await _sync.eventGoals.catchUp();
                  } on UnauthorizedException { rethrow; } catch (_) {}
                },
              ),
            ]),
          ),
        ),
      ),
    );
    // Dispose after the next frame: when the sheet is dismissed its exit
    // animation is still running, so the FTextField (and its managed control)
    // is briefly still mounted and depends on these controllers. Disposing them
    // synchronously here throws `_dependents.isEmpty is not true`. Deferring one
    // frame lets the field detach first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      labelCtrl.dispose();
      totalCtrl.dispose();
      labelFocus.dispose();
    });
  }

  /// Re-focuses the goal-label field after a tap on the mode toggle. The toggle
  /// is a tap *outside* the field, which fires AppInput's onTapOutside ->
  /// unfocus and hides the keyboard; re-requesting focus on the next frame (so
  /// the rebuilt field is attached) keeps the keyboard up across the toggle.
  void _keepLabelFocus(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (node.canRequestFocus && !node.hasFocus) {
        node.requestFocus();
      }
    });
  }

  Future<void> _deleteGoalPrep(EventGoalsTableData goal) async {
    try {
      await ApiService.deleteEventGoal(widget.event.id, goal.id);
      await _sync.eventGoals.catchUp();
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) showAppToast(context, 'Failed to delete goal.');
    }
  }

  String _daysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);
    final diff = eventDay.difference(today).inDays;
    if (diff < 0) { return 'Past'; }
    if (diff == 0) { return 'Today'; }
    if (diff == 1) { return 'Tomorrow'; }
    return 'In $diff Days';
  }

  String _formatDateRange(DateTime start, DateTime? end) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (end == null) { return '${months[start.month - 1]} ${start.day}'; }
    return '${months[start.month - 1]} ${start.day} — ${months[end.month - 1]} ${end.day}';
  }

  Future<void> _openTargetDetail(TargetCompanyRow target) async {
    // Push onto the ROOT navigator so this full-screen detail renders above the
    // AppShell — no bottom nav bar / live bar leaks through. See router.dart.
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => TargetCompanyPrepScreen(event: widget.event, targetId: target.id),
      ),
    );
    await _targetsRepo.catchUp();
    await _contactEventsRepo.catchUp();
  }

  Future<void> _importTargets() async {
    await showAppSheet(
      context: context,
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _c.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.upload_file_outlined, color: _c.accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Import Target Companies', style: context.theme.typography.lg.copyWith(fontWeight: FontWeight.w700, color: context.theme.colors.foreground)),
                    Text('Upload a CSV or Excel file to bulk-add companies', style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground)),
                  ]),
                ),
              ]),
              const SizedBox(height: 24),
              Text('Required columns', style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w600, color: context.theme.colors.foreground)),
              const SizedBox(height: 10),
              _buildCsvFieldRow(
                icon: Icons.business_outlined,
                label: 'company_name',
                description: 'Company name — required',
                required: true,
              ),
              const SizedBox(height: 8),
              _buildCsvFieldRow(
                icon: Icons.location_on_outlined,
                label: 'booth_number',
                description: 'Booth / stand number — optional',
                required: false,
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ColoredBox(
                  color: _c.surfaceAlt,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Example', style: context.theme.typography.xs.copyWith(fontWeight: FontWeight.w600, color: context.theme.colors.mutedForeground, letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      Text(
                        'company_name,booth_number\nAcme Corp,A-12\nGlobex,\nInitech,Hall 3 B04',
                        style: context.theme.typography.xs.copyWith(
                          fontFamily: 'monospace',
                          color: context.theme.colors.foreground,
                          height: 1.6,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'CHOOSE FILE',
                fullWidth: true,
                variant: ButtonVariant.primary,
                prefixIcon: const Icon(Icons.folder_open_outlined, size: 18),
                onPressed: () async {
                  Navigator.of(sheetCtx).pop();
                  await _pickAndUploadCsv();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCsvFieldRow({required IconData icon, required String label, required String description, required bool required}) {
    return Row(children: [
      Icon(icon, size: 16, color: required ? _c.accent : context.theme.colors.mutedForeground),
      const SizedBox(width: 10),
      Expanded(
        child: RichText(
          text: TextSpan(children: [
            TextSpan(text: label, style: context.theme.typography.sm.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w600, color: context.theme.colors.foreground)),
            TextSpan(text: '  $description', style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground)),
          ]),
        ),
      ),
      if (required)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: _c.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
          child: Text('required', style: context.theme.typography.xs.copyWith(color: _c.accent, fontWeight: FontWeight.w600)),
        )
      else
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: context.theme.colors.border.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4)),
          child: Text('optional', style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground, fontWeight: FontWeight.w600)),
        ),
    ]);
  }

  Future<void> _pickAndUploadCsv() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) showAppToast(context, 'Could not open file picker.');
      return;
    }

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final name = file.name.toLowerCase();
    if (!name.endsWith('.csv') && !name.endsWith('.xlsx') && !name.endsWith('.xls')) {
      if (mounted) showAppToast(context, 'Please select a CSV or Excel file.');
      return;
    }
    if (file.bytes == null) {
      if (mounted) showAppToast(context, 'Could not read file. Try again.');
      return;
    }

    try {
      final imported = await ApiService.importEventTargets(widget.event.id, file.bytes!, file.name);
      await _targetsRepo.catchUp();
      if (mounted) {
        showAppToast(context, 'Import complete: ${imported['added']} added, ${imported['skipped']} skipped.');
      }
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) showAppToast(context, 'Upload failed. Check the file and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    padding: EdgeInsets.fromLTRB(16, 24, 16, bottomScrollInset(context, margin: 88)),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderSection(),
                            const SizedBox(height: 32),
                            _buildGoalsPanel(),
                            const SizedBox(height: 24),
                            _buildTargetContactsPanel(),
                            const SizedBox(height: 24),
                            _buildTargetListPanel(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ExoDockBar(
                      entity: ChatMention(
                        type: 'event',
                        id: widget.event.id,
                        displayName: widget.event.name,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.theme.colors.foreground,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer, size: 14, color: context.theme.colors.background),
              const SizedBox(width: 8),
              Text(
                _daysUntil(widget.event.localStartDate).toUpperCase(),
                style: context.theme.typography.xs.copyWith(
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.4,
                  color: context.theme.colors.background,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.event.name,
          style: context.theme.typography.xl2.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: context.theme.colors.foreground,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: _c.accent),
                const SizedBox(width: 8),
                Text(
                  (widget.event.location ?? 'Location TBD').toUpperCase(),
                  style: context.theme.typography.xs.copyWith(
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.1,
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month_outlined, size: 16, color: _c.accent),
                const SizedBox(width: 8),
                Text(
                  _formatDateRange(widget.event.localStartDate, widget.event.endDate).toUpperCase(),
                  style: context.theme.typography.xs.copyWith(
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.1,
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
            if (widget.event.localTimeRange != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_outlined, size: 16, color: _c.accent),
                  const SizedBox(width: 8),
                  Text(
                    widget.event.localTimeRange!.toUpperCase(),
                    style: context.theme.typography.xs.copyWith(
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.1,
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildGoalsPanel() {
    return StreamBuilder<List<EventGoalsTableData>>(
      stream: _sync.eventGoals.watchAll(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildPanelSkeleton();
        final goals = snapshot.data!.where((g) => g.eventId == widget.event.id).toList();
        return AppCard(
          padding: const EdgeInsets.all(24),
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    'Event Goals',
                    style: context.theme.typography.xl.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.theme.colors.foreground,
                    ),
                  ),
                ),
                AppButton(
                  prefixIcon: const Icon(Icons.add_rounded, size: 16),
                  label: 'Add',
                  variant: ButtonVariant.primary,
                  size: ButtonSize.sm,
                  onPressed: _addGoal,
                ),
              ]),
              const SizedBox(height: 16),
              if (goals.isEmpty)
                Row(children: [
                  Icon(Icons.flag_outlined, size: 18, color: _c.accent),
                  const SizedBox(width: 10),
                  Expanded(child: Text('No goals yet. Set targets to stay focused during the event.',
                      style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground, height: 1.4))),
                ])
              else
                for (int i = 0; i < goals.length; i++) ...[
                  _buildPrepGoalRow(goals[i]),
                  if (i < goals.length - 1)
                    const SizedBox(height: 4),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrepGoalRow(EventGoalsTableData goal) {
    final current = goal.current;
    final total = goal.total;
    final isCheckbox = total == 0;
    final isComplete = isCheckbox ? current == 1 : (total > 0 && current >= total);
    final progress = (!isCheckbox && total > 0) ? (current / total).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onLongPress: () async {
        final confirmed = await showAppConfirmDialog(
          context: context,
          title: 'Delete goal?',
          message: 'This removes "${goal.label}" from your event goals.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (confirmed == true) { _deleteGoalPrep(goal); }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isComplete ? _c.success : Colors.transparent,
                border: Border.all(color: isComplete ? _c.success : context.theme.colors.border, width: 1.5),
              ),
              child: isComplete ? Icon(Icons.check_rounded, size: 10, color: _c.isDark ? context.theme.colors.foreground : context.theme.colors.background) : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(goal.label, style: context.theme.typography.sm.copyWith(
                fontWeight: FontWeight.w500,
                color: isComplete ? _c.success : context.theme.colors.foreground,
                decoration: isComplete ? TextDecoration.lineThrough : null,
                decorationColor: _c.success))),
            const SizedBox(width: 8),
            if (!isCheckbox)
              Text('$current / $total', style: context.theme.typography.xs.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isComplete ? _c.success : context.theme.colors.mutedForeground)),
          ]),
          if (!isCheckbox) ...[
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress, minHeight: 3,
                backgroundColor: _c.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(isComplete ? _c.success : _c.accent),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildTargetContactsPanel() {
    return StreamBuilder<List<TargetContactRow>>(
      stream: _contactEventsRepo.watchByEventWithContact(widget.event.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildPanelSkeleton();
        final targetContacts = snapshot.data!;
        return AppCard(
          padding: const EdgeInsets.all(24),
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Target Contacts',
                      style: context.theme.typography.xl.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.theme.colors.foreground,
                      ),
                    ),
                  ),
                  AppButton(
                    prefixIcon: const Icon(Icons.person_add_outlined, size: 16),
                    label: 'Add',
                    variant: ButtonVariant.primary,
                    size: ButtonSize.sm,
                    onPressed: () => _showAddTargetContactSheet(targetContacts),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (targetContacts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'No target contacts yet. Add people you want to meet.',
                    style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground),
                  ),
                )
              else
                ...targetContacts.map(_buildTargetContactRow),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTargetContactRow(TargetContactRow contact) {
    final name = contact.name.isNotEmpty ? contact.name : 'Unknown';
    final jobTitle = contact.jobTitle;
    final companyName = contact.companyName;
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.take(2).map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.theme.colors.border)),
      ),
      child: Row(
        children: [
          AppAvatar(initials: initials.isNotEmpty ? initials : '?', size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w600, color: context.theme.colors.foreground)),
                if (jobTitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    jobTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.typography.xs.copyWith(
                      fontWeight: FontWeight.w500,
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ],
                if (companyName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.typography.xs.copyWith(
                      color: _c.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppButton(
            variant: ButtonVariant.ghost,
            size: ButtonSize.sm,
            onPressed: () => _removeTargetContact(contact.contactId),
            child: Icon(Icons.delete_outline, color: _c.destructive, size: 20),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTargetContactSheet(List<TargetContactRow> targetContacts) async {
    String searchQuery = '';
    List<dynamic> contacts = [];
    bool isSearching = true;
    bool initialLoaded = false;
    final searchCtrl = TextEditingController();

    final existingIds = targetContacts.map((c) => c.contactId).toSet();

    await showAppSheet(
      context: context,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          if (!initialLoaded) {
            initialLoaded = true;
            ApiService.getContacts().then((results) {
              final eligible = results.where((c) => !existingIds.contains(c.id)).toList()
                ..sort((a, b) => '${a.firstName} ${a.lastName ?? ''}'.compareTo('${b.firstName} ${b.lastName ?? ''}'));
              setModalState(() { contacts = eligible; isSearching = false; });
            }).catchError((_) { setModalState(() => isSearching = false); });
          }

          final filtered = contacts.where((c) {
            final cname = '${c.firstName} ${c.lastName ?? ''}'.toLowerCase();
            final company = (c.company?.name ?? '').toLowerCase();
            final q = searchQuery.toLowerCase();
            return q.isEmpty || cname.contains(q) || company.contains(q);
          }).toList();

          return SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add Target Contact',
                            style: context.theme.typography.xl.copyWith(fontWeight: FontWeight.w600, color: context.theme.colors.foreground)),
                        const SizedBox(height: 16),
                        AppInput(
                          controller: searchCtrl,
                          autofocus: true,
                          hintText: 'Search contacts...',
                          prefixIcon: Icon(Icons.search, color: _c.accent),
                          onChanged: (val) => setModalState(() => searchQuery = val),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  Expanded(
                    child: isSearching
                        ? _buildSearchingState()
                        : filtered.isEmpty
                            ? Center(child: Text('No contacts found', style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)))
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                itemCount: filtered.length,
                                itemBuilder: (_, i) {
                                  final c = filtered[i];
                                  final cname = '${c.firstName} ${c.lastName ?? ''}'.trim();
                                  final company = c.company?.name ?? '';
                                  final initials = cname.isNotEmpty ? cname.split(' ').take(2).map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase() : '?';
                                  return GestureDetector(
                                    onTap: () async {
                                      Navigator.of(sheetCtx).pop();
                                      await _addTargetContact(c.id, cname, c.jobTitle ?? '', company);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      child: Row(
                                        children: [
                                          AppAvatar(initials: initials, size: 40),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              Text(cname, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w500, color: context.theme.colors.foreground)),
                                              if (company.isNotEmpty)
                                                Text(company, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground)),
                                            ]),
                                          ),
                                          Icon(Icons.add_circle_outline, color: _c.accent, size: 22),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    // Defer one frame: the sheet's exit animation is still running, so the field
    // still depends on this controller (see _addGoal for details).
    WidgetsBinding.instance.addPostFrameCallback((_) => searchCtrl.dispose());
  }

  Future<void> _addTargetContact(String contactId, String name, String jobTitle, String companyName) async {
    try {
      await ApiService.addContactToEvent(widget.event.id, contactId);
      await _contactEventsRepo.catchUp();
      if (mounted) showAppToast(context, '$name added to target contacts.');
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) showAppToast(context, 'Failed to add contact.');
    }
  }

  Future<void> _removeTargetContact(String contactId) async {
    try {
      await ApiService.removeContactFromEvent(widget.event.id, contactId);
      await _contactEventsRepo.catchUp();
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) showAppToast(context, 'Failed to remove contact.');
    }
  }

  Widget _buildTargetListPanel() {
    return StreamBuilder<List<TargetCompanyRow>>(
      stream: _targetsRepo.watchByEventWithCompany(widget.event.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildPanelSkeleton();
        final targets = snapshot.data!;
        return AppCard(
          padding: const EdgeInsets.all(24),
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Target Companies',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.typography.xl.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.theme.colors.foreground,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    variant: ButtonVariant.outline,
                    size: ButtonSize.sm,
                    onPressed: _importTargets,
                    child: const Icon(Icons.upload, size: 16),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    prefixIcon: const Icon(Icons.add, size: 16),
                    label: 'Add',
                    variant: ButtonVariant.primary,
                    size: ButtonSize.sm,
                    onPressed: _showAddTargetDialog,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (targets.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'No target companies yet. Add or import.',
                    style: context.theme.typography.sm.copyWith(
                      fontWeight: FontWeight.w400,
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                )
              else
                ...targets.map((t) => _TargetCompanyTile(
                  key: ValueKey(t.id),
                  target: t,
                  onManage: () => _openTargetDetail(t),
                  onDelete: () => _deleteTarget(t),
                )),
            ],
          ),
        );
      },
    );
  }


  Future<void> _showAddTargetDialog() async {
    await showAppSheet(
      context: context,
      builder: (sheetCtx) => AddTargetCompanySheet(
        onCompanySelected: (co) {
          Navigator.of(sheetCtx).pop();
          _showBoothInputDialog(co);
        },
        onCreatePressed: (query) {
          Navigator.of(sheetCtx).pop();
          _showCreateCompanyDialog(query);
        },
      ),
    );
  }

  Future<void> _showBoothInputDialog(Map<String, dynamic> company) async {
    _boothCtrl.clear();

    await showAppSheet(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.theme.colors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(company['name'] as String, style: context.theme.typography.xl.copyWith(fontWeight: FontWeight.w600, color: context.theme.colors.foreground)),
              const SizedBox(height: 4),
              Text('Adding to target list', style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
              const SizedBox(height: 20),
              AppInput(
                controller: _boothCtrl,
                autofocus: true,
                hintText: 'e.g. A-12, Hall 3 B04',
                labelText: 'Booth Number (optional)',
                prefixIcon: Icon(Icons.location_on_outlined, color: _c.accent),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'SKIP',
                      variant: ButtonVariant.outline,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _addCompanyAsTarget(company, null);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: 'ADD TO LIST',
                      variant: ButtonVariant.primary,
                      onPressed: () {
                        final booth = _boothCtrl.text.trim();
                        Navigator.of(ctx).pop();
                        _addCompanyAsTarget(company, booth.isEmpty ? null : booth);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addCompanyAsTarget(Map<String, dynamic> company, String? booth) async {
    try {
      final newRow = await ApiService.addEventTarget(widget.event.id, company['id'] as String, boothLocation: booth);
      // Upsert the returned row directly — catchUp only fetches deltas since
      // lastSyncedAt, which may already be past this new row's created_at.
      await _targetsRepo.applyDelta(upserts: [newRow], deletedIds: []);
      await CompanyNameResolver.resolve(company['id'] as String?);
      if (mounted) showAppToast(context, '${company['name']} added to target list.');
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) showAppToast(context, 'Failed to add target.');
    }
  }

  Future<void> _showCreateCompanyDialog(String initialName) async {
    Map<String, dynamic>? created;
    await showAppSheet(
      context: context,
      builder: (sheetCtx) => CreateCompanySheet(
        initialName: initialName,
        onCreated: (data) {
          created = data;
          Navigator.of(sheetCtx).pop();
        },
      ),
    );
    if (created != null && mounted) {
      await _showBoothInputDialog(created!);
    }
  }

  Future<void> _deleteTarget(TargetCompanyRow target) async {
    try {
      await ApiService.deleteEventTarget(widget.event.id, target.id);
      await _targetsRepo.catchUp();
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) showAppToast(context, 'Failed to remove target.');
    }
  }

  Widget _buildPanelSkeleton() {
    return AppCard(
      padding: const EdgeInsets.all(24),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SkeletonLoader(width: 150, height: 24, borderRadius: BorderRadius.circular(4)),
              ),
              SkeletonLoader(width: 80, height: 36, borderRadius: BorderRadius.circular(6)),
            ],
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < 2; i++) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(width: 180, height: 18, borderRadius: BorderRadius.circular(4)),
                      const SizedBox(height: 8),
                      SkeletonLoader(width: 100, height: 24, borderRadius: BorderRadius.circular(999)),
                    ],
                  ),
                ),
              ],
            ),
            if (i < 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchingState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (int i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SkeletonLoader(
                    width: 40,
                    height: 40,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonLoader(
                          width: double.infinity,
                          height: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 6),
                        SkeletonLoader(
                          width: 120,
                          height: 14,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TargetCompanyTile extends StatefulWidget {
  final TargetCompanyRow target;
  final VoidCallback onManage;
  final VoidCallback onDelete;

  const _TargetCompanyTile({super.key, required this.target, required this.onManage, required this.onDelete});

  @override
  State<_TargetCompanyTile> createState() => _TargetCompanyTileState();
}

class _TargetCompanyTileState extends State<_TargetCompanyTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    final companyId = widget.target.target.companyId;
    final cachedName = CompanyNameResolver.cached(companyId) ?? widget.target.companyName;
    final booth = widget.target.boothLocation;
    final initials = cachedName.length >= 2 ? cachedName.substring(0, 2).toUpperCase() : cachedName.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: c.surfaceAlt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      AppAvatar(initials: initials, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CompanyName(
                              companyId: companyId,
                              fallback: cachedName,
                              overflow: TextOverflow.ellipsis,
                              style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w600, color: context.theme.colors.foreground),
                            ),
                            if (booth != null && booth.isNotEmpty)
                              Text(
                                'Booth $booth',
                                style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppTheme.colorsOf(context).accent),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Column(
                  children: [
                    Container(height: 1, color: context.theme.colors.border),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              prefixIcon: const Icon(Icons.delete_outline, size: 16),
                              label: 'Delete',
                              variant: ButtonVariant.destructive,
                              size: ButtonSize.sm,
                              fullWidth: true,
                              onPressed: widget.onDelete,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppButton(
                              prefixIcon: const Icon(Icons.open_in_new_rounded, size: 14),
                              label: 'MANAGE',
                              variant: ButtonVariant.primary,
                              size: ButtonSize.sm,
                              fullWidth: true,
                              onPressed: widget.onManage,
                            ),
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
      ),
    );
  }
}
