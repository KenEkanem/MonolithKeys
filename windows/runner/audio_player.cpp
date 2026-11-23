#include "audio_player.h"

#include <mmsystem.h>

#include <algorithm>
#include <array>

namespace {

constexpr int kVoices = 8;

// Keypresses queued faster than this are dropped rather than played late.
constexpr size_t kMaxQueue = 16;

}  // namespace

AudioPlayer::~AudioPlayer() {
  {
    std::lock_guard lock(mutex_);
    stop_ = true;
  }
  wake_.notify_one();
  if (thread_.joinable()) thread_.join();
}

void AudioPlayer::SetBank(Bank bank) {
  std::lock_guard lock(mutex_);
  bank_ = std::make_shared<const Bank>(std::move(bank));
  if (!thread_.joinable()) thread_ = std::thread(&AudioPlayer::Run, this);
}

void AudioPlayer::Play(Kind kind) {
  {
    std::lock_guard lock(mutex_);
    if (!bank_ || queue_.size() >= kMaxQueue) return;
    queue_.push_back(kind);
  }
  wake_.notify_one();
}

void AudioPlayer::Run() {
  WAVEFORMATEX format{};
  format.wFormatTag = WAVE_FORMAT_PCM;
  format.nChannels = 1;
  format.nSamplesPerSec = 44100;
  format.wBitsPerSample = 16;
  format.nBlockAlign = 2;
  format.nAvgBytesPerSec = format.nSamplesPerSec * format.nBlockAlign;

  std::array<Voice, kVoices> voices;
  for (auto& v : voices) {
    // Without an audio device this fails and Play() becomes a no-op.
    if (waveOutOpen(&v.device, WAVE_MAPPER, &format, 0, 0, CALLBACK_NULL) != MMSYSERR_NOERROR) {
      v.device = nullptr;
    }
  }

  std::unique_lock lock(mutex_);
  while (true) {
    wake_.wait(lock, [this] { return stop_ || !queue_.empty(); });
    if (stop_) break;
    const Kind kind = queue_.front();
    queue_.pop_front();
    const auto bank = bank_;
    lock.unlock();

    // Prefer a finished voice; otherwise cut off the oldest one.
    Voice* chosen = nullptr;
    for (auto& v : voices) {
      if (!v.device) continue;
      if (!(v.header.dwFlags & WHDR_PREPARED) || (v.header.dwFlags & WHDR_DONE)) {
        chosen = &v;
        break;
      }
      if (!chosen || v.started < chosen->started) chosen = &v;
    }
    if (chosen && bank) Start(kind, *chosen, *bank);
    lock.lock();
  }
  lock.unlock();

  for (auto& v : voices) {
    if (!v.device) continue;
    waveOutReset(v.device);
    if (v.header.dwFlags & WHDR_PREPARED) waveOutUnprepareHeader(v.device, &v.header, sizeof(WAVEHDR));
    waveOutClose(v.device);
  }
}

void AudioPlayer::Start(Kind kind, Voice& voice, const Bank& bank) {
  if (static_cast<size_t>(kind) >= bank.size() || bank[kind].empty()) return;
  const auto& source = bank[kind][variant_++ % bank[kind].size()];
  if (source.empty()) return;

  if (voice.header.dwFlags & WHDR_PREPARED) {
    if (!(voice.header.dwFlags & WHDR_DONE)) waveOutReset(voice.device);
    waveOutUnprepareHeader(voice.device, &voice.header, sizeof(WAVEHDR));
  }

  const double volume = std::clamp(volume_.load(), 0.0, 1.0);
  voice.samples.resize(source.size());
  std::transform(source.begin(), source.end(), voice.samples.begin(),
                 [volume](int16_t s) { return static_cast<int16_t>(s * volume); });

  voice.header = {};
  voice.header.lpData = reinterpret_cast<LPSTR>(voice.samples.data());
  voice.header.dwBufferLength = static_cast<DWORD>(voice.samples.size() * sizeof(int16_t));
  voice.started = GetTickCount64();
  if (waveOutPrepareHeader(voice.device, &voice.header, sizeof(WAVEHDR)) == MMSYSERR_NOERROR) {
    waveOutWrite(voice.device, &voice.header, sizeof(WAVEHDR));
  }
}
