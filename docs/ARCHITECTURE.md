# Architecture

MonolithKeys is a Flutter app for Windows with a small C++ layer in the Windows runner. Dart owns the product: settings, what the overlay shows, templates, sounds, licensing and the settings window. C++ owns what only Windows can do: input hooks, global shortcuts, the tray icon, overlay windows and audio output.

```
 Settings window (Flutter)                    Windows runner (C++)
 ┌────────────────────────────┐   channel     ┌──────────────────────────────┐
 │ SettingsController ──┐     │ "monolithkeys │ NativeHost                   │
 │ AppController ───────┼─────┼───/native"────┤  ├ WH_KEYBOARD_LL, WH_MOUSE_LL│
 │  ├ KeystrokeComposer │     │               │  ├ RegisterHotKey            │
 │  ├ key templates     │     │               │  ├ tray icon and menu        │
 │  └ sound synthesis   │     │               │  ├ KeystrokeOverlay (GDI+)   │
 │ LicenseService       │     │               │  ├ CursorOverlay (GDI+)      │
 │ Pages and widgets ───┘     │               │  ├ AudioPlayer (waveOut)     │
 └────────────────────────────┘               │  └ startup entry, displays   │
                                              └──────────────────────────────┘
```

## Why Flutter with native overlays

The settings window is ordinary UI and benefits from Flutter's testability: nearly all product logic runs in `flutter test` on any OS. The overlays must be transparent, click-through, always on top and never take focus, and they must follow the pointer at input rate. Flutter windows cannot do that reliably, so the overlays are Win32 layered windows drawn with GDI+ and updated with `UpdateLayeredWindow`.

## Data flow

1. `SettingsController` holds `Settings`, saves them to `%APPDATA%\MonolithKeys\settings.json` 400 ms after the last change, and notifies listeners.
2. `AppController` turns settings into one configuration map (`nativeConfig`) and sends it with `configure`. The reply reports whether each shortcut registered or is taken by another app.
3. Hook callbacks in C++ do the minimum and return. Keys and clicks for the overlay are posted to the host window, then sent to Dart as `key` and `mouse` calls. Sounds are queued to the audio thread straight from the hook. Pointer moves never leave C++.
4. `KeystrokeComposer` decides what is on screen (combinations, repeats, hide timing). `overlayScene` resolves template colors and sizes, and `showKeystrokes` sends the result. `KeystrokeOverlay` only lays out and draws it.
5. Shortcuts and tray toggles arrive as `toggle`, which flips the setting. The new configuration then flows back through step 2.

## Rules that keep the two sides in step

- Enum index order is shared: `CapGlyph`, `MouseAction`, `Modifier` bits, `CursorShape`, `CursorPlacement`, `ClickAnimation` and `SoundKind`. Each enum is commented where it crosses the channel.
- The overlay position rule exists twice: `overlayOrigin` in Dart (used by the display preview) and `AlignInArea` in C++.
- Cursor shape geometry exists twice: `CursorShapePainter` (settings preview) and `CursorOverlay::Render`.
- Key cap layout exists twice: `KeystrokePreview` and `KeystrokeOverlay::Show`.

Change these pairs together.

## Windows behaviour

- **Hooks** are installed only while a feature needs them and removed when it is turned off. With every feature off, no input is observed.
- **Keyboard layouts**: the label for a character key comes from `MapVirtualKeyEx` with the focused app's layout, which does not disturb dead-key state.
- **Stuck keys**: each event carries the OS view of held modifiers, and the composer forgets held keys after 10 s without input. This recovers from key-ups lost to the lock screen or UAC.
- **DPI**: the process is Per-Monitor V2 aware. Overlays scale to the DPI of the display they are on, and the cursor highlight re-renders when it crosses to a display with a different scale.
- **Single instance**: a per-session mutex. A second launch asks the running copy to show its window, then exits.
- **Lifecycle**: closing the window hides it. Exit (sidebar or tray), sign-out and installer upgrades end the message loop, and the hooks, shortcuts, tray icon, overlays and audio thread are released in `NativeHost`'s destructor.
- **Startup** uses the per-user `Run` key with `--background`, which starts without showing the window.

## Licensing

`LicenseService` stores the activated key and expiry, masks the key in the UI and reports expired licenses. Activation goes through the `LicenseClient` interface. No licensing server exists yet, so the app ships `UnconfiguredLicenseClient`, which never reports success, and the License page says that online activation is not available. Every feature works without a license. To connect a real service, implement `LicenseClient` and pass it in `lib/main.dart`.

## Tests

| Suite | Runs on | Covers |
| --- | --- | --- |
| `test/` | any OS | settings persistence and validation, composer rules, key labels, templates, sound synthesis, display maths, license states, controller wiring with a fake native host, and settings window widgets |
| `integration_test/` | Windows | real hooks via injected key presses, global shortcut toggling, startup registry entry, display enumeration, overlay and sound calls |
| `tool/smoke_test.ps1` | Windows | installer: install, launch, single instance, upgrade over a running copy, settings kept, uninstall cleanup |
