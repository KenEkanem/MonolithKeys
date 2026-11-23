#ifndef RUNNER_AUDIO_PLAYER_H_
#define RUNNER_AUDIO_PLAYER_H_

#include <windows.h>

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <deque>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>

// Plays short key sounds on its own thread so the keyboard hook never waits
// on audio. Several voices overlap, so fast typing is not cut off.
class AudioPlayer {
 public:
  // Index order matches SoundKind in lib/sound/sound_synth.dart.
  enum Kind { kKey, kSpace, kEnter, kBackspace };

  // [kind][variant] -> 16-bit mono PCM at 44.1 kHz.
  using Bank = std::vector<std::vector<std::vector<int16_t>>>;

  AudioPlayer() = default;
  ~AudioPlayer();

  AudioPlayer(const AudioPlayer&) = delete;
  AudioPlayer& operator=(const AudioPlayer&) = delete;

  void SetBank(Bank bank);
  void SetVolume(double volume) { volume_ = volume; }

  // Queues a sound and returns immediately. Safe to call from the hook.
  void Play(Kind kind);

 private:
  struct Voice {
    HWAVEOUT device = nullptr;
    WAVEHDR header{};
    std::vector<int16_t> samples;
    ULONGLONG started = 0;
  };

  void Run();
  void Start(Kind kind, Voice& voice, const Bank& bank);

  std::thread thread_;
  std::mutex mutex_;
  std::condition_variable wake_;
  std::deque<Kind> queue_;
  std::shared_ptr<const Bank> bank_;
  std::atomic<double> volume_{0.5};
  bool stop_ = false;
  unsigned variant_ = 0;
};

#endif  // RUNNER_AUDIO_PLAYER_H_
