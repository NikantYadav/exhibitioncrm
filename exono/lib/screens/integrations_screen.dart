import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../config/app_theme.dart';
import '../widgets/skeleton_loader.dart';
import '../utils/screen_logger.dart';

class IntegrationsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const IntegrationsScreen({super.key, this.onNavigateTab});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> with ScreenLogger {
  bool _isLoading = true;

  late final List<_IntegrationItem> _integrations = [
    const _IntegrationItem(
      id: 'calendar',
      title: 'Calendar Sync',
      vendor: 'Google Calendar',
      category: 'Scheduling',
      description:
          'Keep meetings, prep windows, and follow-up holds aligned with your live calendar.',
      status: _IntegrationStatus.connected,
      primaryMetric: '18 events synced',
      secondaryMetric: 'Last sync 4 min ago',
      icon: Icons.calendar_today_rounded,
    ),
    const _IntegrationItem(
      id: 'crm',
      title: 'CRM Mirror',
      vendor: 'Salesforce',
      category: 'Pipeline',
      description:
          'Mirror contact, account, and opportunity context into the event-day mobile workflow.',
      status: _IntegrationStatus.warning,
      primaryMetric: '2 field conflicts',
      secondaryMetric: 'Sync review needed',
      icon: Icons.hub_rounded,
    ),
    const _IntegrationItem(
      id: 'messaging',
      title: 'Team Messaging',
      vendor: 'Slack',
      category: 'Collaboration',
      description:
          'Push meeting outcomes, lead captures, and follow-up drafts into your operating channels.',
      status: _IntegrationStatus.connected,
      primaryMetric: '3 channels mapped',
      secondaryMetric: 'Draft alerts live',
      icon: Icons.forum_rounded,
    ),
    const _IntegrationItem(
      id: 'voice',
      title: 'Voice Notes Archive',
      vendor: 'Notion',
      category: 'Knowledge',
      description:
          'Store structured summaries from voice capture and post-event notes in one workspace.',
      status: _IntegrationStatus.disconnected,
      primaryMetric: 'Not connected',
      secondaryMetric: 'Ready to map pages',
      icon: Icons.mic_external_on_rounded,
    ),
  ];

  late final Map<String, bool> _autoSyncEnabled = {
    'calendar': true,
    'crm': true,
    'messaging': true,
    'voice': false,
  };

  int _selectedIndex = 0;
  bool _notifyOnConflict = true;
  bool _pushMeetingOutcomes = true;
  bool _syncOnlyOnWifi = false;

