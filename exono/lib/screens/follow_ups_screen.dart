import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_section_label.dart';

class FollowUpsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const FollowUpsScreen({super.key, this.onNavigateTab});

  @override
  State<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends State<FollowUpsScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  final List<_FollowUpQueueItem> _queueItems = [
    const _FollowUpQueueItem(
      initials: 'MT',
      name: 'Marcus Thorne',
      roleCompany: 'Chief Operations Officer @ Nexus Dynamics',
      lastMetEvent: 'Global Tech Summit',
      aiScore: 82,
      insight:
          'Marcus recently closed a Series C round. Reference the “Scalability bottleneck” mentioned in his LinkedIn post 4 hours ago for maximum resonance.',
      tags: ['High Priority', 'Series C Milestone'],
      subject: 'Strategic Operations: Addressing the Nexus Scalability Gap',
      greeting: 'Dear Marcus,',
      contextLine:
          'I noted your recent update regarding the Series C milestone—congratulations to the Nexus team.',
      problemLine:
          'In your post, you touched on the “scalability bottleneck” that often follows such rapid expansion. EXONO has specifically engineered its high-density data pipeline to alleviate the exact pressure points Nexus is currently experiencing.',
      closeLine:
          'I’ve attached a brief comparative analysis of how we handled similar operational surges for Tier 1 partners. Are you available for a 10-minute brief next Tuesday?',
    ),
    const _FollowUpQueueItem(
      initials: 'SR',
      name: 'Sophia Reed',
      roleCompany: 'VP Revenue Operations @ Altis Cloud',
      lastMetEvent: 'Revenue Leaders Forum',
      aiScore: 77,
      insight:
          'Sophia is under pressure to shorten rep onboarding. Anchor the note around EXONO’s guided enablement workflows and the 18% ramp-time reduction from a comparable rollout.',
      tags: ['Follow-Up Due', 'Enablement'],
      subject: 'A faster path to revenue ramp consistency at Altis',
      greeting: 'Hi Sophia,',
      contextLine:
          'It was great meeting you at Revenue Leaders Forum and hearing how aggressively Altis is scaling the field team this quarter.',
      problemLine:
          'You mentioned that onboarding consistency becomes the bottleneck once hiring accelerates. EXONO’s guided enablement workflows were built for exactly that kind of operational strain.',
      closeLine:
          'If helpful, I can send over a one-page breakdown of how a similar team reduced rep ramp time by 18% within the first cycle.',
    ),
    const _FollowUpQueueItem(
      initials: 'AK',
      name: 'Amir Khan',
      roleCompany: 'Director of Partnerships @ Vertex Grid',
      lastMetEvent: 'Energy Connect Expo',
      aiScore: 69,
      insight:
          'Amir responded positively to co-sell language. Keep the message concise, outcome-led, and centered on partner visibility across distributed accounts.',
      tags: ['Partnership Lead', 'Co-Sell Motion'],
      subject: 'Partner visibility for Vertex Grid’s next co-sell cycle',
      greeting: 'Hello Amir,',
      contextLine:
          'I appreciated your perspective at Energy Connect Expo on how difficult it is to maintain partner visibility once opportunities spread across regional teams.',
      problemLine:
          'That distributed-account challenge is where EXONO tends to add immediate value—especially when partner managers need one reliable layer for activity, ownership, and momentum.',
      closeLine:
          'Would it be useful if I sent a short walkthrough focused specifically on co-sell coordination across regional accounts?',
    ),
  ];

  late final TextEditingController _subjectController;
  late final TextEditingController _messageController;

  int _queuePosition = 5;
  final int _totalQueue = 12;
  int _currentItemIndex = 0;
  _DraftTone _selectedTone = _DraftTone.base;
  bool _aiImproved = false;

  _FollowUpQueueItem get _currentItem => _queueItems[_currentItemIndex];

  double get _progress => _queuePosition / _totalQueue;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController();
    _messageController = TextEditingController();
    _syncDraftWithCurrentItem(resetImproved: true);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _syncDraftWithCurrentItem({required bool resetImproved}) {
    if (resetImproved) {
      _aiImproved = false;
      _selectedTone = _DraftTone.base;
    }

    _subjectController.text = _currentItem.subject;
    _messageController.text = _buildMessage(_currentItem, _selectedTone);
  }

  String _buildMessage(_FollowUpQueueItem item, _DraftTone tone) {
    switch (tone) {
      case _DraftTone.base:
        return '${item.greeting}\n\n${item.contextLine}\n\n${item.problemLine}\n\n${item.closeLine}\n\nBest,\nExono Intelligence';
      case _DraftTone.shorten:
        return '${item.greeting}\n\n${item.contextLine}\n\nEXONO can help address this quickly and with very little operational lift.\n\nWould a 10-minute discussion next week be useful?\n\nBest,\nExono Intelligence';
      case _DraftTone.professional:
        return '${item.greeting}\n\nThank you again for the conversation. ${item.contextLine}\n\n${item.problemLine}\n\nIf appropriate, I would be glad to share a concise operating brief tailored to your team’s priorities.\n\nKind regards,\nExono Intelligence';
      case _DraftTone.friendly:
        return '${item.greeting}\n\nReally enjoyed meeting you. ${item.contextLine}\n\n${item.problemLine}\n\nHappy to send a short example or jump on a quick call if that’s easier.\n\nBest,\nExono Intelligence';
    }
  }

  void _showUiOnlyMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _setTone(_DraftTone tone) {
    setState(() {
      _selectedTone = tone;
      _messageController.text = _buildMessage(_currentItem, tone);
    });
  }

  void _improveDraft() {
    setState(() {
      _aiImproved = true;
      _subjectController.text =
          '${_currentItem.subject} — tailored for immediate action';
      _messageController.text =
          '${_currentItem.greeting}\n\n${_currentItem.contextLine}\n\n${_currentItem.problemLine}\n\nBased on the signals we captured, this is likely the most relevant moment to align around a focused next step instead of a broad overview.\n\n${_currentItem.closeLine}\n\nBest,\nExono Intelligence';
    });
    _showUiOnlyMessage('Draft improved with AI suggestions.');
  }

  void _advanceQueue(String feedback) {
    setState(() {
      if (_queuePosition < _totalQueue) {
        _queuePosition += 1;
      }
      _currentItemIndex = (_currentItemIndex + 1) % _queueItems.length;
      _syncDraftWithCurrentItem(resetImproved: true);
    });
    _showUiOnlyMessage(feedback);
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
            Expanded(child: _buildScrollableBody(bottomPadding: 24)),
          ],
        ),
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
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _showUiOnlyMessage('Menu is UI-only for now.'),
                icon: Icon(Icons.menu, color: _c.textPrimary, size: 22),
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
                  color: _c.textPrimary,
                  size: 22,
                ),
                splashRadius: 20,
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: _c.textMuted, size: 22),
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
                        text: '$_queuePosition ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _c.accent,
                          height: 1.33,
                        ),
                      ),
                      TextSpan(
                        text: 'of $_totalQueue',
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
                        decoration: BoxDecoration(
                          color: _c.accent,
                        ),
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
                        _currentItem.initials,
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
                            _currentItem.name,
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
                            _currentItem.roleCompany,
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
                                color: _c.borderStrong,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Last met · ${_currentItem.lastMetEvent}',
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
                    '${_currentItem.aiScore}%',
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
                  '”${_currentItem.insight}”',
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
              for (var i = 0; i < _currentItem.tags.length; i++)
                i == 0
                    ? AppChip.status(_currentItem.tags[i], color: _c.accent)
                    : AppChip.label(_currentItem.tags[i]),
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
            onPressed: () => _advanceQueue('Priority follow-up sent.'),
            style: FilledButton.styleFrom(
              backgroundColor: _c.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle: TextStyle(
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
                onPressed: () => _showUiOnlyMessage('Draft saved locally.'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _c.textPrimary,
                  backgroundColor: _c.surface,
                  side: BorderSide(color: _c.border),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                  ),
                ),
                icon: const Icon(Icons.save_outlined, size: 18),
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
                  textStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                  ),
                ),
                icon: const Icon(Icons.skip_next, size: 18),
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

class _FollowUpQueueItem {
  final String initials;
  final String name;
  final String roleCompany;
  final String lastMetEvent;
  final int aiScore;
  final String insight;
  final List<String> tags;
  final String subject;
  final String greeting;
  final String contextLine;
  final String problemLine;
  final String closeLine;

  const _FollowUpQueueItem({
    required this.initials,
    required this.name,
    required this.roleCompany,
    required this.lastMetEvent,
    required this.aiScore,
    required this.insight,
    required this.tags,
    required this.subject,
    required this.greeting,
    required this.contextLine,
    required this.problemLine,
    required this.closeLine,
  });
}

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
