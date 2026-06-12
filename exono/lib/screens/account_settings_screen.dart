import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_feedback.dart';
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

  // ── Edit mode ───────────────────────────────────────────────────────────────
  bool _editing = false;

  // ── Profile controllers (only used in edit mode) ────────────────────────────
  late TextEditingController _nameCtrl;
  late TextEditingController _designationCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _linkedinCtrl;
  late TextEditingController _productsCtrl;
  late TextEditingController _aboutCtrl;
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
    _aboutCtrl = TextEditingController();
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
    _aboutCtrl.dispose();
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
    _aboutCtrl.text = p?['value_proposition'] as String? ?? '';
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

  Future<void> _saveProfile() async {
    if (_isSavingProfile) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Display name is required.', error: true);
      return;
    }
    setState(() => _isSavingProfile = true);
    try {
      final result = await context.read<AuthProvider>().updateProfile(
            name: name,
            designation: _designationCtrl.text.trim(),
            website: _websiteCtrl.text.trim(),
            linkedinUrl: _linkedinCtrl.text.trim(),
            productsServices: _productsCtrl.text.trim(),
            valueProposition: _aboutCtrl.text.trim(),
            additionalContext: _contextCtrl.text.trim(),
            aiTone: _aiTone,
          );
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() => _editing = false);
        _snack('Profile saved.');
      } else {
        _snack(result['error'] as String? ?? 'Failed to save profile.', error: true);
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    context.go('/auth');
  }

  void _snack(String message, {bool error = false}) {
    showAppToast(context, message);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.profile == null || auth.user == null;

    return DecoratedBox(
      decoration: AppTheme.appBackground(context),
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
        border: Border(bottom: BorderSide(color: _c.border)),
      ),
      child: Row(
        children: [
          AppButton(
            onPressed: () => context.go('/'),
            variant: ButtonVariant.outline,
            size: ButtonSize.sm,
            child: Icon(Icons.arrow_back_rounded, color: _c.textPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Settings',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: _c.textPrimary,
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
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _c.accent,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              auth.initials,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _c.isDark ? _c.background : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: _c.textPrimary,
                  ),
                ),
                if (auth.designation.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    auth.designation,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _c.textSecondary),
                  ),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(email, style: TextStyle(fontSize: 12, color: _c.textMuted)),
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

  // ── Profile VIEW mode ───────────────────────────────────────────────────────

  Widget _buildViewPanel(AuthProvider auth) {
    final p = auth.profile;
    final name = auth.displayName;
    final designation = p?['designation'] as String? ?? '';
    final website = p?['website'] as String? ?? '';
    final linkedin = p?['linkedin_url'] as String? ?? '';
    final products = p?['products_services'] as String? ?? '';
    final valueProposition = p?['value_proposition'] as String? ?? '';
    final additionalContext = p?['additional_context'] as String? ?? '';
    final tone = p?['ai_tone'] as String? ?? 'professional';

    final hasContent = designation.isNotEmpty || website.isNotEmpty ||
        linkedin.isNotEmpty || products.isNotEmpty ||
        valueProposition.isNotEmpty || additionalContext.isNotEmpty;

    return AppCard(
      radius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI personalisation nudge
          Container(
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
                    style: TextStyle(fontSize: 12, height: 1.5, color: _c.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (!hasContent) ...[
            _emptyProfileHint(),
          ] else ...[
            _viewRow('Name', name),
            if (designation.isNotEmpty) _viewRow('Designation', designation),
            if (website.isNotEmpty) _viewRow('Website', website, isLink: true),
            if (linkedin.isNotEmpty) _viewRow('LinkedIn', linkedin, isLink: true),
            if (products.isNotEmpty) _viewRow('Products & Services', products, multiLine: true),
            if (valueProposition.isNotEmpty) _viewRow('Value Proposition', valueProposition, multiLine: true),
            if (additionalContext.isNotEmpty) _viewRow('Additional AI Context', additionalContext, multiLine: true),
            _viewRow('AI Tone', tone[0].toUpperCase() + tone.substring(1), isLast: true),
          ],

          const SizedBox(height: 16),
          AppButton(
            label: hasContent ? 'EDIT PROFILE' : 'COMPLETE PROFILE',
            onPressed: _startEditing,
            variant: ButtonVariant.outline,
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
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _c.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Add your details to unlock personalised AI-generated emails, follow-ups, and conversation suggestions.',
            style: TextStyle(fontSize: 13, height: 1.5, color: _c.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _viewRow(String label, String value, {bool isLink = false, bool multiLine = false, bool isLast = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _c.textMuted),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    height: multiLine ? 1.5 : 1.0,
                    color: isLink ? _c.accent : _c.textPrimary,
                    decoration: isLink ? TextDecoration.underline : null,
                    decorationColor: isLink ? _c.accent.withValues(alpha: 0.4) : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) FDivider(),
      ],
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
          // AI personalisation nudge
          Container(
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
                    style: TextStyle(fontSize: 12, height: 1.5, color: _c.accent),
                  ),
                ),
              ],
            ),
          ),
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
          _field(label: 'Value Proposition', ctrl: _aboutCtrl, hint: 'Your elevator pitch...', lines: 3),
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
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: _c.textMuted),
        ),
        const SizedBox(height: 8),
        Row(
          children: _toneOptions.map((tone) {
            final active = _aiTone == tone;
            final isLast = tone == _toneOptions.last;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 8),
                child: GestureDetector(
                  onTap: () => setState(() => _aiTone = tone),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? _c.accent : _c.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active ? _c.accent : _c.border,
                        width: active ? 1.5 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tone[0].toUpperCase() + tone.substring(1),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? (_c.isDark ? _c.background : Colors.white) : _c.textSecondary,
                      ),
                    ),
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
          isLast: true,
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
        isLast: true,
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
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
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
                    Text(title,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _c.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: _c.textMuted)),
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
        ),
        if (!isLast) FDivider(),
      ],
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    required String sublabel,
    required VoidCallback onTap,
    bool destructive = false,
    bool loading = false,
    bool isLast = false,
  }) {
    final color = destructive ? _c.destructive : _c.accent;
    return Column(
      children: [
        GestureDetector(
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
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: FCircularProgress(),
                        )
                      : Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
                      const SizedBox(height: 2),
                      Text(sublabel, style: TextStyle(fontSize: 12, color: _c.textMuted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: _c.textMuted),
              ],
            ),
          ),
        ),
        if (!isLast) FDivider(),
      ],
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
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: _c.textMuted),
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
            border: Border(bottom: BorderSide(color: _c.border)),
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
                _skeletonCard(
                  radius: 28,
                  child: Row(
                    children: [
                      SkeletonLoader(width: 56, height: 56, borderRadius: BorderRadius.circular(18)),
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
                _skeletonCard(
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
                _skeletonCard(
                  child: SkeletonLoader(width: double.infinity, height: 56, borderRadius: BorderRadius.circular(12)),
                ),
                const SizedBox(height: 24),
                SkeletonLoader(width: 65, height: 11, borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: 10),
                _skeletonCard(
                  child: SkeletonLoader(width: double.infinity, height: 56, borderRadius: BorderRadius.circular(12)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _skeletonCard({required Widget child, double radius = 20}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _c.border),
      ),
      child: child,
    );
  }
}
