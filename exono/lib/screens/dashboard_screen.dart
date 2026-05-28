import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';

/// Dashboard screen replicating CRM frontend with backend integration
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getDashboardSummary();
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.stone900),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.stone400),
            const SizedBox(height: 16),
            Text(
              'Failed to load dashboard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.stone900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(fontSize: 12, color: AppTheme.stone500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchDashboardData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final summary = _dashboardData?['summary'] ?? {};
    final upcomingMeetings = _dashboardData?['upcomingMeetings'] ?? [];
    final recentActivity = _dashboardData?['recentActivity'] ?? [];

    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.stone900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'YOUR NETWORK SUMMARY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.stone400,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                if (!isMobile)
                  Row(
                    children: [
                      _buildActionButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'CAPTURE',
                        onTap: () {},
                      ),
                      const SizedBox(width: 12),
                      _buildActionButton(
                        icon: Icons.add_rounded,
                        label: 'NEW MEETING',
                        onTap: () {},
                        isPrimary: true,
                      ),
                    ],
                  ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Performance Metrics
            GridView.count(
              crossAxisCount: isMobile ? 2 : 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: isMobile ? 1.5 : 2.5,
              children: [
                _buildStatCard(
                  icon: Icons.flag_rounded,
                  label: 'Target Companies',
                  value: summary['targets']?.toString() ?? '0',
                ),
                _buildStatCard(
                  icon: Icons.camera_alt_rounded,
                  label: 'Total Scans',
                  value: summary['captured']?.toString() ?? '0',
                ),
                _buildStatCard(
                  icon: Icons.check_circle_rounded,
                  label: 'Enriched Profiles',
                  value: summary['enriched']?.toString() ?? '0',
                ),
                _buildStatCard(
                  icon: Icons.schedule_rounded,
                  label: 'Follow-ups Due',
                  value: summary['drafts']?.toString() ?? '0',
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Timeline and Activity Feed
            if (isMobile)
              Column(
                children: [
                  _buildTimelineSection(upcomingMeetings),
                  const SizedBox(height: 24),
                  _buildActivityFeedSection(recentActivity),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTimelineSection(upcomingMeetings),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: _buildActivityFeedSection(recentActivity),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.stone900 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? AppTheme.stone900 : AppTheme.stone200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isPrimary ? AppTheme.stone900 : Colors.black)
                  .withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isPrimary ? Colors.white : AppTheme.stone900,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: isPrimary ? Colors.white : AppTheme.stone900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.stone100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.stone900,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.stone900.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.stone400,
                    letterSpacing: 1.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.stone900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(List<dynamic> meetings) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppTheme.stone100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.stone50.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
              border: Border(
                bottom: BorderSide(color: AppTheme.stone100),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: AppTheme.stone900,
                ),
                const SizedBox(width: 12),
                Text(
                  'TIMELINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.stone900,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Text(
                  'VIEW ALL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.stone900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppTheme.stone900,
                ),
              ],
            ),
          ),
          
          // Content
          Container(
            height: 400,
            padding: const EdgeInsets.all(24),
            child: meetings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.stone50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.stone100),
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            size: 28,
                            color: AppTheme.stone200,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'NO UPCOMING MEETINGS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.stone300,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: meetings.length,
                    itemBuilder: (context, index) {
                      final meeting = meetings[index];
                      return _buildMeetingItem(meeting);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingItem(Map<String, dynamic> meeting) {
    final contact = meeting['contact'];
    final company = contact?['company'];
    final meetingDate = DateTime.parse(meeting['meeting_date']);
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.stone50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.stone100.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.stone900,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${contact?['first_name']?[0] ?? ''}${contact?['last_name']?[0] ?? ''}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${contact?['first_name'] ?? ''} ${contact?['last_name'] ?? ''}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.stone900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  company?['name'] ?? 'No company',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.stone500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeFormat.format(meetingDate),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.stone900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateFormat.format(meetingDate),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.stone500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeedSection(List<dynamic> activities) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppTheme.stone100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.stone50.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
              border: Border(
                bottom: BorderSide(color: AppTheme.stone100),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 16,
                  color: AppTheme.stone900,
                ),
                const SizedBox(width: 12),
                Text(
                  'DAILY FEED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.stone900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Container(
            height: 400,
            padding: const EdgeInsets.all(20),
            child: activities.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 32,
                          color: AppTheme.stone200,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'NO RECENT ACTIVITY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.stone300,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: activities.length,
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      return _buildActivityItem(activity);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final contact = activity['contact'];
    final interactionDate = DateTime.parse(activity['interaction_date']);
    final dateFormat = DateFormat('MMM d');

    IconData activityIcon;
    switch (activity['interaction_type']) {
      case 'capture':
        activityIcon = Icons.camera_alt_rounded;
        break;
      case 'note':
        activityIcon = Icons.message_rounded;
        break;
      case 'meeting':
        activityIcon = Icons.calendar_today_rounded;
        break;
      default:
        activityIcon = Icons.circle_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.stone50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.stone900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${contact?['first_name']?[0] ?? ''}${contact?['last_name']?[0] ?? ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.stone100),
                  ),
                  child: Icon(
                    activityIcon,
                    size: 10,
                    color: AppTheme.stone900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['summary'] ?? '${activity['interaction_type']} recorded',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.stone900,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${contact?['first_name'] ?? ''} ${contact?['last_name'] ?? ''}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.stone400,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      ' • ',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppTheme.stone200,
                      ),
                    ),
                    Text(
                      dateFormat.format(interactionDate),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.stone300,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
