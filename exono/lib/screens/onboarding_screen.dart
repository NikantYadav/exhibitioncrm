import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/entry_flow_components.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  final _nameController = TextEditingController();
  final _designationController = TextEditingController();
  final _productsController = TextEditingController();
  final _aboutController = TextEditingController();
  final _websiteController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _contextController = TextEditingController();

  int _currentPage = 0;
  bool _isLoading = false;

  String _profileType = 'company';
  String _aiTone = 'professional';
  String? _initialName;
  String? _initialEmail;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args == null) return;

      final initialName = args['name'] as String?;
      final initialEmail = args['email'] as String?;
      final accessToken = args['token'] as String?;

      setState(() {
        _initialName = initialName;
        _initialEmail = initialEmail;
        _accessToken = accessToken != null && accessToken.trim().isNotEmpty ? accessToken : null;
        if (initialName != null && initialName.trim().isNotEmpty) {
          _nameController.text = initialName.trim();
        }
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _designationController.dispose();
    _productsController.dispose();
    _aboutController.dispose();
    _websiteController.dispose();
    _linkedinController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    FocusScope.of(context).unfocus();
    if (!_validateCurrentStep()) return;

    if (_currentPage < 3) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    } else {
      await _completeOnboarding();
    }
  }

  Future<void> _previousPage() async {
    FocusScope.of(context).unfocus();
    if (_currentPage == 0) return;

    await _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  bool _validateCurrentStep() {
    switch (_currentPage) {
      case 0:
        return true;
      case 1:
        if (_profileType != 'individual' && _nameController.text.trim().isEmpty) {
          _showError(
            _profileType == 'company'
                ? 'Please enter your company name.'
                : 'Please enter the company name.',
          );
          return false;
        }
        if (_profileType != 'individual' && _designationController.text.trim().isEmpty) {
          _showError('Please enter your designation.');
          return false;
        }
        return true;
      case 2:
        if (_productsController.text.trim().isEmpty && _aboutController.text.trim().isEmpty) {
          _showError(
            _profileType == 'individual'
                ? 'Please add your skills or a short profile summary.'
                : 'Please add your products/services or a short company description.',
          );
          return false;
        }
        return true;
      case 3:
        return true;
      default:
        return true;
    }
  }

  Future<void> _completeOnboarding() async {
    if (_accessToken == null || _accessToken!.trim().isEmpty) {
      _showError('Session expired. Please login again.');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
      return;
    }

    final effectiveName = _profileType == 'individual'
        ? (_initialName?.trim().isNotEmpty == true ? _initialName!.trim() : _nameController.text.trim())
        : _nameController.text.trim();

    if (effectiveName.isEmpty) {
      _showError('Please provide a valid name before continuing.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.completeProfile(
        token: _accessToken!,
        name: effectiveName,
        profileType: _profileType,
        designation: _designationController.text.trim().isNotEmpty ? _designationController.text.trim() : null,
        productsServices: _productsController.text.trim().isNotEmpty ? _productsController.text.trim() : null,
        valueProposition: _aboutController.text.trim().isNotEmpty ? _aboutController.text.trim() : null,
        website: _websiteController.text.trim().isNotEmpty ? _websiteController.text.trim() : null,
        linkedinUrl: _linkedinController.text.trim().isNotEmpty ? _linkedinController.text.trim() : null,
        aiTone: _aiTone,
        additionalContext: _contextController.text.trim().isNotEmpty ? _contextController.text.trim() : null,
      );

      if (!mounted) return;

      setState(() => _isLoading = false);
      if (result['success'] == true) {
        Navigator.of(context).pushReplacementNamed('/mode-selection');
      } else {
        _showError(result['error']?.toString() ?? 'Failed to complete profile');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('An error occurred: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.destructive,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return EntryFlowScaffold(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 8, isMobile ? 16 : 24, 0),
            child: Column(
              children: [
                const EntryFlowTopBar(
                  leadingIcon: Icons.tune_rounded,
                  title: 'EXONO',
                  badgeLabel: 'Profile Setup',
                ),
                const SizedBox(height: 20),
                _buildProgressHeader(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _buildProfileTypePage(isMobile),
                _buildBasicInfoPage(isMobile),
                _buildDetailsPage(isMobile),
                _buildAIConfigPage(isMobile),
              ],
            ),
          ),
          _buildBottomBar(isMobile),
        ],
      ),
    );
  }

  Widget _buildProgressHeader() {
    final colors = AppTheme.colorsOf(context);
    const titles = ['Account Type', 'Identity', 'Details', 'AI Setup'];

    return EntryPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ONBOARDING',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 8),
                    Text(titles[_currentPage], style: Theme.of(context).textTheme.headlineLarge),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  '${_currentPage + 1}/4',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: colors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: List.generate(4, (index) {
              final isComplete = index <= _currentPage;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 6,
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
                  decoration: BoxDecoration(
                    gradient: isComplete ? LinearGradient(colors: [colors.accent, colors.accentStrong]) : null,
                    color: isComplete ? null : colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTypePage(bool isMobile) {
    return _buildPageShell(
      isMobile: isMobile,
      eyebrow: 'STEP 1',
      title: 'Choose the profile that matches your operating model.',
      subtitle: 'This shapes how Exono frames your company, expertise, and outreach workflow.',
      children: [
        if (_initialEmail?.trim().isNotEmpty == true) _buildAccountCard(),
        _buildProfileTypeOption(
          value: 'company',
          label: 'Company',
          description: 'Best for founders, operators, and businesses representing a company profile.',
          icon: Icons.business_center_rounded,
        ),
        const SizedBox(height: 12),
        _buildProfileTypeOption(
          value: 'individual',
          label: 'Individual',
          description: 'Best for solo professionals building a personal network and knowledge profile.',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 12),
        _buildProfileTypeOption(
          value: 'employee',
          label: 'Employee',
          description: 'Best for team members working inside a broader company workflow.',
          icon: Icons.badge_outlined,
        ),
      ],
    );
  }

  Widget _buildBasicInfoPage(bool isMobile) {
    final showNameField = _profileType != 'individual';

    return _buildPageShell(
      isMobile: isMobile,
      eyebrow: 'STEP 2',
      title: _profileType == 'individual'
          ? 'Confirm who you are and how people should understand you.'
          : 'Add the core identity details behind this profile.',
      subtitle: _profileType == 'individual'
          ? 'Your personal name comes from signup. Add links that help Exono build context.'
          : 'These details define the organization or team context for events, contacts, and AI guidance.',
      children: [
        if (_profileType == 'individual' && _initialName?.trim().isNotEmpty == true)
          _buildSummaryCard(
            title: 'Signed up as',
            value: _initialName!,
            subtitle: _initialEmail ?? 'Personal profile',
            icon: Icons.verified_user_rounded,
          ),
        if (showNameField) ...[
          EntryTextField(
            controller: _nameController,
            label: 'Company Name',
            hint: 'Northstar Labs',
            prefixIcon: Icons.corporate_fare_rounded,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          EntryTextField(
            controller: _designationController,
            label: 'Your Designation',
            hint: _profileType == 'company' ? 'Founder, CEO, Head of Growth' : 'Sales Manager, Account Executive',
            prefixIcon: Icons.work_outline_rounded,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
        ],
        EntryTextField(
          controller: _websiteController,
          label: 'Website',
          hint: 'https://example.com',
          prefixIcon: Icons.language_rounded,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        EntryTextField(
          controller: _linkedinController,
          label: 'LinkedIn',
          hint: 'Profile URL or handle',
          prefixIcon: Icons.link_rounded,
        ),
      ],
    );
  }

  Widget _buildDetailsPage(bool isMobile) {
    return _buildPageShell(
      isMobile: isMobile,
      eyebrow: 'STEP 3',
      title: _profileType == 'individual'
          ? 'Describe what you do and why your network should care.'
          : 'Tell Exono what your company offers and how it should be positioned.',
      subtitle: 'This information feeds summaries, preparation workflows, and AI-generated follow-up context.',
      children: [
        EntryTextField(
          controller: _productsController,
          label: _profileType == 'individual' ? 'Skills & Expertise' : 'Products & Services',
          hint: _profileType == 'individual'
              ? 'Enterprise sales, GTM strategy, partnerships...'
              : 'CRM consulting, AI tooling, workflow automation...',
          prefixIcon: Icons.layers_outlined,
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        EntryTextField(
          controller: _aboutController,
          label: 'About',
          hint: _profileType == 'individual'
              ? 'Describe your background, strengths, and the kind of conversations you want AI to understand...'
              : 'Describe your company, positioning, and the kind of buyers or partners you care about...',
          prefixIcon: Icons.short_text_rounded,
          maxLines: 5,
        ),
      ],
    );
  }

  Widget _buildAIConfigPage(bool isMobile) {
    return _buildPageShell(
      isMobile: isMobile,
      eyebrow: 'STEP 4',
      title: 'Tune how the assistant should sound and what context it should keep in mind.',
      subtitle: 'These settings shape drafts, summaries, and support inside the assistant and CRM.',
      children: [
        EntrySoftTile(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI PERSONALITY',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.2),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildAIToneChip('professional', 'Professional'),
                  _buildAIToneChip('casual', 'Casual'),
                  _buildAIToneChip('formal', 'Formal'),
                  _buildAIToneChip('friendly', 'Friendly'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        EntryTextField(
          controller: _contextController,
          label: 'Additional Context',
          hint: 'Any industry context, customer focus, event goals, or preferred framing the AI should know...',
          prefixIcon: Icons.tips_and_updates_outlined,
          maxLines: 6,
        ),
      ],
    );
  }

  Widget _buildPageShell({
    required bool isMobile,
    required String eyebrow,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 0, isMobile ? 16 : 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: EntryPanel(
            padding: EdgeInsets.all(isMobile ? 20 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EntryEyebrow(label: eyebrow),
                const SizedBox(height: 18),
                Text(title, style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 10),
                Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 22),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    final colors = AppTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: EntrySoftTile(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Icon(Icons.mark_email_read_outlined, color: colors.accentStrong, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SIGNED IN AS', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(_initialEmail!, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    final colors = AppTheme.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: EntrySoftTile(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border),
              ),
              child: Icon(icon, color: colors.accentStrong, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTypeOption({
    required String value,
    required String label,
    required String description,
    required IconData icon,
  }) {
    final colors = AppTheme.colorsOf(context);
    final isSelected = _profileType == value;

    return InkWell(
      onTap: () => setState(() => _profileType = value),
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(colors: [colors.accentSoft, colors.surface]) : null,
          color: isSelected ? null : colors.surfaceAlt,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isSelected ? colors.accent.withValues(alpha: 0.45) : colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Icon(icon, size: 24, color: colors.accentStrong),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 5),
                  Text(description, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? colors.accentStrong : colors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIToneChip(String value, String label) {
    final colors = AppTheme.colorsOf(context);
    final isSelected = _aiTone == value;

    return InkWell(
      onTap: () => setState(() => _aiTone = value),
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(colors: [colors.accent, colors.accentStrong]) : null,
          color: isSelected ? null : colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isSelected ? Colors.transparent : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? (colors.isDark ? colors.background : Colors.white) : colors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 8, isMobile ? 16 : 24, isMobile ? 16 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Row(
            children: [
              if (_currentPage > 0)
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _previousPage,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('BACK'),
                    ),
                  ),
                ),
              if (_currentPage > 0) const SizedBox(width: 12),
              Expanded(
                flex: _currentPage > 0 ? 2 : 1,
                child: EntryPrimaryButton(
                  label: _currentPage == 3 ? 'COMPLETE SETUP' : 'CONTINUE',
                  icon: _currentPage == 3 ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  loading: _isLoading,
                  onPressed: _nextPage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
