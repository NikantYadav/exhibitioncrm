import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/screen_logger.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Fora landing page replica — rebuilt in Flutter from the Framer export.
// Design tokens (colors, fonts, copy, layout) extracted from the published
// HTML: Inter + Fragment Mono, true-black canvas, and the signature hero
// radial gradient  #1b2228 → #353f44 → #d39794.
// ═════════════════════════════════════════════════════════════════════════════

// ─── Palette (Framer tokens) ─────────────────────────────────────────────────
const _black = Color(0xFF000000); // page canvas
const _white = Color(0xFFFFFFFF);
const _w80 = Color(0xCCFFFFFF); //  #fffc      — primary body text
const _w65 = Color(0xA6FFFFFF); //  #ffffffa6  — secondary text
const _w40 = Color(0x66FFFFFF); //              — muted text
const _w25 = Color(0x40FFFFFF); //  #ffffff40  — faint text / strokes
const _w10 = Color(0x1AFFFFFF); //  #ffffff1a  — hairline borders
const _w06 = Color(0x0FFFFFFF); //              — faint borders
const _w05 = Color(0x0DFFFFFF); //  rgba(255,255,255,.05) — card surfaces
const _ink = Color(0xFF1B2228); //  hero gradient start
const _slate = Color(0xFF353F44); // hero gradient mid
const _salmon = Color(0xFFD39794); // hero gradient end / accent
const _teal = Color(0xFF177275); //  brand accent
const _cream = Color(0xFFFFF3F0); // warm light accent
const _panel = Color(0xFF0F0F0F); // app-mockup surface

// ─── Typography ──────────────────────────────────────────────────────────────
TextStyle _t(double size,
        {FontWeight w = FontWeight.w400, Color c = _white, double? h, double? ls}) =>
    GoogleFonts.inter(
        fontSize: size, fontWeight: w, color: c, height: h, letterSpacing: ls);

TextStyle _mono(double size, {Color c = _cream, double ls = 1.6}) =>
    GoogleFonts.fragmentMono(fontSize: size, color: c, letterSpacing: ls);

TextStyle _display(double size, {Color c = _white}) =>
    _t(size, w: FontWeight.w600, c: c, h: 1.08, ls: size * -0.03);

const double _kMaxW = 1200;

bool _mob(BuildContext context) => MediaQuery.sizeOf(context).width < 760;

// ═════════════════════════════════════════════════════════════════════════════
// Shared primitives
// ═════════════════════════════════════════════════════════════════════════════

/// Centers content at the page max-width with horizontal gutters.
class _Section extends StatelessWidget {
  const _Section({required this.child, this.maxWidth = _kMaxW});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _mob(context) ? 20 : 32),
          child: child,
        ),
      ),
    );
  }
}

/// Hover-state builder (web/desktop) — powers the Framer-like hover polish.
class _Hover extends StatefulWidget {
  const _Hover({required this.builder});
  final Widget Function(BuildContext context, bool hovered) builder;

  @override
  State<_Hover> createState() => _HoverState();
}

class _HoverState extends State<_Hover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(context, _hovered),
    );
  }
}

/// Scroll-triggered entrance: fade + rise, once, like Framer's appear effects.
class _Reveal extends StatefulWidget {
  const _Reveal({required this.sc, required this.child, this.delayMs = 0});
  final ScrollController sc;
  final Widget child;
  final int delayMs;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 750));
  late final Animation<double> _anim =
      CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic);
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    widget.sc.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_shown || !mounted) {
      return;
    }
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) {
      return;
    }
    final top = ro.localToGlobal(Offset.zero).dy;
    final vh = MediaQuery.sizeOf(context).height;
    if (top < vh * 0.92) {
      _shown = true;
      widget.sc.removeListener(_check);
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) {
          _ac.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.sc.removeListener(_check);
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final v = _anim.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 28 * (1 - v)), child: child),
        );
      },
      child: widget.child,
    );
  }
}

enum _BtnKind { filled, outline, ghost }

/// Rounded-pill button (radius 100px in the source).
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    this.kind = _BtnKind.filled,
    this.big = false,
  });
  final String label;
  final VoidCallback onTap;
  final _BtnKind kind;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return _Hover(
      builder: (context, hovered) {
        Color bg;
        Color fg;
        Border? border;
        switch (kind) {
          case _BtnKind.filled:
            bg = hovered ? _cream : _white;
            fg = _black;
            border = null;
          case _BtnKind.outline:
            bg = hovered ? _w10 : _w05;
            fg = _white;
            border = Border.all(color: _w10);
          case _BtnKind.ghost:
            bg = hovered ? _w05 : const Color(0x00000000);
            fg = hovered ? _white : _w80;
            border = null;
        }
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
                horizontal: big ? 28 : 18, vertical: big ? 15 : 10),
            decoration: BoxDecoration(
              color: bg,
              border: border,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(label,
                style: _t(big ? 16 : 14, w: FontWeight.w600, c: fg, ls: -0.2)),
          ),
        );
      },
    );
  }
}

/// Small mono uppercase section tag chip (Fragment Mono).
class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _w05,
        border: Border.all(color: _w10),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(text.toUpperCase(), style: _mono(11, c: _salmon)),
    );
  }
}

/// Continuously drifting linear gradient — mirrors the "animated gradient"
/// community hero banner in the product mockups.
class _AnimatedGradient extends StatefulWidget {
  const _AnimatedGradient({this.height, this.radius = 14});
  final double? height;
  final double radius;

  @override
  State<_AnimatedGradient> createState() => _AnimatedGradientState();
}

