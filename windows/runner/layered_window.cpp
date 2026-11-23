#include "layered_window.h"

#include <algorithm>

namespace {

constexpr wchar_t kOverlayClass[] = L"MonolithKeysOverlay";

const wchar_t* RegisterOverlayClass() {
  static bool registered = false;
  if (!registered) {
    WNDCLASSW wc{};
    wc.lpfnWndProc = DefWindowProcW;
    wc.hInstance = GetModuleHandle(nullptr);
    wc.lpszClassName = kOverlayClass;
    RegisterClassW(&wc);
    registered = true;
  }
  return kOverlayClass;
}

}  // namespace

LayeredWindow::LayeredWindow() {
  hwnd_ = CreateWindowExW(
      WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOPMOST | WS_EX_TOOLWINDOW |
          WS_EX_NOACTIVATE,
      RegisterOverlayClass(), L"MonolithKeys overlay", WS_POPUP, 0, 0, 1, 1,
      nullptr, nullptr, GetModuleHandle(nullptr), nullptr);
}

LayeredWindow::~LayeredWindow() {
  ReleaseSurface();
  if (hwnd_) DestroyWindow(hwnd_);
}

void LayeredWindow::ReleaseSurface() {
  bitmap_.reset();
  if (dc_) {
    SelectObject(dc_, previous_);
    DeleteDC(dc_);
    dc_ = nullptr;
  }
  if (dib_) {
    DeleteObject(dib_);
    dib_ = nullptr;
  }
  bits_ = nullptr;
  width_ = height_ = 0;
}

std::unique_ptr<Gdiplus::Graphics> LayeredWindow::BeginDraw(int width,
                                                            int height) {
  width = (std::max)(1, width);
  height = (std::max)(1, height);
  if (width != width_ || height != height_ || !dc_) {
    ReleaseSurface();
    BITMAPINFO info{};
    info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = width;
    info.bmiHeader.biHeight = -height;  // Top-down rows.
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;
    HDC screen = GetDC(nullptr);
    dib_ = CreateDIBSection(screen, &info, DIB_RGB_COLORS, &bits_, nullptr, 0);
    dc_ = CreateCompatibleDC(screen);
    ReleaseDC(nullptr, screen);
    previous_ = SelectObject(dc_, dib_);
    // GDI+ draws straight into the DIB in the premultiplied format that
    // UpdateLayeredWindow expects.
    bitmap_ = std::make_unique<Gdiplus::Bitmap>(
        width, height, width * 4, PixelFormat32bppPARGB,
        static_cast<BYTE*>(bits_));
    width_ = width;
    height_ = height;
  }
  auto graphics = std::make_unique<Gdiplus::Graphics>(bitmap_.get());
  graphics->Clear(Gdiplus::Color(0, 0, 0, 0));
  graphics->SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
  graphics->SetPixelOffsetMode(Gdiplus::PixelOffsetModeHalf);
  graphics->SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAliasGridFit);
  return graphics;
}

void LayeredWindow::Present(POINT position, BYTE alpha) {
  position_ = position;
  alpha_ = alpha;
  Update(true);
  if (!visible_) {
    SetWindowPos(hwnd_, HWND_TOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
    visible_ = true;
  }
}

void LayeredWindow::Move(POINT position) {
  if (position.x == position_.x && position.y == position_.y) return;
  position_ = position;
  SetWindowPos(hwnd_, nullptr, position.x, position.y, 0, 0,
               SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOREDRAW);
}

void LayeredWindow::SetAlpha(BYTE alpha) {
  alpha_ = alpha;
  Update(false);
}

void LayeredWindow::Hide() {
  if (!visible_) return;
  ShowWindow(hwnd_, SW_HIDE);
  visible_ = false;
}

void LayeredWindow::Update(bool content) {
  if (!dc_) return;
  BLENDFUNCTION blend{AC_SRC_OVER, 0, alpha_, AC_SRC_ALPHA};
  SIZE size{width_, height_};
  POINT origin{0, 0};
  if (content) {
    UpdateLayeredWindow(hwnd_, nullptr, &position_, &size, dc_, &origin, 0,
                        &blend, ULW_ALPHA);
  } else {
    UpdateLayeredWindow(hwnd_, nullptr, nullptr, nullptr, nullptr, nullptr, 0,
                        &blend, ULW_ALPHA);
  }
}

Gdiplus::Color ArgbColor(uint32_t argb, double opacity) {
  const auto a = static_cast<BYTE>(std::clamp(((argb >> 24) & 0xFF) * opacity, 0.0, 255.0));
  return Gdiplus::Color(a, (argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);
}

void AddRoundedRect(Gdiplus::GraphicsPath& path, Gdiplus::RectF r,
                    float radius) {
  const float d = (std::min)({radius * 2, r.Width, r.Height});
  if (d <= 0.5f) {
    path.AddRectangle(r);
    return;
  }
  path.AddArc(r.X, r.Y, d, d, 180, 90);
  path.AddArc(r.X + r.Width - d, r.Y, d, d, 270, 90);
  path.AddArc(r.X + r.Width - d, r.Y + r.Height - d, d, d, 0, 90);
  path.AddArc(r.X, r.Y + r.Height - d, d, d, 90, 90);
  path.CloseFigure();
}
