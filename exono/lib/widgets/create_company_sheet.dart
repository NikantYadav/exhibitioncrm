import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'app_button.dart';
import 'app_feedback.dart';
import 'app_input.dart';
import 'app_sheet_content.dart';

/// Bottom sheet content for creating a new company.
/// Used from both pre-event planning and the live event home screen.
class CreateCompanySheet extends StatefulWidget {
  final String initialName;
  final ValueChanged<Map<String, dynamic>> onCreated;

  const CreateCompanySheet({
    super.key,
    required this.initialName,
    required this.onCreated,
  });

  @override
  State<CreateCompanySheet> createState() => _CreateCompanySheetState();
}

class _CreateCompanySheetState extends State<CreateCompanySheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _industryCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _websiteCtrl;

  String? _nameError;
  String? _industryError;
  String? _websiteError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _industryCtrl = TextEditingController();
    _locationCtrl = TextEditingController();
    _websiteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _industryCtrl.dispose();
    _locationCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  String? _validateWebsite(String val) {
    if (val.isEmpty) return null;
    final uri = Uri.tryParse(val);
    return (uri == null || !uri.hasScheme || !uri.host.contains('.'))
        ? 'Enter a valid URL (e.g. https://samtac.ae)'
        : null;
  }

  bool _runValidation() {
    _nameError = _nameCtrl.text.trim().isEmpty ? 'Company name is required' : null;
    _industryError = _industryCtrl.text.trim().isEmpty ? 'Industry is required' : null;
    _websiteError = _validateWebsite(_websiteCtrl.text.trim());
    return _nameError == null && _industryError == null && _websiteError == null;
  }

  Future<void> _submit() async {
    if (!_runValidation()) { setState(() {}); return; }
    setState(() => _isSubmitting = true);
    final name = _nameCtrl.text.trim();
    final industry = _industryCtrl.text.trim();
    final location = _locationCtrl.text.trim();
    final website = _websiteCtrl.text.trim();
    try {
      final companyData = <String, dynamic>{'name': name, 'industry': industry};
      if (location.isNotEmpty) { companyData['location'] = location; }
      if (website.isNotEmpty) { companyData['website'] = website; }
      final created = await ApiService.createCompany(companyData);
      if (mounted) { widget.onCreated(created); }
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showAppToast(context, 'Failed to add company.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetContent(
      title: 'New Company',
      subtitle: 'Adding more details helps the AI research the right company.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppInput(
            controller: _nameCtrl,
            autofocus: true,
            labelText: 'Company Name',
            error: _nameError,
            onChanged: (_) => setState(() {
              _nameError = _nameCtrl.text.trim().isEmpty ? 'Company name is required' : null;
            }),
          ),
          const SizedBox(height: 12),
          AppInput(
            controller: _industryCtrl,
            labelText: 'Industry',
            hintText: 'e.g. Boilers & Heating, Logistics',
            error: _industryError,
            onChanged: (_) => setState(() {
              _industryError = _industryCtrl.text.trim().isEmpty ? 'Industry is required' : null;
            }),
          ),
          const SizedBox(height: 12),
          AppInput(
            controller: _locationCtrl,
            labelText: 'Country / City (optional)',
            hintText: 'e.g. UAE, Dubai',
          ),
          const SizedBox(height: 12),
          AppInput(
            controller: _websiteCtrl,
            labelText: 'Website (optional)',
            hintText: 'e.g. https://samtac.ae',
            keyboardType: TextInputType.url,
            error: _websiteError,
            onChanged: (_) => setState(() {
              _websiteError = _validateWebsite(_websiteCtrl.text.trim());
            }),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'CONTINUE',
            fullWidth: true,
            variant: ButtonVariant.primary,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
