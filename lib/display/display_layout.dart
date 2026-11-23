import 'dart:math' as math;
import 'dart:ui';

/// A connected monitor as reported by Windows, in physical pixels.
class DisplayInfo {
  const DisplayInfo({
    required this.id,
    required this.bounds,
    required this.workArea,
    required this.scale,
    required this.primary,
  });

  factory DisplayInfo.fromNative(Map<Object?, Object?> m) {
    Rect rect(String prefix) => Rect.fromLTWH(
      (m['${prefix}Left'] as num).toDouble(),
      (m['${prefix}Top'] as num).toDouble(),
      (m['${prefix}Width'] as num).toDouble(),
      (m['${prefix}Height'] as num).toDouble(),
    );
    return DisplayInfo(
      id: m['id'] as String,
      bounds: rect('bounds'),
      workArea: rect('work'),
      scale: (m['scale'] as num).toDouble(),
      primary: m['primary'] as bool,
    );
  }

  /// Windows device name, e.g. `\\.\DISPLAY1`. Stable while cabling is unchanged.
  final String id;
  final Rect bounds;
  final Rect workArea;
  final double scale;
  final bool primary;

  /// The number Windows shows in Display settings, taken from the device name.
  String get number => RegExp(r'(\d+)$').firstMatch(id)?.group(1) ?? '?';
}

/// Picks the display the overlay should use: the saved one when still
/// connected, otherwise the primary.
DisplayInfo? resolveDisplay(List<DisplayInfo> displays, String? savedId) =>
    displays.where((d) => d.id == savedId).firstOrNull ??
    displays.where((d) => d.primary).firstOrNull ??
    displays.firstOrNull;

/// Top-left corner for an overlay of [size] placed inside [area] at the given
/// 0..1 alignment, keeping [margin] from the edges and never leaving the area.
/// The C++ overlay uses the same rule; keep the two in step.
Offset overlayOrigin(Rect area, Size size, double alignX, double alignY, double margin) {
  double axis(double start, double extent, double item, double align) {
    final min = start + margin;
    final max = start + extent - margin - item;
    if (max <= min) return start + math.max(0, (extent - item) / 2);
    return min + (max - min) * align.clamp(0.0, 1.0);
  }

  return Offset(axis(area.left, area.width, size.width, alignX), axis(area.top, area.height, size.height, alignY));
}

/// Scales the whole desktop arrangement to fit in [box], preserving aspect
/// ratio and relative monitor positions. Returns one rect per display.
Map<String, Rect> previewLayout(List<DisplayInfo> displays, Size box, {double gap = 6}) {
  if (displays.isEmpty) return {};
  final union = displays.map((d) => d.bounds).reduce((a, b) => a.expandToInclude(b));
  final scale = math.min(box.width / union.width, box.height / union.height);
  final offset = Offset((box.width - union.width * scale) / 2, (box.height - union.height * scale) / 2);
  return {
    for (final d in displays)
      d.id: Rect.fromLTWH(
        offset.dx + (d.bounds.left - union.left) * scale,
        offset.dy + (d.bounds.top - union.top) * scale,
        d.bounds.width * scale,
        d.bounds.height * scale,
      ).deflate(displays.length > 1 ? gap / 2 : 0),
  };
}
