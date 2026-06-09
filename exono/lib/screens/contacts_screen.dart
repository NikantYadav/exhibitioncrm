import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_theme.dart';
import '../models/contact_profile_data.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../widgets/app_card.dart';
import '../widgets/app_header.dart';
import '../widgets/skeleton_loader.dart';
import 'add_contact_dialog.dart';
import 'capture_screen.dart';
import 'voice_contact_capture_screen.dart';

class ContactsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const ContactsScreen({super.key, this.onNavigateTab});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

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
    return ColoredBox(
      color: _c.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(
              onNotificationPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications is UI-only for now.'), behavior: SnackBarBehavior.floating),
              ),
              actionIcon: Icons.add_rounded,
              actionTooltip: 'Add Contact',
              onActionPressed: _showAddContactSheet,
            ),
            Expanded(child: _buildListBody()),
          ],
        ),
      ),
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
            ElevatedButton(
              onPressed: _loadContacts,
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
          Container(height: 1, color: _c.border),
          if (paged.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No contacts found.',
                  style: TextStyle(color: _c.textSecondary),
                ),
              ),
            )
          else
            ...paged.map(_buildContactRow),
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildListHeader(int count) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            'Contacts',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              height: 1,
              letterSpacing: -0.48,
              color: _c.textPrimary,
            ),
          ),
        ),
        Text(
          'Total $count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1,
            letterSpacing: 1.7,
            color: _c.textSecondary.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: _c.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _c.border),
        boxShadow: [
          BoxShadow(
            color: _c.accentGlow.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        cursorColor: _c.textPrimary,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: _c.textPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Search across network...',
          hintStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _c.textSecondary,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          prefixIcon: Icon(Icons.search, color: _c.accent, size: 22),
        ),
      ),
    );
  }

  Widget _buildFilterButton() {
    final activeCount = [_filterCompany, _filterLocation, _filterStatus, _filterEventId]
        .where((f) => f != null)
        .length;
    return Row(
      children: [
        GestureDetector(
          onTap: _showFilterSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _hasActiveFilters ? _c.accent : _c.surface,
              border: Border.all(color: _hasActiveFilters ? _c.accent : _c.border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded,
                    size: 16,
                    color: _hasActiveFilters ? _c.background : _c.textSecondary),
                const SizedBox(width: 6),
                Text(
                  activeCount > 0 ? 'Filters ($activeCount)' : 'Filter',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _hasActiveFilters ? _c.background : _c.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_hasActiveFilters) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() {
              _filterCompany = null;
              _filterLocation = null;
              _filterStatus = null;
              _filterEventId = null;
              _filterEventName = null;
              _displayedCount = _pageSize * 2;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _c.surface,
                border: Border.all(color: _c.border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Clear',
                style: TextStyle(fontSize: 13, color: _c.textSecondary),
              ),
            ),
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
      ('urgent', 'Urgent'),
      ('converted', 'Converted'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        initialCompany: _filterCompany,
        initialLocation: _filterLocation,
        initialStatus: _filterStatus,
        initialEventId: _filterEventId,
        initialEventName: _filterEventName,
        allCompanies: allCompanies,
        allLocations: allLocations,
        allEvents: allEvents,
        statuses: statuses,
        colors: _c,
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

  Widget _buildContactRow(ContactProfileData contact) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => context.push('/contacts/${contact.id}'),
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
                        color: _c.accentSoft,
                        shape: BoxShape.circle,
                        border: Border.all(color: _c.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        contact.initials,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: _c.textPrimary,
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
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1,
                              color: _c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            contact.listSubtitle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              height: 1.2,
                              color: _c.textSecondary,
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
                  color: contact.followUpDue ? _c.textPrimary : _c.border,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddContactSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildAddContactBottomSheet(),
    );
  }

  Widget _buildAddContactBottomSheet() {
    return Container(
      decoration: BoxDecoration(
        color: _c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: _c.border, width: 1)),
      ),
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
                    color: _c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add New Contact',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _c.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _buildAddContactOption(
                icon: Icons.qr_code_scanner,
                label: 'Scan Card',
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CaptureScreen()),
                  );
                  if (result == true) _loadContacts();
                },
              ),
              const SizedBox(height: 12),
              _buildAddContactOption(
                icon: Icons.mic,
                label: 'Voice Entry',
                onTap: () async {
                  Navigator.of(context).pop();
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VoiceContactCaptureScreen(),
                    ),
                  );
                  if (result != null) _loadContacts();
                },
              ),
              const SizedBox(height: 12),
              _buildAddContactOption(
                icon: Icons.edit,
                label: 'Manual Entry',
                onTap: () async {
                  Navigator.pop(context);
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => const AddContactDialog(),
                  );
                  if (result == true) _loadContacts();
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _c.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'CANCEL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2.0,
                      color: _c.textPrimary,
                    ),
                  ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _c.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _c.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: _c.accent, size: 20),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.8,
                  color: _c.textPrimary,
                ),
              ),
            ],
          ),
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
  final String? initialEventName;
  final List<String> allCompanies;
  final List<String> allLocations;
  final List<Event> allEvents;
  final List<(String, String)> statuses;
  final ExonoColors colors;
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
    required this.colors,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  ExonoColors get _c => widget.colors;

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
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: _c.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: _c.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48, height: 4,
                decoration: BoxDecoration(color: _c.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Text('Filter Contacts',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _c.textPrimary)),
                    const Spacer(),
                    TextButton(
                      onPressed: _reset,
                      child: Text('Reset', style: TextStyle(color: _c.textMuted, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                            Icon(Icons.event_available_outlined, size: 14, color: _c.accent),
                            const SizedBox(width: 6),
                            Text(_eventCtrl.text, style: TextStyle(fontSize: 13, color: _c.accent, fontWeight: FontWeight.w500)),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setState(() { _tempEventId = null; _eventCtrl.clear(); }),
                              child: Icon(Icons.close, size: 14, color: _c.accent),
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
                          return GestureDetector(
                            onTap: () => setState(() => _tempStatus = isSelected ? null : s.$1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? _c.accent : _c.surface,
                                border: Border.all(color: isSelected ? _c.accent : _c.border),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                s.$2,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: isSelected ? _c.background : _c.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _apply,
                          style: FilledButton.styleFrom(
                            backgroundColor: _c.accent,
                            foregroundColor: _c.background,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('APPLY FILTERS',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.4, color: _c.textMuted),
    ),
  );

  Widget _searchField(TextEditingController ctrl, String hint) => TextField(
    controller: ctrl,
    style: TextStyle(color: _c.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _c.textMuted, fontSize: 14),
      prefixIcon: Icon(Icons.search, color: _c.accent, size: 18),
      suffixIcon: ctrl.text.isNotEmpty
          ? IconButton(
              icon: Icon(Icons.clear, size: 16, color: _c.accent),
              onPressed: () => ctrl.clear(),
            )
          : null,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _c.accent, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );

  Widget _suggestionList(List<String> items, ValueChanged<String> onTap) => Container(
    margin: const EdgeInsets.only(top: 4),
    decoration: BoxDecoration(
      color: _c.surface,
      border: Border.all(color: _c.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: items.take(5).map((item) => InkWell(
        onTap: () => onTap(item),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(Icons.business_outlined, size: 14, color: _c.accent),
              const SizedBox(width: 8),
              Text(item, style: TextStyle(fontSize: 14, color: _c.textPrimary)),
            ],
          ),
        ),
      )).toList(),
    ),
  );

  Widget _eventSuggestionList(List<Event> events, ValueChanged<Event> onTap) => Container(
    margin: const EdgeInsets.only(top: 4),
    decoration: BoxDecoration(
      color: _c.surface,
      border: Border.all(color: _c.border),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: events.take(6).map((event) => InkWell(
        onTap: () => onTap(event),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(Icons.event_outlined, size: 14, color: _c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.name, style: TextStyle(fontSize: 13, color: _c.textPrimary)),
                    if (event.location != null && event.location!.isNotEmpty)
                      Text(event.location!, style: TextStyle(fontSize: 11, color: _c.textMuted)),
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
