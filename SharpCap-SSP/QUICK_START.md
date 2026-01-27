# SharpCap-SSP Quick Start Guide

## Overview
SharpCap-SSP provides SSP photometer control for use with SharpCap or standalone. This guide will get you collecting photometry data in 5 minutes.

---

## Installation

### Option 1: SharpCap (Zero Setup - Recommended for SharpCap users)

**Prerequisites:**
- ✅ SharpCap Pro installed
- ✅ SSP-3a or SSP-5a photometer
- ✅ Serial cable connected to PC

**One-Time Setup:**
1. Copy `SharpCap-SSP\Python` folder to:
   ```
   C:\Users\YourName\Documents\SharpCap\Scripts\SharpCap-SSP\Python
   ```

2. In SharpCap, go to **Tools → Settings → Scripting**

3. Set **Startup Script** to:
   ```
   C:\Users\YourName\Documents\SharpCap\Scripts\SharpCap-SSP\Python\main.py
   ```

4. Restart SharpCap - **"PEP"** button appears in toolbar
   - Button displays the SSP photometer icon
   - Located in the main SharpCap toolbar

5. Click **PEP** to launch the SSP control window

**Alternative - Manual Launch:**
- Go to **Tools → Scripting Console**
- Run:
  ```python
  exec(open(r'C:\path\to\SharpCap-SSP\Python\main.py').read())
  ```

Done! All dependencies are included.

---

### Option 2: Standalone IronPython (Recommended for non-SharpCap users)

**Prerequisites:**
- ✅ SSP-3a or SSP-5a photometer
- ✅ Serial cable connected to PC
- ✅ Know your COM port number (check Windows Device Manager)

**One-Time Setup:**
1. Download and install IronPython 3.4: https://github.com/IronLanguages/ironpython3/releases
2. Navigate to the Python folder in File Explorer
3. Right-click `install.ps1` and select **"Run with PowerShell"**
4. Double-click `Create_Desktop_Shortcut.bat` to create a desktop icon

**Daily Use:**
- Double-click the **"SSP Photometer"** desktop icon
- Application launches with SSP icon
- Or double-click `Launch_SSP.bat` in the Python folder

**For detailed setup instructions, see [Python/SETUP.md](Python/SETUP.md)**

---

## Prerequisites (Check Device Manager)
- ✅ SSP photometer connected
- ✅ COM port visible in Windows Device Manager
- ✅ Note your COM port number (e.g., COM3)

---

## First Time Setup

### 1. Test Your Connection (Recommended)
Before using the main application, verify your SSP photometer connection:

```python
# In SharpCap IronPython console:
exec(open('ssp_quick_test.py').read())
```

This opens a test window where you can:
- Select your COM port
- Click "Connect" to verify communication
- Test gain settings
- Get trial counts

**If the test succeeds, your setup is correct!**

---

### 2. Configure COM Port
1. Run `main.py`
2. Click "Launch SSPDataq3"
3. Go to **Setup → Select SSP COM Port**
4. Choose your COM port (1-19)
5. Click OK

Your COM port selection is saved in: `Documents\SharpCap\SSP\ssp_config.json`

### 3. Configure Filter Mode (IMPORTANT)

**Before collecting data, you MUST configure the correct filter mode:**

1. Go to **Setup → Auto/Manual Filters**
2. Choose based on your hardware:

   **Select AUTO if:**
   - ✅ You have an SSP with a 6-position automated filter slider
   - ✅ The filter wheel moves automatically when you send commands
   - Example: SSP-3a with optional motorized filter upgrade

   **Select MANUAL if:**
   - ✅ You have a standard 2-position manual slider
   - ✅ You manually slide filters in and out
   - This is the default for most SSP units

**⚠️ WARNING:** The SSP firmware will acknowledge filter commands even if you don't have automated filter hardware. If you select Auto mode without the hardware, the software will report "filter moved" but no physical movement occurs. Always verify your hardware configuration.

---

## Basic Operation

