import 'keys.dart';

/// A group of caps pressed together, e.g. Ctrl + Shift + K, shown [count] times.
class Stroke {
  Stroke(this.caps, [this.count = 1]);

  final List<KeyCap> caps;
  int count;

  bool sameCapsAs(Stroke other) {
    if (other.caps.length != caps.length) return false;
    for (var i = 0; i < caps.length; i++) {
      if (other.caps[i] != caps[i]) return false;
    }
    return true;
  }

  @override
  String toString() => '${caps.join(' + ')}${count > 1 ? ' ×$count' : ''}';
}

class ComposerOptions {
  const ComposerOptions({
    this.shortcutsOnly = false,
    this.singleKeyMode = false,
    this.macSymbols = false,
    this.showMouse = true,
    this.hideAfter = const Duration(milliseconds: 1500),
    this.maxStrokes = 5,
  });

  final bool shortcutsOnly;
  final bool singleKeyMode;
  final bool macSymbols;
  final bool showMouse;
  final Duration hideAfter;
  final int maxStrokes;
}

/// Turns raw key and mouse events into the strokes the overlay shows.
///
/// Holds only what is on screen right now. Nothing is kept once the overlay
/// hides, and no typed text is ever assembled.
class KeystrokeComposer {
  KeystrokeComposer([this.options = const ComposerOptions()]);

  ComposerOptions options;

  /// If a key-up was never delivered (for example the secure desktop took
  /// over mid-press), forget held keys after this long without input.
  static const staleAfter = Duration(seconds: 10);

  final List<Stroke> _strokes = [];
  final Set<int> _downKeys = {};
  final Set<Modifier> _held = {};
  bool _lastIsLiveModifiers = false;
  DateTime _lastInput = DateTime.fromMillisecondsSinceEpoch(0);

  List<Stroke> get strokes => List.unmodifiable(_strokes);

  /// When the overlay should next be checked for hiding, or null if empty.
  DateTime? get hideDeadline => _strokes.isEmpty ? null : _lastInput.add(options.hideAfter);

  /// [heldModifiers] is the OS view of which modifiers are down, used to
  /// recover from missed key-up events.
  bool keyDown(int vk, {String? char, Set<Modifier>? heldModifiers, required DateTime at}) {
    _lastInput = at;
    final isRepeat = !_downKeys.add(vk);
    final modifier = modifierOf(vk);
    _syncHeld(heldModifiers);
    if (modifier != null) {
      _held.add(modifier);
      if (isRepeat) return false;
      if (options.shortcutsOnly && !_hasShortcutModifier) return false;
      final live = Stroke(_modifierCaps());
      if (_lastIsLiveModifiers) {
        _strokes.removeLast();
      }
      _push(live, mergeRepeats: !_lastIsLiveModifiers);
      _lastIsLiveModifiers = true;
      return true;
    }
    if (options.shortcutsOnly && !_hasShortcutModifier) return false;
    _addStroke(Stroke([..._modifierCaps(), KeyCap(keyLabel(vk, char: char))]));
    return true;
  }

  bool keyUp(int vk, {required DateTime at}) {
    _lastInput = at;
    _downKeys.remove(vk);
    final modifier = modifierOf(vk);
    if (modifier != null) {
      _held.remove(modifier);
      if (_held.isEmpty) _lastIsLiveModifiers = false;
    }
    return false;
  }

  /// Clicks show even in shortcuts-only mode, since they are not typing.
  bool mouse(MouseAction action, {Set<Modifier>? heldModifiers, required DateTime at}) {
    if (!options.showMouse) return false;
    _lastInput = at;
    _syncHeld(heldModifiers);
    _addStroke(Stroke([..._modifierCaps(), mouseCap(action)]));
    return true;
  }

  /// Clears the overlay once input has been idle for [ComposerOptions.hideAfter]
  /// and no keys are held. Returns true when the visible strokes changed.
  bool tick(DateTime now) {
    final idle = now.difference(_lastInput);
    if (idle >= staleAfter) {
      _downKeys.clear();
      _held.clear();
    }
    if (_strokes.isEmpty || _downKeys.isNotEmpty || idle < options.hideAfter) return false;
    reset();
    return true;
  }

  void reset() {
    _strokes.clear();
    _lastIsLiveModifiers = false;
  }

  void _syncHeld(Set<Modifier>? reported) {
    if (reported == null) return;
    _held
      ..clear()
      ..addAll(reported);
  }

  bool get _hasShortcutModifier =>
      _held.contains(Modifier.ctrl) || _held.contains(Modifier.alt) || _held.contains(Modifier.win);

  List<KeyCap> _modifierCaps() => [
    for (final m in Modifier.values)
      if (_held.contains(m)) modifierCap(m, macSymbols: options.macSymbols),
  ];

  void _addStroke(Stroke stroke) {
    if (_lastIsLiveModifiers) _strokes.removeLast();
    _lastIsLiveModifiers = false;
    _push(stroke, mergeRepeats: true);
  }

  void _push(Stroke stroke, {required bool mergeRepeats}) {
    if (mergeRepeats && _strokes.isNotEmpty && _strokes.last.sameCapsAs(stroke)) {
      _strokes.last.count++;
      return;
    }
    if (options.singleKeyMode) _strokes.clear();
    _strokes.add(stroke);
    while (_strokes.length > options.maxStrokes) {
      _strokes.removeAt(0);
    }
  }
}
