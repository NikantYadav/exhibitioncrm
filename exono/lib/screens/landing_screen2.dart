import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../utils/safe_area_insets.dart';
import '../utils/screen_logger.dart';

// ─── Aeline replica palette (exact template tokens) ───────────────────────────
const _ink = Color(0xFF131313); // primary text / dark surfaces
const _ink2 = Color(0xFF2F2F2F); // secondary dark
const _gray = Color(0xFF7B7B7B); // body copy
const _grayCard = Color(0xFFF2F2F2); // light card fill
const _lime = Color(0xFFD6FD70); // primary accent
const _limeDeep = Color(0xFFCDFB56); // accent pressed / chips
const _white = Color(0xFFFFFFFF);
const _skyTop = Color(0xFF2E7BD6); // hero gradient top
const _skyMid = Color(0xFF3795D7); // hero gradient middle
const _skyLow = Color(0xFF7CC3EE); // hero gradient toward clouds
const _skyPale = Color(0xFFD8EEFB); // cloud band

// ─── Typography: Plus Jakarta Sans display/body + Geist Mono labels ───────────
TextStyle _h(double s,
        {Color c = _ink, FontWeight w = FontWeight.w600, double? height}) =>
    GoogleFonts.plusJakartaSans(
        fontSize: s,
        fontWeight: w,
        color: c,
        height: height ?? 1.12,
        letterSpacing: -s * 0.028);

TextStyle _b(double s, {Color c = _gray, FontWeight w = FontWeight.w400}) =>
    GoogleFonts.plusJakartaSans(
        fontSize: s, fontWeight: w, color: c, height: 1.55);

TextStyle _m(double s, {Color c = _ink, FontWeight w = FontWeight.w500}) =>
    GoogleFonts.geistMono(
        fontSize: s, fontWeight: w, color: c, letterSpacing: 1.1);

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

// Verified Unsplash assets (photo-led sections).
const _imgTesti1 =
    'https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=900&q=80';
const _imgTesti2 =
    'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=900&q=80';
const _imgTesti3 =
    'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&w=900&q=80';
const _imgCta =
    'https://images.unsplash.com/photo-1540575467063-178a50c2df87?auto=format&fit=crop&w=1600&q=80';
const _imgNote1 =
    'https://images.unsplash.com/photo-1511578314322-379afb476865?auto=format&fit=crop&w=900&q=80';
const _imgNote2 =
    'https://images.unsplash.com/photo-1587825140708-dfaf72ae4b04?auto=format&fit=crop&w=900&q=80';
const _imgNote3 =
    'https://images.unsplash.com/photo-1591115765373-5207764f72e7?auto=format&fit=crop&w=900&q=80';
const _imgAvatar1 =
    'https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=100&q=80';
const _imgAvatar2 =
    'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=100&q=80';
const _imgAvatar3 =
    'https://images.unsplash.com/photo-1556761175-b413da4baf72?auto=format&fit=crop&w=100&q=80';

// ══════════════════════════════════════════════════════════════════════════════
// Screen
// ══════════════════════════════════════════════════════════════════════════════
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with ScreenLogger {
  final _scroll = ScrollController();
  final _featuresKey = GlobalKey();
  final _insideKey = GlobalKey();
  final _pricingKey = GlobalKey();
  final _testiKey = GlobalKey();
  final _notesKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _goAuth() => context.go('/auth');

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) {
      return;
    }
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutQuart);
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MenuSheet(
        onGetStarted: () {
          Navigator.pop(ctx);
          _goAuth();
        },
        onLink: (key) {
          Navigator.pop(ctx);
          _scrollTo(key);
        },
        links: {
          'FEATURES': _featuresKey,
          'INSIDE THE APP': _insideKey,
          'PRICING': _pricingKey,
          'TESTIMONIALS': _testiKey,
          'FIELD NOTES': _notesKey,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _white,
      body: SingleChildScrollView(
        controller: _scroll,
        child: Column(
          children: [
            _Hero(
              onGetStarted: _goAuth,
              onViewDemo: () => _scrollTo(_insideKey),
              onMenu: _openMenu,
            ),
            const _LogoStrip(),
            const _AboutSection(),
            _ServicesSection(key: _featuresKey, onGetStarted: _goAuth),
            _InsideSection(key: _insideKey),
            _PricingSection(key: _pricingKey, onGetStarted: _goAuth),
            _TestimonialsSection(key: _testiKey),
            _FieldNotesSection(key: _notesKey),
            _FinalCtaSection(onGetStarted: _goAuth),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared building blocks
// ══════════════════════════════════════════════════════════════════════════════

/// Max-width page gutter.
class _Gutter extends StatelessWidget {
  final Widget child;
  final double max;
  const _Gutter({required this.child, this.max = 1140});
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 900;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 20),
          child: child,
        ),
      ),
    );
  }
}

