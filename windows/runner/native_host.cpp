#include "native_host.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>
#include <windowsx.h>

#include <algorithm>
#include <cstring>
#include <string>

#include "displays.h"
#include "encodable.h"
#include "resource.h"
#include "utils.h"

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

// Missing from Windows SDKs older than 10.0.22000.
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

namespace {

NativeHost* g_host = nullptr;

constexpr UINT kKeyMessage = WM_APP + 1;
constexpr UINT kMouseMessage = WM_APP + 2;
constexpr UINT kTrayMessage = WM_APP + 3;
constexpr UINT_PTR kKeystrokeFadeTimer = 0x4D4B10;
constexpr UINT kFadeFrameMs = 16;
constexpr UINT kTrayId = 1;

// Same order as Feature in lib/native/native_host.dart; hotkey ids are index + 1.
constexpr const char* kFeatures[] = {"keystroke", "cursor", "sounds"};
constexpr const wchar_t* kFeatureLabels[] = {L"Keystroke overlay", L"Cursor highlight", L"Keystroke sounds"};

enum TrayCommand { kOpen = 1, kToggleFirst = 2, kExit = 10 };

constexpr wchar_t kRunKey[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kRunValue[] = L"MonolithKeys";

// Bit order matches Modifier in lib/keystroke/keys.dart.
int HeldModifiers() {
  auto down = [](int vk) { return (GetAsyncKeyState(vk) & 0x8000) != 0; };
  return (down(VK_LWIN) || down(VK_RWIN) ? 1 : 0) | (down(VK_CONTROL) ? 2 : 0) | (down(VK_MENU) ? 4 : 0) |
         (down(VK_SHIFT) ? 8 : 0);
}

AudioPlayer::Kind SoundFor(DWORD vk) {
  switch (vk) {
    case VK_SPACE:
      return AudioPlayer::kSpace;
    case VK_RETURN:
      return AudioPlayer::kEnter;
    case VK_BACK:
    case VK_DELETE:
      return AudioPlayer::kBackspace;
    default:
      return AudioPlayer::kKey;
  }
}

std::wstring ExePath() {
  wchar_t path[MAX_PATH];
  const DWORD length = GetModuleFileNameW(nullptr, path, MAX_PATH);
  return std::wstring(path, length);
}

}  // namespace

NativeHost::GdiplusSession::GdiplusSession() {
  Gdiplus::GdiplusStartupInput input;
  Gdiplus::GdiplusStartup(&token, &input, nullptr);
}

NativeHost::GdiplusSession::~GdiplusSession() { Gdiplus::GdiplusShutdown(token); }

NativeHost::NativeHost(flutter::BinaryMessenger* messenger, HWND main_window) : main_window_(main_window) {
  g_host = this;
  show_message_ = RegisterWindowMessageW(kShowMessage);
  taskbar_created_message_ = RegisterWindowMessageW(L"TaskbarCreated");

  WNDCLASSW wc{};
  wc.lpfnWndProc = HostProc;
  wc.hInstance = GetModuleHandle(nullptr);
  wc.lpszClassName = kWindowClass;
  RegisterClassW(&wc);
  // A hidden top-level window rather than a message-only one, so it receives
  // the broadcasts it needs (TaskbarCreated, WM_DISPLAYCHANGE).
  host_window_ = CreateWindowExW(WS_EX_TOOLWINDOW, kWindowClass, L"MonolithKeys", WS_POPUP, 0, 0, 0, 0, nullptr,
                                 nullptr, GetModuleHandle(nullptr), this);

  cursor_ = std::make_unique<CursorOverlay>(host_window_);

  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "monolithkeys/native", &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) { HandleMethodCall(call, std::move(result)); });

  const UINT icon_size = GetSystemMetricsForDpi(SM_CXSMICON, GetDpiForSystem());
  tray_icon_ = static_cast<HICON>(LoadImageW(GetModuleHandle(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON), IMAGE_ICON,
                                             icon_size, icon_size, LR_DEFAULTCOLOR));
  AddTrayIcon();
}

NativeHost::~NativeHost() {
  channel_->SetMethodCallHandler(nullptr);
  if (keyboard_hook_) UnhookWindowsHookEx(keyboard_hook_);
  if (mouse_hook_) UnhookWindowsHookEx(mouse_hook_);
  for (int i = 0; i < 3; ++i) UnregisterHotKey(host_window_, i + 1);
  if (tray_added_) {
    NOTIFYICONDATAW nid{sizeof(nid)};
    nid.hWnd = host_window_;
    nid.uID = kTrayId;
    Shell_NotifyIconW(NIM_DELETE, &nid);
  }
  if (tray_icon_) DestroyIcon(tray_icon_);
  DestroyWindow(host_window_);
  g_host = nullptr;
}

