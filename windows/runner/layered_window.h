#ifndef RUNNER_LAYERED_WINDOW_H_
#define RUNNER_LAYERED_WINDOW_H_

// clang-format off
#include <windows.h>
#include <objidl.h>
#include <gdiplus.h>
// clang-format on

#include <cstdint>
#include <memory>

// A transparent, always-on-top window that never takes focus and lets every
// click pass through to the windows below. Content is drawn with GDI+ into a
// premultiplied 32-bit surface and presented with UpdateLayeredWindow.
class LayeredWindow {
 public:
  LayeredWindow();
  ~LayeredWindow();

  LayeredWindow(const LayeredWindow&) = delete;
  LayeredWindow& operator=(const LayeredWindow&) = delete;

  // Returns a canvas of |width| x |height| cleared to transparent. Call
  // Present() when drawing is done.
  std::unique_ptr<Gdiplus::Graphics> BeginDraw(int width, int height);
  void Present(POINT position, BYTE alpha);

  void Move(POINT position);
  void SetAlpha(BYTE alpha);
  void Hide();

  bool visible() const { return visible_; }
  BYTE alpha() const { return alpha_; }
  SIZE size() const { return {width_, height_}; }

 private:
  void ReleaseSurface();
  void Update(bool content);

  HWND hwnd_ = nullptr;
  HDC dc_ = nullptr;
  HBITMAP dib_ = nullptr;
  HGDIOBJ previous_ = nullptr;
  void* bits_ = nullptr;
  std::unique_ptr<Gdiplus::Bitmap> bitmap_;
  int width_ = 0;
  int height_ = 0;
  POINT position_{};
  BYTE alpha_ = 255;
  bool visible_ = false;
};

// Shared drawing helpers.
Gdiplus::Color ArgbColor(uint32_t argb, double opacity = 1.0);
void AddRoundedRect(Gdiplus::GraphicsPath& path, Gdiplus::RectF rect,
                    float radius);

#endif  // RUNNER_LAYERED_WINDOW_H_
