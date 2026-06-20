import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/api_service.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_feedback.dart';
import '../widgets/entry_flow_components.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _fadeController.dispose();
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
          context.go('/');
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
            await prefs.setString('access_token', session['access_token'] as String? ?? '');
            await prefs.setString('refresh_token', session['refresh_token'] as String? ?? '');
          }
          if (!mounted) return;
          context.go('/onboarding');
        } else {
          final error = result['error'] as String? ?? 'Signup failed';
          final alreadyExists = error.toLowerCase().contains('already registered') ||
              error.toLowerCase().contains('already exists') ||
              error.toLowerCase().contains('email address is already');
          if (alreadyExists) {
            _showAccountExistsDialog();
          } else {
            _showError(error);
          }
        }
      }
    } on UnauthorizedException { rethrow; } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Something went wrong. Please try again.');
    }
  }

  Future<void> _showAccountExistsDialog() async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Account already exists',
      message: 'An account with this email already exists. Please log in instead.',
      confirmLabel: 'Go to Login',
      cancelLabel: 'Cancel',
    );
    if (confirmed == true && mounted) {
      setState(() => _isLogin = true);
    }
  }

  void _showError(String message) => showAppToast(context, message);

  void _toggleMode(bool login) {
    if (_isLoading || _isLogin == login) return;
    _fadeController.reset();
    setState(() => _isLogin = login);
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return EntryFlowScaffold(
      showGrid: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;
          return isDesktop
              ? _buildDesktopLayout(colors)
              : _buildMobileLayout(colors);
        },
      ),
    );
  }

  Widget _buildMobileLayout(ExonoColors colors) {
    return Stack(
      children: [
        _themeToggle(colors),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeTransition(opacity: _fadeAnim, child: _buildCard(colors)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(ExonoColors colors) {
    return Row(
      children: [
        // left: form panel
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              _themeToggle(colors),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: FadeTransition(opacity: _fadeAnim, child: _buildCard(colors)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // right: brand panel
        Expanded(
          flex: 6,
          child: _BrandPanel(colors: colors),
        ),
      ],
    );
  }

  Widget _themeToggle(ExonoColors colors) {
    return const Positioned(
      bottom: 16,
      right: 16,
      child: EntryThemeToggleButton(),
    );
  }

  Widget _buildCard(ExonoColors colors) {
    return EntryPanel(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCardHeader(colors),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isLogin) ...[
                    EntryTextField(
                      controller: _nameController,
                      label: 'Full name',
                      hint: 'Alex Morgan',
                      prefixIcon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter your name';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  EntryTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'you@example.com',
                    prefixIcon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter your email';
                      if (!v.contains('@')) return 'Please enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  EntryTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: _isLogin ? 'Enter your password' : 'Create a password',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleSubmit(),
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: colors.textMuted,
                        size: 18,
                      ),
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter your password';
                      if (v.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  EntryPrimaryButton(
                    label: _isLogin ? 'SIGN IN' : 'CREATE ACCOUNT',
                    icon: _isLogin ? Icons.login_rounded : Icons.person_add_alt_rounded,
                    loading: _isLoading,
                    onPressed: _handleSubmit,
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: GestureDetector(
                      onTap: () => _toggleMode(!_isLogin),
                      child: RichText(
                        text: TextSpan(
                          style: context.theme.typography.sm.copyWith(color: colors.textMuted),
                          children: [
                            TextSpan(text: _isLogin ? "Don't have an account? " : 'Already have an account? '),
                            TextSpan(
                              text: _isLogin ? 'Create one' : 'Sign in',
                              style: TextStyle(
                                color: colors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHeader(ExonoColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // brand mark
          SvgPicture.asset(
            colors.isDark
                ? 'assets/images/logo-white.svg'
                : 'assets/images/logo-black.svg',
            width: 40,
            height: 40,
          ),
          const SizedBox(height: 16),
          Text(
            _isLogin ? 'Welcome back' : 'Create account',
            style: context.theme.typography.xl.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: colors.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isLogin
                ? 'Sign in to continue to your workspace'
                : 'Get started — your workspace is waiting',
            style: context.theme.typography.sm.copyWith(
              color: colors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

}

class _BrandPanel extends StatelessWidget {
  final ExonoColors colors;
  const _BrandPanel({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.accent.withValues(alpha: 0.12),
            colors.accentStrong.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(left: BorderSide(color: colors.border)),
      ),
      child: Stack(
        children: [
          // subtle dot pattern
          Positioned.fill(child: CustomPaint(painter: _DotGridPainter(colors))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // logo mark
                SvgPicture.asset(
                  colors.isDark
                      ? 'assets/images/logo-white.svg'
                      : 'assets/images/logo-black.svg',
                  width: 44,
                  height: 44,
                ),
                const SizedBox(height: 12),
                Text(
                  'Exono',
                  style: context.theme.typography.lg.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                // headline
                Text(
                  'Never lose a lead.\nNever miss a follow-up.',
                  style: context.theme.typography.xl2.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                    height: 1.2,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Capture leads on the expo floor, remember every interaction, and follow up before the conversation goes cold.',
                  style: context.theme.typography.sm.copyWith(
                    height: 1.6,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),
                // feature list
                ..._features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colors.accentSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.border),
                        ),
                        child: Icon(f.$1, size: 16, color: colors.accentStrong),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.$2,
                              style: context.theme.typography.sm.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              f.$3,
                              style: context.theme.typography.xs.copyWith(color: colors.textMuted, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
                const Spacer(),
                // bottom tagline
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 14, color: colors.accentStrong),
                      const SizedBox(width: 8),
                      Text(
                        'Trusted by teams working the exhibition floor',
                        style: context.theme.typography.xs.copyWith(
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _features = [
    (Icons.qr_code_scanner_rounded, 'Instant capture', 'Scan badges and business cards in seconds'),
    (Icons.psychology_outlined, 'Relationship memory', 'Every interaction remembered, automatically'),
    (Icons.notifications_active_rounded, 'Smart follow-ups', 'Never let a hot lead go cold'),
  ];
}

class _DotGridPainter extends CustomPainter {
  final ExonoColors colors;
  _DotGridPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colors.border.withValues(alpha: colors.isDark ? 0.18 : 0.30)
      ..strokeWidth = 0;
    const spacing = 28.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter old) => old.colors != colors;
}

