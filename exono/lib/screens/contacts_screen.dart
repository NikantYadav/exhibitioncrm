import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../models/contact_profile_data.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_avatar.dart';
import '../widgets/app_button.dart';
import '../widgets/app_header.dart';
import '../widgets/app_input.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/skeleton_loader.dart';
import 'add_contact_dialog.dart';
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

  List<ContactProfileData> _allContacts = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  // Alphabet index
  final List<String> _alphabet = ['#', ...List.generate(26, (i) => String.fromCharCode(65 + i))];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final contacts = await ApiService.getContacts();
      if (mounted) {
        setState(() {
          _allContacts = contacts.map(mapContactToProfileData).toList();
          _isLoading = false;
        });
      }
    } on UnauthorizedException { rethrow; } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<ContactProfileData> get _filteredContacts {
    final query = _searchQuery.trim().toLowerCase();
    return _allContacts.where((c) {
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
  List<(String, List<ContactProfileData>)> get _groupedContacts {
    final filtered = _filteredContacts;
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
    return FScaffold(
      header: AppHeader(
        actionIcon: Icons.add_rounded,
        actionTooltip: 'Add Contact',
        onActionPressed: _showAddContactSheet,
      ),
      childPad: false,
      child: _buildListBody(),
    );
  }

  bool get _hasActiveFilters =>
      _filterCompany != null || _filterLocation != null ||
      _filterStatus != null || _filterEventId != null;

  Widget _buildSearchBar(FThemeData theme) {
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
              prefixIcon: Icon(Icons.search, color: theme.colors.mutedForeground, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          AppButton(
            variant: _hasActiveFilters ? ButtonVariant.primary : ButtonVariant.outline,
            onPressed: _showFilterSheet,
            prefixIcon: const Icon(Icons.tune_rounded, size: 16),
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
              child: const Icon(Icons.close, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterRow(FThemeData theme) => const SizedBox.shrink();

  void _showFilterSheet() {
    final allCompanies = _allContacts
        .map((c) => c.company).where((c) => c.isNotEmpty).toSet().toList()..sort();
    final allLocations = _allContacts
        .map((c) => c.location).where((l) => l.isNotEmpty).toSet().toList()..sort();
    final eventMap = <String, Event>{};
    for (final c in _allContacts) {
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

  Widget _buildListBody() {
    final theme = context.theme;
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: 8,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: SkeletonCard(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            AppButton(label: 'RETRY', onPressed: _loadContacts),
          ],
        ),
      );
    }

    final groups = _groupedContacts;

    return Column(
      children: [
        _buildSearchBar(theme),
        _buildFilterRow(theme),
        Expanded(
          child: groups.isEmpty
              ? Center(
                  child: Text(
                    'No contacts found.',
                    style: theme.typography.sm.copyWith(color: theme.colors.mutedForeground),
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

    items.add(const SizedBox(height: 40));

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
                    ),
                    const SizedBox(height: 3),
                    Text(
                      contact.phone.isNotEmpty ? contact.phone : contact.listSubtitle,
                      style: theme.typography.xs.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Text(
              letter,
              style: theme.typography.xs.copyWith(
                fontWeight: FontWeight.w600,
                color: active ? theme.colors.primary : theme.colors.mutedForeground.withAlpha(80),
                fontSize: 10,
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

  void _showAddContactSheet() {
    showAppSheet(
      context: context,
      builder: (ctx) => _AddContactSheet(onContactAdded: _loadContacts),
    );
  }

}

// ─── Add Contact Sheet ────────────────────────────────────────────────────────

class _AddContactSheet extends StatelessWidget {
  final VoidCallback onContactAdded;

  const _AddContactSheet({required this.onContactAdded});

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
              prefixIcon: const Icon(Icons.qr_code_scanner, size: 20),
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
              prefixIcon: const Icon(Icons.mic, size: 20),
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
              prefixIcon: const Icon(Icons.edit, size: 20),
              label: 'Manual Entry',
              variant: ButtonVariant.outline,
              fullWidth: true,
              onPressed: () async {
                context.pop();
                final result = await showManualEntrySheet(context);
                if (result == true) { onContactAdded(); }
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
                          Icon(Icons.event_available_outlined, size: 14, color: theme.colors.primary),
                          const SizedBox(width: 6),
                          Text(_eventCtrl.text, style: theme.typography.sm.copyWith(color: theme.colors.primary, fontWeight: FontWeight.w500)),
                          const Spacer(),
                          AppButton(
                            variant: ButtonVariant.ghost,
                            onPressed: () => setState(() { _tempEventId = null; _eventCtrl.clear(); }),
                            child: Icon(Icons.close, size: 14, color: theme.colors.primary),
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
    prefixIcon: Icon(Icons.search, color: context.theme.colors.primary, size: 18),
    suffixIcon: ctrl.text.isNotEmpty
        ? Icon(Icons.clear, size: 16, color: context.theme.colors.primary)
        : null,
  );

  Widget _suggestionList(List<String> items, ValueChanged<String> onTap) {
    final theme = context.theme;
    return FCard.raw(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items.take(5).map((item) => FTappable(
          onPress: () => onTap(item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(Icons.business_outlined, size: 14, color: theme.colors.primary),
                const SizedBox(width: 8),
                Text(item, style: theme.typography.sm.copyWith(color: theme.colors.foreground)),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _eventSuggestionList(List<Event> events, ValueChanged<Event> onTap) {
    final theme = context.theme;
    return FCard.raw(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: events.take(6).map((event) => FTappable(
          onPress: () => onTap(event),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(Icons.event_outlined, size: 14, color: theme.colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.name, style: theme.typography.sm.copyWith(color: theme.colors.foreground)),
                      if (event.location != null && event.location!.isNotEmpty)
                        Text(event.location!, style: theme.typography.xs.copyWith(color: theme.colors.mutedForeground)),
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