### Connect to Photometer
1. Go to **Setup → Connect to SSP**
2. Wait for "Connected to COMX" message
3. Green status message appears

**Troubleshooting:**
- "Not connected - no response": Check power, cable, COM port
- "Port in use": Close other programs using the port
- "Access denied": Run SharpCap as administrator

---

### Collect Data

#### Trial Mode (Quick Test)
1. Select settings:
   - **Filter**: V (or desired filter)
     - **Auto mode**: Filter moves automatically
     - **Manual mode**: Change filter manually on photometer when prompted
   - **Gain**: 10 (typical starting point)
   - **Integ(sec)**: 1.00 (options: 0.02, 0.05, 0.10, 0.50, 1.00, 5.00, 10.00)
   - **Count**: trial
2. Click **START**
3. Results appear in a popup dialog
4. No data is saved (test only)

#### Slow Mode (Scientific Data)
1. Select settings:
   - **Filter**: V, B, R, I, etc.
     - **Auto mode**: Filter moves automatically when you select it
     - **Manual mode**: Change filter manually when prompted
   - **Gain**: 10 (adjust based on count rates)
   - **Integ(sec)**: 5.00 (typical for stars)
   - **Interval**: 3 (options: 1-4 for slow, 100-5000 for fast mode)
   - **Count**: slow
2. Select **Object**: 
   - "New Object" for manual entry
   - "SKY" for sky background
   - Use **Catalog → Select Target Star** to choose from PEP star catalog
3. Select **Catalog**: Astar, Foe, Soe, Var, etc.
4. Click **START**
5. Watch status messages update as each count completes
6. Data appears in the display grid when all counts complete
7. **Optional:** Double-click the data line to add notes/comments

**Using the Star Catalog:**
1. Go to **Catalog → Select Target Star**
2. Search for your target by name (e.g., "OMI CET", "ALF CAS")
3. View target details: RA/Dec, magnitudes, comparison and check stars
4. Click **Select** to load the target
5. The target name and comp/check stars appear in the Object combobox

The catalog includes 300+ PEP targets with:
- Variable star coordinates and magnitudes
- Comparison star data
- Check star data
- AAVSO identifiers
- Spectral types

**Data Format:**
```
DATE       TIME     C    OBJECT          F  COUNT  COUNT  COUNT  COUNT  IT GN NOTES
12-10-2025 03:45:23 A    HD 12345        V  12543  12587  12521  12498   5 10
```

---

### Save Your Data

#### First Time (New File)
1. Go to **File → Save Data**
2. Choose filename (e.g., `HD12345.raw`)
3. **Header Information Dialog appears:**
   - **Telescope**: Enter telescope name (saved to config)
   - **Observer**: Enter observer name (saved to config)
   - **Conditions**: Enter observing conditions (e.g., "CLEAR", "HAZY")
   - Click **Accept**
4. File saved with complete header

#### Subsequent Saves (Append Mode)
1. Go to **File → Save Data**
2. Select existing .raw file
3. New data appended (no header dialog)
4. Only new data since last save is added

**File Location:**
- Remembered for next save (last directory used)
- Typical: `Documents\Photometry\YourObservation.raw`

**File Format:**
```
 FILENAME=HD12345.RAW       RAW OUTPUT DATA FROM SSP DATA ACQUISITION PROGRAM
 UT DATE= 12/10/2025   TELESCOPE= MY TELESCOPE      OBSERVER= YOUR NAME
 CONDITIONS= CLEAR
 MO-DY-YEAR    UT    CAT  OBJECT         F  ----------COUNTS---------- INT SCLE COMMENTS
 12-10-2025 03:45:23 A    HD 12345       V  12543  12587  12521         5 10 good seeing
```

**Notes:**
- All text automatically uppercased to match original format
- Telescope and observer names persist in config
- Conditions remembered for next session
- Comments field populated from notes (double-click feature)

This file can be:
- Opened in SSPDataq Reduction module
- Processed with external photometry tools
- Edited in text editor if needed