class _AnimatedGradientState extends State<_AnimatedGradient>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
      vsync: this, duration: const Duration(seconds: 5))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ac.value);
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment.lerp(
                  const Alignment(-1.4, -1.0), const Alignment(-0.3, -1.0), t)!,
              end: Alignment.lerp(
                  const Alignment(1.0, 1.4), const Alignment(0.3, 1.0), t)!,
              colors: const [_teal, _slate, _salmon],
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// App mockup — the "Strong By Ava" community preview used in hero + final CTA
// ═════════════════════════════════════════════════════════════════════════════

class _AppMockup extends StatelessWidget {
  const _AppMockup();

  static const _navItems = <(IconData, String)>[
    (Icons.grid_view_rounded, 'Overview'),
    (Icons.chat_bubble_outline_rounded, 'Chat'),
    (Icons.bar_chart_rounded, 'Analytics'),
    (Icons.menu_book_rounded, 'Courses'),
    (Icons.calendar_today_rounded, 'Events'),
    (Icons.people_alt_outlined, 'Members'),
    (Icons.emoji_events_outlined, 'Leaderboard'),
  ];

  @override
  Widget build(BuildContext context) {
    final mobile = _mob(context);
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _w10),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 60, offset: Offset(0, 30)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!mobile) _sidebar(),
            Expanded(child: _content(context, mobile)),
          ],
        ),
      ),
    );
  }

  Widget _sidebar() {
    return Container(
      width: 190,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: _w06)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _cream,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: Text('S',
                      style: _t(12, w: FontWeight.w700, c: _ink)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('Strong By Ava',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(12.5, w: FontWeight.w600, c: _w80)),
                ),
              ],
            ),
          ),
          for (var i = 0; i < _navItems.length; i++) _navItem(i),
        ],
      ),
    );
  }

  Widget _navItem(int i) {
    final active = i == 0;
    final (icon, label) = _navItems[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? _w10 : const Color(0x00000000),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: active ? _white : _w40),
          const SizedBox(width: 9),
          Text(label,
              style: _t(12.5,
                  w: active ? FontWeight.w600 : FontWeight.w400,
                  c: active ? _white : _w65)),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, bool mobile) {
    return Padding(
      padding: EdgeInsets.all(mobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner with the overlapping community avatar.
          SizedBox(
            height: mobile ? 150 : 190,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  bottom: 34,
                  child: _AnimatedGradient(radius: mobile ? 12 : 16),
                ),
                Positioned(
                  left: mobile ? 14 : 22,
                  bottom: 0,
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: _cream,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _panel, width: 3),
                    ),
                    alignment: Alignment.center,
                    child: Text('S', style: _t(26, w: FontWeight.w700, c: _ink)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Strong By Ava',
                        style: _t(mobile ? 17 : 20, w: FontWeight.w700, ls: -0.3)),
                    const SizedBox(height: 3),
                    Text('847 members', style: _t(13, c: _w65)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const _PillButtonStub(label: 'Join now'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Ava Torres is a certified strength coach with 80k+ followers on '
            'Instagram. → 12-week progressive training programs with video '
            'lessons → Weekly live Q&As and form-check threads → A supportive '
            'community of women training for strength',
            style: _t(13, c: _w65, h: 1.65),
          ),
        ],
      ),
    );
  }
}

