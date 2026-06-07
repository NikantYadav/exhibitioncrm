import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chip.dart';
import '../widgets/app_section_label.dart';
import 'log_interaction_screen.dart';

// ─── Data models ────────────────────────────────────────────────────────────

class TargetListItemData {
  final String company;
  final String booth;
  final String sector;
  final String contact;
  final String title;
  final int score;
  final List<String> prepNotes;
  final String overview;
  final String products;
  final String meetingObjective;
  final String notes;
  final double relationshipStrength;
  final bool isMet;

  const TargetListItemData({
    required this.company,
    required this.booth,
    required this.sector,
    required this.contact,
    required this.title,
    required this.score,
    required this.prepNotes,
    this.overview = '',
    this.products = '',
    this.meetingObjective = '',
    this.notes = '',
    required this.relationshipStrength,
    required this.isMet,
  });
}

class EventGoalData {
  final String label;
  final int current;
  final int target;

  const EventGoalData({
    required this.label,
    required this.current,
    required this.target,
  });

  double get progress => target == 0 ? 0 : (current / target).clamp(0.0, 1.0);
  bool get isComplete => current >= target;
}

// ─── Screen ─────────────────────────────────────────────────────────────────

class TargetListFullViewScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  final List<TargetListItemData> items;
  final String eventTitle;
  final String countLabel;
  final List<EventGoalData> goals;

  const TargetListFullViewScreen({
    super.key,
    this.onNavigateTab,
    required this.items,
    required this.eventTitle,
    required this.countLabel,
    this.goals = const [],
  });

  @override
  State<TargetListFullViewScreen> createState() =>
      _TargetListFullViewScreenState();
}

class _TargetListFullViewScreenState extends State<TargetListFullViewScreen> {
  ExonoColors get _c => AppTheme.colorsOf(context);

  late final List<_FullTargetItem> _items = widget.items
      .map(
        (d) => _FullTargetItem(
          company: d.company,
          booth: d.booth,
          sector: d.sector,
          contact: d.contact,
          title: d.title,
          score: d.score,
          prepNotes: d.prepNotes,
          overview: d.overview,
          products: d.products,
          meetingObjective: d.meetingObjective,
          notes: d.notes,
          relationshipStrength: d.relationshipStrength,
          isMet: d.isMet,
          isExpanded: false,
        ),
      )
      .toList();

  late final List<_GoalItem> _goals = widget.goals
      .map((g) => _GoalItem(label: g.label, current: g.current, target: g.target))
      .toList();

  String _searchQuery = '';
  String _selectedFilter = 'All';
  final _searchController = TextEditingController();

  int get _metCount => _items.where((i) => i.isMet).length;
  int get _goalsComplete => _goals.where((g) => g.isComplete).length;
  int get _remaining => _items.length - _metCount;

