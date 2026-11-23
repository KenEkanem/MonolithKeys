import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../cursor/cursor_templates.dart';
import '../keystroke/composer.dart';
import '../keystroke/key_templates.dart';
import '../keystroke/keys.dart';

/// Draws strokes the way the native overlay does, for the settings previews.
class KeystrokePreview extends StatelessWidget {
  const KeystrokePreview({
    super.key,
    required this.strokes,
    required this.template,
    required this.colors,
    this.scale = 1,
  });

  final List<Stroke> strokes;
  final KeyTemplate template;
  final KeyColorTheme colors;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final t = template;
    final h = t.height * scale;
    final gap = h * 0.12;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, s) in strokes.indexed) ...[
          if (i > 0) SizedBox(width: gap * 2.5),
          if (t.presentation)
            _cap(strokeText(s), null, CapGlyph.none, capColors(t, colors, modifier: false), h)
          else
            for (final (j, cap) in s.caps.indexed) ...[
              if (j > 0) SizedBox(width: gap),
              _cap(cap.label, cap.symbol, cap.glyph, capColors(t, colors, modifier: cap.isModifier), h),
            ],
          // The repeat count is drawn as one more cap, like the native overlay.
          if (s.count > 1) ...[
            SizedBox(width: gap),
            _cap('×${s.count}', null, CapGlyph.none, capColors(t, colors, modifier: false), h),
          ],
        ],
      ],
    );
  }

  Widget _cap(String label, String? symbol, CapGlyph glyph, CapColors c, double h) {
    final t = template;
    final depth = t.depth * scale;
    final style = TextStyle(
      color: c.text,
      fontSize: t.fontSize * scale,
      fontWeight: FontWeight.values[(t.fontWeight ~/ 100 - 1).clamp(0, 8)],
      height: 1,
    );
    final radius = BorderRadius.circular(t.radius * scale);
    return Container(
      height: h,
      constraints: BoxConstraints(minWidth: h),
      padding: EdgeInsets.only(bottom: depth),
      decoration: BoxDecoration(color: c.edge, borderRadius: radius),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: h * 0.3),
        decoration: BoxDecoration(
          color: c.face,
          borderRadius: radius,
          border: t.border > 0 ? Border.all(color: c.border, width: t.border * scale) : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyph != CapGlyph.none) ...[
              CustomPaint(size: Size.square(style.fontSize!), painter: CapGlyphPainter(glyph, c.text)),
              SizedBox(width: h * 0.12),
            ],
            if (symbol != null) Text('$symbol ', style: style),
            Text(label, style: style),
          ],
        ),
      ),
    );
  }
}

/// The Windows logo and mouse glyphs drawn inside caps.
class CapGlyphPainter extends CustomPainter {
  const CapGlyphPainter(this.glyph, this.color);

  final CapGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final fill = Paint()..color = color;
    if (glyph == CapGlyph.windows) {
      final g = s * 0.08;
      final q = (s - g) / 2;
      for (final (x, y) in [(0.0, 0.0), (q + g, 0.0), (0.0, q + g), (q + g, q + g)]) {
        canvas.drawRect(Rect.fromLTWH(x, y, q, q), fill);
      }
      return;
    }
    // Mouse body, with the pressed button or wheel direction filled in.
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.2, 0, s * 0.6, s), Radius.circular(s * 0.3));
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.08;
    canvas.drawRRect(body.deflate(s * 0.04), outline);
    canvas.drawLine(Offset(s * 0.2, s * 0.42), Offset(s * 0.8, s * 0.42), outline);
    final top = Rect.fromLTWH(s * 0.2, 0, s * 0.6, s * 0.42);
    switch (glyph) {
      case CapGlyph.mouseLeft:
        canvas.save();
        canvas.clipRRect(body);
        canvas.drawRect(Rect.fromLTRB(top.left, top.top, top.center.dx, top.bottom), fill);
        canvas.restore();
      case CapGlyph.mouseRight:
        canvas.save();
        canvas.clipRRect(body);
        canvas.drawRect(Rect.fromLTRB(top.center.dx, top.top, top.right, top.bottom), fill);
        canvas.restore();
      case CapGlyph.mouseMiddle || CapGlyph.wheelUp || CapGlyph.wheelDown:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(s / 2, s * 0.22), width: s * 0.14, height: s * 0.24),
            Radius.circular(s * 0.07),
          ),
          fill,
        );
      case CapGlyph.none || CapGlyph.windows:
        break;
    }
  }

  @override
  bool shouldRepaint(CapGlyphPainter old) => old.glyph != glyph || old.color != color;
}

