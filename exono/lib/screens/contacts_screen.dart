import 'dart:math' as Math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_header.dart';
import '../widgets/app_section_label.dart';
import '../widgets/skeleton_loader.dart';
import '../models/contact.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import 'add_contact_dialog.dart';
import 'app_shell.dart' show appNavBarHidden;
import 'capture_screen.dart';
import 'voice_contact_capture_screen.dart';
import 'contact_links_files_sheet.dart';
import 'log_interaction_screen.dart';

class ContactsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  final String? initialContactId;

  const ContactsScreen({super.key, this.onNavigateTab, this.initialContactId});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const int _pageSize = 20;
  int _displayedCount = _pageSize;
  bool _isLoadingMore = false;

  // Active filters
  String? _filterCompany;
  String? _filterLocation;
  String? _filterStatus;
  String? _filterEventId;   // event id
  String? _filterEventName; // display name

  List<_ContactProfileData> _allContacts = [];
  bool _isLoading = true;
  bool _isLoadingDetails = false;
  bool _isLoadingInsights = false;
  bool _isUploadingAvatar = false;
  Map<String, dynamic>? _contactInsights;
  String? _error;

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
    // Small delay for smooth feel, then clear loading flag
    Future.delayed(const Duration(milliseconds: 300), () {
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
          _allContacts = contacts.map(_mapContactToProfileData).toList();
          _displayedCount = _pageSize * 2; // preload 2 pages
          _isLoading = false;
        });
        // If an initial contact ID was provided, select it after contacts are loaded
        if (widget.initialContactId != null) {
          _selectContactById(widget.initialContactId!);
        }
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

  static String _clean(String? v) {
    if (v == null) return '';
    final t = v.trim();
    if (t.isEmpty || t.toLowerCase() == 'n/a' || t.toLowerCase() == 'na' || t == '-') return '';
    return t;
  }

  _ContactProfileData _mapContactToProfileData(Contact contact) {
    final initials = contact.firstName.isNotEmpty
        ? (contact.firstName[0] + (contact.lastName?.isNotEmpty == true ? contact.lastName![0] : ''))
        : '??';

    // Treat INDEPENDENT as no company
    final companyName = contact.company?.name ?? '';
    final isIndependent = companyName.toUpperCase() == 'INDEPENDENT' || companyName.isEmpty;

    final assets = contact.contactAssets
        .map((j) => ContactAsset.fromJson(j))
        .toList();

    return _buildGenericProfile(
      id: contact.id,
      userId: contact.userId,
      initials: initials.toUpperCase(),
      name: contact.fullName,
      title: _clean(contact.jobTitle),
      company: isIndependent ? '' : companyName,
      companyId: isIndependent ? '' : (contact.companyId ?? ''),
      followUpDue: contact.followUpStatus == 'urgent' || contact.followUpStatus == 'contacted',
      followUpStatus: contact.followUpStatus,
      location: isIndependent ? '' : _clean(contact.company?.location),
      website: isIndependent ? '' : _clean(contact.company?.website),
      email: _clean(contact.email),
      phone: _clean(contact.phone),
      linkedin: _clean(contact.linkedinUrl),
      sector: isIndependent ? '' : _clean(contact.company?.industry),
      productTag: isIndependent ? '' : _clean(contact.company?.productsServices),
      companyDescription: isIndependent ? '' : _clean(contact.company?.description),
      employeeRange: isIndependent ? '' : _clean(contact.company?.companySize),
      avatarUrl: contact.avatarUrl ?? '',
      assets: assets,
    );
  }

  Future<void> _fetchInsights(String contactId) async {
    if (!mounted) return;
    setState(() { _isLoadingInsights = true; _contactInsights = null; });
    try {
      final result = await ApiService.getContactInsights(contactId);
      if (mounted) {
        setState(() {
          _contactInsights = result['data'] as Map<String, dynamic>?;
          _isLoadingInsights = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingInsights = false);
    }
  }

  Future<void> _fetchContactDetails(_ContactProfileData profile) async {
    if (mounted) setState(() => _isLoadingDetails = true);
    _fetchInsights(profile.id);
    try {
      final results = await Future.wait([
        ApiService.getContactTimeline(profile.id),
        ApiService.getContactEvents(profile.id),
      ]);

      final timelineData = results[0] as List<Map<String, dynamic>>;
      final eventsData  = results[1] as List<Map<String, dynamic>>;

      final timelineItems = timelineData
          .where((item) => (item['interaction_type'] ?? '') != 'event_link' && item['date'] != null)
          .map((item) {
        final date = DateTime.tryParse(item['date'] as String) ?? DateTime.now();
        final type = item['type'] as String? ?? 'interaction';
        final details = item['details'] as Map<String, dynamic>?;
        final mode = details?['mode'] as String?;
        String title = item['title'] ?? (type == 'note' ? 'Note Added' : 'Interaction');
        if (type == 'meeting') title = 'Meeting: ${item['subject'] ?? 'Strategy Session'}';
        else if (type == 'interaction' && item['interaction_type'] == 'capture') title = 'Scanner Capture';
        else if (type == 'interaction' && mode != null && mode.isNotEmpty) title = mode;
        else if (type == 'interaction' && item['interaction_type'] == 'voice_note') title = '🎙 Voice Note';
        return _TimelineItem(
          dateLabel: '${_formatDate(date)} • ${_formatTime(date)}',
          title: title,
          description: item['summary'] ?? item['content'] ?? 'No additional details.',
          isCurrent: false,
        );
      }).toList();

      final linkedEvents = eventsData.map((e) => Event.fromJson(e)).toList();

      if (mounted && _selectedContact?.id == profile.id) {
        setState(() {
          _isLoadingDetails = false;
          _selectedContact = _selectedContact!.copyWith(
            timelineItems: timelineItems,
            linkedEvents: linkedEvents,
          );
        });
      }
    } catch (e) {
      debugPrint('Error fetching contact details: $e');
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _showErrorMessage('Could not open $url');
    }
  }

  void _navigateToCompanyDetail(_ContactProfileData contact) {
    if (contact.companyId.isNotEmpty) {
      context.push('/companies/${contact.companyId}');
    } else {
      _showUiOnlyMessage('No company linked to this contact');
    }
  }

  Future<void> _pickAndUploadAvatar(_ContactProfileData contact) async {
    if (_isUploadingAvatar) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final path = 'contacts/${contact.id}/avatar.$ext';

      final supabase = Supabase.instance.client;
      await supabase.storage.from('contact-avatars').uploadBinary(
        path, bytes, fileOptions: const FileOptions(upsert: true),
      );
      final url = supabase.storage.from('contact-avatars').getPublicUrl(path);

      await ApiService.updateContact(contact.id, {'avatar_url': url});
      await _loadContacts();
      if (mounted) {
        final updated = _allContacts.firstWhere((c) => c.id == contact.id, orElse: () => contact);
        setState(() { _selectedContact = updated; _isUploadingAvatar = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        _showErrorMessage('Failed to upload photo: $e');
      }
    }
  }

  Future<void> _showEditContactSheet(_ContactProfileData contact) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditContactSheet(contact: contact),
    );
    if (result == true && mounted) {
      await _loadContacts();
      if (mounted) {
        final updated = _allContacts.firstWhere((c) => c.id == contact.id, orElse: () => contact);
        setState(() {
          _selectedContact = updated;
          _contactInsights = null; // refresh insights since contact data changed
        });
        _fetchContactDetails(updated);
      }
    }
  }

  Future<void> _deleteContact(_ContactProfileData contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Contact',
            style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to delete ${contact.listName}? This cannot be undone.',
          style: TextStyle(color: _c.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCEL', style: TextStyle(color: _c.textMuted, fontSize: 12, letterSpacing: 1.2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('DELETE', style: TextStyle(color: _c.destructive, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.deleteContact(contact.id);
      if (mounted) {
        setState(() { _selectedContact = null; _contactInsights = null; });
        appNavBarHidden.value = false;
        await _loadContacts();
        _showSuccessMessage('${contact.listName} deleted');
      }
    } catch (e) {
      if (mounted) _showErrorMessage('Delete failed: $e');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _searchQuery = '';
  _ContactProfileData? _selectedContact;

  void _selectContactById(String contactId) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final contact = _allContacts.firstWhere(
      (c) => c.id == contactId,
      orElse: () => _allContacts.first,
    );
    
    // Validate ownership before selecting
    if (contact.id == contactId) {
      if (contact.userId != null && currentUserId != null && contact.userId != currentUserId) {
        if (mounted) _showErrorMessage("You do not have permission to view this contact.");
        return;
      }
      setState(() {
        _selectedContact = contact;
        _contactInsights = null;
        _isLoadingInsights = true;
      });
      appNavBarHidden.value = true;
      _fetchContactDetails(contact);
    } else {
      // It's possible the contact hasn't loaded yet or belongs to someone else.
      // If we attempt an API fetch directly:
      _fetchSingleContactAndSelect(contactId, currentUserId);
    }
  }

  Future<void> _fetchSingleContactAndSelect(String contactId, String? currentUserId) async {
    try {
      final res = await ApiService.getContact(contactId);
      if (res['data'] != null) {
        final c = Contact.fromJson(res['data']);
        if (c.userId != null && currentUserId != null && c.userId != currentUserId) {
          if (mounted) _showErrorMessage("You do not have permission to view this contact.");
          return;
        }
        if (mounted) {
          final profile = _mapContactToProfileData(c);
          setState(() {
            _selectedContact = profile;
            _contactInsights = null;
            _isLoadingInsights = true;
          });
          appNavBarHidden.value = true;
          _fetchContactDetails(profile);
        }
      }
    } catch (e) {
      // Likely 404 or row not found due to RLS/backend filters
      if (mounted) _showErrorMessage("Contact not found or access denied.");
    }
  }

  bool get _hasActiveFilters =>
      _filterCompany != null || _filterLocation != null ||
      _filterStatus != null || _filterEventId != null;

  List<_ContactProfileData> get _filteredContacts {
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

  List<_ContactProfileData> get _pagedContacts {
    final filtered = _filteredContacts;
    return filtered.take(_displayedCount).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    appNavBarHidden.value = false;
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
            if (_selectedContact == null)
              AppHeader(
                onNotificationPressed: () => _showUiOnlyMessage('Notifications'),
                actionIcon: Icons.add_rounded,
                actionTooltip: 'Add Contact',
                onActionPressed: _showAddContactSheet,
              )
            else
              _buildDetailHeader(_selectedContact!),
            Expanded(
              child: _selectedContact == null
                  ? _buildListBody()
                  : _buildDetailBody(_selectedContact!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailHeader(_ContactProfileData contact) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _c.background,
        border: Border(bottom: BorderSide(color: _c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() { _selectedContact = null; _contactInsights = null; });
              appNavBarHidden.value = false;
            },
            icon: Icon(Icons.arrow_back_rounded, color: _c.accent, size: 22),
            splashRadius: 20,
            tooltip: 'Back',
          ),
          Expanded(
            child: Text(
              contact.listName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _c.textPrimary,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => _showEditContactSheet(contact),
            icon: Icon(Icons.edit_outlined, color: _c.accent, size: 20),
            splashRadius: 20,
            tooltip: 'Edit contact',
          ),
          IconButton(
            onPressed: () => _deleteContact(contact),
            icon: Icon(Icons.delete_outline_rounded, color: _c.destructive, size: 20),
            splashRadius: 20,
            tooltip: 'Delete contact',
          ),
        ],
      ),
    );
  }

  Widget _buildListBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        itemCount: 6,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: const SkeletonCard(),
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
    // Collect all linked events across all loaded contacts for suggestions
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

  Widget _buildContactRow(_ContactProfileData contact) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedContact = contact;
            _contactInsights = null;
            _isLoadingInsights = true;
          });
          appNavBarHidden.value = true;
          _fetchContactDetails(contact);
        },
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

  Widget _buildDetailBody(_ContactProfileData contact) {
    if (_isLoadingDetails) return _buildDetailSkeleton();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeroCard(contact),
          const SizedBox(height: 12),
          _buildAIIntelligenceCard(contact),
          const SizedBox(height: 12),
          _buildTimelineCard(contact),
          const SizedBox(height: 12),
          _buildLinksCard(contact),
          const SizedBox(height: 12),
          _buildEventsCard(contact),
        ],
      ),
    );
  }

  Widget _buildDetailSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile hero card skeleton
          _skeletonCard(
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(width: 72, height: 72, borderRadius: BorderRadius.circular(20)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLoader(width: double.infinity, height: 18, borderRadius: BorderRadius.circular(5)),
                          const SizedBox(height: 8),
                          SkeletonLoader(width: 160, height: 13, borderRadius: BorderRadius.circular(4)),
                          const SizedBox(height: 6),
                          SkeletonLoader(width: 120, height: 13, borderRadius: BorderRadius.circular(4)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Contact chip row
                Row(
                  children: [
                    SkeletonLoader(width: 90, height: 32, borderRadius: BorderRadius.circular(10)),
                    const SizedBox(width: 8),
                    SkeletonLoader(width: 110, height: 32, borderRadius: BorderRadius.circular(10)),
                    const SizedBox(width: 8),
                    SkeletonLoader(width: 80, height: 32, borderRadius: BorderRadius.circular(10)),
                  ],
                ),
                const SizedBox(height: 14),
                // Company description block
                SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 6),
                SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 6),
                SkeletonLoader(width: 200, height: 13, borderRadius: BorderRadius.circular(4)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // AI intelligence card skeleton
          _skeletonCard(
            accent: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonLoader(width: 15, height: 15, borderRadius: BorderRadius.circular(4)),
                    const SizedBox(width: 8),
                    SkeletonLoader(width: 110, height: 13, borderRadius: BorderRadius.circular(4)),
                  ],
                ),
                const SizedBox(height: 14),
                SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 6),
                SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 6),
                SkeletonLoader(width: 220, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 12),
                SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 6),
                SkeletonLoader(width: 180, height: 13, borderRadius: BorderRadius.circular(4)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Timeline card skeleton
          _skeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 140, height: 13, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 16),
                ...List.generate(3, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(width: 10, height: 10, borderRadius: BorderRadius.circular(5)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLoader(width: 100, height: 11, borderRadius: BorderRadius.circular(3)),
                            const SizedBox(height: 5),
                            SkeletonLoader(width: double.infinity, height: 13, borderRadius: BorderRadius.circular(4)),
                            const SizedBox(height: 4),
                            SkeletonLoader(width: 200, height: 13, borderRadius: BorderRadius.circular(4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonCard({required Widget child, double radius = 16, bool accent = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: accent ? _c.accent.withValues(alpha: 0.3) : _c.border,
        ),
      ),
      child: child,
    );
  }

  // ─── Profile Hero Card ────────────────────────────────────────────────────

  Widget _buildProfileHeroCard(_ContactProfileData contact) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name/title/company
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _pickAndUploadAvatar(contact),
                child: Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _c.accentSoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _c.border),
                        image: contact.avatarUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(contact.avatarUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: _isUploadingAvatar
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(_c.textPrimary),
                              ),
                            )
                          : contact.avatarUrl.isEmpty
                              ? Text(
                                  contact.initials,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: _c.textPrimary,
                                  ),
                                )
                              : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _c.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _c.border),
                        ),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          size: 12,
                          color: _c.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.listName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _c.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (contact.title.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        contact.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: _c.textSecondary,
                        ),
                      ),
                    ],
                    if (contact.company.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        contact.company,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: _c.accent,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _followUpChip(contact.followUpStatus),
                  ],
                ),
              ),
            ],
          ),

          // Contact info rows
          if (contact.email.isNotEmpty || contact.phone.isNotEmpty || contact.linkedin.isNotEmpty || contact.company.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: _c.border.withValues(alpha: 0.4)),
            if (contact.company.isNotEmpty)
              _heroInfoRow(Icons.business_outlined, contact.company,
                  () => _navigateToCompanyDetail(contact)),
            if (contact.email.isNotEmpty)
              _heroInfoRow(Icons.mail_outline, contact.email,
                  () => _launchUrl('mailto:${contact.email}')),
            if (contact.phone.isNotEmpty)
              _heroInfoRow(Icons.call_outlined, contact.phone,
                  () => _launchUrl('tel:${contact.phone}')),
            if (contact.linkedin.isNotEmpty)
              _heroInfoRow(Icons.link, 'LinkedIn Profile',
                  () => _launchUrl(contact.linkedin.startsWith('http')
                      ? contact.linkedin
                      : 'https://${contact.linkedin}')),
          ],

          // Quick action buttons
          const SizedBox(height: 14),
          Row(
            children: [
              _quickActionBtn(Icons.call_outlined, 'Call',
                  contact.phone.isNotEmpty ? () => _launchUrl('tel:${contact.phone}') : null),
              _quickActionBtn(Icons.mail_outline, 'Email',
                  contact.email.isNotEmpty ? () => _generateEmailDraft(contact) : null),
              _quickActionBtn(Icons.calendar_month_outlined, 'Schedule',
                  () => _showUiOnlyMessage('Schedule Meeting')),
            ],
          ),

          // Log Interaction button
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showLogInteractionSheet(
                context,
                contactId: contact.id,
                onSaved: () => _fetchContactDetails(contact),
              ),
              icon: Icon(Icons.chat_bubble_outline_rounded, size: 16, color: _c.accent),
              label: Text(
                'LOG INTERACTION',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _c.accent,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _c.accent,
                side: BorderSide(color: _c.accent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroInfoRow(IconData icon, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 17, color: _c.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _c.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: _c.accent),
          ],
        ),
      ),
    );
  }

  Widget _followUpChip(String status) {
    switch (status) {
      case 'urgent':
        return AppChip.status('URGENT', color: _c.destructive);
      case 'contacted':
        return AppChip.status('CONTACTED', color: _c.success);
      case 'needs_followup':
        return AppChip.status('FOLLOW UP', color: _c.accent);
      default:
        return AppChip.status('NOT CONTACTED', color: _c.textMuted);
    }
  }

  Widget _quickActionBtn(IconData icon, String label, VoidCallback? onTap) {
    final enabled = onTap != null;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _c.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _c.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: enabled ? _c.accent : _c.textMuted.withValues(alpha: 0.4), size: 18),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: enabled ? _c.textMuted : _c.textMuted.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // ─── AI Intelligence Card ─────────────────────────────────────────────────

  Widget _buildAIIntelligenceCard(_ContactProfileData contact) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 16,
      borderColor: _c.accent.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 15, color: _c.accent),
              const SizedBox(width: 8),
              AppSectionLabel('AI Intelligence', letterSpacing: 1.4, color: _c.accent),
              const Spacer(),
              if (_contactInsights != null)
                GestureDetector(
                  onTap: () => _fetchInsights(contact.id),
                  child: Icon(Icons.refresh, size: 15, color: _c.accent),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_contactInsights != null)
            _buildInsightsContent(_contactInsights!)
          else
            _buildInsightsNeedMoreData(contact),
        ],
      ),
    );
  }

  Widget _buildInsightsNeedMoreData(_ContactProfileData contact) {
    final hasTitle = contact.title.isNotEmpty;
    final hasCompany = contact.company.isNotEmpty;
    final hasLinkedin = contact.linkedin.isNotEmpty;
    final hasTimeline = contact.timelineItems.isNotEmpty;
    final signalCount = [hasTitle, hasCompany, hasLinkedin, hasTimeline].where((v) => v).length;
    final hasEnoughData = signalCount >= 2;

    if (hasEnoughData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI insights are being generated and will appear here shortly.',
            style: TextStyle(fontSize: 13, color: _c.textMuted, fontStyle: FontStyle.italic, height: 1.5),
          ),
          const SizedBox(height: 16),
          const _AiThinkingDots(),
        ],
      );
    }

    final missing = <_MissingDetail>[];
    if (!hasTitle) missing.add(_MissingDetail(Icons.work_outline, 'Job title'));
    if (!hasCompany) missing.add(_MissingDetail(Icons.domain_outlined, 'Company'));
    if (!hasLinkedin) missing.add(_MissingDetail(Icons.link, 'LinkedIn profile'));
    if (!hasTimeline) missing.add(_MissingDetail(Icons.history, 'Log an interaction'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add more details to unlock AI-generated intelligence for this contact.',
          style: TextStyle(
            fontSize: 13,
            color: _c.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ...missing.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(m.icon, size: 14, color: _c.accent),
                  const SizedBox(width: 8),
                  Text(
                    m.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: _c.textMuted,
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => showLogInteractionSheet(
            context,
            contactId: contact.id,
            onSaved: () => _fetchContactDetails(contact),
          ),
          icon: Icon(Icons.add, size: 14, color: _c.accent),
          label: Text(
            'LOG INTERACTION',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: _c.textMuted,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            side: BorderSide(color: _c.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightsContent(Map<String, dynamic> insights) {
    final strategicContext = insights['strategic_context'] as String? ?? '';
    final briefing = (insights['briefing_items'] as List?)?.cast<String>() ?? [];
    final aiInsights = (insights['ai_insights'] as List?)?.cast<String>() ?? [];
    final painPoint = insights['primary_pain_point'] as String? ?? '';
    final keyMarkets = (insights['key_markets'] as List?)?.cast<String>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Strategic context
        if (strategicContext.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _c.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              strategicContext,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
                color: _c.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Pain point
        if (painPoint.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_outlined, size: 14, color: _c.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pain point: $painPoint',
                  style: TextStyle(fontSize: 12, color: _c.textMuted, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Briefing bullets
        if (briefing.isNotEmpty) ...[
          AppSectionLabel('Before Your Meeting', letterSpacing: 1.2),
          const SizedBox(height: 8),
          ...briefing.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: _c.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 13,
                          color: _c.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
        ],

        // AI Insights
        if (aiInsights.isNotEmpty) ...[
          AppSectionLabel('Key Insights', letterSpacing: 1.2),
          const SizedBox(height: 8),
          ...aiInsights.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_right, size: 16, color: _c.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 13,
                          color: _c.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],

        // Key Markets
        if (keyMarkets.isNotEmpty) ...[
          AppSectionLabel('Key Markets', letterSpacing: 1.2),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: keyMarkets.map((m) => AppChip(m)).toList(),
          ),
        ],
      ],
    );
  }

  // ─── Timeline Card ────────────────────────────────────────────────────────

  Widget _buildTimelineCard(_ContactProfileData contact) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionLabel('Engagement Timeline', letterSpacing: 1.4),
          const SizedBox(height: 16),
          if (contact.timelineItems.isEmpty)
            Text('No interactions logged yet.', style: TextStyle(fontSize: 13, color: _c.textMuted))
          else
            Stack(
              children: [
                Positioned(
                  left: 10,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 1,
                    color: _c.border.withValues(alpha: 0.4),
                  ),
                ),
                Column(
                  children: contact.timelineItems
                      .map((item) => _buildTimelineItem(item))
                      .toList(),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ─── Links Card ───────────────────────────────────────────────────────────

  Widget _buildLinksCard(_ContactProfileData contact) {
    final hasAssets = contact.assets.isNotEmpty;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      radius: 16,
      child: InkWell(
        onTap: _openLinksFiles,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Icon(Icons.attachment_outlined, size: 18, color: _c.accent),
            const SizedBox(width: 12),
            Text(
              'Links & Files',
              style: TextStyle(fontSize: 14, color: _c.textSecondary),
            ),
            const Spacer(),
            Text(
              hasAssets ? '${contact.assets.length} items' : 'None added',
              style: TextStyle(
                fontSize: 12,
                fontStyle: hasAssets ? FontStyle.normal : FontStyle.italic,
                color: _c.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              hasAssets ? Icons.chevron_right : Icons.add,
              size: 18,
              color: _c.accent,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Events Card ─────────────────────────────────────────────────────────

  Widget _buildEventsCard(_ContactProfileData contact) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSectionLabel('Events', letterSpacing: 1.4),
              const Spacer(),
              GestureDetector(
                onTap: () => _showLinkEventSheet(contact),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _c.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: _c.accent),
                      const SizedBox(width: 4),
                      Text('Link Event',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _c.accent)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (contact.linkedEvents.isEmpty)
            Text('No events linked yet.',
                style: TextStyle(fontSize: 13, color: _c.textMuted))
          else
            ...contact.linkedEvents.map((event) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _c.accentSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.event_outlined, size: 18, color: _c.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.name,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _c.textPrimary)),
                        if (event.location != null && event.location!.isNotEmpty)
                          Text(event.location!,
                              style: TextStyle(fontSize: 11, color: _c.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.link_off_rounded, size: 16, color: _c.accent),
                    splashRadius: 18,
                    tooltip: 'Unlink',
                    onPressed: () => _unlinkEvent(contact, event),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Future<void> _showLinkEventSheet(_ContactProfileData contact) async {
    List<Event> allEvents = [];
    try {
      allEvents = await ApiService.getEvents();
    } catch (_) {}

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventPickerSheet(
        allEvents: allEvents,
        linkedEventIds: contact.linkedEvents.map((e) => e.id).toSet(),
        colors: _c,
        onLink: (event) async {
          await ApiService.linkContactToEvent(contact.id, event.id);
          if (mounted && _selectedContact?.id == contact.id) {
            final updated = contact.linkedEvents.any((e) => e.id == event.id)
                ? contact.linkedEvents
                : [...contact.linkedEvents, event];
            setState(() {
              _selectedContact = _selectedContact!.copyWith(linkedEvents: updated);
            });
            // Also update the list card
            final idx = _allContacts.indexWhere((c) => c.id == contact.id);
            if (idx != -1) _allContacts[idx] = _allContacts[idx].copyWith(linkedEvents: updated);
          }
        },
      ),
    );
  }

  Future<void> _unlinkEvent(_ContactProfileData contact, Event event) async {
    try {
      await ApiService.unlinkContactFromEvent(contact.id, event.id);
      if (mounted && _selectedContact?.id == contact.id) {
        final updated = contact.linkedEvents.where((e) => e.id != event.id).toList();
        setState(() {
          _selectedContact = _selectedContact!.copyWith(linkedEvents: updated);
        });
        final idx = _allContacts.indexWhere((c) => c.id == contact.id);
        if (idx != -1) _allContacts[idx] = _allContacts[idx].copyWith(linkedEvents: updated);
      }
    } catch (e) {
      if (mounted) _showErrorMessage('Failed to unlink event');
    }
  }

  Widget _buildTimelineItem(_TimelineItem item) {
    return Padding(
      padding: const EdgeInsets.only(left: 0, bottom: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 21,
            height: 21,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _c.background,
              border: Border.all(
                color: item.isCurrent
                    ? _c.textPrimary
                    : Colors.white.withValues(alpha: 0.20),
                width: 2,
              ),
            ),
            child: item.isCurrent
                ? Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _c.textPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.dateLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: _c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateEmailDraft(_ContactProfileData contact) async {
    try {
      final result = await ApiService.generateEmailDraft(
        contactId: contact.id,
        emailType: 'general',
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _c.surface,
            title: Text('Email Draft', style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subject: ${result['data']['subject']}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: _c.textPrimary)),
                  const SizedBox(height: 12),
                  Text(result['data']['body'], style: TextStyle(color: _c.textSecondary)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('DISMISS', style: TextStyle(color: _c.textMuted)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _showErrorMessage('Failed to generate email draft: $e');
    }
  }


  Future<void> _openLinksFiles() async {
    final contact = _selectedContact;
    if (contact == null) return;

    final updatedAssets = await showContactLinksFilesSheet(
      context,
      contactId: contact.id,
      initialAssets: contact.assets,
    );

    if (!mounted || updatedAssets == null) return;

    try {
      await ApiService.updateContact(contact.id, {
        'contact_assets': updatedAssets.map((a) => a.toJson()).toList(),
      });
    } catch (_) {}

    final updatedContact = contact.copyWith(assets: updatedAssets);
    final index = _allContacts.indexWhere((item) => item.id == contact.id);

    setState(() {
      _selectedContact = updatedContact;
      if (index != -1) _allContacts[index] = updatedContact;
    });
  }




  _ContactProfileData _buildGenericProfile({
    required String id,
    String? userId,
    required String initials,
    required String name,
    required String title,
    required String company,
    required bool followUpDue,
    required String followUpStatus,
    required String location,
    required String website,
    required String email,
    required String phone,
    required String linkedin,
    required String sector,
    required String productTag,
    String companyId = '',
    String companyDescription = '',
    String employeeRange = '',
    String avatarUrl = '',
    List<ContactAsset> assets = const [],
  }) {
    final companyDisplay = company.toUpperCase();
    return _ContactProfileData(
      id: id,
      userId: userId,
      initials: initials,
      name: name.toUpperCase(),
      listName: name,
      title: title,
      company: companyDisplay,
      companyId: companyId,
      listSubtitle: title.isNotEmpty ? '$title${companyDisplay.isNotEmpty ? ' • $companyDisplay' : ''}' : companyDisplay,
      eventTag: '',
      followUpDue: followUpDue,
      followUpStatus: followUpStatus,
      productTag: productTag,
      briefingItems: const [],
      buyingAuthority: '',
      currentSentiment: '',
      primaryPainPoint: '',
      email: email,
      phone: phone,
      linkedin: linkedin,
      location: location,
      employeeRange: employeeRange,
      sector: sector,
      website: website,
      avatarUrl: avatarUrl,
      assets: assets,
      companyDescription: companyDescription,
      recentNews: '',
      keyMarkets: const [],
      decisionStructure: '',
      aiInsights: const [],
      strategicContext: '',
      timelineItems: const [],
    );
  }

  void _showUiOnlyMessage(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label is UI-only for now.'),
        behavior: SnackBarBehavior.floating,
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
                  if (result == true) {
                    _loadContacts();
                  }
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
                  if (result != null) {
                    _loadContacts();
                  }
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
                  if (result == true) {
                    _loadContacts();
                  }
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

class _ContactProfileData {
  final String id;
  final String? userId;
  final String initials;
  final String name;
  final String listName;
  final String title;
  final String company;
  final String companyId;
  final String listSubtitle;
  final String eventTag;
  final bool followUpDue;
  final String followUpStatus;
  final String productTag;
  final List<String> briefingItems;
  final String buyingAuthority;
  final String currentSentiment;
  final String primaryPainPoint;
  final String email;
  final String phone;
  final String linkedin;
  final String location;
  final String employeeRange;
  final String sector;
  final String website;
  final String avatarUrl;
  final List<String> sectors;
  final List<ContactAsset> assets;
  final String companyDescription;
  final String recentNews;
  final List<String> keyMarkets;
  final String decisionStructure;
  final List<String> aiInsights;
  final String strategicContext;
  final List<_TimelineItem> timelineItems;
  final List<Event> linkedEvents;

  const _ContactProfileData({
    required this.id,
    this.userId,
    required this.initials,
    required this.name,
    required this.listName,
    required this.title,
    required this.company,
    this.companyId = '',
    required this.listSubtitle,
    required this.eventTag,
    required this.followUpDue,
    this.followUpStatus = 'not_contacted',
    required this.productTag,
    required this.briefingItems,
    required this.buyingAuthority,
    required this.currentSentiment,
    required this.primaryPainPoint,
    required this.email,
    required this.phone,
    required this.linkedin,
    required this.location,
    required this.employeeRange,
    required this.sector,
    required this.website,
    this.avatarUrl = '',
    this.sectors = const [],
    this.assets = const [],
    required this.companyDescription,
    required this.recentNews,
    required this.keyMarkets,
    required this.decisionStructure,
    required this.aiInsights,
    required this.strategicContext,
    required this.timelineItems,
    this.linkedEvents = const [],
  });

  _ContactProfileData copyWith({
    String? id,
    String? userId,
    String? initials,
    String? name,
    String? listName,
    String? title,
    String? company,
    String? companyId,
    String? listSubtitle,
    String? eventTag,
    bool? followUpDue,
    String? followUpStatus,
    String? productTag,
    List<String>? briefingItems,
    String? buyingAuthority,
    String? currentSentiment,
    String? primaryPainPoint,
    String? email,
    String? phone,
    String? linkedin,
    String? location,
    String? employeeRange,
    String? sector,
    String? website,
    String? avatarUrl,
    List<String>? sectors,
    List<ContactAsset>? assets,
    String? companyDescription,
    String? recentNews,
    List<String>? keyMarkets,
    String? decisionStructure,
    List<String>? aiInsights,
    String? strategicContext,
    List<_TimelineItem>? timelineItems,
    List<Event>? linkedEvents,
  }) {
    return _ContactProfileData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      initials: initials ?? this.initials,
      name: name ?? this.name,
      listName: listName ?? this.listName,
      title: title ?? this.title,
      company: company ?? this.company,
      companyId: companyId ?? this.companyId,
      listSubtitle: listSubtitle ?? this.listSubtitle,
      eventTag: eventTag ?? this.eventTag,
      followUpDue: followUpDue ?? this.followUpDue,
      followUpStatus: followUpStatus ?? this.followUpStatus,
      productTag: productTag ?? this.productTag,
      briefingItems: briefingItems ?? this.briefingItems,
      buyingAuthority: buyingAuthority ?? this.buyingAuthority,
      currentSentiment: currentSentiment ?? this.currentSentiment,
      primaryPainPoint: primaryPainPoint ?? this.primaryPainPoint,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      linkedin: linkedin ?? this.linkedin,
      location: location ?? this.location,
      employeeRange: employeeRange ?? this.employeeRange,
      sector: sector ?? this.sector,
      website: website ?? this.website,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      sectors: sectors ?? this.sectors,
      assets: assets ?? this.assets,
      companyDescription: companyDescription ?? this.companyDescription,
      recentNews: recentNews ?? this.recentNews,
      keyMarkets: keyMarkets ?? this.keyMarkets,
      decisionStructure: decisionStructure ?? this.decisionStructure,
      aiInsights: aiInsights ?? this.aiInsights,
      strategicContext: strategicContext ?? this.strategicContext,
      timelineItems: timelineItems ?? this.timelineItems,
      linkedEvents: linkedEvents ?? this.linkedEvents,
    );
  }
}

// ─── Edit Contact Sheet ───────────────────────────────────────────────────────

class _EditContactSheet extends StatefulWidget {
  final _ContactProfileData contact;
  const _EditContactSheet({required this.contact});

  @override
  State<_EditContactSheet> createState() => _EditContactSheetState();
}

class _EditContactSheetState extends State<_EditContactSheet> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  late final _firstNameCtrl  = TextEditingController(text: _splitName(widget.contact.listName).first);
  late final _lastNameCtrl   = TextEditingController(text: _splitName(widget.contact.listName).last);
  late final _emailCtrl      = TextEditingController(text: widget.contact.email);
  late final _phoneCtrl      = TextEditingController(text: widget.contact.phone);
  late final _jobTitleCtrl   = TextEditingController(text: widget.contact.title);
  late final _linkedinCtrl   = TextEditingController(text: widget.contact.linkedin);
  late final _companyCtrl    = TextEditingController(text: widget.contact.company);

  bool _isSaving = false;

  List<String> _splitName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length == 1) return [parts[0], ''];
    return [parts.first, parts.sublist(1).join(' ')];
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _jobTitleCtrl.dispose();
    _linkedinCtrl.dispose();
    _companyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final firstName = _firstNameCtrl.text.trim();
    if (firstName.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        'first_name': firstName,
        'last_name': _lastNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'job_title': _jobTitleCtrl.text.trim(),
        'linkedin_url': _linkedinCtrl.text.trim(),
      };

      // Only send company_name if it actually changed — backend does find-or-create.
      final newCompany = _companyCtrl.text.trim();
      final originalCompany = widget.contact.company;
      if (newCompany.toUpperCase() != originalCompany.toUpperCase()) {
        payload['company_name'] = newCompany.isEmpty ? 'INDEPENDENT' : newCompany;
      }

      await ApiService.updateContact(widget.contact.id, payload);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), behavior: SnackBarBehavior.floating),
        );
        setState(() => _isSaving = false);
      }
    }
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
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: _c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Text(
                      'Edit Contact',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _c.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('CANCEL', style: TextStyle(color: _c.textMuted, fontSize: 12, letterSpacing: 1.2)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _field('First Name', _firstNameCtrl, required: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _field('Last Name', _lastNameCtrl)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _field('Email', _emailCtrl, keyboard: TextInputType.emailAddress),
                      const SizedBox(height: 12),
                      _field('Phone', _phoneCtrl, keyboard: TextInputType.phone),
                      const SizedBox(height: 12),
                      _field('Job Title', _jobTitleCtrl),
                      const SizedBox(height: 12),
                      _field('Company', _companyCtrl),
                      const SizedBox(height: 12),
                      _field('LinkedIn URL', _linkedinCtrl, keyboard: TextInputType.url),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _isSaving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: _c.accent,
                            foregroundColor: _c.background,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isSaving
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(_c.background),
                                  ),
                                )
                              : const Text('SAVE CHANGES',
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

  Widget _field(String label, TextEditingController ctrl, {
    bool required = false,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: TextStyle(color: _c.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _c.textMuted, fontSize: 13),
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
  }
}

class _AiThinkingDots extends StatefulWidget {
  const _AiThinkingDots();
  @override
  State<_AiThinkingDots> createState() => _AiThinkingDotsState();
}

class _AiThinkingDotsState extends State<_AiThinkingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot peaks at a different phase
            final phase = (i / 3.0);
            final t = ((_ctrl.value - phase) % 1.0);
            // Sine curve: bright in the middle of its cycle
            final brightness = (Math.sin(t * Math.pi)).clamp(0.0, 1.0);
            final size = 6.0 + brightness * 3.0;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accent.withValues(alpha: 0.3 + brightness * 0.7),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _MissingDetail {
  final IconData icon;
  final String label;
  const _MissingDetail(this.icon, this.label);
}

class _TimelineItem {
  final String dateLabel;
  final String title;
  final String description;
  final bool isCurrent;

  const _TimelineItem({
    required this.dateLabel,
    required this.title,
    required this.description,
    this.isCurrent = false,
  });
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
    if (q.isEmpty && _tempEventId != null) return; // don't open dropdown if selection already made
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

// ─── Event Picker Sheet ───────────────────────────────────────────────────────

class _EventPickerSheet extends StatefulWidget {
  final List<Event> allEvents;
  final Set<String> linkedEventIds;
  final ExonoColors colors;
  final Future<void> Function(Event event) onLink;

  const _EventPickerSheet({
    required this.allEvents,
    required this.linkedEventIds,
    required this.colors,
    required this.onLink,
  });

  @override
  State<_EventPickerSheet> createState() => _EventPickerSheetState();
}

class _EventPickerSheetState extends State<_EventPickerSheet> {
  ExonoColors get _c => widget.colors;
  final _searchCtrl = TextEditingController();
  List<Event> _filtered = [];
  bool _linking = false;

  @override
  void initState() {
    super.initState();
    _filtered = widget.allEvents;
    _searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.allEvents
          : widget.allEvents.where((e) => e.name.toLowerCase().contains(q) ||
              (e.location ?? '').toLowerCase().contains(q)).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: _c.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: _c.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 48, height: 4,
                  decoration: BoxDecoration(color: _c.border, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Text('Link to Event',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _c.textPrimary)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: _c.accent),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: TextStyle(color: _c.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search events...',
                    hintStyle: TextStyle(color: _c.textMuted, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: _c.accent, size: 18),
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
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(child: Text('No events found.', style: TextStyle(color: _c.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final event = _filtered[i];
                          final isLinked = widget.linkedEventIds.contains(event.id);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                            leading: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: _c.accentSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.event_outlined, size: 18, color: _c.accent),
                            ),
                            title: Text(event.name,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _c.textPrimary)),
                            subtitle: event.location != null && event.location!.isNotEmpty
                                ? Text(event.location!, style: TextStyle(fontSize: 11, color: _c.textMuted))
                                : null,
                            trailing: isLinked
                                ? Icon(Icons.check_circle_rounded, color: _c.accent, size: 20)
                                : (_linking
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Icon(Icons.add_circle_outline, color: _c.accent, size: 20)),
                            onTap: isLinked ? null : () async {
                              setState(() => _linking = true);
                              try {
                                await widget.onLink(event);
                              } finally {
                                if (mounted) setState(() => _linking = false);
                              }
                              if (mounted) Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
