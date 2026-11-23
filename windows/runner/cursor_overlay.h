#ifndef RUNNER_CURSOR_OVERLAY_H_
#define RUNNER_CURSOR_OVERLAY_H_

#include <flutter/encodable_value.h>

#include <cstdint>

#include "layered_window.h"

enum class MouseButton { kNone, kLeft, kRight, kMiddle };

// Highlight drawn around (or pinned near) the pointer. Shape geometry mirrors
// CursorShapePainter in lib/ui/previews.dart.
class CursorOverlay {
 public:
  // Timers the host must route back via OnTimer().
  static constexpr UINT_PTR kAnimationTimer = 0x4D4B01;
  static constexpr UINT_PTR kIdleTimer = 0x4D4B02;
  static constexpr UINT_PTR kFadeTimer = 0x4D4B03;

  explicit CursorOverlay(HWND timer_window);

  void Configure(const flutter::EncodableMap& config);
  bool enabled() const { return enabled_; }

  void OnMove(POINT cursor);
  void OnButton(MouseButton button, bool down);
  void OnTimer(UINT_PTR id);

 private:
  enum class Placement { kFollow, kScreenCenter, kWindowCenter };
  enum class Animation { kNone, kPulse, kRipple, kShrink };
  enum class Shape { kCircle, kDiamond, kSquare, kCrosshair, kTarget, kDot };

  void Render();
  void Reposition();
  void Wake();
  POINT Anchor() const;
  double AnimationProgress() const;

  HWND timer_window_;
  LayeredWindow window_;

  bool enabled_ = false;
  Placement placement_ = Placement::kFollow;
  Shape shape_ = Shape::kCircle;
  bool filled_ = false;
  bool dashed_ = false;
  bool double_ring_ = false;
  double size_ = 56;
  double glow_ = 0;
  UINT hide_after_ms_ = 0;
  Animation animation_ = Animation::kRipple;
  bool click_colors_ = true;
  uint32_t color_ = 0, left_ = 0, right_ = 0, middle_ = 0;

  POINT cursor_{};
  UINT dpi_ = 96;
  MouseButton pressed_ = MouseButton::kNone;
  ULONGLONG animation_start_ = 0;
  bool animating_ = false;
  bool fading_ = false;
};

#endif  // RUNNER_CURSOR_OVERLAY_H_
