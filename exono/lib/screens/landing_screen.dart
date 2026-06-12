import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/screen_logger.dart';

// ─── Dark navy palette ────────────────────────────────────────────────────────
const _bg    = Color(0xFF010C1C);   // very dark navy canvas
const _card  = Color(0xFF071627);   // card / section surface
const _card2 = Color(0xFF0B1E33);   // slightly raised card
const _bdr   = Color(0x1AFFFFFF);   // 10 % white border
const _text  = Color(0xFFFFFFFF);
const _sub   = Color(0x99FFFFFF);   // 60 % white body text
const _muted = Color(0x55FFFFFF);   // 33 % white muted text
const _blue  = Color(0xFF4478F5);   // bright navy-blue accent
const _blueT = Color(0x1A4478F5);   // blue 10 % tint
const _blueDp = Color(0xFF0F1F4A);  // deep navy (button / header)
const _white = Color(0xFFFFFFFF);
const _amber = Color(0xFFF59E0B);
const _green = Color(0xFF4ADE80);

// ─── Typography ──────────────────────────────────────────────────────────────
TextStyle _d(double sz, {FontWeight w = FontWeight.w800, Color c = _text}) =>
    GoogleFonts.plusJakartaSans(fontSize: sz, fontWeight: w, color: c,
        letterSpacing: -(sz * 0.025), height: 1.06);

TextStyle _b(double sz, {Color c = _sub, FontWeight w = FontWeight.w400}) =>
    GoogleFonts.inter(fontSize: sz, fontWeight: w, color: c, height: 1.65);

TextStyle _mono(double sz, {Color c = _muted}) =>
    GoogleFonts.ibmPlexMono(fontSize: sz, fontWeight: FontWeight.w500, color: c,
        letterSpacing: 0.4);

// ─── Max-width wrapper ────────────────────────────────────────────────────────
class _W extends StatelessWidget {
  final Widget child;
  final double max;
  const _W({required this.child, this.max = 1100});
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: Padding(padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 20), child: child),
      ),
    );
  }
}

// ─── Scroll-reveal (fade + directional slide) ─────────────────────────────────
class _Reveal extends StatefulWidget {
  final Widget child;
  final ScrollController sc;
  final Duration delay;
  final double dy;
  final double dx;
  const _Reveal({required this.child, required this.sc,
      this.delay = Duration.zero, this.dy = 0.06, this.dx = 0});
  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _op;
  late final Animation<Offset> _sl;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _op = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _sl = Tween(begin: Offset(widget.dx, widget.dy), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    widget.sc.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_done || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    if (box.localToGlobal(Offset.zero).dy < MediaQuery.of(context).size.height * 0.94) {
      _done = true;
      Future.delayed(widget.delay, () { if (mounted) _c.forward(); });
    }
  }

  @override
  void dispose() { widget.sc.removeListener(_check); _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _op, child: SlideTransition(position: _sl, child: widget.child));
}

// ─── Hover-lift card ──────────────────────────────────────────────────────────
class _Hover extends StatefulWidget {
  final Widget child;
  const _Hover({required this.child});
  @override
  State<_Hover> createState() => _HoverState();
}

class _HoverState extends State<_Hover> with ScreenLogger {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _h ? -4.0 : 0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Transform.translate(offset: Offset(0, v), child: child),
      child: widget.child,
    ),
  );
}

// ─── Shared button components ─────────────────────────────────────────────────
class _Btn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool small;
  const _Btn(this.label, this.onTap, {this.primary = true, this.small = false});
  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
            horizontal: widget.small ? 18 : 26, vertical: widget.small ? 10 : 14),
        decoration: BoxDecoration(
          color: widget.primary
              ? (_h ? const Color(0xFF5588FF) : _blue)
              : (_h ? _bdr : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          border: widget.primary ? null : Border.all(color: _bdr),
        ),
        child: Text(widget.label,
            style: GoogleFonts.inter(
                fontSize: widget.small ? 13 : 15,
                fontWeight: FontWeight.w600,
                color: _white,
                letterSpacing: -0.1)),
      ),
    ),
  );
}

// ─── Logo mark ────────────────────────────────────────────────────────────────
class _Logo extends StatelessWidget {
  final double size;
  const _Logo({this.size = 28});
  @override
  Widget build(BuildContext context) {
    final sq = size * 0.52;
    final dot = size * 0.18;
    return SizedBox(width: size, height: size,
      child: Stack(alignment: Alignment.center, children: [
        Transform.rotate(angle: 0.785398,
          child: Container(width: sq, height: sq,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(sq * 0.1),
              border: Border.all(color: _blue.withValues(alpha: 0.30), width: 1.5)))),
        Transform.rotate(angle: -0.785398,
          child: Container(width: sq, height: sq,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(sq * 0.1),
              border: Border.all(color: _blue.withValues(alpha: 0.75), width: 1.5)))),
        Container(width: dot, height: dot,
          decoration: BoxDecoration(color: _blue, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.50), blurRadius: 10)])),
      ]),
    );
  }
}

// ─── Mono chip label ──────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: _blueT,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: _blue.withValues(alpha: 0.30)),
    ),
    child: Text(text, style: _mono(11, c: _blue.withValues(alpha: 0.90))),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// NAV
// ═══════════════════════════════════════════════════════════════════════════════
class _Nav extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onCta;
  final VoidCallback onFeatures;
  final VoidCallback onHowItWorks;
  final VoidCallback onPricing;
  const _Nav({required this.onLogin, required this.onCta,
      required this.onFeatures, required this.onHowItWorks, required this.onPricing});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 768;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: _bg.withValues(alpha: 0.85),
            border: Border(bottom: BorderSide(color: _bdr)),
          ),
          child: _W(child: Row(children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const _Logo(size: 24),
              const SizedBox(width: 9),
              Text('Exono', style: GoogleFonts.plusJakartaSans(
                  fontSize: 19, fontWeight: FontWeight.w800, color: _text, letterSpacing: -0.4)),
            ]),
            if (wide) ...[
              const SizedBox(width: 40),
              _NL('Features', onFeatures),
              const SizedBox(width: 28),
              _NL('How it works', onHowItWorks),
              const SizedBox(width: 28),
              _NL('Pricing', onPricing),
            ],
            const Spacer(),
            if (wide) ...[
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(onTap: onLogin,
                    child: Text('Log in', style: _b(14, c: _sub, w: FontWeight.w500))),
              ),
              const SizedBox(width: 12),
            ],
            _Btn('Get started', onCta, small: true),
          ])),
        ),
      ),
    );
  }
}

