#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "native_host.h"
#include "utils.h"

namespace {

// Initial settings window size, in logical pixels.
constexpr unsigned int kWidth = 900;
constexpr unsigned int kHeight = 760;

// Asks the already running instance to show its settings window. Returns
// false if no running instance could be found.
bool ShowRunningInstance() {
  HWND host = FindWindowW(NativeHost::kWindowClass, nullptr);
  if (!host) return false;
  DWORD process_id = 0;
  GetWindowThreadProcessId(host, &process_id);
  AllowSetForegroundWindow(process_id);
  PostMessageW(host, RegisterWindowMessageW(NativeHost::kShowMessage), 0, 0);
  return true;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // One instance per user session: hooks, shortcuts and the tray icon must not
  // be registered twice.
  HANDLE instance_mutex =
      CreateMutexW(nullptr, TRUE, L"Local\\MonolithKeys.SingleInstance");
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    ShowRunningInstance();
    if (instance_mutex) CloseHandle(instance_mutex);
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  // Centre on the primary display's work area. Win32Window scales the logical
  // origin and size by that display's DPI.
  RECT work{};
  SystemParametersInfoW(SPI_GETWORKAREA, 0, &work, 0);
  const double scale = GetDpiForSystem() / 96.0;
  const auto centre = [scale](LONG start, LONG extent, unsigned int size) {
    return static_cast<unsigned int>((std::max)(
        0.0, start / scale + (extent / scale - size) / 2));
  };
  FlutterWindow window(project);
  Win32Window::Point origin(centre(work.left, work.right - work.left, kWidth),
                            centre(work.top, work.bottom - work.top, kHeight));
  Win32Window::Size size(kWidth, kHeight);
  if (!window.Create(L"MonolithKeys", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (instance_mutex) CloseHandle(instance_mutex);
  return EXIT_SUCCESS;
}
