# Builds the release app and the installer. Run from the repository root on
# Windows with Flutter and Inno Setup 6 installed:
#
#   powershell -ExecutionPolicy Bypass -File tool\build_release.ps1
#
# Output: build\windows\x64\runner\Release\MonolithKeys.exe
#         build\installer\MonolithKeys-Setup-<version>.exe
param([string]$Version)
$ErrorActionPreference = 'Stop'

function Invoke-Checked([string]$Exe, [string[]]$Arguments) {
  & $Exe @Arguments
  if ($LASTEXITCODE -ne 0) { throw "$Exe exited with code $LASTEXITCODE" }
}

if (-not $Version) {
  $Version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)').Matches[0].Groups[1].Value
}
$build = (git rev-parse --short HEAD).Trim()
$date = Get-Date -Format 'yyyy-MM-dd'

Invoke-Checked flutter @('build', 'windows', '--release',
  "--build-name=$Version",
  "--dart-define=APP_VERSION=$Version",
  "--dart-define=APP_BUILD=$build",
  "--dart-define=APP_BUILD_DATE=$date")

$iscc = Get-Command iscc -ErrorAction SilentlyContinue
$isccPath = if ($iscc) { $iscc.Source } else { "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" }
if (-not (Test-Path $isccPath)) { throw 'Inno Setup 6 is not installed (choco install innosetup).' }
Invoke-Checked $isccPath @("/DAppVersion=$Version", 'installer\MonolithKeys.iss')

Write-Host "Built MonolithKeys $Version ($build)"
