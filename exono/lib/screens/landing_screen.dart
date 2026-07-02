import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../utils/screen_logger.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Fora landing page — Flutter replica of the published Framer site.
//
// Rebuilt 1:1 from the exported HTML:
//  · palette + typography presets (Inter 56/40/28, -4%/-3% tracking, cream
//    #fff3f0 headings, white/65 secondary)
//  · real image assets hotlinked from framerusercontent.com (hero hill layers,
//    gallery screenshots, feature-card mockups, blog covers, footer badges)
//  · Framer appear effects (per-element y-rise + fade springs, staggered
//    delays, scale-1.1 image reveals) re-implemented on the page scroll
//  · scroll-linked stacked cards in the "What you get" section
//  · segmented gallery tab bar (radius-72 bar, fading radius-66 active pill)
// ═════════════════════════════════════════════════════════════════════════════

// ─── Palette (extracted Framer tokens) ───────────────────────────────────────
const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);
const _cream = Color(0xFFFFF3F0); //  token 090acfc6 — warm heading/accent tint
const _w90 = Color(0xE6FFFFFF);
const _w80 = Color(0xCCFFFFFF); //   token 792af9ed — button fill #fffc
const _w65 = Color(0xA6FFFFFF); //   token c6de8ea4 — dimmed heading/body
const _w40 = Color(0x66FFFFFF);
const _w25 = Color(0x40FFFFFF); //   token e3ce13ec
const _w10 = Color(0x1AFFFFFF); //   token aecd04de — chip bg / borders
const _w05 = Color(0x0DFFFFFF);
const _panel21 = Color(0xD9212121); // token feab5ab7 rendered — mockup panel
const _panel0f = Color(0xD90F0F0F); // token 9a0a5818 — card inner panel
const _black85 = Color(0xD9000000); // token 259d8c78 — card/bar fill
const _ink = Color(0xFF1B2228); //   token d22f0868 — hero gradient start
const _slate = Color(0xFF353F44); // token 6a452ef3 — hero gradient mid
const _salmon = Color(0xFFD39794); // token dedd8b7f — hero gradient end
const _glow = Color(0xFFFAE6E1); //  mockup bottom glow line

// ─── Remote assets (same URLs the site ships) ────────────────────────────────
const _imgHillsFar =
    'https://framerusercontent.com/images/h5VHoQg2qBhfygdenEQ0WUtEZU.png';
const _imgHillsNear =
    'https://framerusercontent.com/images/T6hTfVKiQ81oLHCljxjb0WPLHY8.png';
const _imgHillsBanner =
    'https://framerusercontent.com/images/rNwNiQxFN2tkAEI5eUdmAxB9v4.png';
const _imgDunes =
    'https://framerusercontent.com/images/KEyElslPaeEXTKlix9xtVlt4.png';
const _imgAvatar1 =
    'https://framerusercontent.com/images/J17st5pcaAXO9GWA5udu8FGf50.jpg';
const _imgAvatar2 =
    'https://framerusercontent.com/images/MVRiYah2MhTCdKz3Q79AIXobIM.jpg';
const _imgAvatar3 =
    'https://framerusercontent.com/images/mO82b4q0xkPyk9UthT8GcXc2vf8.jpg';
const _imgTabCommunity =
    'https://framerusercontent.com/images/yzwKdfh1gcsfSCL6ylKvhrtgbY.png';
const _imgTabCourses =
    'https://framerusercontent.com/images/jtkBouztMWHN35tV9uDupUp7b0.png';
const _imgTabEvents =
    'https://framerusercontent.com/images/GggiItB2BHGATkulRf4FZJ9tmGo.png';
const _imgTabMembers =
    'https://framerusercontent.com/images/giwgubyK5fSpftrgOfka34sQA.png';
const _imgCardOverview =
    'https://framerusercontent.com/images/n1xVmUcl9Kn3XOvJd3FJe2qdg.webp?lossless=1';
const _imgCardLeaderboard =
    'https://framerusercontent.com/images/ZvDVx7hlgVHOG7O5kXF7y5tn8.webp';
const _imgCardCourse =
    'https://framerusercontent.com/images/OkFHRTU6rnFb5o15ue6pN5eCMw.webp';
const _imgBlog1 =
    'https://framerusercontent.com/images/EisEW7TIP5i38O4TWciQ1Zf6Q.webp';
const _imgBlog2 =
    'https://framerusercontent.com/images/9UBZAGM31zJYY1cxzKu0pWhMNs.png';
const _imgBlog3 =
    'https://framerusercontent.com/images/9n8OOMGCaEmCo8MDRO2tHo17cQ.png';
const _badgeFindly = 'https://findly.tools/badges/findly-tools-badge-light.svg';
const _badgeTurbo0 = 'https://img.turbo0.com/badge-listed-light.svg';
const _badgeStartupFame = 'https://startupfa.me/badges/featured-badge.webp';
const _badgeTwelve = 'https://twelve.tools/badge0-light.svg';

// ─── Motion (Framer appear-effect specs from the export) ─────────────────────
// Springs are duration-based with bounce 0 → approximated by easeOutQuint-ish.
const _spring = Cubic(0.22, 1.0, 0.36, 1.0);
const _navEase = Cubic(0.44, 0.0, 0.56, 1.0); // nav tween ease

/// Widens a radial gradient into the CSS `radial-gradient(200% 83% at 50% 0)`
/// ellipse by scaling the shader on the X axis about the top-center point.
/// (Shader-level transform — no oversized raster layer.)
class _EllipseXScale extends GradientTransform {
  const _EllipseXScale(this.scaleX);
  final double scaleX;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final cx = bounds.center.dx;
    final ay = bounds.top;
    return Matrix4.translationValues(cx, ay, 0)
      ..multiply(Matrix4.diagonal3Values(scaleX, 1, 1))
      ..multiply(Matrix4.translationValues(-cx, -ay, 0));
  }
}

