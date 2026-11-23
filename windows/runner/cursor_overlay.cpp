#include "cursor_overlay.h"

#include <dwmapi.h>

#include <algorithm>
#include <cmath>

#include "displays.h"
#include "encodable.h"

namespace {

constexpr double kPi = 3.14159265358979323846;
constexpr UINT kFrameMs = 16;
constexpr BYTE kFadeStep = 25;

// Animation lengths in milliseconds.
constexpr double kPulseMs = 220;
constexpr double kRippleMs = 450;
constexpr double kShrinkMs = 90;

// Highlight radius plus room for the glow and a full ripple.
constexpr double kCanvasFactor = 2.0;

}  // namespace

CursorOverlay::CursorOverlay(HWND timer_window) : timer_window_(timer_window) {}

void CursorOverlay::Configure(const flutter::EncodableMap& c) {
  enabled_ = GetBool(c, "enabled");
  placement_ = static_cast<Placement>(std::clamp<int64_t>(GetInt(c, "placement"), 0, 2));
  shape_ = static_cast<Shape>(std::clamp<int64_t>(GetInt(c, "shape"), 0, 5));
  filled_ = GetBool(c, "filled");
  dashed_ = GetBool(c, "dashed");
  double_ring_ = GetBool(c, "doubleRing");
  size_ = std::clamp(GetDouble(c, "size", 56), 8.0, 400.0);
  glow_ = std::clamp(GetDouble(c, "glow"), 0.0, 1.0);
  hide_after_ms_ = static_cast<UINT>(std::clamp<int64_t>(GetInt(c, "hideAfterMs"), 0, 600000));
  animation_ = static_cast<Animation>(std::clamp<int64_t>(GetInt(c, "animation"), 0, 3));
  click_colors_ = GetBool(c, "clickColors", true);
  color_ = GetColor(c, "color");
  left_ = GetColor(c, "left");
  right_ = GetColor(c, "right");
  middle_ = GetColor(c, "middle");

  if (!enabled_) {
    KillTimer(timer_window_, kAnimationTimer);
    KillTimer(timer_window_, kIdleTimer);
    KillTimer(timer_window_, kFadeTimer);
    animating_ = fading_ = false;
    pressed_ = MouseButton::kNone;
    window_.Hide();
    return;
  }
  GetCursorPos(&cursor_);
  dpi_ = DpiForMonitor(MonitorFromPoint(cursor_, MONITOR_DEFAULTTONEAREST));
  Render();
  Wake();
}

void CursorOverlay::OnMove(POINT cursor) {
  if (!enabled_) return;
  cursor_ = cursor;
  const UINT dpi = DpiForMonitor(MonitorFromPoint(cursor, MONITOR_DEFAULTTONEAREST));
  if (dpi != dpi_) {
    dpi_ = dpi;
    Render();
  } else {
    Reposition();
  }
  Wake();
}

void CursorOverlay::OnButton(MouseButton button, bool down) {
  if (!enabled_) return;
  if (down) {
    pressed_ = button;
  } else if (button == pressed_) {
    pressed_ = MouseButton::kNone;
  } else {
    return;
  }
  // Pulse and ripple play on press; shrink animates both ways.
  if (animation_ != Animation::kNone && (down || animation_ == Animation::kShrink)) {
    animation_start_ = GetTickCount64();
    animating_ = true;
    SetTimer(timer_window_, kAnimationTimer, kFrameMs, nullptr);
  }
  Render();
  Wake();
}

void CursorOverlay::OnTimer(UINT_PTR id) {
  switch (id) {
    case kAnimationTimer:
      if (AnimationProgress() >= 1) {
        animating_ = false;
        KillTimer(timer_window_, kAnimationTimer);
      }
      Render();
      break;
    case kIdleTimer:
      KillTimer(timer_window_, kIdleTimer);
      if (pressed_ == MouseButton::kNone) {
        fading_ = true;
        SetTimer(timer_window_, kFadeTimer, kFrameMs, nullptr);
      }
      break;
    case kFadeTimer:
      if (!fading_ || window_.alpha() <= kFadeStep) {
        KillTimer(timer_window_, kFadeTimer);
        if (fading_) window_.Hide();
        fading_ = false;
      } else {
        window_.SetAlpha(static_cast<BYTE>(window_.alpha() - kFadeStep));
      }
      break;
  }
}

