import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../services/api_service.dart';
import '../widgets/app_input.dart';
import '../widgets/app_button.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_section_label.dart';
import '../utils/screen_logger.dart';

/// Full-screen bottom sheet for manual contact entry.
/// Call via [showManualEntrySheet] — do NOT use showAppDialog for this.
Future<bool?> showManualEntrySheet(BuildContext context) {
  return showAppSheet<bool>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => const _ManualEntrySheet(),
  );
}

class _ManualEntrySheet extends StatefulWidget {
  const _ManualEntrySheet();

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> with ScreenLogger {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _jobTitleController.dispose();
    _companyNameController.dispose();
    _linkedinController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ApiService.createContact({
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'job_title': _jobTitleController.text.trim(),
        'company_name': _companyNameController.text.trim(),
        'linkedin_url': _linkedinController.text.trim(),
        'notes': _notesController.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on UnauthorizedException { rethrow; } catch (e) {
      if (mounted) {
        showAppToast(context, 'Failed to save contact');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.theme.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'New Contact',
                    style: context.theme.typography.xl.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.theme.colors.foreground,
                    ),
                  ),
                  const Spacer(),
                  AppButton(
                    onPressed: () => Navigator.pop(context),
                    variant: ButtonVariant.ghost,
                    size: ButtonSize.sm,
                    child: Icon(Icons.close_rounded, size: 18, color: context.theme.colors.mutedForeground),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Scrollable form body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row
                    AppSectionLabel('Basic Info'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AppInput(
                            controller: _firstNameController,
                            label: 'First Name',
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppInput(
                            controller: _lastNameController,
                            label: 'Last Name',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      controller: _emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      controller: _phoneController,
                      label: 'Phone',
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 24),

                    // Professional
                    AppSectionLabel('Professional'),
                    const SizedBox(height: 10),
                    AppInput(
                      controller: _jobTitleController,
                      label: 'Job Title',
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      controller: _companyNameController,
                      label: 'Company',
                    ),
                    const SizedBox(height: 12),
                    AppInput(
                      controller: _linkedinController,
                      label: 'LinkedIn URL',
                      keyboardType: TextInputType.url,
                    ),

                    const SizedBox(height: 24),

                    // Notes
                    AppSectionLabel('Notes'),
                    const SizedBox(height: 10),
                    AppInput(
                      controller: _notesController,
                      label: 'Add a note...',
                      maxLines: 3,
                    ),

                    const SizedBox(height: 28),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Cancel',
                            variant: ButtonVariant.outline,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            label: 'Save Contact',
                            variant: ButtonVariant.primary,
                            isLoading: _isLoading,
                            onPressed: _submit,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
