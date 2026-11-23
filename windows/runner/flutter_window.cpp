#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Smallest settings window, in logical pixels.
constexpr int kMinWidth = 760;
constexpr int kMinHeight = 560;

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  native_host_ = std::make_unique<NativeHost>(
      flutter_controller_->engine()->messenger(), GetHandle());

  // Apply the custom frame from WM_NCCALCSIZE.
  SetWindowPos(GetHandle(), nullptr, 0, 0, 0, 0,
               SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                   SWP_NOACTIVATE);

  // The window stays hidden until Dart calls showWindow, so a launch at sign-in
  // can start in the notification area. Render the first frame meanwhile.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  native_host_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  switch (message) {
    case WM_NCCALCSIZE:
      // Remove the title bar but keep the resize borders, so Windows still
      // draws the shadow, border and rounded corners.
      if (wparam) {
        const UINT dpi = GetDpiForWindow(hwnd);
        const int frame_x = GetSystemMetricsForDpi(SM_CXFRAME, dpi) +
                            GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
        const int frame_y = GetSystemMetricsForDpi(SM_CYFRAME, dpi) +
                            GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
        auto* params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
        params->rgrc[0].left += frame_x;
        params->rgrc[0].right -= frame_x;
        params->rgrc[0].bottom -= frame_y;
        if (IsZoomed(hwnd)) params->rgrc[0].top += frame_y;
        return 0;
      }
      break;
    case WM_GETMINMAXINFO: {
      const double scale = GetDpiForWindow(hwnd) / 96.0;
      auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
      info->ptMinTrackSize.x = static_cast<LONG>(kMinWidth * scale);
      info->ptMinTrackSize.y = static_cast<LONG>(kMinHeight * scale);
      return 0;
    }
    case WM_CLOSE:
      // Alt+F4 hides the window; MonolithKeys keeps running in the
      // notification area. Exit is in the sidebar and the tray menu.
      ShowWindow(hwnd, SW_HIDE);
      return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