/// Scroll-triggered reveal: fade + slide, plays once when it enters view.
class _Reveal extends StatefulWidget {
  final Widget child;
  final double dy;
  final int delayMs;
  const _Reveal({required this.child, this.dy = 0.08, this.delayMs = 0});
  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  final _vk = UniqueKey();
  bool _seen = false;

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) {
      return widget.child;
    }
    return VisibilityDetector(
      key: _vk,
      onVisibilityChanged: (info) {
        if (!_seen && info.visibleFraction > 0.12 && mounted) {
          setState(() => _seen = true);
        }
      },
      child: widget.child
          .animate(target: _seen ? 1 : 0)
          .fadeIn(
              delay: widget.delayMs.ms,
              duration: 700.ms,
              curve: Curves.easeOutQuart)
          .slideY(
              begin: widget.dy,
              end: 0,
              delay: widget.delayMs.ms,
              duration: 700.ms,
              curve: Curves.easeOutQuart),
    );
  }
}

enum _PillVariant { dark, light, lime }

/// Template button: pill shape, mono uppercase label, optional lime arrow chip.
class _Pill extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final _PillVariant variant;
  final bool arrow;
  final bool fullWidth;
  const _Pill(this.label, this.onTap,
      {this.variant = _PillVariant.dark,
      this.arrow = false,
      this.fullWidth = false});
  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (widget.variant) {
      case _PillVariant.dark:
        bg = _ink;
        fg = _white;
      case _PillVariant.light:
        bg = _white;
        fg = _ink;
      case _PillVariant.lime:
        bg = _lime;
        fg = _ink;
    }
    final row = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(widget.label, style: _m(12, c: fg, w: FontWeight.w600)),
        if (widget.arrow) ...[
          const SizedBox(width: 10),
          Container(
            width: 24,
            height: 24,
            decoration:
                const BoxDecoration(color: _lime, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_outward, size: 14, color: _ink),
          ),
        ],
      ],
    );
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutQuart,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: widget.arrow ? 18 : 24, vertical: 13),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: row,
        ),
      ),
    );
  }
}

/// "• SECTION NAME" mono kicker.
class _Kicker extends StatelessWidget {
  final String text;
  final Color color;
  const _Kicker(this.text, {this.color = _ink});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(text, style: _m(11, c: color, w: FontWeight.w600)),
      ],
    );
  }
}

/// Centered section header: kicker + heading + optional sub + optional button.
class _SectionHead extends StatelessWidget {
  final String kicker;
  final String title;
  final String? sub;
  final Widget? action;
  const _SectionHead(
      {required this.kicker, required this.title, this.sub, this.action});
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 900;
    return Column(
      children: [
        _Kicker(kicker),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: _h(wide ? 44 : 30, w: FontWeight.w500),
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(sub!, textAlign: TextAlign.center, style: _b(15)),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: 26),
          action!,
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Hero
// ══════════════════════════════════════════════════════════════════════════════
class _Hero extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onViewDemo;
  final VoidCallback onMenu;
  const _Hero(
      {required this.onGetStarted,
      required this.onViewDemo,
      required this.onMenu});

  Widget _entrance(BuildContext context, Widget w, int i) {
    if (_reduceMotion(context)) {
      return w;
    }
    return w
        .animate()
        .fadeIn(
            delay: (140 * i).ms, duration: 750.ms, curve: Curves.easeOutQuart)
        .slideY(
            begin: 0.22,
            end: 0,
            delay: (140 * i).ms,
            duration: 750.ms,
            curve: Curves.easeOutQuart);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width > 900;
    final heroH = size.height.clamp(640.0, 980.0);
    return Container(
      height: heroH,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_skyTop, _skyMid, _skyLow, _skyPale],
          stops: [0.0, 0.45, 0.8, 1.0],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: _CloudLayer()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _NavBar(onMenu: onMenu),
                const Spacer(),
                _Gutter(
                  child: Column(
                    children: [
                      _entrance(
                        context,
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Text(
                            'Capture every lead.\nLand every follow-up.',
                            textAlign: TextAlign.center,
                            style: _h(wide ? 60 : 36,
                                c: _white, w: FontWeight.w500, height: 1.08),
                          ),
                        ),
                        0,
                      ),
                      const SizedBox(height: 18),
                      _entrance(
                        context,
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Text(
                            'Exono is the AI assistant for exhibitions and events. It captures contacts, remembers every conversation, and drafts follow-ups that actually get sent.',
                            textAlign: TextAlign.center,
                            style: _b(15, c: _white.withValues(alpha: 0.88)),
                          ),
                        ),
                        1,
                      ),
                      const SizedBox(height: 28),
                      _entrance(
                        context,
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            _Pill('VIEW DEMO', onViewDemo,
                                variant: _PillVariant.light),
                            _Pill('GET STARTED', onGetStarted, arrow: true),
                          ],
                        ),
                        2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                _entrance(context, const _HeroCardFan(), 3),
                const SizedBox(height: 26),
                _entrance(
                  context,
                  Column(
                    children: [
                      Text('Rated 4.9/5 by 4,900+ event professionals',
                          style: _b(12, c: _white.withValues(alpha: 0.85))),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          5,
                          (_) => const Icon(Icons.star_rounded,
                              size: 16, color: _lime),
                        ),
                      ),
                    ],
                  ),
                  4,
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final VoidCallback onMenu;
  const _NavBar({required this.onMenu});
  @override
  Widget build(BuildContext context) {
    return _Gutter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            const _Wordmark(color: _white),
            const Spacer(),
            GestureDetector(
              onTap: onMenu,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _lime,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_rounded, color: _ink, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  final Color color;
  const _Wordmark({this.color = _ink});
  @override
  Widget build(BuildContext context) {
    final onDark = color == _white;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: onDark ? _white : _ink,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text('e',
                style: _h(17,
                    c: onDark ? _skyTop : _lime,
                    w: FontWeight.w800,
                    height: 1)),
          ),
        ),
        const SizedBox(width: 9),
        Text('Exono', style: _h(18, c: color, w: FontWeight.w700)),
      ],
    );
  }
}

