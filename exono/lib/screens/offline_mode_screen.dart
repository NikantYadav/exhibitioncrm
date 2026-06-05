import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OfflineModeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const OfflineModeScreen({super.key, this.onNavigateTab});

  @override
  State<OfflineModeScreen> createState() => _OfflineModeScreenState();
}

class _OfflineModeScreenState extends State<OfflineModeScreen> {
  static const Color _background = Color(0xFF080808);
  static const Color _surface = Color(0xFF141313);
  static const Color _surfaceContainer = Color(0xFF201F1F);
  static const Color _surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color _surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color _surfaceContainerHighest = Color(0xFF353434);
  static const Color _outlineVariant = Color(0xFF444748);
  static const Color _outline = Color(0xFF8E9192);
  static const Color _primary = Colors.white;
  static const Color _onPrimary = Color(0xFF2F3131);
  static const Color _onSurface = Color(0xFFE5E2E1);
  static const Color _onSurfaceVariant = Color(0xFFC4C7C8);
  static const Color _pending = Color(0xFFFACC15);
  static const Color _hairline = Color(0xFF262626);

  final List<String> _filters = const ['All', 'Must Meet', 'Met', 'Remaining'];
  String _selectedFilter = 'All';

  late final List<_OfflineTarget> _targets = [
    _OfflineTarget(
      indexLabel: '01',
      company: 'Aether Systems',
      booth: 'B-04',
      tags: const ['AI & Robotics'],
      notes:
          'Review Series B funding status and core NLP architecture milestones.',
      isMet: false,
      isExpanded: true,
    ),
    _OfflineTarget(
      indexLabel: '02',
      company: 'Lumina Labs',
      booth: 'C-12',
      tags: const ['Photonics'],
      notes: 'Will sync when reconnected',
      isMet: true,
      isExpanded: false,
    ),
    _OfflineTarget(
      indexLabel: '03',
      company: 'Helix Motion',
      booth: 'D-08',
      tags: const ['Industrial AI'],
      notes: 'Confirm operating footprint across Nordic logistics hubs.',
      isMet: false,
      isExpanded: false,
    ),
  ];

  int get _pendingSyncCount => 14;

  List<_OfflineTarget> get _visibleTargets {
    return _targets.where((target) {
      return switch (_selectedFilter) {
        'All' => true,
        'Must Meet' => !target.isMet && target.indexLabel == '01',
        'Met' => target.isMet,
        'Remaining' => !target.isMet,
        _ => true,
      };
    }).toList();
  }

  void _showUiOnlyMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _toggleTarget(_OfflineTarget target) {
    setState(() => target.isExpanded = !target.isExpanded);
  }

  void _toggleMet(_OfflineTarget target) {
    setState(() {
      target.isMet = !target.isMet;
      if (target.isMet) {
        target.isExpanded = false;
      }
    });
    _showUiOnlyMessage('Offline status stored locally.');
  }