/// Non-interactive white pill used inside the mockup (decorative only).
class _PillButtonStub extends StatelessWidget {
  const _PillButtonStub({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label, style: _t(13, w: FontWeight.w600, c: _black)),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Navigation bar
// ═════════════════════════════════════════════════════════════════════════════

class _Nav extends StatefulWidget {
  const _Nav({
    required this.onAbout,
    required this.onFeatures,
    required this.onPricing,
    required this.onBlog,
    required this.onContact,
    required this.onLogin,
    required this.onCta,
  });
  final VoidCallback onAbout, onFeatures, onPricing, onBlog, onContact;
  final VoidCallback onLogin, onCta;

  @override
  State<_Nav> createState() => _NavState();
}

class _NavState extends State<_Nav> {
  bool _open = false;

  List<(String, VoidCallback)> get _links => [
        ('About', widget.onAbout),
        ('Features', widget.onFeatures),
        ('Pricing', widget.onPricing),
        ('Blog', widget.onBlog),
        ('Contact', widget.onContact),
      ];

  void _tapLink(VoidCallback cb) {
    setState(() => _open = false);
    cb();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 900;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xB3000000),
            border: Border(bottom: BorderSide(color: _w06)),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 64,
                  child: _Section(
                    child: Row(
                      children: [
                        const _Logo(),
                        const Spacer(),
                        if (!narrow) ...[
                          for (final (label, cb) in _links)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _NavLink(label: label, onTap: cb),
                            ),
                          const Spacer(),
                          _PillButton(
                              label: 'Login',
                              onTap: widget.onLogin,
                              kind: _BtnKind.ghost),
                          const SizedBox(width: 8),
                          _PillButton(label: 'Get started', onTap: widget.onCta),
                        ] else
                          _Hover(
                            builder: (context, hovered) => GestureDetector(
                              onTap: () => setState(() => _open = !_open),
                              child: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: hovered || _open ? _w10 : _w05,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: _w10),
                                ),
                                child: Icon(
                                    _open ? Icons.close_rounded : Icons.menu_rounded,
                                    size: 18,
                                    color: _white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Mobile dropdown menu.
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: (narrow && _open)
                      ? _Section(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final (label, cb) in _links)
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _tapLink(cb),
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 11),
                                      child: Text(label,
                                          style: _t(16, w: FontWeight.w500)),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: _PillButton(
                                            label: 'Login',
                                            onTap: () => _tapLink(widget.onLogin),
                                            kind: _BtnKind.outline),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Center(
                                        child: _PillButton(
                                            label: 'Get started',
                                            onTap: () => _tapLink(widget.onCta)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_teal, _salmon],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text('F', style: _t(13, w: FontWeight.w800, c: _white)),
        ),
        const SizedBox(width: 9),
        Text('Fora', style: _t(18, w: FontWeight.w700, ls: -0.4)),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Hover(
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0x00000000),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: _t(14, w: FontWeight.w500, c: hovered ? _white : _w65),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Hero
// ═════════════════════════════════════════════════════════════════════════════

class _Hero extends StatelessWidget {
  const _Hero({required this.sc, required this.onCta});
  final ScrollController sc;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final mobile = _mob(context);
    return ClipRect(
      child: Stack(
        children: [
          // radial-gradient(200% 83% at 50% 0, #1b2228 0%, #353f44 42%, #d39794 100%)
          Positioned.fill(
            child: Transform.scale(
              scaleX: 2.2,
              alignment: Alignment.topCenter,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.15,
                    colors: [_ink, _slate, _salmon],
                    stops: [0.0, 0.42, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // Fade to the black page canvas at the bottom edge.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 260,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), _black],
                ),
              ),
            ),
          ),
          _Section(
            child: Padding(
              padding: EdgeInsets.only(top: mobile ? 120 : 160, bottom: 24),
              child: Column(
                children: [
                  _Reveal(
                    sc: sc,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0x26000000),
                        border: Border.all(color: _w10),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text('Community platform for creators',
                          style: _t(13, w: FontWeight.w500, c: _w80)),
                    ),
                  ),
                  const SizedBox(height: 26),
                  _Reveal(
                    sc: sc,
                    delayMs: 80,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Text(
                        'Your community deserves its own home.',
                        textAlign: TextAlign.center,
                        style: _display(mobile ? 38 : 56),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _Reveal(
                    sc: sc,
                    delayMs: 160,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Text(
                        'Fora gives creators, educators, and coaches a fully '
                        'branded space with courses, events, discussions, and '
                        'members.',
                        textAlign: TextAlign.center,
                        style: _t(mobile ? 16 : 18, c: _w80, h: 1.55),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _Reveal(
                    sc: sc,
                    delayMs: 240,
                    child: _PillButton(
                        label: 'Get started free', onTap: onCta, big: true),
                  ),
                  SizedBox(height: mobile ? 48 : 72),
                  _Reveal(
                    sc: sc,
                    delayMs: 320,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: const _AppMockup(),
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
}

// ═════════════════════════════════════════════════════════════════════════════
// Intro
// ═════════════════════════════════════════════════════════════════════════════

class _Intro extends StatelessWidget {
  const _Intro({required this.sc});
  final ScrollController sc;

  static const _paragraphs = <String>[
    'Fora is a community platform built for creators, educators, and coaches. '
        'Courses, events, discussions, and a member directory, all in one '
        'place, under one login, with one URL.',
    "That URL is yours. Every community on Fora runs on its own subdomain or "
        "a custom domain you own. Members sign up and sign in inside your "
        "branded space. They never see Fora's name, and they never should.",
    'You set it up in minutes. Fora handles the routing, the auth, and the '
        'infrastructure in the background. What your members experience is '
        'entirely yours.',
  ];

  @override
  Widget build(BuildContext context) {
    final mobile = _mob(context);
    return _Section(
      maxWidth: 900,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: mobile ? 70 : 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Reveal(sc: sc, child: const _Tag('Intro')),
            const SizedBox(height: 30),
            for (var i = 0; i < _paragraphs.length; i++)
              _Reveal(
                sc: sc,
                delayMs: i * 100,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 26),
                  child: Text(
                    _paragraphs[i],
                    style: _t(mobile ? 18 : 24,
                        w: FontWeight.w500, c: _w80, h: 1.45, ls: -0.3),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Core features — tabbed product preview
// ═════════════════════════════════════════════════════════════════════════════

class _CoreFeatures extends StatefulWidget {
  const _CoreFeatures({required this.sc});
  final ScrollController sc;

  @override
  State<_CoreFeatures> createState() => _CoreFeaturesState();
}

class _CoreFeaturesState extends State<_CoreFeatures> {
  int _tab = 0;

  static const _tabs = ['Community', 'Courses', 'Events', 'Members'];
  static const _captions = [
    'Post, discuss, react — the feed your members live in.',
    'Chapters and lessons your members learn from, right inside your space.',
    'Live sessions and meetups your members actually show up to.',
    'Every member, one directory — profiles your community can browse.',
  ];

  @override
  Widget build(BuildContext context) {
    final mobile = _mob(context);
    final sc = widget.sc;
    return _Section(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: mobile ? 60 : 100),
        child: Column(
          children: [
            _Reveal(sc: sc, child: const _Tag('Core Features')),
            const SizedBox(height: 24),
            _Reveal(
              sc: sc,
              delayMs: 80,
              child: Text(
                'One platform to run right\nyour entire community.',
                textAlign: TextAlign.center,
                style: _display(mobile ? 30 : 44),
              ),
            ),
            const SizedBox(height: 20),
            _Reveal(
              sc: sc,
              delayMs: 160,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(
                  'Fora brings your courses, events, discussions, and members '
                  'into one space, so you stop switching between tools and '
                  'start spending time with your community.',
                  textAlign: TextAlign.center,
                  style: _t(mobile ? 15 : 17, c: _w65, h: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 38),
            _Reveal(
              sc: sc,
              delayMs: 220,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < _tabs.length; i++) _tabChip(i),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                _captions[_tab],
                key: ValueKey(_tab),
                textAlign: TextAlign.center,
                style: _t(14, c: _w40),
              ),
            ),
            const SizedBox(height: 32),
            _Reveal(
              sc: sc,
              delayMs: 280,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(mobile ? 16 : 28),
                  decoration: BoxDecoration(
                    color: _panel,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _w10),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOut,
                    child: KeyedSubtree(
                      key: ValueKey(_tab),
                      child: switch (_tab) {
                        0 => const _FeedPreview(),
                        1 => const _CoursesPreview(),
                        2 => const _EventsPreview(),
                        _ => const _MembersPreview(),
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(int i) {
    final active = _tab == i;
    return _Hover(
      builder: (context, hovered) => GestureDetector(
        onTap: () => setState(() => _tab = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: active
                ? _white
                : hovered
                    ? _w10
                    : _w05,
            border: Border.all(color: active ? _white : _w10),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            _tabs[i],
            style: _t(14,
                w: FontWeight.w600, c: active ? _black : _w80, ls: -0.2),
          ),
        ),
      ),
    );
  }
}

// ─── Mini skeleton pieces shared by the previews ─────────────────────────────

Widget _skelBar(double w, {double h = 8, Color c = _w10}) => Container(
      width: w,
      height: h,
      decoration:
          BoxDecoration(color: c, borderRadius: BorderRadius.circular(100)),
    );

Widget _miniAvatar(String letter, Color bg, {double size = 34}) => Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      alignment: Alignment.center,
      child: Text(letter,
          style: _t(size * 0.42, w: FontWeight.w700, c: _black)),
    );

class _FeedPreview extends StatelessWidget {
  const _FeedPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _post('A', _salmon, 'Ava Torres', '2h',
            'New 12-week program drops Monday. Form-check thread opens tonight.',
            reactions: '24'),
        const SizedBox(height: 12),
        _post('M', _cream, 'Maya K.', '5h',
            'Hit a 100kg deadlift PR today — thank you all for the cues!',
            reactions: '61'),
        const SizedBox(height: 12),
        _post('J', Color(0xFFB9D2D3), 'Jess P.', '1d',
            'Weekly Q&A replay is up in Courses, chapter 4.',
            reactions: '18'),
      ],
    );
  }

  Widget _post(String letter, Color color, String name, String time,
      String body,
      {required String reactions}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _w05,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _w06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _miniAvatar(letter, color, size: 30),
              const SizedBox(width: 10),
              Text(name, style: _t(13.5, w: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(time, style: _t(12, c: _w40)),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: _t(13.5, c: _w65, h: 1.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              _reaction(Icons.favorite_border_rounded, reactions),
              const SizedBox(width: 8),
              _reaction(Icons.chat_bubble_outline_rounded, 'Reply'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reaction(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _w05,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _w06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _w65),
          const SizedBox(width: 5),
          Text(label, style: _t(11.5, c: _w65)),
        ],
      ),
    );
  }
}

class _CoursesPreview extends StatelessWidget {
  const _CoursesPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _chapter('01', 'Foundations of strength', '6 lessons', 1.0),
        const SizedBox(height: 12),
        _chapter('02', 'Progressive overload, week by week', '8 lessons', 0.55),
        const SizedBox(height: 12),
        _chapter('03', 'Form clinics and video reviews', '5 lessons', 0.0),
      ],
    );
  }

  Widget _chapter(String num, String title, String meta, double progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _w05,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _w06),
      ),
      child: Row(
        children: [
          Text(num, style: _mono(13, c: _salmon)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _t(14, w: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(meta, style: _t(12, c: _w40)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: SizedBox(
                    height: 4,
                    child: Stack(
                      children: [
                        Container(color: _w10),
                        FractionallySizedBox(
                          widthFactor: progress == 0 ? 0.001 : progress,
                          child: Container(color: _salmon),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(
              progress >= 1
                  ? Icons.check_circle_rounded
                  : Icons.play_circle_outline_rounded,
              size: 20,
              color: progress >= 1 ? _salmon : _w40),
        ],
      ),
    );
  }
}

class _EventsPreview extends StatelessWidget {
  const _EventsPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _event('JUN', '12', 'Live Q&A — training through plateaus', '7:00 PM',
            live: true),
        const SizedBox(height: 12),
        _event('JUN', '19', 'Form-check workshop: squat day', '6:30 PM'),
        const SizedBox(height: 12),
        _event('JUN', '26', 'Monthly community challenge kickoff', '5:00 PM'),
      ],
    );
  }

  Widget _event(String month, String day, String title, String time,
      {bool live = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _w05,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _w06),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _w05,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _w10),
            ),
            child: Column(
              children: [
                Text(month, style: _mono(10, c: _salmon)),
                const SizedBox(height: 2),
                Text(day, style: _t(17, w: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _t(14, w: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(time, style: _t(12, c: _w40)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (live)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x33D39794),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text('LIVE', style: _mono(10, c: _salmon)),
            )
          else
            Text('RSVP', style: _t(12.5, w: FontWeight.w600, c: _w65)),
        ],
      ),
    );
  }
}

class _MembersPreview extends StatelessWidget {
  const _MembersPreview();

  static const _members = <(String, String, String, Color)>[
    ('A', 'Ava Torres', 'Coach', _salmon),
    ('M', 'Maya K.', 'Member', _cream),
    ('J', 'Jess P.', 'Member', Color(0xFFB9D2D3)),
    ('R', 'Rosa D.', 'Moderator', Color(0xFFE8C9B8)),
    ('L', 'Lena W.', 'Member', Color(0xFFCBD5C0)),
    ('T', 'Tara S.', 'Member', Color(0xFFD9C4E3)),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth > 620 ? 3 : (box.maxWidth > 380 ? 2 : 1);
        final w = (box.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (letter, name, role, color) in _members)
              SizedBox(
                width: w,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _w05,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _w06),
                  ),
                  child: Row(
                    children: [
                      _miniAvatar(letter, color, size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _t(13, w: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(role, style: _t(11.5, c: _w40)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// What you get — three feature cards
// ═════════════════════════════════════════════════════════════════════════════

class _WhatYouGet extends StatelessWidget {
  const _WhatYouGet({required this.sc});
  final ScrollController sc;

  @override
  Widget build(BuildContext context) {
    final mobile = _mob(context);
    final wide = MediaQuery.sizeOf(context).width >= 980;
    return _Section(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: mobile ? 60 : 100),
        child: Column(
          children: [
            _Reveal(sc: sc, child: const _Tag('What you get')),
            const SizedBox(height: 24),
            _Reveal(
              sc: sc,
              delayMs: 80,
              child: Text(
                'Set up once.\nRun it the way you want.',
                textAlign: TextAlign.center,
                style: _display(mobile ? 30 : 44),
              ),
            ),
            const SizedBox(height: 20),
            _Reveal(
              sc: sc,
              delayMs: 160,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  'Fora is built so you spend time with your community, not '
                  'configuring it. From your first setting to your hundredth '
                  'member, the platform stays out of your way.',
                  textAlign: TextAlign.center,
                  style: _t(mobile ? 15 : 17, c: _w65, h: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 48),
            _Reveal(
              sc: sc,
              delayMs: 200,
              child: _FeatureCard(
                horizontal: wide,
                kicker: 'Your front door',
                title: 'A community overview page that sells itself.',
                body:
                    'Customize your hero with a static color or animated '
                    'gradient. Add a headline, a description and member '
                    'avatars. Your overview page is the first thing a visitor '
                    'sees — make it yours.',
                tagline: 'First impressions that convert.',
                visual: const _OverviewVisual(),
              ),
            ),
            const SizedBox(height: 20),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Reveal(
                      sc: sc,
                      delayMs: 100,
                      child: const _FeatureCard(
                        kicker: 'Friendly competition',
                        title: 'A leaderboard your members actually check.',
                        body:
                            'Rankings based on posts, completions, and '
                            'activity — surfaced automatically. Gives your '
                            'most engaged members a reason to stay and your '
                            'quieter ones a reason to show up.',
                        tagline: 'Engagement that compounds over time.',
                        visual: _LeaderboardVisual(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _Reveal(
                      sc: sc,
                      delayMs: 200,
                      child: const _FeatureCard(
                        kicker: 'Courses',
                        title: 'Build your course the way you teach.',
                        body:
                            'Structure your content into chapters and '
                            'lessons, in any order you want. Add your '
                            'material, hit publish, and your members can '
                            'start learning — right inside the community they '
                            'already live in.',
                        tagline: 'Courses that feel like yours, not a template.',
                        visual: _CourseVisual(),
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              _Reveal(
                sc: sc,
                delayMs: 100,
                child: const _FeatureCard(
                  kicker: 'Friendly competition',
                  title: 'A leaderboard your members actually check.',
                  body:
                      'Rankings based on posts, completions, and activity — '
                      'surfaced automatically. Gives your most engaged members '
                      'a reason to stay and your quieter ones a reason to show '
                      'up.',
                  tagline: 'Engagement that compounds over time.',
                  visual: _LeaderboardVisual(),
                ),
              ),
              const SizedBox(height: 20),
              _Reveal(
                sc: sc,
                delayMs: 100,
                child: const _FeatureCard(
                  kicker: 'Courses',
                  title: 'Build your course the way you teach.',
                  body:
                      'Structure your content into chapters and lessons, in '
                      'any order you want. Add your material, hit publish, and '
                      'your members can start learning — right inside the '
                      'community they already live in.',
                  tagline: 'Courses that feel like yours, not a template.',
                  visual: _CourseVisual(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.kicker,
    required this.title,
    required this.body,
    required this.tagline,
    required this.visual,
    this.horizontal = false,
  });
  final String kicker, title, body, tagline;
  final Widget visual;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(kicker.toUpperCase(), style: _mono(11, c: _salmon)),
        const SizedBox(height: 14),
        Text(title, style: _display(24)),
        const SizedBox(height: 12),
        Text(body, style: _t(14.5, c: _w65, h: 1.6)),
        const SizedBox(height: 18),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                  color: _salmon, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(tagline,
                  style: _t(13.5, w: FontWeight.w500, c: _w80)),
            ),
          ],
        ),
      ],
    );

    return _Hover(
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _w05,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: hovered ? _w25 : _w10),
        ),
        child: horizontal
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 32),
                  Expanded(child: visual),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  visual,
                  const SizedBox(height: 24),
                  text,
                ],
              ),
      ),
    );
  }
}

/// Mini "overview page" visual: animated-gradient hero + avatar + copy bars.
class _OverviewVisual extends StatelessWidget {
  const _OverviewVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _w06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AnimatedGradient(height: 90, radius: 10),
          const SizedBox(height: 12),
          Row(
            children: [
              _miniAvatar('S', _cream, size: 30),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skelBar(110, h: 9, c: _w25),
                  const SizedBox(height: 6),
                  _skelBar(70, h: 7),
                ],
              ),
              const Spacer(),
              const _PillButtonStub(label: 'Join'),
            ],
          ),
          const SizedBox(height: 12),
          _skelBar(double.infinity, h: 7),
          const SizedBox(height: 6),
          _skelBar(200, h: 7),
        ],
      ),
    );
  }
}

/// Mini leaderboard visual.
class _LeaderboardVisual extends StatelessWidget {
  const _LeaderboardVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _w06),
      ),
      child: Column(
        children: [
          _row('1', 'M', _cream, 'Maya K.', '1,240 pts', top: true),
          const SizedBox(height: 8),
          _row('2', 'J', const Color(0xFFB9D2D3), 'Jess P.', '1,105 pts'),
          const SizedBox(height: 8),
          _row('3', 'R', const Color(0xFFE8C9B8), 'Rosa D.', '980 pts'),
        ],
      ),
    );
  }

  Widget _row(String rank, String letter, Color color, String name,
      String pts,
      {bool top = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: top ? const Color(0x1AD39794) : _w05,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: top ? const Color(0x40D39794) : _w06),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 18, child: Text(rank, style: _mono(12, c: _salmon))),
          const SizedBox(width: 8),
          _miniAvatar(letter, color, size: 26),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: _t(13, w: FontWeight.w600))),
          Text(pts, style: _t(12, c: _w40)),
        ],
      ),
    );
  }
}

/// Mini course-builder visual.
class _CourseVisual extends StatelessWidget {
  const _CourseVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _w06),
      ),
      child: Column(
        children: [
          _lesson('Chapter 1 · Welcome', true),
          const SizedBox(height: 8),
          _lesson('Chapter 2 · The program', true),
          const SizedBox(height: 8),
          _lesson('Chapter 3 · Going further', false),
        ],
      ),
    );
  }

  Widget _lesson(String label, bool published) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: _w05,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _w06),
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator_rounded, size: 15, color: _w25),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: _t(13, w: FontWeight.w500))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: published ? const Color(0x1AD39794) : _w05,
              borderRadius: BorderRadius.circular(100),
              border:
                  Border.all(color: published ? const Color(0x40D39794) : _w10),
            ),
            child: Text(published ? 'LIVE' : 'DRAFT',
                style: _mono(9, c: published ? _salmon : _w40)),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Pricing