void CursorOverlay::Wake() {
  if (fading_ || !window_.visible()) {
    fading_ = false;
    KillTimer(timer_window_, kFadeTimer);
    Render();
  }
  if (hide_after_ms_ > 0) SetTimer(timer_window_, kIdleTimer, hide_after_ms_, nullptr);
}

double CursorOverlay::AnimationProgress() const {
  if (!animating_) return 1;
  const double length = animation_ == Animation::kPulse    ? kPulseMs
                        : animation_ == Animation::kRipple ? kRippleMs
                                                           : kShrinkMs;
  return std::clamp(static_cast<double>(GetTickCount64() - animation_start_) / length, 0.0, 1.0);
}

POINT CursorOverlay::Anchor() const {
  switch (placement_) {
    case Placement::kScreenCenter: {
      MONITORINFO info{sizeof(info)};
      GetMonitorInfoW(MonitorFromPoint(cursor_, MONITOR_DEFAULTTONEAREST), &info);
      return {(info.rcMonitor.left + info.rcMonitor.right) / 2, (info.rcMonitor.top + info.rcMonitor.bottom) / 2};
    }
    case Placement::kWindowCenter: {
      RECT r{};
      HWND foreground = GetForegroundWindow();
      if (foreground && SUCCEEDED(DwmGetWindowAttribute(foreground, DWMWA_EXTENDED_FRAME_BOUNDS, &r, sizeof(r)))) {
        return {(r.left + r.right) / 2, (r.top + r.bottom) / 2};
      }
      return cursor_;
    }
    case Placement::kFollow:
    default:
      return cursor_;
  }
}

void CursorOverlay::Reposition() {
  const SIZE s = window_.size();
  const POINT anchor = Anchor();
  window_.Move({anchor.x - s.cx / 2, anchor.y - s.cy / 2});
}

