import 'dart:ui' show Color;

import 'composer.dart';
import 'keys.dart';

/// Shape and typography of a key-cap template, in logical pixels at 100%.
class KeyTemplate {
  const KeyTemplate({
    required this.id,
    required this.name,
    required this.radius,
    required this.depth,
    required this.border,
    required this.height,
    required this.fontSize,
    required this.fontWeight,
    this.accentModifiers = false,
    this.presentation = false,
  });

  final String id;
  final String name;
  final double radius;

  /// Height of the darker bottom edge that gives caps a pressed-key look.
  final double depth;
  final double border;
  final double height;
  final double fontSize;
  final int fontWeight;

  /// Modifiers use the theme's accent colour instead of the cap colour.
  final bool accentModifiers;

  /// Draws each stroke as a single text pill ("Ctrl + K") instead of caps.
  final bool presentation;
}

class KeyColorTheme {
  const KeyColorTheme(
    this.id,
    this.name, {
    required this.face,
    required this.edge,
    required this.text,
    required this.accent,
    required this.accentText,
  });

  final String id;
  final String name;
  final Color face;
  final Color edge;
  final Color text;
  final Color accent;
  final Color accentText;
}

const keyTemplates = <KeyTemplate>[
  KeyTemplate(
    id: 'classic',
    name: 'Classic',
    radius: 8,
    depth: 4,
    border: 0,
    height: 52,
    fontSize: 19,
    fontWeight: 600,
  ),
  KeyTemplate(
    id: 'minimal',
    name: 'Minimal',
    radius: 6,
    depth: 0,
    border: 1.5,
    height: 44,
    fontSize: 17,
    fontWeight: 500,
  ),
  KeyTemplate(id: 'soft', name: 'Soft', radius: 16, depth: 2, border: 0, height: 50, fontSize: 18, fontWeight: 600),
  KeyTemplate(
    id: 'accent',
    name: 'Accent',
    radius: 8,
    depth: 4,
    border: 0,
    height: 52,
    fontSize: 19,
    fontWeight: 600,
    accentModifiers: true,
  ),
  KeyTemplate(
    id: 'presentation',
    name: 'Presentation',
    radius: 12,
    depth: 0,
    border: 0,
    height: 52,
    fontSize: 21,
    fontWeight: 600,
    presentation: true,
  ),
];

const _white = Color(0xFFFFFFFF);
const _ink = Color(0xFF1F2328);

const keyColors = <KeyColorTheme>[
  KeyColorTheme(
    'graphite',
    'Graphite',
    face: Color(0xFF2B2D31),
    edge: Color(0xFF141518),
    text: Color(0xFFF4F4F5),
    accent: Color(0xFF2F6FED),
    accentText: _white,
  ),
  KeyColorTheme(
    'snow',
    'Snow',
    face: Color(0xFFF7F7F8),
    edge: Color(0xFFC4C7CE),
    text: _ink,
    accent: Color(0xFF2F6FED),
    accentText: _white,
  ),
  KeyColorTheme(
    'rose',
    'Rose',
    face: Color(0xFFE35D8C),
    edge: Color(0xFFA83A63),
    text: _white,
    accent: Color(0xFF2B2D31),
    accentText: _white,
  ),
  KeyColorTheme(
    'crimson',
    'Crimson',
    face: Color(0xFFD14343),
    edge: Color(0xFF93292A),
    text: _white,
    accent: Color(0xFF2B2D31),
    accentText: _white,
  ),
  KeyColorTheme(
    'ocean',
    'Ocean',
    face: Color(0xFF2E78DB),
    edge: Color(0xFF1C539F),
    text: _white,
    accent: Color(0xFF2B2D31),
    accentText: _white,
  ),
  KeyColorTheme(
    'forest',
    'Forest',
    face: Color(0xFF3B9356),
    edge: Color(0xFF27673B),
    text: _white,
    accent: Color(0xFF2B2D31),
    accentText: _white,
  ),
  KeyColorTheme(
    'violet',
    'Violet',
    face: Color(0xFF8457EE),
    edge: Color(0xFF5B35BE),
    text: _white,
    accent: Color(0xFF2B2D31),
    accentText: _white,
  ),
  KeyColorTheme(
    'amber',
    'Amber',
    face: Color(0xFFF0B232),
    edge: Color(0xFFB98414),
    text: Color(0xFF2A1F05),
    accent: Color(0xFF2B2D31),
    accentText: _white,
  ),
  KeyColorTheme(
    'teal',
    'Teal',
    face: Color(0xFF1AAE9F),
    edge: Color(0xFF117F74),
    text: _white,
    accent: Color(0xFF2B2D31),
    accentText: _white,
  ),
];

KeyTemplate keyTemplateById(String id) => keyTemplates.firstWhere((t) => t.id == id, orElse: () => keyTemplates.first);

KeyColorTheme keyColorById(String id) => keyColors.firstWhere((c) => c.id == id, orElse: () => keyColors.first);

/// Colours for one cap after the template rules are applied.
class CapColors {
  const CapColors(this.face, this.edge, this.text, this.border);

  final Color face;
  final Color edge;
  final Color text;
  final Color border;
}

CapColors capColors(KeyTemplate t, KeyColorTheme c, {required bool modifier}) {
  if (t.accentModifiers && modifier) {
    return CapColors(c.accent, Color.lerp(c.accent, const Color(0xFF000000), 0.35)!, c.accentText, c.accent);
  }
  if (t.border > 0) {
    return CapColors(c.face, c.edge, c.text, Color.lerp(c.face, c.text, 0.35)!);
  }
  return CapColors(c.face, c.edge, c.text, c.face);
}

/// Text used for a stroke in presentation mode.
String strokeText(Stroke s) => s.caps.map((c) => c.symbol == null ? c.label : '${c.symbol} ${c.label}').join(' + ');

/// Everything the native overlay needs to draw [strokes], with sizes already
/// multiplied by [scale] so the C++ side applies only the monitor DPI.
Map<String, Object?> overlayScene(List<Stroke> strokes, KeyTemplate t, KeyColorTheme c, double scale) {
  Map<String, Object?> colors(CapColors cc) => {
    'face': cc.face.toARGB32(),
    'edge': cc.edge.toARGB32(),
    'text': cc.text.toARGB32(),
    'border': cc.border.toARGB32(),
  };
  return {
    'radius': t.radius * scale,
    'depth': t.depth * scale,
    'border': t.border * scale,
    'height': t.height * scale,
    'fontSize': t.fontSize * scale,
    'fontWeight': t.fontWeight,
    'presentation': t.presentation,
    'strokes': [
      for (final s in strokes)
        {
          'count': s.count,
          'text': strokeText(s),
          'caps': [
            for (final cap in s.caps)
              {
                'label': cap.label,
                'symbol': cap.symbol,
                'glyph': cap.glyph.index,
                ...colors(capColors(t, c, modifier: cap.isModifier)),
              },
          ],
        },
    ],
    'pill': colors(capColors(t, c, modifier: false)),
  };
}

/// Caps used to preview templates in settings.
const previewStroke = <KeyCap>[KeyCap('Ctrl', isModifier: true), KeyCap('Shift', isModifier: true), KeyCap('K')];