// ─── Typography (Framer presets; families bundled in assets/fonts) ──────────
TextStyle _t(double size,
        {FontWeight w = FontWeight.w400,
        Color c = _white,
        double? h,
        double? ls}) =>
    TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: w,
        color: c,
        height: h,
        letterSpacing: ls);

TextStyle _mono(double size, {Color c = _cream, double ls = 1.2}) =>
    TextStyle(
        fontFamily: 'Fragment Mono', fontSize: size, color: c, letterSpacing: ls);

/// H1 — 56/40/36, w400, -0.04em, lh 1.3, cream.
TextStyle _h1(BuildContext context) {
  final s = _bp(context) == 2 ? 56.0 : (_bp(context) == 1 ? 40.0 : 36.0);
  return _t(s, w: FontWeight.w400, c: _cream, h: 1.3, ls: s * -0.04);
}

/// H2 — 40/36/32, w500, -0.04em, lh 1.35, white (dim spans _w65).
TextStyle _h2(BuildContext context, {Color c = _white}) {
  final s = _bp(context) == 2 ? 40.0 : (_bp(context) == 1 ? 36.0 : 32.0);
  return _t(s, w: FontWeight.w500, c: c, h: 1.35, ls: s * -0.04);
}

/// H4 — 28/24/22, w400, -0.03em, lh 1.35, cream. Intro text + card titles.
TextStyle _h4(BuildContext context, {Color c = _cream}) {
  final s = _bp(context) == 2 ? 28.0 : (_bp(context) == 1 ? 24.0 : 22.0);
  return _t(s, w: FontWeight.w400, c: c, h: 1.35, ls: s * -0.03);
}

/// Breakpoints: 2 = desktop ≥1280, 1 = tablet ≥810, 0 = phone.
int _bp(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 1280) {
    return 2;
  }
  if (w >= 810) {
    return 1;
  }
  return 0;
}

bool _phone(BuildContext context) => _bp(context) == 0;

// ═════════════════════════════════════════════════════════════════════════════
// Shared primitives
// ═════════════════════════════════════════════════════════════════════════════

/// Page container: centers content, max 1560, responsive gutters.
class _Section extends StatelessWidget {
  const _Section({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pad = _bp(context) == 2 ? 72.0 : (_bp(context) == 1 ? 40.0 : 20.0);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1560),
        child: Padding(
            padding: EdgeInsets.symmetric(horizontal: pad), child: child),
      ),
    );
  }
}

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

/// Scroll-triggered appear effect: rise `dy` + optional fade, once.
/// Mirrors Framer's exported appear animations (spring, bounce 0, 1s).
class _Reveal extends StatefulWidget {
  const _Reveal({
    required this.sc,
    required this.child,
    this.dy = 24,
    this.fade = true,
    this.scaleFrom = 1.0,
    this.delayMs = 0,
    this.durationMs = 1000,
  });
  final ScrollController sc;
  final Widget child;
  final double dy;
  final bool fade;
  final double scaleFrom; // 1.1 → Framer image zoom-in reveals
  final int delayMs;
  final int durationMs;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
      vsync: this, duration: Duration(milliseconds: widget.durationMs));
  late final Animation<double> _anim =
      CurvedAnimation(parent: _ac, curve: _spring);
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
    if (top < vh * 0.95) {
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
        Widget w = Transform.translate(
            offset: Offset(0, widget.dy * (1 - v)), child: child);
        if (widget.scaleFrom != 1.0) {
          final s = widget.scaleFrom + (1.0 - widget.scaleFrom) * v;
          w = Transform.scale(scale: s, child: w);
        }
        if (widget.fade) {
          w = Opacity(opacity: v.clamp(0.0, 1.0), child: w);
        }
        return w;
      },
      child: widget.child,
    );
  }
}

/// Network image with dark placeholder + graceful offline fallback.
class _NetImg extends StatelessWidget {
  const _NetImg(this.url, {this.fit = BoxFit.cover, this.alignment = Alignment.center});
  final String url;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      alignment: alignment,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }
        return const ColoredBox(color: Color(0xFF131313));
      },
      errorBuilder: (context, error, stack) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_ink, _slate],
          ),
        ),
      ),
    );
  }
}

enum _BtnSize { m, l }

/// Primary pill button — white/80 fill, black label (token 792af9ed).
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    this.size = _BtnSize.m,
    this.filled = true,
  });
  final String label;
  final VoidCallback onTap;
  final _BtnSize size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final big = size == _BtnSize.l;
    return _Hover(
      builder: (context, hovered) {
        final Color bg;
        final Color fg;
        Border? border;
        if (filled) {
          bg = hovered ? _white : _w80;
          fg = _black;
        } else {
          bg = hovered ? _w10 : const Color(0x00000000);
          fg = _white;
          border = Border.all(color: _w10);
        }
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
                horizontal: big ? 26 : 20, vertical: big ? 14 : 11),
            decoration: BoxDecoration(
              color: bg,
              border: border,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(label,
                style: _t(big ? 16 : 14.5,
                    w: FontWeight.w500, c: fg, ls: -0.2)),
          ),
        );
      },
    );
  }
}

/// Section chip: white/10 pill + cream dot + label.
/// `bare` variant (card kickers): dot + label, no pill.
class _Chip extends StatelessWidget {
  const _Chip(this.label, {this.bare = false});
  final String label;
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration:
              const BoxDecoration(color: _cream, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Text(label, style: _t(15, c: _w90, ls: -0.1)),
      ],
    );
    if (bare) {
      return row;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: _w10,
        borderRadius: BorderRadius.circular(100),
      ),
      child: row,
    );
  }
}

