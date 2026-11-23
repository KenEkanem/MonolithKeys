# Captures the real keystroke overlay and cursor highlight for visual review.
# Launches the built app once per template, injects key presses and pointer
# movement through the OS, and saves a screenshot of the primary display.
#
#   powershell -ExecutionPolicy Bypass -File tool\capture_overlay.ps1 -OutDir artifacts\overlay
#
# Overwrites %APPDATA%\MonolithKeys\settings.json, so run it on a test machine.
param(
  [string]$Exe = 'build\windows\x64\runner\Release\MonolithKeys.exe',
  [string]$OutDir = 'build\overlay'
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Input {
  [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] static extern void mouse_event(uint flags, int dx, int dy, uint data, UIntPtr extra);
  [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
  public static void Dpi() { SetProcessDPIAware(); }
  public static void Press(params byte[] vks) {
    foreach (var vk in vks) keybd_event(vk, 0, 0, UIntPtr.Zero);
    for (int i = vks.Length - 1; i >= 0; i--) keybd_event(vks[i], 0, 2, UIntPtr.Zero);
  }
  // Absolute move on the primary display, 0..65535 in each axis.
  public static void MoveTo(int x, int y) { mouse_event(0x8001, x, y, 0, UIntPtr.Zero); }
  public static void ButtonDown() { mouse_event(0x0008, 0, 0, 0, UIntPtr.Zero); }
  public static void ButtonUp() { mouse_event(0x0010, 0, 0, 0, UIntPtr.Zero); }
}
'@
[Input]::Dpi()

$exe = (Resolve-Path $Exe).Path
$settingsDir = Join-Path $env:APPDATA 'MonolithKeys'
New-Item -ItemType Directory -Force $settingsDir, $OutDir | Out-Null

$VK_CTRL = 0xA2; $VK_SHIFT = 0xA0; $VK_ALT = 0xA4; $VK_F13 = 0x7C; $VK_LEFT = 0x25

$cases = @(
  @{ name = 'classic-graphite'; template = 'classic'; color = 'graphite'; cursor = 'ring' },
  @{ name = 'minimal-snow'; template = 'minimal'; color = 'snow'; cursor = 'halo' },
  @{ name = 'accent-ocean'; template = 'accent'; color = 'ocean'; cursor = 'target' },
  @{ name = 'presentation-violet'; template = 'presentation'; color = 'violet'; cursor = 'solid-diamond' }
)

foreach ($c in $cases) {
  @{
    keyTemplate = $c.template; keyColor = $c.color; keyHideAfterMs = 10000; macSymbols = $true
    cursorTemplate = $c.cursor; cursorSize = 90; cursorGlow = 0.7; clickAnimation = 'none'
  } | ConvertTo-Json | Set-Content (Join-Path $settingsDir 'settings.json')

  $app = Start-Process $exe -ArgumentList '--background' -PassThru
  Start-Sleep -Seconds 8
  [Input]::MoveTo(30000, 26000); Start-Sleep -Milliseconds 300
  [Input]::MoveTo(32768, 30000); Start-Sleep -Milliseconds 300
  [Input]::Press($VK_CTRL, $VK_SHIFT, $VK_F13)
  [Input]::Press($VK_ALT, $VK_LEFT)
  [Input]::Press($VK_F13); [Input]::Press($VK_F13); [Input]::Press($VK_F13)
  # Hold the left button so the click colour shows in the capture.
  [Input]::ButtonDown()
  Start-Sleep -Milliseconds 600

  $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
  $bitmap.Save((Join-Path $OutDir "$($c.name).png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $graphics.Dispose(); $bitmap.Dispose()
  [Input]::ButtonUp()

  Stop-Process -Id $app.Id -Force
  Start-Sleep -Seconds 2
  Write-Host "captured $($c.name)"
}
Remove-Item (Join-Path $settingsDir 'settings.json')
