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
          child: ColoredBox(
            color: bg,
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

                // Stats row — all three on the same baseline. The bottom edge of
                // the bar is notched (see _LiveBarNotchClipper) so the scanner
                // button nests into the centre. Bottom padding clears the notch
                // depth so the centre label is never clipped.
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
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

/// Clips the live bar's bottom edge into a concave notch at the centre, so the
/// floating scanner button (centred over the nav bar) nests into the bar
/// instead of overlapping its content or leaving a gap above the nav.
class _LiveBarNotchClipper extends CustomClipper<Path> {
  // Geometry of the notch — a wide, shallow concave cradle for the scanner
  // button (≈56px). Half-width controls how wide it spreads; depth how far it
  // dips up into the bar. Kept shallow so the centre stat's label clears it.
  static const double _notchHalfWidth = 56;
  static const double _notchDepth = 24;
  static const double _topRadius = 18;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final path = Path();
    // Start just below the top-left rounded corner.
    path.moveTo(0, _topRadius);
    path.quadraticBezierTo(0, 0, _topRadius, 0);
    path.lineTo(w - _topRadius, 0);
    path.quadraticBezierTo(w, 0, w, _topRadius);
    // Down the right edge to the bottom.
    path.lineTo(w, h);
    // Along the bottom edge to the right shoulder of the notch.
    path.lineTo(cx + _notchHalfWidth, h);
    // Smooth concave dip up to the centre and back down — two mirrored cubics.
    path.cubicTo(
      cx + _notchHalfWidth * 0.45, h,
      cx + _notchHalfWidth * 0.40, h - _notchDepth,
      cx, h - _notchDepth,
    );
    path.cubicTo(
      cx - _notchHalfWidth * 0.40, h - _notchDepth,
      cx - _notchHalfWidth * 0.45, h,
      cx - _notchHalfWidth, h,
    );
    // Remaining bottom edge to the left, then up to the start.
    path.lineTo(0, h);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
