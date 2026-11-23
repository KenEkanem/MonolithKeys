# Installs, launches, upgrades and uninstalls the real installer, checking
# each step. Run on a Windows machine (or CI) where MonolithKeys is not
# already installed for the current user:
#
#   powershell -ExecutionPolicy Bypass -File tool\smoke_test.ps1 -Installer build\installer\MonolithKeys-Setup-1.0.0.exe
param([Parameter(Mandatory = $true)][string]$Installer)
$ErrorActionPreference = 'Stop'

$appDir = Join-Path $env:LOCALAPPDATA 'Programs\MonolithKeys'
$exe = Join-Path $appDir 'MonolithKeys.exe'
$settingsDir = Join-Path $env:APPDATA 'MonolithKeys'
$logDir = Join-Path $env:LOCALAPPDATA 'MonolithKeys\logs'
$silent = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER', '/CLOSEAPPLICATIONS')

function Check([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw "FAILED: $Message" }
  Write-Host "ok   $Message"
}

function Install() {
  $p = Start-Process $Installer -ArgumentList $silent -Wait -PassThru
  Check ($p.ExitCode -eq 0) "installer exits with 0 (got $($p.ExitCode))"
}

function Running() { @(Get-Process MonolithKeys -ErrorAction SilentlyContinue) }

# Install
Install
Check (Test-Path $exe) 'MonolithKeys.exe is installed per user'
Check (Test-Path (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\MonolithKeys.lnk')) 'Start menu shortcut exists'
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{37169598-82D6-4BAC-AFF1-6B43666FE57E}_is1'
Check (Test-Path $uninstallKey) 'listed in Installed apps'
$version = (Get-Item $exe).VersionInfo
Check ($version.ProductName -eq 'MonolithKeys') "exe version info names the product ($($version.ProductVersion))"

# Launch as the startup entry would
$app = Start-Process $exe -ArgumentList '--background' -PassThru
Start-Sleep -Seconds 10
Check (-not $app.HasExited) 'app keeps running after launch'
$log = Get-ChildItem $logDir -Filter '*.log' | Sort-Object LastWriteTime | Select-Object -Last 1
Check ($null -ne $log -and (Select-String -Path $log.FullName -Pattern 'Started in background' -Quiet)) 'startup is logged'
Check (-not (Select-String -Path $log.FullName -Pattern ' ERROR ' -Quiet)) 'no errors logged at startup'
Check (-not (Select-String -Path $log.FullName -Pattern 'hook could not be installed' -Quiet)) 'input hooks installed'

$second = Start-Process $exe -Wait -PassThru
Check ($second.ExitCode -eq 0) 'a second launch exits cleanly'
Check ((Running).Count -eq 1) 'only one instance runs'
$before = (Get-Process -Id $app.Id).CPU
Start-Sleep -Seconds 10
$process = Get-Process -Id $app.Id
$idleCpu = $process.CPU - $before
Write-Host ("info working set {0:N1} MB; CPU used while idle for 10 s: {1:N2} s" -f ($process.WorkingSet64 / 1MB), $idleCpu)
Check ($idleCpu -lt 0.5) 'near-zero CPU while idle'

# Upgrade over the running app; user settings must survive
New-Item -ItemType Directory -Force $settingsDir | Out-Null
'{ "keyScale": 150 }' | Set-Content (Join-Path $settingsDir 'settings.json')
Install
Start-Sleep -Seconds 2
Check ((Running).Count -eq 0) 'the installer closed the running app before upgrading'
Check ((Get-Content (Join-Path $settingsDir 'settings.json') -Raw) -match '"keyScale": 150') 'settings survive an upgrade'

# Uninstall while running, with a startup entry like the app creates
Start-Process $exe -ArgumentList '--background'
Start-Sleep -Seconds 5
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name MonolithKeys -Value "`"$exe`" --background"
# unins000.exe relaunches itself from a temporary copy, so wait for the result.
Start-Process (Join-Path $appDir 'unins000.exe') -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART')
Start-Sleep -Seconds 2
for ($i = 0; $i -lt 60 -and (Get-Process -Name '_iu*' -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Seconds 1 }
Check (-not (Test-Path $exe)) 'program files removed'
Check ((Running).Count -eq 0) 'no MonolithKeys process left running'
Check (-not (Test-Path $uninstallKey)) 'removed from Installed apps'
$run = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name MonolithKeys -ErrorAction SilentlyContinue
Check ($null -eq $run) 'no startup entry left behind'
Check (Test-Path (Join-Path $settingsDir 'settings.json')) 'a silent uninstall keeps user settings'

Write-Host 'Smoke test passed'
