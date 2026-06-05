import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const Color _background = Color(0xFF080808);
  static const Color _surface = Color(0xFF141313);
  static const Color _surfaceContainerLow = Color(0xFF0C0C0C);
  static const Color _surfaceContainerHigh = Color(0xFF1C1C1C);
  static const Color _outlineVariant = Color(0xFF444748);
  static const Color _primary = Color(0xFFFFFFFF);
  static const Color _onPrimary = Color(0xFF000000);
  static const Color _onSurfaceVariant = Color(0xFFA3A3A3);
  static const Color _idle = Color(0xFF262626);

  final TextEditingController _searchController = TextEditingController();
  final List<String> _filters = const [
    'All',
    'This Event',
    'By Product',
    'By Country',
    'By Company',
  ];

  late final List<_ContactProfileData> _allContacts = [
    _buildGenericProfile(
      initials: 'JD',
      name: 'Julianne De Marco',
      title: 'VP Supply Chain',
      company: 'Global Logistics Corp',
      eventTag: 'Summit 2024',
      followUpDue: true,
      location: 'Chicago, USA',
      website: 'globallogistics.example',
      email: 'j.demarco@globallogistics.example',
      phone: '+1 (555) 210-4401',
      linkedin: 'linkedin.com/in/juliannedemarco',
      sector: 'Logistics',
      productTag: 'PRODUCT: ROUTE AI',
    ),
    _buildGenericProfile(
      initials: 'AH',
      name: 'Arthur Hennessey',
      title: 'Managing Director',
      company: 'Silver Oak Capital',
      eventTag: 'FinTech Expo',
      followUpDue: false,
      location: 'New York, USA',
      website: 'silveroakcapital.example',
      email: 'arthur.h@silveroakcapital.example',
      phone: '+1 (555) 930-1124',
      linkedin: 'linkedin.com/in/arthurhennessey',
      sector: 'Finance',
      productTag: 'PRODUCT: EDGE INTEL',
    ),
    _buildGenericProfile(
      initials: 'SK',
      name: 'Satoshi Kobayashi',
      title: 'Chief Architect',
      company: 'NeoTokyo Systems',
      eventTag: 'Cloud Conf',
      followUpDue: true,
      location: 'Tokyo, Japan',
      website: 'neotokyosystems.example',
      email: 's.kobayashi@neotokyosystems.example',
      phone: '+81 03-5555-9087',
      linkedin: 'linkedin.com/in/satoshikobayashi',
      sector: 'Cloud Infrastructure',
      productTag: 'PRODUCT: Q-NET',
    ),
    _buildGenericProfile(
      initials: 'LW',
      name: 'Lena Weiss',
      title: 'Head of Growth',
      company: 'Munich Agri-Tech',
      eventTag: 'AgriWorld 24',
      followUpDue: false,
      location: 'Munich, Germany',
      website: 'munichagritech.example',
      email: 'l.weiss@munichagritech.example',
      phone: '+49 89 555 2190',
      linkedin: 'linkedin.com/in/lenaweiss',
      sector: 'Agriculture',
      productTag: 'PRODUCT: CORE PLATFORM',
    ),
    _ContactProfileData(
      initials: 'MV',
      name: 'MARCUS VANCE',
      listName: 'Marcus Thorne',
      title: 'SVP Global Infrastructure',
      company: 'NEXUS DYNAMICS',
      listSubtitle: 'Principal Partner • Blackwood Strategy',
      eventTag: 'CES 2024',
      followUpDue: true,
      productTag: 'PRODUCT: Q-NET',
      briefingItems: const [
        'Last discussed the Quantum-V shift at CES; expressed concern about legacy integration.',
        'Mentioned interest in the Q3 Beta for enterprise-grade security protocols.',
      ],
      buyingAuthority: 'Economic Buyer',
      currentSentiment: 'Strategic Advocate',
      primaryPainPoint: 'Scalability Latency',
      email: 'm.vance@nexusdynamics.com',
      phone: '+1 (555) 012-3456',
      linkedin: 'linkedin.com/in/marcusvance',
      location: 'San Francisco, USA',
      employeeRange: '10,000+ Employees',
      sector: 'Cloud Infrastructure',
      website: 'nexusdynamics.com',
      companyDescription:
          'Nexus Dynamics provides enterprise-grade cloud infrastructure and edge computing solutions.',
      recentNews:
          'Announced strategic partnership with Q-Net for Quantum-V integration.',
      keyMarkets: const ['North America', 'EMEA', 'APAC'],
      decisionStructure:
          'Decentralized with regional SVP approval required for Q1 budgets.',
      aiInsights: const [
        'Expressed urgency for Q3 beta; follow up on security protocol documentation.',
        'Consistent engagement at CES suggests high intent for enterprise integration.',
        'Budget approval cycle starting in two weeks—prime time for a technical deep dive.',
      ],
      strategicContext:
          '"Vance is navigating a complex migration phase. Focus the conversation on risk mitigation and our zero-downtime deployment record. He responds better to hard engineering data than high-level visionary pitches. Position EXONO as the stability layer for their 2025 expansion."',
      timelineItems: const [
        _TimelineItem(
          dateLabel: 'Today • 14:00',
          title: 'Planned Briefing',
          description: 'Private meeting room A4, Exhibition Hall.',
          isCurrent: true,
        ),
        _TimelineItem(
          dateLabel: 'Jan 12, 2024',
          title: 'CES Las Vegas',
          description:
              'Initial contact at Keynote Mixer. High interest in infrastructure resilience.',
        ),
        _TimelineItem(
          dateLabel: 'Dec 04, 2023',
          title: 'Inbound Query',
          description: 'Requested technical whitepaper via LinkedIn DM.',
        ),
      ],
    ),
    _buildGenericProfile(
      initials: 'EF',
      name: 'Elena Flores',
      title: 'Operations Lead',
      company: 'Aero Dynamics',
      eventTag: 'Paris Air Show',
      followUpDue: false,
      location: 'Madrid, Spain',
      website: 'aerodynamics.example',
      email: 'elena.f@aerodynamics.example',
      phone: '+34 91 555 0032',
      linkedin: 'linkedin.com/in/elenaflores',
      sector: 'Aerospace',
      productTag: 'PRODUCT: FLIGHT OPS',
    ),
  ];

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
          contact.eventTag.toLowerCase().contains(query);

      final matchesFilter = switch (_selectedFilter) {
        'All' => true,
        'This Event' => contact.eventTag == 'Summit 2024',
        'By Product' =>
          contact.productTag.contains('Q-NET') ||
              contact.productTag.contains('EDGE') ||
              contact.productTag.contains('CORE'),
        'By Country' =>
          contact.location.contains('Germany') ||
              contact.location.contains('Japan') ||
              contact.location.contains('Spain'),
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
      color: _background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _selectedContact == null
                ? _buildListTopBar()
                : _buildDetailTopBar(),
            Expanded(
              child: _selectedContact == null
                  ? _buildListBody()
                  : _buildDetailBody(_selectedContact!),
            ),
            if (_selectedContact != null)
              _buildDetailActionBar(_selectedContact!),
            _selectedContact == null
                ? _buildListBottomNav()
                : _buildDetailBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildListTopBar() {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: _background,
        border: Border(bottom: BorderSide(color: _idle, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.menu, color: _primary, size: 22),
          const SizedBox(width: 14),
          Text(
            'EXONO',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: _primary,
              height: 1,
            ),
          ),
          const Spacer(),
          const Icon(
            Icons.notifications_none_rounded,
            color: _primary,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTopBar() {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: _background,
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() => _selectedContact = null),
            splashRadius: 20,
            icon: const Icon(Icons.arrow_back, color: _primary),
          ),
          const Spacer(),
          Text(
            'EXONO',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: _primary,
              height: 1,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              IconButton(
                onPressed: () => _showUiOnlyMessage('Share contact'),
                splashRadius: 20,
                icon: const Icon(Icons.share_outlined, color: _primary),
              ),
              IconButton(
                onPressed: () => _showUiOnlyMessage('More actions'),
                splashRadius: 20,
                icon: const Icon(Icons.more_vert, color: _primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildListHeader(),
          const SizedBox(height: 28),
          _buildSearchField(),
          const SizedBox(height: 24),
          _buildFilterRow(),
          const SizedBox(height: 12),
          _buildLegend(),
          const SizedBox(height: 26),
          Container(height: 1, color: _idle),
          ..._filteredContacts.map(_buildContactRow),
          const SizedBox(height: 28),
          Center(child: _buildLoadMoreButton()),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            'Contacts',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              height: 1,
              letterSpacing: -0.48,
              color: _primary,
            ),
          ),
        ),
        Text(
          'Total 1,482',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1,
            letterSpacing: 1.7,
            color: _onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _outlineVariant),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        cursorColor: _primary,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: _primary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Search across network...',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _onSurfaceVariant,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          prefixIcon: const Icon(
            Icons.search,
            color: _onSurfaceVariant,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final label = _filters[index];
              final isActive = label == _selectedFilter;
              return InkWell(
                onTap: () => setState(() => _selectedFilter = label),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isActive ? _primary : Colors.transparent,
                    border: isActive
                        ? null
                        : Border.all(color: _outlineVariant),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    label.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: 1.2,
                      color: isActive ? _background : _onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _idle),
            color: _surface,
          ),
          padding: const EdgeInsets.all(5),
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: _idle),
            child: const Icon(Icons.list, color: _primary, size: 18),
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
            decoration: const BoxDecoration(
              color: _primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'FOLLOW-UP DUE',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 2.0,
              color: _onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(_ContactProfileData contact) {
    return InkWell(
      onTap: () => setState(() => _selectedContact = contact),
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _idle)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      shape: BoxShape.circle,
                      border: Border.all(color: _idle),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      contact.initials,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: _primary,
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
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            height: 1,
                            color: _primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          contact.listSubtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                            color: _onSurfaceVariant,
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
                color: contact.followUpDue ? _primary : _idle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return OutlinedButton(
      onPressed: () => _showUiOnlyMessage('Load more records'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 16),
        side: const BorderSide(color: _idle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      ),
      child: Text(
        'LOAD MORE\nRECORDS',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 3.0,
          color: _primary,
          height: 1.25,
        ),
      ),
    );
  }

  Widget _buildDetailBody(_ContactProfileData contact) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBriefingCard(contact),
          const SizedBox(height: 20),
          _buildProfileHeader(contact),
          const SizedBox(height: 24),
          _buildCoreAttributesSection(contact),
          const SizedBox(height: 20),
          _buildCompanyIntelligenceSection(contact),
          const SizedBox(height: 20),
          _buildInsightsSection(contact),
          const SizedBox(height: 20),
          _buildStrategicContextSection(contact),
          const SizedBox(height: 20),
          _buildTimelineSection(contact),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBriefingCard(_ContactProfileData contact) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: _primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Before your meeting',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                  color: _primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...contact.briefingItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: const BoxDecoration(
                      color: _primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Dismiss',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: _onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(_ContactProfileData contact) {
    return Column(
      children: [
        Container(
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            color: _surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          alignment: Alignment.center,
          child: Text(
            contact.initials,
            style: GoogleFonts.inter(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.8,
              color: _primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          contact.name,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: _primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          contact.title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: _onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          contact.company,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 2.2,
            color: _primary,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPill('MET', filled: true),
            _buildPill(contact.productTag, filled: true),
            _buildPill(contact.eventTag),
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
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
                ),
                child: Text(
                  'Core Attributes',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                    color: _onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => showLogInteractionSheet(context),
              icon: const Icon(Icons.add, size: 14),
              label: Text(
                'LOG INTERACTION',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 16),
          _buildInfoBlock('Recent News', contact.recentNews),
          const SizedBox(height: 16),
          Text('Key Markets', style: _labelStyle()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: contact.keyMarkets.map(_buildMarketTag).toList(),
          ),
          const SizedBox(height: 16),
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
        children: contact.aiInsights
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 7),
                      decoration: const BoxDecoration(
                        color: _primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: _primary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildStrategicContextSection(_ContactProfileData contact) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: _primary, width: 4),
          top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          right: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, color: _primary, size: 14),
              const SizedBox(width: 8),
              Text(
                'Strategic Context',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: _primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            contact.strategicContext,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: _onSurfaceVariant,
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
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
          ),
          child: Text(
            'Engagement Timeline',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: _onSurfaceVariant,
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
      padding: const EdgeInsets.only(left: 0, bottom: 26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 21,
            height: 21,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _background,
              border: Border.all(
                color: item.isCurrent
                    ? _primary
                    : Colors.white.withValues(alpha: 0.20),
                width: 2,
              ),
            ),
            child: item.isCurrent
                ? Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _primary,
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
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: _onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: _onSurfaceVariant,
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

  Widget _buildDetailActionBar(_ContactProfileData contact) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: () => _showUiOnlyMessage('Send priority brief'),
                icon: const Icon(Icons.mail_outline, size: 20),
                label: Text(
                  'SEND PRIORITY\nBRIEF',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: _onPrimary,
                    height: 1.15,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: _onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ...[
            Icons.call_outlined,
            Icons.calendar_month_outlined,
            Icons.more_horiz,
          ].map(
            (icon) => Padding(
              padding: const EdgeInsets.only(left: 0, right: 10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: OutlinedButton(
                  onPressed: () => _showUiOnlyMessage('Contact action'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    backgroundColor: _surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Icon(icon, color: _primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListBottomNav() {
    return Container(
      height: 84,
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: Color(0x1AFFFFFF), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildBottomNavIcon(
              Icons.track_changes_outlined,
              false,
              () => widget.onNavigateTab?.call(0),
            ),
          ),
          Expanded(
            child: _buildBottomNavIcon(Icons.contact_page_outlined, true, null),
          ),
          Expanded(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -18),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x80000000),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () => widget.onNavigateTab?.call(2),
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: _primary,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _buildBottomNavIcon(
              Icons.event_outlined,
              false,
              () => widget.onNavigateTab?.call(1),
            ),
          ),
          Expanded(
            child: _buildBottomNavIcon(
              Icons.person_outline_rounded,
              false,
              () => widget.onNavigateTab?.call(5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailBottomNav() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: Color(0x1AFFFFFF), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildBottomNavItem(
              Icons.track_changes_outlined,
              'TARGETS',
              false,
              () => widget.onNavigateTab?.call(0),
            ),
          ),
          Expanded(
            child: _buildBottomNavItem(Icons.group, 'CONTACTS', true, null),
          ),
          Expanded(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: IconButton(
                    onPressed: () => widget.onNavigateTab?.call(2),
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: _primary,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _buildBottomNavItem(
              Icons.event_outlined,
              'EVENTS',
              false,
              () => widget.onNavigateTab?.call(1),
            ),
          ),
          Expanded(
            child: _buildBottomNavItem(
              Icons.person_outline_rounded,
              'PROFILE',
              false,
              () => widget.onNavigateTab?.call(5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavIcon(IconData icon, bool active, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Center(
        child: Icon(
          icon,
          color: active ? _primary : _onSurfaceVariant,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(
    IconData icon,
    String label,
    bool active,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? _primary : _onSurfaceVariant, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: active ? _primary : _onSurfaceVariant,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _primary, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                  color: _primary,
                ),
              ),
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
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _primary,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  TextStyle _labelStyle() {
    return GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      color: _onSurfaceVariant,
    );
  }

  Widget _buildPill(String label, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? _primary : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: filled ? _primary : Colors.white.withValues(alpha: 0.20),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: filled ? _onPrimary : _primary,
        ),
      ),
    );
  }

  Widget _buildKeyValueRow(String key, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              key,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _primary,
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Icon(icon, color: _onSurfaceVariant, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _primary,
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Icon(
              Icons.domain_outlined,
              color: _onSurfaceVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sectors
                  .map(
                    (sector) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        sector,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: _primary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          IconButton(
            onPressed: _openEditSectors,
            splashRadius: 18,
            icon: const Icon(Icons.edit, color: _onSurfaceVariant, size: 16),
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
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
                color: _onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Links & Files',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _onSurfaceVariant,
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
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  fontStyle: hasAssets ? FontStyle.normal : FontStyle.italic,
                  color: _onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              onPressed: _openLinksFiles,
              splashRadius: 18,
              icon: Icon(
                hasAssets ? Icons.chevron_right : Icons.add,
                color: _onSurfaceVariant,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: _primary,
        ),
      ),
    );
  }

  _ContactProfileData _buildGenericProfile({
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
  }) {
    return _ContactProfileData(
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
        'Recently discussed platform modernization priorities and integration timelines.',
        'Asked for a concise follow-up that includes implementation examples relevant to ${company.split(' ').first}.',
      ],
      buyingAuthority: 'Department Lead',
      currentSentiment: followUpDue ? 'Warm Opportunity' : 'Monitoring',
      primaryPainPoint: 'Operational Complexity',
      email: email,
      phone: phone,
      linkedin: linkedin,
      location: location,
      employeeRange: '1,000+ Employees',
      sector: sector,
      website: website,
      assets: const [],
      companyDescription:
          '$company operates in the $sector space and is evaluating modernization and efficiency programs for 2025.',
      recentNews:
          'Recently expanded its digital transformation roadmap and is exploring strategic technology partnerships.',
      keyMarkets: const ['North America', 'EMEA'],
      decisionStructure:
          'Cross-functional sign-off required across operations, finance, and IT leadership.',
      aiInsights: [
        'Engagement suggests interest in pragmatic, implementation-first messaging.',
        'A short technical follow-up with proof points is likely to perform best.',
        'Good candidate for a focused follow-up within the next 72 hours.',
      ],
      strategicContext:
          '"Position EXONO as an operational accelerator rather than a disruptive replacement. Lead with implementation confidence and measurable outcomes."',
      timelineItems: const [
        _TimelineItem(
          dateLabel: 'Today • 14:00',
          title: 'Planned Briefing',
          description:
              'Focused follow-up planned after event-floor conversation.',
          isCurrent: true,
        ),
        _TimelineItem(
          dateLabel: 'Jan 12, 2024',
          title: 'Event Introduction',
          description:
              'Initial relationship-building conversation with strong product curiosity.',
        ),
        _TimelineItem(
          dateLabel: 'Dec 04, 2023',
          title: 'Inbound Research',
          description:
              'Looked at shared material and requested additional context.',
        ),
      ],
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
}

class _ContactProfileData {
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