class _NL extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NL(this.label, this.onTap);
  @override
  State<_NL> createState() => _NLState();
}

class _NLState extends State<_NL> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 120),
          style: _b(14, c: _h ? _white : _sub, w: FontWeight.w500),
          child: Text(widget.label))),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// HERO
// ═══════════════════════════════════════════════════════════════════════════════
class _Hero extends StatefulWidget {
  final VoidCallback onCta;
  final VoidCallback onDemo;
  final ScrollController sc;
  const _Hero({required this.onCta, required this.onDemo, required this.sc});
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<Animation<double>> _fades;
  late final List<Animation<Offset>> _slides;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _fades = List.generate(5, (i) => CurvedAnimation(parent: _c,
        curve: Interval(i * 0.12, (i * 0.12 + 0.50).clamp(0.0, 1.0), curve: Curves.easeOut)));
    _slides = List.generate(5, (i) =>
        Tween(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(
            parent: _c, curve: Interval(i * 0.12, (i * 0.12 + 0.55).clamp(0.0, 1.0), curve: Curves.easeOutCubic))));
    _c.forward();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  Widget _a(int i, Widget child) => FadeTransition(opacity: _fades[i],
      child: SlideTransition(position: _slides[i], child: child));

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 768;
    final h1 = wide ? 72.0 : 48.0;
    return Container(
      color: _bg,
      padding: EdgeInsets.only(top: wide ? 100 : 72, bottom: wide ? 72 : 56),
      child: _W(max: 860,
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          _a(0, const _Chip('Exhibition CRM · Capture · Follow up')),
          SizedBox(height: wide ? 28 : 20),
          _a(1, Text('Never forget\nwho you met.',
              textAlign: TextAlign.center,
              style: _d(h1, w: FontWeight.w900))),
          const SizedBox(height: 20),
          _a(2, ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'Scan any badge or card in under three seconds. Record a voice memo immediately after. Exono structures it, enriches the contact, and follows up for you — before the next flight home.',
              textAlign: TextAlign.center,
              style: _b(17, c: _sub),
            ),
          )),
          const SizedBox(height: 36),
          _a(3, Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
            _Btn('Get started free', widget.onCta),
            _Btn('See how it works', widget.onDemo, primary: false),
          ])),
          const SizedBox(height: 28),
          _a(4, _TrustRow()),
          SizedBox(height: wide ? 64 : 48),
          _a(4, _AppWindow()),
        ]),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = [
      [const Color(0xFF6D9DC5), const Color(0xFF5A8B78)],
      [const Color(0xFFD4A56A), const Color(0xFF9B6B9E)],
      [const Color(0xFF7AC7D4), const Color(0xFF4A90B8)],
      [const Color(0xFFE8A87C), const Color(0xFFD4687E)],
      [const Color(0xFF8FBE8F), const Color(0xFF5A9E6D)],
    ];
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
        width: 28 + 4 * 20.0, height: 28,
        child: Stack(children: List.generate(5, (i) => Positioned(
          left: i * 20.0,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: _bg, width: 2),
              gradient: LinearGradient(colors: colors[i]),
            ),
          ),
        ))),
      ),
      const SizedBox(width: 12),
      Text('10,000+ sales professionals worldwide', style: _b(13, c: _sub, w: FontWeight.w500)),
    ]);
  }
}

// ─── App window mockup ────────────────────────────────────────────────────────
class _AppWindow extends StatefulWidget {
  const _AppWindow();
  @override
  State<_AppWindow> createState() => _AppWindowState();
}

class _AppWindowState extends State<_AppWindow> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  int _activeNav = 1; // 0=Home, 1=Leads, 2=Contacts...

  static const _navItems = [
    (Icons.home_outlined, 'Home', null),
    (Icons.person_search_outlined, 'Leads', '14'),
    (Icons.people_outline, 'Contacts', null),
    (Icons.event_outlined, 'Events', null),
    (Icons.send_outlined, 'Follow-ups', '3'),
    (Icons.bar_chart_rounded, 'Analytics', null),
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 700;
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bdr),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 80, offset: const Offset(0, 32)),
          BoxShadow(color: _blue.withValues(alpha: 0.06), blurRadius: 60, offset: const Offset(0, 20)),
        ],
      ),
      child: Column(children: [
        // ── Browser chrome ─────────────────────────────────────────────────
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: _bdr)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (final c in [const Color(0xFFFF5F57), const Color(0xFFFFBD2E), const Color(0xFF28CA41)])
              Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.8), shape: BoxShape.circle)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _bdr)),
              child: Text('app.exono.ai', style: _mono(10, c: _muted)),
            ),
            const Spacer(),
          ]),
        ),
        // ── App shell ──────────────────────────────────────────────────────
        SizedBox(
          height: wide ? 380 : 420,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (wide) _Sidebar(_navItems, _activeNav, (i) => setState(() => _activeNav = i)),
            Expanded(child: _MainPane(_pulse, _activeNav)),
          ]),
        ),
      ]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<(IconData, String, String?)> items;
  final int active;
  final ValueChanged<int> onTap;
  const _Sidebar(this.items, this.active, this.onTap);

  @override
  Widget build(BuildContext context) => Container(
    width: 172,
    decoration: BoxDecoration(
      color: _bg,
      border: Border(right: BorderSide(color: _bdr)),
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16)),
    ),
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          const _Logo(size: 18),
          const SizedBox(width: 7),
          Text('Exono', style: GoogleFonts.plusJakartaSans(
              fontSize: 14, fontWeight: FontWeight.w800, color: _text, letterSpacing: -0.3)),
        ]),
      ),
      const SizedBox(height: 8),
      ...List.generate(items.length, (i) {
        final (icon, label, badge) = items[i];
        final sel = i == active;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? _blueT : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(icon, size: 15, color: sel ? _blue : _muted),
                const SizedBox(width: 8),
                Expanded(child: Text(label,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500,
                        color: sel ? _blue : _sub))),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(4)),
                    child: Text(badge, style: _mono(9, c: _white)),
                  ),
              ]),
            ),
          ),
        );
      }),
    ]),
  );
}