void CursorOverlay::Render() {
  using Gdiplus::REAL;
  const double scale = dpi_ / 96.0;
  const double base = size_ * scale / 2;
  const int canvas = static_cast<int>(std::ceil(base * 2 * kCanvasFactor)) + 4;
  auto g = window_.BeginDraw(canvas, canvas);
  const Gdiplus::PointF c(static_cast<float>(canvas) / 2, static_cast<float>(canvas) / 2);

  const double t = AnimationProgress();
  double factor = 1;
  if (animating_ || animation_ == Animation::kShrink) {
    switch (animation_) {
      case Animation::kPulse:
        factor = 1 - 0.2 * std::sin(kPi * t);
        break;
      case Animation::kShrink: {
        const double pressed = pressed_ != MouseButton::kNone ? t : 1 - t;
        factor = 1 - 0.25 * pressed;
        break;
      }
      default:
        break;
    }
  }

  uint32_t argb = color_;
  if (click_colors_) {
    if (pressed_ == MouseButton::kLeft) argb = left_;
    if (pressed_ == MouseButton::kRight) argb = right_;
    if (pressed_ == MouseButton::kMiddle) argb = middle_;
  }
  const Gdiplus::Color color = ArgbColor(argb);
  const Gdiplus::Color opaque = ArgbColor(argb | 0xFF000000u);
  const REAL r = static_cast<REAL>(base * factor);
  const REAL w = (std::max)(2.0f, r * 0.14f);

  if (glow_ > 0) {
    // GDI+ has no blur, so the glow is a stack of fading rings.
    constexpr int kRings = 10;
    const REAL spread = static_cast<REAL>(r * 0.35 * glow_);
    for (int i = kRings; i >= 1; --i) {
      const double k = static_cast<double>(i) / kRings;
      Gdiplus::Pen ring(ArgbColor(argb, 0.6 * (1 - k) * (1 - k)), spread / kRings * 1.6f);
      const REAL radius = r + spread * static_cast<REAL>(k);
      g->DrawEllipse(&ring, c.X - radius, c.Y - radius, radius * 2, radius * 2);
    }
  }

  if (animating_ && animation_ == Animation::kRipple) {
    const REAL radius = static_cast<REAL>(r * (1 + 0.8 * t));
    Gdiplus::Pen ripple(ArgbColor(argb | 0xFF000000u, 1 - t), w * 0.7f);
    g->DrawEllipse(&ripple, c.X - radius, c.Y - radius, radius * 2, radius * 2);
  }

  auto outline = [&](Gdiplus::GraphicsPath& path, REAL radius) {
    switch (shape_) {
      case Shape::kDiamond: {
        Gdiplus::PointF pts[] = {{c.X, c.Y - radius}, {c.X + radius, c.Y}, {c.X, c.Y + radius}, {c.X - radius, c.Y}};
        path.AddPolygon(pts, 4);
        break;
      }
      case Shape::kSquare: {
        const REAL half = radius * 0.86f;
        AddRoundedRect(path, Gdiplus::RectF(c.X - half, c.Y - half, half * 2, half * 2), radius * 0.3f);
        break;
      }
      default:
        path.AddEllipse(c.X - radius, c.Y - radius, radius * 2, radius * 2);
    }
  };

  Gdiplus::SolidBrush fill(color);
  Gdiplus::Pen stroke(color, w);
  switch (shape_) {
    case Shape::kDot:
      g->FillEllipse(&fill, c.X - r * 0.3f, c.Y - r * 0.3f, r * 0.6f, r * 0.6f);
      break;
    case Shape::kCrosshair:
    case Shape::kTarget: {
      Gdiplus::Pen thin(color, w * 0.7f);
      const REAL inner = shape_ == Shape::kTarget ? 0 : r * 0.3f;
      g->DrawLine(&thin, c.X + inner, c.Y, c.X + r, c.Y);
      g->DrawLine(&thin, c.X - inner, c.Y, c.X - r, c.Y);
      g->DrawLine(&thin, c.X, c.Y + inner, c.X, c.Y + r);
      g->DrawLine(&thin, c.X, c.Y - inner, c.X, c.Y - r);
      const REAL ring = r - w / 2;
      g->DrawEllipse(&thin, c.X - ring, c.Y - ring, ring * 2, ring * 2);
      if (shape_ == Shape::kTarget) g->DrawEllipse(&thin, c.X - r * 0.45f, c.Y - r * 0.45f, r * 0.9f, r * 0.9f);
      break;
    }
    default: {
      if (dashed_) {
        const REAL pattern[] = {1.6f, 1.2f};
        stroke.SetDashPattern(pattern, 2);
      }
      Gdiplus::GraphicsPath outer;
      outline(outer, r - w / 2);
      if (filled_) {
        Gdiplus::GraphicsPath body;
        outline(body, double_ring_ ? r * 0.62f : r);
        g->FillPath(&fill, &body);
        if (double_ring_) g->DrawPath(&stroke, &outer);
        if (dashed_) {
          stroke.SetColor(opaque);
          g->DrawPath(&stroke, &outer);
        }
      } else {
        g->DrawPath(&stroke, &outer);
        if (double_ring_) {
          Gdiplus::GraphicsPath inner;
          outline(inner, r * 0.62f);
          Gdiplus::Pen thin(color, w * 0.7f);
          g->DrawPath(&thin, &inner);
        }
      }
    }
  }
  g.reset();

  const POINT anchor = Anchor();
  window_.Present({anchor.x - canvas / 2, anchor.y - canvas / 2}, fading_ ? window_.alpha() : 255);
}
