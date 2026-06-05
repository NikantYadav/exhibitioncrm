import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../services/auth_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const Color _backgroundColor = Color(0xFF080808);
  static const Color _surfaceColor = Color(0xFF141313);
  static const Color _surfaceAltColor = Color(0xFF1C1B1B);
  static const Color _borderColor = Color(0xFF444748);
  static const Color _mutedColor = Color(0xFFC4C7C8);
  static const Color _subtleColor = Color(0xFF8E9192);

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
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args == null) return;

      final initialName = args['name'] as String?;
      final initialEmail = args['email'] as String?;
      final accessToken = args['token'] as String?;

      setState(() {
        _initialName = initialName;
        _initialEmail = initialEmail;
        _accessToken = accessToken != null && accessToken.trim().isNotEmpty
            ? accessToken
            : null;
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
        if (_profileType != 'individual' &&
            _nameController.text.trim().isEmpty) {
          _showError(
            _profileType == 'company'
                ? 'Please enter your company name.'
                : 'Please enter the company name.',
          );
          return false;
        }
        if (_profileType != 'individual' &&
            _designationController.text.trim().isEmpty) {
          _showError('Please enter your designation.');
          return false;
        }
        return true;
      case 2:
        if (_productsController.text.trim().isEmpty &&
            _aboutController.text.trim().isEmpty) {
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
        ? (_initialName?.trim().isNotEmpty == true
              ? _initialName!.trim()
              : _nameController.text.trim())
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
        designation: _designationController.text.trim().isNotEmpty
            ? _designationController.text.trim()
            : null,
        productsServices: _productsController.text.trim().isNotEmpty
            ? _productsController.text.trim()
            : null,
        valueProposition: _aboutController.text.trim().isNotEmpty
            ? _aboutController.text.trim()
            : null,
        website: _websiteController.text.trim().isNotEmpty
            ? _websiteController.text.trim()
            : null,
        linkedinUrl: _linkedinController.text.trim().isNotEmpty
            ? _linkedinController.text.trim()
            : null,
        aiTone: _aiTone,
        additionalContext: _contextController.text.trim().isNotEmpty
            ? _contextController.text.trim()
            : null,
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 768;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: _backgroundColor,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 16 : 24,
                  8,
                  isMobile ? 16 : 24,
                  0,
                ),
                child: Column(
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 20),
                    _buildProgressHeader(isMobile),
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
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: _backgroundColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'EXONO',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: Colors.white,
              height: 1,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _borderColor),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 16, color: _mutedColor),
                SizedBox(width: 8),
                Text(
                  'Profile Setup',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: _mutedColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHeader(bool isMobile) {
    final titles = ['Account Type', 'Identity', 'Details', 'AI Setup'];

    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 22),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ONBOARDING',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: _mutedColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      titles[_currentPage],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _surfaceAltColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _borderColor),
                ),
                child: Text(
                  '${_currentPage + 1}/4',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
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
                  height: 5,
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 8),
                  decoration: BoxDecoration(
                    color: isComplete ? Colors.white : _borderColor,
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
      subtitle:
          'This shapes how Exono frames your company, expertise, and outreach workflow.',
      icon: Icons.apartment_rounded,
      children: [
        if (_initialEmail?.trim().isNotEmpty == true) _buildAccountCard(),
        _buildProfileTypeOption(
          value: 'company',
          label: 'Company',
          description:
              'Best for founders, operators, and businesses representing a company profile.',
          icon: Icons.business_center_rounded,
        ),
        const SizedBox(height: 12),
        _buildProfileTypeOption(
          value: 'individual',
          label: 'Individual',
          description:
              'Best for solo professionals building a personal network and knowledge profile.',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 12),
        _buildProfileTypeOption(
          value: 'employee',
          label: 'Employee',
          description:
              'Best for team members working inside a broader company workflow.',
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
      icon: Icons.badge_rounded,
      children: [
        if (_profileType == 'individual' &&
            _initialName?.trim().isNotEmpty == true)
          _buildSummaryCard(
            title: 'Signed up as',
            value: _initialName!,
            subtitle: _initialEmail ?? 'Personal profile',
            icon: Icons.verified_user_rounded,
          ),
        if (showNameField) ...[
          _buildTextField(
            controller: _nameController,
            label: _profileType == 'company' ? 'Company Name' : 'Company Name',
            hint: _profileType == 'company'
                ? 'Northstar Labs'
                : 'Northstar Labs',
            prefixIcon: Icons.corporate_fare_rounded,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _designationController,
            label: 'Your Designation',
            hint: _profileType == 'company'
                ? 'Founder, CEO, Head of Growth'
                : 'Sales Manager, Account Executive',
            prefixIcon: Icons.work_outline_rounded,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
        ],
        _buildTextField(
          controller: _websiteController,
          label: 'Website',
          hint: 'https://example.com',
          prefixIcon: Icons.language_rounded,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        _buildTextField(
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
      subtitle:
          'This information feeds summaries, preparation workflows, and AI-generated follow-up context.',
      icon: Icons.notes_rounded,
      children: [
        _buildTextField(
          controller: _productsController,
          label: _profileType == 'individual'
              ? 'Skills & Expertise'
              : 'Products & Services',
          hint: _profileType == 'individual'
              ? 'Enterprise sales, GTM strategy, partnerships...'
              : 'CRM consulting, AI tooling, workflow automation...',
          prefixIcon: Icons.layers_outlined,
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        _buildTextField(
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
      title:
          'Tune how the assistant should sound and what context it should keep in mind.',
      subtitle:
          'These settings shape drafts, summaries, and support inside the assistant and CRM.',
      icon: Icons.psychology_alt_rounded,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _surfaceAltColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI PERSONALITY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _mutedColor,
                ),
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
        _buildTextField(
          controller: _contextController,
          label: 'Additional Context',
          hint:
              'Any industry context, customer focus, event goals, or preferred framing the AI should know...',
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
    required IconData icon,
    required List<Widget> children,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        0,
        isMobile ? 16 : 24,
        24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 20 : 24),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _borderColor),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -10,
                  right: -8,
                  child: Icon(
                    icon,
                    size: isMobile ? 88 : 120,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Text(
                        eyebrow,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isMobile ? 28 : 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.2,
                        color: Colors.white,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: _mutedColor,
                      ),
                    ),
                    const SizedBox(height: 22),
                    ...children,
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceAltColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Signed in as',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: _mutedColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _initialEmail!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceAltColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: _mutedColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: _subtleColor),
                  ),
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
    final isSelected = _profileType == value;

    return InkWell(
      onTap: () => setState(() => _profileType = value),
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : _surfaceAltColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: isSelected ? Colors.white : _borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? _backgroundColor.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? _backgroundColor.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? _backgroundColor : Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: isSelected ? _backgroundColor : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: isSelected
                          ? _backgroundColor.withValues(alpha: 0.72)
                          : _mutedColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? _backgroundColor : _subtleColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIToneChip(String value, String label) {
    final isSelected = _aiTone == value;

    return InkWell(
      onTap: () => setState(() => _aiTone = value),
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : _surfaceColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isSelected ? Colors.white : _borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? _backgroundColor : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
  }) {
    final isMultiline = maxLines > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: _mutedColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isMultiline ? TextInputType.multiline : keyboardType,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          minLines: isMultiline ? maxLines : 1,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: _subtleColor,
              fontSize: 14,
              height: 1.4,
            ),
            prefixIcon: isMultiline
                ? Padding(
                    padding: const EdgeInsets.only(
                      left: 14,
                      right: 10,
                      top: 14,
                    ),
                    child: Icon(prefixIcon, color: _mutedColor, size: 20),
                  )
                : Icon(prefixIcon, color: _mutedColor, size: 20),
            prefixIconConstraints: const BoxConstraints(minWidth: 44),
            filled: true,
            fillColor: _surfaceAltColor,
            alignLabelWithHint: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isMultiline ? 16 : 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: _borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: _borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Colors.white, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        14,
        isMobile ? 16 : 24,
        isMobile ? 16 : 20,
      ),
      decoration: const BoxDecoration(
        color: _backgroundColor,
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Row(
            children: [
              if (_currentPage > 0)
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _previousPage,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _borderColor),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'BACK',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_currentPage > 0) const SizedBox(width: 12),
              Expanded(
                flex: _currentPage > 0 ? 2 : 1,
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _nextPage,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white.withValues(
                        alpha: 0.4,
                      ),
                      foregroundColor: _backgroundColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _backgroundColor,
                              ),
                            ),
                          )
                        : Text(
                            _currentPage < 3 ? 'CONTINUE' : 'COMPLETE SETUP',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
