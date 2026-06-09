import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_header.dart';
import '../widgets/app_section_label.dart';
import '../widgets/skeleton_loader.dart';
import 'event_target_screen.dart';

class PreEventPrepScreen extends StatefulWidget {
  final Event event;
  final ValueChanged<int>? onNavigateTab;

  const PreEventPrepScreen({super.key, required this.event, this.onNavigateTab});

  @override
  State<PreEventPrepScreen> createState() => _PreEventPrepScreenState();
}

class _PreEventPrepScreenState extends State<PreEventPrepScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  List<Map<String, dynamic>> _targets = [];
  List<Map<String, dynamic>> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadTargets(), _loadGoals()]);
  }

  Future<void> _loadGoals() async {
    try {
      final goals = await ApiService.getEventGoals(widget.event.id);
      if (mounted) setState(() => _goals = goals);
    } catch (_) {}
  }

  Future<void> _addGoal() async {
    final labelCtrl = TextEditingController();
    final totalCtrl = TextEditingController(text: '1');
    final c = _c;
    bool isCheckbox = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add Goal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 20),
            TextField(
              controller: labelCtrl, autofocus: true,
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
            // Type toggle
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
                      child: Center(child: Text('Checkbox',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: isCheckbox ? (c.isDark ? c.textPrimary : Colors.white) : c.textMuted))),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setModalState(() => isCheckbox = false),
                      behavior: HitTestBehavior.opaque,
                      child: Center(child: Text('Counted',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: !isCheckbox ? (c.isDark ? c.textPrimary : Colors.white) : c.textMuted))),
                    ),
                  ),
                ]),
              ]),
            ),
            if (!isCheckbox) ...[
              const SizedBox(height: 12),
              TextField(
                controller: totalCtrl, keyboardType: TextInputType.number,
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
                    final newGoal = await ApiService.createEventGoal(widget.event.id, label, total);
                    if (mounted) setState(() => _goals.add(newGoal));
                  } catch (_) {}
                },
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: c.isDark ? c.textPrimary : c.background,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ADD GOAL', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _deleteGoalPrep(Map<String, dynamic> goal) async {
    setState(() => _goals.removeWhere((g) => g['id'] == goal['id']));
    try {
      await ApiService.deleteEventGoal(widget.event.id, goal['id'] as String);
    } catch (_) {
      if (mounted) setState(() => _goals.add(goal));
    }
  }

  Future<void> _loadTargets() async {
    try {
      final targets = await ApiService.getEventTargets(widget.event.id);
      setState(() {
        _targets = targets;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  String _daysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);
    final diff = eventDay.difference(today).inDays;
    if (diff < 0) return 'Past';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return 'In $diff Days';
  }

  String _formatDateRange(DateTime start, DateTime? end) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (end == null) return '${months[start.month - 1]} ${start.day}';
    return '${months[start.month - 1]} ${start.day} — ${months[end.month - 1]} ${end.day}';
  }

  Future<void> _openTargetDetail(Map<String, dynamic> target, int index) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventTargetScreen(event: widget.event, targetId: target['id'] as String),
      ),
    );
    // Reload this target's data since it may have been edited
    try {
      final data = await ApiService.getEventTarget(widget.event.id, target['id'] as String);
      if (mounted) setState(() => _targets[index] = data);
    } catch (_) {}
  }

  Future<void> _importTargets() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file picker.'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final name = file.name.toLowerCase();
    if (!name.endsWith('.csv') && !name.endsWith('.xlsx') && !name.endsWith('.xls')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a CSV or Excel file.'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    if (file.bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file. Try again.'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }

    try {
      final imported = await ApiService.importEventTargets(widget.event.id, file.bytes!, file.name);
      await _loadTargets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import complete: ${imported['added']} added, ${imported['skipped']} skipped.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Check the file and try again.'), behavior: SnackBarBehavior.floating),
        );
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
              onNotificationPressed: () {},
              actionWidget: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.arrow_back_rounded, color: _c.accent, size: 22),
                splashRadius: 20,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : SingleChildScrollView(
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
            color: _c.textPrimary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer, size: 14, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                _daysUntil(widget.event.startDate).toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.4,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.event.name,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: _c.textPrimary,
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.1,
                    color: _c.textMuted,
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.1,
                    color: _c.textMuted,
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
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: AppTheme.radiusCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: AppSectionLabel('Event Goals')),
            GestureDetector(
              onTap: _addGoal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _c.accent.withValues(alpha: 0.5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, size: 12, color: _c.accent),
                  const SizedBox(width: 4),
                  Text('ADD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: _c.accent)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          if (_goals.isEmpty)
            Row(children: [
              Icon(Icons.flag_outlined, size: 18, color: _c.accent),
              const SizedBox(width: 10),
              Expanded(child: Text('No goals yet. Set targets to stay focused during the event.',
                  style: TextStyle(fontSize: 13, color: _c.textMuted, height: 1.4))),
            ])
          else
            for (int i = 0; i < _goals.length; i++) ...[
              _buildPrepGoalRow(_goals[i]),
              if (i < _goals.length - 1) ...[
                Divider(color: _c.border.withValues(alpha: 0.4), height: 1),
                const SizedBox(height: 4),
              ],
            ],
        ],
      ),
    );
  }

  Widget _buildPrepGoalRow(Map<String, dynamic> goal) {
    final current = goal['current'] as int? ?? 0;
    final total = goal['total'] as int? ?? 1;
    final isCheckbox = total == 0;
    final isComplete = isCheckbox ? current == 1 : (total > 0 && current >= total);
    final progress = (!isCheckbox && total > 0) ? (current / total).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: _c.surface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: _c.border, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: _c.destructive),
              title: Text('Delete goal', style: TextStyle(color: _c.destructive)),
              onTap: () { Navigator.pop(context); _deleteGoalPrep(goal); },
            ),
          ])),
        );
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
                border: Border.all(color: isComplete ? _c.success : _c.border, width: 1.5),
              ),
              child: isComplete ? Icon(Icons.check_rounded, size: 10, color: _c.isDark ? _c.textPrimary : _c.background) : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(goal['label'] as String? ?? '', style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500,
                color: isComplete ? _c.success : _c.textPrimary,
                decoration: isComplete ? TextDecoration.lineThrough : null,
                decorationColor: _c.success))),
            const SizedBox(width: 8),
            if (!isCheckbox)
              Text('$current / $total', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: isComplete ? _c.success : _c.textMuted)),
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

  Widget _buildTargetListPanel() {
    return _buildGlassPanel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Target List',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _c.textPrimary,
                  ),
                ),
              ),
              _buildHeaderAction(
                icon: Icons.upload,
                label: 'Import',
                filled: false,
                onTap: () => _importTargets(),
              ),
              const SizedBox(width: 8),
              _buildHeaderAction(
                icon: Icons.add,
                label: 'Add',
                filled: true,
                onTap: () => _showAddTargetDialog(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: _c.border),
          if (_targets.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'No target companies yet. Add or import some.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _c.textMuted,
                ),
              ),
            )
          else
            ..._targets.asMap().entries.map((entry) {
              return _buildTargetRow(entry.value, entry.key);
            }),
        ],
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? _c.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: filled ? _c.accent : _c.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: filled ? Colors.white : _c.accent),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
                color: filled ? Colors.white : _c.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetRow(Map<String, dynamic> target, int globalIndex) {
    final company = target['company'] as Map<String, dynamic>? ?? {};
    final companyName = company['name'] as String? ?? 'Unknown';
    final booth = target['booth_location'] as String?;
    final rawTags = target['tags'] as List?;
    final industryStr = company['industry'] as String?;
    final tags = rawTags != null && rawTags.isNotEmpty
        ? rawTags.cast<String>()
        : (industryStr != null ? [industryStr] : <String>[]);
    return InkWell(
      onTap: () => _openTargetDetail(target, globalIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _c.border)),
        ),
        child: Row(
          children: [
            // Company info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(companyName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _c.textPrimary)),
                  if (booth != null && booth.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    AppChip.label('BOOTH $booth'),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 4, children: tags.map((t) => AppChip(t)).toList()),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Manage button
            GestureDetector(
              onTap: () => _openTargetDetail(target, globalIndex),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: _c.borderStrong),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 14, color: _c.accent),
                    const SizedBox(width: 4),
                    Text('MANAGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: _c.textSecondary)),
                  ],
                ),
              ),
            ),
            // Delete button
            IconButton(
              onPressed: () => _deleteTarget(target, globalIndex),
              icon: Icon(Icons.delete_outline, color: _c.destructive, size: 20),
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
    bool _initialLoaded = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (!_initialLoaded) {
              _initialLoaded = true;
              ApiService.getCompanies(query: '').then((results) {
                results.sort((a, b) => (a['name'] as String? ?? '').toLowerCase().compareTo((b['name'] as String? ?? '').toLowerCase()));
                setModalState(() { companies = results; isSearching = false; });
              }).catchError((_) { setModalState(() => isSearching = false); });
            }
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: _c.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: _c.border)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _c.border, borderRadius: BorderRadius.circular(2))),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add Target Company', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _c.textPrimary)),
                        const SizedBox(height: 16),
                        TextField(
                          autofocus: true,
                          style: TextStyle(fontSize: 14, color: _c.textPrimary),
                          cursorColor: _c.accent,
                          decoration: InputDecoration(
                            hintText: 'Search companies...',
                            hintStyle: TextStyle(color: _c.textMuted),
                            prefixIcon: Icon(Icons.search, color: _c.accent),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.accent)),
                            filled: true,
                            fillColor: _c.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: (val) async {
                            setModalState(() { searchQuery = val; isSearching = true; });
                            try {
                              final results = await ApiService.getCompanies(query: val);
                              results.sort((a, b) => (a['name'] as String? ?? '').toLowerCase().compareTo((b['name'] as String? ?? '').toLowerCase()));
                              setModalState(() { companies = results; isSearching = false; });
                            } catch (_) {
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
                            ? Center(child: Text('No companies found', style: TextStyle(color: _c.textMuted)))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: companies.length + (searchQuery.isNotEmpty ? 1 : 0),
                                itemBuilder: (_, i) {
                                  if (searchQuery.isNotEmpty && i == companies.length) {
                                    return ListTile(
                                      leading: Icon(Icons.add_circle_outline, color: _c.accent),
                                      title: Text('Create "$searchQuery"', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w500)),
                                      subtitle: Text('Add as new company', style: TextStyle(color: _c.textMuted, fontSize: 12)),
                                      onTap: () {
                                        Navigator.of(sheetCtx).pop();
                                        _showCreateCompanyDialog(searchQuery);
                                      },
                                    );
                                  }
                                  final co = companies[i];
                                  return InkWell(
                                    onTap: () async {
                                      Navigator.of(sheetCtx).pop();
                                      _showBoothInputDialog(co);
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40, height: 40,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(color: _c.surfaceAlt, borderRadius: BorderRadius.circular(8), border: Border.all(color: _c.border)),
                                            child: Text(
                                              (co['name'] as String).length >= 2 ? (co['name'] as String).substring(0, 2).toUpperCase() : (co['name'] as String).toUpperCase(),
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _c.textPrimary),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(co['name'] as String, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _c.textPrimary)),
                                                if (co['industry'] != null)
                                                  Text(co['industry'] as String, style: TextStyle(fontSize: 13, color: _c.textMuted)),
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
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showBoothInputDialog(Map<String, dynamic> company) async {
    final boothCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: _c.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: _c.border)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _c.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(company['name'] as String, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _c.textPrimary)),
              const SizedBox(height: 4),
              Text('Adding to target list', style: TextStyle(fontSize: 14, color: _c.textMuted)),
              const SizedBox(height: 20),
              TextField(
                controller: boothCtrl,
                autofocus: true,
                style: TextStyle(fontSize: 14, color: _c.textPrimary),
                cursorColor: _c.accent,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Booth Number (optional)',
                  hintText: 'e.g. A-12, Hall 3 B04',
                  labelStyle: TextStyle(color: _c.textMuted),
                  hintStyle: TextStyle(color: _c.textMuted),
                  prefixIcon: Icon(Icons.location_on_outlined, color: _c.accent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.accent)),
                  filled: true,
                  fillColor: _c.surface,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await _addCompanyAsTarget(company, null);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _c.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('SKIP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: _c.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () async {
                        final booth = boothCtrl.text.trim();
                        Navigator.of(ctx).pop();
                        await _addCompanyAsTarget(company, booth.isEmpty ? null : booth);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _c.accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('ADD TO LIST', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: Colors.white)),
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
      final newTarget = await ApiService.addEventTarget(widget.event.id, company['id'] as String, boothLocation: booth);
      setState(() => _targets.add(newTarget));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${company['name']} added to target list.'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add target.'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _showCreateCompanyDialog(String initialName) async {
    final nameCtrl = TextEditingController(text: initialName);
    final industryCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: _c.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: _c.border)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _c.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('New Company', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _c.textPrimary)),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: TextStyle(fontSize: 14, color: _c.textPrimary),
                cursorColor: _c.accent,
                decoration: InputDecoration(
                  labelText: 'Company Name',
                  labelStyle: TextStyle(color: _c.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.accent)),
                  filled: true,
                  fillColor: _c.surface,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: industryCtrl,
                style: TextStyle(fontSize: 14, color: _c.textPrimary),
                cursorColor: _c.accent,
                decoration: InputDecoration(
                  labelText: 'Industry (optional)',
                  labelStyle: TextStyle(color: _c.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _c.accent)),
                  filled: true,
                  fillColor: _c.surface,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.of(sheetCtx).pop();
                    try {
                      final companyData = <String, dynamic>{'name': name};
                      final industryText = industryCtrl.text.trim();
                      if (industryText.isNotEmpty) {
                        companyData['industry'] = industryText;
                      }
                      final company = await ApiService.createCompany(companyData);
                      nameCtrl.dispose();
                      industryCtrl.dispose();
                      await _showBoothInputDialog(company);
                    } catch (_) {
                      nameCtrl.dispose();
                      industryCtrl.dispose();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to add company.'), behavior: SnackBarBehavior.floating),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _c.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('CONTINUE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2.0, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTarget(Map<String, dynamic> target, int index) async {
    final targetId = target['id'] as String;
    try {
      await ApiService.deleteEventTarget(widget.event.id, targetId);
      setState(() {
        _targets.removeAt(index);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to remove target.'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  Widget _buildGlassPanel({
    required EdgeInsets padding,
    required Widget child,
  }) {
    return AppCard(
      padding: padding,
      radius: 16,
      child: child,
    );
  }

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header skeleton
              SkeletonLoader(
                width: 100,
                height: 28,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 16),
              SkeletonLoader(
                width: double.infinity,
                height: 40,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SkeletonLoader(
                    width: 120,
                    height: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(width: 20),
                  SkeletonLoader(
                    width: 100,
                    height: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Goals panel skeleton
              AppCard(
                padding: const EdgeInsets.all(20),
                radius: AppTheme.radiusCard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SkeletonLoader(
                            width: 120,
                            height: 20,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        SkeletonLoader(
                          width: 60,
                          height: 24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SkeletonLoader(
                      width: double.infinity,
                      height: 16,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    SkeletonLoader(
                      width: double.infinity,
                      height: 3,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Target list panel skeleton
              AppCard(
                padding: const EdgeInsets.all(24),
                radius: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SkeletonLoader(
                            width: 150,
                            height: 24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        SkeletonLoader(
                          width: 80,
                          height: 36,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        const SizedBox(width: 8),
                        SkeletonLoader(
                          width: 80,
                          height: 36,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(height: 1, color: _c.border),
                    const SizedBox(height: 16),
                    for (int i = 0; i < 3; i++) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonLoader(
                                  width: 180,
                                  height: 18,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 8),
                                SkeletonLoader(
                                  width: 100,
                                  height: 24,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SkeletonLoader(
                            width: 80,
                            height: 32,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          const SizedBox(width: 8),
                          SkeletonLoader(
                            width: 36,
                            height: 36,
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ],
                      ),
                      if (i < 2)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Container(height: 1, color: _c.border),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
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
