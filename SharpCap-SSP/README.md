# SharpCap-SSP

SharpCap-SSP is a Python-based tool for integrating Optec SSP photometers with SharpCap astronomical imaging software.

---

## 📥 Quick Download

**Latest Release: v0.2.0**

https://github.com/labstercam/pep-ssp-tools/releases/tag/v0.2.0 

### [**Download SharpCap-SSP (ZIP)**](https://github.com/labstercam/pep-ssp-tools/releases/latest/download/SharpCap-SSP-v0.2.0.zip)

*Non-experts: Just download the ZIP, extract it, and follow the `QUICK_INSTALL.txt` file inside.*

---

## Overview

This tool replicates the core data collection functionality of the original SSPDataq software, enabling serial communication and photometer control directly within the SharpCap environment or standalone.

## Status: Version 0.2.0 - Automated Sequence Runs

✅ **Serial communication implemented and tested**
✅ **Data collection working (slow mode + trial mode)**
✅ **File export in SSPDataq .raw format**
✅ **First order extinction star selection with airmass filtering**
✅ **Real-time Alt/Az coordinate display**
✅ **All Sky Calibration tool for extinction coefficient calculation**
✅ **Memory optimizations for extended observation sessions**
✅ **Test scripts and verification tools included**

See [QUICK_START.md](QUICK_START.md) for usage instructions.
See [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) for technical details.

## Features

### Implemented ✅
- ✅ **SharpCap Integration**: Custom "PEP" toolbar button with icon
- ✅ **Star Catalog Integration**: PEP variable star catalog with 300+ targets
  - Load target, comparison, and check stars from starparm_latest.csv
  - Searchable star database with RA/Dec coordinates and magnitudes
  - AAVSO designations and spectral types included
- ✅ **First Order Extinction**: Dedicated extinction standard star selection
  - 150+ extinction standards from Landolt, Cousins, & Graham
  - Airmass-based filtering with 7 preset filters (1.0-2.5 in 0.25 steps)
  - Automatic filter progression for systematic observations
  - Real-time Alt/Az/Airmass calculations
- ✅ **Coordinate Display**: Real-time altitude and azimuth for all targets
  - Alt/Az shown in both target star and extinction star grids
  - Corrected azimuth calculation matching planetarium software
  - Below-horizon stars automatically filtered
- ✅ **All Sky Calibration**: Calculate first-order extinction coefficients
  - Load .raw data files from All Sky observations
  - Calculate K'v (V extinction) and K'bv (B-V color extinction)
  - Linear regression with scatter plot and best-fit line
  - Transformation coefficients (epsilon, mu) loaded from PPparms3.txt
  - Results display with zero points and standard error
  - **Raw Data Viewer**: View complete raw file with processing status
    - Chronologically sorted observations
    - Color-coded: normal text for used data, red strikethrough for excluded
    - Shows calculated X (airmass) and Y values for regression points
    - Individual count values with zero highlighting
    - Removal reasons displayed (not in catalog, below horizon, zero counts)
  - Compatible with AllSky2,57.bas format
  - **VERIFIED**: All 12 processing steps match BASIC implementation exactly
  - Enhanced: Accepts V-only observations for improved flexibility
- ✅ Serial COM port connection and management (19200,N,8,1)
- ✅ Automatic COM port disconnect on program close
- ✅ SSP photometer command protocol (SSSSSS, SEEEEE, SCnnnn, SGNNN)
- ✅ **Slow Mode**: 1-4 readings with 0.02-10 second integrations
- ✅ **Trial Mode**: Single test reading with instant results
- ✅ Automatic binning of 6 or 8 readings to 3 or 4 readings so can use, say, 5s integrations instead of 10s to avoid saturation 
- ✅ Real-time data display with column headers
- ✅ Resizable window with fixed controls and dynamic data display
- ✅ Notes field - double-click data lines to add comments
- ✅ Status message logging with timestamps and immediate updates
- ✅ Data export to .raw files (SSPDataq compatible)
- ✅ Data export to .tab text files which can open directly in Excel or copied easily into PEP processing Excel
- ✅ Header information dialog (telescope, observer, conditions)
- ✅ Append mode for existing data files
- ✅ Gain control (1, 10, 100) with proper acknowledgment
- ✅ UTC time recording with mid-point correction
- ✅ Configuration management (Documents\SharpCap\SSP\)
- ✅ Night mode (red screen for dark adaptation) with button highlighting
- ✅ Interactive test script (ssp_quick_test.py)
- ✅ Automated test suite (ssp_test_serial.py)
- ✅ **Memory leak fix for long sessions with a guide camera** ⭐
  - Fixed `OutOfMemoryException` / crash after ~100 readings when a camera was running
  - SSP waits now **pump the UI message loop** instead of blocking it, so camera frames
    are released rather than queued
  - **Measured** over a 99-minute soak: **+6.6 MB total**, versus ~15.6 GB projected at the
    old rate. SharpCap's own camera frame pool was byte-identical throughout
  - See `BUG_FIXES.md` section 6 and `MEMORY_ANALYSIS.md` for the measurements