---

## Typical Observation Workflow

### Variable Star Photometry

**1. Setup (once per session)**
```
Connect to SSP
Set gain = 10
Integration = 5 seconds
Interval = 3
```

**2. Comparison Star**
```
Object = CATALOG (select comp star)
Filter = V
Click START
Wait for 3 readings
```

**3. Variable Star**
```
Object = CATALOG (select variable)
Filter = V  
Click START
Wait for 3 readings
```

**4. Sky Background**
```
Object = SKY
Filter = V
Click START
Wait for 3 readings
```

**5. Repeat for Each Filter**
```
Change filter manually on photometer
Set Filter dropdown = B
Repeat steps 2-4
```

**6. Save Data**
```
File → Save Data
Filename: V1234_20250110.raw
```

---

### Extinction Calibration

**1. Select Multiple Airmasses**
```
Object = CATALOG (FOE or SOE star)
Filter = V
Integration = 5 seconds
Interval = 3
```

**2. Observe at Different Times**
```
Early evening (high airmass)
Mid-evening (medium airmass)
Late evening (low airmass)
```

**3. Record Sky Between Stars**
```
Object = SKY
Same integration and interval
```

**4. Save Data**
```
File → Save Data  
Filename: Extinction_20250110.raw
```

---

## Tips & Best Practices

### Integration Time Selection
| Count Rate | Integration | Notes |
|------------|-------------|-------|
| > 50,000 | 1.00 sec | Reduce gain or use filter |
| 10,000 - 50,000 | 1.00 - 5.00 sec | Optimal range |
| 1,000 - 10,000 | 5.00 - 10.00 sec | Good SNR |
| < 1,000 | 10.00 sec | Increase gain or longer integration |

### Gain Selection
- **Gain = 1**: Very bright objects (planets, bright stars)
- **Gain = 10**: Normal stars (magnitude 4-10)
- **Gain = 100**: Faint stars (magnitude > 10)

### Sky Background
- Take sky reading before and after each star
- Use "SKY" object type
- Same integration and filter as star
- Sky should be < 5% of star counts

### Data Quality
- **Interval = 3 or 4**: Better statistics
- **Interval = 1**: Rapid monitoring (eclipses, transits)
- Monitor status messages for communication errors
- Retry if communication error reported

---

## Advanced Features

### Night Mode
- **Setup → Night/Day Screen**
- Switches to red display
- Preserves dark adaptation
- Toggles between red (night) and normal (day)

### Observer/Telescope Info
- Edit: `Documents\SharpCap\SSP\ssp_config.json`
- Fields: `observer_name`, `telescope_name`
- Appears in saved .raw file headers

### Clear Data
- **File → Clear Data**
- Removes all data from display
- Does NOT delete saved files
- Use before new observation session

---

## Troubleshooting

### "Not connected" Error
**Problem:** START button shows error dialog
**Solution:**
1. Setup → Connect to SSP
2. Verify green "Connected" message
3. Check status messages for connection confirmation

### Communication Errors During Collection
**Problem:** Status shows "Communication error - count restarted"
**Solution:**
1. Normal - automatic retry implemented
2. If frequent: Check serial cable
3. If persistent: Reduce integration time
4. Try reconnecting (Disconnect → Connect)

### Counts Not Changing
**Problem:** All readings show same count value
**Solution:**
1. Check photometer is receiving light
2. Remove lens cap if present
3. Verify photometer is pointed at source
4. Check gain setting (may be too low)

### Very High Counts (> 60000)
**Problem:** Saturation indicated
**Solution:**
1. Reduce gain (100 → 10 → 1)
2. Use neutral density filter
3. Reduce integration time
4. Photometer may be saturated

### File Won't Save
**Problem:** "Permission denied" or "Access denied"
**Solution:**
1. Config files now in Documents folder
2. Should not occur with current version
3. Check disk space
4. Verify Documents folder is writable

---

## Data Format Reference

