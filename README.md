# MonolithKeys

MonolithKeys shows the keys you press and highlights your mouse pointer, for screen recordings, live demos and teaching. It runs on Windows 10 and Windows 11 (64-bit) and sits in the notification area.

- **Keystroke overlay**: key combinations appear as key caps on the display you choose, in five templates and nine colors.
- **Cursor highlight**: a ring, disc, diamond, square or crosshair around the pointer, with click colors and click animations.
- **Key sounds**: five synthesized sound sets with volume control.
- **Shortcuts**: Ctrl + Alt + Shift + K, N and M turn the overlay, highlight and sounds on and off from anywhere.

## Install

1. Download `MonolithKeys-Setup-<version>.exe` from the latest build.
2. Run it. By default it installs for your account only and needs no administrator rights. Choose "Install for all users" if everyone on the PC should have it.
3. MonolithKeys opens when setup finishes. Afterwards, start it from the Start menu.

The installer is not code-signed yet, so Windows SmartScreen may show "Windows protected your PC". Choose **More info**, then **Run anyway**.

To upgrade, run a newer installer. It closes MonolithKeys first and keeps your settings.

To uninstall, use **Settings > Apps > Installed apps > MonolithKeys > Uninstall**. You will be asked whether to remove your settings as well.

## Use

- Closing the window keeps MonolithKeys running in the notification area. Click the tray icon to open settings again, or right-click it for quick toggles and **Exit**.
- **General** has the main switches, shortcuts, startup options and dark theme.
- **Keystroke** picks the display, position, template, colors and size of the overlay, and how long keys stay visible.
- **Cursor** sets the highlight style, size, glow, click animation and colors.
- **Sounds** picks a sound set. Use the play button to hear one before choosing.

If a shortcut is already taken by another app, the General page says so next to it.

## Privacy

MonolithKeys reads keyboard and mouse input only while a feature that needs it is on, and only to draw the overlay and play sounds. It never stores, logs or sends what you type, and it makes no network connections. With the overlay, highlight and sounds all off, it does not watch input at all.

Files it keeps:

| What | Where |
| --- | --- |
| Settings | `%APPDATA%\MonolithKeys\settings.json` |
| License | `%APPDATA%\MonolithKeys\license.json` |
| Diagnostic logs (no key data, kept 7 days) | `%LOCALAPPDATA%\MonolithKeys\logs` |
| Startup entry, when enabled | `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\MonolithKeys` |

## Build from source

Requirements: Windows 10 or 11, [Flutter](https://docs.flutter.dev/get-started/install/windows/desktop) 3.50, Visual Studio 2022 with "Desktop development with C++", and [Inno Setup 6](https://jrsoftware.org/isinfo.php) for the installer.

```powershell
flutter pub get
flutter test                              # unit and widget tests (also run on Linux and macOS)
flutter test integration_test -d windows  # end-to-end tests against the real Windows layer
flutter run -d windows                    # development build
powershell -ExecutionPolicy Bypass -File tool\build_release.ps1
powershell -ExecutionPolicy Bypass -File tool\smoke_test.ps1 -Installer build\installer\MonolithKeys-Setup-1.0.0.exe
```

`build_release.ps1` produces `build\windows\x64\runner\Release\MonolithKeys.exe` and `build\installer\MonolithKeys-Setup-<version>.exe`. The smoke test installs, launches, upgrades and uninstalls that installer for the current user, so run it on a test machine or CI.

Every push runs the same steps on GitHub Actions (`.github/workflows/build.yml`) and publishes the installer and a portable folder as build artifacts.

Other tools:

- `tool/make_icon.sh` regenerates the app icon (needs ImageMagick).
- `flutter test tool/screenshots/screenshot_test.dart` renders every settings page to `build/screenshots/` for design review.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the code is organized and [docs/RELEASE_NOTES.md](docs/RELEASE_NOTES.md) for changes.
