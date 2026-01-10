# SharpCap-SSP

SharpCap-SSP is a Python-based tool for integrating Optec SSP photometers with SharpCap astronomical imaging software.

## Overview

This tool replicates the core data collection functionality of the original SSPDataq software, enabling serial communication and photometer control directly within the SharpCap environment.

## Status: Version 0.1.0 - Fully Functional

✅ **Serial communication implemented and tested**
✅ **Data collection working (slow mode + trial mode)**
✅ **File export in SSPDataq .raw format**
✅ **Test scripts included for verification**

See [QUICK_START.md](QUICK_START.md) for usage instructions.
See [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) for technical details.

## Features

### Implemented ✅
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
- ✅ Night mode (red screen for dark adaptation)
- ✅ Interactive test script (ssp_quick_test.py)
- ✅ Automated test suite (ssp_test_serial.py)

### Not Yet Implemented ⏸️
- ⏸️ **Fast Mode**: 100-5000 rapid readings
- ⏸️ **Very Fast Mode**: Ultra-rapid 20ms integrations (SSP-5 only)
- ⏸️ Automatic filter bar control
- ⏸️ Catalog loading from files
- ⏸️ Script automation (.ssp files)
- ⏸️ Telescope integration
- ⏸️ Data reduction/magnitude calculation

## Requirements

- SharpCap Pro (for IronPython scripting support)
- Optec SSP-3a or SSP-5a photometer
- Windows operating system
- Serial (COM) port connection to photometer

## Installation

1. Copy the SharpCap-SSP folder to your SharpCap scripts directory
2. Launch SharpCap
3. Open the Python Scripts panel
4. Run `main.py` from the SharpCap-SSP/Python folder

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
