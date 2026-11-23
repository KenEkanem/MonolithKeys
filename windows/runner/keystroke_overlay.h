#ifndef RUNNER_KEYSTROKE_OVERLAY_H_
#define RUNNER_KEYSTROKE_OVERLAY_H_

#include <flutter/encodable_value.h>

#include <string>

#include "layered_window.h"

// Draws the key caps Dart sends (see overlayScene() in
// lib/keystroke/key_templates.dart) on the chosen display.
class KeystrokeOverlay {
 public:
  void Configure(std::wstring display_id, double align_x, double align_y,
                 double margin);
  void Show(const flutter::EncodableMap& scene);

  // Starts a short fade-out; the host calls FadeStep() on a timer until it
  // returns false.
  void BeginFadeOut();
  bool FadeStep();

 private:
  LayeredWindow window_;
  std::wstring display_id_;
  double align_x_ = 0.5;
  double align_y_ = 0.92;
  double margin_ = 24;
  bool fading_ = false;
};

#endif  // RUNNER_KEYSTROKE_OVERLAY_H_
