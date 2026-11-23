enum CursorShape { circle, diamond, square, crosshair, target, dot }

/// A cursor highlight style. Index order of [CursorShape] is shared with the
/// native renderer.
class CursorTemplate {
  const CursorTemplate(
    this.id,
    this.name,
    this.shape, {
    this.filled = false,
    this.dashed = false,
    this.doubleRing = false,
  });

  final String id;
  final String name;
  final CursorShape shape;
  final bool filled;
  final bool dashed;
  final bool doubleRing;

  Map<String, Object?> toNative() => {
    'shape': shape.index,
    'filled': filled,
    'dashed': dashed,
    'doubleRing': doubleRing,
  };
}

const cursorTemplates = <CursorTemplate>[
  CursorTemplate('ring', 'Ring', CursorShape.circle),
  CursorTemplate('disc', 'Disc', CursorShape.circle, filled: true),
  CursorTemplate('halo', 'Halo', CursorShape.circle, filled: true, doubleRing: true),
  CursorTemplate('double-ring', 'Double ring', CursorShape.circle, doubleRing: true),
  CursorTemplate('dashed-ring', 'Dashed ring', CursorShape.circle, dashed: true),
  CursorTemplate('dashed-disc', 'Dashed disc', CursorShape.circle, filled: true, dashed: true),
  CursorTemplate('diamond', 'Diamond', CursorShape.diamond),
  CursorTemplate('solid-diamond', 'Solid diamond', CursorShape.diamond, filled: true),
  CursorTemplate('square', 'Square', CursorShape.square),
  CursorTemplate('solid-square', 'Solid square', CursorShape.square, filled: true),
  CursorTemplate('crosshair', 'Crosshair', CursorShape.crosshair),
  CursorTemplate('target', 'Target', CursorShape.target),
  CursorTemplate('dot', 'Dot', CursorShape.dot, filled: true),
];

CursorTemplate cursorTemplateById(String id) =>
    cursorTemplates.firstWhere((t) => t.id == id, orElse: () => cursorTemplates.first);
