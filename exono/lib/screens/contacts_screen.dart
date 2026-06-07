import 'package:flutter/material.dart';

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

  _ContactProfileData _mapContactToProfileData(Contact contact) {
    final initials = contact.firstName.isNotEmpty
        ? (contact.firstName[0] + (contact.lastName?.isNotEmpty == true ? contact.lastName![0] : ''))
        : '??';
    
    return _buildGenericProfile(
      id: contact.id,
      initials: initials.toUpperCase(),
      name: contact.fullName,
      title: contact.jobTitle ?? 'Professional',
      company: contact.company?.name ?? 'Unknown Company',
      eventTag: 'Summit 2024', // Default for now
      followUpDue: contact.followUpStatus == 'urgent' || contact.followUpStatus == 'contacted',
      location: contact.company?.location ?? 'Global',
      website: contact.company?.website ?? '',
      email: contact.email ?? '',
      phone: contact.phone ?? '',
      linkedin: contact.linkedinUrl ?? '',
      sector: contact.company?.industry ?? 'Technology',
      productTag: contact.company?.productsServices ?? 'Strategic Solution',
      companyDescription: contact.company?.description,
      employeeRange: contact.company?.companySize,
    );
  }

  Future<void> _fetchContactDetails(_ContactProfileData profile) async {
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

  Future<void> _enrichContact(_ContactProfileData contact) async {
    if (_isEnriching) return;

    setState(() {
      _isEnriching = true;
    });

    try {
      await ApiService.enrichContact(contact.id);
      
      // Reload contacts to get updated data
      await _loadContacts();
      
      // Update selected contact
      if (mounted) {
        final updated = _allContacts.firstWhere((c) => c.id == contact.id);
        setState(() {
          _selectedContact = updated;
          _isEnriching = false;
        });
        _showSuccessMessage('Contact enriched with AI intelligence');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isEnriching = false;
        });
        _showErrorMessage('Enrichment failed: $e');
      }
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
  bool _showBriefing = true;

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
                actionWidget: IconButton(
                  onPressed: () => setState(() => _selectedContact = null),
                  icon: Icon(Icons.arrow_back_rounded, color: _c.textPrimary),
                  splashRadius: 20,
                ),
              ),
            Expanded(
              child: _selectedContact == null
                  ? _buildListBody()
                  : _buildDetailBody(_selectedContact!),
            ),
            if (_selectedContact != null)
              _buildDetailActionBar(_selectedContact!),
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
            _showBriefing = true;
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_showBriefing)
            SizedBox(
              width: double.infinity,
              child: _buildBriefingCard(contact),
            ),
          if (_showBriefing) const SizedBox(height: 24),
          _buildProfileHeader(contact),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: _buildCoreAttributesSection(contact),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: _buildCompanyIntelligenceSection(contact),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: _buildInsightsSection(contact),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: _buildStrategicContextSection(contact),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: _buildTimelineSection(contact),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBriefingCard(_ContactProfileData contact) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 24,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: _c.textPrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Before your meeting',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                  color: _c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...contact.briefingItems.asMap().entries.map(
            (entry) => Padding(
              padding: EdgeInsets.only(bottom: entry.key < contact.briefingItems.length - 1 ? 12 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: BoxDecoration(
                      color: _c.textPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _c.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => setState(() => _showBriefing = false),
              child: Text(
                'Dismiss',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: _c.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(_ContactProfileData contact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: _c.accentSoft,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _c.border),
                boxShadow: [
                  BoxShadow(
                    color: _c.accentGlow.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                contact.initials,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.8,
                  color: _c.textPrimary,
                ),
              ),
            ),
            Positioned(
              right: -10,
              bottom: -10,
              child: _isEnriching
                  ? Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _c.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _c.accentGlow,
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: () => _enrichContact(contact),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _c.accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _c.accentGlow,
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          contact.name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: _c.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          contact.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: _c.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          contact.company,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.2,
            color: _c.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            AppChip.status('MET', color: _c.accent),
            AppChip.status(contact.productTag, color: _c.accent),
            AppChip(contact.eventTag),
          ],
        ),
      ],
    );
  }

  Widget _buildCoreAttributesSection(_ContactProfileData contact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _c.border.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                child: Text(
                  'Core Attributes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                    color: _c.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => showLogInteractionSheet(context),
              icon: Icon(Icons.add, size: 14),
              label: Text(
                'LOG INTERACTION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _c.textPrimary,
                backgroundColor: _c.surface,
                side: BorderSide(color: _c.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...[
          _buildKeyValueRow('Buying Authority', contact.buyingAuthority),
          _buildKeyValueRow('Current Sentiment', contact.currentSentiment),
          _buildKeyValueRow('Primary Pain Point', contact.primaryPainPoint),
          _buildIconValueRow(Icons.mail_outline, contact.email),
          _buildIconValueRow(Icons.phone_outlined, contact.phone),
          _buildIconValueRow(Icons.public, contact.linkedin, underline: true),
          _buildIconValueRow(Icons.location_on_outlined, contact.location),
          _buildIconValueRow(Icons.groups_outlined, contact.employeeRange),
          _buildSectorRow(
            contact.sectors.isEmpty ? [contact.sector] : contact.sectors,
          ),
          _buildIconValueRow(Icons.language, contact.website, underline: true),
          _buildLinksRow(contact),
        ],
      ],
    );
  }

  Widget _buildCompanyIntelligenceSection(_ContactProfileData contact) {
    return _buildInfoCard(
      icon: Icons.domain_outlined,
      title: 'COMPANY INTELLIGENCE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBlock('Description', contact.companyDescription),
          const SizedBox(height: 18),
          _buildInfoBlock('Recent News', contact.recentNews),
          const SizedBox(height: 18),
          Text('Key Markets', style: _labelStyle()),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: contact.keyMarkets.map((m) => AppChip(m)).toList(),
          ),
          const SizedBox(height: 18),
          _buildInfoBlock('Decision Structure', contact.decisionStructure),
        ],
      ),
    );
  }

  Widget _buildInsightsSection(_ContactProfileData contact) {
    return _buildInfoCard(
      icon: Icons.auto_awesome_outlined,
      title: 'AI INSIGHTS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contact.aiInsights.asMap().entries.map(
          (entry) => Padding(
            padding: EdgeInsets.only(
              bottom: entry.key < contact.aiInsights.length - 1 ? 16 : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 7),
                  decoration: BoxDecoration(
                    color: _c.textPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _c.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ).toList(),
      ),
    );
  }

  Widget _buildStrategicContextSection(_ContactProfileData contact) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 24,
      borderColor: _c.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, color: _c.textPrimary, size: 14),
              const SizedBox(width: 8),
              Text(
                'Strategic Context',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: _c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            contact.strategicContext,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: _c.textSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(_ContactProfileData contact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: _c.border.withValues(alpha: 0.25)),
            ),
          ),
          child: Text(
            'Engagement Timeline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: _c.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Stack(
          children: [
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: Container(
                width: 1,
                color: Colors.white.withValues(alpha: 0.10),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 56,
              child: _isEnriching 
                ? const Center(child: CircularProgressIndicator())
                : FilledButton.icon(
                    onPressed: () => _sendPriorityBrief(contact),
                    icon: Icon(Icons.mail_outline, size: 20),
                    label: Text(
                      'SEND PRIORITY\nBRIEF',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _c.textPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
            ),
          ),
          const SizedBox(width: 10),
          ...[
            {'icon': Icons.call_outlined, 'action': () => _showUiOnlyMessage('Call ${contact.phone}')},
            {'icon': Icons.calendar_month_outlined, 'action': () => _showUiOnlyMessage('Schedule Meeting')},
            {'icon': Icons.more_horiz, 'action': () => _showUiOnlyMessage('More Actions')},
          ].map(
            (btn) => Padding(
              padding: const EdgeInsets.only(left: 0, right: 10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: OutlinedButton(
                  onPressed: btn['action'] as VoidCallback,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    backgroundColor: _c.surfaceAlt,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Icon(btn['icon'] as IconData, color: _c.textPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _c.textPrimary, size: 16),
              const SizedBox(width: 8),
              AppSectionLabel(title, letterSpacing: 1.8),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle()),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _c.textPrimary,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  TextStyle _labelStyle() {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      color: _c.textSecondary,
    );
  }


  Widget _buildKeyValueRow(String key, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _c.border.withValues(alpha: 0.25)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              key,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _c.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconValueRow(
    IconData icon,
    String value, {
    bool underline = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _c.border.withValues(alpha: 0.25)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Icon(icon, color: _c.textSecondary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _c.textPrimary,
                decoration: underline
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectorRow(List<String> sectors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _c.border.withValues(alpha: 0.25)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Icon(
              Icons.domain_outlined,
              color: _c.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sectors.map((sector) => AppChip(sector)).toList(),
            ),
          ),
          IconButton(
            onPressed: _openEditSectors,
            splashRadius: 18,
            icon: Icon(Icons.edit, color: _c.textSecondary, size: 16),
          ),
        ],
      ),
    );
  }

  Future<void> _openLinksFiles() async {
    final contact = _selectedContact;
    if (contact == null) return;

    final updatedAssets = await showContactLinksFilesSheet(
      context,
      initialAssets: contact.assets,
    );

    if (!mounted || updatedAssets == null) return;

    final updatedContact = contact.copyWith(assets: updatedAssets);
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

  Widget _buildLinksRow(_ContactProfileData contact) {
    final hasAssets = contact.assets.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _c.border.withValues(alpha: 0.25)),
        ),
      ),
      child: InkWell(
        onTap: _openLinksFiles,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Icon(
                Icons.attachment_outlined,
                color: _c.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Links & Files',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _c.textSecondary,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                hasAssets
                    ? '${contact.assets.length} item${contact.assets.length == 1 ? '' : 's'}'
                    : 'No links added',
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  fontStyle: hasAssets ? FontStyle.normal : FontStyle.italic,
                  color: _c.textSecondary,
                ),
              ),
            ),
            IconButton(
              onPressed: _openLinksFiles,
              splashRadius: 18,
              icon: Icon(
                hasAssets ? Icons.chevron_right : Icons.add,
                color: _c.textSecondary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }


  _ContactProfileData _buildGenericProfile({
    required String id,
    required String initials,
    required String name,
    required String title,
    required String company,
    required String eventTag,
    required bool followUpDue,
    required String location,
    required String website,
    required String email,
    required String phone,
    required String linkedin,
    required String sector,
    required String productTag,
    String? companyDescription,
    String? employeeRange,
  }) {
    return _ContactProfileData(
      id: id,
      initials: initials,
      name: name.toUpperCase(),
      listName: name,
      title: title,
      company: company.toUpperCase(),
      listSubtitle: '$title • $company',
      eventTag: eventTag,
      followUpDue: followUpDue,
      productTag: productTag,
      briefingItems: [
        'Evaluating ${productTag.isNotEmpty ? productTag : 'modernization'} priorities and integration timelines.',
        'Focus on implementation examples relevant to ${company.split(' ').first}.',
      ],
      buyingAuthority: 'Verified Lead',
      currentSentiment: followUpDue ? 'Warm Opportunity' : 'Evaluating',
      primaryPainPoint: 'Operational Efficiency',
      email: email,
      phone: phone,
      linkedin: linkedin,
      location: location,
      employeeRange: employeeRange ?? '1,000+ Employees',
      sector: sector,
      website: website,
      assets: const [],
      companyDescription: companyDescription ??
          '$company operates in the $sector space and is exploring efficiency programs for 2025.',
      recentNews:
          'Actively expanding digital transformation roadmap and exploring strategic partnerships.',
      keyMarkets: const ['North America', 'EMEA', 'APAC'],
      decisionStructure:
          'Stakeholder alignment required across operations and technology leadership.',
      aiInsights: [
        'Strategic interest in ${productTag.isNotEmpty ? productTag : 'solutions'} with clear ROI.',
        'Technical follow-up with concrete proof points recommended.',
        'High potential for engagement within existing networks.',
      ],
      strategicContext:
          '"Position as an operational accelerator with measurable outcomes and implementation confidence."',
      timelineItems: const [], // Will be populated by _fetchContactDetails
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