- ✅ **Memory optimizations for extended sessions**
  - Optimized string handling reduces temporary allocations by ~80%
  - Timer resource cleanup prevents memory leaks
  - Verified with `verify_optimization.py` test tool
- ✅ **Optimization verification tools**
  - `verify_optimization.py` - Validates memory optimizations
  - `test_memory_optimization.py` - Diagnoses memory issues
- ✅ **Automated Sequence Runs** ⭐
  - Build/run a configurable sequence of steps: GOTO (Var/Comp/Check/coords),
    TARGET (switch catalog object mid-run, by name or AUID), MEASURE,
    SKY (optional RA/Dec offset), FILTER, WAIT, WAIT_UNTIL (absolute UTC),
    ABORT_IF (altitude/airmass), REPEAT
  - One **`offset=dRA,dDec`** syntax for GOTO and SKY, applied **on top of** the
    target star/coords (e.g. `GOTO, V, offset=0,0.05`)
  - Run length by **minutes** or **number of observations**; STOP aborts cleanly
  - **PAUSE / RESUME** the run between steps (the current step completes first);
    while paused the manual SSP controls (GOTO, filter, integration, START, …) are
    unlocked so SharpCap stays usable
  - Editor dialog (`Sequence → Edit Sequence…`): add/reorder steps, a per-command
    syntax/help panel, save/load named sequences (**Save As**), and built-in
    templates (V-C-V-C, C-V-C, V-C-K)
  - **`Sequence → Load Sequence…`** picks a saved sequence (or template) to load
    as the current sequence
  - Unknown `TARGET` objects are warned about when added/edited and on load, and at
    run start (a 10-second countdown you can cancel); at run time they are skipped
    silently
  - `.ssp`-style text and JSON formats; `Sequence → Export Sequence…`
  - Headless GOTO (no modal dialogs mid-run); reuses the existing plate-solve
    and memory-safe pumped waits
  - See [SEQUENCER_DEVELOPMENT.md](SEQUENCER_DEVELOPMENT.md)
- ✅ **Compulsory autosave** — every reading is silently appended (no prompts, never
  blocks the run) to a per-target `.raw` + `.tab` pair named
  `YYMMDD-HHMMSS-<target>.raw/.tab`

### Not Yet Implemented ⏸️
- ⏸️ **Fast Mode**: 100-5000 rapid readings
- ⏸️ **Very Fast Mode**: Ultra-rapid 20ms integrations (SSP-5 only)
- ⏸️ Catalog loading from additional catalog files
- ⏸️ Full multi-target **queue editor** (a single mid-run object switch via `TARGET` *is* supported)
- ⏸️ Advanced telescope integration features
- ⏸️ Data reduction/magnitude calculation

## Requirements

### Core Requirements
- Optec SSP-3a or SSP-5a photometer
- Windows operating system
- Serial (COM) port connection to photometer

### Software Options (Choose One)

**Option 1: SharpCap Pro (Recommended for astronomy workflows)**
- Best for: Users who already use SharpCap for astronomical imaging
- Pros: Zero setup, all dependencies included, integrated with imaging workflow
- Cons: Requires SharpCap Pro license

**Option 2: Standalone IronPython (Recommended for general use)**
- Best for: Standalone photometry without SharpCap
- Pros: Free, lightweight, works independently
- Cons: Requires one-time setup (5 minutes)

---

## Installation

### Option 1: Run in SharpCap

**Prerequisites:** SharpCap Pro installed

**Installation Steps:**

1. **Copy the files:**
   - Copy the `SharpCap-SSP/Python` folder to a location of your choice
   - Recommended: `Documents\SharpCap\Scripts\SharpCap-SSP\Python`

