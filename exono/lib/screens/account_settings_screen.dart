import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import 'profile_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _pushNotifications = true;
  bool _dailyDigest = true;
  bool _offlineCaching = true;
  bool _compactMeetingCards = false;
  bool _isLoggingOut = false;

  void _showUiOnlyMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);

    await context.read<AuthProvider>().logout();
    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isMobile = MediaQuery.of(context).size.width < 768;
    final email = auth.user?['email'] as String? ?? 'No email available';
    final profileType = (auth.profile?['profile_type'] as String? ?? 'team')
        .replaceAll('_', ' ')
        .toUpperCase();
    final aiTone = (auth.profile?['ai_tone'] as String? ?? 'professional')
        .toUpperCase();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 20),
                  _buildHeroCard(
                    name: auth.displayName,
                    designation: auth.designation,
                    email: email,
                    profileType: profileType,
                    aiTone: aiTone,
                    initials: auth.initials,
                  ),
                  const SizedBox(height: 16),
                  if (isMobile)
                    Column(
                      children: [
                        _buildPreferencesPanel(),
                        const SizedBox(height: 16),
                        _buildAccountPanel(auth),
                        const SizedBox(height: 16),
                        _buildDangerPanel(),
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
                              _buildPreferencesPanel(),
                              const SizedBox(height: 16),
                              _buildDangerPanel(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(flex: 8, child: _buildAccountPanel(auth)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.stone900,
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Settings',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: AppTheme.stone900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Control your workspace defaults and session preferences.',
              style: TextStyle(fontSize: 13, color: AppTheme.stone500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroCard({
    required String name,
    required String designation,
    required String email,
    required String profileType,
    required String aiTone,
    required String initials,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.stone900,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: AppTheme.stone900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      designation,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppTheme.stone600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email,
                      style: TextStyle(fontSize: 13, color: AppTheme.stone500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBadge(Icons.apartment_rounded, profileType),
              _buildBadge(Icons.psychology_alt_rounded, 'AI TONE: $aiTone'),
              _buildBadge(Icons.verified_rounded, 'SESSION ACTIVE'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.stone100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.stone800),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.stone800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesPanel() {
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
            'Workspace Preferences'.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppTheme.stone500,
            ),
          ),
          const SizedBox(height: 14),
          _buildPreferenceTile(
            title: 'Push notifications',
            subtitle: 'Show event, follow-up, and sync-related alerts.',
            value: _pushNotifications,
            onChanged: (value) => setState(() => _pushNotifications = value),
          ),
          const SizedBox(height: 10),
          _buildPreferenceTile(
            title: 'Daily digest',
            subtitle:
                'Receive a concise morning summary of targets, meetings, and follow-ups.',
            value: _dailyDigest,
            onChanged: (value) => setState(() => _dailyDigest = value),
          ),
          const SizedBox(height: 10),
          _buildPreferenceTile(
            title: 'Offline caching',
            subtitle:
                'Keep priority records available for low-connectivity event spaces.',
            value: _offlineCaching,
            onChanged: (value) => setState(() => _offlineCaching = value),
          ),
          const SizedBox(height: 10),
          _buildPreferenceTile(
            title: 'Compact meeting cards',
            subtitle: 'Use denser summaries in the meetings workspace.',
            value: _compactMeetingCards,
            onChanged: (value) => setState(() => _compactMeetingCards = value),
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
          Switch.adaptive(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: AppTheme.stone900.withValues(alpha: 0.35),
            inactiveThumbColor: AppTheme.stone400,
            inactiveTrackColor: AppTheme.stone200,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountPanel(AuthProvider auth) {
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
            'Account Controls'.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppTheme.stone500,
            ),
          ),
          const SizedBox(height: 14),
          _buildActionTile(
            title: 'Refresh profile snapshot',
            subtitle: 'Pull the latest profile data into the app shell.',
            icon: Icons.refresh_rounded,
            onTap: () async {
              await auth.refreshProfile();
              if (!mounted) return;
              _showUiOnlyMessage('Profile snapshot refreshed.');
            },
          ),
          const SizedBox(height: 10),
          _buildActionTile(
            title: 'Switch experience mode',
            subtitle:
                'Return to mode selection and choose between AI Chat and CRM.',
            icon: Icons.swap_horiz_rounded,
            onTap: () {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/mode-selection', (route) => false);
            },
          ),
          const SizedBox(height: 10),
          _buildActionTile(
            title: 'Manage profile details',
            subtitle:
                'Open your full profile workspace and review live details.',
            icon: Icons.edit_outlined,
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
          const SizedBox(height: 10),
          _buildActionTile(
            title: 'Open default home preview',
            subtitle:
                'Launch the standalone Stitch-style mobile home preview route.',
            icon: Icons.space_dashboard_outlined,
            onTap: () => Navigator.of(context).pushNamed('/home-default'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.stone50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.stone200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 18, color: AppTheme.stone800),
            ),
            const SizedBox(width: 12),
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
            Icon(Icons.chevron_right_rounded, color: AppTheme.stone400),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerPanel() {
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
            'Session'.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppTheme.stone500,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Need to switch account or reset your environment?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.stone900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Logging out will clear the local session and return you to the auth screen.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppTheme.stone600,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoggingOut ? null : _logout,
              icon: _isLoggingOut
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.logout_rounded, size: 18),
              label: Text(_isLoggingOut ? 'SIGNING OUT...' : 'LOG OUT'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.stone900,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
