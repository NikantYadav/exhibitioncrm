import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../services/auth_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Form controllers
  final _nameController = TextEditingController();
  final _designationController = TextEditingController();
  final _productsController = TextEditingController();
  final _aboutController = TextEditingController();
  final _websiteController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _contextController = TextEditingController();

  String _profileType = 'company';
  String _aiTone = 'professional';
  String? _initialName;
  String? _initialEmail;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    // Get passed arguments after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _initialName = args['name'] as String?;
          _initialEmail = args['email'] as String?;
          _accessToken = args['token'] as String?;
          if (_initialName != null) {
            _nameController.text = _initialName!;
          }
        });
      }
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

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeOnboarding() async {
    if (_accessToken == null) {
      _showError('Session expired. Please login again.');
      Navigator.of(context).pushReplacementNamed('/auth');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // Call API to complete profile
      final result = await AuthService.completeProfile(
        token: _accessToken!,
        name: _profileType == 'individual' ? _initialName! : _nameController.text,
        profileType: _profileType,
        designation: _designationController.text.isNotEmpty ? _designationController.text : null,
        productsServices: _productsController.text.isNotEmpty ? _productsController.text : null,
        valueProposition: _aboutController.text.isNotEmpty ? _aboutController.text : null,
        website: _websiteController.text.isNotEmpty ? _websiteController.text : null,
        linkedinUrl: _linkedinController.text.isNotEmpty ? _linkedinController.text : null,
        aiTone: _aiTone,
        additionalContext: _contextController.text.isNotEmpty ? _contextController.text : null,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        
        if (result['success'] == true) {
          // Profile completed successfully
          Navigator.of(context).pushReplacementNamed('/mode-selection');
        } else {
          _showError(result['error'] ?? 'Failed to complete profile');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('An error occurred: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.destructive,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Setup Profile',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.stone900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_currentPage + 1}/4',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.stone400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: List.generate(4, (index) {
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(
                            right: index < 3 ? 8 : 0,
                          ),
                          decoration: BoxDecoration(
                            color: index <= _currentPage
                                ? AppTheme.stone900
                                : AppTheme.stone200,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                children: [
                  _buildProfileTypePage(isMobile),
                  _buildBasicInfoPage(isMobile),
                  _buildDetailsPage(isMobile),
                  _buildAIConfigPage(isMobile),
                ],
              ),
            ),

            // Navigation Buttons
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: AppTheme.stone200.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppTheme.stone300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'BACK',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: AppTheme.stone700,
                          ),
                        ),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      onPressed: _isLoading ? null : _nextPage,
                      isLoading: _isLoading,
                      child: Text(
                        _currentPage < 3 ? 'CONTINUE' : 'COMPLETE SETUP',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
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

  Widget _buildProfileTypePage(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Type',
            style: TextStyle(
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.w900,
              color: AppTheme.stone900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the type that best describes you',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.stone500,
            ),
          ),
          const SizedBox(height: 32),
          _buildProfileTypeOption(
            'company',
            'Company',
            'Enterprise profile',
            Icons.business_rounded,
            isMobile,
          ),
          const SizedBox(height: 16),
          _buildProfileTypeOption(
            'individual',
            'Individual',
            'Personal account',
            Icons.person_rounded,
            isMobile,
          ),
          const SizedBox(height: 16),
          _buildProfileTypeOption(
            'employee',
            'Employee',
            'Team member',
            Icons.badge_rounded,
            isMobile,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTypeOption(
    String value,
    String label,
    String description,
    IconData icon,
    bool isMobile,
  ) {
    final isSelected = _profileType == value;
    
    return InkWell(
      onTap: () {
        setState(() => _profileType = value);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 20 : 24),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.stone900 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.stone900
                : AppTheme.stone200.withValues(alpha: 0.4),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.stone900.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: isMobile ? 48 : 56,
              height: isMobile ? 48 : 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppTheme.stone100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: isMobile ? 24 : 28,
                color: isSelected ? Colors.white : AppTheme.stone600,
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
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : AppTheme.stone900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppTheme.stone500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoPage(bool isMobile) {
    final showNameField = _profileType != 'individual';
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: TextStyle(
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.w900,
              color: AppTheme.stone900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _profileType == 'individual'
                ? 'Tell us about yourself'
                : 'Tell us about your company',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.stone500,
            ),
          ),
          const SizedBox(height: 32),
          
          if (showNameField) ...[
            AppInput(
              controller: _nameController,
              label: _profileType == 'company' ? 'Company Name' : 'Company Name',
              hint: 'Enter name...',
            ),
            const SizedBox(height: 20),
          ],
          
          if (_profileType != 'individual') ...[
            AppInput(
              controller: _designationController,
              label: 'Your Designation',
              hint: _profileType == 'company' ? 'e.g., CEO, Founder' : 'e.g., Sales Manager',
            ),
            const SizedBox(height: 20),
          ],
          
          AppInput(
            controller: _websiteController,
            label: 'Website (Optional)',
            hint: 'https://...',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 20),
          AppInput(
            controller: _linkedinController,
            label: 'LinkedIn (Optional)',
            hint: 'Username or URL...',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPage(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _profileType == 'individual' ? 'Your Details' : 'Company Details',
            style: TextStyle(
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.w900,
              color: AppTheme.stone900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _profileType == 'individual'
                ? 'Tell us about your expertise'
                : 'Help us understand what you do',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.stone500,
            ),
          ),
          const SizedBox(height: 32),
          AppInput(
            controller: _productsController,
            label: _profileType == 'individual' 
                ? 'Skills & Expertise' 
                : 'Products & Services',
            hint: _profileType == 'individual'
                ? 'What are you good at?'
                : 'What do you offer?',
            maxLines: 4,
          ),
          const SizedBox(height: 20),
          AppInput(
            controller: _aboutController,
            label: 'About',
            hint: _profileType == 'individual'
                ? 'Describe yourself...'
                : 'Describe your company...',
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildAIConfigPage(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Configuration',
            style: TextStyle(
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.w900,
              color: AppTheme.stone900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Customize how AI assists you',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.stone500,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'AI PERSONALITY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppTheme.stone400,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildAIToneChip('professional', 'Professional'),
              _buildAIToneChip('casual', 'Casual'),
              _buildAIToneChip('formal', 'Formal'),
              _buildAIToneChip('friendly', 'Friendly'),
            ],
          ),
          const SizedBox(height: 32),
          AppInput(
            controller: _contextController,
            label: 'Additional Context',
            hint: 'Any specific information for AI to know...',
            maxLines: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildAIToneChip(String value, String label) {
    final isSelected = _aiTone == value;
    
    return InkWell(
      onTap: () {
        setState(() => _aiTone = value);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.stone900 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.stone900
                : AppTheme.stone200,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppTheme.stone700,
          ),
        ),
      ),
    );
  }
}
