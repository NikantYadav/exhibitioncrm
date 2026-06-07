import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/app_section_label.dart';
import 'account_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const ProfileScreen({super.key, this.onNavigateTab});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  bool _dailyBriefEnabled = true;
  bool _offlinePrepEnabled = true;
  bool _assistantSuggestionsEnabled = true;

  String? _draftDisplayName;
  String? _draftDesignation;
  String? _draftWebsite;
  String? _draftLinkedin;
  String? _draftProducts;
  String? _draftAbout;
  String? _draftAdditionalContext;

  void _navigateTo(int index) {
    widget.onNavigateTab?.call(index);
  }

  void _showUiOnlyMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _readString(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) return '';
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  String _formatProfileType(String raw) {
    if (raw.isEmpty) return 'TEAM PROFILE';
    return raw
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ')
        .toUpperCase();
  }

  String _normalizeLink(String value) {
    if (value.isEmpty) return value;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('linkedin.com')) {
      return 'https://$value';
    }
    return value;
  }

  String _resolvedValue(String? draftValue, String fallback) {
    return draftValue ?? fallback;
  }

  Future<void> _openEditProfileSheet({
    required String displayName,
    required String designation,
    required String website,
    required String linkedin,
    required String products,
    required String about,
    required String additionalContext,
  }) async {
    final result = await showModalBottomSheet<_EditableProfileDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => _EditProfileSheet(
        initialDraft: _EditableProfileDraft(
          displayName: displayName,
          designation: designation,
          website: website,
          linkedin: linkedin,
          products: products,
          about: about,
          additionalContext: additionalContext,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _draftDisplayName = result.displayName;
      _draftDesignation = result.designation;
      _draftWebsite = result.website;
      _draftLinkedin = result.linkedin;
      _draftProducts = result.products;
      _draftAbout = result.about;
      _draftAdditionalContext = result.additionalContext;
    });

    _showUiOnlyMessage('Profile updated in local preview.');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    final user = auth.user;
    final userMetadata = user?['user_metadata'] as Map<String, dynamic>?;

    final displayName = _resolvedValue(_draftDisplayName, auth.displayName);
    final designation = _resolvedValue(_draftDesignation, auth.designation);
    final email = _readString(user, ['email']);
    final profileType = _formatProfileType(
      _readString(profile, ['profile_type']),
    );
    final website = _normalizeLink(
      _resolvedValue(_draftWebsite, _readString(profile, ['website'])),
    );
    final linkedin = _normalizeLink(
      _resolvedValue(_draftLinkedin, _readString(profile, ['linkedin_url'])),
    );
    final products = _resolvedValue(
      _draftProducts,
      _readString(profile, ['products_services']),
    );
    final about = _resolvedValue(
      _draftAbout,
      _readString(profile, ['value_proposition']),
    );
    final additionalContext = _resolvedValue(
      _draftAdditionalContext,
      _readString(profile, ['additional_context']),
    );
    final aiToneRaw = _readString(profile, ['ai_tone']);
    final aiTone = aiToneRaw.isEmpty ? 'PROFESSIONAL' : aiToneRaw.toUpperCase();
    final signedUpName = _readString(userMetadata, ['name']);

    return ColoredBox(
      color: _c.background,
      child: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroCard(
                    auth: auth,
                    displayName: displayName,
                    designation: designation,
                    email: email,
                    profileType: profileType,
                  ),
                  const SizedBox(height: 16),
                  _buildQuickActionsCard(),
                  const SizedBox(height: 16),
                  AppSectionLabel('Account Snapshot'),
                  const SizedBox(height: 10),
                  _buildInfoGrid(
                    children: [
                      _InfoTile(
                        title: 'Display Name',
                        value: displayName,
                        icon: Icons.person_outline_rounded,
                      ),
                      _InfoTile(
                        title: 'Signup Name',
                        value: signedUpName.isEmpty
                            ? displayName
                            : signedUpName,
                        icon: Icons.badge_outlined,
                      ),
                      _InfoTile(
                        title: 'Email',
                        value: email.isEmpty ? 'No email available' : email,
                        icon: Icons.alternate_email_rounded,
                      ),
                      _InfoTile(
                        title: 'Designation',
                        value: designation,
                        icon: Icons.work_outline_rounded,
                      ),
                      _InfoTile(
                        title: 'Profile Type',
                        value: profileType,
                        icon: Icons.apartment_rounded,
                      ),
                      _InfoTile(
                        title: 'AI Tone',
                        value: aiTone,
                        icon: Icons.psychology_alt_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppSectionLabel('Profile Details'),
                  const SizedBox(height: 10),
                  _buildDetailPanel(
                    title: 'Company & Identity Links',
                    icon: Icons.link_rounded,
                    children: [
                      _buildDetailRow(
                        'Website',
                        website.isEmpty ? 'Not provided' : website,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        'LinkedIn',
                        linkedin.isEmpty ? 'Not provided' : linkedin,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailPanel(
                    title: 'Positioning',
                    icon: Icons.layers_outlined,
                    children: [
                      _buildBodyBlock(
                        label: 'Products & Services',
                        value: products.isEmpty
                            ? 'No products or services added yet.'
                            : products,
                      ),
                      const SizedBox(height: 16),
                      _buildBodyBlock(
                        label: 'About / Value Proposition',
                        value: about.isEmpty
                            ? 'No positioning summary added yet.'
                            : about,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailPanel(
                    title: 'Assistant Context',
                    icon: Icons.auto_awesome_rounded,
                    children: [
                      _buildBodyBlock(
                        label: 'Additional Context',
                        value: additionalContext.isEmpty
                            ? 'No extra AI context saved yet.'
                            : additionalContext,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppSectionLabel('Workspace Preferences'),
                  const SizedBox(height: 10),
                  _buildPreferenceTile(
                    title: 'Daily brief notifications',
                    subtitle:
                        'Surface priorities and relationship signals each morning.',
                    value: _dailyBriefEnabled,
                    onChanged: (value) {
                      setState(() => _dailyBriefEnabled = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildPreferenceTile(
                    title: 'Offline event prep',
                    subtitle:
                        'Keep event-day context accessible even with poor connectivity.',
                    value: _offlinePrepEnabled,
                    onChanged: (value) {
                      setState(() => _offlinePrepEnabled = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildPreferenceTile(
                    title: 'Assistant proactive suggestions',
                    subtitle:
                        'Show draft nudges and follow-up recommendations throughout the app.',
                    value: _assistantSuggestionsEnabled,
                    onChanged: (value) {
                      setState(() => _assistantSuggestionsEnabled = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  AppSectionLabel('Actions'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildActionButton(
                        label: 'Edit Profile',
                        icon: Icons.edit_outlined,
                        onTap: () => _openEditProfileSheet(
                          displayName: displayName,
                          designation: designation,
                          website: website,
                          linkedin: linkedin,
                          products: products,
                          about: about,
                          additionalContext: additionalContext,
                        ),
                      ),
                      _buildActionButton(
                        label: 'Refresh Snapshot',
                        icon: Icons.refresh_rounded,
                        onTap: () async {
                          await context.read<AuthProvider>().refreshProfile();
                          if (!mounted) return;
                          _showUiOnlyMessage('Profile snapshot refreshed.');
                        },
                      ),
                      _buildActionButton(
                        label: 'Settings',
                        icon: Icons.settings_outlined,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AccountSettingsScreen(),
                            ),
                          );
                        },
                      ),
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

  Widget _buildHeroCard({
    required AuthProvider auth,
    required String displayName,
    required String designation,
    required String email,
    required String profileType,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 28,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  auth.initials,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _c.background,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROFILE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: _c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.0,
                        color: _c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      designation,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: _c.textSecondary,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        email,
                        style: TextStyle(fontSize: 13, color: _c.borderStrong),
                      ),
                    ],
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
              _buildHeroBadge(
                icon: Icons.apartment_rounded,
                label: profileType,
              ),
              _buildHeroBadge(icon: Icons.verified_rounded, label: 'ACTIVE'),
              _buildHeroBadge(
                icon: Icons.tips_and_updates_rounded,
                label: 'AI READY',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBadge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _c.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _c.textPrimary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return AppCard(
      padding: const EdgeInsets.all(18),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionLabel('Quick Actions'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildActionButton(
                label: 'Targets',
                icon: Icons.track_changes_outlined,
                onTap: () => _navigateTo(0),
              ),
              _buildActionButton(
                label: 'Events',
                icon: Icons.event_outlined,
                onTap: () => _navigateTo(1),
              ),
              _buildActionButton(
                label: 'Follow-Ups',
                icon: Icons.mark_email_unread_outlined,
                onTap: () => _navigateTo(4),
              ),
              _buildActionButton(
                label: 'Capture',
                icon: Icons.qr_code_scanner_rounded,
                onTap: () => _navigateTo(2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
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
          color: _c.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: _c.textPrimary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildInfoGrid({required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 720;
        final tileWidth = useTwoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map((child) => SizedBox(width: tileWidth, child: child))
              .toList(),
        );
      },
    );
  }

  Widget _buildDetailPanel({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _c.textPrimary),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: _c.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(fontSize: 14, height: 1.45, color: _c.borderStrong),
        ),
      ],
    );
  }

  Widget _buildBodyBlock({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: _c.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 14, height: 1.55, color: _c.borderStrong),
        ),
      ],
    );
  }

  Widget _buildPreferenceTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      radius: 24,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _c.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: _c.borderStrong,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch.adaptive(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.35),
            inactiveThumbColor: _c.borderStrong,
            inactiveTrackColor: _c.surfaceAlt,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _EditableProfileDraft {
  final String displayName;
  final String designation;
  final String website;
  final String linkedin;
  final String products;
  final String about;
  final String additionalContext;

  const _EditableProfileDraft({
    required this.displayName,
    required this.designation,
    required this.website,
    required this.linkedin,
    required this.products,
    required this.about,
    required this.additionalContext,
  });
}

class _EditProfileSheet extends StatefulWidget {
  final _EditableProfileDraft initialDraft;

  const _EditProfileSheet({required this.initialDraft});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _displayNameController;
  late final TextEditingController _designationController;
  late final TextEditingController _websiteController;
  late final TextEditingController _linkedinController;
  late final TextEditingController _productsController;
  late final TextEditingController _aboutController;
  late final TextEditingController _additionalContextController;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.initialDraft.displayName,
    );
    _designationController = TextEditingController(
      text: widget.initialDraft.designation,
    );
    _websiteController = TextEditingController(
      text: widget.initialDraft.website,
    );
    _linkedinController = TextEditingController(
      text: widget.initialDraft.linkedin,
    );
    _productsController = TextEditingController(
      text: widget.initialDraft.products,
    );
    _aboutController = TextEditingController(text: widget.initialDraft.about);
    _additionalContextController = TextEditingController(
      text: widget.initialDraft.additionalContext,
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _designationController.dispose();
    _websiteController.dispose();
    _linkedinController.dispose();
    _productsController.dispose();
    _aboutController.dispose();
    _additionalContextController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      _EditableProfileDraft(
        displayName: _displayNameController.text.trim(),
        designation: _designationController.text.trim(),
        website: _websiteController.text.trim(),
        linkedin: _linkedinController.text.trim(),
        products: _productsController.text.trim(),
        about: _aboutController.text.trim(),
        additionalContext: _additionalContextController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 760),
          decoration: BoxDecoration(
            color: _c.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: _c.border),
              left: BorderSide(color: _c.border),
              right: BorderSide(color: _c.border),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _c.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Profile',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.8,
                                  color: _c.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Update the visible profile snapshot in this app preview.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _c.textMuted,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: _c.textPrimary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumns = constraints.maxWidth >= 680;
                        final fieldWidth = twoColumns
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: fieldWidth,
                              child: _buildField(
                                controller: _displayNameController,
                                label: 'Display Name',
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Display name is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _buildField(
                                controller: _designationController,
                                label: 'Designation',
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Designation is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _buildField(
                                controller: _websiteController,
                                label: 'Website',
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _buildField(
                                controller: _linkedinController,
                                label: 'LinkedIn',
                              ),
                            ),
                            SizedBox(
                              width: constraints.maxWidth,
                              child: _buildField(
                                controller: _productsController,
                                label: 'Products & Services',
                                minLines: 3,
                                maxLines: 4,
                              ),
                            ),
                            SizedBox(
                              width: constraints.maxWidth,
                              child: _buildField(
                                controller: _aboutController,
                                label: 'About / Value Proposition',
                                minLines: 4,
                                maxLines: 6,
                              ),
                            ),
                            SizedBox(
                              width: constraints.maxWidth,
                              child: _buildField(
                                controller: _additionalContextController,
                                label: 'Additional Context',
                                minLines: 4,
                                maxLines: 6,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _c.textPrimary,
                              side: BorderSide(color: _c.border),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text(
                              'CANCEL',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _c.background,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text(
                              'SAVE CHANGES',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    int minLines = 1,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: _c.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          validator: validator,
          style: TextStyle(fontSize: 14, color: _c.textPrimary),
          cursorColor: _c.textPrimary,
          decoration: InputDecoration(
            filled: true,
            fillColor: _c.surface,
            hintStyle: TextStyle(color: _c.textMuted),
            errorStyle: const TextStyle(color: Color(0xFFFFB4AB)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: _c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: _c.textPrimary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFFFB4AB)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFFFB4AB)),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final _c = AppTheme.colorsOf(context);
    return AppCard(
      padding: const EdgeInsets.all(18),
      radius: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _c.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _c.border),
            ),
            child: Icon(icon, size: 18, color: _c.textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: _c.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: _c.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