void NativeHost::ShowMainWindow() {
  ShowWindow(main_window_, IsIconic(main_window_) ? SW_RESTORE : SW_SHOW);
  SetForegroundWindow(main_window_);
}

void NativeHost::Send(const char* method, EncodableValue args) {
  channel_->InvokeMethod(method, std::make_unique<EncodableValue>(std::move(args)));
}

void NativeHost::Log(const std::string& message) { Send("log", EncodableValue(EncodableMap{{"message", message}})); }

// ---------------------------------------------------------------------------
// Method channel

void NativeHost::HandleMethodCall(const flutter::MethodCall<EncodableValue>& call,
                                  std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();
  const auto* args = call.arguments() ? std::get_if<EncodableMap>(call.arguments()) : nullptr;
  static const EncodableMap kEmpty;
  const EncodableMap& map = args ? *args : kEmpty;

  if (method == "configure") {
    result->Success(EncodableValue(Configure(map)));
  } else if (method == "showKeystrokes") {
    KillTimer(host_window_, kKeystrokeFadeTimer);
    keystrokes_.Show(map);
    result->Success();
  } else if (method == "hideKeystrokes") {
    keystrokes_.BeginFadeOut();
    SetTimer(host_window_, kKeystrokeFadeTimer, kFadeFrameMs, nullptr);
    result->Success();
  } else if (method == "setSoundBank") {
    AudioPlayer::Bank bank;
    if (const auto* kinds = std::get_if<EncodableList>(call.arguments())) {
      for (const auto& kind : *kinds) {
        auto& variants = bank.emplace_back();
        if (const auto* list = std::get_if<EncodableList>(&kind)) {
          for (const auto& bytes : *list) {
            if (const auto* data = std::get_if<std::vector<uint8_t>>(&bytes)) {
              auto& pcm = variants.emplace_back(data->size() / 2);
              memcpy(pcm.data(), data->data(), pcm.size() * 2);
            }
          }
        }
      }
    }
    audio_.SetBank(std::move(bank));
    result->Success();
  } else if (method == "playSound") {
    audio_.Play(AudioPlayer::kKey);
    result->Success();
  } else if (method == "displays") {
    EncodableList list;
    for (const auto& d : EnumerateDisplays()) {
      list.emplace_back(EncodableMap{
          {"id", Utf8FromUtf16(d.id.c_str())},
          {"boundsLeft", static_cast<int>(d.bounds.left)},
          {"boundsTop", static_cast<int>(d.bounds.top)},
          {"boundsWidth", static_cast<int>(d.bounds.right - d.bounds.left)},
          {"boundsHeight", static_cast<int>(d.bounds.bottom - d.bounds.top)},
          {"workLeft", static_cast<int>(d.work.left)},
          {"workTop", static_cast<int>(d.work.top)},
          {"workWidth", static_cast<int>(d.work.right - d.work.left)},
          {"workHeight", static_cast<int>(d.work.bottom - d.work.top)},
          {"scale", d.dpi / 96.0},
          {"primary", d.primary},
      });
    }
    result->Success(EncodableValue(list));
  } else if (method == "wallpaper") {
    wchar_t path[MAX_PATH] = {};
    if (SystemParametersInfoW(SPI_GETDESKWALLPAPER, MAX_PATH, path, 0) && path[0]) {
      result->Success(EncodableValue(Utf8FromUtf16(path)));
    } else {
      result->Success();
    }
  } else if (method == "showWindow") {
    ShowMainWindow();
    result->Success();
  } else if (method == "hideWindow") {
    ShowWindow(main_window_, SW_HIDE);
    result->Success();
  } else if (method == "startWindowDrag") {
    result->Success();
    ReleaseCapture();
    SendMessageW(main_window_, WM_SYSCOMMAND, SC_MOVE | HTCAPTION, 0);
  } else if (method == "open") {
    // Only web and mail links or existing folders; never run programs.
    const std::wstring target = Utf16FromUtf8(GetString(map, "target"));
    const bool link = target.rfind(L"https://", 0) == 0 || target.rfind(L"http://", 0) == 0 ||
                      target.rfind(L"mailto:", 0) == 0;
    const DWORD attributes = GetFileAttributesW(target.c_str());
    const bool folder = attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_DIRECTORY);
    if (link || folder) ShellExecuteW(nullptr, L"open", target.c_str(), nullptr, nullptr, SW_SHOWNORMAL);
    result->Success(EncodableValue(link || folder));
  } else if (method == "quit") {
    result->Success();
    // Ends the message loop in main(); windows and hooks are torn down as
    // the FlutterWindow is destroyed.
    PostQuitMessage(0);
  } else {
    result->NotImplemented();
  }
}

