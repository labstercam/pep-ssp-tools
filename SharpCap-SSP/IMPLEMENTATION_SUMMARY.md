# SharpCap-SSP Implementation Summary

## Overview
Complete implementation of SSP photometer data acquisition functionality for SharpCap IronPython, following the original SSPDataq3 software architecture and processing exactly.

**Note:** See [BUG_FIXES.md](BUG_FIXES.md) for details on bugs discovered during verification and their fixes (timing overhead, timestamp mid-point correction, file format).

---

## Implemented Features

### 1. Serial Communication (ssp_comm.py)
**Full SSP-3a/SSP-5a protocol implementation**

#### Connection Management
- `connect(com_port)` - Establishes connection with "SSSSSS" handshake
- `disconnect()` - Closes connection with "SEEEEE" command
- Automatic acknowledgment detection (CR or ! character)
- 5-second connection timeout with retry logic
- Proper buffer management and clearing

#### Data Acquisition
- `get_slow_count(integration_ms)` - Slow mode count acquisition
  - Sends "SCnnnn" command
  - Waits with proper overhead (1s: 15%, 5s: 3%, 10s: 1.5%)
  - Parses "C=XXXXX" response format
  - Returns 5-digit count value
  - Error detection (null character check)
  - Communication retry on failure

#### Hardware Control
- `set_gain(value)` - Sets photometer gain (1, 10, or 100)
- `home_filter()` - Homes filter bar with acknowledgment wait

#### Serial Parameters
- Baud rate: 19200
- Data bits: 8
- Parity: None
- Stop bits: 1
- Buffer size: 32768 bytes

---

### 2. Data Collection (ssp_dataaq.py)
**Complete data acquisition window with SSPDataq3-compliant processing**

#### User Interface
- 1100×345 pixel window (resizable, minimum size enforced)
- File menu: Save Data, Clear Data, Open Script, Quit
- Setup menu: Connect/Disconnect, COM Port, Night Mode, Show Setup
- Control panel: Filter, Gain, Integration, Interval, Mode selectors
- Time display: PC local time and UTC time (updated every second)
- Object/Catalog selection with dropdown menus
- START button for data collection
- Status message area (single-line with overwrite, immediate updates)
- Data display grid with fixed column headers:
  - DATE, TIME, C, OBJECT, F, COUNT (×4), IT, GN, NOTES
  - Courier New 8pt font for proper alignment
  - Resizable - expands/contracts with window
  - Double-click any line to add/edit notes
- Column headers remain visible (non-scrolling)
- COM port automatically disconnects on program close

#### Data Collection Modes
**Trial Mode:**
- Single test reading
- Results displayed in message box
- No data storage
- Quick verification of settings

**Slow Mode:**
- Integration times: 0.02, 0.05, 0.10, 0.50, 1.00, 5.00, 10.00 seconds
  - 0.02s: SSP-5 only, very fast mode
  - 0.05-0.50s: Fast mode
  - 1.00-10.00s: Fast or slow mode
- Intervals: 1-4 readings (slow mode), 100-5000 (fast mode - not yet implemented)
- UT timestamp recorded at start
- Mid-point correction applied (half of total integration time)
- Gain set on photometer before collection (SGNNN3/2/1 format)
- Individual count display during acquisition
- Status updates show each count as collected (immediate UI refresh)
- Data grid displays one line after all counts complete
- Automatic retry on communication errors
- Button disabled during collection ("WAIT" state)

#### Data Processing
**Following SSPDataq [DisplayData] subroutine exactly:**
- Records UT date/time at acquisition start
- Applies mid-point correction to timestamp (half of total integration time)
- Formats data as: `MM-DD-YYYY HH:MM:SS C OBJECTNAME F XXXXX XXXXX XXXXX XXXXX II GG`
- Catalog code: First letter of catalog name
- Object name: Padded/truncated to 12 characters
- Filter: Single character
- Counts: 5-digit values, right-justified, up to 4 readings
- Integration: 2-character field
- Gain: 2-character field
- Stores in `saved_data[]` array (chronological order)
- Displays in `data_array[]` (reverse chronological)
- Updates listbox with latest data at top

---

### 3. File Export (ssp_dataaq.py)
**SSPDataq .raw file format - exact match**

#### File Structure
```
FILENAME=FILENAME.RAW       RAW OUTPUT DATA FROM SSP DATA ACQUISITION PROGRAM
UT DATE= MM/DD/YYYY   TELESCOPE= [name]      OBSERVER= [name]
CONDITIONS= [description]
MO-DY-YEAR    UT    CAT  OBJECT         F  ----------COUNTS---------- INT SCLE COMMENTS
[data lines with leading space]
```