/// Split section header: chip + two-line heading (2nd line white/65) on the
/// left, body paragraph on the right (stacks on small screens).
class _SplitHeader extends StatelessWidget {
  const _SplitHeader({
    required this.sc,
    required this.chip,
    required this.line1,
    this.line2,
    this.body,
  });
  final ScrollController sc;
  final String chip;
  final String line1;
  final String? line2;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final heading = _Reveal(
      sc: sc,
      child: Text.rich(
        TextSpan(
          style: _h2(context),
          children: [
            TextSpan(text: line1),
            if (line2 != null)
              TextSpan(text: '\n$line2', style: _h2(context, c: _w65)),
          ],
        ),
      ),
    );
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Reveal(sc: sc, child: _Chip(chip)),
        const SizedBox(height: 28),
        heading,
      ],
    );
    if (body == null) {
      return left;
    }
    final right = _Reveal(
      sc: sc,
      child: Text(body!, style: _t(17, c: _w65, h: 1.6)),
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [left, const SizedBox(height: 24), right],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(flex: 7, child: left),
        const SizedBox(width: 64),
        Expanded(flex: 4, child: right),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Navigation
// ═════════════════════════════════════════════════════════════════════════════

class _Nav extends StatefulWidget {
  const _Nav({
    required this.sc,
    required this.onAbout,
    required this.onFeatures,
    required this.onPricing,
    required this.onBlog,
    required this.onContact,
    required this.onLogin,
    required this.onCta,
  });
  final ScrollController sc;
  final VoidCallback onAbout, onFeatures, onPricing, onBlog, onContact;
  final VoidCallback onLogin, onCta;

  @override
  State<_Nav> createState() => _NavState();
}

class _NavState extends State<_Nav> with SingleTickerProviderStateMixin {
  bool _open = false;
  // Appear: y -36 → 0 with fade, 1s tween, ease (0.44, 0, 0.56, 1).
  late final AnimationController _ac = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000))
    ..forward();
  late final Animation<double> _in =
      CurvedAnimation(parent: _ac, curve: _navEase);

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

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
    final narrow = MediaQuery.sizeOf(context).width < 960;
    return AnimatedBuilder(
      animation: _in,
      builder: (context, child) => Opacity(
        opacity: _in.value.clamp(0.0, 1.0),
        child: Transform.translate(
            offset: Offset(0, -36 * (1 - _in.value)), child: child),
      ),
      // The source nav is transparent — content scrolls underneath it.
      child: ColoredBox(
        color: _open ? _black : const Color(0x00000000),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 76,
                child: _Section(
                  child: Row(
                    children: [
                      const _Logo(),
                      const Spacer(),
                      if (!narrow) ...[
                        for (final (label, cb) in _links)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 22),
                            child: _NavLink(label: label, onTap: cb),
                          ),
                        const Spacer(),
                        _Hover(
                          builder: (context, hovered) => GestureDetector(
                            onTap: widget.onLogin,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              child: Text('Login',
                                  style: _t(15,
                                      c: hovered ? _white : _w80, ls: -0.1)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _PillButton(label: 'Get started', onTap: widget.onCta),
                      ] else
                        _Hover(
                          builder: (context, hovered) => GestureDetector(
                            onTap: () => setState(() => _open = !_open),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: hovered || _open ? _w10 : _w05,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _w10),
                              ),
                              child: Icon(
                                  _open
                                      ? Icons.close_rounded
                                      : Icons.menu_rounded,
                                  size: 19,
                                  color: _white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: (narrow && _open)
                    ? _Section(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final (label, cb) in _links)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _tapLink(cb),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Text(label,
                                        style:
                                            _t(17, w: FontWeight.w500)),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: _PillButton(
                                          label: 'Login',
                                          filled: false,
                                          onTap: () =>
                                              _tapLink(widget.onLogin)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Center(
                                      child: _PillButton(
                                          label: 'Get started',
                                          onTap: () =>
                                              _tapLink(widget.onCta)),
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
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.small = false});
  final bool small;

  @override
  Widget build(BuildContext context) {
    final box = small ? 24.0 : 30.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: box,
          height: box,
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(box * 0.32),
          ),
          alignment: Alignment.center,
          child: Text('f',
              style: _t(box * 0.62, w: FontWeight.w700, c: _black, h: 1.0)),
        ),
        SizedBox(width: small ? 8 : 10),
        Text('Fora.',
            style: _t(small ? 17 : 21, w: FontWeight.w600, ls: -0.5)),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: _t(15, c: hovered ? _white : _w80, ls: -0.1),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Hero — radial gradient, layered hills, content, app mockup
// ═════════════════════════════════════════════════════════════════════════════

class _Hero extends StatelessWidget {
  const _Hero({required this.sc, required this.onCta});
  final ScrollController sc;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final phone = _phone(context);
    return ClipRect(
      child: Stack(
        children: [
          // bg gradient — radial(200% 83% at 50% 0): #1b2228 → #353f44 → #d39794.
          // Fades in (0.5s spring).
          Positioned.fill(
            child: _Reveal(
              sc: sc,
              dy: 0,
              durationMs: 500,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.15,
                    colors: [_ink, _slate, _salmon],
                    stops: [0.0, 0.42, 1.0],
                    transform: _EllipseXScale(2.2),
                  ),
                ),
              ),
            ),
          ),
          // background far — hill silhouettes (rise 72 + fade).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: _Reveal(
                sc: sc,
                dy: 72,
                child: LayoutBuilder(
                  builder: (context, box) => SizedBox(
                    width: box.maxWidth,
                    height: box.maxWidth / (2464 / 909),
                    child: const _NetImg(_imgHillsFar, fit: BoxFit.fill),
                  ),
                ),
              ),
            ),
          ),
          // background near — closer hills (rise 48, no fade).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: _Reveal(
                sc: sc,
                dy: 48,
                fade: false,
                child: LayoutBuilder(
                  builder: (context, box) => SizedBox(
                    width: box.maxWidth,
                    height: box.maxWidth / (2464 / 848),
                    child: const _NetImg(_imgHillsNear, fit: BoxFit.fill),
                  ),
                ),
              ),
            ),
          ),
          _Section(
            child: Padding(
              padding: EdgeInsets.only(top: phone ? 130 : 170, bottom: 0),
              child: Column(
                children: [
                  _Reveal(
                    sc: sc,
                    delayMs: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: _w10,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text('Community platform for creators',
                          style: _t(14, c: _w90, ls: -0.1)),
                    ),
                  ),
                  const SizedBox(height: 26),
                  _Reveal(
                    sc: sc,
                    delayMs: 100,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Text(
                        'Your community deserves its own home.',
                        textAlign: TextAlign.center,
                        style: _h1(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Reveal(
                    sc: sc,
                    delayMs: 200,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Text(
                        'Fora gives creators, educators, and coaches a fully '
                        'branded space with courses, events, discussions, and '
                        'members.',
                        textAlign: TextAlign.center,
                        style: _t(phone ? 16 : 18, c: _w80, h: 1.55),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _Reveal(
                    sc: sc,
                    delayMs: 300,
                    child: _PillButton(
                        label: 'Get started free',
                        onTap: onCta,
                        size: _BtnSize.l),
                  ),
                  SizedBox(height: phone ? 56 : 88),
                  // foreground — the app mockup (rise 36, no fade).
                  _Reveal(
                    sc: sc,
                    dy: 36,
                    fade: false,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: _AppMockup(sc: sc),
                    ),
                  ),
                  SizedBox(height: phone ? 48 : 84),
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
// App mockup — "Strong By Ava" community preview (hero + final CTA)
// ═════════════════════════════════════════════════════════════════════════════

class _AppMockup extends StatelessWidget {
  const _AppMockup({required this.sc});
  final ScrollController sc;

  static const _navItems = <(IconData, String)>[
    (Icons.grid_view_rounded, 'Overview'),
    (Icons.chat_bubble_outline_rounded, 'Chat'),
    (Icons.bar_chart_rounded, 'Analytics'),
    (Icons.menu_book_outlined, 'Courses'),
    (Icons.calendar_today_outlined, 'Events'),
    (Icons.people_alt_outlined, 'Members'),
    (Icons.emoji_events_outlined, 'Leaderboard'),
  ];

  @override
  Widget build(BuildContext context) {
    final phone = _phone(context);
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: _panel21, // rgba(33,33,33,.85) — token feab5ab7
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _w10),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!phone) ...[
                  _sidebar(),
                  Container(width: 1, color: _w10),
                ],
                Expanded(child: _content(context, phone)),
              ],
            ),
          ),
        ),
        // Cream glow line at the bottom edge, masked to fade at both ends.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.9,
              child: Container(
                height: 2,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x00FAE6E1), _glow, Color(0x00FAE6E1)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sidebar() {
    return SizedBox(
      width: 196,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 10, bottom: 18),
              child: _Logo(small: true),
            ),
            for (var i = 0; i < _navItems.length; i++) _navItem(i),
          ],
        ),
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
              style: _t(13,
                  w: active ? FontWeight.w500 : FontWeight.w400,
                  c: active ? _white : _w65)),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, bool phone) {
    return Padding(
      padding: EdgeInsets.all(phone ? 14 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner: animated gradient canvas with hills overlay; the "S"
          // community avatar overlaps its bottom-left edge.
          SizedBox(
            height: phone ? 158 : 204,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  bottom: 36,
                  child: _AnimatedGradientBanner(radius: phone ? 12 : 16),
                ),
                Positioned(
                  left: phone ? 12 : 20,
                  bottom: 0,
                  child: _Reveal(
                    sc: sc,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child:
                          Text('S', style: _t(26, w: FontWeight.w600, c: _black)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Reveal(
            sc: sc,
            delayMs: 60,
            child: Text('Strong By Ava',
                style: _t(phone ? 17 : 19, w: FontWeight.w600, ls: -0.3)),
          ),
          const SizedBox(height: 10),
          _Reveal(
            sc: sc,
            delayMs: 120,
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  height: 20,
                  child: Stack(
                    children: [
                      _photoAvatar(_imgAvatar1, 0),
                      _photoAvatar(_imgAvatar2, 14),
                      _photoAvatar(_imgAvatar3, 28),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text('847 members', style: _t(13, c: _w65)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Reveal(
            sc: sc,
            delayMs: 180,
            child: _Hover(
              builder: (context, hovered) => Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: hovered ? _white : _w80,
                  borderRadius: BorderRadius.circular(100),
                ),
                alignment: Alignment.center,
                child: Text('Join now',
                    style: _t(14.5, w: FontWeight.w500, c: _black)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Reveal(
            sc: sc,
            delayMs: 240,
            child: Text(
              'Ava Torres is a certified strength coach with 80k+ followers '
              'on Instagram. → 12-week progressive training programs with '
              'video lessons → Weekly live Q&As and form-check threads → A '
              'supportive community of women training for strength',
              style: _t(13, c: _w65, h: 1.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoAvatar(String url, double left) {
    return Positioned(
      left: left,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF2A2A2A), width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: _NetImg(url),
      ),
    );
  }
}

/// The mockup banner: slow drifting gradient (the site renders this on a
/// canvas) with the transparent hills image overlaid at the bottom.
class _AnimatedGradientBanner extends StatefulWidget {
  const _AnimatedGradientBanner({this.radius = 16});
  final double radius;

  @override
  State<_AnimatedGradientBanner> createState() =>
      _AnimatedGradientBannerState();
}

class _AnimatedGradientBannerState extends State<_AnimatedGradientBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
      vsync: this, duration: const Duration(seconds: 6))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: AnimatedBuilder(
        animation: _ac,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_ac.value);
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.lerp(const Alignment(-1.3, -1.0),
                    const Alignment(-0.2, -1.0), t)!,
                end: Alignment.lerp(
                    const Alignment(1.0, 1.3), const Alignment(0.2, 1.0), t)!,
                colors: const [_slate, _salmon, _cream],
              ),
            ),
            child: child,
          );
        },
        child: const SizedBox.expand(
          child: _NetImg(_imgHillsBanner,
              fit: BoxFit.cover, alignment: Alignment.bottomCenter),
        ),
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
    final phone = _phone(context);
    return _Section(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: phone ? 80 : 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Reveal(sc: sc, child: const _Chip('Intro')),
            const SizedBox(height: 36),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _paragraphs.length; i++)
                    _Reveal(
                      sc: sc,
                      delayMs: i * 100,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: Text(_paragraphs[i], style: _h4(context)),
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
}

// ═════════════════════════════════════════════════════════════════════════════
// Core Features — segmented tab bar + gallery of product screenshots
// ═════════════════════════════════════════════════════════════════════════════

class _Features extends StatefulWidget {
  const _Features({required this.sc});
  final ScrollController sc;

  @override
  State<_Features> createState() => _FeaturesState();
}

class _FeaturesState extends State<_Features> {
  int _tab = 0;

  static const _tabs = ['Community', 'Courses', 'Events', 'Members'];
  static const _images = [
    _imgTabCommunity,
    _imgTabCourses,
    _imgTabEvents,
    _imgTabMembers,
  ];
  static const _captions = [
    'Post, discuss, react — the feed your members live in.',
    'Chapters and lessons your members learn from, inside your space.',
    'Live sessions and meetups with RSVP and calendar invites.',
    'Every member in one directory, one click away.',
  ];

  void _step(int dir) {
    setState(() => _tab = (_tab + dir + _tabs.length) % _tabs.length);
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phone(context);
    final sc = widget.sc;
    return _Section(
      child: Padding(
        padding: EdgeInsets.only(top: phone ? 40 : 60, bottom: phone ? 80 : 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SplitHeader(
              sc: sc,
              chip: 'Core Features',
              line1: 'One platform to run right',
              line2: 'your entire community.',
              body:
                  'Fora brings your courses, events, discussions, and members '
                  'into one space, so you stop switching between tools and '
                  'start spending time with your community.',
            ),
            SizedBox(height: phone ? 40 : 64),
            _Reveal(sc: sc, child: _tabBar(phone)),
            const SizedBox(height: 18),
            _Reveal(
              sc: sc,
              delayMs: 80,
              child: Row(
                children: [
                  _arrowButton(Icons.arrow_back_rounded, () => _step(-1)),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _captions[_tab],
                        key: ValueKey(_tab),
                        textAlign: TextAlign.center,
                        style: _t(15, c: _w65),
                      ),
                    ),
                  ),
                  _arrowButton(Icons.arrow_forward_rounded, () => _step(1)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _Reveal(
              sc: sc,
              delayMs: 140,
              scaleFrom: 1.04,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _w10),
                  color: _black85,
                ),
                clipBehavior: Clip.antiAlias,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      for (var i = 0; i < _images.length; i++)
                        AnimatedOpacity(
                          opacity: _tab == i ? 1 : 0,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                          child: _NetImg(_images[i]),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Radius-72 full-width bar; active segment gets a fading radius-66 pill
  /// (white/5 border layer over rgba(33,33,33,.85) fill — as exported).
  Widget _tabBar(bool phone) {
    return Container(
      height: phone ? 52 : 64,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _black85,
        borderRadius: BorderRadius.circular(72),
        border: Border.all(color: _w05),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: _Hover(
                builder: (context, hovered) => GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedOpacity(
                        opacity: _tab == i ? 1 : (hovered ? 0.35 : 0),
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _panel21,
                            borderRadius: BorderRadius.circular(66),
                            border: Border.all(color: _w10),
                          ),
                        ),
                      ),
                      Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: _t(phone ? 13.5 : 16,
                              w: FontWeight.w500,
                              c: _tab == i ? _white : _w65,
                              ls: -0.2),
                          child: Text(_tabs[i],
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _arrowButton(IconData icon, VoidCallback onTap) {
    return _Hover(
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: hovered ? _w10 : _black85,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _w10),
          ),
          child: Icon(icon, size: 18, color: _w80),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// What you get — scroll-linked stacked cards
// ═════════════════════════════════════════════════════════════════════════════

class _CardData {
  const _CardData({
    required this.kicker,
    required this.title,
    required this.body,
    required this.tagline,
    required this.img,
    required this.imageRight,
  });
  final String kicker, title, body, tagline, img;
  final bool imageRight;
}

const _aboutCards = <_CardData>[
  _CardData(
    kicker: 'Your front door',
    title: 'A community overview page that sells itself.',
    body: 'Customize your hero with a static color or animated gradient. Add '
        'a headline, a description and member avatars. Your overview page is '
        'the first thing a visitor sees — make it yours.',
    tagline: 'First impressions that convert.',
    img: _imgCardOverview,
    imageRight: true,
  ),
  _CardData(
    kicker: 'Friendly competition',
    title: 'A leaderboard your members actually check.',
    body: 'Rankings based on posts, completions, and activity — surfaced '
        'automatically. Gives your most engaged members a reason to stay and '
        'your quieter ones a reason to show up.',
    tagline: 'Engagement that compounds over time.',
    img: _imgCardLeaderboard,
    imageRight: false,
  ),
  _CardData(
    kicker: 'Courses',
    title: 'Build your course the way you teach.',
    body: 'Structure your content into chapters and lessons, in any order '
        'you want. Add your material, hit publish, and your members can start '
        'learning — right inside the community they already live in.',
    tagline: 'Courses that feel like yours, not a template.',
    img: _imgCardCourse,
    imageRight: true,
  ),
];

class _WhatYouGet extends StatelessWidget {
  const _WhatYouGet({required this.sc});
  final ScrollController sc;

  @override
  Widget build(BuildContext context) {
    final phone = _phone(context);
    return _Section(
      child: Padding(
        padding: EdgeInsets.only(bottom: phone ? 80 : 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SplitHeader(
              sc: sc,
              chip: 'What you get',
              line1: 'Set up once.',
              line2: 'Run it the way you want.',
              body:
                  'Fora is built so you spend time with your community, not '
                  'configuring it. From your first setting to your hundredth '
                  'member, the platform stays out of your way.',
            ),
            SizedBox(height: phone ? 40 : 64),
            _StackedCards(sc: sc),
          ],
        ),
      ),
    );
  }
}

/// Framer-style card stack: as the page scrolls the stack pins in place and
/// each next card rides up over the previous one (which dims underneath).
class _StackedCards extends StatelessWidget {
  const _StackedCards({required this.sc});
  final ScrollController sc;

  @override
  Widget build(BuildContext context) {
    final vh = MediaQuery.sizeOf(context).height;
    final phone = _phone(context);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        // Card height: portrait image pane (aspect 0.869) drives it on wide
        // layouts; capped to the viewport so a card always fits on screen.
        final double cardH;
        if (phone) {
          cardH = (vh * 0.72).clamp(420.0, 640.0);
        } else {
          cardH = ((w - 28) * 0.44 / 0.869 + 28).clamp(380.0, vh * 0.84);
        }
        final step = cardH * 0.92;
        final total = cardH + step * (_aboutCards.length - 1);
        return SizedBox(
          height: total,
          child: AnimatedBuilder(
            animation: sc,
            builder: (context, _) {
              double vpTop = 0;
              final ro = context.findRenderObject();
              if (ro is RenderBox && ro.attached) {
                vpTop = ro.localToGlobal(Offset.zero).dy;
              }
              // Pin position for the stack on screen.
              final pinTop = ((vh - cardH) / 2).clamp(24.0, 140.0);
              final local =
                  (pinTop - vpTop).clamp(0.0, step * (_aboutCards.length - 1));
              return Transform.translate(
                offset: Offset(0, local),
                child: SizedBox(
                  height: cardH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var i = 0; i < _aboutCards.length; i++)
                        _positionedCard(i, local, step, cardH, phone),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _positionedCard(
      int i, double local, double step, double cardH, bool phone) {
    final y = (step * i - local).clamp(0.0, double.infinity);
    // Incoming card rides in dimmed and brightens as it settles.
    final settle = i == 0 ? 1.0 : (1 - y / step).clamp(0.0, 1.0);
    final opacity = i == 0 ? 1.0 : 0.45 + 0.55 * settle;
    // Card being covered by the next one dims underneath.
    double covered = 0;
    if (i < _aboutCards.length - 1) {
      final nextY = (step * (i + 1) - local).clamp(0.0, double.infinity);
      covered = (1 - nextY / step).clamp(0.0, 1.0);
    }
    return Positioned(
      top: y,
      left: 0,
      right: 0,
      height: cardH,
      child: Opacity(
        opacity: opacity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _AboutCard(data: _aboutCards[i], sc: sc, phone: phone),
            if (covered > 0)
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: _black.withValues(alpha: 0.4 * covered),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard(
      {required this.data, required this.sc, required this.phone});
  final _CardData data;
  final ScrollController sc;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    // Outer shell: black/85 radius 24; inner panel: #0f0f0f/85 radius 16
    // with a white/10 border (two-layer border technique in the export).
    final copy = Padding(
      padding: EdgeInsets.all(phone ? 22 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Reveal(sc: sc, child: _Chip(data.kicker, bare: true)),
          SizedBox(height: phone ? 18 : 28),
          _Reveal(
            sc: sc,
            delayMs: 60,
            child: Text(data.title, style: _h4(context)),
          ),
          const SizedBox(height: 14),
          _Reveal(
            sc: sc,
            delayMs: 120,
            child: Text(data.body, style: _t(15, c: _w65, h: 1.6)),
          ),
          SizedBox(height: phone ? 18 : 26),
          _Reveal(
            sc: sc,
            delayMs: 180,
            child: Text(data.tagline, style: _t(15, c: _w80)),
          ),
        ],
      ),
    );

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: _Reveal(
        sc: sc,
        dy: 0,
        scaleFrom: 1.1,
        child: SizedBox.expand(child: _NetImg(data.img)),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: _black85,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(6),
      child: Container(
        decoration: BoxDecoration(
          color: _panel0f,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _w10),
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(8),
        child: phone
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: image),
                  copy,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: data.imageRight
                    ? [
                        Expanded(flex: 11, child: copy),
                        Expanded(flex: 9, child: image),
                      ]
                    : [
                        Expanded(flex: 9, child: image),
                        Expanded(flex: 11, child: copy),
                      ],
              ),
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
    final phone = _phone(context);
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    final cards = <Widget>[
      _PlanCard(
        plan: 'STARTER',
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
        plan: 'PRO',
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
        plan: 'ENTERPRISE',
        price: 'Custom price',
        period: null,
        blurb: 'For teams that need\nmore control.',
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
        padding: EdgeInsets.symmetric(vertical: phone ? 80 : 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SplitHeader(
              sc: sc,
              chip: 'Pricing',
              line1: 'Clear pricing plans',
              line2: 'that scale with you',
            ),
            SizedBox(height: phone ? 40 : 64),
            if (wide)
              _Reveal(
                sc: sc,
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
                  delayMs: 60,
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
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: featured ? _panel21 : _panel0f,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: featured ? (hovered ? _w40 : _w25) : (hovered ? _w25 : _w10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan, style: _mono(12, c: featured ? _cream : _w65)),
            const SizedBox(height: 20),
            if (period != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('\$',
                        style: _t(22, w: FontWeight.w500, c: _cream)),
                  ),
                  Text(price.replaceAll('\$', ''),
                      style: _t(48,
                          w: FontWeight.w500, c: _cream, h: 1.1, ls: -1.8)),
                  Padding(
                    padding: const EdgeInsets.only(top: 26, left: 4),
                    child: Text(period!, style: _t(14, c: _w40)),
                  ),
                ],
              )
            else
              Text(price,
                  style:
                      _t(34, w: FontWeight.w400, c: _cream, h: 1.2, ls: -1.0)),
            const SizedBox(height: 12),
            Text(blurb, style: _t(14.5, c: _w65, h: 1.5)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: _Hover(
                builder: (context, h2) => GestureDetector(
                  onTap: onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: featured
                          ? (h2 ? _white : _w80)
                          : (h2 ? _w10 : _w05),
                      borderRadius: BorderRadius.circular(100),
                      border: featured ? null : Border.all(color: _w10),
                    ),
                    alignment: Alignment.center,
                    child: Text(cta,
                        style: _t(15,
                            w: FontWeight.w500,
                            c: featured ? _black : _white)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            for (final f in features)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_rounded, size: 16, color: _cream),
                    const SizedBox(width: 10),
                    Expanded(child: Text(f, style: _t(14, c: _w80))),
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
  int _openIndex = -1; // all closed initially, as exported

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
    final phone = _phone(context);
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final sc = widget.sc;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Reveal(sc: sc, child: const _Chip('FAQ')),
        const SizedBox(height: 28),
        _Reveal(
          sc: sc,
          delayMs: 60,
          child: Text('Answers to the questions that come up most.',
              style: _h2(context)),
        ),
        const SizedBox(height: 18),
        _Reveal(
          sc: sc,
          delayMs: 120,
          child: Text(
            "Learn how Fora works, what's included in the beta, what your "
            'members experience, and what to expect as the platform grows.',
            style: _t(16, c: _w65, h: 1.6),
          ),
        ),
        const SizedBox(height: 28),
        _Reveal(
          sc: sc,
          delayMs: 180,
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
          delayMs: 240,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: _panel0f,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _w10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Got Questions?',
                    style: _t(18, w: FontWeight.w500, c: _cream)),
                const SizedBox(height: 8),
                Text(
                  "Can't find what you're looking for? Reach out — we're fast.",
                  style: _t(14.5, c: _w65, h: 1.55),
                ),
                const SizedBox(height: 18),
                _Hover(
                  builder: (context, hovered) => GestureDetector(
                    onTap: widget.onContact,
                    child: Text('Contact us →',
                        style: _t(14.5,
                            w: FontWeight.w500,
                            c: hovered ? _cream : _white)),
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
            delayMs: 50 * i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _faqTile(i),
            ),
          ),
      ],
    );

    return _Section(
      child: Padding(
        padding: EdgeInsets.only(bottom: phone ? 80 : 140),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: left),
                  const SizedBox(width: 64),
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
          _openIndex = -1;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: active ? _panel21 : (hovered ? _w10 : _w05),
            border: Border.all(color: active ? _w25 : _w10),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(_categories[i],
              style: _t(14, w: FontWeight.w500, c: active ? _white : _w65)),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: open || hovered ? _panel0f : _black85,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: open ? _w25 : _w10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(q,
                          style: _t(16, w: FontWeight.w500, c: _cream))),
                  const SizedBox(width: 12),
                  AnimatedRotation(
                    turns: open ? 0.125 : 0,
                    duration: const Duration(milliseconds: 220),
                    child:
                        const Icon(Icons.add_rounded, size: 20, color: _w65),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 24),
                  child: Text(a, style: _t(14.5, c: _w65, h: 1.65)),
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

  static const _posts = <(String, String, String, String)>[
    (
      'Fora vs Mighty Networks: Full Comparison for Creators & Educators '
          '(2026)',
      'Comparisons',
      'Jun 3, 2026',
      _imgBlog1,
    ),
    (
      'How to Launch an Online Community in 2026: A Step-by-Step Guide',
      'Guides',
      'Jun 3, 2026',
      _imgBlog2,
    ),
    (
      'Best White-Label Community Platform for Coaches & Educators',
      'Community Building',
      'Jun 3, 2026',
      _imgBlog3,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final phone = _phone(context);
    final wide = MediaQuery.sizeOf(context).width >= 940;
    return _Section(
      child: Padding(
        padding: EdgeInsets.only(bottom: phone ? 80 : 140),
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
                        const _Chip('Blog'),
                        const SizedBox(height: 28),
                        Text('Ideas, updates, and practical AI workflows',
                            style: _h2(context)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  _Hover(
                    builder: (context, hovered) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Visit blog →',
                          style: _t(15,
                              w: FontWeight.w500,
                              c: hovered ? _cream : _w80)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: phone ? 32 : 56),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _posts.length; i++) ...[
                    if (i > 0) const SizedBox(width: 20),
                    Expanded(
                      child: _Reveal(
                          sc: sc, delayMs: 80 * i, child: _postCard(context, i)),
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
                    child: _postCard(context, i),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _postCard(BuildContext context, int i) {
    final (title, category, date, img) = _posts[i];
    return _Hover(
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _panel0f,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: hovered ? _w25 : _w10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: AnimatedScale(
                scale: hovered ? 1.04 : 1.0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                child: _NetImg(img),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: _t(17,
                          w: FontWeight.w500, c: _cream, h: 1.4, ls: -0.2)),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          color: _w05,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: _w10),
                        ),
                        child: Text(category, style: _t(12, c: _w80)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(date,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _t(12.5, c: _w40)),
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
// Final CTA — heading + button + mockup over the dunes
// ═════════════════════════════════════════════════════════════════════════════

class _FinalCta extends StatelessWidget {
  const _FinalCta({required this.sc, required this.onCta});
  final ScrollController sc;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final phone = _phone(context);
    return ClipRect(
      child: Stack(
        children: [
          // Sand dunes anchored to the section bottom, full width.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: _Reveal(
                sc: sc,
                dy: 48,
                child: LayoutBuilder(
                  builder: (context, box) => SizedBox(
                    width: box.maxWidth,
                    height: box.maxWidth / (1600 / 349),
                    child: const _NetImg(_imgDunes, fit: BoxFit.fill),
                  ),
                ),
              ),
            ),
          ),
          _Section(
            child: Padding(
              padding: EdgeInsets.only(top: phone ? 40 : 60, bottom: 48),
              child: Column(
                children: [
                  _Reveal(
                    sc: sc,
                    child: Text('Your community is one sec away.',
                        textAlign: TextAlign.center, style: _h2(context)),
                  ),
                  const SizedBox(height: 18),
                  _Reveal(
                    sc: sc,
                    delayMs: 80,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Text(
                        'Fora is in beta and free to join. Set up your space, '
                        'invite your first members, and see what it feels like '
                        'when everything lives in one place — under your name.',
                        textAlign: TextAlign.center,
                        style: _t(phone ? 15.5 : 17, c: _w65, h: 1.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _Reveal(
                    sc: sc,
                    delayMs: 160,
                    child: _PillButton(
                        label: 'Start for free',
                        onTap: onCta,
                        size: _BtnSize.l),
                  ),
                  SizedBox(height: phone ? 48 : 72),
                  _Reveal(
                    sc: sc,
                    dy: 36,
                    fade: false,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: _AppMockup(sc: sc),
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
    required this.onContact,
  });
  final VoidCallback onAbout, onPricing, onBlog, onContact;

  @override
  Widget build(BuildContext context) {
    final phone = _phone(context);
    final wide = MediaQuery.sizeOf(context).width >= 860;

    final columns = <Widget>[
      _col('Product', [
        ('About', onAbout),
        ('Pricing', onPricing),
        ('Blog', onBlog),
        ('Contact', onContact),
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

    return DecoratedBox(
      decoration:
          const BoxDecoration(border: Border(top: BorderSide(color: _w10))),
      child: _Section(
        child: Padding(
          padding: EdgeInsets.only(top: phone ? 48 : 80, bottom: 32),
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
                Wrap(spacing: 56, runSpacing: 32, children: columns),
              ],
              SizedBox(height: phone ? 40 : 64),
              // Directory badges, as on the site footer.
              Wrap(
                spacing: 14,
                runSpacing: 12,
                children: const [
                  _FooterBadge.svg(_badgeFindly),
                  _FooterBadge.svg(_badgeTurbo0),
                  _FooterBadge.img(_badgeStartupFame),
                  _FooterBadge.svg(_badgeTwelve),
                ],
              ),
              const SizedBox(height: 32),
              const Divider(color: _w10, height: 1),
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                children: [
                  Text('© Fora. 2026. All rights reserved',
                      style: _t(13, c: _w40)),
                  Text('contact@fora.so', style: _t(13, c: _w40)),
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
        Text(title, style: _t(14, c: _w40)),
        const SizedBox(height: 18),
        for (final (label, cb) in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Hover(
              builder: (context, hovered) => GestureDetector(
                onTap: cb,
                child:
                    Text(label, style: _t(14.5, c: hovered ? _white : _w80)),
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
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            'White-label community platform for creators, educators, and '
            'coaches.',
            style: _t(13.5, c: _w40, h: 1.55),
          ),
        ),
      ],
    );
  }
}

class _FooterBadge extends StatelessWidget {
  const _FooterBadge.svg(this.url) : isSvg = true;
  const _FooterBadge.img(this.url) : isSvg = false;
  final String url;
  final bool isSvg;

  @override
  Widget build(BuildContext context) {
    const h = 44.0;
    if (isSvg) {
      return SvgPicture.network(
        url,
        height: h,
        placeholderBuilder: (context) =>
            const SizedBox(height: h, width: 120),
      );
    }
    return SizedBox(
      height: h,
      child: Image.network(
        url,
        height: h,
        errorBuilder: (context, error, stack) =>
            const SizedBox(height: h, width: 120),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Floating chat bubble (bottom-right, as on the site)
// ═════════════════════════════════════════════════════════════════════════════

class _ChatBubble extends StatelessWidget {
  const _ChatBubble();

  @override
  Widget build(BuildContext context) {
    return _Hover(
      builder: (context, hovered) => AnimatedScale(
        scale: hovered ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFF222222),
            shape: BoxShape.circle,
            border: Border.all(color: _w10),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.mode_comment, color: _white, size: 22),
        ),
      ),
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
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
        alignment: 0.02);
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
                      key: _featuresKey, child: _Features(sc: _sc)),
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
                      onContact: () => _scrollTo(_contactKey),
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
                sc: _sc,
                onAbout: () => _scrollTo(_aboutKey),
                onFeatures: () => _scrollTo(_featuresKey),
                onPricing: () => _scrollTo(_pricingKey),
                onBlog: () => _scrollTo(_blogKey),
                onContact: () => _scrollTo(_contactKey),
                onLogin: _goAuth,
                onCta: _goAuth,
              ),
            ),
            const Positioned(right: 22, bottom: 22, child: _ChatBubble()),
          ],
        ),
      ),
    );
  }
}