/// Paints a cursor highlight template. Geometry matches the C++ renderer.
class CursorShapePainter extends CustomPainter {
  const CursorShapePainter(this.template, this.color, {this.glow = 0});

  final CursorTemplate template;
  final Color color;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2 / (1 + glow * 0.35);
    final c = size.center(Offset.zero);
    final w = math.max(2.0, r * 0.14);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    final fill = Paint()..color = color;
    if (glow > 0) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = color.withValues(alpha: color.a * 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.outer, r * 0.35 * glow),
      );
    }

    Path outline(double radius) => switch (template.shape) {
      CursorShape.diamond =>
        Path()
          ..moveTo(c.dx, c.dy - radius)
          ..lineTo(c.dx + radius, c.dy)
          ..lineTo(c.dx, c.dy + radius)
          ..lineTo(c.dx - radius, c.dy)
          ..close(),
      CursorShape.square =>
        Path()..addRRect(
          RRect.fromRectAndRadius(Rect.fromCircle(center: c, radius: radius * 0.86), Radius.circular(radius * 0.3)),
        ),
      _ => Path()..addOval(Rect.fromCircle(center: c, radius: radius)),
    };

    switch (template.shape) {
      case CursorShape.dot:
        canvas.drawCircle(c, r * 0.3, fill);
        return;
      case CursorShape.crosshair || CursorShape.target:
        final thin = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.7;
        final inner = template.shape == CursorShape.target ? 0.0 : r * 0.3;
        for (final d in [const Offset(1, 0), const Offset(-1, 0), const Offset(0, 1), const Offset(0, -1)]) {
          canvas.drawLine(c + d * inner, c + d * r, thin);
        }
        canvas.drawCircle(c, r - w / 2, thin);
        if (template.shape == CursorShape.target) canvas.drawCircle(c, r * 0.45, thin);
        return;
      case CursorShape.circle || CursorShape.diamond || CursorShape.square:
        final outer = outline(r - w / 2);
        final ring = template.dashed ? _dashed(outer, w * 1.6, w * 1.2) : outer;
        if (template.filled) {
          canvas.drawPath(outline(template.doubleRing ? r * 0.62 : r), fill);
          if (template.doubleRing) canvas.drawPath(ring, stroke);
          if (template.dashed) canvas.drawPath(ring, stroke..color = color.withValues(alpha: 1));
        } else {
          canvas.drawPath(ring, stroke);
          if (template.doubleRing) canvas.drawPath(outline(r * 0.62), stroke..strokeWidth = w * 0.7);
        }
    }
  }

  static Path _dashed(Path source, double on, double off) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += on + off) {
        out.addPath(metric.extractPath(d, math.min(d + on, metric.length)), Offset.zero);
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(CursorShapePainter old) => old.template != template || old.color != color || old.glow != glow;
}

/// The MonolithKeys mark: a tall key cap on a dark tile. The app icon is
/// generated from the same proportions (tool/make_icon.sh).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: const _BrandMarkPainter());
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    RRect rr(double x, double y, double w, double h, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x * s, y * s, w * s, h * s), Radius.circular(r * s));
    canvas.drawRRect(rr(0, 0, 1, 1, 0.22), Paint()..color = const Color(0xFF16181D));
    canvas.drawRRect(rr(0.30, 0.17, 0.40, 0.68, 0.09), Paint()..color = const Color(0xFF2F6FED));
    canvas.drawRRect(rr(0.30, 0.17, 0.40, 0.60, 0.09), Paint()..color = const Color(0xFFF4F5F7));
    canvas.drawRRect(rr(0.36, 0.23, 0.28, 0.46, 0.06), Paint()..color = const Color(0xFFE1E4EA));
  }

  @override
  bool shouldRepaint(_BrandMarkPainter old) => false;
}