2. **Configure SharpCap startup script:**
   - In SharpCap, go to **Tools → Settings**
   - Navigate to the **Scripting** tab
   - In the **"Startup Script"** field, enter the full path:
     ```
     C:\Users\YourName\Documents\SharpCap\Scripts\SharpCap-SSP\Python\main.py
     ```
   - Replace `YourName` with your actual Windows username
   - Click **OK** to save

3. **Restart SharpCap:**
   - Close and reopen SharpCap
   - A **"PEP"** button with the SSP icon will appear in the SharpCap toolbar
   - The button looks like: ![SSP Icon](Python/SSP.ico)
   - Click the PEP button to launch the SSP control window

**Alternative - Manual Launch (without startup script):**
- Go to **Tools → Scripting Console**
- Run:
  ```python
  exec(open(r'C:\path\to\SharpCap-SSP\Python\main.py').read())
  ```

Done! All dependencies are already included in SharpCap.

---

### Option 2: Standalone IronPython (Detailed Instructions)

**Step 1: Install IronPython 3.4**

1. Download IronPython 3.4 from: https://github.com/IronLanguages/ironpython3/releases
   - Get the `.msi` installer (e.g., `IronPython.3.4.1.msi`)
2. Run the installer
3. Verify installation:
   ```powershell
   ipy --version
   ```
   Should show: `IronPython 3.4.x`

**Step 2: Install System.IO.Ports (Serial Communication)**

**Method A: Automatic Installation (Recommended)**

1. Navigate to the Python folder in File Explorer:
   ```
   C:\Users\YourName\Documents\GitHub\pep-ssp-tools\SharpCap-SSP\Python
   ```
2. **Right-click** `install.ps1` and select **"Run with PowerShell"**
3. Wait for "Installation successful!" message
4. Press any key to close

**Alternative - Command Line:**
```powershell
cd C:\Users\YourName\Documents\GitHub\pep-ssp-tools\SharpCap-SSP\Python
powershell -ExecutionPolicy Bypass -File install.ps1
```

**Method B: Manual Installation (If PowerShell script fails)**

1. Download System.IO.Ports:
   - Go to: https://www.nuget.org/packages/System.IO.Ports/
   - Click **"Download package"** button (right side)
   - Save the `.nupkg` file

2. Extract the DLL:
   ```powershell
   # Rename to .zip
   Rename-Item System.IO.Ports.*.nupkg System.IO.Ports.zip
   
   # Extract
   Expand-Archive System.IO.Ports.zip -DestinationPath extracted
   
   # Copy the DLL
   copy extracted\lib\net6.0\System.IO.Ports.dll C:\path\to\SharpCap-SSP\Python\
   ```

**Step 3: Create Desktop Shortcut (Recommended)**

1. **Double-click** `Create_Desktop_Shortcut.bat` in the Python folder
2. A desktop shortcut **"SSP Photometer"** will be created with the SSP icon
3. Double-click the shortcut to launch SSP anytime

**Alternative Launch Methods:**

**Option A: Use Launch_SSP.bat**
- Double-click `Launch_SSP.bat` directly
- Automatically finds IronPython even if not in PATH
- Shows helpful errors if setup incomplete

**Option B: Command Line**

```powershell
ipy
>>> exec(open('C:\\path\\to\\main.py').read())
```

Or with full path:
```powershell
ipy -c "exec(open('main.py').read())"
```

**Quick Launch (after setup):**
- Double-click the desktop shortcut (easiest)
- Or double-click `Launch_SSP.bat`
- Or run from command line

## Quick Start

### First Time: Test Your Connection
```python
# In SharpCap IronPython console:
exec(open('ssp_quick_test.py').read())
```
This opens a test window to verify your SSP photometer connection.

### Basic Usage
1. Run `main.py` - Opens launcher
2. Click "Launch SSPDataq3" - Opens data acquisition window
3. Setup → Select SSP COM Port (choose your port)
4. Setup → Connect to SSP
5. Select Filter, Gain, Integration, Interval, Mode
6. Click START to collect data
7. File → Save Data to export .raw file

**See [QUICK_START.md](QUICK_START.md) for detailed workflow examples.**

## Supported Hardware

- **SSP-3a**: Single-channel photometer with PMT detector
- **SSP-5a**: Single-channel photometer with enhanced detector options

