# SharpCap-SSP Installation Script for IronPython 3.4
# Downloads and extracts System.IO.Ports NuGet package

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "SharpCap-SSP Setup - Installing System.IO.Ports" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# NuGet package details
$packageName = "System.IO.Ports"
$packageVersion = "8.0.0"
$nugetUrl = "https://www.nuget.org/api/v2/package/$packageName/$packageVersion"
$outputFile = "System.IO.Ports.nupkg"
$extractDir = "extracted_nuget"

Write-Host "Downloading $packageName version $packageVersion..." -ForegroundColor Yellow

try {
    # Download the NuGet package
    Invoke-WebRequest -Uri $nugetUrl -OutFile $outputFile -UseBasicParsing
    Write-Host "Download complete!" -ForegroundColor Green
    Write-Host ""
    
    # Rename .nupkg to .zip (NuGet packages are ZIP files)
    Write-Host "Preparing package for extraction..." -ForegroundColor Yellow
    $zipFile = "System.IO.Ports.zip"
    if (Test-Path $zipFile) {
        Remove-Item $zipFile -Force
    }
    Rename-Item $outputFile $zipFile
    
    # Extract the package
    Write-Host "Extracting package..." -ForegroundColor Yellow
    if (Test-Path $extractDir) {
        Remove-Item $extractDir -Recurse -Force
    }
    Expand-Archive -Path $zipFile -DestinationPath $extractDir -Force
    
    Write-Host "Extraction complete!" -ForegroundColor Green
    Write-Host ""
    
    # Find and copy the DLL
    Write-Host "Looking for System.IO.Ports.dll..." -ForegroundColor Yellow
    
    # Try different framework versions in order of preference
    $frameworks = @("net8.0", "net7.0", "net6.0", "net5.0", "netstandard2.1", "netstandard2.0")
    $dllFound = $false
    
    foreach ($fw in $frameworks) {
        $dllPath = Join-Path $extractDir "lib\$fw\System.IO.Ports.dll"
        if (Test-Path $dllPath) {
            Write-Host "Found DLL for $fw" -ForegroundColor Green
            Copy-Item $dllPath -Destination "." -Force
            $dllFound = $true
            break
        }
    }
    
    if ($dllFound) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Green
        Write-Host "Installation successful!" -ForegroundColor Green
        Write-Host "============================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "System.IO.Ports.dll has been copied to:" -ForegroundColor White
        Write-Host "  $(Get-Location)\System.IO.Ports.dll" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "You can now run SharpCap-SSP:" -ForegroundColor White
        Write-Host "  ipy" -ForegroundColor Cyan
        Write-Host "  >>> exec(open('main.py').read())" -ForegroundColor Cyan
        Write-Host ""
        
        # Cleanup
        Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
        Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
        Remove-Item $extractDir -Recurse -Force
        Write-Host "Done!" -ForegroundColor Green
        
    } else {
        Write-Host "ERROR: Could not find System.IO.Ports.dll in package" -ForegroundColor Red
        Write-Host "Available frameworks in package:" -ForegroundColor Yellow
        Get-ChildItem (Join-Path $extractDir "lib") -Directory | ForEach-Object { Write-Host "  $($_.Name)" }
    }
    
} catch {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "Installation failed!" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual installation instructions:" -ForegroundColor Yellow
    Write-Host "1. Go to: https://www.nuget.org/packages/System.IO.Ports/" -ForegroundColor White
    Write-Host "2. Click 'Download package'" -ForegroundColor White
    Write-Host "3. Rename .nupkg file to .zip" -ForegroundColor White
    Write-Host "4. Extract and copy System.IO.Ports.dll from lib\net6.0\ to this folder" -ForegroundColor White
    Write-Host ""
}

Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
