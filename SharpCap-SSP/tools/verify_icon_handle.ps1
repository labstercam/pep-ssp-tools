<#
    Verification for the Phase 2 icon-handle fix (Section 10.3 of BUG_FIXES.md).

        powershell -ExecutionPolicy Bypass -File tools\verify_icon_handle.ps1

    Proves, against the real .NET System.Drawing that IronPython binds to, that:

      * Image.FromFile holds the icon file open for as long as the Image lives
        (the leak that kept SSP.ico locked for the whole SharpCap session);
      * the shipped replacement - ReadAllBytes -> MemoryStream -> Image.FromStream -
        does not hold the file open;
      * both load paths yield a pixel-identical image, including alpha (so the
        toolbar icon cannot change appearance).

    Two independent copies of the icon are used, so a still-alive Image from one
    pattern can never confound the measurement of the other.

    Exit code 0 on success, 1 on failure.
#>
param(
    [string]$IconPath = (Join-Path $PSScriptRoot '..\Python\SSP.ico')
)

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path -LiteralPath $IconPath)) {
    Write-Host "ERROR: icon not found: $IconPath" -ForegroundColor Red
    exit 1
}
$IconPath = (Resolve-Path -LiteralPath $IconPath).Path
Write-Host "Icon under test: $IconPath"

$copyA = Join-Path $env:TEMP 'ssp_icon_old.ico'
$copyB = Join-Path $env:TEMP 'ssp_icon_new.ico'
Copy-Item -LiteralPath $IconPath -Destination $copyA -Force
Copy-Item -LiteralPath $IconPath -Destination $copyB -Force

function Test-FileLocked([string]$path) {
    try {
        $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open,
                                     [System.IO.FileAccess]::ReadWrite,
                                     [System.IO.FileShare]::None)
        $fs.Close(); $fs.Dispose()
        return $false
    } catch {
        return $true
    }
}

$baselineClean = (-not (Test-FileLocked $copyA)) -and (-not (Test-FileLocked $copyB))
Write-Host ("baseline: untouched copies unlocked      : {0}" -f $baselineClean)

# --- OLD pattern: Image.FromFile -------------------------------------
$old = [System.Drawing.Image]::FromFile($copyA)
$oldLocked = Test-FileLocked $copyA
Write-Host ("OLD Image.FromFile holds file open       : {0}" -f $oldLocked)

# --- NEW pattern: ReadAllBytes -> MemoryStream -> FromStream ---------
$bytes    = [System.IO.File]::ReadAllBytes($copyB)
$readFreed = -not (Test-FileLocked $copyB)
$stream   = New-Object System.IO.MemoryStream (,$bytes)
$new      = [System.Drawing.Image]::FromStream($stream)
$newLocked = Test-FileLocked $copyB
Write-Host ("NEW ReadAllBytes releases the file       : {0}" -f $readFreed)
Write-Host ("NEW FromStream holds file open           : {0}" -f $newLocked)

# --- pixel identity ---------------------------------------------------
$b1 = New-Object System.Drawing.Bitmap $old
$b2 = New-Object System.Drawing.Bitmap $new
$differing = 0
for ($y = 0; $y -lt $b1.Height; $y++) {
    for ($x = 0; $x -lt $b1.Width; $x++) {
        if ($b1.GetPixel($x, $y).ToArgb() -ne $b2.GetPixel($x, $y).ToArgb()) { $differing++ }
    }
}
$identical = ($differing -eq 0)
Write-Host ("size / pixel format                      : {0}x{1} {2} / {3}x{4} {5}" -f `
    $old.Width, $old.Height, $old.PixelFormat, $new.Width, $new.Height, $new.PixelFormat)
Write-Host ("pixels identical incl. alpha             : {0} (differing: {1})" -f $identical, $differing)
$sameFormat = ($old.PixelFormat -eq $new.PixelFormat) -and `
              ($old.Width -eq $new.Width) -and ($old.Height -eq $new.Height)

# --- the lock must lift once the old Image is disposed ----------------
$old.Dispose(); Start-Sleep -Milliseconds 200
$freedAfterDispose = -not (Test-FileLocked $copyA)

$b1.Dispose(); $b2.Dispose(); $new.Dispose(); $stream.Dispose()
Remove-Item -LiteralPath $copyA, $copyB -Force -ErrorAction SilentlyContinue

Write-Host ''
$passed = $baselineClean -and $oldLocked -and $readFreed -and (-not $newLocked) `
          -and $identical -and $sameFormat -and $freedAfterDispose
if ($passed) {
    Write-Host 'ALL ICON HANDLE CHECKS PASSED' -ForegroundColor Green
    exit 0
}
Write-Host 'ICON HANDLE CHECKS FAILED' -ForegroundColor Red
exit 1