  List<_FullTargetItem> get _visibleItems {
    final q = _searchQuery.toLowerCase();
    return _items.where((item) {
      final matchesSearch = q.isEmpty ||
          item.company.toLowerCase().contains(q) ||
          item.booth.toLowerCase().contains(q) ||
          item.sector.toLowerCase().contains(q);
      final matchesFilter = switch (_selectedFilter) {
        'Met' => item.isMet,
        'Not Met' => !item.isMet,
        _ => true,
      };
      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _c.background,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 4,
        onNavigate: (i) {
          Navigator.of(context).pop();
          widget.onNavigateTab?.call(i);
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressStrip(),
                    if (_goals.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildGoalsCard(),
                    ],
                    const SizedBox(height: 16),
                    _buildLogInteractionButton(),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _buildFilterRow(),
                    const SizedBox(height: 16),
                    ..._buildTargetCards(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _c.background,
        border: Border(bottom: BorderSide(color: _c.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 20,
            icon: Icon(Icons.menu, color: _c.textPrimary, size: 22),
          ),
          Expanded(
            child: Center(
              child: Text(
                'EXONO',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  color: _c.textPrimary,
                  height: 1,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showUiOnlyMessage('Search'),
            splashRadius: 20,
            icon: Icon(Icons.search, color: _c.textPrimary, size: 22),
          ),
          IconButton(
            onPressed: () => _showUiOnlyMessage('Notifications'),
            splashRadius: 20,
            icon: Icon(Icons.notifications_none_rounded, color: _c.textPrimary, size: 22),
          ),
        ],
      ),
    );
  }

  // ─── Progress strip ───────────────────────────────────────────────────────

  Widget _buildProgressStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _c.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          _ProgressRing(
            metFraction: _items.isEmpty ? 0 : _metCount / _items.length,
            goalsFraction: _goals.isEmpty ? 0 : _goalsComplete / _goals.length,
            metCount: _metCount,
            totalCount: _items.length,
            metColor: _c.accent,
            goalColor: _c.success,
            trackColor: _c.border,
            textColor: _c.textPrimary,
            mutedColor: _c.textMuted,
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TARGET PROGRESS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: _c.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              _buildLegendRow(_c.accent, '$_metCount Met'),
              const SizedBox(height: 6),
              _buildLegendRow(_c.success, '$_goalsComplete Goals Done'),
              const SizedBox(height: 6),
              _buildLegendRow(_c.border, '$_remaining Remaining'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: _c.textPrimary,
          ),
        ),
      ],
    );
  }

  // ─── Goals card ───────────────────────────────────────────────────────────

  Widget _buildGoalsCard() {
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionLabel('Event Goals'),
          const SizedBox(height: 16),
          for (int i = 0; i < _goals.length; i++) ...[
            _buildGoalRow(_goals[i]),
            if (i < _goals.length - 1) const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalRow(_GoalItem goal) {
    final isComplete = goal.isComplete;
    final isNotStarted = goal.current == 0;
    final textColor = isComplete
        ? _c.success
        : isNotStarted
            ? _c.textMuted
            : _c.textPrimary;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                goal.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '${goal.current}/${goal.target}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: textColor,
              ),
            ),
            const SizedBox(width: 12),
            if (isComplete)
              Icon(Icons.check_circle_outline, size: 20, color: _c.success)
            else
              InkWell(
                onTap: () => setState(() => goal.current++),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _c.border),
                  ),
                  child: Icon(Icons.add, size: 16, color: _c.textPrimary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 4,
            color: _c.surfaceElevated,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: goal.progress,
                child: ColoredBox(
                  color: isComplete ? _c.success : _c.accent,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── LOG INTERACTION button ───────────────────────────────────────────────

  Widget _buildLogInteractionButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => showLogInteractionSheet(context),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('LOG INTERACTION'),
        style: FilledButton.styleFrom(
          backgroundColor: _c.textPrimary,
          foregroundColor: _c.background,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }

  // ─── Search + filter ──────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: TextStyle(fontSize: 13, color: _c.textPrimary),
      cursorColor: _c.accent,
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: InputDecoration(
        hintText: 'Search companies, people, booths...',
        hintStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: _c.textMuted,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(Icons.search, size: 20, color: _c.textMuted),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: _c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _c.accent),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    const filters = ['All', 'Not Met', 'Met'];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = filters[i];
          final isActive = _selectedFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? _c.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive ? _c.accent : _c.border,
                ),
              ),
              child: Text(
                f.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: isActive ? Colors.white : _c.textMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Target cards ─────────────────────────────────────────────────────────

  List<Widget> _buildTargetCards() {
    final visible = _visibleItems;
    if (visible.isEmpty) {
      return [
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No targets match.',
            style: TextStyle(fontSize: 14, color: _c.textMuted),
          ),
        ),
      ];
    }

    return [
      for (int i = 0; i < visible.length; i++) ...[
        _buildTargetCard(i, visible[i]),
        if (i < visible.length - 1) const SizedBox(height: 12),
      ],
    ];
  }