class _MainPane extends StatelessWidget {
  final AnimationController pulse;
  final int activeNav;
  const _MainPane(this.pulse, this.activeNav);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header row
      Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('DevWorld 2025 · Hall B',
              style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: _text)),
          Text('Day 2 of 3 · Stand 214',
              style: _b(12, c: _muted)),
        ]),
        const Spacer(),
        AnimatedBuilder(
          animation: pulse,
          builder: (_, _) => SizedBox(
            width: 14, height: 14,
            child: Stack(alignment: Alignment.center, children: [
              Transform.scale(
                scale: 1 + pulse.value * 1.8,
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: _green.withValues(alpha: (1 - pulse.value) * 0.5),
                      shape: BoxShape.circle),
                ),
              ),
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
            ]),
          ),
        ),
        const SizedBox(width: 5),
        Text('LIVE', style: _mono(9, c: _green.withValues(alpha: 0.7))),
      ]),
      const SizedBox(height: 14),
      // Quick stats
      Row(children: [
        _MiniStat('14', 'leads today'),
        const SizedBox(width: 8),
        _MiniStat('3', 'follow-ups due'),
        const SizedBox(width: 8),
        _MiniStat('92%', 'capture rate'),
      ]),
      const SizedBox(height: 14),
      // Lead entries
      Expanded(
        child: Column(children: [
          _WinLead('SM', 'Sarah Mitchell', 'Head of Engineering · Stripe',
              '2m ago', 'Hot', const Color(0xFF16A34A), const Color(0xFF166534)),
          const SizedBox(height: 8),
          _WinLead('MW', 'Marcus Webb', 'VP Sales · Notion',
              '18m ago', 'Warm', const Color(0xFFD97706), const Color(0xFF92400E)),
          const SizedBox(height: 8),
          _WinLead('PA', 'Priya Agarwal', 'CTO · Figma',
              '1h ago', 'Warm', _blue, _blueDp),
        ]),
      ),
      const SizedBox(height: 12),
      // Scan button
      Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.qr_code_scanner_rounded, color: _white, size: 14),
          const SizedBox(width: 7),
          Text('Scan new lead', style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: _white)),
        ]),
      ),
    ]),
  );
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: GoogleFonts.plusJakartaSans(
          fontSize: 15, fontWeight: FontWeight.w800, color: _blue, height: 1)),
      Text(label, style: _mono(9, c: _muted)),
    ]),
  );
}

class _WinLead extends StatelessWidget {
  final String initials;
  final String name;
  final String role;
  final String time;
  final String tag;
  final Color tagFg;
  final Color tagBg;
  const _WinLead(this.initials, this.name, this.role, this.time, this.tag, this.tagFg, this.tagBg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _bdr)),
    child: Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(7)),
        alignment: Alignment.center,
        child: Text(initials, style: GoogleFonts.inter(
            fontSize: 10, fontWeight: FontWeight.w700, color: tagFg.withValues(alpha: 0.90))),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _text)),
        Text(role, style: _b(11, c: _muted), overflow: TextOverflow.ellipsis),
      ])),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(time, style: _mono(9, c: _muted)),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
              color: tagFg.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
          child: Text(tag, style: _mono(9, c: tagFg.withValues(alpha: 0.85))),
        ),
      ]),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVENT TICKER MARQUEE
// ═══════════════════════════════════════════════════════════════════════════════
class _Marquee extends StatefulWidget {
  const _Marquee();
  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  static const _events = [
    'SaaStr Annual · San Francisco',
    'DevWorld 2025 · Berlin',
    'Money20/20 · Amsterdam',
    'Web Summit · Lisbon',
    'TechExpo APAC · Singapore',
    'CES 2026 · Las Vegas',
    'Dreamforce · San Francisco',
    'Slush · Helsinki',
    'TNW Conference · Amsterdam',
    'GITEX Global · Dubai',
  ];

