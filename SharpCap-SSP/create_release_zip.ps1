# Create release ZIP for SharpCap-SSP v0.1.5

$files = @(
    "Python\main.py",
    "Python\ssp_dataaq.py",
    "Python\ssp_comm.py",
    "Python\ssp_config.py",
    "Python\ssp_dialogs.py",
    "Python\ssp_catalog.py",
    "Python\ssp_extinction.py",
    "Python\ssp_allsky.py",
    "Python\ssp_location_utils.py",
    "Python\night_mode.py",
    "Python\ssp_docking.py",
    "Python\install.ps1",
    "Python\Launch_SSP.bat",
    "Python\Create_Desktop_Shortcut.bat",
    "Python\QUICK_INSTALL.txt",
    "Python\SETUP.md",
    "Python\requirements.txt",
    "Python\SSP.ico",
    "Python\starparm_latest.csv",
    "Python\first_order_extinction_stars.csv",
    "Python\verify_optimization.py",
    "Python\test_memory_optimization.py",
    "Python\ssp_quick_test.py",
    "Python\ssp_test_serial.py",
    "Python\System.IO.Ports.dll",
    "README.md",
    "QUICK_START.md",
    "IMPLEMENTATION_SUMMARY.md",
    "OPTIMIZATION_SUMMARY.md",
    "DOCKING.md"
)

$zipPath = "SharpCap-SSP-v0.1.5.zip"

Write-Host "Creating $zipPath..." -ForegroundColor Green

if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
    Write-Host "Removed existing zip file" -ForegroundColor Yellow
}

Compress-Archive -Path $files -DestinationPath $zipPath -CompressionLevel Optimal

if (Test-Path $zipPath) {
    $size = (Get-Item $zipPath).Length / 1KB
    Write-Host "Success! Created $zipPath ($([math]::Round($size, 1)) KB)" -ForegroundColor Green
} else {
    Write-Host "ERROR: Failed to create zip file" -ForegroundColor Red
}

Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
