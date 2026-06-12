import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/live_event_provider.dart';

/// Live bar docked above the nav bar — rounded top corners, blue accent theme.
class LiveBar extends StatefulWidget {
  final VoidCallback onTap;

  const LiveBar({super.key, required this.onTap});

  @override
  State<LiveBar> createState() => _LiveBarState();
}

class _LiveBarState extends State<LiveBar> with TickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late AnimationController _pulseCtrl;

  late Animation<double> _enterSlide;
  late Animation<double> _enterOpacity;
  late Animation<double> _pulseScale;

  bool _wasLive = false;

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _enterSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic),
    );
    _enterOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.75, end: 1.4).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _handleLiveChange(bool isLive) {
    if (isLive && !_wasLive) _enterCtrl.forward(from: 0);
    _wasLive = isLive;
  }

  @override
  Widget build(BuildContext context) {
    final lep = context.watch<LiveEventProvider>();
    final c = AppTheme.colorsOf(context);

    _handleLiveChange(lep.isLive);

    if (!lep.isLive) return const SizedBox.shrink();

    final event = lep.liveEvent!;
    final targetsLeft = lep.targetsLeft;
    final scanned = lep.scannedContacts.length;
    final goalsLeft = lep.liveGoals.where((g) => (g['status'] as String?) != 'completed').length;

    final bg = c.isDark ? c.accentStrong : c.accent;
    const live = Color(0xFFFF453A);
    final divider = Colors.white.withValues(alpha: 0.20);
    final labelColor = Colors.white.withValues(alpha: 0.70);
    const valueColor = Colors.white;

    return AnimatedBuilder(
      animation: _enterCtrl,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _enterSlide.value),
        child: Opacity(opacity: _enterOpacity.value, child: child),
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        // Extra bottom padding so the QR button floating 14px above the nav
        // doesn't overlap this bar's content.
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: dot + LIVE + event name + arrow
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Row(
                    children: [
                      // Pulsing dot
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (context, _) {
                          return SizedBox(
                            width: 20,
                            height: 20,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Transform.scale(
                                  scale: _pulseScale.value,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: live.withValues(
                                        alpha: (1 - (_pulseScale.value - 0.75) / 0.65) * 0.30,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: live,
                                    boxShadow: [
                                      BoxShadow(
                                        color: live.withValues(alpha: 0.7),
                                        blurRadius: 5,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: live,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 12, color: divider),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.name,
                          style: context.theme.typography.sm.copyWith(
                            fontWeight: FontWeight.w600,
                            color: valueColor,
                            letterSpacing: 0.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.north_east_rounded, size: 13, color: Colors.white.withValues(alpha: 0.5)),
                    ],
                  ),
                ),

                // Thin divider
                Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),

                // Stats row
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Row(
                    children: [
                      _stat(scanned.toString(), 'Scanned', labelColor, valueColor, context),
                      _dividerWidget(divider),
                      _stat(
                        targetsLeft.toString(),
                        'Targets left',
                        labelColor,
                        targetsLeft > 0 ? live : Colors.white.withValues(alpha: 0.5),
                        context,
                      ),
                      _dividerWidget(divider),
                      _stat(
                        goalsLeft.toString(),
                        'Goals left',
                        labelColor,
                        goalsLeft > 0 ? live : Colors.white.withValues(alpha: 0.5),
                        context,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color labelColor, Color valueColor, BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: context.theme.typography.lg.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: context.theme.typography.xs.copyWith(
              fontWeight: FontWeight.w500,
              color: labelColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerWidget(Color color) {
    return Container(width: 1, height: 28, color: color);
  }
}