#### Features
- SaveFileDialog with .raw filter
- New file mode:
  - Prompts for telescope name (saved to config)
  - Prompts for observer name (saved to config)
  - Prompts for observing conditions
  - Creates 4-line header with current UT date
  - Saves all data with header
- Append mode:
  - Detects existing file
  - Appends only new data since last save
  - No header prompts
  - Tracks saved data count (data_saved_count)
- Remembers last save directory
- Data lines in chronological order (not display order)
- All text uppercased to match original format
- Success confirmation dialog
- Notes included in COMMENTS field when present

---

### 4. Configuration Management (ssp_config.py)
**Updated for SharpCap environment**

#### Location
- Configuration files stored in: `Documents\SharpCap\SSP\`
- Auto-creates directory if doesn't exist
- Avoids permission denied errors in Program Files

#### Dual Format Support
- **ssp_config.json** - Master configuration (JSON format)
- **dparms.txt** - Backward compatibility with SSPDataq

#### Settings Stored
- COM port selection (0-19)
- Filter names (6 filters: U, B, V, R, I, Dark)
- Night mode flag (0=day, 1=night)
- Telescope name (prompted when saving new files)
- Observer name (prompted when saving new files)
- Last conditions (remembered from previous save)
- Last selected indices (filter, gain, integration, interval, mode)
- Last data directory

---

### 5. Test Scripts
**Two comprehensive test tools**

#### ssp_quick_test.py - Interactive GUI Test
- Visual interface with buttons and dropdowns
- COM port selection (1-19)
- Connect/disconnect functionality
- Gain control testing
- Count acquisition with real-time logging
- Timestamped output log
- Ideal for quick verification and troubleshooting

#### ssp_test_serial.py - Automated Test Suite
- Command-line operation
- Full connection test sequence
- Gain control verification (1, 10, 100)
- Count acquisition timing tests (1, 5, 10 seconds)
- Elapsed time verification
- Optional 60-second continuous monitoring mode
- Detailed error reporting

---

## Implementation Details

### Data Flow
```
User clicks START
    ↓
Get settings (filter, gain, integration, interval, mode)
    ↓
Check connection status
    ↓
Set gain on photometer (SG command)
    ↓
Record UT date/time
    ↓
Loop for each interval:
    - Clear serial buffer
    - Send "SCnnnn" command
    - Wait with proper overhead
    - Read response
    - Parse "C=XXXXX" format
    - Extract 5-digit count
    - Verify not null
    - Retry once on error
    ↓
Apply mid-point timestamp correction
    ↓
Format data line (SSPDataq format)
    ↓
Add to saved_data[] array
    ↓
Insert at top of data_array and data_listbox
    ↓
Update status message (with immediate Refresh() and DoEvents())
    ↓
