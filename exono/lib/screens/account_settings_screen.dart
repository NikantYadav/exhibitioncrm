import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_header.dart';
import '../widgets/app_input.dart';
import '../widgets/app_section_label.dart';
import '../widgets/skeleton_loader.dart';
import '../utils/screen_logger.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> with ScreenLogger {
  ExonoColors get _c => AppTheme.colorsOf(context);

  bool _editing = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _designationCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _linkedinCtrl;
  late TextEditingController _productsCtrl;
  late TextEditingController _contextCtrl;
  String _aiTone = 'professional';
  bool _isSavingProfile = false;
  bool _isLoggingOut = false;

  static const _toneOptions = ['professional', 'casual', 'formal', 'friendly'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _designationCtrl = TextEditingController();
    _websiteCtrl = TextEditingController();
    _linkedinCtrl = TextEditingController();
    _productsCtrl = TextEditingController();
    _contextCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _designationCtrl.dispose();
    _websiteCtrl.dispose();
    _linkedinCtrl.dispose();
    _productsCtrl.dispose();
    _contextCtrl.dispose();
    super.dispose();
  }

  void _loadProfile() {
    final auth = context.read<AuthProvider>();
    final p = auth.profile;
    _nameCtrl.text = auth.displayName;
    _designationCtrl.text = p?['designation'] as String? ?? '';
    _websiteCtrl.text = p?['website'] as String? ?? '';
    _linkedinCtrl.text = p?['linkedin_url'] as String? ?? '';
    _productsCtrl.text = p?['products_services'] as String? ?? '';
    _contextCtrl.text = p?['additional_context'] as String? ?? '';
    setState(() => _aiTone = p?['ai_tone'] as String? ?? 'professional');
  }

  void _startEditing() {
    _loadProfile();
    setState(() => _editing = true);
  }

  void _cancelEditing() {
    _loadProfile();
    setState(() => _editing = false);
  }

  static bool _isValidUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

  Future<void> _saveProfile() async {
    if (_isSavingProfile) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showAppToast(context, 'Display name is required.');
      return;
    }
    if (name.length > 100) {
      showAppToast(context, 'Display name must be 100 characters or fewer');
      return;
    }
    final website = _websiteCtrl.text.trim();
    if (website.isNotEmpty && !_isValidUrl(website)) {
      showAppToast(context, 'Website URL must start with http:// or https://');
      return;
    }
    final linkedinUrl = _linkedinCtrl.text.trim();
    if (linkedinUrl.isNotEmpty) {
      if (!_isValidUrl(linkedinUrl)) {
        showAppToast(context, 'LinkedIn URL must start with http:// or https://');
        return;
      }
      if (!linkedinUrl.contains('linkedin.com')) {
        showAppToast(context, 'Please enter a valid LinkedIn URL');
        return;
      }
    }
    setState(() => _isSavingProfile = true);
    try {
      final result = await context.read<AuthProvider>().updateProfile(
            name: name,
            designation: _designationCtrl.text.trim(),
            website: _websiteCtrl.text.trim(),
            linkedinUrl: _linkedinCtrl.text.trim(),
            productsServices: _productsCtrl.text.trim(),
            additionalContext: _contextCtrl.text.trim(),
            aiTone: _aiTone,
          );
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() => _editing = false);
        showAppToast(context, 'Profile saved.');
      } else {
        showAppToast(context, result['error'] as String? ?? 'Failed to save profile.');
      }
    } finally {
      if (mounted) { setState(() => _isSavingProfile = false); }
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    context.go('/auth');
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.profile == null || auth.user == null;

    return ColoredBox(
      color: context.theme.colors.background,
      child: SafeArea(
        bottom: false,
        child: isLoading ? _buildSkeleton() : _buildBody(auth),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _c.navBackground,
        border: Border(bottom: BorderSide(color: context.theme.colors.border)),
      ),
      child: Row(
        children: [
          AppHeaderActionButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => context.go('/'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Settings',
              style: context.theme.typography.lg.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: context.theme.colors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AuthProvider auth) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIdentityCard(auth),
                    const SizedBox(height: 24),
                    AppSectionLabel('Profile'),
                    const SizedBox(height: 10),
                    _editing ? _buildEditPanel(auth) : _buildViewPanel(auth),
                    const SizedBox(height: 24),
                    AppSectionLabel('Preferences'),
                    const SizedBox(height: 10),
                    _buildAppearancePanel(),
                    const SizedBox(height: 24),
                    AppSectionLabel('Session'),
                    const SizedBox(height: 10),
                    _buildSessionPanel(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Identity card ───────────────────────────────────────────────────────────

  Widget _buildIdentityCard(AuthProvider auth) {
    final email = auth.user?['email'] as String? ?? '';
    final profileType = (auth.profile?['profile_type'] as String? ?? 'individual')
        .replaceAll('_', ' ');
    final tone = auth.profile?['ai_tone'] as String? ?? 'professional';

    return AppCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppAvatar(initials: auth.initials, size: 56),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.displayName,
                  style: context.theme.typography.xl.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: context.theme.colors.foreground,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (auth.designation.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    auth.designation,
                    style: context.theme.typography.sm.copyWith(
                      fontWeight: FontWeight.w500,
                      color: context.theme.colors.mutedForeground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: context.theme.typography.xs.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AppChip.status(profileType.toUpperCase(), color: _c.accent),
                    AppChip.status('TONE: ${tone.toUpperCase()}', color: _c.accentStrong),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AI nudge banner (shared) ────────────────────────────────────────────────

  Widget _aiNudge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _c.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _c.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 15, color: _c.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Completing your profile helps the AI generate personalised responses, emails, and follow-ups in your voice.',
              style: context.theme.typography.xs.copyWith(height: 1.5, color: _c.accent),
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile VIEW mode ───────────────────────────────────────────────────────

  Widget _buildViewPanel(AuthProvider auth) {
    final p = auth.profile;
    final name = auth.displayName;
    final designation = p?['designation'] as String? ?? '';
    final website = p?['website'] as String? ?? '';
    final linkedin = p?['linkedin_url'] as String? ?? '';
    final products = p?['products_services'] as String? ?? '';
    final additionalContext = p?['additional_context'] as String? ?? '';
    final tone = p?['ai_tone'] as String? ?? 'professional';

    final hasContent = designation.isNotEmpty || website.isNotEmpty ||
        linkedin.isNotEmpty || products.isNotEmpty ||
        additionalContext.isNotEmpty;

    return AppCard(
      radius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _aiNudge(),
          const SizedBox(height: 16),

          if (!hasContent) ...[
            _emptyProfileHint(),
          ] else ...[
            ..._stripeRows([
              _viewRow('Name', name),
              if (designation.isNotEmpty) _viewRow('Designation', designation),
              if (website.isNotEmpty) _viewRow('Website', website, isLink: true),
              if (linkedin.isNotEmpty) _viewRow('LinkedIn', linkedin, isLink: true),
              if (products.isNotEmpty) _viewRow('Products & Services', products, multiLine: true),
              if (additionalContext.isNotEmpty) _viewRow('Additional AI Context', additionalContext, multiLine: true),
              _viewRow('AI Tone', tone[0].toUpperCase() + tone.substring(1)),
            ]),
          ],

          const SizedBox(height: 16),
          AppButton(
            label: hasContent ? 'EDIT PROFILE' : 'COMPLETE PROFILE',
            onPressed: _startEditing,
            variant: ButtonVariant.secondary,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _emptyProfileHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No profile info yet',
            style: context.theme.typography.sm.copyWith(
              fontWeight: FontWeight.w600,
              color: context.theme.colors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add your details to unlock personalised AI-generated emails, follow-ups, and conversation suggestions.',
            style: context.theme.typography.sm.copyWith(
              height: 1.5,
              color: context.theme.colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _stripeRows(List<Widget> rows) {
    return [
      for (var i = 0; i < rows.length; i++)
        Container(
          decoration: i.isOdd ? BoxDecoration(color: _c.surfaceAlt, borderRadius: BorderRadius.circular(10)) : null,
          child: rows[i],
        ),
    ];
  }

  Widget _viewRow(String label, String value, {bool isLink = false, bool multiLine = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Row(
        crossAxisAlignment: multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: context.theme.typography.xs.copyWith(
                fontWeight: FontWeight.w600,
                color: context.theme.colors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.theme.typography.sm.copyWith(
                height: multiLine ? 1.5 : 1.0,
                color: isLink ? _c.accent : context.theme.colors.foreground,
                decoration: isLink ? TextDecoration.underline : null,
                decorationColor: isLink ? _c.accent.withValues(alpha: 0.4) : null,
              ),
              maxLines: multiLine ? 3 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile EDIT mode ───────────────────────────────────────────────────────

  Widget _buildEditPanel(AuthProvider auth) {
    return AppCard(
      radius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _aiNudge(),
          const SizedBox(height: 20),
          _field(label: 'Display Name', ctrl: _nameCtrl, hint: 'Your full name', required: true),
          _gap(),
          _field(label: 'Designation', ctrl: _designationCtrl, hint: 'e.g. Co-Founder & CEO'),
          _gap(),
          _field(label: 'Website', ctrl: _websiteCtrl, hint: 'https://yoursite.com', keyboard: TextInputType.url),
          _gap(),
          _field(label: 'LinkedIn URL', ctrl: _linkedinCtrl, hint: 'https://linkedin.com/in/...', keyboard: TextInputType.url),
          _gap(),
          _field(label: 'Products & Services', ctrl: _productsCtrl, hint: 'What you offer...', lines: 3),
          _gap(),
          _field(label: 'Additional Context for AI', ctrl: _contextCtrl, hint: 'Extra context for personalised AI responses...', lines: 3),
          _gap(),
          _tonePicker(),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'CANCEL',
                  onPressed: _isSavingProfile ? null : _cancelEditing,
                  variant: ButtonVariant.outline,
                  fullWidth: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: 'SAVE PROFILE',
                  onPressed: _isSavingProfile ? null : _saveProfile,
                  isLoading: _isSavingProfile,
                  fullWidth: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tonePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI TONE',
          style: context.theme.typography.xs.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: context.theme.colors.mutedForeground,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _toneOptions.map((tone) {
            final active = _aiTone == tone;
            return GestureDetector(
              onTap: () => setState(() => _aiTone = tone),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: active ? _c.accent : _c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? _c.accent : context.theme.colors.border,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  tone[0].toUpperCase() + tone.substring(1),
                  style: context.theme.typography.xs.copyWith(
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : context.theme.colors.foreground,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Appearance panel ────────────────────────────────────────────────────────

  Widget _buildAppearancePanel() {
    return AppCard(
      radius: 20,
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => _switchRow(
          icon: Icons.dark_mode_rounded,
          title: 'Dark Mode',
          subtitle: theme.isDarkMode ? 'Using dark surfaces.' : 'Using light surfaces.',
          value: theme.isDarkMode,
          onChanged: (v) => theme.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
        ),
      ),
    );
  }

  // ── Session panel ───────────────────────────────────────────────────────────

  Widget _buildSessionPanel() {
    return AppCard(
      radius: 20,
      child: _actionRow(
        icon: Icons.logout_rounded,
        label: 'Log Out',
        sublabel: 'Clear session and return to auth.',
        destructive: true,
        loading: _isLoggingOut,
        onTap: _logout,
      ),
    );
  }

  // ── Row components ──────────────────────────────────────────────────────────

  Widget _switchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _c.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: _c.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.typography.sm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.theme.colors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.theme.typography.xs.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FSwitch(
            value: value,
            onChange: onChanged,
            style: FSwitchStyleDelta.delta(
              trackColor: FVariantsValueDelta.delta([
                FVariantValueDeltaOperation.base(context.theme.colors.border),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    required String sublabel,
    required VoidCallback onTap,
    bool destructive = false,
    bool loading = false,
  }) {
    final color = destructive ? _c.destructive : _c.accent;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: loading
                  ? SizedBox(width: 16, height: 16, child: FCircularProgress())
                  : Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.typography.sm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.typography.xs.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: _c.accent),
          ],
        ),
      ),
    );
  }

  // ── Form helpers ────────────────────────────────────────────────────────────

  Widget _gap() => const SizedBox(height: 14);

  Widget _field({
    required String label,
    required TextEditingController ctrl,
    String? hint,
    bool required = false,
    int lines = 1,
    TextInputType? keyboard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '${label.toUpperCase()} *' : label.toUpperCase(),
          style: context.theme.typography.xs.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: context.theme.colors.mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        AppInput(
          controller: ctrl,
          hint: hint,
          maxLines: lines,
          keyboardType: keyboard,
        ),
      ],
    );
  }

  // ── Skeleton ────────────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return Column(
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _c.navBackground,
            border: Border(bottom: BorderSide(color: context.theme.colors.border)),
          ),
          child: Row(
            children: [
              SkeletonLoader(width: 40, height: 40, borderRadius: BorderRadius.circular(10)),
              const SizedBox(width: 12),
              SkeletonLoader(width: 80, height: 16, borderRadius: BorderRadius.circular(4)),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  radius: 28,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      SkeletonLoader(width: 56, height: 56, borderRadius: BorderRadius.circular(12)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLoader(width: 160, height: 18, borderRadius: BorderRadius.circular(5)),
                            const SizedBox(height: 6),
                            SkeletonLoader(width: 110, height: 12, borderRadius: BorderRadius.circular(4)),
                            const SizedBox(height: 6),
                            SkeletonLoader(width: 140, height: 12, borderRadius: BorderRadius.circular(4)),
                            const SizedBox(height: 12),
                            Row(children: [
                              SkeletonLoader(width: 80, height: 22, borderRadius: BorderRadius.circular(4)),
                              const SizedBox(width: 6),
                              SkeletonLoader(width: 100, height: 22, borderRadius: BorderRadius.circular(4)),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SkeletonLoader(width: 60, height: 11, borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: 10),
                AppCard(
                  radius: 20,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      SkeletonLoader(width: double.infinity, height: 44, borderRadius: BorderRadius.circular(12)),
                      const SizedBox(height: 12),
                      ...List.generate(5, (_) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          SkeletonLoader(width: 120, height: 13, borderRadius: BorderRadius.circular(4)),
                          const SizedBox(width: 16),
                          Expanded(child: SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4))),
                        ]),
                      )),
                      const SizedBox(height: 8),
                      SkeletonLoader(width: double.infinity, height: 44, borderRadius: BorderRadius.circular(999)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SkeletonLoader(width: 90, height: 11, borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: 10),
                AppCard(
                  radius: 20,
                  padding: const EdgeInsets.all(16),
                  child: SkeletonLoader(width: double.infinity, height: 56, borderRadius: BorderRadius.circular(12)),
                ),
                const SizedBox(height: 24),
                SkeletonLoader(width: 65, height: 11, borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: 10),
                AppCard(
                  radius: 20,
                  padding: const EdgeInsets.all(16),
                  child: SkeletonLoader(width: double.infinity, height: 56, borderRadius: BorderRadius.circular(12)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
