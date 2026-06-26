import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../utils/safe_area_insets.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/contact.dart';
import 'app_shell.dart' show navBarHide, navBarShow;
import '../models/contact_profile_data.dart';
import '../providers/offline_provider.dart';
import '../providers/sync_provider.dart';
import '../repositories/contacts_repository.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_header.dart';
import '../widgets/app_input.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_offline_screen.dart';
import '../widgets/skeleton_loader.dart';
import 'manual_entry_screen.dart';
import '../utils/screen_logger.dart';

class ContactsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const ContactsScreen({super.key, this.onNavigateTab});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> with ScreenLogger {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _filterCompany;
  String? _filterLocation;
  String? _filterStatus;
  String? _filterEventId;

  String _searchQuery = '';

  // Alphabet index
  final List<String> _alphabet = ['#', ...List.generate(26, (i) => String.fromCharCode(65 + i))];

  List<ContactProfileData> _filteredContacts(List<ContactProfileData> allContacts) {
    final query = _searchQuery.trim().toLowerCase();
    return allContacts.where((c) {
      if (query.isNotEmpty &&
          !c.listName.toLowerCase().contains(query) &&
          !c.listSubtitle.toLowerCase().contains(query) &&
          !c.location.toLowerCase().contains(query)) { return false; }
      if (_filterCompany != null && c.company != _filterCompany) { return false; }
      if (_filterLocation != null && c.location != _filterLocation) { return false; }
      if (_filterStatus != null && c.followUpStatus != _filterStatus) { return false; }
      if (_filterEventId != null && !c.linkedEvents.any((e) => e.id == _filterEventId)) { return false; }
      return true;
    }).toList();
  }