  static const _itemW = 248.0;
  static const _totalW = 2480.0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 55000))..repeat();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
    color: _card,
    child: Column(children: [
      Container(height: 1, color: _bdr),
      const SizedBox(height: 16),
      ClipRect(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Transform.translate(
            offset: Offset(-_c.value * _totalW, 0),
            child: Row(children: [
              ..._events.map((e) => _TickerChip(e)),
              ..._events.map((e) => _TickerChip(e)),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Container(height: 1, color: _bdr),
    ]),
  );
}

class _TickerChip extends StatelessWidget {
  final String text;
  const _TickerChip(this.text);
  @override
  Widget build(BuildContext context) => SizedBox(
    width: _MarqueeState._itemW,
    child: Row(children: [
      Container(width: 4, height: 4,
          decoration: BoxDecoration(color: _blue.withValues(alpha: 0.4), shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: _b(13, c: _muted, w: FontWeight.w500),
          overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 12),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// PHILOSOPHY / INTRO
// ═══════════════════════════════════════════════════════════════════════════════
class _Philosophy extends StatelessWidget {
  final ScrollController sc;
  const _Philosophy({required this.sc});
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 768;
    return Container(
      color: _bg,
      padding: EdgeInsets.symmetric(vertical: wide ? 96 : 72),
      child: _W(max: 760,
        child: _Reveal(sc: sc,
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const _Chip('Why Exono'),
            const SizedBox(height: 36),
            Text(
              '"Every deal starts with a conversation on the exhibition floor. Most of them die on the plane home — buried under 80 business cards, half-remembered names, and follow-up emails that never get sent."',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: wide ? 24 : 19, fontWeight: FontWeight.w500,
                  color: _text, height: 1.55, letterSpacing: -0.5),
            ),
            const SizedBox(height: 36),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  color: _card, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _bdr)),
              child: Text(
                'Exono exists to close that gap. One tool, built for the field.',
                textAlign: TextAlign.center,
                style: _b(15, c: _sub, w: FontWeight.w500),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURES — tab switcher
// ═══════════════════════════════════════════════════════════════════════════════
class _Features extends StatefulWidget {
  final GlobalKey sectionKey;
  final ScrollController sc;
  const _Features({required this.sectionKey, required this.sc});
  @override
  State<_Features> createState() => _FeaturesState();
}

class _FeaturesState extends State<_Features> {
  int _active = 0;
  Timer? _timer;

  static const _tabs = [
    _FTab('01', 'Instant capture',
        'Point at any badge, QR code, or business card. Read in under three seconds. Works offline on the exhibition floor.',
        Icons.document_scanner_outlined),
    _FTab('02', 'Voice memory',
        'Speak your notes right after meeting someone. "Interested in our enterprise tier, follow up Q1, mention the Amsterdam event." Exono transcribes and structures it.',
        Icons.mic_none_rounded),
    _FTab('03', 'Auto-enrichment',
        'Exono pulls company news, role history, and funding context automatically. You arrive at the follow-up already briefed.',
        Icons.auto_awesome_outlined),
    _FTab('04', 'Smart follow-ups',
        'At exactly the right moment, Exono surfaces the lead with a suggested message written from your notes. One tap to personalise, one tap to send.',
        Icons.send_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4),
        (_) { if (mounted) setState(() => _active = (_active + 1) % _tabs.length); });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    return Container(
      key: widget.sectionKey,
      color: _card,
      padding: EdgeInsets.symmetric(vertical: wide ? 96 : 72),
      child: _W(
        child: Column(children: [
          _Reveal(sc: widget.sc,
            child: Column(children: [
              const _Chip('Core features'),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text('One platform to run your\nentire exhibition pipeline.',
                    textAlign: TextAlign.center, style: _d(wide ? 42 : 34, w: FontWeight.w800)),
              ),
              const SizedBox(height: 12),
              Text(
                'Everything you need to capture, enrich, and follow up — without switching tools.',
                textAlign: TextAlign.center, style: _b(16, c: _sub),
              ),
            ]),
          ),
          const SizedBox(height: 52),
          _Reveal(sc: widget.sc,
            child: wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: 240,
                      child: Column(children: List.generate(_tabs.length, (i) =>
                          _FTabItem(_tabs[i], i, _active, () {
                            setState(() => _active = i);
                            _timer?.cancel();
                          }))),
                    ),
                    const SizedBox(width: 40),
                    Expanded(child: _FTabPanel(_tabs[_active], _active)),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    ...List.generate(_tabs.length, (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FMobileCard(_tabs[i]),
                    )),
                  ]),
          ),
        ]),
      ),
    );
  }
}

class _FTab {
  final String num;
  final String title;
  final String body;
  final IconData icon;
  const _FTab(this.num, this.title, this.body, this.icon);
}

class _FTabItem extends StatefulWidget {
  final _FTab tab;
  final int index;
  final int active;
  final VoidCallback onTap;
  const _FTabItem(this.tab, this.index, this.active, this.onTap);
  @override
  State<_FTabItem> createState() => _FTabItemState();
}

class _FTabItemState extends State<_FTabItem> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final sel = widget.index == widget.active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: sel ? _blueT : (_h ? _bdr : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: sel ? Border.all(color: _blue.withValues(alpha: 0.30)) : null,
          ),
          child: Row(children: [
            Text(widget.tab.num, style: _mono(10, c: sel ? _blue.withValues(alpha: 0.60) : _muted)),
            const SizedBox(width: 10),
            Text(widget.tab.title,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600,
                    color: sel ? _blue : _sub)),
          ]),
        ),
      ),
    );
  }
}

class _FTabPanel extends StatelessWidget {
  final _FTab tab;
  final int idx;
  const _FTabPanel(this.tab, this.idx);
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 350),
    switchInCurve: Curves.easeOutCubic,
    transitionBuilder: (child, anim) => FadeTransition(opacity: anim,
        child: SlideTransition(
            position: Tween(begin: const Offset(0.03, 0), end: Offset.zero).animate(anim),
            child: child)),
    child: Container(
      key: ValueKey(idx),
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: _blueT, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _blue.withValues(alpha: 0.20))),
          child: Icon(tab.icon, color: _blue, size: 26),
        ),
        const SizedBox(height: 22),
        Text(tab.title, style: _d(26, w: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(tab.body, style: _b(16, c: _sub)),
      ]),
    ),
  );
}

class _FMobileCard extends StatelessWidget {
  final _FTab tab;
  const _FMobileCard(this.tab);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _bdr)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36,
        decoration: BoxDecoration(color: _blueT, borderRadius: BorderRadius.circular(10)),
        child: Icon(tab.icon, color: _blue, size: 18)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(tab.num, style: _mono(10, c: _muted)),
          const SizedBox(width: 8),
          Text(tab.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _text)),
        ]),
        const SizedBox(height: 6),
        Text(tab.body, style: _b(13, c: _sub)),
      ])),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// FEATURE STRIPS — alternating, Fora "what you get" style
