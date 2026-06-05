import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const Color _backgroundColor = Color(0xFF080808);
  static const Color _surfaceColor = Color(0xFF141313);
  static const Color _surfaceAltColor = Color(0xFF1C1B1B);
  static const Color _borderColor = Color(0xFF444748);
  static const Color _mutedColor = Color(0xFFC4C7C8);

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();

      if (_isLogin) {
        final result = await authProvider.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (!mounted) return;

        setState(() => _isLoading = false);
        if (result['success'] == true) {
          Navigator.of(context).pushReplacementNamed('/mode-selection');
        } else {
          _showError(result['error'] as String? ?? 'Login failed');
        }
      } else {
        final result = await authProvider.signup(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
        );
        if (!mounted) return;

        setState(() => _isLoading = false);
        if (result['success'] == true) {
          final session = result['session'] as Map<String, dynamic>?;
          if (session != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'access_token',
              session['access_token'] as String? ?? '',
            );
            await prefs.setString(
              'refresh_token',
              session['refresh_token'] as String? ?? '',
            );
          }
          if (!mounted) return;

          Navigator.of(context).pushReplacementNamed(
            '/onboarding',
            arguments: {
              'name': _nameController.text.trim(),
              'email': _emailController.text.trim(),
              'token': session?['access_token'] ?? '',
            },
          );
        } else {
          _showError(result['error'] as String? ?? 'Signup failed');
        }
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

  void _toggleMode(bool login) {
    if (_isLoading || _isLogin == login) return;
    setState(() => _isLogin = login);
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
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24,
              8,
              isMobile ? 16 : 24,
              isMobile ? 24 : 32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 24),
                    if (isMobile)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroCard(isMobile),
                          const SizedBox(height: 16),
                          _buildAuthCard(isMobile),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 11, child: _buildHeroCard(isMobile)),
                          const SizedBox(width: 16),
                          Expanded(flex: 9, child: _buildAuthCard(isMobile)),
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
              Icons.lock_open_rounded,
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
                Icon(Icons.verified_user_rounded, size: 16, color: _mutedColor),
                SizedBox(width: 8),
                Text(
                  'Secure Access',
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

  Widget _buildHeroCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderColor),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -12,
            right: -12,
            child: Icon(
              Icons.shield_moon_rounded,
              size: isMobile ? 88 : 120,
              color: Colors.white.withValues(alpha: 0.08),
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
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: const Text(
                  'INTELLIGENT CRM ACCESS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _isLogin
                    ? 'Step back into your command center.'
                    : 'Create your event-day command center.',
                style: TextStyle(
                  fontSize: isMobile ? 30 : 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.4,
                  color: Colors.white,
                  height: 1.02,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isLogin
                    ? 'Sign in to continue into targets, events, capture, contacts, follow-ups, and AI assistance.'
                    : 'Create your account to unlock the mobile CRM workflow, then finish your setup in onboarding.',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: _mutedColor,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInsightPill(Icons.track_changes_rounded, 'Targets'),
                  _buildInsightPill(Icons.calendar_today_rounded, 'Events'),
                  _buildInsightPill(Icons.qr_code_scanner_rounded, 'Capture'),
                  _buildInsightPill(Icons.forum_rounded, 'AI Assist'),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What you get',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: _mutedColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildBullet(
                      title: 'Fast mobile workflow',
                      description:
                          'Designed for event-floor execution with capture and follow-up flow baked in.',
                    ),
                    const SizedBox(height: 12),
                    _buildBullet(
                      title: 'Frontend-first interactions',
                      description:
                          'UI actions remain responsive even where backend integration is still mocked.',
                    ),
                    const SizedBox(height: 12),
                    _buildBullet(
                      title: 'AI + CRM split mode',
                      description:
                          'Choose between focused assistant chat and the full CRM shell after sign-in.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderColor),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModeSwitch(),
            const SizedBox(height: 24),
            Text(
              _isLogin ? 'Welcome back' : 'Create account',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.0,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isLogin
                  ? 'Use your credentials to continue into Exono.'
                  : 'Start with your account details. You’ll finish profile setup on the next step.',
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: _mutedColor,
              ),
            ),
            const SizedBox(height: 24),
            if (!_isLogin) ...[
              _buildTextField(
                controller: _nameController,
                label: 'Full name',
                hint: 'Alex Morgan',
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                prefixIcon: Icons.person_outline_rounded,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.alternate_email_rounded,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              hint: _isLogin ? 'Enter your password' : 'Create a password',
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.lock_outline_rounded,
              suffix: IconButton(
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _mutedColor,
                  size: 20,
                ),
                splashRadius: 20,
              ),
              onSubmitted: (_) => _handleSubmit(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            if (_isLogin)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Mode selection comes next after sign-in.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'After signup, onboarding collects your company and AI profile details.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.4),
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
                        _isLogin ? 'SIGN IN' : 'CREATE ACCOUNT',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(
                    _isLogin
                        ? 'Need a new account?'
                        : 'Already have an account?',
                    style: const TextStyle(fontSize: 13, color: _mutedColor),
                  ),
                  GestureDetector(
                    onTap: () => _toggleMode(!_isLogin),
                    child: const Text(
                      'Switch mode',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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

  Widget _buildModeSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surfaceAltColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSwitchChip(
              label: 'Sign In',
              isSelected: _isLogin,
              onTap: () => _toggleMode(true),
            ),
          ),
          Expanded(
            child: _buildSwitchChip(
              label: 'Sign Up',
              isSelected: !_isLogin,
              onTap: () => _toggleMode(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: isSelected ? _backgroundColor : _mutedColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    IconData? prefixIcon,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
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
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          obscureText: obscureText,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF8E9192), fontSize: 14),
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, color: _mutedColor, size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: _surfaceAltColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppTheme.destructive),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: AppTheme.destructive,
                width: 1.2,
              ),
            ),
            errorStyle: const TextStyle(
              fontSize: 12,
              color: AppTheme.destructive,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet({required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: _mutedColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
