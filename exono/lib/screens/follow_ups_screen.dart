import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FollowUpsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const FollowUpsScreen({super.key, this.onNavigateTab});

  @override
  State<FollowUpsScreen> createState() => _FollowUpsScreenState();
}

class _FollowUpsScreenState extends State<FollowUpsScreen> {
  static const Color _background = Color(0xFF080808);
  static const Color _surfaceContainerLowest = Color(0xFF0E0E0E);
  static const Color _surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color _surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color _surfaceContainerHighest = Color(0xFF353434);
  static const Color _outline = Color(0xFF8E9192);
  static const Color _outlineVariant = Color(0xFF444748);
  static const Color _primary = Color(0xFFFFFFFF);
  static const Color _primaryFixedDim = Color(0xFFC6C6C7);
  static const Color _onSurfaceVariant = Color(0xFFC4C7C8);
  static const Color _onPrimary = Color(0xFF000000);

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

  void _navigateTo(int index) {
    widget.onNavigateTab?.call(index);
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
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (!isMobile) {
      return ColoredBox(
        color: _background,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _buildScrollableBody(bottomPadding: 32),
          ),
        ),
      );
    }

    return ColoredBox(
      color: _background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildScrollableBody(bottomPadding: 24)),
            _buildBottomNav(),
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
            color: _background.withValues(alpha: 0.80),
            border: const Border(
              bottom: BorderSide(color: Color(0xFF262626), width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _showUiOnlyMessage('Menu is UI-only for now.'),
                icon: const Icon(Icons.menu, color: _primary, size: 22),
                splashRadius: 20,
              ),
              Expanded(
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(-10, 0),
                    child: Text(
                      'EXONO',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                        color: _primary,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    _showUiOnlyMessage('Notifications are UI-only for now.'),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: _primary,
                  size: 22,
                ),
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
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _surfaceContainerHighest)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Queue Status',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2.4,
                        color: _outline.withValues(alpha: 0.80),
                        height: 1.33,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pending Outbox',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.48,
                        color: _primary,
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
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _primaryFixedDim,
                          height: 1.33,
                        ),
                      ),
                      TextSpan(
                        text: 'of $_totalQueue',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: _outline,
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
              color: _surfaceContainerHighest,
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
                        decoration: const BoxDecoration(
                          color: _primary,
                          boxShadow: [
                            BoxShadow(color: Color(0x66FFFFFF), blurRadius: 8),
                          ],
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.30)),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 4)],
      ),
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
                        color: _surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _outlineVariant),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _currentItem.initials,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: _primary,
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
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: _primary,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currentItem.roleCompany,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _outline,
                              height: 1.33,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.event_outlined,
                                size: 14,
                                color: _outline,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Last met · ${_currentItem.lastMetEvent}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _outline.withValues(alpha: 0.70),
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
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: _primary,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'AI Score',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: _outline,
                      height: 1.27,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: _surfaceContainerLow.withValues(alpha: 0.50),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
                bottomLeft: Radius.circular(2),
                topLeft: Radius.circular(2),
              ),
              border: Border(
                left: BorderSide(
                  color: _primary.withValues(alpha: 0.20),
                  width: 2,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: _primaryFixedDim,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI Strategy Insight',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: _primary,
                        height: 1.33,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '“${_currentItem.insight}”',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: _onSurfaceVariant,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: i == 0 ? _primary : _surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    _currentItem.tags[i],
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w600,
                      letterSpacing: 1.2,
                      color: i == 0 ? _onPrimary : _outline,
                      height: 1.27,
                    ),
                  ),
                ),
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
            Expanded(
              child: Text(
                'Smart Draft',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                  color: _outline,
                  height: 1.33,
                ),
              ),
            ),
            Row(
              children: const [
                _PulseDot(color: Colors.white),
                SizedBox(width: 4),
                _PulseDot(color: Color(0x66FFFFFF)),
                SizedBox(width: 4),
                _PulseDot(color: Color(0x33FFFFFF)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: _surfaceContainerLow.withValues(alpha: 0.30),
                  border: Border(
                    bottom: BorderSide(
                      color: _outlineVariant.withValues(alpha: 0.30),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subject',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                        color: _outline,
                        height: 1.27,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _subjectController,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                        height: 1.5,
                      ),
                      cursorColor: _primary,
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
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                        color: _outline,
                        height: 1.27,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _messageController,
                      maxLines: null,
                      minLines: 8,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _onSurfaceVariant,
                        height: 1.55,
                      ),
                      cursorColor: _primary,
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
          color: filled ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: filled ? null : Border.all(color: _primary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: filled ? _onPrimary : _primary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: filled ? _onPrimary : _primary,
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
              backgroundColor: _primary,
              foregroundColor: _onPrimary,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.inter(
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
                  foregroundColor: _primary,
                  side: const BorderSide(color: _outlineVariant),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.inter(
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
                  foregroundColor: _primary,
                  side: const BorderSide(color: _outlineVariant),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.inter(
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

  Widget _buildBottomNav() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: _background.withValues(alpha: 0.90),
            border: const Border(
              top: BorderSide(color: Color(0xFF262626), width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 80,
              child: Row(
                children: [
                  Expanded(
                    child: _buildBottomNavItem(
                      icon: Icons.gps_fixed,
                      label: 'Targets',
                      isActive: false,
                      onTap: () => _navigateTo(0),
                    ),
                  ),
                  Expanded(
                    child: _buildBottomNavItem(
                      icon: Icons.group_outlined,
                      label: 'Contacts',
                      isActive: false,
                      onTap: () => _navigateTo(3),
                    ),
                  ),
                  SizedBox(
                    width: 78,
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(0, -16),
                        child: InkWell(
                          onTap: () => _navigateTo(2),
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: _primary,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x80000000),
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.qr_code_scanner_rounded,
                                  size: 30,
                                  color: _onPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Scan',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                  color: _primary,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildBottomNavItem(
                      icon: Icons.event,
                      label: 'Events',
                      isActive: true,
                      filled: true,
                      onTap: () => _navigateTo(1),
                    ),
                  ),
                  Expanded(
                    child: _buildBottomNavItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Profile',
                      isActive: false,
                      onTap: () => _navigateTo(5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final color = isActive ? _primary : _outline;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
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