Display complete data line in grid
```

### Notes Functionality
**Double-click any data line to add/edit comments:**
- Opens InputBox dialog with current notes
- Updates both data_array[] and saved_data[]
- Appends notes to COMMENTS field
- Notes persist when saving to file
- Empty notes are handled gracefully

### Error Handling
**Connection Errors:**
- No response from SSP: "Not connected - no response from SSP. Is unit on?"
- COM port in use: Exception caught and displayed
- Invalid COM port: "Please select a COM port in Setup menu"

**Data Collection Errors:**
- Communication error (null character): Automatic retry
- Timeout: Caught and reported in status
- Not connected: Warning dialog before START button allows action

**File Errors:**
- Permission denied: Now avoided by using Documents folder
- Disk full: Exception caught and displayed
- Invalid filename: Handled by SaveFileDialog

### Timing Accuracy
**Following SSPDataq exactly:**
- 1 second integration: Wait 1.15 seconds (15% overhead)
- 5 second integration: Wait 5.15 seconds (3% overhead)
- 10 second integration: Wait 10.15 seconds (1.5% overhead)
- Overhead accounts for serial communication and processing delays
- Matches original SSPDataq timing precisely (different overhead per integration time)

---

## Compatibility with Original SSPDataq

### Identical Behavior
✅ Serial protocol (19200,N,8,1, commands, responses)
✅ Data format (MM-DD-YYYY HH:MM:SS C OBJECTNAME F XXXXX...)
✅ .raw file structure (header, column names, data lines)
✅ Slow mode count acquisition logic
✅ Gain control (1, 10, 100)
✅ Integration times (1.00, 5.00, 10.00 seconds)
✅ Integration timing overhead (15%, 3%, 1.5% respectively)
✅ Interval counts (1-4 readings)
✅ Error handling (null check, retry logic)
✅ UT time recording with mid-point correction
✅ Display order (reverse chronological in listbox)
✅ File save order (chronological in .raw file)

### Differences (Improvements)
- Configuration in Documents folder (not Program Files)
- UTC-only time handling (no timezone offset complexity)
- Modern .NET SerialPort class (instead of LibertyBasic COM handling)
- JSON configuration format (more robust than dparms.txt alone)
- Integrated with SharpCap environment

### Not Yet Implemented
⏸️ Fast mode (0.05-10 sec, 100-5000 intervals)
⏸️ Very Fast mode (0.02 sec, 2000-5000 intervals)
⏸️ Script automation (.ssp files)
⏸️ Catalog loading (Astar, Foe, Soe, etc.)
⏸️ Filter bar control (automatic filter changes)
⏸️ Flip mirror control
⏸️ Telescope integration
⏸️ Data reduction module
⏸️ Data visualization/plotting

---

## Testing Verification

### Test Coverage
✅ Connection establishment with SSP photometer
✅ Disconnection with cleanup
✅ Gain control (all three values)
✅ Single count acquisition (trial mode)
✅ Multiple count acquisition (slow mode, intervals 1-4)
✅ Data formatting and display
✅ File export (.raw format)
✅ Configuration save/load
✅ Error handling and retry logic
✅ Timing accuracy verification

### Test Procedure
1. Run **ssp_quick_test.py** for initial verification
2. Connect to SSP photometer
3. Test gain settings
4. Get several counts with different integration times
5. Run **ssp_test_serial.py** for automated validation
6. Launch main application (main.py)
7. Collect data in slow mode
8. Save data to .raw file
9. Verify file format matches SSPDataq output

---

## File Structure
```
SharpCap-SSP/Python/
├── main.py                  # Launcher window
├── ssp_dataaq.py           # Main data acquisition window
├── ssp_comm.py             # Serial communication (COMPLETE)
├── ssp_config.py           # Configuration management
├── ssp_dialogs.py          # Configuration dialogs
├── ssp_catalog.py          # Star catalog with 300+ targets
├── ssp_extinction.py       # Extinction stars & airmass calculations
├── ssp_allsky.py           # All Sky Calibration for extinction coefficients
├── ssp_location_utils.py   # Location utilities and geodesic calculations
├── night_mode.py           # Night mode theme
├── ssp_quick_test.py       # Interactive test tool
├── ssp_test_serial.py      # Automated test suite
└── TEST_README.md          # Test documentation
```

---

## 8. All Sky Calibration (ssp_allsky.py)
**First-order extinction coefficient calculation tool**

### Overview
Complete implementation of AllSky2,57.bas functionality for calculating extinction coefficients (K'v, K'bv) from All Sky photometry observations.

### Features
- Load .raw data files with paired star/sky observations
- Parse fixed-width format matching BASIC mid$() positions
- Star catalog lookup from first_order_extinction_stars.csv (173 stars)
- Airmass calculation using Hardie method
- Sky subtraction: net_count = star_count - sky_count
- Instrumental magnitude: v = -2.5 × log₁₀(net_count)
- Transformation coefficients loaded from PPparms3.txt:
  - Epsilon (ε): Line 8, for V magnitude transformation
  - Mu (μ): Line 10, for B-V color transformation
- Linear regression for extinction determination
- Scatter plot with best-fit line visualization
- Results display with zero points and standard error

### User Interface (1050×730 pixels)
**Components:**
- Menu bar: File (Open/Save/Exit), Coefficients (Load/Save/Use/Clear), Help
- Filename display textbox
- Observer location display and Set Location button
- Data grid (500×265) with columns:
  - Star, X (airmass), V, B-V, v, (V-v)-ε(B-V), (B-V)-μ(b-v)
- Graph area (490×265) with:
  - X-axis: Airmass (1.0-2.5 typical range)
  - Y-axis: Transformation column with auto-scaled tick labels
  - Data points rendered as circles
  - Red best-fit regression line
  - Rotated Y-axis label
- Control buttons:
  - "extinction plot for v" - Show K'v calculation
  - "extinction plot for b-v" - Show K'bv calculation
  - "print" - Save plot image
- Results display (680×85):
  - K'v, ZPv, Ev (V magnitude results)
  - K'bv, ZPbv, Ebv (B-V color results)
  - Right-aligned at 3 decimal places
- Analysis display (305×85):
  - Slope, Intercept, Standard Error
  - Courier New 9pt font for alignment

### Data Processing

**File Format:**
- 4-line header (skipped)
- Paired observations: Star line, Sky line, Star line, Sky line...
- Fixed-width fields (BASIC positions):
  - Date: pos 1-10 (MM-DD-YYYY)
  - Time: pos 12-19 (HH:MM:SS)
  - Catalog: pos 21 (F/C for calibration stars)
  - Object: pos 26-37 (12 chars)
  - Filter: pos 41 (V/B/U/R)
  - Counts: pos 44-48, 51-55, 58-62 (first 3 values only)

**Count Processing:**
- Parse 3 count values per line
- Calculate average: (cnt1 + cnt2 + cnt3) / 3.0
- Star line: observation counts
- Next line (sky): background counts
- Net count = star_avg - sky_avg

**Transformation Equations:**
- For V extinction: Y = (V-v) - ε(B-V) vs X = airmass
  - V: Standard magnitude from catalog
  - v: Instrumental magnitude = -2.5 × log₁₀(net_count)
  - ε: Transformation coefficient from PPparms3.txt
  - B-V: Standard color from catalog
- For B-V color: Y = (B-V) - μ(b-v) vs X = airmass
  - B-V: Standard color from catalog
  - b-v: Instrumental color = b_inst - v_inst
  - μ: Transformation coefficient from PPparms3.txt

**Linear Regression:**
- Least-squares fit: Y = slope × X + intercept
- Slope = extinction coefficient (K'v or K'bv)
- Intercept = zero point (ZPv or ZPbv)
- Standard error calculated from residuals

### Airmass Calculation
Uses AirmassCalculator from ssp_extinction.py:
- Hardie equation: sec(z) - 0.0018167 × (sec(z) - 1) - 0.002875 × (sec(z) - 1)²
- z = zenith distance from Alt/Az calculation
- Requires observer location (latitude/longitude)
- Time handling: UTC timestamps from .raw file
- RA/Dec from star catalog

### Error Handling
- Missing stars: Printed warnings, skipped in calculations
- Below horizon: Airmass returns None, star excluded
- Invalid counts: Zero or negative after sky subtraction rejected
- File format errors: Try/except with error dialogs
- Graph refresh: Disposes old image before creating new one

### Window Behavior
- Modal dialog (ShowDialog) - returns to launcher on close
- File → Exit sets DialogResult.OK
- Clear all results when loading new file:
  - Data grid cleared
  - Result textboxes emptied
  - Graph image disposed
  - Buttons disabled until new calculations performed

### Technical Details
- .NET WinForms (System.Windows.Forms)
- Bitmap graphics with GDI+ drawing
- CSV catalog loading with UTF-8 encoding
- PPparms3.txt: Tab-separated with "Label=Value" format
- Configuration stored in SSPConfig (Documents\SharpCap\SSP\)
- Default transformation coefficients: ε=-0.030, μ=1.047

---

## Next Steps

### Immediate Use
The software is now **fully functional** for photometry and data reduction:
1. Connect to SSP photometer
2. Set gain
3. Select filter (manual filter changes)
4. Collect slow mode data (1-4 intervals)
5. Display data in real-time
6. Save to .raw files compatible with SSPDataq reduction tools
7. Calculate extinction coefficients using All Sky Calibration tool

### Future Enhancements
Priority order for additional features:
1. **Second-order extinction** - More accurate atmospheric corrections
2. **Fast mode** - High-speed photometry (0.05-10 sec)
3. **Filter bar control** - Automatic filter changes with SSP-5
4. **Script automation** - .ssp script file support
5. **Built-in data reduction** - Magnitude calculations in main window
6. **Telescope integration** - Enhanced LX200/Celestron control

---

## Known Limitations

### Current Version (0.1.4)
- Slow mode only (fast/vfast not implemented)
- Manual filter changes only (automatic filter bar not implemented)
- First-order extinction only (second-order requires more complex modeling)
- No script automation
- No flip mirror control
- All Sky Calibration requires manual data file preparation

### Platform
- **IronPython 2.7** required (SharpCap environment)
- **Windows only** (.NET Framework dependency)
- **SSP-3a or SSP-5a photometer** required for actual use
- **COM port** must be available (no USB virtual COM support guaranteed)

---

## Conclusion

The SharpCap-SSP implementation successfully replicates the core SSPDataq3 functionality:
- ✅ Serial communication protocol matches exactly
- ✅ Data processing follows original logic
- ✅ File format is identical and compatible
- ✅ Timing and error handling preserved
- ✅ User interface workflow similar
- ✅ Configuration management improved
- ✅ Star catalog integration with 300+ targets
- ✅ First-order extinction star selection (150+ standards)
- ✅ All Sky Calibration tool for extinction coefficient calculation
- ✅ Real-time coordinate display (Alt/Az/Airmass)

The software is **ready for astronomical observations** with SSP photometers including full extinction analysis. Test scripts verify all critical functions. File output is compatible with existing SSPDataq reduction tools.