  Widget _buildTargetCard(int displayIndex, _FullTargetItem item) {
    final rankLabel = (displayIndex + 1).toString().padLeft(2, '0');

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: item.isMet ? 0.55 : 1.0,
      child: AppCard(
        radius: 16,
        elevated: item.isExpanded,
        borderColor: item.isExpanded ? _c.accent.withValues(alpha: 0.5) : null,
        child: Column(
          children: [
            // ── Collapsed header ──
            InkWell(
              onTap: () => setState(() => item.isExpanded = !item.isExpanded),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rank
                    SizedBox(
                      width: 28,
                      child: Text(
                        rankLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _c.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Company + booth + sector
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.company,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                              color: item.isMet ? _c.textMuted : _c.textPrimary,
                              decoration: item.isMet
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              AppChip.label(item.booth),
                              const SizedBox(width: 8),
                              Text(
                                item.sector.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                  color: _c.textMuted,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                item.isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 16,
                                color: _c.textMuted,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Met toggle
                    Column(
                      children: [
                        InkWell(
                          onTap: () => setState(() {
                            item.isMet = !item.isMet;
                            if (item.isMet) item.isExpanded = false;
                          }),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: item.isMet ? _c.textPrimary : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: item.isMet ? _c.textPrimary : _c.border,
                              ),
                            ),
                            child: item.isMet
                                ? Icon(Icons.check, size: 16, color: _c.background)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'MET',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: _c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // ── Expanded body ──
            if (item.isExpanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _c.surfaceAlt,
                  border: Border(top: BorderSide(color: _c.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.overview.isNotEmpty) ...[
                      _buildDetailSection('Company Overview', item.overview),
                      const SizedBox(height: 16),
                    ],
                    if (item.products.isNotEmpty) ...[
                      _buildDetailSection('Products & Services', item.products),
                      const SizedBox(height: 16),
                    ],
                    if (item.prepNotes.isNotEmpty) ...[
                      AppSectionLabel('AI Prep Notes'),
                      const SizedBox(height: 8),
                      for (final note in item.prepNotes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $note',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                              color: _c.textSecondary,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                    if (item.meetingObjective.isNotEmpty) ...[
                      _buildDetailSection('Meeting Objective', item.meetingObjective),
                      const SizedBox(height: 16),
                    ],
                    _buildDetailSection(
                      'Key Contact',
                      '${item.contact}, ${item.title}',
                      bold: true,
                    ),
                    const SizedBox(height: 16),
                    AppSectionLabel('My Notes'),
                    const SizedBox(height: 6),
                    Text(
                      item.notes.isEmpty ? 'No notes yet.' : item.notes,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        fontStyle: item.notes.isEmpty ? FontStyle.italic : null,
                        color: _c.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // ── Actions ──
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => showLogInteractionSheet(context),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('LOG INTERACTION'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _c.textPrimary,
                          foregroundColor: _c.background,
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _showUiOnlyMessage('Profile'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _c.textPrimary,
                              side: BorderSide(color: _c.border),
                              minimumSize: const Size.fromHeight(40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              ),
                            ),
                            child: const Text('PROFILE'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              item.isMet = !item.isMet;
                              if (item.isMet) item.isExpanded = false;
                            }),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _c.textPrimary,
                              side: BorderSide(color: _c.border),
                              minimumSize: const Size.fromHeight(40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              ),
                            ),
                            child: Text(item.isMet ? 'UNMARK MET' : 'MARK MET'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String label, String content, {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionLabel(label),
        const SizedBox(height: 6),
        Text(
          content,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            height: 1.5,
            color: _c.textSecondary,
          ),
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

// ─── Progress ring ────────────────────────────────────────────────────────────

class _ProgressRing extends StatelessWidget {
  final double metFraction;
  final double goalsFraction;
  final int metCount;
  final int totalCount;
  final Color metColor;
  final Color goalColor;
  final Color trackColor;
  final Color textColor;
  final Color mutedColor;

  const _ProgressRing({
    required this.metFraction,
    required this.goalsFraction,
    required this.metCount,
    required this.totalCount,
    required this.metColor,
    required this.goalColor,
    required this.trackColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(72, 72),
            painter: _RingPainter(
              metFraction: metFraction,
              goalsFraction: goalsFraction,
              metColor: metColor,
              goalColor: goalColor,
              trackColor: trackColor,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$metCount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  height: 1,
                ),
              ),
              Container(
                height: 1,
                width: 20,
                color: mutedColor.withValues(alpha: 0.4),
                margin: const EdgeInsets.symmetric(vertical: 2),
              ),
              Text(
                '$totalCount',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: mutedColor,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double metFraction;
  final double goalsFraction;
  final Color metColor;
  final Color goalColor;
  final Color trackColor;

  _RingPainter({
    required this.metFraction,
    required this.goalsFraction,
    required this.metColor,
    required this.goalColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 4;
    const strokeWidth = 5.0;
    const startAngle = -math.pi / 2;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt,
    );

    // Met arc
    if (metFraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * math.pi * metFraction,
        false,
        Paint()
          ..color = metColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
    }

    // Goals arc (offset after met arc)
    if (goalsFraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + (2 * math.pi * metFraction),
        2 * math.pi * goalsFraction,
        false,
        Paint()
          ..color = goalColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.metFraction != metFraction || old.goalsFraction != goalsFraction;
}

// ─── Mutable runtime item ─────────────────────────────────────────────────────

class _FullTargetItem {
  final String company;
  final String booth;
  final String sector;
  final String contact;
  final String title;
  final int score;
  final List<String> prepNotes;
  final String overview;
  final String products;
  final String meetingObjective;
  final String notes;
  final double relationshipStrength;
  bool isMet;
  bool isExpanded;

  _FullTargetItem({
    required this.company,
    required this.booth,
    required this.sector,
    required this.contact,
    required this.title,
    required this.score,
    required this.prepNotes,
    required this.overview,
    required this.products,
    required this.meetingObjective,
    required this.notes,
    required this.relationshipStrength,
    required this.isMet,
    required this.isExpanded,
  });
}

class _GoalItem {
  final String label;
  int current;
  final int target;

  _GoalItem({
    required this.label,
    required this.current,
    required this.target,
  });

  double get progress => target == 0 ? 0 : (current / target).clamp(0.0, 1.0);
  bool get isComplete => current >= target;
}
