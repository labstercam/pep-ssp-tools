<#
.SYNOPSIS
    Fixed-interval memory sampler for SharpCap.

.DESCRIPTION
    Memory monitor for the SSP OutOfMemoryException investigation
    (see SharpCap-SSP/MEMORY_ANALYSIS.md).

    Samples a SharpCap process on a fixed clock and writes a CSV plus a live
    console trace. The primary metric is Private Bytes: Working Set under-reports
    the leak because Windows trims it (MEMORY_ANALYSIS.md 7.1).

    Read-only. Does not modify SharpCap, its settings, or the registry.

    Typical use is the Phase 0 control experiment (MEMORY_ANALYSIS.md 7.4):
      Leg A  camera stopped, no SSP script   -> host baseline
      Leg B  camera live,   no SSP script    -> the decisive measurement
      Leg C  camera live,   SSP script       -> reference

    On an 8 GB machine keep runs short. At the measured ~2.6 MB/s a 100-star
    session would need ~15 GB, so long runs are fatal rather than informative.

.PARAMETER DurationMinutes
    How long to sample. Default 8.

.PARAMETER Label
    Free-text tag used in the CSV filename, e.g. LegA_stopped or LegB_camera_live.

.PARAMETER ProcessName
    Process name to sample. Default SharpCap.

.PARAMETER IntervalSeconds
    Seconds between samples. Default 60.

.PARAMETER OutputDir
    CSV output directory. Default %USERPROFILE%\Documents\SharpCap\phase0.

.EXAMPLE
    .\monitor_sharpcap.ps1 -DurationMinutes 8 -Label LegB_camera_live

.EXAMPLE
    .\monitor_sharpcap.ps1 -DurationMinutes 8 -Label LegA_stopped -IntervalSeconds 30
#>
[CmdletBinding()]
param(
    [int]$DurationMinutes = 100,
    [string]$Label = 'run',
    [string]$ProcessName = 'SharpCap',
    [int]$IntervalSeconds = 60,
    [string]$OutputDir = (Join-Path $env:USERPROFILE 'Documents\SharpCap\phase0')
)

$ErrorActionPreference = 'Continue'

# --- GDI / USER handle counts via user32!GetGuiResources -------------------
# WinForms controls release GDI/USER handles in Dispose(), not in the finalizer,
# so these counts are a direct leak signal (MEMORY_ANALYSIS.md 2.1).
$guiType = 'SspMemTest.GuiResources' -as [type]
if (-not $guiType) {
    Add-Type -Namespace SspMemTest -Name GuiResources -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
public static extern uint GetGuiResources(System.IntPtr hProcess, uint uiFlags);
'@
}

# --- output ---------------------------------------------------------------
if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$csvPath = Join-Path $OutputDir ("memory_{0}_{1}.csv" -f $Label, $stamp)

$header = @(
    'timestamp', 'elapsed_s', 'working_set_mb', 'private_mb', 'peak_working_set_mb',
    'handle_count', 'thread_count', 'gdi_handles', 'user_handles',
    'ws_rate_mb_per_s', 'private_rate_mb_per_s'
) -join ','
$header | Out-File -LiteralPath $csvPath -Encoding UTF8

Write-Host ''
Write-Host 'SharpCap memory monitor' -ForegroundColor Cyan
Write-Host "  process  : $ProcessName"
Write-Host "  duration : $DurationMinutes min"
Write-Host "  interval : $IntervalSeconds s"
Write-Host "  csv      : $csvPath"
Write-Host '  primary  : private_mb (working set under-reports; MEMORY_ANALYSIS 7.1)'
Write-Host ''
Write-Host 'Ctrl+C stops early. The CSV is appended after every sample.' -ForegroundColor DarkGray
Write-Host ''

$mb          = 1048576.0
$start       = Get-Date
$prevWs      = $null
$prevPrivate = $null
$prevTime    = $null
$samples     = 0

while ($true) {
    $now     = Get-Date
    $elapsed = ($now - $start).TotalSeconds
    if ($elapsed -ge ($DurationMinutes * 60)) {
        Write-Host "Reached $DurationMinutes min - stopping." -ForegroundColor Cyan
        break
    }

    $proc = $null
    try {
        $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $proc) {
            Write-Host "Process '$ProcessName' not found - stopping." -ForegroundColor Yellow
            break
        }

        $proc.Refresh()
        $ws      = [double]$proc.WorkingSet64 / $mb
        $private = [double]$proc.PrivateMemorySize64 / $mb
        $peakWs  = [double]$proc.PeakWorkingSet64 / $mb
        $handles = $proc.HandleCount
        $threads = $proc.Threads.Count

        # Handle counts are best-effort: access denied if SharpCap runs elevated
        # and this script does not. Run elevated to match.
        $gdi  = ''
        $user = ''
        try {
            $h    = $proc.Handle
            $gdi  = [SspMemTest.GuiResources]::GetGuiResources($h, 0)
            $user = [SspMemTest.GuiResources]::GetGuiResources($h, 1)
        } catch {
            $gdi  = ''
            $user = ''
        }

        $wsRate      = ''
        $privateRate = ''
        if ($null -ne $prevWs) {
            $dt = ($now - $prevTime).TotalSeconds
            if ($dt -gt 0.001) {
                $wsRate      = [math]::Round((($ws - $prevWs) / $dt), 3)
                $privateRate = [math]::Round((($private - $prevPrivate) / $dt), 3)
            }
        }

        $row = @(
            $now.ToString('HH:mm:ss.fff'),
            [math]::Round($elapsed, 1),
            [math]::Round($ws, 2),
            [math]::Round($private, 2),
            [math]::Round($peakWs, 2),
            $handles,
            $threads,
            $gdi,
            $user,
            $wsRate,
            $privateRate
        ) -join ','
        $row | Out-File -LiteralPath $csvPath -Encoding UTF8 -Append

        $samples++
        Write-Host ("[{0}] {1,6:N0}s  WS {2,9:N2} MB  Priv {3,9:N2} MB  " +
                    "PrivRate {4,7} MB/s  H {5,6}  GDI {6,5}  USER {7,5}" -f `
            $now.ToString('HH:mm:ss'), $elapsed, $ws, $private,
            $privateRate, $handles, $gdi, $user)

        $prevWs      = $ws
        $prevPrivate = $private
        $prevTime    = $now
    }
    finally {
        if ($proc) { $proc.Dispose() }
    }

    Start-Sleep -Seconds $IntervalSeconds
}

Write-Host ''
Write-Host "Done. $samples sample(s) written to:" -ForegroundColor Cyan
Write-Host "  $csvPath"
Write-Host ''
Write-Host 'Send this CSV back with the run label, camera resolution, exposure,' -ForegroundColor DarkGray
Write-Host 'and whether the preview stayed live throughout.' -ForegroundColor DarkGray