EncodableMap NativeHost::Configure(const EncodableMap& config) {
  key_events_ = GetBool(config, "keyEvents");
  mouse_events_ = GetBool(config, "mouseEvents");
  sounds_ = GetBool(config, "sounds");
  audio_.SetVolume(GetDouble(config, "volume", 0.5));

  if (const auto* tray = GetMap(config, "tray")) {
    for (int i = 0; i < 3; ++i) tray_checks_[i] = GetBool(*tray, kFeatures[i]);
  }
  if (const auto* overlay = GetMap(config, "overlay")) {
    keystrokes_.Configure(Utf16FromUtf8(GetString(*overlay, "displayId")), GetDouble(*overlay, "alignX", 0.5),
                          GetDouble(*overlay, "alignY", 0.92), GetDouble(*overlay, "margin", 24));
  }
  if (const auto* cursor = GetMap(config, "cursor")) cursor_->Configure(*cursor);

  UpdateStartupEntry(GetBool(config, "startup"));

  const BOOL dark = GetBool(config, "dark");
  DwmSetWindowAttribute(main_window_, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark, sizeof(dark));

  UpdateHooks();
  const auto* hotkeys = GetMap(config, "hotkeys");
  return RegisterHotkeys(hotkeys ? *hotkeys : EncodableMap{});
}

EncodableMap NativeHost::RegisterHotkeys(const EncodableMap& hotkeys) {
  EncodableMap status;
  for (int i = 0; i < 3; ++i) {
    const int vk = static_cast<int>(GetInt(hotkeys, kFeatures[i]));
    if (vk != hotkey_vks_[i]) {
      UnregisterHotKey(host_window_, i + 1);
      hotkey_vks_[i] = vk;
      if (vk == 0) {
        hotkey_status_[i] = "off";
      } else if (RegisterHotKey(host_window_, i + 1, MOD_CONTROL | MOD_ALT | MOD_SHIFT | MOD_NOREPEAT, vk)) {
        hotkey_status_[i] = "registered";
      } else {
        hotkey_status_[i] = "conflict";
      }
    }
    status[EncodableValue(kFeatures[i])] = EncodableValue(hotkey_status_[i]);
  }
  return status;
}

void NativeHost::UpdateHooks() {
  // Hooks run only while a feature needs them, so with everything off
  // MonolithKeys sees no input at all.
  const bool want_keyboard = key_events_ || sounds_;
  const bool want_mouse = mouse_events_ || cursor_->enabled();
  if (want_keyboard && !keyboard_hook_) {
    keyboard_hook_ = SetWindowsHookExW(WH_KEYBOARD_LL, KeyboardProc, GetModuleHandle(nullptr), 0);
    if (!keyboard_hook_) Log("Keyboard hook could not be installed (error " + std::to_string(GetLastError()) + ")");
  } else if (!want_keyboard && keyboard_hook_) {
    UnhookWindowsHookEx(keyboard_hook_);
    keyboard_hook_ = nullptr;
    keys_down_.reset();
  }
  if (want_mouse && !mouse_hook_) {
    mouse_hook_ = SetWindowsHookExW(WH_MOUSE_LL, MouseProc, GetModuleHandle(nullptr), 0);
    if (!mouse_hook_) Log("Mouse hook could not be installed (error " + std::to_string(GetLastError()) + ")");
  } else if (!want_mouse && mouse_hook_) {
    UnhookWindowsHookEx(mouse_hook_);
    mouse_hook_ = nullptr;
  }
}

