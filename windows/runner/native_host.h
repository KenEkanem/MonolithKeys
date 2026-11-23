#ifndef RUNNER_NATIVE_HOST_H_
#define RUNNER_NATIVE_HOST_H_

// clang-format off
#include <windows.h>
#include <objidl.h>
#include <gdiplus.h>
#include <shellapi.h>
// clang-format on

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <bitset>
#include <memory>
#include <string>

#include "audio_player.h"
#include "cursor_overlay.h"
#include "keystroke_overlay.h"

// Windows side of MonolithKeys: global hooks and shortcuts, the notification
// area icon, the overlays, key sounds and the Windows startup entry. Dart
// owns the settings and drives everything here through one method channel
// (see lib/native/native_host.dart).
class NativeHost {
 public:
  // Window class of the hidden host window. A second instance finds the
  // running one through it.
  static constexpr wchar_t kWindowClass[] = L"MonolithKeysHost";
  // Registered message asking the running instance to show its window.
  static constexpr wchar_t kShowMessage[] = L"MonolithKeys.ShowSettings";

  NativeHost(flutter::BinaryMessenger* messenger, HWND main_window);
  ~NativeHost();

  NativeHost(const NativeHost&) = delete;
  NativeHost& operator=(const NativeHost&) = delete;

  void ShowMainWindow();

 private:
  static LRESULT CALLBACK HostProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
  static LRESULT CALLBACK KeyboardProc(int code, WPARAM wparam, LPARAM lparam);
  static LRESULT CALLBACK MouseProc(int code, WPARAM wparam, LPARAM lparam);

  LRESULT HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);
  void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  flutter::EncodableMap Configure(const flutter::EncodableMap& config);
  flutter::EncodableMap RegisterHotkeys(const flutter::EncodableMap& hotkeys);
  void UpdateHooks();
  void UpdateStartupEntry(bool enabled);
  void AddTrayIcon();
  void ShowTrayMenu();
  void Send(const char* method, flutter::EncodableValue args = flutter::EncodableValue());
  void Log(const std::string& message);
  void OnKey(DWORD vk, bool down, int modifiers, wchar_t character);

  // GDI+ must outlive the overlays, so it is declared (and started) first.
  struct GdiplusSession {
    GdiplusSession();
    ~GdiplusSession();
    ULONG_PTR token = 0;
  } gdiplus_;

  HWND main_window_;
  HWND host_window_ = nullptr;
  UINT show_message_ = 0;
  UINT taskbar_created_message_ = 0;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  HHOOK keyboard_hook_ = nullptr;
  HHOOK mouse_hook_ = nullptr;
  std::bitset<256> keys_down_;

  bool key_events_ = false;
  bool mouse_events_ = false;
  bool sounds_ = false;
  bool tray_checks_[3] = {};
  int hotkey_vks_[3] = {};
  const char* hotkey_status_[3] = {"off", "off", "off"};
  bool tray_added_ = false;
  HICON tray_icon_ = nullptr;

  KeystrokeOverlay keystrokes_;
  std::unique_ptr<CursorOverlay> cursor_;
  AudioPlayer audio_;
};

#endif  // RUNNER_NATIVE_HOST_H_
