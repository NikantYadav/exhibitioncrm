import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// 3D isometric "boxes" loader, replicating the Uiverse loader by Nawsome.
/// Four cubes shuffle positions on a grid in an isometric projection.
class BoxesLoader extends StatefulWidget {
  /// Edge length of one cube in logical pixels (CSS `--size`).
  final double size;
  const BoxesLoader({super.key, this.size = 32});

  @override
  State<BoxesLoader> createState() => _BoxesLoaderState();
}

class _BoxesLoaderState extends State<BoxesLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final accent = AppTheme.colorsOf(context).accent;
    final canvasSize = s * 4.2;
    return SizedBox(
      width: canvasSize,
      height: canvasSize,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _BoxesPainter(t: _controller.value, size: s, accent: accent),
            size: Size(canvasSize, canvasSize),
          );
        },
      ),
    );
  }
}

class _BoxesPainter extends CustomPainter {
  final double t;
  final double size;
  final Color accent;

  const _BoxesPainter({required this.t, required this.size, required this.accent});

  // Derive face shades from accent: top=base, right=darker, front=mid, shadow=very light
  Color get _top => accent;
  Color get _right => Color.lerp(accent, Colors.black, 0.35)!;
  Color get _front => Color.lerp(accent, Colors.black, 0.15)!;
  Color get _shadow => Color.lerp(accent, Colors.white, 0.75)!;

  // Projection matching CSS `rotateX(60deg) rotateZ(45deg)`.
  // Grid +x -> screen (cos45, cos60*sin45) = (0.707, 0.354)
  // Grid +y -> screen (-cos45, cos60*cos45) = (-0.707, 0.354)
  // Height +z -> screen (0, -sin60) = (0, -0.866)
  static const double _hx = 0.7071; // cos45
  static const double _hy = 0.3536; // cos60 * sin45
  static const double _vz = 0.8660; // sin60

  Offset _project(double gx, double gy) {
    final sx = (gx - gy) * size * _hx;
    final sy = (gx + gy) * size * _hy;
    return Offset(sx, sy);
  }

  // Each box's grid position over the animation, per the CSS keyframes.
  // Positions are in grid units where 100% == 1 cell.
  // p: 0..1 phase for this box.
  Offset _box1(double p) {
    // 0%,50%: (1,0) ; 100%: (2,0)
    if (p <= 0.5) return const Offset(1, 0);
    return Offset(1 + (p - 0.5) / 0.5, 0);
  }

  Offset _box2(double p) {
    // 0%:(0,1) 50%:(0,0) 100%:(1,0)
    if (p <= 0.5) return Offset(0, 1 - p / 0.5);
    return Offset((p - 0.5) / 0.5, 0);
  }

  Offset _box3(double p) {
    // 0%,50%:(1,1) 100%:(0,1)
    if (p <= 0.5) return const Offset(1, 1);
    return Offset(1 - (p - 0.5) / 0.5, 1);
  }

  Offset _box4(double p) {
    // 0%:(2,0) 50%:(2,1) 100%:(1,1)
    if (p <= 0.5) return Offset(2, p / 0.5);
    return Offset(2 - (p - 0.5) / 0.5, 1);
  }

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Center the grid in the canvas.
    canvas.translate(canvasSize.width / 2, canvasSize.height * 0.35);

    final boxes = [_box1(t), _box2(t), _box3(t), _box4(t)];

    // Painter's algorithm: draw far cells first (smaller gx+gy drawn first
    // so nearer boxes overlap correctly).
    final ordered = List<Offset>.from(boxes)
      ..sort((a, b) => (a.dx + a.dy).compareTo(b.dx + b.dy));

    // All ground shadows first, behind every cube.
    for (final g in ordered) {
      _drawShadow(canvas, g.dx, g.dy);
    }
    for (final g in ordered) {
      _drawCube(canvas, g.dx, g.dy);
    }
  }

  // child4 #DBE3F4, pushed back (down) by 3 cube heights — the ground shadow.
  void _drawShadow(Canvas canvas, double gx, double gy) {
    final sh = Offset(0, size * _vz * 3);
    final b00 = _project(gx, gy) + sh;
    final b10 = _project(gx + 1, gy) + sh;
    final b11 = _project(gx + 1, gy + 1) + sh;
    final b01 = _project(gx, gy + 1) + sh;
    _fill(canvas, [b00, b10, b11, b01], _shadow);
  }

  void _drawCube(Canvas canvas, double gx, double gy) {
    // Cube corners in grid space. Top face is at "height" 1 above the cell.
    // We model height as an upward screen offset of one cube edge.
    final dz = Offset(0, -size * _vz); // vertical lift for cube height

    // Base (bottom) square corners at grid cell.
    final b00 = _project(gx, gy);
    final b10 = _project(gx + 1, gy);
    final b11 = _project(gx + 1, gy + 1);
    final b01 = _project(gx, gy + 1);

    // Top square = base lifted by dz.
    final t00 = b00 + dz;
    final t10 = b10 + dz;
    final t11 = b11 + dz;
    final t01 = b01 + dz;

    // Front face (toward viewer, bottom edge) — child3 #447cf5
    _fill(canvas, [b01, b11, t11, t01], _front);
    // Right face — child2 #145af2
    _fill(canvas, [b11, b10, t10, t11], _right);
    // Top face — child1 #5C8DF6
    _fill(canvas, [t00, t10, t11, t01], _top);
  }

  void _fill(Canvas canvas, List<Offset> pts, Color color) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_BoxesPainter old) => old.t != t || old.size != size || old.accent != accent;
}
