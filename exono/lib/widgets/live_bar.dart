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
    final divider = Colors.white.withValues(alpha: 0.20);
    final labelColor = Colors.white.withValues(alpha: 0.65);
    const valueColor = Colors.white;
    const liveIndicator = Colors.white;

    return AnimatedBuilder(
      animation: _enterCtrl,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _enterSlide.value),
        child: Opacity(opacity: _enterOpacity.value, child: child),
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        child: PhysicalShape(
          clipper: _LiveBarNotchClipper(),
          color: bg,
          elevation: 8,
          shadowColor: c.accent.withValues(alpha: 0.45),
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
                          final ringAlpha = (1 - (_pulseScale.value - 0.75) / 0.65) * 0.35;
                          return SizedBox(
                            width: 18,
                            height: 18,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Transform.scale(
                                  scale: _pulseScale.value,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: liveIndicator.withValues(alpha: ringAlpha),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: liveIndicator,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'LIVE',
                        style: context.theme.typography.xs.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                          color: Colors.white.withValues(alpha: 0.90),
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

                // Stats row — all three on the same baseline. Extra bottom
                // padding keeps the centre stat clear of the raised scanner
                // button that pokes up over the nav bar below.
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                  child: Row(
                    children: [
                      _stat(scanned.toString(), 'Scanned', labelColor, valueColor, context),
                      _dividerWidget(divider),
                      _stat(
                        targetsLeft.toString(),
                        'Targets left',
                        labelColor,
                        targetsLeft > 0 ? valueColor : Colors.white.withValues(alpha: 0.45),
                        context,
                      ),
                      _dividerWidget(divider),
                      _stat(
                        goalsLeft.toString(),
                        'Goals left',
                        labelColor,
                        goalsLeft > 0 ? valueColor : Colors.white.withValues(alpha: 0.45),
                        context,
                      ),
                    ],
                  ),
                ),
              ],
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

/// Clips the live bar with rounded top corners and a straight bottom edge.
class _LiveBarNotchClipper extends CustomClipper<Path> {
  static const double _topRadius = 28;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();
    // Top-left rounded corner (true quarter-circle arc).
    path.moveTo(0, _topRadius);
    path.arcToPoint(
      Offset(_topRadius, 0),
      radius: const Radius.circular(_topRadius),
      clockwise: true,
    );
    path.lineTo(w - _topRadius, 0);
    // Top-right rounded corner.
    path.arcToPoint(
      Offset(w, _topRadius),
      radius: const Radius.circular(_topRadius),
      clockwise: true,
    );
    // Down the right edge, straight along the bottom, back up the left edge.
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
