import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../models/contact_profile_data.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_header.dart';
import '../widgets/app_input.dart';
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

  static const int _pageSize = 20;
  int _displayedCount = _pageSize * 2;
  bool _isLoadingMore = false;

  String? _filterCompany;
  String? _filterLocation;
  String? _filterStatus;
  String? _filterEventId;
  String? _filterEventName;

  List<ContactProfileData> _allContacts = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_isLoadingMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent * 0.75) {
      _loadMoreVisible();
    }
  }

  void _loadMoreVisible() {
    final totalFiltered = _filteredContacts.length;
    if (_displayedCount >= totalFiltered) return;
    setState(() {
      _isLoadingMore = true;
      _displayedCount = (_displayedCount + _pageSize).clamp(0, totalFiltered);
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _isLoadingMore = false);
    });
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
          _displayedCount = _pageSize * 2;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  bool get _hasActiveFilters =>
      _filterCompany != null || _filterLocation != null ||
      _filterStatus != null || _filterEventId != null;

  List<ContactProfileData> get _filteredContacts {
    final query = _searchQuery.trim().toLowerCase();
    return _allContacts.where((c) {
      if (query.isNotEmpty &&
          !c.listName.toLowerCase().contains(query) &&
          !c.listSubtitle.toLowerCase().contains(query) &&
          !c.location.toLowerCase().contains(query)) return false;
      if (_filterCompany != null && c.company != _filterCompany) return false;
      if (_filterLocation != null && c.location != _filterLocation) return false;
      if (_filterStatus != null && c.followUpStatus != _filterStatus) return false;
      if (_filterEventId != null && !c.linkedEvents.any((e) => e.id == _filterEventId)) return false;
      return true;
    }).toList();
  }

  List<ContactProfileData> get _pagedContacts {
    final filtered = _filteredContacts;
    return filtered.take(_displayedCount).toList();
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
        onNotificationPressed: () => showFToast(context: context, title: const Text('Notifications is UI-only for now.')),
        actionIcon: Icons.add_rounded,
        actionTooltip: 'Add Contact',
        onActionPressed: _showAddContactSheet,
      ),
      childPad: false,
      child: _buildListBody(),
    );
  }

  Widget _buildListBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        itemCount: 6,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: 16),
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
            FButton(
              variant: FButtonVariant.primary,
              onPress: _loadContacts,
              child: const Text('RETRY'),
            ),
          ],
        ),
      );
    }

    final filtered = _filteredContacts;
    final paged = _pagedContacts;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildListHeader(filtered.length),
          const SizedBox(height: 28),
          _buildSearchField(),
          const SizedBox(height: 16),
          _buildFilterButton(),
          const SizedBox(height: 26),
          FDivider(),
          if (paged.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No contacts found.',
                  style: context.theme.typography.sm.copyWith(color: context.theme.colors.mutedForeground),
                ),
              ),
            )
          else
            ...paged.map(_buildContactRow),
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: FCircularProgress()),
            ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildListHeader(int count) {
    final theme = context.theme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            'Contacts',
            style: theme.typography.xl2.copyWith(
              fontWeight: FontWeight.w600,
              height: 1,
              letterSpacing: -0.48,
              color: theme.colors.foreground,
            ),
          ),
        ),
        Text(
          'Total $count',
          style: theme.typography.xs.copyWith(
            fontWeight: FontWeight.w600,
            height: 1,
            letterSpacing: 1.7,
            color: theme.colors.mutedForeground,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return AppInput(
      controller: _searchController,
      hint: 'Search across network...',
      onChanged: (value) => setState(() => _searchQuery = value),
      prefixIcon: Icon(Icons.search, color: context.theme.colors.primary, size: 22),
    );
  }

  Widget _buildFilterButton() {
    final activeCount = [_filterCompany, _filterLocation, _filterStatus, _filterEventId]
        .where((f) => f != null)
        .length;
    return Row(
      children: [
        FButton(
          variant: _hasActiveFilters ? FButtonVariant.primary : FButtonVariant.outline,
          onPress: _showFilterSheet,
          prefix: const Icon(Icons.tune_rounded, size: 16),
          child: Text(activeCount > 0 ? 'Filters ($activeCount)' : 'Filter'),
        ),
        if (_hasActiveFilters) ...[
          const SizedBox(width: 8),
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => setState(() {
              _filterCompany = null;
              _filterLocation = null;
              _filterStatus = null;
              _filterEventId = null;
              _filterEventName = null;
              _displayedCount = _pageSize * 2;
            }),
            child: const Text('Clear'),
          ),
        ],
      ],
    );
  }

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

    showFSheet(
      context: context,
      side: FLayout.btt,
      builder: (ctx) => _FilterSheet(
        initialCompany: _filterCompany,
        initialLocation: _filterLocation,
        initialStatus: _filterStatus,
        initialEventId: _filterEventId,
        initialEventName: _filterEventName,
        allCompanies: allCompanies,
        allLocations: allLocations,
        allEvents: allEvents,
        statuses: statuses,
        onApply: (company, location, status, eventId, eventName) {
          setState(() {
            _filterCompany = company;
            _filterLocation = location;
            _filterStatus = status;
            _filterEventId = eventId;
            _filterEventName = eventName;
            _displayedCount = _pageSize * 2;
          });
        },
      ),
    );
  }

  Future<bool> _confirmDelete(ContactProfileData contact) async {
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (ctx, style, _) => FDialog(
        title: const Text('Delete contact?'),
        body: Text(
          'This will permanently remove ${contact.listName} and cannot be undone.',
          style: ctx.theme.typography.sm.copyWith(color: ctx.theme.colors.mutedForeground, height: 1.5),
        ),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => ctx.pop(false),
            child: const Text('Cancel'),
          ),
          FButton(
            variant: FButtonVariant.destructive,
            onPress: () => ctx.pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteContact(ContactProfileData contact) async {
    try {
      await ApiService.deleteContact(contact.id);
      if (!mounted) return;
      setState(() => _allContacts.removeWhere((c) => c.id == contact.id));
    } catch (_) {
      if (!mounted) return;
      showFToast(context: context, title: const Text('Failed to delete contact'));
    }
  }

  Widget _buildContactRow(ContactProfileData contact) {
    return Dismissible(
      key: ValueKey(contact.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(contact),
      onDismissed: (_) => _deleteContact(contact),
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: context.theme.colors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FTappable(
          onPress: () => context.push('/contacts/${contact.id}'),
          child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          radius: 16,
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.theme.colors.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.theme.colors.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        contact.initials,
                        style: context.theme.typography.xs.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            contact.listName,
                            style: context.theme.typography.xl.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1,
                              color: context.theme.colors.foreground,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            contact.listSubtitle,
                            style: context.theme.typography.xs.copyWith(
                              fontWeight: FontWeight.w400,
                              height: 1.2,
                              color: context.theme.colors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: contact.followUpDue ? context.theme.colors.foreground : context.theme.colors.border,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  void _showAddContactSheet() {
    showFSheet(
      context: context,
      side: FLayout.btt,
      builder: (ctx) => _buildAddContactBottomSheet(),
    );
  }

  Widget _buildAddContactBottomSheet() {
    final theme = context.theme;
    return ColoredBox(
      color: theme.colors.background,
      child: SafeArea(
        top: false,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
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
              style: theme.typography.xl.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colors.foreground,
              ),
            ),
              const SizedBox(height: 20),
              _buildAddContactOption(
                icon: Icons.qr_code_scanner,
                label: 'Scan Card',
                onTap: () async {
                  context.pop();
                  final result = await context.push('/capture');
                  if (result == true) _loadContacts();
                },
              ),
              const SizedBox(height: 12),
              _buildAddContactOption(
                icon: Icons.mic,
                label: 'Voice Entry',
                onTap: () async {
                  context.pop();
                  final result = await context.push('/voice-capture');
                  if (result != null) _loadContacts();
                },
              ),
              const SizedBox(height: 12),
              _buildAddContactOption(
                icon: Icons.edit,
                label: 'Manual Entry',
                onTap: () async {
                  context.pop();
                  final result = await showFDialog<bool>(
                    context: context,
                    builder: (ctx, style, _) => const AddContactDialog(),
                  );
                  if (result == true) _loadContacts();
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FButton(
                  variant: FButtonVariant.outline,
                  onPress: () => context.pop(),
                  child: const Text('CANCEL'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddContactOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FButton(
        variant: FButtonVariant.outline,
        onPress: onTap,
        prefix: Icon(icon, size: 20),
        child: Text(label),
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
  final String? initialEventName;
  final List<String> allCompanies;
  final List<String> allLocations;
  final List<Event> allEvents;
  final List<(String, String)> statuses;
  final void Function(String? company, String? location, String? status, String? eventId, String? eventName) onApply;

  const _FilterSheet({
    required this.initialCompany,
    required this.initialLocation,
    required this.initialStatus,
    this.initialEventId,
    this.initialEventName,
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
  late final _companyCtrl = TextEditingController(text: widget.initialCompany ?? '');
  late final _locationCtrl = TextEditingController(text: widget.initialLocation ?? '');
  late final _eventCtrl = TextEditingController(text: widget.initialEventName ?? '');
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
    final eventName = _eventCtrl.text.trim().isEmpty ? null : _eventCtrl.text.trim();
    widget.onApply(company, location, _tempStatus, _tempEventId, eventName);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ColoredBox(
      color: theme.colors.background,
      child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48, height: 4,
            decoration: BoxDecoration(color: theme.colors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Text('Filter Contacts',
                    style: theme.typography.lg.copyWith(fontWeight: FontWeight.w700, color: theme.colors.foreground)),
                const Spacer(),
                FButton(
                  variant: FButtonVariant.ghost,
                  onPress: _reset,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          Expanded(
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
                        FButton(
                          variant: FButtonVariant.ghost,
                          onPress: () => setState(() { _tempEventId = null; _eventCtrl.clear(); }),
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
                      return FButton(
                        variant: isSelected ? FButtonVariant.primary : FButtonVariant.outline,
                        onPress: () => setState(() => _tempStatus = isSelected ? null : s.$1),
                        child: Text(s.$2),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FButton(
                      variant: FButtonVariant.primary,
                      onPress: _apply,
                      child: const Text('APPLY FILTERS'),
                    ),
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
