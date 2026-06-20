import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../db/app_database.dart';
import '../models/event.dart';
import '../providers/sync_provider.dart';
import '../repositories/contact_events_repository.dart';
import '../repositories/target_companies_repository.dart';
import '../services/api_service.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_header.dart';
import '../widgets/app_input.dart';
import '../widgets/skeleton_loader.dart';
import 'target_company_prep_screen.dart';
import '../utils/screen_logger.dart';

class PreEventPrepScreen extends StatefulWidget {
  final Event event;
  final ValueChanged<int>? onNavigateTab;

  const PreEventPrepScreen({super.key, required this.event, this.onNavigateTab});

  @override
  State<PreEventPrepScreen> createState() => _PreEventPrepScreenState();
}

class _PreEventPrepScreenState extends State<PreEventPrepScreen> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  late final TargetCompaniesRepository _targetsRepo;
  late final ContactEventsRepository _contactEventsRepo;
  late final SyncProvider _sync;

  @override
  void initState() {
    super.initState();
    _sync = context.read<SyncProvider>();
    _targetsRepo = _sync.targetCompanies;
    _contactEventsRepo = _sync.contactEvents;
  }

  Future<void> _addGoal() async {
    final labelCtrl = TextEditingController();
    final totalCtrl = TextEditingController(text: '1');
    bool isCheckbox = false;

    await showAppSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Add Goal', style: context.theme.typography.lg.copyWith(fontWeight: FontWeight.w700, color: context.theme.colors.foreground)),
              const SizedBox(height: 20),
              AppInput(
                controller: labelCtrl,
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
                        onTap: () => setModalState(() => isCheckbox = true),
                        behavior: HitTestBehavior.opaque,
                        child: Center(child: Text('Checkbox',
                            style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w600,
                                color: isCheckbox ? (context.theme.colors.primaryForeground) : context.theme.colors.mutedForeground))),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => isCheckbox = false),
                        behavior: HitTestBehavior.opaque,
                        child: Center(child: Text('Counted',
                            style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w600,
                                color: !isCheckbox ? (context.theme.colors.primaryForeground) : context.theme.colors.mutedForeground))),
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
                  hintText: 'Target count',
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
    labelCtrl.dispose();
    totalCtrl.dispose();
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TargetCompanyPrepScreen(event: widget.event, targetId: target.id),
      ),
    );
    await _targetsRepo.catchUp();
    await _contactEventsRepo.catchUp();
  }

  Future<void> _importTargets() async {
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
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
                _daysUntil(widget.event.startDate).toUpperCase(),
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
                  _formatDateRange(widget.event.startDate, widget.event.endDate).toUpperCase(),
                  style: context.theme.typography.xs.copyWith(
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.1,
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
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
                Text(name, style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w600, color: context.theme.colors.foreground)),
                if (jobTitle.isNotEmpty || companyName.isNotEmpty)
                  Text(
                    [if (jobTitle.isNotEmpty) jobTitle, if (companyName.isNotEmpty) companyName].join(' · '),
                    style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground),
                  ),
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
                                              Text(cname, style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w500, color: context.theme.colors.foreground)),
                                              if (company.isNotEmpty)
                                                Text(company, style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground)),
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
    searchCtrl.dispose();
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
                ...targets.map(_buildTargetRow),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTargetRow(TargetCompanyRow target) {
    final companyName = target.companyName;
    final booth = target.boothLocation;
    return GestureDetector(
      onTap: () => _openTargetDetail(target),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.theme.colors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    companyName,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w600, color: context.theme.colors.foreground),
                  ),
                ),
                const SizedBox(width: 8),
                AppButton(
                  variant: ButtonVariant.ghost,
                  size: ButtonSize.sm,
                  onPressed: () => _deleteTarget(target),
                  child: Icon(Icons.delete_outline, color: _c.destructive, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (booth != null && booth.isNotEmpty)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppChip.label('BOOTH $booth', ellipsis: true),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 8),
                AppButton(
                  prefixIcon: Icon(Icons.open_in_new_rounded, size: 14),
                  label: 'MANAGE',
                  variant: ButtonVariant.outline,
                  size: ButtonSize.sm,
                  onPressed: () => _openTargetDetail(target),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTargetDialog() async {
    String searchQuery = '';
    List<Map<String, dynamic>> companies = [];
    bool isSearching = true;
    bool initialLoaded = false;
    final searchCtrl = TextEditingController();

    await showAppSheet(
      context: context,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (!initialLoaded) {
              initialLoaded = true;
              ApiService.getCompanies(query: '').then((results) {
                results.sort((a, b) => (a['name'] as String? ?? '').toLowerCase().compareTo((b['name'] as String? ?? '').toLowerCase()));
                setModalState(() { companies = results; isSearching = false; });
              }).catchError((_) { setModalState(() => isSearching = false); });
            }
            return SafeArea(
              top: false,
              child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add Target Company', style: context.theme.typography.xl.copyWith(fontWeight: FontWeight.w600, color: context.theme.colors.foreground)),
                        const SizedBox(height: 16),
                        AppInput(
                          controller: searchCtrl,
                          autofocus: true,
                          hintText: 'Search companies...',
                          prefixIcon: Icon(Icons.search, color: _c.accent),
                          onChanged: (val) async {
                            setModalState(() { searchQuery = val; isSearching = true; });
                            try {
                              final results = await ApiService.getCompanies(query: val);
                              results.sort((a, b) => (a['name'] as String? ?? '').toLowerCase().compareTo((b['name'] as String? ?? '').toLowerCase()));
                              setModalState(() { companies = results; isSearching = false; });
                            } on UnauthorizedException { rethrow; } catch (_) {
                              setModalState(() => isSearching = false);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: isSearching
                              ? _buildSearchingState()
                              : companies.isEmpty
                            ? Center(child: Text('No companies found', style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: companies.length + (searchQuery.isNotEmpty ? 1 : 0),
                                itemBuilder: (_, i) {
                                  if (searchQuery.isNotEmpty && i == companies.length) {
                                    return ListTile(
                                      leading: Icon(Icons.add_circle_outline, color: _c.accent),
                                      title: Text('Create "$searchQuery"', style: context.theme.typography.sm.copyWith(color: context.theme.colors.foreground, fontWeight: FontWeight.w500)),
                                      subtitle: Text('Add as new company', style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground)),
                                      onTap: () {
                                        Navigator.of(sheetCtx).pop();
                                        _showCreateCompanyDialog(searchQuery);
                                      },
                                    );
                                  }
                                  final co = companies[i];
                                  final coName = co['name'] as String;
                                  final initials = coName.length >= 2 ? coName.substring(0, 2).toUpperCase() : coName.toUpperCase();
                                  return GestureDetector(
                                    onTap: () async {
                                      Navigator.of(sheetCtx).pop();
                                      _showBoothInputDialog(co);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Row(
                                        children: [
                                          AppAvatar(initials: initials, size: 40),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(coName, style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w500, color: context.theme.colors.foreground)),
                                                if (co['industry'] != null)
                                                  Text(co['industry'] as String, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
                                              ],
                                            ),
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
              )),
            );
          },
        );
      },
    );
    searchCtrl.dispose();
  }

  Future<void> _showBoothInputDialog(Map<String, dynamic> company) async {
    final boothCtrl = TextEditingController();

    await showAppSheet(
      context: context,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(ctx).viewInsets.bottom + 32),
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
                controller: boothCtrl,
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
                        final booth = boothCtrl.text.trim();
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
    boothCtrl.dispose();
  }

  Future<void> _addCompanyAsTarget(Map<String, dynamic> company, String? booth) async {
    try {
      await ApiService.addEventTarget(widget.event.id, company['id'] as String, boothLocation: booth);
      await _targetsRepo.catchUp();
      if (mounted) showAppToast(context, '${company['name']} added to target list.');
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) showAppToast(context, 'Failed to add target.');
    }
  }

  Future<void> _showCreateCompanyDialog(String initialName) async {
    final nameCtrl = TextEditingController(text: initialName);
    final industryCtrl = TextEditingController();
    Map<String, dynamic>? createdCompany;

    await showAppSheet(
      context: context,
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(sheetCtx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.theme.colors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('New Company', style: context.theme.typography.xl.copyWith(fontWeight: FontWeight.w600, color: context.theme.colors.foreground)),
              const SizedBox(height: 20),
              AppInput(
                controller: nameCtrl,
                autofocus: true,
                labelText: 'Company Name',
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: industryCtrl,
                labelText: 'Industry (optional)',
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'CONTINUE',
                fullWidth: true,
                variant: ButtonVariant.primary,
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final industry = industryCtrl.text.trim();
                  Navigator.of(sheetCtx).pop();
                  try {
                    final companyData = <String, dynamic>{'name': name};
                    if (industry.isNotEmpty) { companyData['industry'] = industry; }
                    createdCompany = await ApiService.createCompany(companyData);
                  } on UnauthorizedException { rethrow; } catch (_) {
                    if (mounted) showAppToast(context, 'Failed to add company.');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
    nameCtrl.dispose();
    industryCtrl.dispose();
    if (createdCompany != null && mounted) {
      await _showBoothInputDialog(createdCompany!);
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