void NativeHost::UpdateStartupEntry(bool enabled) {
  const std::wstring command = L"\"" + ExePath() + L"\" --background";
  wchar_t current[MAX_PATH * 2] = {};
  DWORD size = sizeof(current);
  const bool present =
      RegGetValueW(HKEY_CURRENT_USER, kRunKey, kRunValue, RRF_RT_REG_SZ, nullptr, current, &size) == ERROR_SUCCESS;
  if (enabled && (!present || command != current)) {
    const auto bytes = static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t));
    if (RegSetKeyValueW(HKEY_CURRENT_USER, kRunKey, kRunValue, REG_SZ, command.c_str(), bytes) != ERROR_SUCCESS) {
      Log("Could not add MonolithKeys to Windows startup");
    }
  } else if (!enabled && present) {
    RegDeleteKeyValueW(HKEY_CURRENT_USER, kRunKey, kRunValue);
  }
}

// ---------------------------------------------------------------------------
// Notification area

void NativeHost::AddTrayIcon() {
  NOTIFYICONDATAW nid{sizeof(nid)};
  nid.hWnd = host_window_;
  nid.uID = kTrayId;
  nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP;
  nid.uCallbackMessage = kTrayMessage;
  nid.hIcon = tray_icon_;
  wcscpy_s(nid.szTip, L"MonolithKeys");
  tray_added_ = Shell_NotifyIconW(NIM_ADD, &nid);
  nid.uVersion = NOTIFYICON_VERSION_4;
  Shell_NotifyIconW(NIM_SETVERSION, &nid);
}

void NativeHost::ShowTrayMenu() {
  HMENU menu = CreatePopupMenu();
  AppendMenuW(menu, MF_STRING, kOpen, L"Open MonolithKeys");
  SetMenuDefaultItem(menu, kOpen, FALSE);
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  for (int i = 0; i < 3; ++i) {
    std::wstring label = kFeatureLabels[i];
    if (hotkey_vks_[i]) label += L"\tCtrl+Alt+Shift+" + std::wstring(1, static_cast<wchar_t>(hotkey_vks_[i]));
    AppendMenuW(menu, MF_STRING | (tray_checks_[i] ? MF_CHECKED : MF_UNCHECKED), kToggleFirst + i, label.c_str());
  }
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kExit, L"Exit");

  POINT pt;
  GetCursorPos(&pt);
  // Required so the menu closes when the user clicks elsewhere.
  SetForegroundWindow(host_window_);
  const UINT command = TrackPopupMenuEx(menu, TPM_RETURNCMD | TPM_RIGHTBUTTON | TPM_NONOTIFY, pt.x, pt.y,
                                        host_window_, nullptr);
  PostMessageW(host_window_, WM_NULL, 0, 0);
  DestroyMenu(menu);

  if (command == kOpen) {
    ShowMainWindow();
  } else if (command == kExit) {
    Send("exit");
  } else if (command >= kToggleFirst && command < kToggleFirst + 3) {
    Send("toggle", EncodableValue(EncodableMap{{"feature", kFeatures[command - kToggleFirst]}}));
  }
}

// ---------------------------------------------------------------------------
// Input

void NativeHost::OnKey(DWORD vk, bool down, int modifiers, wchar_t character) {
  const bool repeat = down && keys_down_[vk];
  keys_down_[vk] = down;
  if (sounds_ && down && !repeat) audio_.Play(SoundFor(vk));
  if (key_events_) {
    PostMessageW(host_window_, kKeyMessage, vk,
                 static_cast<LPARAM>(character) | (static_cast<LPARAM>(modifiers) << 16) |
                     (static_cast<LPARAM>(down ? 1 : 0) << 20));
  }
}

// Hook callbacks do the minimum and return: anything that talks to Dart is
// posted to the host window and handled after the hook has returned.
LRESULT CALLBACK NativeHost::KeyboardProc(int code, WPARAM wparam, LPARAM lparam) {
  if (code == HC_ACTION && g_host) {
    const auto* k = reinterpret_cast<const KBDLLHOOKSTRUCT*>(lparam);
    if (k->vkCode < 256 && k->vkCode != VK_PACKET) {
      const bool down = wparam == WM_KEYDOWN || wparam == WM_SYSKEYDOWN;
      wchar_t character = 0;
      if (down && g_host->key_events_) {
        // Character the key types in the focused app's layout, without
        // Shift. MapVirtualKeyEx does not disturb dead-key state.
        HWND foreground = GetForegroundWindow();
        const HKL layout = GetKeyboardLayout(foreground ? GetWindowThreadProcessId(foreground, nullptr) : 0);
        character = static_cast<wchar_t>(MapVirtualKeyExW(k->vkCode, MAPVK_VK_TO_CHAR, layout) & 0x7FFF);
      }
      g_host->OnKey(k->vkCode, down, HeldModifiers(), character);
    }
  }
  return CallNextHookEx(nullptr, code, wparam, lparam);
}

