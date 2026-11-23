# One-time setup: creates a private Python environment and installs the voice app's packages.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$python = $null
foreach ($cmd in @("py", "python")) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found -and $found.Source -notlike "*WindowsApps*") { $python = $found.Source; break }
}
if (-not $python) {
    Write-Host "Python 3.12 is not installed. Install it with:" -ForegroundColor Yellow
    Write-Host "  winget install -e --id Python.Python.3.12"
    Write-Host "then open a new PowerShell window and run this script again."
    exit 1
}

if (-not (Test-Path ".venv")) {
    Write-Host "Creating Python environment..."
    if ((Split-Path $python -Leaf) -eq "py.exe") { & $python -3.12 -m venv .venv } else { & $python -m venv .venv }
}

& .\.venv\Scripts\python.exe -m pip install --upgrade pip
& .\.venv\Scripts\python.exe -m pip install -r requirements.txt

Write-Host ""
Write-Host "Setup done. Double-click 'Start Voice.bat' to run." -ForegroundColor Green
