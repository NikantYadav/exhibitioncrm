import 'dart:async';

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
import 'voice_contact_capture_screen.dart';
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
  String? _filterCompanyId;
  String? _filterStatus;
  String? _filterEventId;
  String? _filterEventName;

  String _searchQuery = '';

  // Alphabet index
  final List<String> _alphabet = ['#', ...List.generate(26, (i) => String.fromCharCode(65 + i))];

  // contactId -> set of eventIds the contact has a follow-up for (from the
  // follow_ups table). Source of truth for the event filter.
  Map<String, Set<String>> _contactEventIds = {};

  List<ContactProfileData> _filteredContacts(List<ContactProfileData> allContacts) {
    final query = _searchQuery.trim().toLowerCase();
    return allContacts.where((c) {
      if (query.isNotEmpty &&
          !c.listName.toLowerCase().contains(query) &&
          !c.listSubtitle.toLowerCase().contains(query) &&
          !c.location.toLowerCase().contains(query)) { return false; }
      if (_filterCompany != null) {
        // Match by company id when we have one (reliable across casing/whitespace
        // drift in the denormalized company text); otherwise fall back to a
        // case-insensitive name compare.
        final byId = _filterCompanyId != null &&
            _filterCompanyId!.isNotEmpty &&
            c.companyId == _filterCompanyId;
        final byName = c.company.toLowerCase().trim() ==
            _filterCompany!.toLowerCase().trim();
        if (!byId && !byName) { return false; }
      }
      if (_filterStatus != null && c.followUpStatus != _filterStatus) { return false; }
      if (_filterEventId != null &&
          !(_contactEventIds[c.id]?.contains(_filterEventId) ?? false)) { return false; }
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

    final sync = context.read<SyncProvider>();
    final contactsRepo = sync.contacts;

    return FScaffold(
      header: AppHeader(
        actionIcon: Icons.add_rounded,
        actionTooltip: 'Add Contact',
        onActionPressed: () => _showAddContactSheet(contactsRepo),
      ),
      childPad: false,
      child: StreamBuilder<Map<String, Set<String>>>(
        stream: sync.followUps.watchContactEventIds(),
        builder: (context, followUpSnapshot) {
          _contactEventIds = followUpSnapshot.data ?? _contactEventIds;
          return StreamBuilder<List<Contact>>(
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
          );
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
      _filterCompany != null || _filterStatus != null || _filterEventId != null;

  Widget _buildSearchBar(FThemeData theme) {
    final activeCount = [_filterCompany, _filterStatus, _filterEventId]
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
            onPressed: () => _showFilterSheet(),
            prefixIcon: Icon(
              Icons.tune_rounded,
              size: 18,
              color: _hasActiveFilters
                  ? theme.colors.primaryForeground
                  : AppTheme.colorsOf(context).accent,
            ),
            label: activeCount > 0 ? 'Filters ($activeCount)' : 'Filter',
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(width: 4),
            AppButton(
              variant: ButtonVariant.ghost,
              onPressed: () => setState(() {
                _filterCompany = null;
                _filterCompanyId = null;
                _filterStatus = null;
                _filterEventId = null;
                _filterEventName = null;
              }),
              child: Icon(Icons.close_rounded, size: 18, color: AppTheme.colorsOf(context).accent),
            ),
          ],
        ],
      ),
    );
  }

  void _showFilterSheet() {
    const statuses = [
      ('not_contacted', 'Not Contacted'),
      ('contacted', 'Contacted'),
    ];

    showAppSheet(
      context: context,
      builder: (ctx) => _FilterSheet(
        initialCompany: _filterCompany,
        initialCompanyId: _filterCompanyId,
        initialStatus: _filterStatus,
        initialEventId: _filterEventId,
        initialEventName: _filterEventName,
        statuses: statuses,
        onApply: (company, companyId, status, eventId, eventName) {
          setState(() {
            _filterCompany = company;
            _filterCompanyId = companyId;
            _filterStatus = status;
            _filterEventId = eventId;
            _filterEventName = eventName;
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
        _buildSearchBar(theme),
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
                            _filterCompanyId = null;
                            _filterStatus = null;
                            _filterEventId = null;
                            _filterEventName = null;
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
    // Flatten groups into an index-addressable list of "slots" (a section
    // header or a contact row) WITHOUT building any widgets up front. The
    // ListView.builder then builds only the slots currently on screen, so a
    // list of several thousand contacts costs the same as a list of ten.
    final slots = <_ContactSlot>[];
    for (final group in groups) {
      slots.add(_ContactSlot.header(group.$1));
      for (final contact in group.$2) {
        slots.add(_ContactSlot.row(contact));
      }
    }

    final bottomInset = bottomScrollInset(context);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(right: 20),
      // +1 for the trailing safe-area spacer.
      itemCount: slots.length + 1,
      itemBuilder: (context, index) {
        if (index == slots.length) {
          return SizedBox(height: bottomInset);
        }
        final slot = slots[index];
        if (slot.contact == null) {
          return _buildSectionHeader(slot.letter!, theme);
        }
        return _buildContactRow(slot.contact!, theme);
      },
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
                    if (contact.title.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        contact.title,
                        style: theme.typography.xs.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (contact.company.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        contact.company,
                        style: theme.typography.xs.copyWith(
                          color: AppTheme.colorsOf(context).accent,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (contact.phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        contact.phone,
                        style: theme.typography.xs.copyWith(
                          color: theme.colors.mutedForeground,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

/// One row in the flattened, lazily-built contacts list: either an alphabet
/// section header (`letter` set, `contact` null) or a contact card (`contact`
/// set). Lets `ListView.builder` address items by index without materialising
/// every widget up front.
class _ContactSlot {
  const _ContactSlot.header(this.letter) : contact = null;
  const _ContactSlot.row(this.contact) : letter = null;

  final String? letter;
  final ContactProfileData? contact;
}

// ─── Add Contact Sheet ────────────────────────────────────────────────────────

class _AddContactSheet extends StatelessWidget {
  final VoidCallback onContactAdded;

  const _AddContactSheet({required this.onContactAdded});

  // Pushes the Manual Entry screen. Shared by the Manual Entry button and the
  // Voice screen's "switch to manual" handoff (which pops with goManual=true).
  // Takes a NavigatorState (captured before the add-contact sheet is dismissed)
  // so it stays valid after the sheet's own BuildContext is gone.
  Future<void> _openManualEntry(NavigatorState navigator) async {
    final navToken = Object();
    navBarHide(navToken);
    final result = await navigator.push<ManualEntryResult>(
      MaterialPageRoute(
        builder: (_) => const ManualEntryScreen(),
      ),
    );
    navBarShow(navToken);
    if (result != null) { onContactAdded(); }
  }

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
      result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'xlsx', 'xls'], withData: true);
    } catch (_) {
      if (context.mounted) showAppToast(context, 'Could not open file picker.');
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    const maxImportBytes = 10 * 1024 * 1024;
    if (file.size > maxImportBytes) {
      if (context.mounted) showAppToast(context, 'File too large (max 10 MB)');
      return;
    }
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
                final navigator = Navigator.of(context);
                context.pop();
                final result = await context.push('/voice-capture');
                if (result is VoiceContactResult && result.goManual) {
                  await _openManualEntry(navigator);
                } else if (result != null) {
                  onContactAdded();
                }
              },
            ),
            const SizedBox(height: 12),
            AppButton(
              prefixIcon: Icon(Icons.edit_rounded, size: 18, color: AppTheme.colorsOf(context).accent),
              label: 'Manual Entry',
              variant: ButtonVariant.outline,
              fullWidth: true,
              onPressed: () async {
                final navigator = Navigator.of(context);
                context.pop();
                await _openManualEntry(navigator);
              },
            ),
            const SizedBox(height: 12),
            AppButton(
              prefixIcon: Icon(Icons.upload_file_outlined, size: 18, color: AppTheme.colorsOf(context).accent),
              label: 'Bulk Import',
              variant: ButtonVariant.outline,
              fullWidth: true,
              onPressed: () async {
                final navToken = Object();
                navBarHide(navToken);
                context.pop();
                await _showBulkImportSheet(context);
                navBarShow(navToken);
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
  final String? initialCompanyId;
  final String? initialStatus;
  final String? initialEventId;
  final String? initialEventName;
  final List<(String, String)> statuses;
  final void Function(String? company, String? companyId, String? status, String? eventId, String? eventName) onApply;

  const _FilterSheet({
    required this.initialCompany,
    this.initialCompanyId,
    required this.initialStatus,
    this.initialEventId,
    this.initialEventName,
    required this.statuses,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TextEditingController _companyCtrl = TextEditingController(text: widget.initialCompany ?? '');
  late final TextEditingController _eventCtrl = TextEditingController();
  final FocusNode _companyFocus = FocusNode();
  final FocusNode _eventFocus = FocusNode();
  String? _tempStatus;
  String? _tempEventId;
  // (id, name) pairs from the companies table search.
  List<(String, String)> _companySuggestions = [];
  bool _companyLoading = false;
  Timer? _companyDebounce;
  int _companyReqId = 0;
  String _lastCompanyQuery = '';
  // The company picked from the list. When the field text equals the name, a
  // selection is active and we must NOT show the "no results" empty state.
  String? _selectedCompany;
  String? _selectedCompanyId;
  // Server-side event typeahead state (mirrors the company field).
  List<Event> _eventSuggestions = [];
  bool _eventLoading = false;
  Timer? _eventDebounce;
  int _eventReqId = 0;
  String _lastEventQuery = '';

  @override
  void initState() {
    super.initState();
    _tempStatus = widget.initialStatus;
    _tempEventId = widget.initialEventId;
    _selectedCompany = widget.initialCompany;
    _selectedCompanyId = widget.initialCompanyId;
    _lastCompanyQuery = widget.initialCompany ?? '';
    if (widget.initialEventId != null && widget.initialEventName != null) {
      _eventCtrl.text = widget.initialEventName!;
      _lastEventQuery = widget.initialEventName!;
    }
    _companyCtrl.addListener(_onCompanyChanged);
    _eventCtrl.addListener(_onEventChanged);
  }

  // Server-side company typeahead: debounce keystrokes, fetch from the companies
  // table (backend already searches by name and caps at 20). Falls back to first
  // page when the field is empty so a list shows on focus.
  void _onCompanyChanged() {
    final q = _companyCtrl.text.trim();
    if (q == _lastCompanyQuery) return;
    _lastCompanyQuery = q;
    // Typing diverged from the picked company → no longer a selection.
    if (q != _selectedCompany) { _selectedCompany = null; _selectedCompanyId = null; }
    _companyDebounce?.cancel();
    _companyDebounce = Timer(const Duration(milliseconds: 280), () => _fetchCompanies(q));
  }

  Future<void> _fetchCompanies(String query) async {
    final reqId = ++_companyReqId;
    if (mounted) { setState(() => _companyLoading = true); }
    try {
      final rows = await ApiService.getCompanies(query: query.isEmpty ? null : query);
      if (!mounted || reqId != _companyReqId) return;
      final items = <(String, String)>[
        for (final r in rows)
          if (((r['name'] as String?)?.trim() ?? '').isNotEmpty)
            ((r['id'] as String?) ?? '', (r['name'] as String?)!.trim()),
      ];
      setState(() {
        _companySuggestions = items;
        _companyLoading = false;
      });
    } catch (_) {
      if (!mounted || reqId != _companyReqId) return;
      setState(() {
        _companySuggestions = [];
        _companyLoading = false;
      });
    }
  }

  // Server-side event typeahead (mirrors the company field): debounce keystrokes
  // and fetch the user's events filtered by name on the backend.
  void _onEventChanged() {
    final q = _eventCtrl.text.trim();
    if (q == _lastEventQuery) return;
    _lastEventQuery = q;
    // Typing after a selection clears it so the list can show again.
    if (_tempEventId != null) _tempEventId = null;
    _eventDebounce?.cancel();
    _eventDebounce = Timer(const Duration(milliseconds: 280), () => _fetchEvents(q));
  }

  Future<void> _fetchEvents(String query) async {
    final reqId = ++_eventReqId;
    if (mounted) { setState(() => _eventLoading = true); }
    try {
      final events = await ApiService.getEvents(query: query.isEmpty ? null : query);
      if (!mounted || reqId != _eventReqId) return;
      setState(() {
        _eventSuggestions = events;
        _eventLoading = false;
      });
    } catch (_) {
      if (!mounted || reqId != _eventReqId) return;
      setState(() {
        _eventSuggestions = [];
        _eventLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _companyDebounce?.cancel();
    _eventDebounce?.cancel();
    _companyFocus.dispose();
    _eventFocus.dispose();
    _companyCtrl.dispose();
    _eventCtrl.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
    // Cancel pending searches and pre-sync the "last query" guards BEFORE
    // clearing the controllers, so the change listeners see no diff and don't
    // schedule a fetch that would re-open a dropdown.
    _companyDebounce?.cancel();
    _eventDebounce?.cancel();
    _lastCompanyQuery = '';
    _lastEventQuery = '';
    _companyCtrl.clear();
    _eventCtrl.clear();
    _tempStatus = null;
    _tempEventId = null;
    _companySuggestions = [];
    _companyLoading = false;
    _selectedCompany = null;
    _selectedCompanyId = null;
    _eventSuggestions = [];
    _eventLoading = false;
  });

  void _apply() {
    final company = _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim();
    // Only carry the id when it still matches the typed text (a selection).
    final companyId = (company != null && company == _selectedCompany) ? _selectedCompanyId : null;
    final eventName = _tempEventId == null ? null : _eventCtrl.text.trim();
    widget.onApply(company, companyId, _tempStatus, _tempEventId, eventName);
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
            Flexible(
              child: SingleChildScrollView(
                // Keyboard inset handled centrally by showAppSheet.
                padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Company'),
                    TapRegion(
                      groupId: 'company-field',
                      // Tap outside the field + its dropdown closes the list.
                      onTapOutside: (_) {
                        if (_companySuggestions.isNotEmpty) {
                          setState(() => _companySuggestions = []);
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _searchField(
                            _companyCtrl,
                            'Search company...',
                            focusNode: _companyFocus,
                            onTap: () {
                              // Load first page on focus if nothing has been fetched yet.
                              if (_companySuggestions.isEmpty && !_companyLoading) {
                                _fetchCompanies(_companyCtrl.text.trim());
                              }
                            },
                            onClear: () {
                              _companyDebounce?.cancel();
                              setState(() {
                                _selectedCompany = null;
                                _selectedCompanyId = null;
                                _lastCompanyQuery = '';
                                _companySuggestions = [];
                                _companyLoading = false;
                              });
                            },
                          ),
                          if (_companyLoading)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: AppCard(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const FCircularProgress(size: FCircularProgressSizeVariant.sm),
                                    const SizedBox(width: 10),
                                    Text('Searching companies',
                                        style: theme.typography.sm.copyWith(color: theme.colors.mutedForeground)),
                                  ],
                                ),
                              ),
                            )
                          else if (_companySuggestions.isNotEmpty)
                            _companySuggestionList(_companySuggestions, (id, name) {
                              // Guard the listener BEFORE mutating the controller, and
                              // cancel any in-flight debounce, so writing the selected
                              // name does not trigger another search.
                              _companyDebounce?.cancel();
                              _lastCompanyQuery = name;
                              _selectedCompany = name;
                              _selectedCompanyId = id;
                              _companyCtrl.text = name;
                              _companyFocus.unfocus();
                              setState(() => _companySuggestions = []);
                            })
                          else if (_companyCtrl.text.trim().isNotEmpty && _selectedCompany == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text('No companies found.',
                                  style: theme.typography.xs.copyWith(color: theme.colors.mutedForeground)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('Event'),
                    TapRegion(
                      groupId: 'event-field',
                      onTapOutside: (_) {
                        if (_eventSuggestions.isNotEmpty) {
                          setState(() => _eventSuggestions = []);
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _searchField(
                            _eventCtrl,
                            'Search event...',
                            focusNode: _eventFocus,
                            onTap: () {
                              if (_eventSuggestions.isEmpty && !_eventLoading && _tempEventId == null) {
                                _fetchEvents(_eventCtrl.text.trim());
                              }
                            },
                            onClear: () {
                              _eventDebounce?.cancel();
                              setState(() {
                                _tempEventId = null;
                                _lastEventQuery = '';
                                _eventSuggestions = [];
                                _eventLoading = false;
                              });
                            },
                          ),
                          if (_tempEventId != null)
                            const SizedBox.shrink()
                          else if (_eventLoading)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: AppCard(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const FCircularProgress(size: FCircularProgressSizeVariant.sm),
                                    const SizedBox(width: 10),
                                    Text('Searching events',
                                        style: theme.typography.sm.copyWith(color: theme.colors.mutedForeground)),
                                  ],
                                ),
                              ),
                            )
                          else if (_eventSuggestions.isNotEmpty)
                            _eventSuggestionList(_eventSuggestions, (event) {
                              _eventDebounce?.cancel();
                              _lastEventQuery = event.name;
                              _eventFocus.unfocus();
                              setState(() {
                                _tempEventId = event.id;
                                _eventCtrl.text = event.name;
                                _eventSuggestions = [];
                              });
                            })
                          else if (_eventCtrl.text.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text('No events found.',
                                  style: theme.typography.xs.copyWith(color: theme.colors.mutedForeground)),
                            ),
                        ],
                      ),
                    ),
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

  Widget _searchField(TextEditingController ctrl, String hint, {VoidCallback? onTap, VoidCallback? onClear, FocusNode? focusNode}) => AppInput(
    controller: ctrl,
    hint: hint,
    focusNode: focusNode,
    onTap: onTap,
    prefixIcon: Icon(Icons.search_rounded, color: AppTheme.colorsOf(context).accent, size: 18),
    suffixIcon: ctrl.text.isNotEmpty
        ? FTappable(
            onPress: () {
              ctrl.clear();
              onClear?.call();
            },
            child: Icon(Icons.clear_rounded, size: 16, color: AppTheme.colorsOf(context).accent),
          )
        : null,
  );

  Widget _companySuggestionList(List<(String, String)> items, void Function(String id, String name) onTap) {
    final theme = context.theme;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items.take(20).map((item) => FTappable(
          onPress: () => onTap(item.$1, item.$2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(Icons.business_outlined, size: 14, color: AppTheme.colorsOf(context).accent),
                const SizedBox(width: 8),
                Expanded(child: Text(item.$2, style: theme.typography.sm.copyWith(color: theme.colors.foreground), maxLines: 1, overflow: TextOverflow.ellipsis)),
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