  @override
  void initState() {
    super.initState();
    // Simulate loading
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  _IntegrationItem get _selectedIntegration => _integrations[_selectedIndex];

  void _showUiOnlyMessage(String message) {
    showFToast(context: context, title: Text(message));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 960;
          return SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(isMobile),
                const SizedBox(height: 20),
                _buildMetricRow(isMobile),
                const SizedBox(height: 20),
                if (_isLoading)
                  _buildLoadingGrid(isMobile: isMobile)
                else if (isMobile)
                  Column(
                    children: [
                      _buildIntegrationGrid(singleColumn: true),
                      const SizedBox(height: 16),
                      _buildSelectedIntegrationPanel(),
                      const SizedBox(height: 16),
                      _buildAutomationPanel(),
                      const SizedBox(height: 16),
                      _buildActivityPanel(),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 11,
                        child: Column(
                          children: [
                            _buildIntegrationGrid(singleColumn: false),
                            const SizedBox(height: 16),
                            _buildActivityPanel(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 8,
                        child: Column(
                          children: [
                            _buildSelectedIntegrationPanel(),
                            const SizedBox(height: 16),
                            _buildAutomationPanel(),
                          ],
                        ),
                      ),
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
                  'INTEGRATIONS',
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
                  'UI-ONLY CONTROL CENTER',
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
            'Connect the operating systems behind your event workflow.',
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
            'Review sync health, resolve high-signal conflicts, and decide which external systems should feed the mobile CRM shell.',
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
                label: 'Open Meetings',
                icon: Icons.event_note_rounded,
                onTap: () => widget.onNavigateTab?.call(6),
              ),
              _buildHeroAction(
                label: 'Open Contacts',
                icon: Icons.people_outline_rounded,
                onTap: () => widget.onNavigateTab?.call(3),
              ),
              _buildHeroAction(
                label: 'Run Health Check',
                icon: Icons.health_and_safety_outlined,
                onTap: () => _showUiOnlyMessage(
                  'Integration health check completed. No live backend actions were triggered.',
                ),
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
            Icon(icon, size: 18, color: AppTheme.colorsOf(context).accent),
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
      _MetricCardData('Connected', '3', 'Systems currently active'),
      _MetricCardData('Warnings', '1', 'Conflict path needs review'),
      _MetricCardData('Auto-Sync', '3', 'Connectors pushing updates'),
      _MetricCardData('Pending', '2', 'Manual approvals remaining'),
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

  Widget _buildIntegrationGrid({required bool singleColumn}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = singleColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(_integrations.length, (index) {
            final integration = _integrations[index];
            final isSelected = index == _selectedIndex;
            final autoSync = _autoSyncEnabled[integration.id] ?? false;

            return SizedBox(
              width: width,
              child: InkWell(
                onTap: () => setState(() => _selectedIndex = index),
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.stone900 : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? AppTheme.stone900 : AppTheme.stone200,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.stone900.withValues(alpha: 0.12),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : AppTheme.stone100,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              integration.icon,
                              size: 20,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.colorsOf(context).accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  integration.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.stone900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${integration.vendor} • ${integration.category}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.78)
                                        : AppTheme.stone500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildStatusPill(
                            integration.status,
                            isSelected: isSelected,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        integration.description,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.82)
                              : AppTheme.stone600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildMetricLine(
                        label: integration.primaryMetric,
                        isSelected: isSelected,
                      ),
                      const SizedBox(height: 6),
                      _buildMetricLine(
                        label: integration.secondaryMetric,
                        isSelected: isSelected,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              autoSync
                                  ? 'Auto-sync enabled'
                                  : 'Manual sync only',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.84)
                                    : AppTheme.stone700,
                              ),
                            ),
                          ),
                          FSwitch(
                            value: autoSync,
                            onChange: (value) {
                              setState(() => _autoSyncEnabled[integration.id] = value);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildMetricLine({required String label, required bool isSelected}) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : AppTheme.stone900,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.8)
                  : AppTheme.stone600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedIntegrationPanel() {
    final integration = _selectedIntegration;
    final autoSync = _autoSyncEnabled[integration.id] ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.stone200.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Integration Detail'.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppTheme.stone500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            integration.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: AppTheme.stone900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${integration.vendor} • ${integration.category}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.stone600,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusPill(integration.status),
          const SizedBox(height: 16),
          _buildDetailBlock('Summary', integration.description),
          const SizedBox(height: 16),
          _buildDetailBlock('Current Health', integration.primaryMetric),
          const SizedBox(height: 16),
          _buildDetailBlock('Latest Sync', integration.secondaryMetric),
          const SizedBox(height: 16),
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
                  'Sync Mode'.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppTheme.stone500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  autoSync ? 'Auto-sync enabled' : 'Manual sync only',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.stone900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FButton(variant: FButtonVariant.primary, 
                onPress: () => _showUiOnlyMessage(
                  '${integration.title} sync triggered. This is a UI-only preview.',
                ),
                prefix: Icon(Icons.sync_rounded, size: 18, color: Colors.white),
                child: const Text('RUN SYNC'),
              ),
              FButton(variant: FButtonVariant.outline, 
                onPress: () => _showUiOnlyMessage(
                  '${integration.title} configuration opened. Editing is UI-only for now.',
                ),
                prefix: Icon(Icons.settings_outlined, size: 18, color: AppTheme.colorsOf(context).accent),
                child: const Text('CONFIGURE'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutomationPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.stone200.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Automation Rules'.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppTheme.stone500,
            ),
          ),
          const SizedBox(height: 14),
          _buildPreferenceTile(
            title: 'Notify on sync conflicts',
            subtitle:
                'Surface field mismatches before event-day edits overwrite source systems.',
            value: _notifyOnConflict,
            onChanged: (value) => setState(() => _notifyOnConflict = value),
          ),
          const SizedBox(height: 10),
          _buildPreferenceTile(
            title: 'Push meeting outcomes to messaging',
            subtitle:
                'Send meeting summaries and follow-up tasks into team channels automatically.',
            value: _pushMeetingOutcomes,
            onChanged: (value) => setState(() => _pushMeetingOutcomes = value),
          ),
          const SizedBox(height: 10),
          _buildPreferenceTile(
            title: 'Sync only on Wi-Fi',
            subtitle:
                'Reduce heavy background sync while working in low-connectivity event spaces.',
            value: _syncOnlyOnWifi,
            onChanged: (value) => setState(() => _syncOnlyOnWifi = value),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.stone50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.stone200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.stone900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppTheme.stone600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FSwitch(
            value: value,
            onChange: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityPanel() {
    final activities = [
      const _IntegrationActivity(
        title: 'Salesforce sync flagged 2 conflicts',
        subtitle: 'Company owner field differs for Atlas Manufacturing.',
        timeLabel: '8 min ago',
        icon: Icons.warning_amber_rounded,
      ),
      const _IntegrationActivity(
        title: 'Google Calendar imported event prep block',
        subtitle:
            'Operations Sync prep buffer added ahead of the 11:30 meeting.',
        timeLabel: '24 min ago',
        icon: Icons.calendar_today_rounded,
      ),
      const _IntegrationActivity(
        title: 'Slack draft alert delivered',
        subtitle: 'Revenue follow-up draft pushed to #field-ops for review.',
        timeLabel: '41 min ago',
        icon: Icons.forum_rounded,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.stone200.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity'.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppTheme.stone500,
            ),
          ),
          const SizedBox(height: 14),
          ...activities.asMap().entries.map((entry) {
            final isLast = entry.key == activities.length - 1;
            final activity = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.stone100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      activity.icon,
                      size: 18,
                      color: activity.icon == Icons.warning_amber_rounded
                          ? AppTheme.stone800
                          : AppTheme.colorsOf(context).accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.stone900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activity.subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppTheme.stone600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    activity.timeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.stone500,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusPill(
    _IntegrationStatus status, {
    bool isSelected = false,
  }) {
    late final String label;
    late final Color textColor;
    late final Color backgroundColor;

    switch (status) {
      case _IntegrationStatus.connected:
        label = 'Connected';
        textColor = isSelected ? Colors.white : AppTheme.stone800;
        backgroundColor = isSelected
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFEDEDEB);
      case _IntegrationStatus.warning:
        label = 'Needs Review';
        textColor = isSelected ? Colors.white : AppTheme.stone800;
        backgroundColor = isSelected
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFF4EFE8);
      case _IntegrationStatus.disconnected:
        label = 'Disconnected';
        textColor = isSelected ? Colors.white : AppTheme.stone700;
        backgroundColor = isSelected
            ? Colors.white.withValues(alpha: 0.12)
            : AppTheme.stone100;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildDetailBlock(String title, String body) {
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
            fontSize: 14,
            height: 1.55,
            color: AppTheme.stone700,
          ),
        ),
      ],
    );
    }

    Widget _buildLoadingGrid({required bool isMobile}) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final singleColumn = isMobile;
          final width = singleColumn
              ? constraints.maxWidth
              : (constraints.maxWidth - 12) / 2;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(4, (index) {
              return SizedBox(
                width: width,
                child: _buildIntegrationSkeleton(),
              );
            }),
          );
        },
      );
    }

    Widget _buildIntegrationSkeleton() {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.stone200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  width: 44,
                  height: 44,
                  borderRadius: BorderRadius.circular(14),
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
                      const SizedBox(height: 8),
                      SkeletonLoader(
                        width: 120,
                        height: 12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
                SkeletonLoader(
                  width: 80,
                  height: 24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SkeletonLoader(
              width: double.infinity,
              height: 13,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            SkeletonLoader(
              width: double.infinity,
              height: 13,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            SkeletonLoader(
              width: 180,
              height: 13,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                SkeletonLoader(
                  width: 6,
                  height: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SkeletonLoader(
                    width: double.infinity,
                    height: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SkeletonLoader(
                  width: 6,
                  height: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SkeletonLoader(
                    width: double.infinity,
                    height: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SkeletonLoader(
                    width: double.infinity,
                    height: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                SkeletonLoader(
                  width: 51,
                  height: 31,
                  borderRadius: BorderRadius.circular(16),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  enum _IntegrationStatus { connected, warning, disconnected }

class _IntegrationItem {
  final String id;
  final String title;
  final String vendor;
  final String category;
  final String description;
  final _IntegrationStatus status;
  final String primaryMetric;
  final String secondaryMetric;
  final IconData icon;

  const _IntegrationItem({
    required this.id,
    required this.title,
    required this.vendor,
    required this.category,
    required this.description,
    required this.status,
    required this.primaryMetric,
    required this.secondaryMetric,
    required this.icon,
  });
}

class _MetricCardData {
  final String label;
  final String value;
  final String caption;

  const _MetricCardData(this.label, this.value, this.caption);
}

class _IntegrationActivity {
  final String title;
  final String subtitle;
  final String timeLabel;
  final IconData icon;

  const _IntegrationActivity({
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.icon,
  });
}
