import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../config/app_theme.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_header.dart';
import '../widgets/app_section_label.dart';
import 'event_target_screen.dart';
import 'log_interaction_screen.dart';
import '../utils/screen_logger.dart';

class LiveTargetPersonScreen extends StatefulWidget {
  final Event event;
  final Map<String, dynamic> target;
  final ValueChanged<int>? onNavigateTab;

  const LiveTargetPersonScreen({
    super.key,
    required this.event,
    required this.target,
    this.onNavigateTab,
  });

  @override
  State<LiveTargetPersonScreen> createState() => _LiveTargetPersonScreenState();
}

class _LiveTargetPersonScreenState extends State<LiveTargetPersonScreen> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  late Map<String, dynamic> _target;
  bool _isMet = false;
  bool _isTogglingMet = false;
  bool _editingNotes = false;
  bool _isGenerating = false;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _target = widget.target;
    _isMet = (_target['status'] as String?) == 'met';
    _notesCtrl = TextEditingController(text: _target['notes'] as String? ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String get _name => _target['name'] as String? ?? '';
  String get _jobTitle => _target['job_title'] as String? ?? '';
  String get _companyName => _target['company_name'] as String? ?? '';
  String get _booth => _target['booth'] as String? ?? '';
  String get _priority => _target['priority'] as String? ?? 'medium';
  String get _talkingPointsRaw => _target['talking_points'] as String? ?? '';
  List<String> get _talkingPoints =>
      _talkingPointsRaw.split('\n').where((s) => s.trim().isNotEmpty).toList();

  String get _initials {
    final parts = _name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return _companyName.isNotEmpty ? _companyName[0].toUpperCase() : '?';
  }

  Color get _priorityColor => switch (_priority) {
        'high' => _c.destructive,
        'medium' => _c.accent,
        _ => _c.textMuted,
      };

  String get _priorityLabel => switch (_priority) {
        'high' => 'HIGH',
        'medium' => 'MED',
        _ => 'LOW',
      };

  Future<void> _toggleMet() async {
    final eventId = widget.event.id;
    final id = _target['id'] as String? ?? '';
    if (id.isEmpty) return;
    setState(() => _isTogglingMet = true);
    final nowMet = !_isMet;
    setState(() => _isMet = nowMet);
    try {
      await ApiService.updateTargetStatus(
          eventId, id, nowMet ? 'met' : 'not_contacted');
    } catch (_) {
      if (mounted) {
        setState(() => _isMet = !nowMet);
        _toast('Failed to update status');
      }
    } finally {
      if (mounted) setState(() => _isTogglingMet = false);
    }
  }

  Future<void> _saveNotes() async {
    final notes = _notesCtrl.text.trim();
    final id = _target['id'] as String? ?? '';
    try {
      await ApiService.updateEventTarget(
          widget.event.id, id, {'notes': notes.isEmpty ? null : notes});
      setState(() {
        _target = {..._target, 'notes': notes.isEmpty ? null : notes};
        _editingNotes = false;
      });
    } catch (_) {
      _toast('Failed to save notes');
    }
  }

  Future<void> _generateBriefing() async {
    setState(() => _isGenerating = true);
    try {
      final updated = await ApiService.generateTargetBriefing(
          widget.event.id, _target['id'] as String);
      setState(() {
        _target = {
          ..._target,
          'talking_points': updated['talking_points'] ?? updated['data']?['talking_points'] ?? '',
        };
        _isGenerating = false;
      });
    } catch (_) {
      setState(() => _isGenerating = false);
      _toast('Failed to generate briefing');
    }
  }

  void _toast(String msg) {
    showFToast(context: context, title: Text(msg));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 4,
        onNavigate: (i) {
          Navigator.of(context).pop();
          widget.onNavigateTab?.call(i);
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              onNotificationPressed: () {},
              actionWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isMet)
                    AppChip.status('MET', color: _c.success),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_rounded, color: _c.accent, size: 22),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPersonHero(),
                    const SizedBox(height: 16),
                    _buildTalkingPointsCard(),
                    const SizedBox(height: 16),
                    _buildNotesCard(),
                    const SizedBox(height: 20),
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonHero() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: AppTheme.radiusLarge,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(initials: _initials, size: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_name.isNotEmpty ? _name : _companyName, style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800,
                    letterSpacing: -0.4, color: _c.textPrimary, height: 1.1)),
                if (_jobTitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(_jobTitle, style: TextStyle(fontSize: 14, color: _c.textSecondary)),
                ],
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (_companyName.isNotEmpty) AppChip.label(_companyName),
                  if (_booth.isNotEmpty) AppChip.label('BOOTH $_booth'),
                  AppChip.status(_priorityLabel, color: _priorityColor),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTalkingPointsCard() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_awesome_rounded, size: 14, color: _c.accent),
            const SizedBox(width: 8),
            AppSectionLabel('Talking Points', color: _c.accent),
          ]),
          const SizedBox(height: 14),
          if (_talkingPoints.isEmpty) ...[
            Text('No AI briefing yet.', style: TextStyle(fontSize: 13, color: _c.textMuted, fontStyle: FontStyle.italic)),
            const SizedBox(height: 14),
          ] else ...[
            for (int i = 0; i < _talkingPoints.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i < _talkingPoints.length - 1 ? 12 : 14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 6, height: 6,
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    decoration: BoxDecoration(color: _c.accent, shape: BoxShape.circle),
                  ),
                  Expanded(child: Text(_talkingPoints[i], style: TextStyle(
                      fontSize: 14, color: _c.textSecondary, height: 1.5))),
                ]),
              ),
          ],
          SizedBox(
            width: double.infinity,
            child: FButton(
              variant: FButtonVariant.outline,
              onPress: _isGenerating ? null : _generateBriefing,
              prefix: _isGenerating
                  ? const SizedBox(width: 14, height: 14, child: FCircularProgress())
                  : Icon(Icons.auto_awesome_outlined, size: 14, color: _c.accent),
              child: Text(_isGenerating
                  ? 'GENERATING...'
                  : (_talkingPoints.isEmpty ? 'GENERATE AI BRIEFING' : 'REGENERATE')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    final notes = _target['notes'] as String? ?? '';
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: AppSectionLabel('My Notes')),
            if (!_editingNotes)
              GestureDetector(
                onTap: () => setState(() => _editingNotes = true),
                child: Icon(Icons.edit_outlined, size: 16, color: _c.accent),
              ),
          ]),
          const SizedBox(height: 12),
          if (_editingNotes) ...[
            TextField(
              controller: _notesCtrl,
              autofocus: true,
              maxLines: 4,
              style: TextStyle(fontSize: 14, color: _c.textPrimary),
              cursorColor: _c.accent,
              decoration: InputDecoration(
                hintText: 'Add notes about this person…',
                hintStyle: TextStyle(color: _c.textMuted),
                filled: true, fillColor: _c.surfaceAlt,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _c.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _c.accent)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: FButton(
                  variant: FButtonVariant.primary,
                  onPress: _saveNotes,
                  child: const Text('SAVE'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FButton(
                  variant: FButtonVariant.outline,
                  onPress: () => setState(() => _editingNotes = false),
                  child: const Text('CANCEL'),
                ),
              ),
            ]),
          ] else
            Text(
              notes.isNotEmpty ? notes : 'No notes yet. Tap edit to add.',
              style: TextStyle(
                  fontSize: 14, height: 1.5,
                  color: notes.isNotEmpty ? _c.textSecondary : _c.textMuted,
                  fontStyle: notes.isEmpty ? FontStyle.italic : null),
            ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(children: [
      Row(children: [
        Expanded(
          child: AppButton(
            variant: ButtonVariant.branded,
            onPressed: () => showLogInteractionSheet(context, contactId: _target['contact_id'] as String?),
            prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
            label: 'LOG INTERACTION',
            fullWidth: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FButton(
            variant: FButtonVariant.outline,
            onPress: () {
              final targetId = _target['id'] as String? ?? '';
              if (targetId.isEmpty) return;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => EventTargetScreen(event: widget.event, targetId: targetId),
              ));
            },
            prefix: Icon(Icons.business_outlined, size: 16, color: _c.accent),
            child: const Text('COMPANY'),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: FButton(
          variant: FButtonVariant.outline,
          onPress: _isTogglingMet ? null : _toggleMet,
          prefix: _isTogglingMet
              ? const SizedBox(width: 14, height: 14, child: FCircularProgress())
              : Icon(
                  _isMet ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                  size: 16,
                  color: _isMet ? _c.textMuted : _c.success),
          child: Text(_isMet ? 'UNMARK AS MET' : 'MARK AS MET'),
        ),
      ),
    ]);
  }
}