// ═════════════════════════════════════════════════════════════════════════════

class _Pricing extends StatelessWidget {
  const _Pricing({required this.sc, required this.onCta});
  final ScrollController sc;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final mobile = _mob(context);
    final wide = MediaQuery.sizeOf(context).width >= 980;

    final cards = <Widget>[
      _PlanCard(
        plan: 'Starter',
        price: '\$0',
        period: '/month',
        blurb: 'Everything you need to launch your community.',
        cta: 'Get Started',
        onTap: onCta,
        features: const [
          'Up to 200 members',
          'Fora subdomain',
          'Community feed & chat',
          'Courses & events',
          'Member profiles',
          'Analytics',
        ],
      ),
      _PlanCard(
        plan: 'Pro',
        price: '\$0',
        period: '/month',
        blurb: 'For creators serious about their brand.',
        cta: 'Get Started',
        onTap: onCta,
        featured: true,
        features: const [
          'Up to 5000 members',
          'Custom domain',
          'Community feed & chat',
          'Courses & events',
          'Member profiles',
          'Analytics',
        ],
      ),
      _PlanCard(
        plan: 'Enterprise',
        price: 'Custom price',
        period: null,
        blurb: 'For teams that need more control.',
        cta: 'Contact us',
        onTap: onCta,
        features: const [
          'Unlimited members',
          'Everything in Pro',
          'Priority support',
          'Dedicated onboarding',
          'SLA & uptime guarantee',
          'Custom contract',
        ],
      ),
    ];