  void _navigate(int index) {
    Navigator.of(context).pop();
    widget.onNavigateTab?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildStatusBanner(),
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPreEventCacheCard(),
                        const SizedBox(height: 24),
                        _buildHeaderSection(),
                        const SizedBox(height: 14),
                        _buildFilterRow(),
                        const SizedBox(height: 16),
                        ..._buildTargetCards(),
                        const SizedBox(height: 36),
                        _buildOfflineFooterNote(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: _surfaceContainer,
        border: Border(bottom: BorderSide(color: _outlineVariant)),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: _onSurface, size: 16),
              const SizedBox(width: 8),
              Text(
                'Offline',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: _onSurface,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _pending,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_pendingSyncCount PENDING SYNC',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: _onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'SYNC: 2M AGO',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: _onSurfaceVariant.withValues(alpha: 0.40),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => _showUiOnlyMessage('Refresh attempted.'),
                borderRadius: BorderRadius.circular(999),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.refresh, color: _onSurface, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: _background,
        border: Border(bottom: BorderSide(color: _hairline)),
      ),
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
          const Icon(Icons.notifications, color: _primary, size: 22),
        ],
      ),
    );
  }

  Widget _buildPreEventCacheCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _surfaceContainer,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.cloud_download_outlined,
              color: _onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pre-Event Cache',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'CACHE ALL TARGET DATA FOR UPCOMING EVENT',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                    color: _onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => _showUiOnlyMessage('Cache download started.'),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: _onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'DOWNLOAD',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Web Summit 2026',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '14 TARGETS',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.8,
                  color: _onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () => _showUiOnlyMessage('Sort by booth'),
          style: TextButton.styleFrom(
            foregroundColor: _onSurfaceVariant,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.sort, size: 16),
          label: Text(
            'SORT BY BOOTH',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isActive = filter == _selectedFilter;
          return InkWell(
            onTap: () => setState(() => _selectedFilter = filter),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? Colors.transparent : null,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: isActive ? _primary : _hairline),
              ),
              child: Text(
                filter.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                  color: isActive ? _primary : _onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildTargetCards() {
    if (_visibleTargets.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _outlineVariant),
          ),
          child: Text(
            'No cached targets match the current filter.',
            style: GoogleFonts.inter(fontSize: 14, color: _onSurfaceVariant),
          ),
        ),
      ];
    }

    return [
      for (int i = 0; i < _visibleTargets.length; i++) ...[
        _buildTargetCard(_visibleTargets[i]),
        if (i < _visibleTargets.length - 1) const SizedBox(height: 16),
      ],
    ];
  }

  Widget _buildTargetCard(_OfflineTarget target) {
    final isMet = target.isMet;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: isMet ? 0.5 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _outlineVariant),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        target.indexLabel,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _outline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              target.company,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isMet ? _onSurfaceVariant : _onSurface,
                                decoration: isMet
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            _buildBoothChip(target.booth),
                            if (isMet) _buildMetChip(),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: isMet
                                  ? Text(
                                      'Will sync when reconnected',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        fontStyle: FontStyle.italic,
                                        color: _onSurfaceVariant,
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: target.tags
                                          .map(_buildTagChip)
                                          .toList(),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _toggleTarget(target),
                              borderRadius: BorderRadius.circular(999),
                              child: AnimatedRotation(
                                duration: const Duration(milliseconds: 160),
                                turns: target.isExpanded ? 0.5 : 0,
                                child: const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.expand_more,
                                    color: _onSurfaceVariant,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => _toggleMet(target),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isMet ? _onSurface : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isMet ? _onSurface : _outlineVariant,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.check,
                        size: 18,
                        color: isMet ? _surface : Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (target.isExpanded && !isMet)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: const BoxDecoration(
                  color: _surfaceContainer,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  border: Border(top: BorderSide(color: _outlineVariant)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PREPARED NOTES',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                        color: _onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      target.notes,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showUiOnlyMessage('Add interaction'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _onSurface,
                          side: const BorderSide(color: _outlineVariant),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.note_add_outlined, size: 18),
                        label: Text(
                          'ADD INTERACTION',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoothChip(String booth) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'BOOTH $booth',
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: _onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildMetChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _onSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'MET',
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: _surface,
        ),
      ),
    );
  }

  Widget _buildTagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _outlineVariant),
      ),
      child: Text(
        tag.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: _onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildOfflineFooterNote() {
    return Text(
      'Viewing cached data from last sync. New contacts and AI features unavailable offline.',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        color: _onSurfaceVariant.withValues(alpha: 0.70),
        height: 1.45,
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 92,
      decoration: const BoxDecoration(
        color: Color(0xF2141313),
        border: Border(top: BorderSide(color: _outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBottomItem(
              icon: Icons.gps_fixed,
              label: 'Scope',
              onTap: () => _navigate(0),
            ),
            _buildBottomItem(
              icon: Icons.contacts_outlined,
              label: 'Intel',
              onTap: () => _navigate(3),
            ),
            Transform.translate(
              offset: const Offset(0, -10),
              child: InkWell(
                onTap: () => _navigate(2),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: _onPrimary,
                    size: 30,
                  ),
                ),
              ),
            ),
            _buildBottomItem(
              icon: Icons.calendar_today,
              label: 'Events',
              onTap: () => _navigate(1),
            ),
            _buildBottomItem(
              icon: Icons.wifi_off,
              label: 'System',
              active: true,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 64,
        padding: const EdgeInsets.only(bottom: 14, top: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (active)
              Container(
                width: 28,
                height: 2,
                margin: const EdgeInsets.only(bottom: 8),
                color: _primary,
              )
            else
              const SizedBox(height: 10),
            Icon(icon, color: active ? _primary : _onSurfaceVariant, size: 21),
            const SizedBox(height: 6),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 1.3,
                color: active ? _primary : _onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineTarget {
  final String indexLabel;
  final String company;
  final String booth;
  final List<String> tags;
  final String notes;
  bool isMet;
  bool isExpanded;

  _OfflineTarget({
    required this.indexLabel,
    required this.company,
    required this.booth,
    required this.tags,
    required this.notes,
    required this.isMet,
    required this.isExpanded,
  });
}
