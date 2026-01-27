# SharpCap-SSP

SharpCap-SSP is a Python-based tool for integrating Optec SSP photometers with SharpCap astronomical imaging software.

---

## 📥 Quick Download

**Latest Release: v0.1.4**

https://github.com/labstercam/pep-ssp-tools/releases/tag/v0.1.4 

### [**Download SharpCap-SSP (ZIP)**](https://github.com/labstercam/pep-ssp-tools/releases/latest/download/SharpCap-SSP-v0.1.4.zip)

*Non-experts: Just download the ZIP, extract it, and follow the `QUICK_INSTALL.txt` file inside.*

---

## Overview

This tool replicates the core data collection functionality of the original SSPDataq software, enabling serial communication and photometer control directly within the SharpCap environment or standalone.

## Status: Version 0.1.4 - Fully Functional

✅ **Serial communication implemented and tested**
✅ **Data collection working (slow mode + trial mode)**
✅ **File export in SSPDataq .raw format**
✅ **First order extinction star selection with airmass filtering**
✅ **Real-time Alt/Az coordinate display**
✅ **All Sky Calibration tool for extinction coefficient calculation**
✅ **Test scripts included for verification**

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
  - Compatible with AllSky2,57.bas format
- ✅ Serial COM port connection and management (19200,N,8,1)
- ✅ Automatic COM port disconnect on program close
- ✅ SSP photometer command protocol (SSSSSS, SEEEEE, SCnnnn, SGNNN)
- ✅ **Slow Mode**: 1-4 readings with 0.02-10 second integrations
- ✅ **Trial Mode**: Single test reading with instant results
- ✅ Real-time data display with column headers
- ✅ Resizable window with fixed controls and dynamic data display
- ✅ Notes field - double-click data lines to add comments
- ✅ Status message logging with timestamps and immediate updates
- ✅ Data export to .raw files (SSPDataq compatible)
- ✅ Header information dialog (telescope, observer, conditions)
- ✅ Append mode for existing data files
- ✅ Gain control (1, 10, 100) with proper acknowledgment
- ✅ UTC time recording with mid-point correction
- ✅ Configuration management (Documents\SharpCap\SSP\)
- ✅ Night mode (red screen for dark adaptation) with button highlighting
- ✅ Interactive test script (ssp_quick_test.py)
- ✅ Automated test suite (ssp_test_serial.py)

### Not Yet Implemented ⏸️
- ⏸️ **Fast Mode**: 100-5000 rapid readings
- ⏸️ **Very Fast Mode**: Ultra-rapid 20ms integrations (SSP-5 only)
- ⏸️ Catalog loading from additional catalog files
- ⏸️ Script automation (.ssp files)
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
2. Launch SharpCap and load SharpCap-SSP script
3. Select COM port in configuration panel
4. Click "Connect" to establish communication with photometer
5. Configure observation parameters (filter, gain, integration time)
6. Click "Acquire" to collect photometric data
7. Data is saved in .raw format compatible with SSPDataq reduction tools

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
├── README.md          - This file
└── Python/
    ├── main.py        - Main entry point and UI
    ├── ssp_comm.py    - Serial communication module (planned)
    ├── ssp_control.py - Photometer control module (planned)
    └── data_logger.py - Data collection and storage (planned)
```

## Development Status

**Current Version**: 0.1.0 (Alpha)

- [x] Project structure created
- [x] Basic UI framework
- [ ] Serial communication implementation
- [ ] Slow mode data collection
- [ ] Fast mode data collection
- [ ] Configuration management
- [ ] File output system
- [ ] SharpCap integration

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
