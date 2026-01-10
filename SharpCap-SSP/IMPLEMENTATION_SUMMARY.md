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
├── night_mode.py           # Night mode theme
├── ssp_quick_test.py       # Interactive test tool (NEW)
├── ssp_test_serial.py      # Automated test suite (NEW)
└── TEST_README.md          # Test documentation (NEW)
```

---

## Next Steps

### Immediate Use
The software is now **fully functional** for basic photometry:
1. Connect to SSP photometer
2. Set gain
3. Select filter (manual filter changes)
4. Collect slow mode data (1-4 intervals)
5. Display data in real-time
6. Save to .raw files compatible with SSPDataq reduction tools

### Future Enhancements
Priority order for additional features:
1. **Catalog loading** - Load star databases (Foe, Soe, Astar, etc.)
2. **Fast mode** - High-speed photometry (0.05-10 sec)
3. **Filter bar control** - Automatic filter changes with SSP-5
4. **Script automation** - .ssp script file support
5. **Data reduction** - Built-in magnitude calculations
6. **Telescope integration** - LX200/Celestron control

---

## Known Limitations

### Current Version (0.1.0)
- Slow mode only (fast/vfast not implemented)
- Manual filter changes only (automatic filter bar not implemented)
- No catalog loading (object names entered manually)
- No script automation
- No telescope control
- No data reduction/magnitude calculation
- No flip mirror control
- Trial and slow modes only

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

The software is **ready for astronomical observations** with SSP photometers in slow mode. Test scripts verify all critical functions. File output is compatible with existing SSPDataq reduction tools.
