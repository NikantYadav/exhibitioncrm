import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/entry_flow_components.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _toggleMode(bool login) {
    if (_isLoading || _isLogin == login) return;
    setState(() => _isLogin = login);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return EntryFlowScaffold(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 8, isMobile ? 16 : 24, isMobile ? 24 : 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EntryFlowTopBar(
                  leadingIcon: Icons.lock_open_rounded,
                  title: 'EXONO',
                  badgeLabel: 'Secure Access',
                ),
                const SizedBox(height: 24),
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroCard(),
                      const SizedBox(height: 16),
                      _buildAuthCard(colors),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 11, child: _buildHeroCard()),
                      const SizedBox(width: 16),
                      Expanded(flex: 9, child: _buildAuthCard(colors)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    final isLogin = _isLogin;

    return EntryPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EntryEyebrow(label: isLogin ? 'WELCOME BACK' : 'CREATE ACCOUNT'),
          const SizedBox(height: 18),
          Text(
            isLogin
                ? 'Step back into your command center.'
                : 'Create your mobile-first event operating hub.',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 12),
          Text(
            isLogin
                ? 'Sign in to continue into targets, events, capture, contacts, follow-ups, and AI assistance.'
                : 'Create your account, finish profile setup, and choose between assistant chat or the full CRM shell.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              EntryChip(icon: Icons.track_changes_rounded, label: 'Targets'),
              EntryChip(icon: Icons.calendar_today_rounded, label: 'Events'),
              EntryChip(icon: Icons.qr_code_scanner_rounded, label: 'Capture'),
              EntryChip(icon: Icons.forum_rounded, label: 'AI Assist'),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              if (compact) {
                return const Column(
                  children: [
                    EntryMetricCard(
                      icon: Icons.flash_on_rounded,
                      title: 'Workflow',
                      value: 'Fast',
                      subtitle: 'Mobile-ready flows for event-day use',
                    ),
                    SizedBox(height: 12),
                    EntryMetricCard(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Assistant',
                      value: 'Live',
                      subtitle: 'Drafting, summaries, and guided follow-ups',
                    ),
                  ],
                );
              }

              return const Row(
                children: [
                  Expanded(
                    child: EntryMetricCard(
                      icon: Icons.flash_on_rounded,
                      title: 'Workflow',
                      value: 'Fast',
                      subtitle: 'Mobile-ready flows for event-day use',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: EntryMetricCard(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Assistant',
                      value: 'Live',
                      subtitle: 'Drafting, summaries, and guided follow-ups',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const EntrySoftTile(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EntryBullet(
                  title: 'Soft-glass mobile UI',
                  description: 'Built for compact screens with high-contrast cards, rounded actions, and low-friction flows.',
                ),
                SizedBox(height: 12),
                EntryBullet(
                  title: 'Frontend-first experience',
                  description: 'Core interactions stay responsive even where backend work is still mocked or pending.',
                ),
                SizedBox(height: 12),
                EntryBullet(
                  title: 'Theme-ready foundation',
                  description: 'Day and night mode are now driven from centralized design tokens.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard(ExonoColors colors) {
    return EntryPanel(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildModeSwitch(colors),
            const SizedBox(height: 24),
            Text(
              _isLogin ? 'Welcome back' : 'Create account',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              _isLogin
                  ? 'Use your credentials to continue into Exono.'
                  : 'Start with your account details. You’ll finish profile setup on the next step.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            if (!_isLogin) ...[
              EntryTextField(
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
            EntryTextField(
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
            EntryTextField(
              controller: _passwordController,
              label: 'Password',
              hint: _isLogin ? 'Enter your password' : 'Create a password',
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.lock_outline_rounded,
              suffix: IconButton(
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: colors.textSecondary,
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
            const SizedBox(height: 18),
            EntrySoftTile(
              child: Text(
                _isLogin
                    ? 'Mode selection comes next after sign-in.'
                    : 'After signup, onboarding collects your company and AI profile details.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 20),
            EntryPrimaryButton(
              label: _isLogin ? 'SIGN IN' : 'CREATE ACCOUNT',
              loading: _isLoading,
              icon: _isLogin ? Icons.login_rounded : Icons.person_add_alt_rounded,
              onPressed: _handleSubmit,
            ),
            const SizedBox(height: 16),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(
                    _isLogin ? 'Need a new account?' : 'Already have an account?',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  GestureDetector(
                    onTap: () => _toggleMode(!_isLogin),
                    child: Text(
                      'Switch mode',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.accentStrong,
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

  Widget _buildModeSwitch(ExonoColors colors) {
    return EntrySoftTile(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildSwitchChip(
              label: 'Sign In',
              isSelected: _isLogin,
              colors: colors,
              onTap: () => _toggleMode(true),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildSwitchChip(
              label: 'Sign Up',
              isSelected: !_isLogin,
              colors: colors,
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
    required ExonoColors colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [colors.accent, colors.accentStrong])
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.transparent : colors.border.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: isSelected ? (colors.isDark ? colors.background : Colors.white) : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