// ═══════════════════════════════════════════════════════════════════════════════
class _Strips extends StatelessWidget {
  final ScrollController sc;
  const _Strips({required this.sc});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    return Container(
      color: _bg,
      child: Column(children: [
        _Strip(
          sc: sc, wide: wide, reverse: false,
          chip: 'Your front door',
          title: 'A capture flow built\nfor the exhibition floor.',
          body: 'No fumbling with apps mid-conversation. Open Exono, point your camera, tap once. The contact profile appears in seconds — with company, role, and email already filled in.',
          points: const ['Works on printed cards and digital badges', 'Offline-first — no exhibition WiFi required', 'Duplicate detection across your whole team'],
          visual: const _ScanVisual(),
        ),
        Container(height: 1, color: _bdr),
        _Strip(
          sc: sc, wide: wide, reverse: true,
          chip: 'Capture context',
          title: 'Your voice, structured\nautomatically.',
          body: 'Walk away from the stand, hit record. Talk for 30 seconds. Exono transcribes your words, tags topics, and links the memo to the contact — so nothing gets lost between the show floor and your desk.',
          points: const ['Instant transcription in 30+ languages', 'Auto-tagged: budget, timeline, interest, follow-up', 'Attached to the contact within seconds'],
          visual: const _VoiceVisual(),
        ),
        Container(height: 1, color: _bdr),
        _Strip(
          sc: sc, wide: wide, reverse: false,
          chip: 'Close the loop',
          title: 'The follow-up writes\nitself.',
          body: 'At the right moment — a day, a week, a quarter later — Exono surfaces the lead with a suggested message drawn from your own notes. It sounds like you, because it is your words.',
          points: const ['Timing based on what you said in the memo', 'Draft uses your exact language and context', 'One tap to edit and send from your email client'],
          visual: const _FollowUpVisual(),
        ),
      ]),
    );
  }
}

class _Strip extends StatelessWidget {
  final ScrollController sc;
  final bool wide;
  final bool reverse;
  final String chip;
  final String title;
  final String body;
  final List<String> points;
  final Widget visual;
  const _Strip({required this.sc, required this.wide, required this.reverse,
      required this.chip, required this.title, required this.body,
      required this.points, required this.visual});

  @override
  Widget build(BuildContext context) {
    final textSide = _Reveal(
      sc: sc, dx: reverse ? 0.05 : -0.05, dy: 0,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Chip(chip),
        const SizedBox(height: 20),
        Text(title, style: _d(30, w: FontWeight.w800)),
        const SizedBox(height: 14),
        Text(body, style: _b(16, c: _sub)),
        const SizedBox(height: 20),
        ...points.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 18, height: 18, margin: const EdgeInsets.only(top: 2),
              decoration: const BoxDecoration(color: _blueT, shape: BoxShape.circle),
              child: Icon(Icons.check, color: _blue, size: 11)),
            const SizedBox(width: 10),
            Expanded(child: Text(p, style: _b(14, c: _sub))),
          ]),
        )),
      ]),
    );
    final vizSide = _Reveal(
      sc: sc, dx: reverse ? -0.05 : 0.05, dy: 0,
      delay: const Duration(milliseconds: 80),
      child: visual,
    );
    return Container(
      padding: EdgeInsets.symmetric(vertical: wide ? 80 : 60),
      child: _W(
        child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: reverse
                ? [Expanded(child: vizSide), const SizedBox(width: 72), Expanded(child: textSide)]
                : [Expanded(child: textSide), const SizedBox(width: 72), Expanded(child: vizSide)])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                textSide,
                const SizedBox(height: 40),
                vizSide,
              ]),
      ),
    );
  }
}

// ─── Strip visuals ────────────────────────────────────────────────────────────
class _ScanVisual extends StatelessWidget {
  const _ScanVisual();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: _blueT, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.document_scanner_outlined, color: _blue, size: 16)),
        const SizedBox(width: 10),
        Text('Scanning card...', style: _mono(11, c: _blue)),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(color: _green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
          child: Text('LIVE', style: _mono(9, c: _green))),
      ]),
      const SizedBox(height: 16),
      Container(height: 80, decoration: BoxDecoration(
        color: _card2, borderRadius: BorderRadius.circular(10), border: Border.all(color: _bdr))),
      const SizedBox(height: 16),
      _ExtractRow('Name', 'Sarah Mitchell'),
      _ExtractRow('Role', 'Head of Engineering'),
      _ExtractRow('Company', 'Stripe'),
      _ExtractRow('Email', 'sarah@stripe.com'),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.center,
        child: Text('Save contact', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _white)),
      ),
    ]),
  );
}

class _ExtractRow extends StatelessWidget {
  final String label;
  final String value;
  const _ExtractRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 70, child: Text(label, style: _mono(10, c: _muted))),
      Expanded(child: Text(value, style: _b(13, c: _text, w: FontWeight.w500))),
    ]),
  );
}

class _VoiceVisual extends StatefulWidget {
  const _VoiceVisual();
  @override
  State<_VoiceVisual> createState() => _VoiceVisualState();
}

class _VoiceVisualState extends State<_VoiceVisual> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.1 + _c.value * 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: _blue.withValues(alpha: 0.3 + _c.value * 0.2))),
            child: const Icon(Icons.mic, color: _blue, size: 16)),
        ),
        const SizedBox(width: 10),
        Text('Recording memo...', style: _mono(11, c: _blue)),
        const Spacer(),
        Text('0:23', style: _mono(11, c: _muted)),
      ]),
      const SizedBox(height: 16),
      // Waveform
      AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(20, (i) {
            final h = 8 + (i % 5 + 1) * 6.0 * (0.6 + _c.value * 0.4);
            return Container(width: 4, height: h.clamp(8, 40),
                decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.5 + (i % 3) * 0.17),
                    borderRadius: BorderRadius.circular(2)));
          }),
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _bdr)),
        child: Text(
          '"...interested in our enterprise tier, budget approved for Q1, said to ping her EA to schedule — mention the Amsterdam summit..."',
          style: _b(12, c: _sub),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        _TagChip('Enterprise', _blue),
        const SizedBox(width: 6),
        _TagChip('Q1', _blue),
        const SizedBox(width: 6),
        _TagChip('Follow-up', _blue),
      ]),
    ]),
  );
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color c;
  const _TagChip(this.label, this.c);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
    child: Text(label, style: _mono(9, c: c.withValues(alpha: 0.80))),
  );
}

