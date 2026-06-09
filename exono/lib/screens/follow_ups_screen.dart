import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_section_label.dart';
import '../widgets/skeleton_loader.dart';

class FollowUpsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  final String? eventId;

  const FollowUpsScreen({super.key, this.onNavigateTab, this.eventId});

  @override
  State<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends State<FollowUpsScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  List<Map<String, dynamic>> _followUps = [];
  bool _isLoading = true;
  int _currentItemIndex = 0;
  _DraftTone _selectedTone = _DraftTone.base;
  bool _aiImproved = false;

  late final TextEditingController _subjectController;
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController();
    _messageController = TextEditingController();
    _loadFollowUps();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowUps() async {
    if (widget.eventId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final followUps = await ApiService.getEventFollowUps(widget.eventId!);
      setState(() {
        _followUps = followUps;
        _isLoading = false;
        if (_followUps.isNotEmpty) {
          _syncDraft(resetImproved: true);
        }
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> get _currentFollowUp => _followUps[_currentItemIndex];

  String _contactInitials(Map<String, dynamic> contact) {
    final first = (contact['first_name'] as String? ?? '');
    final last = (contact['last_name'] as String? ?? '');
    final fi = first.isNotEmpty ? first[0].toUpperCase() : '';
    final li = last.isNotEmpty ? last[0].toUpperCase() : '';
    return '$fi$li'.isNotEmpty ? '$fi$li' : '??';
  }

  String _contactName(Map<String, dynamic> contact) {
    final first = contact['first_name'] as String? ?? '';
    final last = contact['last_name'] as String? ?? '';
    return '$first $last'.trim();
  }

  String _roleCompany(Map<String, dynamic> followUp) {
    final contact = followUp['contact'] as Map<String, dynamic>? ?? {};
    final company = followUp['company'] as Map<String, dynamic>?;
    final role = contact['job_title'] as String? ?? 'Contact';
    final companyName = company?['name'] as String? ?? 'Company';
    return '$role @ $companyName';
  }

  int _aiScore(Map<String, dynamic> contact) {
    final insights = contact['ai_insights'];
    if (insights is Map) {
      final score = insights['score'];
      if (score is num) return score.toInt();
    }
    return 75;
  }

  String _insight(Map<String, dynamic> contact) {
    final insights = contact['ai_insights'];
    if (insights is Map) {
      final summary = insights['summary'] as String?;
      if (summary != null && summary.isNotEmpty) return summary;
    }
    return 'Follow up with this contact to strengthen the relationship.';
  }

  List<String> _tags(Map<String, dynamic> contact) {
    final urgency = contact['follow_up_urgency'] as String? ?? '';
    return [urgency == 'high' ? 'High Priority' : 'Pending Follow-Up'];
  }

  String _subject(Map<String, dynamic> emailDraft, Map<String, dynamic> contact) {
    return emailDraft['subject'] as String? ??
        'Following up from our meeting';
  }

  String _messageBody(Map<String, dynamic> emailDraft, Map<String, dynamic> contact) {
    return emailDraft['body'] as String? ??
        'Hi ${contact['first_name'] ?? ''},\n\nIt was great meeting you. I wanted to follow up on our conversation and explore how we can work together.\n\nBest,\nExono Intelligence';
  }

  void _syncDraft({required bool resetImproved}) {
    if (_followUps.isEmpty) return;
    if (resetImproved) {
      _aiImproved = false;
      _selectedTone = _DraftTone.base;
    }
    final followUp = _currentFollowUp;
    final contact = followUp['contact'] as Map<String, dynamic>? ?? {};
    final emailDraft = followUp['email_draft'] as Map<String, dynamic>? ?? {};
    _subjectController.text = _subject(emailDraft, contact);
    _messageController.text = _applyTone(
      _messageBody(emailDraft, contact),
      contact,
      _selectedTone,
    );
  }

  String _applyTone(String base, Map<String, dynamic> contact, _DraftTone tone) {
    final firstName = contact['first_name'] as String? ?? '';
    switch (tone) {
      case _DraftTone.base:
        return base;
      case _DraftTone.shorten:
        return 'Hi $firstName,\n\nGreat meeting you. EXONO can help address your needs quickly.\n\nWould a 10-minute call next week work?\n\nBest,\nExono Intelligence';
      case _DraftTone.professional:
        return 'Dear $firstName,\n\nThank you for the opportunity to connect. I would be glad to share a concise brief tailored to your team\'s priorities.\n\nKind regards,\nExono Intelligence';
      case _DraftTone.friendly:
        return 'Hey $firstName,\n\nReally enjoyed meeting you! Happy to send a short example or jump on a quick call if that\'s easier.\n\nBest,\nExono Intelligence';
    }
  }

  void _setTone(_DraftTone tone) {
    if (_followUps.isEmpty) return;
    setState(() {
      _selectedTone = tone;
      final followUp = _currentFollowUp;
      final contact = followUp['contact'] as Map<String, dynamic>? ?? {};
      final emailDraft = followUp['email_draft'] as Map<String, dynamic>? ?? {};
      final base = _messageBody(emailDraft, contact);
      _messageController.text = _applyTone(base, contact, tone);
    });
  }

  void _improveDraft() {
    if (_followUps.isEmpty) return;
    final followUp = _currentFollowUp;
    final contact = followUp['contact'] as Map<String, dynamic>? ?? {};
    final emailDraft = followUp['email_draft'] as Map<String, dynamic>? ?? {};
    setState(() {
      _aiImproved = true;
      _subjectController.text =
          '${_subject(emailDraft, contact)} — tailored for immediate action';
      _messageController.text =
          '${_messageBody(emailDraft, contact)}\n\nBased on the signals captured, this is the most relevant moment to align around a focused next step.';
    });
    _showUiOnlyMessage('Draft improved with AI suggestions.');
  }

  void _advanceQueue(String feedback) {
    setState(() {
      if (_followUps.isNotEmpty) {
        _currentItemIndex = (_currentItemIndex + 1) % _followUps.length;
        _syncDraft(resetImproved: true);
      }
    });
    _showUiOnlyMessage(feedback);
  }

  double get _progress =>
      _followUps.isEmpty ? 0.0 : (_currentItemIndex + 1) / _followUps.length;

  void _showUiOnlyMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 4,
        onNavigate: (i) {
          if (widget.onNavigateTab != null) {
            Navigator.of(context).pop();
            widget.onNavigateTab!(i);
          } else {
            Navigator.of(context).pop();
          }
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _isLoading
                  ? _buildSkeletonLoading()
                  : _followUps.isEmpty
                      ? _buildEmptyState()
                      : _buildScrollableBody(bottomPadding: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Queue Status Skeleton
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_c.surface, _c.surfaceAlt],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(
                    width: 120,
                    height: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  SkeletonLoader(
                    width: 180,
                    height: 20,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 12),
                  SkeletonLoader(
                    width: double.infinity,
                    height: 6,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Priority Card Skeleton
            const SkeletonCard(),
            const SizedBox(height: 24),
            // Smart Draft Skeleton
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_c.surface, _c.surfaceAlt],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(
                    width: 100,
                    height: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 12),
                  SkeletonLoader(
                    width: double.infinity,
                    height: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 16),
                  SkeletonLoader(
                    width: double.infinity,
                    height: 120,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Action Buttons Skeleton
            SkeletonLoader(
              width: double.infinity,
              height: 56,
              borderRadius: BorderRadius.circular(20),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SkeletonLoader(
                    width: double.infinity,
                    height: 52,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SkeletonLoader(
                    width: double.infinity,
                    height: 52,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: _c.accent),
          const SizedBox(height: 16),
          Text(
            'No follow-ups pending for this event.',
            style: TextStyle(fontSize: 16, color: _c.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: _c.surface.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            border: Border(
              bottom: BorderSide(color: _c.border, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: _c.accentGlow.withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _showUiOnlyMessage('Menu is UI-only for now.'),
                icon: Icon(Icons.menu, color: _c.accent, size: 22),
                splashRadius: 20,
              ),
              Expanded(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(-10, 0),
                    child: Text(
                      'EXONO',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                        color: _c.textPrimary,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    _showUiOnlyMessage('Notifications are UI-only for now.'),
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: _c.accent,
                  size: 22,
                ),
                splashRadius: 20,
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: _c.accent, size: 22),
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableBody({required double bottomPadding}) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 20, 16, bottomPadding),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQueueStatusSection(),
            const SizedBox(height: 24),
            _buildPriorityCard(),
            const SizedBox(height: 24),
            _buildSmartDraftSection(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueStatusSection() {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      radius: 24,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSectionLabel('Queue Status'),
                    const SizedBox(height: 6),
                    Text(
                      'Pending Outbox',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.48,
                        color: _c.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${_currentItemIndex + 1} ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _c.accent,
                          height: 1.33,
                        ),
                      ),
                      TextSpan(
                        text: 'of ${_followUps.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: _c.borderStrong,
                          height: 1.33,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 6,
              width: double.infinity,
              color: _c.surfaceElevated,
              child: Align(
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOut,
                  tween: Tween<double>(begin: 0, end: _progress),
                  builder: (context, value, child) {
                    return FractionallySizedBox(
                      widthFactor: value,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(color: _c.accent),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityCard() {
    final followUp = _currentFollowUp;
    final contact = followUp['contact'] as Map<String, dynamic>? ?? {};
    final initials = _contactInitials(contact);
    final name = _contactName(contact);
    final roleCompany = _roleCompany(followUp);
    final aiScore = _aiScore(contact);
    final insight = _insight(contact);
    final tags = _tags(contact);

    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _c.accentSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _c.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: _c.textPrimary,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: _c.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            roleCompany,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _c.borderStrong,
                              height: 1.33,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.event_outlined,
                                size: 14,
                                color: _c.accent,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Last met · This Event',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _c.borderStrong.withValues(alpha: 0.70),
                                    height: 1.33,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$aiScore%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: _c.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'AI Score',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: _c.borderStrong,
                      height: 1.27,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.all(14),
            radius: 20,
            elevated: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: _c.accent),
                    const SizedBox(width: 8),
                    AppSectionLabel(
                      'AI Strategy Insight',
                      color: _c.accent,
                      letterSpacing: 1.4,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '"$insight"',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: _c.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < tags.length; i++)
                i == 0
                    ? AppChip.status(tags[i], color: _c.accent)
                    : AppChip.label(tags[i]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmartDraftSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: AppSectionLabel('Smart Draft')),
            Row(
              children: [
                _PulseDot(color: _c.accent),
                const SizedBox(width: 4),
                _PulseDot(color: _c.accent.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                _PulseDot(color: _c.accent.withValues(alpha: 0.3)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: _c.surfaceAlt.withValues(alpha: 0.30),
                  border: Border(
                    bottom: BorderSide(
                      color: _c.border.withValues(alpha: 0.30),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subject',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                        color: _c.borderStrong,
                        height: 1.27,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _subjectController,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _c.textPrimary,
                        height: 1.5,
                      ),
                      cursorColor: _c.textPrimary,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                        color: _c.borderStrong,
                        height: 1.27,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _messageController,
                      maxLines: null,
                      minLines: 8,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _c.textSecondary,
                        height: 1.55,
                      ),
                      cursorColor: _c.textPrimary,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTonePill(
              label: 'AI Improve',
              icon: Icons.bolt,
              isActive: _aiImproved,
              onTap: _improveDraft,
              forceFilled: true,
            ),
            _buildTonePill(
              label: 'Shorten',
              isActive: _selectedTone == _DraftTone.shorten,
              onTap: () => _setTone(_DraftTone.shorten),
            ),
            _buildTonePill(
              label: 'Professional',
              isActive: _selectedTone == _DraftTone.professional,
              onTap: () => _setTone(_DraftTone.professional),
            ),
            _buildTonePill(
              label: 'Friendly',
              isActive: _selectedTone == _DraftTone.friendly,
              onTap: () => _setTone(_DraftTone.friendly),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTonePill({
    required String label,
    IconData? icon,
    required bool isActive,
    required VoidCallback onTap,
    bool forceFilled = false,
  }) {
    final filled = forceFilled || isActive;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? _c.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: filled ? null : Border.all(color: _c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: filled ? Colors.white : _c.accent,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: filled ? Colors.white : _c.textPrimary,
                height: 1.33,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              _showUiOnlyMessage('Follow-up queued.');
              _advanceQueue('Priority follow-up sent.');
            },
            style: FilledButton.styleFrom(
              backgroundColor: _c.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            icon: const Icon(Icons.send, size: 20),
            label: const Text('SEND PRIORITY FOLLOW-UP'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showUiOnlyMessage('Draft saved.'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _c.textPrimary,
                  backgroundColor: _c.surface,
                  side: BorderSide(color: _c.border),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                  ),
                ),
                icon: Icon(Icons.save_outlined, size: 18, color: _c.accent),
                label: const Text('SAVE DRAFT'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    _advanceQueue('Skipped for now. Next contact loaded.'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _c.textPrimary,
                  backgroundColor: _c.surface,
                  side: BorderSide(color: _c.border),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                  ),
                ),
                icon: Icon(Icons.skip_next, size: 18, color: _c.accent),
                label: const Text('SKIP FOR NOW'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _DraftTone { base, shorten, professional, friendly }

class _PulseDot extends StatefulWidget {
  final Color color;

  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