/// Soft cloud shapes at the base of the hero.
class _CloudLayer extends StatelessWidget {
  const _CloudLayer();
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _CloudPainter()),
    );
  }
}

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _white.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);
    final h = size.height;
    final w = size.width;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.18, h * 0.94), width: w * 0.7, height: 130),
        paint);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.78, h * 0.9), width: w * 0.6, height: 110),
        paint);
    paint.color = _white.withValues(alpha: 0.35);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.8), width: w * 0.8, height: 100),
        paint);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.1, h * 0.72), width: w * 0.45, height: 70),
        paint);
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) => false;
}

/// The arc of floating mini app-mockup cards under the hero copy.
class _HeroCardFan extends StatelessWidget {
  const _HeroCardFan();

  Widget _float(BuildContext context, Widget w, int i) {
    if (_reduceMotion(context)) {
      return w;
    }
    return w.animate(onPlay: (c) => c.repeat(reverse: true)).moveY(
        begin: 0,
        end: -7,
        duration: (2300 + i * 260).ms,
        curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 900;
    final spread = wide ? 190.0 : 76.0;
    final cards = <Widget>[
      const _MiniPerfCard(),
      const _MiniVoiceCard(),
      const _MiniContactCard(),
      const _MiniFollowUpCard(),
      const _MiniGoalCard(),
    ];
    const angles = [-0.24, -0.11, 0.0, 0.11, 0.24];
    const lifts = [26.0, 8.0, 0.0, 8.0, 26.0];
    // Paint order: outer cards first so the centre card sits on top.
    const order = [0, 4, 1, 3, 2];
    return SizedBox(
      height: wide ? 230 : 200,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          for (final i in order)
            Transform.translate(
              offset: Offset((i - 2) * spread * (wide ? 1 : 1.35), lifts[i]),
              child: Transform.rotate(
                angle: angles[i],
                child: _float(context, cards[i], i),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniCardShell extends StatelessWidget {
  final Widget child;
  const _MiniCardShell({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      height: 152,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 16),
            spreadRadius: -12,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MiniContactCard extends StatelessWidget {
  const _MiniContactCard();
  @override
  Widget build(BuildContext context) {
    return _MiniCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _lime,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
                child:
                    Text('MK', style: _h(11, w: FontWeight.w800, height: 1))),
          ),
          const SizedBox(height: 10),
          Text('Mohammed K.', style: _h(11, w: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Nexus Energy', style: _b(9)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _limeDeep,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text('MET TODAY', style: _m(7, w: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _MiniVoiceCard extends StatelessWidget {
  const _MiniVoiceCard();
  @override
  Widget build(BuildContext context) {
    const heights = [8.0, 16.0, 11.0, 22.0, 9.0, 18.0, 13.0, 7.0];
    return _MiniCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VOICE NOTE', style: _m(7, c: _gray)),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: Color(0xFFE5484D), shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text('Recording', style: _h(10, w: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final h in heights) ...[
                  Container(
                    width: 3,
                    height: h,
                    decoration: BoxDecoration(
                      color: _ink,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
          const Spacer(),
          Text('Extracting name,\ncompany, next step', style: _b(8, c: _gray)),
        ],
      ),
    );
  }
}

class _MiniFollowUpCard extends StatelessWidget {
  const _MiniFollowUpCard();
  @override
  Widget build(BuildContext context) {
    Widget row(bool done) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(
            children: [
              Icon(done ? Icons.check_circle : Icons.circle_outlined,
                  size: 13, color: done ? _ink : _gray),
              const SizedBox(width: 7),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: _grayCard,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        );
    return _MiniCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FOLLOW-UPS', style: _m(7, c: _gray)),
          const SizedBox(height: 12),
          row(true),
          row(true),
          row(false),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text('DRAFT READY', style: _m(7, c: _lime)),
          ),
        ],
      ),
    );
  }
}

class _MiniPerfCard extends StatelessWidget {
  const _MiniPerfCard();
  @override
  Widget build(BuildContext context) {
    const bars = [0.4, 0.7, 0.55, 0.9];
    return _MiniCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FOLLOW-UP RATE', style: _m(7, c: _gray)),
          const SizedBox(height: 8),
          Text('92%', style: _h(24, w: FontWeight.w700, height: 1)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _limeDeep,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('+2.5%', style: _m(7, w: FontWeight.w700)),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final f in bars) ...[
                Expanded(
                  child: Container(
                    height: 26 * f,
                    decoration: BoxDecoration(
                      color: f > 0.8 ? _ink : _grayCard,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniGoalCard extends StatelessWidget {
  const _MiniGoalCard();
  @override
  Widget build(BuildContext context) {
    return _MiniCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TARGETS MET', style: _m(7, c: _gray)),
          const SizedBox(height: 8),
          Text('42/120', style: _h(19, w: FontWeight.w700, height: 1)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 6,
              color: _grayCard,
              child: const FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.35,
                child: ColoredBox(color: _ink),
              ),
            ),
          ),
          const Spacer(),
          Text('Meet 2 VCs', style: _b(9, c: _ink, w: FontWeight.w600)),
          Text('Find IoT experts', style: _b(9)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Logo strip (marquee)
// ══════════════════════════════════════════════════════════════════════════════
class _LogoStrip extends StatelessWidget {
  const _LogoStrip();
  @override
  Widget build(BuildContext context) {
    const events = [
      'ADIPEC',
      'WEB SUMMIT',
      'GITEX',
      'MONEY20/20',
      'SLUSH',
      'CES',
      'MWC',
    ];
    return Container(
      color: _white,
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Column(
        children: [
          Text('TRUSTED BY PROFESSIONALS ATTENDING', style: _m(10, c: _gray)),
          const SizedBox(height: 24),
          _Marquee(
            children: [
              for (final e in events)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Text(
                    e,
                    style: _h(17,
                        c: _ink.withValues(alpha: 0.32), w: FontWeight.w800),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Continuously scrolling row (edge-faded), static under reduced motion.
class _Marquee extends StatefulWidget {
  final List<Widget> children;
  final double speed;
  const _Marquee({required this.children, this.speed = 34});
  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee>
    with SingleTickerProviderStateMixin {
  final _sc = ScrollController();
  late final AnimationController _tick;

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(_advance);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_reduceMotion(context)) {
        _tick.forward();
      }
    });
  }

  void _advance() {
    if (!_sc.hasClients) {
      return;
    }
    final max = _sc.position.maxScrollExtent;
    if (max <= 0) {
      return;
    }
    final vp = _sc.position.viewportDimension;
    final copyWidth = (max + vp) / 4;
    final t = _tick.lastElapsedDuration?.inMicroseconds ?? 0;
    final offset = (t * 1e-6 * widget.speed) % copyWidth;
    _sc.jumpTo(offset);
  }

  @override
  void dispose() {
    _tick.dispose();
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [
          Colors.transparent,
          Colors.black,
          Colors.black,
          Colors.transparent
        ],
        stops: [0.0, 0.12, 0.88, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: SizedBox(
        height: 26,
        child: SingleChildScrollView(
          controller: _sc,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            children: [
              for (var copy = 0; copy < 4; copy++) ...widget.children,
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// About / stats
// ══════════════════════════════════════════════════════════════════════════════
class _AboutSection extends StatelessWidget {
  const _AboutSection();
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 860;
    const cards = <Widget>[
      _StatCard(
        dark: true,
        label: 'CONTACTS CAPTURED',
        value: '48k+',
        body:
            'On expo floors, at conferences and over dinners. Nothing captured gets lost.',
      ),
      _StatCard(
        label: 'FOLLOW-UP RATE',
        value: '92%',
        body: '"Follow-up stopped being a chore. It just happens now."',
        avatars: true,
      ),
      _StatCard(
        lime: true,
        label: 'DATA POINTS',
        value: '480k+',
        body: 'Enriched monthly by AI research across contacts and companies.',
      ),
      _StatCard(
        dark: true,
        label: 'COUNTRIES',
        value: '40+',
        body: 'Wherever professionals meet, Exono keeps the memory.',
      ),
    ];
    return Container(
      color: _white,
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: _Gutter(
        child: Column(
          children: [
            const _Reveal(
              child: _SectionHead(
                kicker: 'ABOUT EXONO',
                title:
                    'A relationship memory dedicated to making every conversation count',
              ),
            ),
            const SizedBox(height: 48),
            if (wide)
              _Reveal(
                delayMs: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i != cards.length - 1) const SizedBox(width: 16),
                    ],
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    _Reveal(delayMs: 60 * i, child: cards[i]),
                    if (i != cards.length - 1) const SizedBox(height: 14),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final bool dark;
  final bool lime;
  final bool avatars;
  final String label;
  final String value;
  final String body;
  const _StatCard(
      {this.dark = false,
      this.lime = false,
      this.avatars = false,
      required this.label,
      required this.value,
      required this.body});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? _ink : (lime ? _lime : _grayCard);
    final fg = dark ? _white : _ink;
    final sub = dark ? _white.withValues(alpha: 0.65) : _ink2;
    return Container(
      width: double.infinity,
      height: 218,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _m(10, c: dark ? _lime : _ink)),
          const Spacer(),
          Text(value, style: _h(40, c: fg, w: FontWeight.w600, height: 1)),
          const SizedBox(height: 12),
          if (avatars) ...[
            const _AvatarRow(size: 24),
            const SizedBox(height: 10),
          ],
          Text(body, style: _b(12.5, c: sub)),
        ],
      ),
    );
  }
}

class _AvatarRow extends StatelessWidget {
  final double size;
  const _AvatarRow({this.size = 28});
  @override
  Widget build(BuildContext context) {
    const urls = [_imgAvatar1, _imgAvatar2, _imgAvatar3];
    return SizedBox(
      height: size,
      width: size + (urls.length - 1) * size * 0.72,
      child: Stack(
        children: [
          for (var i = 0; i < urls.length; i++)
            Positioned(
              left: i * size * 0.72,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _white, width: 1.5),
                  image: DecorationImage(
                    image: NetworkImage(urls[i]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Services (features)
// ══════════════════════════════════════════════════════════════════════════════
class _ServicesSection extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _ServicesSection({super.key, required this.onGetStarted});
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 860;
    const items = [
      (
        Icons.bolt_rounded,
        'Instant capture',
        'Business cards, QR codes and voice notes become clean contacts in seconds. Fully offline on convention floors.'
      ),
      (
        Icons.travel_explore_rounded,
        'AI research',
        'Every contact and company is enriched automatically with role, product and talking points before you follow up.'
      ),
      (
        Icons.mark_email_read_rounded,
        'Smart follow-ups',
        'Personalised drafts that reference what you actually spoke about, ranked by priority and ready to send.'
      ),
    ];
    final cards = [
      for (final (icon, title, body) in items)
        _ServiceCard(icon: icon, title: title, body: body),
    ];
    return Container(
      color: _white,
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: _Gutter(
        child: Column(
          children: [
            _Reveal(
              child: _SectionHead(
                kicker: 'WHAT EXONO DOES',
                title: 'Capture, research and follow-up in one precise tool',
                sub:
                    'Whether you are working an expo floor or a conference dinner, Exono keeps pace and never drops a lead.',
                action: _Pill('GET STARTED', onGetStarted, arrow: true),
              ),
            ),
            const SizedBox(height: 48),
            if (wide)
              _Reveal(
                delayMs: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i != cards.length - 1) const SizedBox(width: 16),
                    ],
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    _Reveal(delayMs: 60 * i, child: cards[i]),
                    if (i != cards.length - 1) const SizedBox(height: 14),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _ServiceCard(
      {required this.icon, required this.title, required this.body});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _grayCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _lime,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 22, color: _ink),
          ),
          const SizedBox(height: 18),
          Text(title, style: _h(18, w: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(body, style: _b(13.5)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Inside the app (expertise rows)
// ══════════════════════════════════════════════════════════════════════════════
class _InsideSection extends StatelessWidget {
  const _InsideSection({super.key});
  @override
  Widget build(BuildContext context) {
    final rows = <(Widget, String, String)>[
      (
        const _MockVoicePanel(),
        'Voice capture on the floor',
        'Hold to record after any conversation. Exono transcribes it, extracts the name, company and next step, and files the contact before you reach the next stand.'
      ),
      (
        const _MockMemoryPanel(),
        'Memory in every contact',
        'Open any contact and see the whole history: every event, every conversation, every promise, legible at a glance.'
      ),
      (
        const _MockResearchPanel(),
        'Research briefs before you arrive',
        'Tell Exono your goals. It researches who is attending, summarises their products and hands you a prioritised target list with talking points.'
      ),
      (
        const _MockDraftPanel(),
        'Follow-ups that actually happen',
        'While the conversation is still warm, Exono drafts the email, references the details and queues it by priority. Send in minutes, not weeks.'
      ),
    ];
    final wide = MediaQuery.sizeOf(context).width > 860;
    return Container(
      color: _white,
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: _Gutter(
        child: Column(
          children: [
            const _Reveal(
              child: _SectionHead(
                kicker: 'INSIDE THE APP',
                title: 'Where floor speed meets relationship memory',
                sub:
                    'Built for one-handed capture mid-conversation, and for the considered follow-through that happens after.',
              ),
            ),
            const SizedBox(height: 48),
            for (var i = 0; i < rows.length; i++) ...[
              _Reveal(
                delayMs: 60,
                child: _FeatureRow(
                  mock: rows[i].$1,
                  title: rows[i].$2,
                  body: rows[i].$3,
                  flip: wide && i.isOdd,
                ),
              ),
              if (i != rows.length - 1) SizedBox(height: wide ? 64 : 44),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final Widget mock;
  final String title;
  final String body;
  final bool flip;
  const _FeatureRow(
      {required this.mock,
      required this.title,
      required this.body,
      this.flip = false});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 860;
    final text = Column(
      crossAxisAlignment:
          wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(title,
            textAlign: wide ? TextAlign.left : TextAlign.center,
            style: _h(wide ? 26 : 20, w: FontWeight.w600)),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(body,
              textAlign: wide ? TextAlign.left : TextAlign.center,
              style: _b(14)),
        ),
      ],
    );
    final panel = Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: _grayCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(child: mock),
    );
    if (!wide) {
      return Column(children: [panel, const SizedBox(height: 20), text]);
    }
    final children = [
      Expanded(child: panel),
      const SizedBox(width: 48),
      Expanded(child: text),
    ];
    return Row(children: flip ? children.reversed.toList() : children);
  }
}

class _MockVoicePanel extends StatelessWidget {
  const _MockVoicePanel();
  @override
  Widget build(BuildContext context) {
    const heights = [
      10.0,
      22.0,
      14.0,
      30.0,
      12.0,
      26.0,
      18.0,
      9.0,
      20.0,
      13.0
    ];
    return Container(
      width: 250,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: Color(0xFFE5484D), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('Recording voice note', style: _h(12, w: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 32,
            child: Row(
              children: [
                for (final h in heights) ...[
                  Container(
                    width: 4,
                    height: h,
                    decoration: BoxDecoration(
                      color: _ink,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _limeDeep,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('AI EXTRACTING CONTACT', style: _m(8)),
          ),
        ],
      ),
    );
  }
}

class _MockMemoryPanel extends StatelessWidget {
  const _MockMemoryPanel();
  @override
  Widget build(BuildContext context) {
    Widget entry(String event, String note) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 7,
                height: 7,
                decoration:
                    const BoxDecoration(color: _ink, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event, style: _h(11, w: FontWeight.w700)),
                    Text(note, style: _b(10)),
                  ],
                ),
              ),
            ],
          ),
        );
    return Transform.rotate(
      angle: -0.03,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MEMORY IN EVERY CONTACT', style: _m(9, c: _lime)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  entry('GITEX 2025', 'Asked for pilot pricing'),
                  entry('Web Summit 2025', 'Intro over dinner'),
                  entry('ADIPEC 2024', 'First met at booth C14'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockResearchPanel extends StatelessWidget {
  const _MockResearchPanel();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI RESEARCH BRIEF', style: _m(9, c: _lime)),
          const SizedBox(height: 12),
          Text('TechVenture Group',
              style: _h(15, c: _white, w: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('94% match with your goals',
              style: _b(11, c: _white.withValues(alpha: 0.65))),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final chip in ['SUBSEA SYSTEMS', 'BOOTH C14', 'PRIORITY'])
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(chip, style: _m(7.5, c: _white)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MockDraftPanel extends StatelessWidget {
  const _MockDraftPanel();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FOLLOW-UP DRAFT', style: _m(9, c: _gray)),
          const SizedBox(height: 10),
          Text(
            'Hi Marcus, great speaking with you at the summit about the Q3 expansion...',
            style: _b(11.5, c: _ink2),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final chip in ['SHORTEN', 'MORE FORMAL']) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _grayCard,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(chip, style: _m(7.5)),
                ),
                const SizedBox(width: 6),
              ],
              const Spacer(),
              Container(
                width: 26,
                height: 26,
                decoration:
                    const BoxDecoration(color: _lime, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_outward, size: 14, color: _ink),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Pricing
// ══════════════════════════════════════════════════════════════════════════════
class _PricingSection extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _PricingSection({super.key, required this.onGetStarted});
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 860;
    final plans = [
      _PlanCard(
        name: 'STARTER PLAN',
        icon: Icons.flag_rounded,
        desc: 'For your first events with smart capture.',
        price: r'$0',
        features: const [
          '3 events per month',
          '50 contacts',
          'Card and QR scanning',
          'Full offline mode',
        ],
        onTap: onGetStarted,
      ),
      _PlanCard(
        name: 'PRO PLAN',
        icon: Icons.auto_awesome_rounded,
        desc: 'Full AI power for serious networkers.',
        price: r'$29',
        features: const [
          'Unlimited events and contacts',
          'AI research briefs',
          'Voice capture',
          'AI follow-up drafts',
          'Goal tracking',
        ],
        onTap: onGetStarted,
      ),
      _PlanCard(
        name: 'TEAM PLAN',
        icon: Icons.groups_rounded,
        desc: 'Shared intelligence for teams on the road.',
        price: r'$99',
        features: const [
          'Everything in Pro',
          'Up to 10 members',
          'Shared contact memory',
          'CRM integrations',
          'Priority support',
        ],
        onTap: onGetStarted,
      ),
    ];
    return Container(
      color: _white,
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: _Gutter(
        child: Column(
          children: [
            _Reveal(
              child: _SectionHead(
                kicker: 'PRICING',
                title: 'Plans built for every stage of your event season',
                sub:
                    'Start free at your next event. Scale when the whole team travels.',
                action: _Pill('GET STARTED', onGetStarted, arrow: true),
              ),
            ),
            const SizedBox(height: 48),
            if (wide)
              _Reveal(
                delayMs: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < plans.length; i++) ...[
                      Expanded(child: plans[i]),
                      if (i != plans.length - 1) const SizedBox(width: 16),
                    ],
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < plans.length; i++) ...[
                    _Reveal(delayMs: 60 * i, child: plans[i]),
                    if (i != plans.length - 1) const SizedBox(height: 14),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final String desc;
  final String price;
  final List<String> features;
  final VoidCallback onTap;
  const _PlanCard(
      {required this.name,
      required this.icon,
      required this.desc,
      required this.price,
      required this.features,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _grayCard,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _lime,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: _ink),
              ),
              const SizedBox(width: 12),
              Text(name, style: _m(11, w: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Text(desc, style: _b(13.5)),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: _h(36, w: FontWeight.w600, height: 1)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('/month', style: _b(13)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: _ink.withValues(alpha: 0.08)),
          const SizedBox(height: 16),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: _ink),
                  const SizedBox(width: 10),
                  Expanded(child: Text(f, style: _b(13, c: _ink2))),
                ],
              ),
            ),
          const SizedBox(height: 10),
          _Pill('GET STARTED', onTap, fullWidth: true),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Testimonials (photo carousel)
// ══════════════════════════════════════════════════════════════════════════════
class _TestimonialsSection extends StatefulWidget {
  const _TestimonialsSection({super.key});
  @override
  State<_TestimonialsSection> createState() => _TestimonialsSectionState();
}

class _TestimonialsSectionState extends State<_TestimonialsSection> {
  final _page = PageController(viewportFraction: 0.9);

  static const _items = [
    (
      _imgTesti1,
      '"I came back from ADIPEC with 80 cards and used to follow up with five. This time all 34 of my targets heard from me within 48 hours."',
      'Mohammed Al-Khalidi, VP Business Development'
    ),
    (
      _imgTesti2,
      '"I walked into Web Summit knowing exactly who to meet and what to say. My meeting rate tripled compared to last year."',
      'Sarah Lindqvist, Founder'
    ),
    (
      _imgTesti3,
      '"Convention WiFi is terrible. Exono works fully offline and syncs everything later. That alone sold me."',
      'David Reyes, Enterprise Sales Director'
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _go(int dir) {
    final target =
        ((_page.page ?? 0).round() + dir).clamp(0, _items.length - 1);
    _page.animateToPage(target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutQuart);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 860;
    return Container(
      color: _white,
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          const _Reveal(
            child: _SectionHead(
              kicker: 'TESTIMONIALS',
              title: 'What the floor says about us',
              sub:
                  'From BD reps to founders: what changed after they brought Exono to their events.',
            ),
          ),
          const SizedBox(height: 44),
          _Reveal(
            delayMs: 120,
            child: SizedBox(
              height: wide ? 460 : 420,
              child: PageView.builder(
                controller: _page,
                itemCount: _items.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _TestimonialCard(
                    image: _items[i].$1,
                    quote: _items[i].$2,
                    author: _items[i].$3,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ArrowButton(
                  icon: Icons.arrow_back_rounded, onTap: () => _go(-1)),
              const SizedBox(width: 12),
              _ArrowButton(
                  icon: Icons.arrow_forward_rounded, onTap: () => _go(1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _ink.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: 20, color: _ink),
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  final String image;
  final String quote;
  final String author;
  const _TestimonialCard(
      {required this.image, required this.quote, required this.author});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            image,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(color: _grayCard),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xD9131313)],
                stops: [0.4, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote_rounded, color: _lime, size: 28),
                const SizedBox(height: 8),
                Text(quote,
                    style:
                        _h(16, c: _white, w: FontWeight.w600, height: 1.35)),
                const SizedBox(height: 12),
                Text(author,
                    style: _b(12, c: _white.withValues(alpha: 0.75))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Field notes (blog)
// ══════════════════════════════════════════════════════════════════════════════
class _FieldNotesSection extends StatelessWidget {
  const _FieldNotesSection({super.key});
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 860;
    const items = [
      (_imgNote1, 'The 48-hour follow-up window'),
      (_imgNote2, 'Working a 40,000-person expo with a plan'),
      (_imgNote3, 'Why voice notes beat business cards'),
    ];
    final cards = [
      for (final (img, title) in items) _NoteCard(image: img, title: title),
    ];
    return Container(
      color: _white,
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: _Gutter(
        child: Column(
          children: [
            const _Reveal(
              child: _SectionHead(
                kicker: 'FIELD NOTES',
                title: 'Latest insights from the floor',
                sub:
                    'What we are learning from thousands of events, captured contacts and follow-ups.',
              ),
            ),
            const SizedBox(height: 44),
            if (wide)
              _Reveal(
                delayMs: 120,
                child: Row(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i != cards.length - 1) const SizedBox(width: 16),
                    ],
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    _Reveal(delayMs: 60 * i, child: cards[i]),
                    if (i != cards.length - 1) const SizedBox(height: 14),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String image;
  final String title;
  const _NoteCard({required this.image, required this.title});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 300,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: _grayCard),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC131313)],
                  stops: [0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(title,
                        style: _h(17, c: _white, w: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                        color: _lime, shape: BoxShape.circle),
                    child:
                        const Icon(Icons.arrow_outward, size: 15, color: _ink),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Final CTA
// ══════════════════════════════════════════════════════════════════════════════
class _FinalCtaSection extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _FinalCtaSection({required this.onGetStarted});
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 860;
    return SizedBox(
      height: wide ? 560 : 520,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            _imgCta,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(color: _ink),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: _ink.withValues(alpha: 0.62),
            ),
          ),
          _Gutter(
            child: _Reveal(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _AvatarRow(),
                  const SizedBox(height: 12),
                  Text('Trusted by 5,000+ professionals',
                      style: _b(13, c: _white.withValues(alpha: 0.85))),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Text(
                      'We give every handshake a lasting memory',
                      textAlign: TextAlign.center,
                      style: _h(wide ? 44 : 30, c: _white, w: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      'Nothing captured gets lost, and every follow-up happens because the next step is already drafted.',
                      textAlign: TextAlign.center,
                      style: _b(14, c: _white.withValues(alpha: 0.8)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _Pill('GET STARTED', onGetStarted,
                      variant: _PillVariant.lime),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Footer
// ══════════════════════════════════════════════════════════════════════════════
class _Footer extends StatefulWidget {
  const _Footer();
  @override
  State<_Footer> createState() => _FooterState();
}

class _FooterState extends State<_Footer> {
  final _email = TextEditingController();
  bool _subscribed = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 860;
    return Container(
      color: _ink,
      padding: EdgeInsets.fromLTRB(0, 56, 0, 28 + bottomScrollInset(context)),
      child: _Gutter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Wordmark(color: _white),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                'The personal assistant and relationship memory for exhibitions and events, built so nothing you capture ever gets lost.',
                style: _b(13, c: _white.withValues(alpha: 0.6)),
              ),
            ),
            const SizedBox(height: 36),
            Wrap(
              spacing: 64,
              runSpacing: 28,
              children: [
                const _FooterCol(
                  title: 'PRODUCT',
                  links: ['Features', 'Inside the app', 'Pricing'],
                ),
                const _FooterCol(
                  title: 'COMPANY',
                  links: ['Testimonials', 'Field notes', 'Contact'],
                ),
                SizedBox(
                  width: wide ? 320 : double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SUBSCRIBE TO FIELD NOTES',
                          style: _m(10, c: _white.withValues(alpha: 0.7))),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 46,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: _white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Center(
                                child: TextField(
                                  controller: _email,
                                  style: _b(13, c: _white),
                                  cursorColor: _lime,
                                  decoration: InputDecoration(
                                    isCollapsed: true,
                                    border: InputBorder.none,
                                    hintText: 'Enter your email',
                                    hintStyle: _b(13,
                                        c: _white.withValues(alpha: 0.4)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _Pill(
                            _subscribed ? 'DONE' : 'SUBMIT',
                            () {
                              if (_email.text.trim().isNotEmpty) {
                                setState(() => _subscribed = true);
                              }
                            },
                            variant: _PillVariant.lime,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 44),
            Container(height: 1, color: _white.withValues(alpha: 0.1)),
            const SizedBox(height: 20),
            Text('© 2026 Exono Technologies. All rights reserved.',
                style: _b(12, c: _white.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }
}

class _FooterCol extends StatelessWidget {
  final String title;
  final List<String> links;
  const _FooterCol({required this.title, required this.links});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _m(10, c: _white.withValues(alpha: 0.7))),
        const SizedBox(height: 14),
        for (final l in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(l, style: _b(13, c: _white.withValues(alpha: 0.6))),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Menu sheet
// ══════════════════════════════════════════════════════════════════════════════
class _MenuSheet extends StatelessWidget {
  final VoidCallback onGetStarted;
  final void Function(GlobalKey) onLink;
  final Map<String, GlobalKey> links;
  const _MenuSheet(
      {required this.onGetStarted, required this.onLink, required this.links});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _Wordmark(color: _white),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _lime,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child:
                        const Icon(Icons.close_rounded, color: _ink, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            for (final entry in links.entries)
              GestureDetector(
                onTap: () => onLink(entry.value),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      Text(entry.key, style: _m(13, c: _white)),
                      const Spacer(),
                      Icon(Icons.arrow_outward,
                          size: 15, color: _white.withValues(alpha: 0.4)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            _Pill('GET STARTED', onGetStarted,
                variant: _PillVariant.lime, fullWidth: true),
          ],
        ),
      ),
    );
  }
}