class _FollowUpVisual extends StatelessWidget {
  const _FollowUpVisual();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 30, height: 30,
          decoration: BoxDecoration(color: _blueT, shape: BoxShape.circle),
          child: const Icon(Icons.auto_awesome, color: _blue, size: 14)),
        const SizedBox(width: 10),
        Text('Suggested follow-up', style: _mono(11, c: _blue)),
        const Spacer(),
        _TagChip('3 days later', _muted.withValues(alpha: 0.4)),
      ]),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _bdr)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('To: Sarah Mitchell · sarah@stripe.com', style: _mono(10, c: _muted)),
          const SizedBox(height: 8),
          Container(height: 1, color: _bdr),
          const SizedBox(height: 8),
          Text(
            'Hi Sarah,\n\nGreat meeting you at DevWorld. Following up on our chat about the enterprise tier — Q1 fits our timeline well.\n\nWould a 30-minute intro call work this week?',
            style: _b(12, c: _sub),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Text('Send', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _white)),
        )),
        const SizedBox(width: 8),
        Expanded(child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _bdr)),
          alignment: Alignment.center,
          child: Text('Edit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: _sub)),
        )),
      ]),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATS STRIP — animated countup
// ═══════════════════════════════════════════════════════════════════════════════
class _SI {
  final int end;
  final String suffix;
  final String label;
  final bool tenths;
  const _SI(this.end, this.suffix, this.label, {this.tenths = false});
}

class _Stats extends StatelessWidget {
  final ScrollController sc;
  const _Stats({required this.sc});

  static const _items = [
    _SI(50, 'K+', 'Contacts captured\nacross exhibitions'),
    _SI(10, '+', 'Events per sales team\nper year on average'),
    _SI(68, '%', 'More follow-ups done\nwithin 30 days'),
    _SI(48, '★', 'Average app rating\nfrom sales teams', tenths: true),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 768;
    return Container(
      color: _card,
      padding: EdgeInsets.symmetric(vertical: wide ? 72 : 56),
      child: _W(
        child: wide
            ? Row(children: List.generate(_items.length, (i) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _CountStat(item: _items[i], index: i, sc: sc),
                ))))
            : GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.6,
                children: List.generate(_items.length, (i) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: _CountStat(item: _items[i], index: i, sc: sc),
                )),
              ),
      ),
    );
  }
}

class _CountStat extends StatefulWidget {
  final _SI item;
  final int index;
  final ScrollController sc;
  const _CountStat({required this.item, required this.index, required this.sc});
  @override
  State<_CountStat> createState() => _CountStatState();
}

