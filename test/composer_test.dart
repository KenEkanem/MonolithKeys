import 'package:flutter_test/flutter_test.dart';
import 'package:monolithkeys/keystroke/composer.dart';
import 'package:monolithkeys/keystroke/keys.dart';

void main() {
  final t0 = DateTime(2026);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));
  List<String> shown(KeystrokeComposer c) => c.strokes.map((s) => s.toString()).toList();

  test('modifier combinations show in Windows order', () {
    final c = KeystrokeComposer();
    c.keyDown(Vk.lShift, at: at(0));
    c.keyDown(Vk.lControl, at: at(1));
    c.keyDown(0x4B, at: at(2));
    expect(shown(c), ['Ctrl + Shift + K']);
  });

  test('a held modifier shows alone and is replaced by the combination', () {
    final c = KeystrokeComposer();
    c.keyDown(Vk.lWin, at: at(0));
    expect(shown(c), ['Win']);
    expect(c.strokes.single.caps.single.glyph, CapGlyph.windows);
    c.keyDown(Vk.printScreen, at: at(10));
    expect(shown(c), ['Win + Print Screen']);
  });

  test('repeated strokes are counted instead of duplicated', () {
    final c = KeystrokeComposer();
    for (var i = 0; i < 3; i++) {
      c.keyDown(Vk.lControl, at: at(i * 10));
      c.keyDown(0x5A, at: at(i * 10 + 1));
      c.keyUp(0x5A, at: at(i * 10 + 2));
      c.keyUp(Vk.lControl, at: at(i * 10 + 3));
    }
    expect(shown(c), ['Ctrl + Z ×3']);
  });

  test('auto-repeat of a held key increments the count', () {
    final c = KeystrokeComposer();
    c.keyDown(Vk.down, at: at(0));
    c.keyDown(Vk.down, at: at(30));
    c.keyDown(Vk.down, at: at(60));
    expect(shown(c), ['↓ ×3']);
  });

  test('a sequence keeps the most recent strokes only', () {
    final c = KeystrokeComposer(const ComposerOptions(maxStrokes: 3));
    for (final vk in [0x41, 0x42, 0x43, 0x44]) {
      c.keyDown(vk, at: at(0));
      c.keyUp(vk, at: at(1));
    }
    expect(shown(c), ['B', 'C', 'D']);
  });

  test('one-key mode replaces the previous stroke', () {
    final c = KeystrokeComposer(const ComposerOptions(singleKeyMode: true));
    c.keyDown(0x41, at: at(0));
    c.keyUp(0x41, at: at(1));
    c.keyDown(0x42, at: at(2));
    expect(shown(c), ['B']);
  });

  test('shortcuts-only mode ignores plain typing and Shift+letter', () {
    final c = KeystrokeComposer(const ComposerOptions(shortcutsOnly: true));
    expect(c.keyDown(0x41, at: at(0)), isFalse);
    c.keyUp(0x41, at: at(1));
    expect(c.keyDown(Vk.lShift, at: at(2)), isFalse);
    expect(c.keyDown(0x41, at: at(3)), isFalse);
    c.keyUp(0x41, at: at(4));
    c.keyUp(Vk.lShift, at: at(5));
    expect(c.strokes, isEmpty);
    c.keyDown(Vk.lMenu, at: at(6));
    c.keyDown(Vk.tab, at: at(7));
    expect(shown(c), ['Alt + Tab']);
  });

  test('mouse clicks combine with held modifiers and respect the toggle', () {
    final c = KeystrokeComposer();
    c.keyDown(Vk.lControl, at: at(0));
    c.mouse(MouseAction.left, at: at(1));
    expect(shown(c), ['Ctrl + Click']);

    final off = KeystrokeComposer(const ComposerOptions(showMouse: false));
    expect(off.mouse(MouseAction.wheelDown, at: at(0)), isFalse);
    expect(off.strokes, isEmpty);
  });

  test('mac symbols add the secondary mark to modifiers', () {
    final c = KeystrokeComposer(const ComposerOptions(macSymbols: true));
    c.keyDown(Vk.lMenu, at: at(0));
    expect(c.strokes.single.caps.single.symbol, '⌥');
  });

  test('hides after the idle delay, but not while a key is held', () {
    final c = KeystrokeComposer(const ComposerOptions(hideAfter: Duration(milliseconds: 1000)));
    c.keyDown(Vk.lShift, at: at(0));
    expect(c.tick(at(5000)), isFalse, reason: 'Shift is still down');
    c.keyUp(Vk.lShift, at: at(5000));
    expect(c.tick(at(5500)), isFalse);
    expect(c.tick(at(6000)), isTrue);
    expect(c.strokes, isEmpty);
    expect(c.hideDeadline, isNull);
  });

  test('a missed key-up is forgotten after the stale timeout', () {
    final c = KeystrokeComposer(const ComposerOptions(hideAfter: Duration(milliseconds: 500)));
    c.keyDown(Vk.lWin, at: at(0));
    c.keyDown(0x4C, at: at(1)); // Win+L locks the PC; the key-ups never arrive.
    expect(c.tick(at(2000)), isFalse);
    expect(c.tick(at(1 + KeystrokeComposer.staleAfter.inMilliseconds)), isTrue);
    c.keyDown(0x41, at: at(20000));
    expect(shown(c), ['A'], reason: 'Win is no longer considered held');
  });

  test('OS-reported modifiers override a stale local view', () {
    final c = KeystrokeComposer();
    c.keyDown(Vk.lControl, at: at(0)); // key-up for Ctrl was lost
    c.keyDown(0x41, heldModifiers: {}, at: at(10));
    expect(shown(c).last, 'A');
  });

  test('key labels', () {
    expect(keyLabel(Vk.f1 + 11), 'F12');
    expect(keyLabel(Vk.numpad0 + 7), 'Num 7');
    expect(keyLabel(Vk.enter), 'Enter');
    expect(keyLabel(0xBA, char: 'ö'), 'Ö', reason: 'layout character from the active keyboard layout');
    expect(keyLabel(0x51, char: 'a'), 'A', reason: 'AZERTY: the Q position types A');
    expect(keyLabel(0x51), 'Q');
    expect(keyLabel(0xFF), 'Key FF');
  });
}
