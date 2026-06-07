import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_filter_row.dart';
import '../widgets/app_header.dart';
import '../widgets/app_section_label.dart';
import '../models/contact.dart';
import '../services/api_service.dart';
import 'add_contact_dialog.dart';
import 'capture_screen.dart';
import 'voice_memory_capture_screen.dart';
import 'contact_links_files_sheet.dart';
import 'edit_sectors_sheet.dart';
import 'log_interaction_screen.dart';

class ContactsScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const ContactsScreen({super.key, this.onNavigateTab});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  final TextEditingController _searchController = TextEditingController();
  final List<String> _filters = const [
    'All',
    'This Event',
    'By Product',
    'By Country',
    'By Company',
  ];

  List<_ContactProfileData> _allContacts = [];
  bool _isLoading = true;
  bool _isEnriching = false;
  bool _isLoadingInsights = false;
  bool _isUploadingAvatar = false;
  Map<String, dynamic>? _contactInsights;
  String? _error;

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
          _allContacts = contacts.map(_mapContactToProfileData).toList();
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
      initials: initials.toUpperCase(),
      name: contact.fullName,
      title: _clean(contact.jobTitle),
      company: isIndependent ? '' : companyName,
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
    _fetchInsights(profile.id);
    try {
      // Fetch timeline
      final timelineData = await ApiService.getContactTimeline(profile.id);
      
      final timelineItems = timelineData.map((item) {
        final date = DateTime.parse(item['date']);
        final type = item['type'] as String;
        String title = item['title'] ?? (type == 'note' ? 'Note Added' : 'Interaction');
        
        // Refine title based on type
        if (type == 'meeting') {
          title = 'Meeting: ${item['subject'] ?? 'Strategy Session'}';
        } else if (type == 'interaction' && item['interaction_type'] == 'capture') {
          title = 'Scanner Capture';
        }

        return _TimelineItem(
          dateLabel: '${_formatDate(date)} • ${_formatTime(date)}',
          title: title,
          description: item['summary'] ?? item['content'] ?? 'No additional details.',
          isCurrent: false,
        );
      }).toList();

      if (mounted && _selectedContact?.id == profile.id) {
        setState(() {
          _selectedContact = _selectedContact!.copyWith(
            timelineItems: timelineItems,
          );
        });
      }
    } catch (e) {
      debugPrint('Error fetching contact details: $e');
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _showErrorMessage('Could not open $url');
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
  String _selectedFilter = 'All';
  _ContactProfileData? _selectedContact;

  List<_ContactProfileData> get _filteredContacts {
    final query = _searchQuery.trim().toLowerCase();

    return _allContacts.where((contact) {
      final matchesQuery =
          query.isEmpty ||
          contact.listName.toLowerCase().contains(query) ||
          contact.listSubtitle.toLowerCase().contains(query) ||
          contact.eventTag.toLowerCase().contains(query) ||
          contact.productTag.toLowerCase().contains(query) ||
          contact.location.toLowerCase().contains(query);

      final matchesFilter = switch (_selectedFilter) {
        'All' => true,
        'This Event' => contact.eventTag == 'Summit 2024',
        'By Product' => contact.productTag != 'Strategic Solution' && contact.productTag.isNotEmpty,
        'By Country' => contact.location != 'Global' && contact.location.isNotEmpty,
        'By Company' => true,
        _ => true,
      };

      return matchesQuery && matchesFilter;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
              AppHeader(
                onNotificationPressed: () => _showUiOnlyMessage('Notifications'),
                actionWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _deleteContact(_selectedContact!),
                      icon: Icon(Icons.delete_outline_rounded, color: _c.destructive),
                      splashRadius: 20,
                      tooltip: 'Delete contact',
                    ),
                    IconButton(
                      onPressed: () => setState(() { _selectedContact = null; _contactInsights = null; }),
                      icon: Icon(Icons.arrow_back_rounded, color: _c.textPrimary),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
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

  Widget _buildListBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildListHeader(filtered.length),
          const SizedBox(height: 28),
          _buildSearchField(),
          const SizedBox(height: 24),
          _buildFilterRow(),
          const SizedBox(height: 12),
          _buildLegend(),
          const SizedBox(height: 26),
          Container(height: 1, color: _c.border),
          if (filtered.isEmpty)
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
            ...filtered.map(_buildContactRow),
          const SizedBox(height: 28),
          Center(child: _buildLoadMoreButton()),
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
          prefixIcon: Icon(Icons.search, color: _c.textSecondary, size: 22),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFilterRow(
          filters: _filters,
          selected: _selectedFilter,
          onSelect: (f) => setState(() => _selectedFilter = f),
          style: AppFilterRowStyle.filled,
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _c.border),
            color: _c.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(5),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _c.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.list, color: _c.textPrimary, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _c.textPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'FOLLOW-UP DUE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 2.0,
              color: _c.textSecondary,
            ),
          ),
        ],
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
          });
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

  Widget _buildLoadMoreButton() {
    return OutlinedButton(
      onPressed: () => _showUiOnlyMessage('Load more records'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 16),
        side: BorderSide(color: _c.border),
        backgroundColor: _c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(
        'LOAD MORE\nRECORDS',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 3.0,
          color: _c.textPrimary,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _buildDetailBody(_ContactProfileData contact) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeroCard(contact),
          const SizedBox(height: 12),
          _buildAIIntelligenceCard(contact),
          if (contact.timelineItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTimelineCard(contact),
          ],
          const SizedBox(height: 12),
          _buildLinksCard(contact),
        ],
      ),
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
                          color: _c.textMuted,
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
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _followUpChip(contact.followUpStatus),
                        if (contact.sector.isNotEmpty)
                          GestureDetector(
                            onTap: _openEditSectors,
                            child: AppChip(contact.sector),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Contact info rows
          if (contact.email.isNotEmpty || contact.phone.isNotEmpty || contact.linkedin.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: _c.border.withValues(alpha: 0.4)),
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
            Icon(icon, size: 17, color: _c.textMuted),
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
            Icon(Icons.chevron_right, size: 16, color: _c.textMuted),
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
                Icon(icon, color: enabled ? _c.textSecondary : _c.textMuted.withValues(alpha: 0.4), size: 18),
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

  bool _hasEnoughDataForAI(_ContactProfileData contact) {
    final hasCompany = contact.company.isNotEmpty;
    final hasLinkedin = contact.linkedin.isNotEmpty;
    final hasTitle = contact.title.isNotEmpty;
    final hasTimeline = contact.timelineItems.isNotEmpty;
    final hasDescription = contact.companyDescription.isNotEmpty;
    // Need at least 2 meaningful signals for useful insights
    final score = [hasCompany, hasLinkedin, hasTitle, hasTimeline, hasDescription]
        .where((v) => v)
        .length;
    return score >= 2;
  }

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
              if (!_isLoadingInsights && _contactInsights != null)
                GestureDetector(
                  onTap: () => _fetchInsights(contact.id),
                  child: Icon(Icons.refresh, size: 15, color: _c.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoadingInsights)
            _buildInsightsShimmer()
          else if (_contactInsights != null)
            _buildInsightsContent(_contactInsights!)
          else if (!_hasEnoughDataForAI(contact))
            _buildInsightsNeedMoreData(contact)
          else
            _buildInsightsReady(contact),
        ],
      ),
    );
  }

  Widget _buildInsightsShimmer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        4,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 14,
            width: i == 3 ? 120 : double.infinity,
            decoration: BoxDecoration(
              color: _c.surfaceElevated,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsNeedMoreData(_ContactProfileData contact) {
    final missing = <_MissingDetail>[];
    if (contact.title.isEmpty) missing.add(_MissingDetail(Icons.work_outline, 'Job title'));
    if (contact.company.isEmpty) missing.add(_MissingDetail(Icons.domain_outlined, 'Company'));
    if (contact.linkedin.isEmpty) missing.add(_MissingDetail(Icons.link, 'LinkedIn profile'));
    if (contact.timelineItems.isEmpty) missing.add(_MissingDetail(Icons.history, 'Log an interaction'));

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
                  Icon(m.icon, size: 14, color: _c.textMuted),
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
          onPressed: () => showLogInteractionSheet(context),
          icon: Icon(Icons.add, size: 14, color: _c.textMuted),
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

  Widget _buildInsightsReady(_ContactProfileData contact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI intelligence will be generated based on contact info and engagement history.',
          style: TextStyle(
            fontSize: 13,
            color: _c.textMuted,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _fetchInsights(contact.id),
          icon: Icon(Icons.auto_awesome_outlined, size: 14, color: _c.accent),
          label: Text(
            'GENERATE NOW',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: _c.accent,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            side: BorderSide(color: _c.accent.withValues(alpha: 0.4)),
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
              Icon(Icons.warning_amber_outlined, size: 14, color: _c.textMuted),
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
            Icon(Icons.attachment_outlined, size: 18, color: _c.textMuted),
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
              color: _c.textMuted,
            ),
          ],
        ),
      ),
    );
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

  Future<void> _sendPriorityBrief(_ContactProfileData contact) async {
    setState(() => _isEnriching = true);
    try {
      final result = await ApiService.generateEmailDraft(
        contactId: contact.id,
        emailType: 'briefing',
        customContext: 'High priority event follow-up requested by user.',
      );
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Priority Brief Drafted'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subject: ${result['data']['subject']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(result['data']['body']),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('DISMISS')),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('SEND NOW')),
            ],
          ),
        );
      }
    } catch (e) {
      _showErrorMessage('Failed to generate brief: $e');
    } finally {
      if (mounted) setState(() => _isEnriching = false);
    }
  }

  Widget _buildDetailActionBar(_ContactProfileData contact) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: _c.background,
        border: Border(top: BorderSide(color: _c.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton.icon(
          onPressed: _isEnriching ? null : () => _sendPriorityBrief(contact),
          icon: _isEnriching
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(_c.background),
                  ),
                )
              : const Icon(Icons.mail_outline, size: 18),
          label: Text(
            _isEnriching ? 'GENERATING...' : 'SEND EMAIL DRAFT',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _c.accent,
            foregroundColor: _c.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
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

  Future<void> _openEditSectors() async {
    final contact = _selectedContact;
    if (contact == null) return;

    final currentSectors = contact.sectors.isEmpty
        ? [contact.sector]
        : contact.sectors;

    final updatedSectors = await showEditSectorsSheet(
      context,
      initialSelection: currentSectors,
    );

    if (!mounted || updatedSectors == null || updatedSectors.isEmpty) return;

    final updatedContact = contact.copyWith(
      sector: updatedSectors.first,
      sectors: updatedSectors,
    );

    final index = _allContacts.indexWhere(
      (item) => item.email == contact.email && item.name == contact.name,
    );

    setState(() {
      _selectedContact = updatedContact;
      if (index != -1) {
        _allContacts[index] = updatedContact;
      }
    });
  }



  _ContactProfileData _buildGenericProfile({
    required String id,
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
    String companyDescription = '',
    String employeeRange = '',
    String avatarUrl = '',
    List<ContactAsset> assets = const [],
  }) {
    final companyDisplay = company.toUpperCase();
    return _ContactProfileData(
      id: id,
      initials: initials,
      name: name.toUpperCase(),
      listName: name,
      title: title,
      company: companyDisplay,
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
                      builder: (context) => VoiceMemoryCaptureScreen(),
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
              Icon(icon, color: _c.textPrimary, size: 20),
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
  final String initials;
  final String name;
  final String listName;
  final String title;
  final String company;
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

  const _ContactProfileData({
    required this.id,
    required this.initials,
    required this.name,
    required this.listName,
    required this.title,
    required this.company,
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
  });

  _ContactProfileData copyWith({
    String? id,
    String? initials,
    String? name,
    String? listName,
    String? title,
    String? company,
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
  }) {
    return _ContactProfileData(
      id: id ?? this.id,
      initials: initials ?? this.initials,
      name: name ?? this.name,
      listName: listName ?? this.listName,
      title: title ?? this.title,
      company: company ?? this.company,
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
