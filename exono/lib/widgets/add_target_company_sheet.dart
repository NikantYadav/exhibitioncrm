import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../config/app_theme.dart';
import '../services/api_service.dart';
import 'app_avatar.dart';
import 'app_input.dart';

/// Search-and-pick sheet for adding a target company.
/// [onCompanySelected] is called when the user picks an existing company.
/// [onCreatePressed] is called when the user taps "Create (name)" — receives
/// the current search query so the create sheet can pre-fill the name.
/// The caller is responsible for popping this sheet before opening the next one.
class AddTargetCompanySheet extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onCompanySelected;
  final ValueChanged<String> onCreatePressed;

  const AddTargetCompanySheet({
    super.key,
    required this.onCompanySelected,
    required this.onCreatePressed,
  });

  @override
  State<AddTargetCompanySheet> createState() => _AddTargetCompanySheetState();
}

class _AddTargetCompanySheetState extends State<AddTargetCompanySheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<Map<String, dynamic>> _companies = [];
  bool _isSearching = true;

  @override
  void initState() {
    super.initState();
    ApiService.getCompanies(query: '').then((results) {
      results.sort((a, b) => (a['name'] as String? ?? '').toLowerCase().compareTo((b['name'] as String? ?? '').toLowerCase()));
      if (mounted) setState(() { _companies = results; _isSearching = false; });
    }).catchError((_) {
      if (mounted) setState(() => _isSearching = false);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSearch(String val) async {
    setState(() { _query = val; _isSearching = true; });
    try {
      final results = await ApiService.getCompanies(query: val);
      results.sort((a, b) => (a['name'] as String? ?? '').toLowerCase().compareTo((b['name'] as String? ?? '').toLowerCase()));
      if (mounted) setState(() { _companies = results; _isSearching = false; });
    } on UnauthorizedException { rethrow; } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    final mq = MediaQuery.of(context);
    // Keyboard avoidance is handled centrally by showAppSheet (it pads the
    // sheet by the keyboard inset). We only size to a fraction of the screen
    // here; do NOT subtract viewInsets.bottom or the keyboard is double-counted.
    final maxHeight = mq.size.height - mq.padding.top - 24;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: (mq.size.height * 0.7).clamp(0.0, maxHeight),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Target Company',
                    style: context.theme.typography.xl.copyWith(fontWeight: FontWeight.w600, color: context.theme.colors.foreground),
                  ),
                  const SizedBox(height: 16),
                  AppInput(
                    controller: _searchCtrl,
                    autofocus: true,
                    hintText: 'Search companies...',
                    prefixIcon: Icon(Icons.search, color: c.accent),
                    onChanged: _onSearch,
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(c)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ExonoColors c) {
    if (_isSearching) {
      return const Center(child: FCircularProgress());
    }
    if (_companies.isEmpty && _query.isEmpty) {
      return Center(
        child: Text(
          'Search for a company above',
          style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground),
        ),
      );
    }
    if (_companies.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => widget.onCreatePressed(_query),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Icon(Icons.add_circle_outline, color: c.accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Create "$_query"', style: context.theme.typography.sm.copyWith(color: context.theme.colors.foreground, fontWeight: FontWeight.w500)),
                    Text('No match found — add as new company', style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground)),
                  ])),
                ]),
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _companies.length + (_query.isNotEmpty ? 1 : 0),
      itemBuilder: (_, i) {
        // Last item when searching: "Create X" row
        if (_query.isNotEmpty && i == _companies.length) {
          return GestureDetector(
            onTap: () => widget.onCreatePressed(_query),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                Icon(Icons.add_circle_outline, color: c.accent, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Create "$_query"', style: context.theme.typography.sm.copyWith(color: context.theme.colors.foreground, fontWeight: FontWeight.w500)),
                  Text('Not in the list? Add as new company', style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground)),
                ])),
              ]),
            ),
          );
        }
        final co = _companies[i];
        final coName = co['name'] as String;
        final initials = coName.length >= 2 ? coName.substring(0, 2).toUpperCase() : coName.toUpperCase();
        return GestureDetector(
          onTap: () => widget.onCompanySelected(co),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              AppAvatar(initials: initials, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(coName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w500, color: context.theme.colors.foreground)),
                  if (co['industry'] != null)
                    Text(co['industry'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground)),
                ]),
              ),
              Icon(Icons.add_circle_outline, color: c.accent, size: 22),
            ]),
          ),
        );
      },
    );
  }
}