    return _Section(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: mobile ? 60 : 100),
        child: Column(
          children: [
            _Reveal(sc: sc, child: const _Tag('Pricing')),
            const SizedBox(height: 24),
            _Reveal(
              sc: sc,
              delayMs: 80,
              child: Text(
                'Clear pricing plans\nthat scale with you',
                textAlign: TextAlign.center,
                style: _display(mobile ? 30 : 44),
              ),
            ),
            const SizedBox(height: 48),
            if (wide)
              _Reveal(
                sc: sc,
                delayMs: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 20),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 20),
                    Expanded(child: cards[2]),
                  ],
                ),
              )
            else
              for (var i = 0; i < cards.length; i++)
                _Reveal(
                  sc: sc,
                  delayMs: 80,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i < 2 ? 20 : 0),
                    child: cards[i],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.price,
    required this.period,
    required this.blurb,
    required this.cta,
    required this.onTap,
    required this.features,
    this.featured = false,
  });
  final String plan, price, blurb, cta;
  final String? period;
  final VoidCallback onTap;
  final List<String> features;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return _Hover(
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: featured ? const Color(0x14D39794) : _w05,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: featured
                ? (hovered ? _salmon : const Color(0x80D39794))
                : (hovered ? _w25 : _w10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.toUpperCase(),
                style: _mono(11, c: featured ? _salmon : _w65)),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(price,
                      style: _display(period == null ? 28 : 40)),
                ),
                if (period != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: Text(period!, style: _t(14, c: _w40)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(blurb, style: _t(14, c: _w65, h: 1.5)),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: Center(
                child: _PillButton(
                  label: cta,
                  onTap: onTap,
                  big: true,
                  kind: featured ? _BtnKind.filled : _BtnKind.outline,
                ),
              ),
            ),
            const SizedBox(height: 24),
            for (final f in features)
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Row(
                  children: [
                    const Icon(Icons.check_rounded, size: 15, color: _salmon),
                    const SizedBox(width: 10),
                    Expanded(child: Text(f, style: _t(13.5, c: _w80))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FAQ
// ═════════════════════════════════════════════════════════════════════════════

class _Faq extends StatefulWidget {
  const _Faq({required this.sc, required this.onContact});
  final ScrollController sc;
  final VoidCallback onContact;

  @override
  State<_Faq> createState() => _FaqState();
}

class _FaqState extends State<_Faq> {
  int _category = 0;
  int _openIndex = 0;

  static const _categories = [
    'General',
    'Community & Features',
    'Privacy & Access',
  ];

  static const _items = <(String, String)>[
    (
      'What is Fora?',
      'Fora is a white-label community platform for creators, educators, and '
          'coaches. You get a fully branded space with courses, events, '
          'discussions, and members — all running on your own subdomain or '
          'custom domain.'
    ),
    (
      'How long does it take to set up?',
      'Most communities are live in under 20 minutes. You pick a subdomain, '
          'customize your overview page, and invite your first members. No '
          'code, no infrastructure.'
    ),
    (
      'Do I need technical knowledge?',
      'Not at all. Everything happens through a clean dashboard. The only '
          'technical step is adding a DNS record if you want a fully custom '
          'domain — and we walk you through it.'
    ),
    (
      'Is Fora really free right now?',
      'Yes. Fora is in beta and completely free. No credit card, no trial '
          'period — just sign up and go. When paid plans launch, beta members '
          'get a permanent discount locked in.'
    ),
    (
      'What happens when the beta ends?',
      "You'll get early notice before anything changes. Beta members are "
          'first to know, first to get access to paid plans, and first to '
          'lock in their discount.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final mobile = _mob(context);
    final wide = MediaQuery.sizeOf(context).width >= 980;
    final sc = widget.sc;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Reveal(sc: sc, child: const _Tag('FAQ')),
        const SizedBox(height: 24),
        _Reveal(
          sc: sc,
          delayMs: 80,
          child: Text('Answers to the questions that come up most.',
              style: _display(mobile ? 28 : 36)),
        ),
        const SizedBox(height: 18),
        _Reveal(
          sc: sc,
          delayMs: 160,
          child: Text(
            "Learn how Fora works, what's included in the beta, what your "
            'members experience, and what to expect as the platform grows.',
            style: _t(15, c: _w65, h: 1.6),
          ),
        ),
        const SizedBox(height: 28),
        _Reveal(
          sc: sc,
          delayMs: 220,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _categories.length; i++) _catChip(i),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _Reveal(
          sc: sc,
          delayMs: 260,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _w05,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _w10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Got Questions?', style: _t(17, w: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  "Can't find what you're looking for? Reach out — we're fast.",
                  style: _t(14, c: _w65, h: 1.55),
                ),
                const SizedBox(height: 16),
                _Hover(
                  builder: (context, hovered) => GestureDetector(
                    onTap: widget.onContact,
                    child: Text(
                      'Contact us →',
                      style: _t(14,
                          w: FontWeight.w600,
                          c: hovered ? _salmon : _white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final right = Column(
      children: [
        for (var i = 0; i < _items.length; i++)
          _Reveal(
            sc: sc,
            delayMs: 60 * i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _faqTile(i),
            ),
          ),
      ],
    );

    return _Section(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: mobile ? 60 : 100),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: left),
                  const SizedBox(width: 56),
                  Expanded(flex: 6, child: right),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, const SizedBox(height: 40), right],
              ),
      ),
    );
  }

  Widget _catChip(int i) {
    final active = _category == i;
    return _Hover(
      builder: (context, hovered) => GestureDetector(
        onTap: () => setState(() {
          _category = i;
          _openIndex = 0;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? _white
                : hovered
                    ? _w10
                    : _w05,
            border: Border.all(color: active ? _white : _w10),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            _categories[i],
            style: _t(13.5,
                w: FontWeight.w600, c: active ? _black : _w80),
          ),
        ),
      ),
    );
  }

  Widget _faqTile(int i) {
    final (q, a) = _items[i];
    final open = _openIndex == i;
    return _Hover(
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _openIndex = open ? -1 : i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: open || hovered ? _w05 : const Color(0x00000000),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: open ? _w25 : _w10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(q, style: _t(15.5, w: FontWeight.w600))),
                  const SizedBox(width: 12),
                  AnimatedRotation(
                    turns: open ? 0.125 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: const Icon(Icons.add_rounded,
                        size: 20, color: _w65),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 24),
                  child: Text(a, style: _t(14, c: _w65, h: 1.65)),
                ),
                crossFadeState: open
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Blog
// ═════════════════════════════════════════════════════════════════════════════

class _Blog extends StatelessWidget {
  const _Blog({required this.sc});
  final ScrollController sc;

  static const _posts = <(String, String, String)>[
    (
      'Fora vs Mighty Networks: Full Comparison for Creators & Educators '
          '(2026)',
      'Comparisons',
      'Jun 3, 2026'
    ),
    (
      'How to Launch an Online Community in 2026: A Step-by-Step Guide',
      'Guides',
      'Jun 3, 2026'
    ),
    (
      'Best White-Label Community Platform for Coaches & Educators',
      'Community Building',
      'Jun 3, 2026'
    ),
  ];

  static const _thumbs = <List<Color>>[
    [_teal, _slate, _salmon],
    [_slate, _salmon, _cream],
    [_salmon, _teal, _ink],
  ];

  @override
  Widget build(BuildContext context) {
    final mobile = _mob(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return _Section(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: mobile ? 60 : 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Reveal(
              sc: sc,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Tag('Blog'),
                        const SizedBox(height: 20),
                        Text('Ideas, updates, and practical AI workflows',
                            style: _display(mobile ? 26 : 34)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  _Hover(
                    builder: (context, hovered) => Text(
                      'Visit blog →',
                      style: _t(14,
                          w: FontWeight.w600,
                          c: hovered ? _salmon : _w80),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _posts.length; i++) ...[
                    if (i > 0) const SizedBox(width: 20),
                    Expanded(
                      child: _Reveal(
                          sc: sc, delayMs: 80 * i, child: _postCard(i)),
                    ),
                  ],
                ],
              )
            else
              for (var i = 0; i < _posts.length; i++)
                _Reveal(
                  sc: sc,
                  delayMs: 60,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i < 2 ? 20 : 0),
                    child: _postCard(i),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _postCard(int i) {
    final (title, category, date) = _posts[i];
    return _Hover(
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _w05,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: hovered ? _w25 : _w10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedScale(
              scale: hovered ? 1.03 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _thumbs[i],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: _t(16, w: FontWeight.w600, h: 1.35, ls: -0.2)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _w05,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: _w10),
                        ),
                        child: Text(category, style: _t(11.5, c: _w80)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(date,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _t(12, c: _w40)),
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
}

// ═════════════════════════════════════════════════════════════════════════════
// Final CTA
// ═════════════════════════════════════════════════════════════════════════════

class _FinalCta extends StatelessWidget {
  const _FinalCta({required this.sc, required this.onCta});
  final ScrollController sc;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final mobile = _mob(context);
    return ClipRect(
      child: Stack(
        children: [
          // Soft salmon glow rising from the bottom, echoing the hero.
          Positioned.fill(
            child: Transform.scale(
              scaleX: 2.2,
              alignment: Alignment.bottomCenter,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomCenter,
                    radius: 1.1,
                    colors: [Color(0x59D39794), Color(0x2E353F44), Color(0x00000000)],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          _Section(
            child: Padding(
              padding: EdgeInsets.only(top: mobile ? 70 : 120, bottom: 40),
              child: Column(
                children: [
                  _Reveal(
                    sc: sc,
                    child: Text(
                      'Your community is one sec away.',
                      textAlign: TextAlign.center,
                      style: _display(mobile ? 30 : 44),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Reveal(
                    sc: sc,
                    delayMs: 80,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Text(
                        'Fora is in beta and free to join. Set up your space, '
                        'invite your first members, and see what it feels like '
                        'when everything lives in one place — under your name.',
                        textAlign: TextAlign.center,
                        style: _t(mobile ? 15 : 17, c: _w80, h: 1.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _Reveal(
                    sc: sc,
                    delayMs: 160,
                    child: _PillButton(
                        label: 'Start for free', onTap: onCta, big: true),
                  ),
                  SizedBox(height: mobile ? 44 : 64),
                  _Reveal(
                    sc: sc,
                    delayMs: 240,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: const _AppMockup(),
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
}

// ═════════════════════════════════════════════════════════════════════════════
// Footer
// ═════════════════════════════════════════════════════════════════════════════

class _Footer extends StatelessWidget {
  const _Footer({
    required this.onAbout,
    required this.onPricing,
    required this.onBlog,
  });
  final VoidCallback onAbout, onPricing, onBlog;

  @override
  Widget build(BuildContext context) {
    final mobile = _mob(context);
    final wide = MediaQuery.sizeOf(context).width >= 820;

    final columns = <Widget>[
      _col('Product', [
        ('About', onAbout),
        ('Pricing', onPricing),
        ('Blog', onBlog),
        ('Contact', null),
        ('Changelog', null),
      ]),
      _col('Legal', [
        ('Terms of use', null),
        ('Privacy policy', null),
        ('Cookie Policy', null),
      ]),
      _col('Compare', [
        ('Skool', null),
        ('Circle', null),
        ('Mighty Networks', null),
      ]),
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _w06)),
      ),
      child: _Section(
        child: Padding(
          padding: EdgeInsets.only(top: mobile ? 48 : 72, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(flex: 2, child: _FooterBrand()),
                    for (final c in columns) Expanded(child: c),
                  ],
                )
              else ...[
                const _FooterBrand(),
                const SizedBox(height: 36),
                Wrap(
                  spacing: 48,
                  runSpacing: 32,
                  children: columns,
                ),
              ],
              SizedBox(height: mobile ? 40 : 64),
              const Divider(color: _w06, height: 1),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                children: [
                  Text('© Fora. 2026. All rights reserved',
                      style: _t(12.5, c: _w40)),
                  Text('contact@fora.so', style: _t(12.5, c: _w40)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _col(String title, List<(String, VoidCallback?)> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: _mono(10.5, c: _w40)),
        const SizedBox(height: 16),
        for (final (label, cb) in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: _Hover(
              builder: (context, hovered) => GestureDetector(
                onTap: cb,
                child: Text(label,
                    style: _t(13.5, c: hovered ? _white : _w65)),
              ),
            ),
          ),
      ],
    );
  }
}

class _FooterBrand extends StatelessWidget {
  const _FooterBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Logo(),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(
            'White-label community platform for creators, educators, and '
            'coaches.',
            style: _t(13, c: _w40, h: 1.55),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Screen
// ═════════════════════════════════════════════════════════════════════════════

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with ScreenLogger {
  final _sc = ScrollController();
  final _aboutKey = GlobalKey();
  final _featuresKey = GlobalKey();
  final _pricingKey = GlobalKey();
  final _blogKey = GlobalKey();
  final _contactKey = GlobalKey();

  void _goAuth() => context.go('/auth');

  void _scrollTo(GlobalKey k) {
    final ctx = k.currentContext;
    if (ctx == null) {
      return;
    }
    Scrollable.ensureVisible(ctx,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
        alignment: 0.06);
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Scaffold(
        backgroundColor: _black,
        body: Stack(
          children: [
            SingleChildScrollView(
              controller: _sc,
              child: Column(
                children: [
                  _Hero(sc: _sc, onCta: _goAuth),
                  KeyedSubtree(key: _aboutKey, child: _Intro(sc: _sc)),
                  KeyedSubtree(
                      key: _featuresKey, child: _CoreFeatures(sc: _sc)),
                  _WhatYouGet(sc: _sc),
                  KeyedSubtree(
                      key: _pricingKey,
                      child: _Pricing(sc: _sc, onCta: _goAuth)),
                  _Faq(sc: _sc, onContact: () => _scrollTo(_contactKey)),
                  KeyedSubtree(key: _blogKey, child: _Blog(sc: _sc)),
                  _FinalCta(sc: _sc, onCta: _goAuth),
                  KeyedSubtree(
                    key: _contactKey,
                    child: _Footer(
                      onAbout: () => _scrollTo(_aboutKey),
                      onPricing: () => _scrollTo(_pricingKey),
                      onBlog: () => _scrollTo(_blogKey),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _Nav(
                onAbout: () => _scrollTo(_aboutKey),
                onFeatures: () => _scrollTo(_featuresKey),
                onPricing: () => _scrollTo(_pricingKey),
                onBlog: () => _scrollTo(_blogKey),
                onContact: () => _scrollTo(_contactKey),
                onLogin: _goAuth,
                onCta: _goAuth,
              ),
            ),
          ],
        ),
      ),
    );
  }
}