class _CountStatState extends State<_CountStat> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<int> _count;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _count = IntTween(begin: 0, end: widget.item.end)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    widget.sc.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_done || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    if (box.localToGlobal(Offset.zero).dy < MediaQuery.of(context).size.height * 0.92) {
      _done = true;
      final delay = Duration(milliseconds: widget.index * 120);
      Future.delayed(delay, () { if (mounted) _c.forward(); });
    }
  }

  @override
  void dispose() { widget.sc.removeListener(_check); _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final left = widget.index > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: left
          ? BoxDecoration(border: Border(left: BorderSide(color: _bdr, width: 1)))
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedBuilder(
          animation: _count,
          builder: (_, _) {
            final n = _count.value;
            final display = widget.item.tenths
                ? '${n ~/ 10}.${n % 10}${widget.item.suffix}'
                : '$n${widget.item.suffix}';
            return Text(display, style: _d(44, w: FontWeight.w900, c: _blue));
          },
        ),
        const SizedBox(height: 6),
        Text(widget.item.label, style: _b(13, c: _sub)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTIMONIALS
// ═══════════════════════════════════════════════════════════════════════════════
class _Testimonials extends StatefulWidget {
  final GlobalKey sectionKey;
  final ScrollController sc;
  const _Testimonials({required this.sectionKey, required this.sc});
  @override
  State<_Testimonials> createState() => _TestimonialsState();
}

class _TestimonialsState extends State<_Testimonials> {
  int _i = 0;

  static const _quotes = [
    _Quote(
      '"I used to come back from exhibitions with 80 cards and follow up on maybe five. With Exono I actually remembered every conversation — and closed three deals the following month."',
      'James Thornton', 'Head of Sales · Meridian Software',
    ),
    _Quote(
      '"The voice memo feature is the thing. Record your thoughts right after a meeting, and by the next morning you have a full profile with suggested follow-up copy. It just works."',
      'Priya Rajan', 'Founder · Stackwise',
    ),
    _Quote(
      '"We went from a 12% follow-up rate post-event to over 70% in one quarter. The AI-suggested messages actually sound like me, not a template."',
      'Carlos Mendes', 'Partnerships · Arc Systems',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 768;
    return Container(
      key: widget.sectionKey,
      color: _bg,
      padding: EdgeInsets.symmetric(vertical: wide ? 96 : 72),
      child: _W(max: 860,
        child: _Reveal(sc: widget.sc,
          child: Column(children: [
            const _Chip('Testimonials'),
            const SizedBox(height: 48),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Container(
                key: ValueKey(_i),
                padding: EdgeInsets.all(wide ? 44 : 28),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _bdr),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: List.generate(5, (_) =>
                      Icon(Icons.star_rounded, color: _amber, size: 16))),
                  const SizedBox(height: 20),
                  Text(_quotes[_i].quote,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: wide ? 21 : 17, fontWeight: FontWeight.w500,
                          color: _text, height: 1.55, letterSpacing: -0.3)),
                  const SizedBox(height: 28),
                  Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: _blueT, borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _blue.withValues(alpha: 0.20))),
                      alignment: Alignment.center,
                      child: Text(
                        _quotes[_i].name.split(' ').map((w) => w[0]).take(2).join(),
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _blue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_quotes[_i].name,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _text)),
                      Text(_quotes[_i].role, style: _b(12, c: _muted)),
                    ]),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ...List.generate(_quotes.length, (i) => GestureDetector(
                onTap: () => setState(() => _i = i),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _i ? 24 : 8, height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _i ? _blue : _bdr,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              )),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Quote {
  final String quote;
  final String name;
  final String role;
  const _Quote(this.quote, this.name, this.role);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRICING
// ═══════════════════════════════════════════════════════════════════════════════
class _Pricing extends StatelessWidget {
  final GlobalKey sectionKey;
  final VoidCallback onCta;
  final ScrollController sc;
  const _Pricing({required this.sectionKey, required this.onCta, required this.sc});

  static const _plans = [
    _Plan('Starter', 'Free forever', 'For individuals and small teams just getting started.',
        ['Up to 3 exhibitions per year', '200 contacts', 'Card & badge scanning', 'Voice memos', 'Basic follow-up reminders'],
        false),
    _Plan('Growth', '\$49 / month', 'For sales teams who go to exhibitions regularly.',
        ['Unlimited exhibitions', '2,000 contacts', 'Everything in Starter', 'AI auto-enrichment', 'Smart follow-up drafts', 'Team collaboration'],
        true),
    _Plan('Teams', '\$149 / month', 'For larger orgs that need control and reporting.',
        ['Unlimited everything', 'Everything in Growth', 'Admin dashboard', 'CRM integrations', 'Priority support', 'Onboarding call'],
        false),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    return Container(
      key: sectionKey,
      color: _card,
      padding: EdgeInsets.symmetric(vertical: wide ? 96 : 72),
      child: _W(
        child: Column(children: [
          _Reveal(sc: sc,
            child: Column(children: [
              const _Chip('Pricing'),
              const SizedBox(height: 20),
              Text('Clear pricing that scales with you.',
                  textAlign: TextAlign.center, style: _d(wide ? 40 : 32, w: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 48),
          _Reveal(sc: sc,
            child: wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children:
                    List.generate(_plans.length, (i) => Expanded(child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: i == 1 ? 0 : 8),
                      child: _Hover(child: _PlanCard(_plans[i], onCta,
                          margin: i == 1 ? const EdgeInsets.symmetric(vertical: 0) : const EdgeInsets.only(top: 16))),
                    ))))
                : Column(children: List.generate(_plans.length, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _PlanCard(_plans[i], onCta)))),
          ),
        ]),
      ),
    );
  }
}

class _Plan {
  final String name;
  final String price;
  final String desc;
  final List<String> features;
  final bool featured;
  const _Plan(this.name, this.price, this.desc, this.features, this.featured);
}

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final VoidCallback onCta;
  final EdgeInsets margin;
  const _PlanCard(this.plan, this.onCta, {this.margin = EdgeInsets.zero});
  @override
  Widget build(BuildContext context) => Container(
    margin: margin,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: plan.featured ? _blueDp : _card2,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: plan.featured ? _blue.withValues(alpha: 0.40) : _bdr, width: plan.featured ? 1.5 : 1),
      boxShadow: plan.featured ? [BoxShadow(color: _blue.withValues(alpha: 0.15), blurRadius: 40)] : null,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (plan.featured)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(5)),
            child: Text('Most popular', style: _mono(9, c: _white)),
          ),
        ),
      Text(plan.name, style: _d(18, w: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(plan.price, style: GoogleFonts.plusJakartaSans(
          fontSize: 28, fontWeight: FontWeight.w900, color: plan.featured ? _white : _blue, letterSpacing: -1)),
      const SizedBox(height: 8),
      Text(plan.desc, style: _b(13, c: _sub)),
      const SizedBox(height: 20),
      Container(height: 1, color: _bdr),
      const SizedBox(height: 16),
      ...plan.features.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 16, height: 16, margin: const EdgeInsets.only(top: 1),
            decoration: const BoxDecoration(color: _blueT, shape: BoxShape.circle),
            child: Icon(Icons.check, color: _blue, size: 10)),
          const SizedBox(width: 10),
          Expanded(child: Text(f, style: _b(13, c: _sub))),
        ]),
      )),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: onCta,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: plan.featured ? _blue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: plan.featured ? null : Border.all(color: _bdr),
          ),
          alignment: Alignment.center,
          child: Text(plan.featured ? 'Get started' : 'Get started free',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _white)),
        ),
      ),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// FAQ
// ═══════════════════════════════════════════════════════════════════════════════
class _FAQ extends StatefulWidget {
  final ScrollController sc;
  const _FAQ({required this.sc});
  @override
  State<_FAQ> createState() => _FAQState();
}

class _FAQState extends State<_FAQ> {
  int? _open;

