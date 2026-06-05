import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class MeetingsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const MeetingsScreen({super.key, this.onNavigateTab});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  late final List<_MeetingItem> _meetings = [
    const _MeetingItem(
      title: 'Operations Sync • Atlas Manufacturing',
      company: 'Atlas Manufacturing',
      timeLabel: 'Today • 11:30 AM – 12:00 PM',
      location: 'Private Meeting Suite B2',
      status: 'Today',
      priority: 'High Priority',
      owner: 'Julianne De Marco',
      objective:
          'Confirm whether Atlas is ready for an ERP modernization pilot before the Q4 procurement review.',
      note:
          'Marcus highlighted legacy workflow friction during the floor conversation. Keep the discussion focused on rollout risk, interoperability, and executive visibility.',
      attendees: ['JD', 'MV', 'AR'],
      prepItems: [
        'Review the Atlas modernization timeline captured during CES.',
        'Lead with the manufacturing workflow visibility angle, not feature breadth.',
        'Have the one-page integration summary ready to share after the meeting.',
      ],
      followUpTask: 'Send Atlas pilot scope memo by 4:00 PM.',
    ),
    const _MeetingItem(
      title: 'Revenue Brief • Altis Cloud',
      company: 'Altis Cloud',
      timeLabel: 'Today • 2:00 PM – 2:45 PM',
      location: 'Lounge 4 • Revenue Leaders Forum',
      status: 'Needs Prep',
      priority: 'Medium Priority',
      owner: 'Sophia Reed',
      objective:
          'Frame EXONO as the fastest path to rep onboarding consistency across the next hiring cycle.',
      note:
          'Sophia cares about enablement speed and reporting consistency. Bring proof points, but keep the meeting concise and operational.',
      attendees: ['SR', 'AK'],
      prepItems: [
        'Pull the 18% ramp-time reduction story into the opening narrative.',
        'Mention the guided enablement workflow only after confirming current onboarding friction.',
        'Prepare two follow-up options: one-pager and 15-minute operator walkthrough.',
      ],
      followUpTask:
          'Draft onboarding consistency follow-up immediately after the brief.',
    ),
    const _MeetingItem(
      title: 'Partner Strategy • Vertex Grid',
      company: 'Vertex Grid',
      timeLabel: 'Tomorrow • 9:15 AM – 9:45 AM',
      location: 'Hotel lobby breakout table',
      status: 'Scheduled',
      priority: 'Partnership',
      owner: 'Amir Khan',
      objective:
          'Explore whether Vertex wants a co-sell workflow pilot with regional ownership tracking.',
      note:
          'Amir responded well to concise co-sell language. Keep the conversation commercial and avoid long platform walkthroughs.',
      attendees: ['AK', 'LM'],
      prepItems: [
        'Bring one partner-coordination example from the energy sector.',
        'Clarify how partner visibility changes once opportunities split by region.',
        'Have the co-sell dashboard mock ready if he asks for specifics.',
      ],
      followUpTask: 'Send co-sell workflow mockup if interest is confirmed.',
    ),
  ];

  int _selectedIndex = 0;
  bool _showCompleted = false;

  _MeetingItem get _selectedMeeting => _meetings[_selectedIndex];

  void _showUiOnlyMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;

          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(isMobile),
                const SizedBox(height: 20),
                _buildMetricRow(isMobile),
                const SizedBox(height: 20),
                if (isMobile)
                  Column(
                    children: [
                      _buildMeetingQueue(),
                      const SizedBox(height: 16),
                      _buildMeetingDetail(),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 360, child: _buildMeetingQueue()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildMeetingDetail()),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroCard(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.stone200.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.stone900,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'MEETINGS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.stone100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _showCompleted ? 'INCLUDING COMPLETED' : 'ACTIVE ONLY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppTheme.stone700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Stay ahead of every high-signal conversation.',
            style: TextStyle(
              fontSize: isMobile ? 26 : 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: AppTheme.stone900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Track upcoming meetings, prep the next discussion block, and keep follow-up actions tied to the right relationship context.',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppTheme.stone500,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroAction(
                label: 'Open Follow-Ups',
                icon: Icons.mark_email_unread_outlined,
                onTap: () => widget.onNavigateTab?.call(4),
              ),
              _buildHeroAction(
                label: 'View Contacts',
                icon: Icons.group_outlined,
                onTap: () => widget.onNavigateTab?.call(3),
              ),
              _buildHeroAction(
                label: _showCompleted ? 'Hide Completed' : 'Show Completed',
                icon: _showCompleted
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                onTap: () {
                  setState(() => _showCompleted = !_showCompleted);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroAction({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.stone50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.stone200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppTheme.stone800),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.stone800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(bool isMobile) {
    final cards = [
      _MetricCardData('Today', '2', 'Critical conversations scheduled'),
      _MetricCardData('This Week', '7', 'Meetings currently tracked'),
      _MetricCardData('Needs Prep', '3', 'Require prep before start'),
      _MetricCardData('Follow-Up Due', '4', 'Actions waiting after meetings'),
    ];

    if (isMobile) {
      return Column(
        children: cards
            .map(
              (card) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMetricCard(card),
              ),
            )
            .toList(),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: _buildMetricCard(cards[i])),
          if (i < cards.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Widget _buildMetricCard(_MetricCardData card) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.stone200.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: AppTheme.stone500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            card.value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: AppTheme.stone900,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            card.caption,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppTheme.stone500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingQueue() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.stone200.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Meeting Queue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.stone900,
                ),
              ),
              const Spacer(),
              Text(
                '${_meetings.length} scheduled',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.stone500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(_meetings.length, (index) {
            final meeting = _meetings[index];
            final isSelected = index == _selectedIndex;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _meetings.length - 1 ? 0 : 12,
              ),
              child: InkWell(
                onTap: () => setState(() => _selectedIndex = index),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.stone900 : AppTheme.stone50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppTheme.stone900 : AppTheme.stone200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              meeting.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.stone900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildStatusPill(
                            meeting.status,
                            isSelected: isSelected,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        meeting.timeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.78)
                              : AppTheme.stone600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        meeting.location,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppTheme.stone500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMeetingDetail() {
    final meeting = _selectedMeeting;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.stone200.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.company.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppTheme.stone500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      meeting.title,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: AppTheme.stone900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      meeting.timeLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.stone700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meeting.location,
                      style: TextStyle(fontSize: 14, color: AppTheme.stone500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusPill(meeting.priority),
                  const SizedBox(height: 8),
                  Text(
                    'Owner: ${meeting.owner}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.stone500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailBlock(
            'Meeting Objective',
            meeting.objective,
            emphasize: true,
          ),
          const SizedBox(height: 16),
          _buildDetailBlock('Context Note', meeting.note),
          const SizedBox(height: 16),
          Text(
            'Attendees'.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppTheme.stone500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: meeting.attendees
                .map((attendee) => _buildAttendeeChip(attendee))
                .toList(),
          ),
          const SizedBox(height: 20),
          Text(
            'Prep Checklist'.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppTheme.stone500,
            ),
          ),
          const SizedBox(height: 10),
          ...meeting.prepItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.stone900,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppTheme.stone700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.stone50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.stone200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Follow-up Task'.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppTheme.stone500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  meeting.followUpTask,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.stone900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    _showUiOnlyMessage('Prep checklist marked complete.'),
                icon: const Icon(Icons.task_alt_rounded, size: 18),
                label: const Text('MARK PREPPED'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.stone900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => widget.onNavigateTab?.call(4),
                icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
                label: const Text('OPEN FOLLOW-UPS'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.stone800,
                  side: BorderSide(color: AppTheme.stone300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _showUiOnlyMessage('Meeting logging is UI-only for now.'),
                icon: const Icon(Icons.note_add_outlined, size: 18),
                label: const Text('LOG OUTCOME'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.stone800,
                  side: BorderSide(color: AppTheme.stone300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String label, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white.withValues(alpha: 0.12)
            : AppTheme.stone100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: isSelected ? Colors.white : AppTheme.stone700,
        ),
      ),
    );
  }

  Widget _buildDetailBlock(
    String title,
    String body, {
    bool emphasize = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppTheme.stone500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: TextStyle(
            fontSize: emphasize ? 15 : 14,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            height: 1.55,
            color: emphasize ? AppTheme.stone900 : AppTheme.stone700,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendeeChip(String attendee) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.stone50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stone200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.stone900,
            child: Text(
              attendee,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            attendee,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.stone800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingItem {
  final String title;
  final String company;
  final String timeLabel;
  final String location;
  final String status;
  final String priority;
  final String owner;
  final String objective;
  final String note;
  final List<String> attendees;
  final List<String> prepItems;
  final String followUpTask;

  const _MeetingItem({
    required this.title,
    required this.company,
    required this.timeLabel,
    required this.location,
    required this.status,
    required this.priority,
    required this.owner,
    required this.objective,
    required this.note,
    required this.attendees,
    required this.prepItems,
    required this.followUpTask,
  });
}

class _MetricCardData {
  final String label;
  final String value;
  final String caption;

  const _MetricCardData(this.label, this.value, this.caption);
}