LRESULT CALLBACK NativeHost::MouseProc(int code, WPARAM wparam, LPARAM lparam) {
  if (code == HC_ACTION && g_host) {
    const auto* m = reinterpret_cast<const MSLLHOOKSTRUCT*>(lparam);
    // Indices match MouseAction in lib/keystroke/keys.dart.
    int action = -1;
    switch (wparam) {
      case WM_MOUSEMOVE:
        g_host->cursor_->OnMove(m->pt);
        break;
      case WM_LBUTTONDOWN:
      case WM_LBUTTONUP:
        g_host->cursor_->OnButton(MouseButton::kLeft, wparam == WM_LBUTTONDOWN);
        if (wparam == WM_LBUTTONDOWN) action = 0;
        break;
      case WM_RBUTTONDOWN:
      case WM_RBUTTONUP:
        g_host->cursor_->OnButton(MouseButton::kRight, wparam == WM_RBUTTONDOWN);
        if (wparam == WM_RBUTTONDOWN) action = 1;
        break;
      case WM_MBUTTONDOWN:
      case WM_MBUTTONUP:
        g_host->cursor_->OnButton(MouseButton::kMiddle, wparam == WM_MBUTTONDOWN);
        if (wparam == WM_MBUTTONDOWN) action = 2;
        break;
      case WM_MOUSEWHEEL:
        action = static_cast<short>(HIWORD(m->mouseData)) > 0 ? 3 : 4;
        break;
    }
    if (action >= 0 && g_host->mouse_events_) {
      PostMessageW(g_host->host_window_, kMouseMessage, action, HeldModifiers());
    }
  }
  return CallNextHookEx(nullptr, code, wparam, lparam);
}

// ---------------------------------------------------------------------------
// Host window

LRESULT CALLBACK NativeHost::HostProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == WM_NCCREATE) {
    auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  } else if (auto* host = reinterpret_cast<NativeHost*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA))) {
    if (host->host_window_ == hwnd) return host->HandleMessage(message, wparam, lparam);
  }
  return DefWindowProcW(hwnd, message, wparam, lparam);
}

LRESULT NativeHost::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == show_message_) {
    ShowMainWindow();
    return 0;
  }
  if (message == taskbar_created_message_) {
    AddTrayIcon();
    return 0;
  }
  switch (message) {
    case kKeyMessage: {
      const auto character = static_cast<wchar_t>(lparam & 0xFFFF);
      const wchar_t text[2] = {character, 0};
      Send("key", EncodableValue(EncodableMap{
                      {"vk", static_cast<int>(wparam)},
                      {"down", ((lparam >> 20) & 1) != 0},
                      {"mods", static_cast<int>((lparam >> 16) & 0xF)},
                      {"char", character ? EncodableValue(Utf8FromUtf16(text)) : EncodableValue()},
                  }));
      return 0;
    }
    case kMouseMessage:
      Send("mouse", EncodableValue(EncodableMap{{"action", static_cast<int>(wparam)},
                                                {"mods", static_cast<int>(lparam)}}));
      return 0;
    case kTrayMessage:
      switch (LOWORD(lparam)) {
        case NIN_SELECT:
        case NIN_KEYSELECT:
          ShowMainWindow();
          break;
        case WM_CONTEXTMENU:
          ShowTrayMenu();
          break;
      }
      return 0;
    case WM_HOTKEY:
      if (wparam >= 1 && wparam <= 3) {
        Send("toggle", EncodableValue(EncodableMap{{"feature", kFeatures[wparam - 1]}}));
      }
      return 0;
    case WM_TIMER:
      if (wparam == kKeystrokeFadeTimer) {
        if (!keystrokes_.FadeStep()) KillTimer(host_window_, kKeystrokeFadeTimer);
      } else {
        cursor_->OnTimer(wparam);
      }
      return 0;
    case WM_QUERYENDSESSION:
      return TRUE;
    case WM_ENDSESSION:
      // Sign-out, shutdown, or an installer closing the app to update it.
      if (wparam) PostQuitMessage(0);
      return 0;
    case WM_DISPLAYCHANGE:
      Send("displaysChanged");
      return 0;
    case WM_SETTINGCHANGE:
      if (wparam == SPI_SETWORKAREA) Send("displaysChanged");
      return 0;
  }
  return DefWindowProcW(host_window_, message, wparam, lparam);
}