  static const _items = [
    _FQ('Does it work offline at exhibitions?',
        'Yes. Card scanning and voice memo recording work fully offline. Everything syncs automatically when you reconnect — usually before you leave the hall.'),
    _FQ('How does the AI enrichment work?',
        'After you capture a contact, Exono searches public sources — LinkedIn, company websites, news — and adds role history, company context, and recent news to the profile. It takes about 30–60 seconds after capture.'),
    _FQ('Can my whole team use it at the same event?',
        'Yes. On Growth and Teams plans, everyone on your team can capture leads at the same exhibition, and duplicates are automatically detected and merged.'),
    _FQ('Does it integrate with our CRM?',
        'Exono syncs with Salesforce, HubSpot, and Pipedrive on the Teams plan. You can also export contacts at any time in CSV or vCard format.'),
    _FQ('What happens to my data?',
        'Your contacts and notes are private to your account. Exono never uses your data for training AI models. You can export or delete everything at any time.'),
    _FQ('Is there a limit on how many events I can attend?',
        'Starter accounts get up to 3 exhibitions per year. Growth and Teams plans are unlimited — use it at every trade show, conference, and networking event you attend.'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 768;
    return Container(
      color: _bg,
      padding: EdgeInsets.symmetric(vertical: wide ? 96 : 72),
      child: _W(max: 760,
        child: Column(children: [
          _Reveal(sc: widget.sc,
            child: Column(children: [
              const _Chip('FAQ'),
              const SizedBox(height: 20),
              Text('Answers to the questions\nthat come up most.',
                  textAlign: TextAlign.center, style: _d(wide ? 38 : 30, w: FontWeight.w800)),
            ]),
          ),
          const SizedBox(height: 48),
          _Reveal(sc: widget.sc,
            child: Column(
              children: List.generate(_items.length, (i) => _FAQItem(
                _items[i], i, _open == i,
                () => setState(() => _open = _open == i ? null : i),
              )),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FQ {
  final String q;
  final String a;
  const _FQ(this.q, this.a);
}

class _FAQItem extends StatelessWidget {
  final _FQ item;
  final int index;
  final bool open;
  final VoidCallback onTap;
  const _FAQItem(this.item, this.index, this.open, this.onTap);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: open ? _card : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: open ? _blue.withValues(alpha: 0.25) : _bdr),
    ),
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Expanded(child: Text(item.q,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _text))),
              const SizedBox(width: 16),
              AnimatedRotation(
                turns: open ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.add, color: open ? _blue : _muted, size: 20),
              ),
            ]),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(item.a, style: _b(14, c: _sub)),
            ),
            crossFadeState: open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ]),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// CTA BANNER
// ═══════════════════════════════════════════════════════════════════════════════
class _CtaBanner extends StatelessWidget {
  final VoidCallback onCta;
  final ScrollController sc;
  const _CtaBanner({required this.onCta, required this.sc});
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 768;
    return Container(
      color: _card,
      padding: EdgeInsets.symmetric(vertical: wide ? 96 : 72),
      child: _W(max: 680,
        child: _Reveal(sc: sc,
          child: Column(children: [
            const _Chip('Get started today'),
            const SizedBox(height: 24),
            Text('Ready to remember\neveryone you meet?',
                textAlign: TextAlign.center,
                style: _d(wide ? 52 : 40, w: FontWeight.w900)),
            const SizedBox(height: 16),
            Text(
              'Join thousands of sales teams who close more by following up on every lead from every exhibition.',
              textAlign: TextAlign.center, style: _b(17, c: _sub),
            ),
            const SizedBox(height: 36),
            _Btn('Get started free — takes 2 minutes', onCta),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FOOTER
// ═══════════════════════════════════════════════════════════════════════════════
class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 768;
    return Container(
      color: _bg,
      child: Column(children: [
        Container(height: 1, color: _bdr),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 36, horizontal: wide ? 48 : 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FooterBrand(),
                      const Spacer(),
                      _FooterCol('Product', ['Features', 'How it works', 'Pricing', 'Changelog']),
                      const SizedBox(width: 48),
                      _FooterCol('Company', ['About', 'Blog', 'Careers', 'Contact']),
                      const SizedBox(width: 48),
                      _FooterCol('Legal', ['Privacy', 'Terms', 'Security']),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FooterBrand(),
                      const SizedBox(height: 32),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: _FooterCol('Product', ['Features', 'Pricing'])),
                        Expanded(child: _FooterCol('Company', ['About', 'Blog'])),
                        Expanded(child: _FooterCol('Legal', ['Privacy', 'Terms'])),
                      ]),
                    ]),
            ),
          ),
        ),
        Container(height: 1, color: _bdr),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Text('© 2025 Exono. All rights reserved.', style: _b(13, c: _muted)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _FooterBrand extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisSize: MainAxisSize.min, children: [
      const _Logo(size: 20),
      const SizedBox(width: 8),
      Text('Exono', style: GoogleFonts.plusJakartaSans(
          fontSize: 16, fontWeight: FontWeight.w800, color: _text, letterSpacing: -0.3)),
    ]),
    const SizedBox(height: 6),
    Text('Intelligent CRM for the exhibition floor.', style: _b(13, c: _muted)),
  ]);
}

class _FooterCol extends StatelessWidget {
  final String heading;
  final List<String> links;
  const _FooterCol(this.heading, this.links);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(heading, style: _mono(12, c: _sub.withValues(alpha: 0.7))),
    const SizedBox(height: 14),
    ...links.map((l) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MouseRegion(cursor: SystemMouseCursors.click,
          child: Text(l, style: _b(13, c: _muted, w: FontWeight.w500))),
    )),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// LANDING SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _sc = ScrollController();
  final _featuresKey = GlobalKey();
  final _howKey = GlobalKey();
  final _pricingKey = GlobalKey();

  void _goAuth() => context.go('/auth');

  void _scrollTo(GlobalKey k) {
    final ctx = k.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
        alignment: 0.06);
  }

  @override
  void dispose() { _sc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(children: [
          SingleChildScrollView(
            controller: _sc,
            child: Column(children: [
              const SizedBox(height: 68),
              _Hero(onCta: _goAuth, onDemo: () => _scrollTo(_howKey), sc: _sc),
              const _Marquee(),
              _Philosophy(sc: _sc),
              _Features(sectionKey: _howKey, sc: _sc),
              _Strips(sc: _sc),
              _Stats(sc: _sc),
              _Testimonials(sectionKey: _featuresKey, sc: _sc),
              _Pricing(sectionKey: _pricingKey, onCta: _goAuth, sc: _sc),
              _FAQ(sc: _sc),
              _CtaBanner(onCta: _goAuth, sc: _sc),
              _Footer(),
            ]),
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: _Nav(
              onLogin: _goAuth,
              onCta: _goAuth,
              onFeatures: () => _scrollTo(_featuresKey),
              onHowItWorks: () => _scrollTo(_howKey),
              onPricing: () => _scrollTo(_pricingKey),
            ),
          ),
        ]),
      ),
    );
  }
}
