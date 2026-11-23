# Builds release\Comunimate-Setup-<version>.exe
#   1. bundles the tray helper + voice engine + WoW add-on with PyInstaller
#   2. wraps it in an installer with Inno Setup
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$py = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
$addon = Resolve-Path (Join-Path $PSScriptRoot "..\Comunimate")
$version = ((Get-Content (Join-Path $addon "Comunimate.toc")) | Where-Object { $_ -like "## Version:*" }) -replace "## Version:\s*", ""
Write-Host "Building Comunimate $version"

New-Item -ItemType Directory -Force build | Out-Null
# Build outside OneDrive: syncing locks files mid-build.
$work = Join-Path $env:LOCALAPPDATA "ComunimateBuild"
$dist = Join-Path $work "dist"
New-Item -ItemType Directory -Force $work | Out-Null

# App icon (same mic as the tray icon).
& $py -c "import helper; img = helper.tray_image('ready', 256); img.save(r'build\comunimate.ico', sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])"
if ($LASTEXITCODE) { throw "icon failed" }

& $py -m PyInstaller --noconfirm --clean --windowed `
    --name Comunimate `
    --icon (Join-Path $PSScriptRoot "build\comunimate.ico") `
    --add-data "$addon;Comunimate" `
    --add-data "$(Join-Path $PSScriptRoot 'config.json');." `
    --collect-data faster_whisper `
    --collect-binaries ctranslate2 `
    --hidden-import pystray._win32 `
    --exclude-module tkinter `
    --distpath $dist --workpath (Join-Path $work "pyi") --specpath $work `
    helper.py
if ($LASTEXITCODE) { throw "PyInstaller failed" }

$iscc = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw "Inno Setup not found. Install it: winget install -e --id JRSoftware.InnoSetup" }

& $iscc "/DAppVersion=$version" "/DDistDir=$dist\Comunimate" installer.iss
if ($LASTEXITCODE) { throw "Inno Setup failed" }

Write-Host "Done: $(Resolve-Path ..\release)" -ForegroundColor Green
