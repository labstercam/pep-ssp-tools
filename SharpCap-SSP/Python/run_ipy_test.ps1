# PowerShell script to run IronPython tests
# Usage: .\run_ipy_test.ps1 test_goto.py

param(
    [Parameter(Mandatory=$true)]
    [string]$TestScript
)

# Change to script directory
Set-Location $PSScriptRoot

# Try to find IronPython executable (same logic as Launch_SSP.bat)
$ipyPaths = @(
    "C:\Program Files\IronPython 3.4\ipy.exe",
    "C:\Program Files (x86)\IronPython 3.4\ipy.exe",
    "C:\Program Files\IronPython 3.4.1\ipy.exe",
    "C:\Program Files (x86)\IronPython 3.4.1\ipy.exe",
    "$env:LOCALAPPDATA\Programs\IronPython 3.4\ipy.exe",
    "$env:USERPROFILE\AppData\Local\Programs\IronPython\ipy.exe"
)

$ipyExe = $null
foreach ($path in $ipyPaths) {
    if (Test-Path $path) {
        $ipyExe = $path
        Write-Host "Found IronPython at: $path" -ForegroundColor Green
        break
    }
}

if ($null -eq $ipyExe) {
    Write-Host "ERROR: IronPython not found in common locations" -ForegroundColor Red
    exit 1
}

# Run the test script
Write-Host "`nRunning: $TestScript`n" -ForegroundColor Cyan
& $ipyExe $TestScript
exit $LASTEXITCODE
