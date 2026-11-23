import 'dart:math' as math;
import 'dart:typed_data';

/// Which sound a key makes. Index order is shared with the native player.
enum SoundKind { key, space, enter, backspace }

class SoundTheme {
  const SoundTheme(this.id, this.name, this.description);

  final String id;
  final String name;
  final String description;
}

const soundThemes = <SoundTheme>[
  SoundTheme('tactile', 'Tactile', 'Muted, rounded bump'),
  SoundTheme('clicky', 'Clicky', 'Crisp click on press and release'),
  SoundTheme('linear', 'Linear', 'Quiet, smooth and soft'),
  SoundTheme('typewriter', 'Typewriter', 'Metal strike with a bell on Enter'),
  SoundTheme('bubble', 'Bubble', 'Light rising pop'),
];

const sampleRate = 44100;

/// Variations per kind, so fast typing does not sound mechanical.
const variantsPerKind = 3;

class _Tone {
  const _Tone(this.freq, this.decayMs, this.gain, {this.sweepTo});

  final double freq;
  final double decayMs;
  final double gain;
  final double? sweepTo;
}

class _Recipe {
  const _Recipe({
    required this.durationMs,
    this.tones = const [],
    this.noiseGain = 0,
    this.noiseDecayMs = 3,
    this.noiseSmoothing = 0,
    this.echoDelayMs,
    this.echoGain = 0,
  });

  final double durationMs;
  final List<_Tone> tones;
  final double noiseGain;
  final double noiseDecayMs;

  /// 0 keeps noise bright, values towards 1 low-pass it.
  final double noiseSmoothing;

  /// A second, quieter hit (e.g. a key's release click).
  final double? echoDelayMs;
  final double echoGain;
}

_Recipe _recipe(String theme, SoundKind kind) {
  final big = kind == SoundKind.space || kind == SoundKind.enter;
  final low = big ? 0.72 : (kind == SoundKind.backspace ? 0.88 : 1.0);
  switch (theme) {
    case 'clicky':
      return _Recipe(
        durationMs: 70,
        tones: [_Tone(3100 * low, 7, 0.55), _Tone(1250 * low, 14, 0.3)],
        noiseGain: 0.7,
        noiseDecayMs: 2,
        echoDelayMs: big ? 34 : 26,
        echoGain: 0.45,
      );
    case 'linear':
      return _Recipe(
        durationMs: 60,
        tones: [_Tone(230 * low, 22, 0.35)],
        noiseGain: 0.5,
        noiseDecayMs: 9,
        noiseSmoothing: 0.85,
      );
    case 'typewriter':
      if (kind == SoundKind.enter) {
        return const _Recipe(durationMs: 700, tones: [_Tone(2093, 420, 0.6), _Tone(4186, 180, 0.2)], noiseGain: 0.4);
      }
      return _Recipe(
        durationMs: 120,
        tones: [_Tone(880 * low, 45, 0.4), _Tone(2430 * low, 25, 0.25), _Tone(4750 * low, 12, 0.15)],
        noiseGain: 0.9,
        noiseDecayMs: 5,
        noiseSmoothing: 0.2,
      );
    case 'bubble':
      return _Recipe(durationMs: 80, tones: [_Tone(520 * low, 28, 0.8, sweepTo: 1050 * low)]);
    default: // tactile
      return _Recipe(
        durationMs: big ? 110 : 80,
        tones: [_Tone(175 * low, big ? 45 : 32, 0.7), _Tone(620 * low, 10, 0.25)],
        noiseGain: 0.55,
        noiseDecayMs: 4,
        noiseSmoothing: 0.55,
      );
  }
}

/// Synthesises one sound as 16-bit mono PCM at [sampleRate]. Deterministic for
/// a given theme, kind and variant; no recorded samples are shipped.
Int16List synthesize(String theme, SoundKind kind, int variant) {
  final r = _recipe(theme, kind);
  final pitch = 1 + (variant - (variantsPerKind - 1) / 2) * 0.035;
  final random = math.Random(
    theme.codeUnits.fold<int>(17, (h, c) => (h * 31 + c) & 0x7fffffff) ^ (kind.index * 7919) ^ (variant * 104729),
  );
  final length = (r.durationMs * sampleRate / 1000).round();
  final out = Float64List(length);

  void hit(int offset, double gain) {
    var noise = 0.0;
    final phases = List<double>.filled(r.tones.length, 0);
    for (var n = 0; offset + n < length; n++) {
      final tMs = n * 1000 / sampleRate;
      var v = 0.0;
      for (var i = 0; i < r.tones.length; i++) {
        final tone = r.tones[i];
        final progress = (tMs / r.durationMs).clamp(0.0, 1.0);
        final f = (tone.sweepTo == null ? tone.freq : tone.freq + (tone.sweepTo! - tone.freq) * progress) * pitch;
        phases[i] += 2 * math.pi * f / sampleRate;
        v += math.sin(phases[i]) * tone.gain * math.exp(-tMs / tone.decayMs);
      }
      if (r.noiseGain > 0) {
        final white = random.nextDouble() * 2 - 1;
        noise = noise * r.noiseSmoothing + white * (1 - r.noiseSmoothing);
        v += noise * r.noiseGain * math.exp(-tMs / r.noiseDecayMs);
      }
      // 1 ms attack avoids a click from starting at full amplitude.
      final attack = math.min(1.0, tMs);
      out[offset + n] += v * gain * attack;
    }
  }

  hit(0, 1);
  if (r.echoDelayMs != null) hit((r.echoDelayMs! * sampleRate / 1000).round(), r.echoGain);

  var peak = 0.0;
  for (final v in out) {
    peak = math.max(peak, v.abs());
  }
  final norm = peak == 0 ? 0.0 : 0.85 / peak;
  final pcm = Int16List(length);
  for (var i = 0; i < length; i++) {
    // Fade the final 5 ms so every buffer ends at silence.
    final fade = math.min(1.0, (length - i) / (sampleRate * 0.005));
    pcm[i] = (out[i] * norm * fade * 32767).round().clamp(-32768, 32767);
  }
  return pcm;
}

/// The full bank for a theme in the form the native player expects:
/// one list of little-endian PCM buffers per [SoundKind].
List<List<Uint8List>> soundBank(String theme) => [
  for (final kind in SoundKind.values)
    [for (var v = 0; v < variantsPerKind; v++) synthesize(theme, kind, v).buffer.asUint8List()],
];