### Display Format
```
MM-DD-YYYY HH:MM:SS C OBJECTNAME F XXXXX XXXXX XXXXX XXXXX II GG
└─ Date    └─Time   │ └─Object  │ └─────Counts─────┘ │  │
                    │           └─Filter             │  └─Gain
                    └─Catalog                        └─Integration
```

### Catalog Codes
- **A** = Astar (general objects)
- **F** = Foe (first order extinction)
- **S** = Soe (second order extinction)
- **C** = Comp (comparison stars)
- **V** = Var (variable stars)
- **M** = Moving (asteroids, comets)
- **T** = Trans (transformation)
- **Q** = Q'check (quality check)

---

## Getting Help

### Check Status Messages
- Bottom of window shows real-time messages
- Scrollable text area
- Timestamps on all messages
- Review for error details

### Run Test Scripts
```python
# Quick GUI test
exec(open('ssp_quick_test.py').read())

# Command-line test
exec(open('ssp_test_serial.py').read())
```

### Verify COM Port
- Windows Device Manager → Ports (COM & LPT)
- SSP shows as USB Serial Port or similar
- Note the COM number
- Update in Setup menu if changed

---

## Keyboard Shortcuts
- **None currently implemented**
- Use mouse for all operations
- Consider implementing Ctrl+S for save in future

---

## All Sky Calibration (Extinction Coefficients)

### Overview
Calculate first-order extinction coefficients (K'v and K'bv) from All Sky observations of standard stars at different airmasses.

### Prerequisites
- Observer location must be configured (File → Set Location)
- .raw data file with All Sky observations
- Data format: Star line followed by sky line (paired observations)
- Stars marked as 'F' (All-sky calibration) or 'C' (Check stars)
- PPparms3.txt file with transformation coefficients (epsilon, mu)

### Launching All Sky Calibration
From the main launcher:
1. Click **"All Sky Calibration"** button
2. Dialog opens with empty data grid and graph area

### Loading Data
1. Go to **File → Open Data File...**
2. Select your .raw file with All Sky observations
3. Data is automatically processed:
   - Star-sky pairs are read and averaged
   - Airmass calculated for each observation time
   - Instrumental magnitudes computed
   - Transformation columns calculated
   - Results displayed in data grid

### Understanding the Display

**Data Grid Columns:**
- **Star**: Star name from catalog
- **X**: Airmass at observation time
- **V**: Standard V magnitude (from catalog)
- **B-V**: Standard B-V color (from catalog)
- **v**: Instrumental V magnitude
- **(V-v)-ε(B-V)**: Transformation column for K'v (Y-axis for V plot)
- **(B-V)-μ(b-v)**: Transformation column for K'bv (Y-axis for B-V plot)

### Calculating Extinction Coefficients

