import 'package:flutter_test/flutter_test.dart';
import 'package:monolithkeys/cursor/cursor_templates.dart';
import 'package:monolithkeys/keystroke/composer.dart';
import 'package:monolithkeys/keystroke/key_templates.dart';
import 'package:monolithkeys/keystroke/keys.dart';
import 'package:monolithkeys/sound/sound_synth.dart';

void main() {
  group('sound synthesis', () {
    for (final theme in soundThemes) {
      test('${theme.id} produces audible, unclipped, deterministic sounds', () {
        for (final kind in SoundKind.values) {
          final a = synthesize(theme.id, kind, 0);
          expect(a.length, greaterThan(sampleRate * 0.04), reason: '$kind is long enough to hear');
          final peak = a.map((v) => v.abs()).reduce((x, y) => x > y ? x : y);
          expect(peak, inInclusiveRange(20000, 32767 * 0.86));
          expect(a.last.abs(), lessThan(200), reason: 'buffers end near silence to avoid clicks');
          expect(synthesize(theme.id, kind, 0), a);
          expect(synthesize(theme.id, kind, 1), isNot(a), reason: 'variants differ');
        }
      });
    }

    test('bank has every kind and variant as 16-bit bytes', () {
      final bank = soundBank('clicky');
      expect(bank, hasLength(SoundKind.values.length));
      for (final variants in bank) {
        expect(variants, hasLength(variantsPerKind));
        expect(variants.first.lengthInBytes.isEven, isTrue);
      }
    });
  });

  group('key templates', () {
    test('ids are unique and lookups fall back to the first', () {
      expect(keyTemplates.map((t) => t.id).toSet(), hasLength(keyTemplates.length));
      expect(keyColors.map((t) => t.id).toSet(), hasLength(keyColors.length));
      expect(keyTemplateById('missing'), keyTemplates.first);
      expect(keyColorById('missing'), keyColors.first);
    });

    test('accent template colours modifiers differently from keys', () {
      final accent = keyTemplateById('accent');
      final c = keyColorById('graphite');
      expect(capColors(accent, c, modifier: true).face, c.accent);
      expect(capColors(accent, c, modifier: false).face, c.face);
    });

    test('scene scales sizes and carries per-cap colours', () {
      final t = keyTemplateById('classic');
      final scene = overlayScene(
        [
          Stroke([modifierCap(Modifier.ctrl, macSymbols: false), const KeyCap('C')], 2),
        ],
        t,
        keyColorById('snow'),
        1.5,
      );
      expect(scene['height'], t.height * 1.5);
      final stroke = (scene['strokes'] as List).single as Map;
      expect(stroke['count'], 2);
      expect((stroke['caps'] as List).map((c) => (c as Map)['label']), ['Ctrl', 'C']);
      expect((stroke['caps'] as List).first, containsPair('face', keyColorById('snow').face.toARGB32()));
    });
  });

  test('cursor template ids are unique', () {
    expect(cursorTemplates.map((t) => t.id).toSet(), hasLength(cursorTemplates.length));
    expect(cursorTemplateById('missing'), cursorTemplates.first);
  });
}
