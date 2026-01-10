# SharpCap-SSP Quick Start Guide

## Overview
SharpCap-SSP provides SSP photometer control directly within SharpCap. This guide will get you collecting photometry data in 5 minutes.

---

## Prerequisites
- ✅ SharpCap 4.1 (64-bit) or later
- ✅ SSP-3a or SSP-5a photometer
- ✅ Serial cable connected to PC
- ✅ Know your COM port number (check Windows Device Manager)

---

## Installation
1. Copy the `SharpCap-SSP/Python/` folder to your SharpCap scripts directory
2. Launch SharpCap
3. Open the IronPython script console
4. Run `main.py` to launch the control interface

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
   - **Filter**: V (or desired filter - manual change on photometer)
   - **Gain**: 10 (typical starting point)
   - **Integ(sec)**: 1.00 (options: 0.02, 0.05, 0.10, 0.50, 1.00, 5.00, 10.00)
   - **Count**: trial
2. Click **START**
3. Results appear in a popup dialog
4. No data is saved (test only)

#### Slow Mode (Scientific Data)
1. Select settings:
   - **Filter**: V, B, R, I, etc. (change manually on photometer)
   - **Gain**: 10 (adjust based on count rates)
   - **Integ(sec)**: 5.00 (typical for stars)
   - **Interval**: 3 (options: 1-4 for slow, 100-5000 for fast mode)
   - **Count**: slow
2. Select **Object**: 
   - "New Object" for manual entry
   - "SKY" for sky background
   - "CATALOG" (future feature)
3. Select **Catalog**: Astar, Foe, Soe, Var, etc.
4. Click **START**
5. Watch status messages update as each count completes
6. Data appears in the display grid when all counts complete
7. **Optional:** Double-click the data line to add notes/comments

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
