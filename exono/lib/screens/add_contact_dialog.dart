import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import '../config/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/app_input.dart';
import '../utils/screen_logger.dart';

class AddContactDialog extends StatefulWidget {
  const AddContactDialog({super.key});

  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> with ScreenLogger {
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

  ExonoColors get _c => AppTheme.colorsOf(context);

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
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'job_title': _jobTitleController.text,
        'company_name': _companyNameController.text,
        'linkedin_url': _linkedinController.text,
        'notes': _notesController.text,
      });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showFToast(
          context: context,
          title: Text('Error: $e'),
          variant: FToastVariant.destructive,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Contact',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _c.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField('First Name', _firstNameController, true),
              const SizedBox(height: 12),
              _buildTextField('Last Name', _lastNameController, false),
              const SizedBox(height: 12),
              _buildTextField('Email', _emailController, false, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _buildTextField('Phone', _phoneController, false, keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _buildTextField('Job Title', _jobTitleController, false),
              const SizedBox(height: 12),
              _buildTextField('Company Name', _companyNameController, false),
              const SizedBox(height: 12),
              _buildTextField('LinkedIn URL', _linkedinController, false, keyboardType: TextInputType.url),
              const SizedBox(height: 12),
              _buildTextField('Notes', _notesController, false, maxLines: 3),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FButton(
                    variant: FButtonVariant.ghost,
                    onPress: () => Navigator.pop(context),
                    child: Text('CANCEL', style: TextStyle(color: _c.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  FButton(
                    variant: FButtonVariant.primary,
                    onPress: _isLoading ? null : _submit,
                    child: _isLoading
                        ? SizedBox(width: 20, height: 20, child: FCircularProgress())
                        : const Text('SAVE'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool required, {TextInputType? keyboardType, int maxLines = 1}) {
    return AppInput(
      controller: controller,
      label: label,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: required ? (value) => value == null || value.isEmpty ? 'Required' : null : null,
    );
  }
}
