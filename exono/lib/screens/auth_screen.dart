import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_button.dart';
import '../widgets/app_feedback.dart';
import '../widgets/entry_flow_components.dart';
import '../utils/screen_logger.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with ScreenLogger {
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('An error occurred: $e');
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

  void _showError(String message) {
    showAppToast(context, message);
  }

  void _toggleMode(bool login) {
    if (_isLoading || _isLogin == login) return;
    setState(() => _isLogin = login);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsOf(context);

    return EntryFlowScaffold(
      showGrid: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _buildAuthCard(colors),
            ),
          ),
        ),
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
            if (!_isLogin) ...[
              EntryTextField(
                controller: _nameController,
                label: "Full name",
                hint: "Alex Morgan",
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                prefixIcon: Icons.person_outline_rounded,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter your name";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
            EntryTextField(
              controller: _emailController,
              label: "Email",
              hint: "you@example.com",
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.alternate_email_rounded,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Please enter your email";
                }
                if (!value.contains("@")) {
                  return "Please enter a valid email";
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            EntryTextField(
              controller: _passwordController,
              label: "Password",
              hint: _isLogin ? "Enter your password" : "Create a password",
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
                  return "Please enter your password";
                }
                if (value.length < 6) {
                  return "Password must be at least 6 characters";
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            EntryPrimaryButton(
              label: _isLogin ? "SIGN IN" : "CREATE ACCOUNT",
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
                    _isLogin ? "Don't have an account?" : "Already have an account?",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  AppButton(
                    label: _isLogin ? 'Create one' : 'Sign in',
                    onPressed: () => _toggleMode(!_isLogin),
                    variant: ButtonVariant.ghost,
                    size: ButtonSize.sm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