## Serial Communication

- **Baud Rate**: 19200 bps
- **Data Bits**: 8
- **Parity**: None
- **Stop Bits**: 1
- **Flow Control**: None

## Testing

Two test scripts are provided:

### Interactive GUI Test
```python
python ssp_quick_test.py
```
- Visual interface for connection testing
- Gain control verification
- Count acquisition with real-time logging

### Automated Test Suite
```python
python ssp_test_serial.py [COM_PORT]
```
- Comprehensive connection test
- Timing verification
- Optional 60-second continuous monitoring

**See [Python/TEST_README.md](Python/TEST_README.md) for complete testing documentation.**

## Usage

See **Basic Usage** under Quick Start above for the normal workflow. In brief:

1. Launch SharpCap, or `main.py` standalone
2. Open the SSP Data Acquisition window from the **PEP** button
3. **Setup → Select SSP COM Port**, then **Setup → Connect to SSP**
4. Select filter, gain, integration time, interval and mode
5. Click **START** to collect data
6. **File → Save Data** to export a `.raw` file (and `.tab`)

## Data Format

Output files use the standard SSPDataq .raw format:
```
FILENAME=SAMPLE.RAW       RAW OUTPUT DATA FROM SSP DATA ACQUISITION PROGRAM
UT DATE= MM/DD/YYYY   TELESCOPE= [name]      OBSERVER= [name]
CONDITIONS= [description]
MO-DY-YEAR    UT    CAT  OBJECT         F  ----------COUNTS---------- INT SCLE COMMENTS
```

## Project Structure

```
SharpCap-SSP/
├── README.md              - This file
├── BUG_FIXES.md           - Bug fix and code verification record
├── DEVELOPMENT_NOTES.md   - Developer notes, patterns and threading rules
├── MEMORY_ANALYSIS.md     - Memory / OutOfMemoryException investigation record
├── DOCKING.md             - Docked-window implementation guide
├── SEQUENCER_DEVELOPMENT.md - Automated sequence runs (design + phases)
├── RELEASE_INSTRUCTIONS.md
├── create_release_zip.ps1
├── tools/
│   └── monitor_sharpcap.ps1   - External SharpCap memory sampler (diagnostics)
└── Python/
    ├── main.py               - Entry point, detects SharpCap, creates launcher
    ├── ssp_dataaq.py         - Data acquisition window + star selection dialogs
    ├── ssp_comm.py           - Serial communication + UI message pump
    ├── ssp_config.py         - JSON configuration
    ├── ssp_catalog.py        - Star catalog
    ├── ssp_dialogs.py        - Utility dialogs (incl. SequenceDialog editor)
    ├── ssp_sequence.py       - Sequence model, .ssp/JSON I/O, templates
    ├── ssp_extinction.py     - Extinction calculations
    ├── ssp_allsky.py         - All Sky calibration
    ├── ssp_location_utils.py - Observer location, Alt/Az, airmass
    ├── ssp_docking.py        - Bottom-docking support
    ├── night_mode.py         - Night-mode theme
    └── starparm_latest.csv   - PEP star catalog
```

## Development Status

**Current Version**: 0.2.0

- [x] Project structure and UI framework
- [x] Serial communication (SSP-3a / SSP-5a)
- [x] Slow mode data collection, including 6/8-interval binning
- [x] Trial mode
- [x] Configuration management
- [x] File output (.raw and .tab)
- [x] SharpCap integration (toolbar button, GOTO, docking)
- [x] Star catalog and first-order extinction star selection
- [x] All Sky calibration (extinction coefficients)
- [x] Night mode
- [x] Memory leak fix for long sessions with a guide camera running
- [x] Automated sequence runs (GOTO/measure/sky/target, run-length, editor)
- [ ] Fast mode
- [ ] Very fast mode

## Related Projects

- **SSPDataq**: Original photometry acquisition software (LibertyBasic)
- **pep-ssp-tools**: Analysis and documentation of SSPDataq system

## References

- SSPDataq Software Analysis: `../SSPDataq/Analysis/SSPDataq_Software_Overview.md`
- Optec SSP Photometer Documentation: [Optec Inc.](https://www.optecinc.com/)

## License

Copyright (c) 2026. See repository root for license details.

## Author

Developed as part of the pep-ssp-tools project for astronomical photometry applications.