**For V magnitude extinction (K'v):**
1. Click **"extinction plot for v"**
2. Graph displays:
   - X-axis: Airmass
   - Y-axis: (V-v) - ε(B-V)
   - Data points as circles
   - Red best-fit regression line
3. Results display shows:
   - **K'v**: Extinction coefficient (slope)
   - **ZPv**: Zero point (intercept)
   - **Ev**: Standard error
4. Analysis box shows slope, intercept, standard error

**For B-V color extinction (K'bv):**
1. Click **"extinction plot for b-v"**
2. Similar display with (B-V)-μ(b-v) vs airmass
3. Results show K'bv, ZPbv, Ebv

### Data File Format
Your .raw file should contain star and sky observations:
```
Line format: MM-DD-YYYY HH:MM:SS C OBJECTNAME F CNT1 CNT2 CNT3 CNT4 IT GN
```
- C = 'F' for All-sky calibration stars, 'C' for Check stars
- OBJECTNAME = Star name matching catalog, or SKY/SKYNEXT/SKYLAST for sky readings
- F = Filter (V, B, U, R)
- CNT1-CNT3 = Count values (3 readings averaged)

**Sky Reading Labels:**
- `SKY` - Regular sky reading
- `SKYNEXT` - Sky reading to be used for following stars
- `SKYLAST` - Sky reading to be used as the last one

**Sky Association Method:**
The program follows the original SSPDataq AllSky2,57.bas logic:
1. For each star, searches backward for the most recent sky reading (matching filter)
2. Searches forward for the next sky reading (matching filter)
3. If both found: Interpolates sky value based on observation time (Julian Date)
4. If only one found: Uses that sky value
5. If none found: Warning issued and star skipped

This allows flexible sky placement - stars can share sky readings, and the program automatically interpolates between them based on observation time.

### Transformation Coefficients
- Epsilon (ε): Loaded from PPparms3.txt line 8
- Mu (μ): Loaded from PPparms3.txt line 10
- These are used in transformation equations
- If PPparms3.txt not found, defaults to ε=-0.030, μ=1.047

### Saving Results
1. Go to **File → Save Plot...**
2. Choose location and filename
3. Graph saved as PNG image

### Tips
- Observe at least 5-10 standard stars across different airmasses (1.0-2.5)
- Ensure stars are well-distributed in airmass range
- Good seeing conditions minimize scatter
- Check that all stars are found in catalog (warnings printed if not)
- Sky readings should be taken close in time to star readings

### Troubleshooting
**"Star not found in catalog"**
- Ensure star name matches first_order_extinction_stars.csv
- Check spelling and formatting

**"No calibration stars found"**
- Verify catalog code is 'F' or 'C' in .raw file
- Check file format (needs 4-line header)

**Buttons disabled after loading data**
- Data may be invalid or all stars below horizon
- Check console output for errors

**Results differ from spreadsheet**
- Verify transformation coefficients (epsilon, mu)
- Check airmass calculation (observer location must be set)
- Ensure count averaging is correct (3 counts per observation)

### Closing All Sky Calibration
- **File → Exit** or click X button
- Returns to main launcher
- Data is not automatically saved

---

## What's Not Implemented (Yet)
- ⏸️ Fast mode (coming soon)
- ⏸️ Very fast mode (SSP-5 only)
- ⏸️ Automatic filter bar control
- ⏸️ Catalog loading from files
- ⏸️ Script automation (.ssp files)
- ⏸️ Telescope control/slewing
- ⏸️ Built-in data reduction
- ⏸️ Plotting/visualization

**Current Version: Fully functional for slow mode manual photometry**

---

## Version History
- **0.1.4** (2026-01-27)
  - All Sky Calibration tool for extinction coefficient calculation
  - K'v and K'bv determination with linear regression
  - Scatter plots with best-fit lines
  - Transformation coefficient loading from PPparms3.txt
  - Modal dialog behavior (returns to launcher)
- **0.1.3** (2026-01-15)
  - First Order Extinction star selection
  - Real-time Alt/Az coordinate display
  - Airmass filtering with preset buttons
  - Location configuration dialog
- **0.1.0** (2026-01-10)
  - Initial release
  - Slow mode and trial mode
  - Manual filter changes
  - .raw file export
  - SSPDataq format compatible
  - Test scripts included

---

## Contact & Support
- **Repository:** github.com/labstercam/pep-ssp-tools
- **Issues:** Use GitHub issue tracker
- **Documentation:** See IMPLEMENTATION_SUMMARY.md for technical details

---

## Quick Reference Card

```
┌─────────────────────────────────────────┐
│  SharpCap-SSP Quick Reference           │
├─────────────────────────────────────────┤
│ CONNECT: Setup → Connect to SSP         │
│ GAIN:    1 (bright) / 10 (normal) /     │
│          100 (faint)                     │
│ INTEG:   1/5/10 seconds                 │
│ MODE:    trial (test) / slow (science)  │
│ START:   Click when ready               │
│ SAVE:    File → Save Data               │
│ CLEAR:   File → Clear Data              │
│ EXIT:    File → Quit                    │
└─────────────────────────────────────────┘
```

**Remember:** Change filters manually on the photometer, then update the Filter dropdown to match!
