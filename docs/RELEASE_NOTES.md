# Release notes

## 1.0.0

First release.

**Keystroke overlay**
- Shows key combinations as key caps in Windows order (Win, Ctrl, Alt, Shift), with repeat counts such as "Ctrl + Z ×3".
- Five templates (Classic, Minimal, Soft, Accent, Presentation) and nine colors.
- Choose the display, horizontal and vertical position, size (50 to 200%) and how long keys stay visible.
- Options: shortcuts only, one key at a time, Mac symbols next to modifier names, and mouse clicks and scrolling.
- Labels follow the active keyboard layout.

**Cursor highlight**
- Thirteen styles, size, glow, and hide-when-still.
- Click animations (pulse, ripple, shrink) and separate colors for left, right and middle clicks.
- Can follow the pointer or stay at the center of the screen or active window.

**Sounds**
- Five synthesized key sound sets with volume control and preview. Space, Enter and Backspace have their own sounds.

**App**
- Global shortcuts Ctrl + Alt + Shift + K, N and M, with a notice when another app already uses one.
- Notification area icon with quick toggles.
- Start with Windows, start hidden, light and dark themes, and restore defaults.
- Per-user installer with optional all-users install, Start menu and optional desktop shortcuts, and clean uninstall.

**Known limitations**
- The installer and app are not code-signed. Smart App Control blocks them, and SmartScreen warns on first run where Smart App Control is off.
- Online license activation is not available yet. All features work without a license.
- Overlays cannot draw over exclusive full-screen games or over secure screens such as UAC prompts and the lock screen.
- Keystrokes typed into elevated (administrator) apps are not seen unless MonolithKeys also runs as administrator. This is a Windows restriction on input hooks.
