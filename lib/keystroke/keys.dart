/// Windows virtual-key codes used by the overlay.
abstract final class Vk {
  static const back = 0x08, tab = 0x09, enter = 0x0D, shift = 0x10, control = 0x11, menu = 0x12;
  static const pause = 0x13, capsLock = 0x14, escape = 0x1B, space = 0x20;
  static const pageUp = 0x21, pageDown = 0x22, end = 0x23, home = 0x24;
  static const left = 0x25, up = 0x26, right = 0x27, down = 0x28;
  static const printScreen = 0x2C, insert = 0x2D, delete = 0x2E;
  static const lWin = 0x5B, rWin = 0x5C, apps = 0x5D;
  static const numpad0 = 0x60, multiply = 0x6A, add = 0x6B, subtract = 0x6D, decimal = 0x6E, divide = 0x6F;
  static const f1 = 0x70, f24 = 0x87, numLock = 0x90, scrollLock = 0x91;
  static const lShift = 0xA0, rShift = 0xA1, lControl = 0xA2, rControl = 0xA3, lMenu = 0xA4, rMenu = 0xA5;
  static const volumeMute = 0xAD, volumeDown = 0xAE, volumeUp = 0xAF;
  static const mediaNext = 0xB0, mediaPrev = 0xB1, mediaStop = 0xB2, mediaPlayPause = 0xB3;
}

/// Display order follows the Windows convention: Win + Ctrl + Alt + Shift.
enum Modifier { win, ctrl, alt, shift }

Modifier? modifierOf(int vk) => switch (vk) {
  Vk.lWin || Vk.rWin => Modifier.win,
  Vk.control || Vk.lControl || Vk.rControl => Modifier.ctrl,
  Vk.menu || Vk.lMenu || Vk.rMenu => Modifier.alt,
  Vk.shift || Vk.lShift || Vk.rShift => Modifier.shift,
  _ => null,
};

enum CapGlyph { none, windows, mouseLeft, mouseRight, mouseMiddle, wheelUp, wheelDown }

enum MouseAction { left, right, middle, wheelUp, wheelDown }

/// One key cap on screen. [symbol] is the optional secondary mark shown when
/// Mac symbols are enabled.
class KeyCap {
  const KeyCap(this.label, {this.symbol, this.glyph = CapGlyph.none, this.isModifier = false});

  final String label;
  final String? symbol;
  final CapGlyph glyph;
  final bool isModifier;

  bool get isMouse => glyph != CapGlyph.none && glyph != CapGlyph.windows;

  @override
  bool operator ==(Object other) =>
      other is KeyCap && other.label == label && other.symbol == symbol && other.glyph == glyph;

  @override
  int get hashCode => Object.hash(label, symbol, glyph);

  @override
  String toString() => label;
}

KeyCap modifierCap(Modifier m, {required bool macSymbols}) => switch (m) {
  Modifier.win => KeyCap('Win', symbol: macSymbols ? '⌘' : null, glyph: CapGlyph.windows, isModifier: true),
  Modifier.ctrl => KeyCap('Ctrl', symbol: macSymbols ? '⌃' : null, isModifier: true),
  Modifier.alt => KeyCap('Alt', symbol: macSymbols ? '⌥' : null, isModifier: true),
  Modifier.shift => KeyCap('Shift', symbol: macSymbols ? '⇧' : null, isModifier: true),
};

KeyCap mouseCap(MouseAction a) => switch (a) {
  MouseAction.left => const KeyCap('Click', glyph: CapGlyph.mouseLeft),
  MouseAction.right => const KeyCap('Right click', glyph: CapGlyph.mouseRight),
  MouseAction.middle => const KeyCap('Middle click', glyph: CapGlyph.mouseMiddle),
  MouseAction.wheelUp => const KeyCap('Scroll up', glyph: CapGlyph.wheelUp),
  MouseAction.wheelDown => const KeyCap('Scroll down', glyph: CapGlyph.wheelDown),
};

const _named = <int, String>{
  Vk.back: 'Backspace',
  Vk.tab: 'Tab',
  Vk.enter: 'Enter',
  Vk.pause: 'Pause',
  Vk.capsLock: 'Caps Lock',
  Vk.escape: 'Esc',
  Vk.space: 'Space',
  Vk.pageUp: 'Page Up',
  Vk.pageDown: 'Page Down',
  Vk.end: 'End',
  Vk.home: 'Home',
  Vk.left: '←',
  Vk.up: '↑',
  Vk.right: '→',
  Vk.down: '↓',
  Vk.printScreen: 'Print Screen',
  Vk.insert: 'Insert',
  Vk.delete: 'Delete',
  Vk.apps: 'Menu',
  Vk.multiply: 'Num *',
  Vk.add: 'Num +',
  Vk.subtract: 'Num -',
  Vk.decimal: 'Num .',
  Vk.divide: 'Num /',
  Vk.numLock: 'Num Lock',
  Vk.scrollLock: 'Scroll Lock',
  Vk.volumeMute: 'Mute',
  Vk.volumeDown: 'Volume Down',
  Vk.volumeUp: 'Volume Up',
  Vk.mediaNext: 'Next Track',
  Vk.mediaPrev: 'Previous Track',
  Vk.mediaStop: 'Stop',
  Vk.mediaPlayPause: 'Play/Pause',
};

/// Label for a non-modifier key. [char] is the unshifted character the active
/// keyboard layout produces for the key (supplied by the native layer), which
/// keeps AZERTY, QWERTZ and other layouts correct.
String keyLabel(int vk, {String? char}) {
  final named = _named[vk];
  if (named != null) return named;
  if (vk >= Vk.f1 && vk <= Vk.f24) return 'F${vk - Vk.f1 + 1}';
  if (vk >= Vk.numpad0 && vk <= Vk.numpad0 + 9) return 'Num ${vk - Vk.numpad0}';
  if (char != null && char.trim().isNotEmpty) return char.toUpperCase();
  if ((vk >= 0x30 && vk <= 0x39) || (vk >= 0x41 && vk <= 0x5A)) return String.fromCharCode(vk);
  return 'Key ${vk.toRadixString(16).toUpperCase().padLeft(2, '0')}';
}