  /// Groups filtered contacts alphabetically. Returns list of (letter, contacts).
  List<(String, List<ContactProfileData>)> _groupedContacts(List<ContactProfileData> allContacts) {
    final filtered = _filteredContacts(allContacts);
    final Map<String, List<ContactProfileData>> map = {};
    for (final c in filtered) {
      final first = c.listName.trim().isEmpty ? '#' : c.listName[0].toUpperCase();
      final key = RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
      map.putIfAbsent(key, () => []).add(c);
    }
    final sorted = map.entries.toList()
      ..sort((a, b) {
        if (a.key == '#') return -1;
        if (b.key == '#') return 1;
        return a.key.compareTo(b.key);
      });
    return sorted.map((e) => (e.key, e.value)).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<OfflineProvider>().isOnline;
    if (!isOnline) return const AppOfflineScreen(title: 'Contacts');

    final contactsRepo = context.read<SyncProvider>().contacts;

    return FScaffold(
      header: AppHeader(
        actionIcon: Icons.add_rounded,
        actionTooltip: 'Add Contact',
        onActionPressed: () => _showAddContactSheet(contactsRepo),
      ),
      childPad: false,
      child: StreamBuilder<List<Contact>>(
        stream: contactsRepo.watchAllWithCompany(),
        builder: (context, snapshot) {
          // Surface a stream error instead of skeletoning forever — a silent
          // drift error here previously looked like an infinite load.
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load contacts: ${snapshot.error}',
                  style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          // Only skeleton before the first emission. An empty table emits [] and
          // falls through to _buildListBody, which renders the empty state.
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return _buildSkeleton();
          }
          final allContacts = (snapshot.data ?? []).map(mapContactToProfileData).toList();
          return _buildListBody(allContacts, contactsRepo);
        },
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 8,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: SkeletonCard(),
      ),
    );
  }

  bool get _hasActiveFilters =>
      _filterCompany != null || _filterLocation != null ||
      _filterStatus != null || _filterEventId != null;

  Widget _buildSearchBar(FThemeData theme, List<ContactProfileData> allContacts) {
    final activeCount = [_filterCompany, _filterLocation, _filterStatus, _filterEventId]
        .where((f) => f != null)
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: AppInput(
              controller: _searchController,
              hint: 'Name, phone or card number',
              onChanged: (value) => setState(() => _searchQuery = value),
              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.colorsOf(context).accent, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          AppButton(
            variant: _hasActiveFilters ? ButtonVariant.primary : ButtonVariant.outline,
            onPressed: () => _showFilterSheet(allContacts),
            prefixIcon: Icon(Icons.tune_rounded, size: 18, color: AppTheme.colorsOf(context).accent),
            label: activeCount > 0 ? 'Filters ($activeCount)' : 'Filter',
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(width: 4),
            AppButton(
              variant: ButtonVariant.ghost,
              onPressed: () => setState(() {
                _filterCompany = null;
                _filterLocation = null;
                _filterStatus = null;
                _filterEventId = null;
              }),
              child: Icon(Icons.close_rounded, size: 18, color: AppTheme.colorsOf(context).accent),
            ),
          ],
        ],
      ),
    );
  }

  void _showFilterSheet(List<ContactProfileData> allContacts) {
    final allCompanies = allContacts
        .map((c) => c.company).where((c) => c.isNotEmpty).toSet().toList()..sort();
    final allLocations = allContacts
        .map((c) => c.location).where((l) => l.isNotEmpty).toSet().toList()..sort();
    final eventMap = <String, Event>{};
    for (final c in allContacts) {
      for (final e in c.linkedEvents) { eventMap[e.id] = e; }
    }
    final allEvents = eventMap.values.toList()..sort((a, b) => a.name.compareTo(b.name));

    const statuses = [
      ('not_contacted', 'Not Contacted'),
      ('contacted', 'Contacted'),
    ];

    showAppSheet(
      context: context,
      builder: (ctx) => _FilterSheet(
        initialCompany: _filterCompany,
        initialLocation: _filterLocation,
        initialStatus: _filterStatus,
        initialEventId: _filterEventId,
        allCompanies: allCompanies,
        allLocations: allLocations,
        allEvents: allEvents,
        statuses: statuses,
        onApply: (company, location, status, eventId) {
          setState(() {
            _filterCompany = company;
            _filterLocation = location;
            _filterStatus = status;
            _filterEventId = eventId;
          });
        },
      ),
    );
  }

  Widget _buildListBody(List<ContactProfileData> allContacts, ContactsRepository contactsRepo) {
    final theme = context.theme;
    final groups = _groupedContacts(allContacts);

    return Column(
      children: [
        _buildSearchBar(theme, allContacts),
        Expanded(
          child: groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No contacts found.',
                        style: theme.typography.sm.copyWith(color: theme.colors.mutedForeground),
                      ),
                      if (_hasActiveFilters || _searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Clear search & filters',
                          variant: ButtonVariant.ghost,
                          onPressed: () => setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                            _filterCompany = null;
                            _filterLocation = null;
                            _filterStatus = null;
                            _filterEventId = null;
                          }),
                        ),
                      ],
                    ],
                  ),
                )
              : Stack(
                  children: [
                    _buildContactList(groups, theme),
                    Positioned(
                      right: 4,
                      top: 0,
                      bottom: 0,
                      child: _buildAlphabetBar(groups, theme),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildContactList(List<(String, List<ContactProfileData>)> groups, FThemeData theme) {
    final items = <Widget>[];

    for (final group in groups) {
      final letter = group.$1;
      final contacts = group.$2;
      items.add(_buildSectionHeader(letter, theme));
      for (final contact in contacts) {
        items.add(_buildContactRow(contact, theme));
      }
    }

    items.add(SizedBox(height: bottomScrollInset(context)));

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(right: 20),
      children: items,
    );
  }

  Widget _buildSectionHeader(String letter, FThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 0, 4),
      child: Text(
        letter,
        style: theme.typography.sm.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colors.foreground,
        ),
      ),
    );
  }

  Widget _buildContactRow(ContactProfileData contact, FThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: FTappable(
        onPress: () => context.push('/contacts/${contact.id}'),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          radius: 16,
          child: Row(
            children: [
              contact.avatarUrl.isNotEmpty
                  ? AppAvatar.network(url: contact.avatarUrl, initials: contact.initials, size: 46)
                  : AppAvatar(initials: contact.initials, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.listName,
                      style: theme.typography.sm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colors.foreground,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      contact.phone.isNotEmpty ? contact.phone : contact.listSubtitle,
                      style: theme.typography.xs.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.colorsOf(context).accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlphabetBar(List<(String, List<ContactProfileData>)> groups, FThemeData theme) {
    final presentLetters = groups.map((g) => g.$1).toSet();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _alphabet.map((letter) {
        final active = presentLetters.contains(letter);
        return GestureDetector(
          onTap: active ? () => _scrollToLetter(letter, groups) : null,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 20,
            height: 16,
            child: Center(
              child: Text(
                letter,
                style: theme.typography.xs.copyWith(
                  fontWeight: FontWeight.w600,
                  color: active ? theme.colors.primary : theme.colors.mutedForeground.withAlpha(80),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _scrollToLetter(String letter, List<(String, List<ContactProfileData>)> groups) {
    // Count items before this letter's group
    double offset = 0;
    const sectionHeaderHeight = 34.0;
    const rowHeight = 66.0;
    const dividerHeight = 1.0;

    for (final group in groups) {
      if (group.$1 == letter) break;
      offset += sectionHeaderHeight;
      final count = group.$2.length;
      offset += count * rowHeight;
      if (count > 1) { offset += (count - 1) * dividerHeight; }
    }

    _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _showAddContactSheet(ContactsRepository contactsRepo) {
    showAppSheet(
      context: context,
      builder: (ctx) => _AddContactSheet(onContactAdded: contactsRepo.catchUp),
    );
  }

}

// ─── Add Contact Sheet ────────────────────────────────────────────────────────

class _AddContactSheet extends StatelessWidget {
  final VoidCallback onContactAdded;

  const _AddContactSheet({required this.onContactAdded});

  Future<void> _showBulkImportSheet(BuildContext context) async {
    await showAppSheet(
      context: context,
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: sheetCtx.theme.colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.upload_file_outlined, color: sheetCtx.theme.colors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Bulk Import Contacts', style: sheetCtx.theme.typography.lg.copyWith(fontWeight: FontWeight.w700, color: sheetCtx.theme.colors.foreground)),
                    Text('Upload a CSV or Excel file', style: sheetCtx.theme.typography.xs.copyWith(color: sheetCtx.theme.colors.mutedForeground)),
                  ]),
                ),
              ]),
              const SizedBox(height: 24),
              Text('Supported columns', style: sheetCtx.theme.typography.sm.copyWith(fontWeight: FontWeight.w600, color: sheetCtx.theme.colors.foreground)),
              const SizedBox(height: 10),
              _buildFieldRow(sheetCtx, Icons.person_outline, 'name / first_name', 'Contact name — required', true),
              const SizedBox(height: 8),
              _buildFieldRow(sheetCtx, Icons.business_outlined, 'company', 'Company name — optional', false),
              const SizedBox(height: 8),
              _buildFieldRow(sheetCtx, Icons.phone_outlined, 'phone', 'Phone number — optional', false),
              const SizedBox(height: 8),
              _buildFieldRow(sheetCtx, Icons.email_outlined, 'email', 'Email address — optional', false),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ColoredBox(
                  color: AppTheme.colorsOf(sheetCtx).surfaceAlt,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Example', style: sheetCtx.theme.typography.xs.copyWith(fontWeight: FontWeight.w600, color: sheetCtx.theme.colors.mutedForeground, letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      Text(
                        'name,company,phone,email\nJane Smith,Acme Corp,+1234567890,jane@acme.com\nJohn Doe,,,',
                        style: sheetCtx.theme.typography.xs.copyWith(
                          fontFamily: 'monospace',
                          color: sheetCtx.theme.colors.foreground,
                          height: 1.6,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'CHOOSE FILE',
                fullWidth: true,
                variant: ButtonVariant.primary,
                prefixIcon: Icon(Icons.folder_open_outlined, size: 18, color: AppTheme.colorsOf(context).accent),
                onPressed: () async {
                  Navigator.of(sheetCtx).pop();
                  await _pickAndUpload(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldRow(BuildContext context, IconData icon, String label, String description, bool required) {
    final c = AppTheme.colorsOf(context);
    return Row(children: [
      Icon(icon, size: 16, color: required ? c.accent : context.theme.colors.mutedForeground),
      const SizedBox(width: 10),
      Expanded(
        child: RichText(
          text: TextSpan(children: [
            TextSpan(text: label, style: context.theme.typography.sm.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w600, color: context.theme.colors.foreground)),
            TextSpan(text: '  $description', style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground)),
          ]),
        ),
      ),
      if (required)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
          child: Text('required', style: context.theme.typography.xs.copyWith(color: c.accent, fontWeight: FontWeight.w600)),
        )
      else
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: context.theme.colors.border.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4)),
          child: Text('optional', style: context.theme.typography.xs.copyWith(color: context.theme.colors.mutedForeground, fontWeight: FontWeight.w600)),
        ),
    ]);
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    } catch (_) {
      if (context.mounted) showAppToast(context, 'Could not open file picker.');
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final name = file.name.toLowerCase();
    if (!name.endsWith('.csv') && !name.endsWith('.xlsx') && !name.endsWith('.xls')) {
      if (context.mounted) showAppToast(context, 'Please select a CSV or Excel file.');
      return;
    }
    if (file.bytes == null) {
      if (context.mounted) showAppToast(context, 'Could not read file. Try again.');
      return;
    }
    try {
      final res = await ApiService.importContacts(file.bytes!, file.name);
      onContactAdded();
      if (context.mounted) {
        showAppToast(context, 'Import complete: ${res['imported']} added, ${res['skipped']} skipped.');
      }
    } catch (_) {
      if (context.mounted) showAppToast(context, 'Upload failed. Check the file and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add New Contact',
              style: theme.typography.lg.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colors.foreground,
              ),
            ),
            const SizedBox(height: 20),
            AppButton(
              prefixIcon: Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppTheme.colorsOf(context).accent),
              label: 'Scan Card',
              variant: ButtonVariant.outline,
              fullWidth: true,
              onPressed: () async {
                context.pop();
                final result = await context.push('/capture');
                if (result == true) { onContactAdded(); }
              },
            ),
            const SizedBox(height: 12),
            AppButton(
              prefixIcon: Icon(Icons.mic_rounded, size: 18, color: AppTheme.colorsOf(context).accent),
              label: 'Voice Entry',
              variant: ButtonVariant.outline,
              fullWidth: true,
              onPressed: () async {
                context.pop();
                final result = await context.push('/voice-capture');
                if (result != null) { onContactAdded(); }
              },
            ),
            const SizedBox(height: 12),
            AppButton(
              prefixIcon: Icon(Icons.edit_rounded, size: 18, color: AppTheme.colorsOf(context).accent),
              label: 'Manual Entry',
              variant: ButtonVariant.outline,
              fullWidth: true,
              onPressed: () async {
                context.pop();
                navBarHide();
                final result = await Navigator.of(context).push<ManualEntryResult>(
                  MaterialPageRoute(
                    builder: (_) => const ManualEntryScreen(),
                  ),
                );
                navBarShow();
                if (result != null) { onContactAdded(); }
              },
            ),
            const SizedBox(height: 12),
            AppButton(
              prefixIcon: Icon(Icons.upload_file_outlined, size: 18, color: AppTheme.colorsOf(context).accent),
              label: 'Bulk Import',
              variant: ButtonVariant.outline,
              fullWidth: true,
              onPressed: () async {
                navBarHide();
                context.pop();
                await _showBulkImportSheet(context);
                navBarShow();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter Sheet ─────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final String? initialCompany;
  final String? initialLocation;
  final String? initialStatus;
  final String? initialEventId;
  final List<String> allCompanies;
  final List<String> allLocations;
  final List<Event> allEvents;
  final List<(String, String)> statuses;
  final void Function(String? company, String? location, String? status, String? eventId) onApply;

  const _FilterSheet({
    required this.initialCompany,
    required this.initialLocation,
    required this.initialStatus,
    this.initialEventId,
    required this.allCompanies,
    required this.allLocations,
    required this.allEvents,
    required this.statuses,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TextEditingController _companyCtrl = TextEditingController(text: widget.initialCompany ?? '');
  late final TextEditingController _locationCtrl = TextEditingController(text: widget.initialLocation ?? '');
  late final TextEditingController _eventCtrl = TextEditingController();
  String? _tempStatus;
  String? _tempEventId;
  List<String> _companySuggestions = [];
  List<String> _locationSuggestions = [];
  List<Event> _eventSuggestions = [];

  @override
  void initState() {
    super.initState();
    _tempStatus = widget.initialStatus;
    _tempEventId = widget.initialEventId;
    _companyCtrl.addListener(_updateCompanySuggestions);
    _locationCtrl.addListener(_updateLocationSuggestions);
    _eventCtrl.addListener(_updateEventSuggestions);
  }

  void _updateCompanySuggestions() {
    final q = _companyCtrl.text.trim().toLowerCase();
    setState(() {
      _companySuggestions = q.isEmpty
          ? widget.allCompanies
          : widget.allCompanies.where((c) => c.toLowerCase().contains(q)).toList();
    });
  }

  void _updateLocationSuggestions() {
    final q = _locationCtrl.text.trim().toLowerCase();
    setState(() {
      _locationSuggestions = q.isEmpty
          ? widget.allLocations
          : widget.allLocations.where((l) => l.toLowerCase().contains(q)).toList();
    });
  }

  void _updateEventSuggestions() {
    final q = _eventCtrl.text.trim().toLowerCase();
    if (q.isEmpty && _tempEventId != null) return;
    setState(() {
      _eventSuggestions = q.isEmpty
          ? widget.allEvents
          : widget.allEvents.where((e) => e.name.toLowerCase().contains(q)).toList();
    });
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _locationCtrl.dispose();
    _eventCtrl.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    _companyCtrl.clear();
    _locationCtrl.clear();
    _eventCtrl.clear();
    _tempStatus = null;
    _tempEventId = null;
    _companySuggestions = [];
    _locationSuggestions = [];
    _eventSuggestions = [];
  });

  void _apply() {
    final company = _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim();
    final location = _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim();
    widget.onApply(company, location, _tempStatus, _tempEventId);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SafeArea(
      top: false,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: theme.colors.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text('Filter Contacts',
                      style: theme.typography.lg.copyWith(fontWeight: FontWeight.w700, color: theme.colors.foreground)),
                  const Spacer(),
                  AppButton(
                    label: 'Reset',
                    variant: ButtonVariant.ghost,
                    onPressed: _reset,
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20, right: 20, top: 12,
                  bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Company'),
                    _searchField(_companyCtrl, 'Search company...'),
                    if (_companySuggestions.isNotEmpty)
                      _suggestionList(_companySuggestions, (v) {
                        _companyCtrl.text = v;
                        setState(() => _companySuggestions = []);
                      }),
                    const SizedBox(height: 20),
                    _sectionLabel('Location / Country'),
                    _searchField(_locationCtrl, 'Search location...'),
                    if (_locationSuggestions.isNotEmpty)
                      _suggestionList(_locationSuggestions, (v) {
                        _locationCtrl.text = v;
                        setState(() => _locationSuggestions = []);
                      }),
                    const SizedBox(height: 20),
                    _sectionLabel('Event'),
                    _searchField(_eventCtrl, 'Search event...'),
                    if (_tempEventId != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.event_available_outlined, size: 14, color: AppTheme.colorsOf(context).accent),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_eventCtrl.text, style: theme.typography.sm.copyWith(color: theme.colors.primary, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const Spacer(),
                          AppButton(
                            variant: ButtonVariant.ghost,
                            onPressed: () => setState(() { _tempEventId = null; _eventCtrl.clear(); }),
                            child: Icon(Icons.close_rounded, size: 14, color: AppTheme.colorsOf(context).accent),
                          ),
                        ],
                      ),
                    ],
                    if (_eventSuggestions.isNotEmpty && _tempEventId == null)
                      _eventSuggestionList(_eventSuggestions, (event) {
                        setState(() {
                          _tempEventId = event.id;
                          _eventCtrl.text = event.name;
                          _eventSuggestions = [];
                        });
                      }),
                    const SizedBox(height: 20),
                    _sectionLabel('Communication Status'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.statuses.map((s) {
                        final isSelected = _tempStatus == s.$1;
                        return AppButton(
                          label: s.$2,
                          variant: isSelected ? ButtonVariant.primary : ButtonVariant.outline,
                          onPressed: () => setState(() => _tempStatus = isSelected ? null : s.$1),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                    AppButton(
                      label: 'APPLY FILTERS',
                      variant: ButtonVariant.primary,
                      fullWidth: true,
                      onPressed: _apply,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
    );
  }

  Widget _sectionLabel(String label) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: theme.typography.xs.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.4, color: theme.colors.mutedForeground),
      ),
    );
  }

  Widget _searchField(TextEditingController ctrl, String hint) => AppInput(
    controller: ctrl,
    hint: hint,
    prefixIcon: Icon(Icons.search_rounded, color: AppTheme.colorsOf(context).accent, size: 18),
    suffixIcon: ctrl.text.isNotEmpty
        ? Icon(Icons.clear_rounded, size: 16, color: AppTheme.colorsOf(context).accent)
        : null,
  );

  Widget _suggestionList(List<String> items, ValueChanged<String> onTap) {
    final theme = context.theme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items.take(5).map((item) => FTappable(
          onPress: () => onTap(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(Icons.business_outlined, size: 14, color: AppTheme.colorsOf(context).accent),
                const SizedBox(width: 8),
                Expanded(child: Text(item, style: theme.typography.sm.copyWith(color: theme.colors.foreground), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _eventSuggestionList(List<Event> events, ValueChanged<Event> onTap) {
    final theme = context.theme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: events.take(6).map((event) => FTappable(
          onPress: () => onTap(event),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(Icons.event_outlined, size: 14, color: AppTheme.colorsOf(context).accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.name, style: theme.typography.sm.copyWith(color: theme.colors.foreground), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (event.location != null && event.location!.isNotEmpty)
                        Text(event.location!, style: theme.typography.xs.copyWith(color: theme.colors.mutedForeground), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }
}
