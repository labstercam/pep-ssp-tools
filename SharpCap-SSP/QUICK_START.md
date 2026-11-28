# SharpCap-SSP Quick Start Guide

## Overview
SharpCap-SSP provides SSP photometer control for use with SharpCap or standalone.
This guide will get you collecting photometry data in 5 minutes. It covers manual
data collection, telescope **GOTO + plate-solve/sync**, and **automated sequence runs**
(Var/Comp/Check/Sky) with silent autosave.

---

## Installation

### Option 1: SharpCap (Zero Setup - Recommended for SharpCap users)

**Prerequisites:**
- ✅ SharpCap Pro installed
- ✅ SSP-3a or SSP-5a photometer
- ✅ Serial cable connected to PC

**One-Time Setup:**
1. Download the latest release zip file from https://github.com/labstercam/pep-ssp-tools/releases/tag/v0.2.0
2. Unzip the contents. Recommend to your \Documents\Sharp\SSP:
   ```
   C:\Users\YourName\Documents\SharpCap\SSP
   ```

3. In SharpCap, go to **Tools → Settings → Scripting**

4. Set **Startup Script** to:
   ```
   C:\Users\YourName\Documents\SharpCap\SSP\main.py
   ```

5. Restart SharpCap - **"PEP"** button appears in toolbar
   - Button displays the SSP photometer icon
   - Located in the main SharpCap toolbar

6. Click **PEP** to launch the SSP control window

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
2. Download and unzip the latest release zip file from https://github.com/labstercam/pep-ssp-tools/releases/tag/v0.2.0, recommend unzip to \Documents\Sharp\SSP
3. Navigate to that folder in File Explorer
4. Right-click `install.ps1` and select **"Run with PowerShell"**
5. Double-click `Create_Desktop_Shortcut.bat` to create a desktop icon

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
- **Every reading is also autosaved silently** (no dialog) to a per-target
  `YYMMDD-HHMMSS-<target>.raw` + `.tab`, so data is never lost even if you don't
  press Save Data. These land in the same folder as your last manual save.

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

### Automated Sequence Runs

Run a Var→Comp cycle (or any custom pattern) automatically instead of pressing
START for each star.

**Build a sequence — two ways:**
- **Editor:** `Sequence → Edit Sequence…` — load a template, add/reorder steps, set
  the run length, and **Save As**. Stored in `Documents\SharpCap\SSP\sequences\*.json`.
  The **Sequence:** box holds the name (type a new one to save a copy); the help panel
  under the step fields shows the **syntax and "what it does"** of the selected command.
- **Text file:** write a `.ssp` file and load it with `File → Open Script File`
  (`Sequence → Export Sequence…` writes the current sequence back out as `.ssp`).

Load a previously saved sequence at any time with **`Sequence → Load Sequence…`** —
pick from the list of saved sequences and built-in templates and it becomes the
current sequence (ready for **RUN SEQ**).

**Run it**
1. Prepare — connect, set gain/integration/interval, and select the target
   (`Catalog → Select Target Star`). Tick **Plate Solve and Sync** to re-solve each GOTO.
2. Load a sequence (above).
3. Set the run length (editor): **Max minutes** and/or **Max observations**;
   **Repeat** caps whole passes (0 = until the limit). Empty = a single pass.
4. Run — click **RUN SEQ** on the main window (or **Run** in the editor). **STOP**
   aborts after the current step. **PAUSE** finishes the current step and holds the
   run (the button then reads **RESUME**); while paused the manual SSP controls
   (**GOTO**, filter, integration, **START**, …) are unlocked so you can operate
   SharpCap, then press **RESUME** to carry on.
5. Every reading is **autosaved silently** (no prompts) to a per-target
   `YYMMDD-HHMMSS-<target>.raw` + `.tab` in your last data folder.

#### Sequencer command reference

Commands are one per line, `COMMAND, value` (comma-separated). `#` starts a comment;
blank lines are ignored. In `MEASURE`/`SKY`, any omitted field inherits the current
main-window setting. Unknown commands are rejected when the file loads.

| Command | Syntax | What it does |
|---|---|---|
| `MAXMINUTES` | `MAXMINUTES, 60` | Stop the run after 60 wall-clock minutes. |
| `MAXOBS` | `MAXOBS, 50` | Stop the run after 50 completed measurements. |
| `REPEAT` / `END` | `REPEAT, 6` … `END` | Repeat the enclosed block 6 times. |
| `GOTO` | `GOTO, V` / `GOTO, C` / `GOTO, K` | Slew to the target's Variable / Comparison / Check star. |
| `GOTO` | `GOTO, RA,Dec` | Slew to absolute coordinates: RA in decimal **hours**, Dec in decimal **degrees**, e.g. `GOTO, 12.5,-30.25`. |
| `GOTO` | `GOTO, offset=0.0,0.25` | Slew to an offset from the target's variable star. |
| `GOTO` | `GOTO, V, offset=0.0,0.25` | Slew to the V/C/K star **plus** an RA/Dec offset (`dRA` in hours, `dDec` in degrees). |
| `TARGET` | `TARGET, OMI CET` | Load a new catalog object **by name** and its Var / Comp / Check stars for all following steps. |
| `TARGET` | `TARGET, auid=000-BBW-425` | Load a new catalog object **by AUID** (add `, id=auid` / `id=name` to force the field explicitly). |
| `MEASURE` | `MEASURE, filter=V, integ=5, interval=3, gain=10` | One PEP measurement (every parameter is optional). |
| `SKY` | `SKY, label=SKYLAST, filter=V` | A sky reading; `label` is `SKY`, `SKYNEXT` or `SKYLAST`. |
| `SKY` | `SKY, label=SKYLAST, offset=0.0,0.25` | Sky reading taken after slewing to an RA/Dec offset. |
| `GOTO` / `SKY` | `GOTO, V, offset=0.0,0.25, plate_solve=0` | Add `plate_solve=0` to **skip** the plate-solve/sync for that step (a fast offset/sky slew); `plate_solve=1` forces it on. |
| `FILTER` | `FILTER, B` | Change filter (auto mode moves the slider; manual mode just records). |
| `WAIT` | `WAIT, 30` | Pause 30 seconds (the UI keeps running). |
| `WAIT_UNTIL` | `WAIT_UNTIL, 2026-11-27 02:45:00` | Wait until that absolute **UTC** date/time. |
| `ABORT_IF` | `ABORT_IF, airmass_above=2.5` | Stop the run if the target is above that airmass (or `alt_below=15`). |

**Field reference**

| Field | Applies to | Meaning |
|---|---|---|
| `filter=` | MEASURE, SKY | Filter name on the active bar (`V`, `B`, `u`, ...). |
| `gain=` | MEASURE, SKY | `1`, `10` or `100`. |
| `integ=` | MEASURE, SKY | Integration time in **seconds** (`5`, `10`). |
| `interval=` | MEASURE, SKY | Number of counts (1-8; 6/8 are binned to 3/4). |
| `object=` / `catalog=` | MEASURE, SKY | Override the data-line object name / catalog code. |
| `label=` | SKY | `SKY` / `SKYNEXT` / `SKYLAST`. |
| `offset=dRA,dDec` | GOTO, SKY | RA/Dec offset (RA in **hours**, Dec in **degrees**). For GOTO it is applied **on top of** the target star/coords; for SKY it is the sky-read position. |
| `plate_solve=0` / `plate_solve=1` | GOTO, SKY | Per-step override of the **Plate Solve and Sync** checkbox: `0` skips the solve for this slew, `1` forces it on. Leave it out to use the checkbox. |
| `id=name` / `id=auid` | TARGET | Force which catalog field the identifier matches (default: try the name first, then the AUID). |
| `alt_below=` / `airmass_above=` | ABORT_IF | Stop thresholds (below altitude / above airmass). |

**Notes**

- `WAIT_UNTIL` uses UTC only: if the time is **<= 30 min** in the past it proceeds with
  a warning; if it is **> 30 min** in the past it stops the run with a warning.
- `ABORT_IF` is skipped when the observer location is not set (0,0); a target below the
  horizon always stops the run.
- `GOTO V/C/K` needs a target selected (`Catalog → Select Target Star`); a missing star
  (e.g. no Check star) simply skips that step.
- `TARGET` loads a new catalog object and its Var / Comp / Check triple **during** the
  run; the following `GOTO V/C/K`, the `MEASURE`/`SKY` defaults and `ABORT_IF` then use the
  new target. Objects are given by name or AUID (`auid=...`). Unknown objects are checked
  the moment a `TARGET` step is **added or edited** in the sequence editor (a popup warns
  if the object is not found), when a sequence is **loaded** (a warning lists any unknown
  objects) and again when a run **starts** (a warning with a **10-second countdown** you
  can cancel — the run does not begin until the countdown ends). If an object is still
  missing at run time the `TARGET` step is skipped silently.

**Legacy SSPDataq aliases** (accepted for compatibility): `COUNT` -> `MEASURE`;
`PAUSE, n` -> `WAIT, n`; `TELESCOPE, RA,Dec` -> `GOTO, RA,Dec`; `OBJECT`, `GAIN`,
`INTEG` and `INTERVAL` set defaults for the following `COUNT` steps; `LOAD`,
`LOADCATALOG` and `MIRROR` are accepted and ignored.

**Editor field mapping** (the same commands, entered in the dialog): `GOTO` -> **Value**
(`V`/`C`/`K`, or `RA,Dec`), plus optional **Params**
(`plate_solve=0`); an RA/Dec offset is written `offset=dRA,dDec` (the same syntax
`SKY` uses) — enter it in **Params** and it is applied **on top of** **Value**, e.g.
**Value** `V` plus **Params** `offset=0,0.25` slews to the variable star **plus** the
offset. `TARGET` -> **Value** (object name or AUID; may be `auid=...`), plus
optional **Params** (`id=auid`); `MEASURE` -> **Params**;
`SKY` -> **Label** + **Params**; `FILTER` -> **Value**; `WAIT` -> **Value** (seconds);
`WAIT_UNTIL` -> **Value** (datetime); `ABORT_IF` -> **Params**; `REPEAT` -> **Value** (count).

**Example** — V-C-V-C with a sky-last bookend, 60 minutes:

```
# V-C-V-C with a sky-last reading; run for 60 minutes
MAXMINUTES, 60
SKY, label=SKYLAST, filter=V
GOTO, C
MEASURE, filter=V, integ=5, interval=3
GOTO, V
MEASURE, filter=V, integ=5, interval=3
GOTO, C
MEASURE, filter=V, integ=5, interval=3
```

**Example** — two targets in one run, with an offset sky reading:

```
TARGET, OMI CET
GOTO, V, offset=0,0.05
MEASURE, filter=V, integ=5, interval=3
SKY, label=SKYLAST, offset=0,0.25
TARGET, auid=000-BBW-425
GOTO, V
MEASURE, filter=V, integ=5, interval=3
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

### Telescope GOTO & Plate Solving
- `Catalog → Select Target Star` loads the target's **Var / Comp / Check** stars.
- A sequence `TARGET, <name or AUID>` step can load a new catalog object (and its
  **Var / Comp / Check** stars) part-way through a run — e.g. to observe several
  objects in one automated session.
- **GOTO Selected Star** slews to whichever star is chosen in the Object dropdown.
- The two-stage button slews **Comp → Var → Comp** (toggles each press).
- Tick **Plate Solve and Sync** (on the target row) to re-solve and sync the mount
  after each slew.
- Without a connected mount, GOTO copies the coordinates to the clipboard for the
  SharpCap Push-To Assistant.

### Automated Sequences & Autosave
- Build and run automatic PEP runs from the **Sequence** menu and the **RUN SEQ**
  button — see *Automated Sequence Runs* under *Typical Observation Workflow*.
- Every reading is **autosaved silently** to a per-target `YYMMDD-HHMMSS-<target>.raw`
  + `.tab` (no prompts, never blocks the run).

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

### `.tab` Format (for the PEP Analysis Workbook)

Alongside every `.raw`, SharpCap-SSP writes a **tab-separated `.tab` file** with a
column order chosen so it can be **cut and pasted straight into the PEP analysis
workbook** (no "text to columns" step needed). It is written both by `File → Save Data`
and by the **silent autosave** (so it is always up to date during a run).

**Header** — 4 lines; from line 4 the columns are separated by a TAB character:

```
 FILENAME=<file>.TAB       RAW OUTPUT DATA FROM SSP DATA ACQUISITION PROGRAM
 UT DATE= MM/DD/YYYY   TELESCOPE= [name]      OBSERVER= [name]
 CONDITIONS= [conditions]
CAT  OBJECT  F  MO-DY-YEAR  UT  COUNT1  COUNT2  COUNT3  COUNT4  INT  SCLE  COMMENTS
```

**Data rows** — one per reading (TAB-separated):

| # | Column | Example | Meaning |
|---|---|---|---|
| 1 | CAT | `V` | Catalog code (`A`/`F`/`C`/`V`/…) |
| 2 | OBJECT | `HD 12345` | Star name (12 chars max) |
| 3 | F | `V` | Filter |
| 4 | MO-DY-YEAR | `12-10-2025` | UT date |
| 5 | UT | `03:45:23` | UT time (mid-point corrected) |
| 6-9 | COUNT1..COUNT4 | `12543` | The 3-4 counts (blank when unused) |
| 10 | INT | `5` | Integration time (seconds) |
| 11 | SCLE | `10` | Scale = gain |
| 12 | COMMENTS | `good seeing` | Optional — only present if you added a note (double-click) |

**How to get it into the PEP analysis workbook**

1. Open the `.tab` file in **Excel** — it opens straight into columns (or open it in
   Notepad and paste into Excel; the tabs land each value in its own cell).
2. The 4 header lines occupy the first rows; select from the **first data row**
   (the one beginning with the catalog code) downwards.
3. **Copy** those rows and **paste** them into the PEP analysis workbook's input sheet
   — the `.tab` column order (CAT, OBJECT, F, date, UT, counts, INT, SCLE, COMMENTS)
   matches the SSPDataq/PEP layout the workbook expects.
4. Because the file is **appended live** during the run, you can paste mid-run or wait
   until the sequence finishes and paste the whole set at once.

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

#### ⚠️ Important: Leading Space in .raw Files

**All data lines in .raw files have a leading space character.** This is critical for understanding field positions:

**BASIC (SSPDataq) behavior:**
- Uses `input #file` statement to read data lines (lines 5+)
- The `input` statement **automatically strips the leading space**
- Field positions in BASIC code use `mid$(line, pos, len)` with 1-based indexing
- Example: `mid$(line, 1, 2)` extracts month "09" (positions 1-2 AFTER space removal)

**Python (SharpCap-SSP) behavior:**
- Uses standard file reading that **preserves the leading space**
- Field positions use Python slicing with 0-based indexing
- Must account for the leading space when mapping BASIC positions
- Example: `line[1:11]` extracts "09-23-2007" (positions 2-11 in the actual file)

**Position Mapping:**
```
Actual file:  _09-23-2007_02:04:59_C____BS458__________U__00706__00712__00706______0__10_1
              ^                                                                            
              Position 0 (Python) / Leading space (stripped by BASIC input)

BASIC mid$(line, start, len) → Python line[start:end]
------------------------------------------------
mid$(1, 2)   → Month "09"     → line[1:3]   (positions 2-3 in file)
mid$(4, 2)   → Day "23"       → line[4:6]   (positions 5-6 in file)  
mid$(7, 4)   → Year "2007"    → line[7:11]  (positions 8-11 in file)
mid$(12, 2)  → Hour "02"      → line[12:14] (positions 13-14 in file)
mid$(21, 1)  → Catalog "C"    → line[21:22] (position 22 in file)
mid$(26, 12) → Object name    → line[26:38] (positions 27-38 in file)
mid$(41, 1)  → Filter "U"     → line[41:42] (position 42 in file)
mid$(44, 5)  → Count1         → line[44:49] (positions 45-49 in file)
mid$(72, 2)  → Integration    → line[72:74] (positions 73-74 in file)
mid$(75, 3)  → Scale          → line[75:78] (positions 76-78 in file)
```

**Why this matters:**
- Field positions appear "off by one" when comparing BASIC and Python code
- Both implementations are correct - they account for different file reading behavior
- When debugging or comparing implementations, always remember BASIC positions are post-strip
- The leading space is NOT an error - it's part of the SSPDataq .raw file format

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

### Managing Coefficients

**Coefficients Menu:**
The Coefficients menu provides tools for managing zero-point and standard error values:

1. **Load Previous** - Loads saved values from PPparms3.txt:
   - Zero-points: ZPv, ZPbv (lines 29-31)
   - Standard errors: Ev, Ebv (lines 33-35)
   - Displays previously saved calibration results
   
2. **Use Current** - Copies computed results to result boxes:
   - Transfers values from most recent regression calculation
   - Allows review before saving
   
3. **Save** - Saves result box values to PPparms3.txt:
   - Updates zero-points and standard errors
   - Type '0' in box to keep previous value unchanged
   - Confirmation dialog before saving
   
4. **Clear** - Clears all result text boxes

### Transformation Coefficients
- Epsilon (ε): Loaded from PPparms3.txt line 8
- Mu (μ): Loaded from PPparms3.txt line 10
- Zero-points (ZPv, ZPbv): Loaded from PPparms3.txt lines 29-31
- Standard errors (Ev, Ebv): Loaded from PPparms3.txt lines 33-35
- These are used in transformation equations
- If PPparms3.txt not found, defaults to zeros

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
- ⏸️ Fast mode (100-5000 rapid readings)
- ⏸️ Very fast mode (SSP-5 only, 20 ms integrations)
- ⏸️ Loading *additional* star catalogs (the built-in PEP target catalog and the
  first-order extinction catalog are included)
- ⏸️ Built-in data reduction / magnitude calculation (use the All Sky tool plus your
  PEP processing spreadsheet)
- ⏸️ General plotting beyond the All Sky calibration scatter plot

**Implemented (v0.2.0):** serial comms; slow + trial modes; 6/8-interval binning;
`.raw` + `.tab` export and silent autosave; star catalog; first-order extinction
selection; telescope **GOTO with plate-solve/sync**; **automated sequence runs**
(`.ssp`/JSON, editor, run length, sky/offset steps); dockable window; night mode;
All Sky calibration; memory-safe long sessions.

---

## Version History
- **0.2.0** (2026-11-26) - Automated Sequence Runs
  - New sequence engine (`ssp_sequence.py`) + executor: GOTO / MEASURE / SKY /
    FILTER / WAIT / WAIT_UNTIL / ABORT_IF / REPEAT steps
  - Run length by minutes or observations; STOP aborts cleanly
  - `Sequence → Edit Sequence…` editor (add/reorder steps, save/load named
    sequences, templates), `Load Template`, `Export Sequence…`, and
    `File → Open Script File` (`.ssp`)
  - Headless GOTO / measure (no modal dialogs mid-run)
  - Fixed: gain is coerced to int (sequence MEASURE steps inherited a string gain)
  - `test_sequence.py` regression suite (16 tests)
- **0.1.6** (2026-11-25) - Memory Leak Fix for Long Sessions
  - Fixed `OutOfMemoryException` / crash after ~100 readings when a guide camera was running
  - SSP waits now pump the UI message loop instead of blocking it, so camera frames are
    released rather than queued
  - Measured over a 99-minute soak: +6.6 MB total (was ~15.6 GB projected at the old rate)
  - Fixed `_dock_timer` not stopping when the window closes
  - Added close-mid-read and trial-mode re-entrancy guards
  - Normalised module version strings (were a mix of 0.1.0, 0.1.2, 0.1.5 and 1.0.0)
- **0.1.5** (2026) - Dockable Window, Binning, .tab Export
  - Dockable SSP Data Acquisition window (snaps to SharpCap's bottom edge)
  - 6 and 8-interval binning modes with automatic summing to 3 or 4 readings
  - .tab tab-separated export for direct paste into Excel
  - Arduino SSPCARD support
- **0.1.4** (2026-09-26) - Memory Optimizations & Stability
  - Memory optimizations for extended observation sessions
  - Reduced temporary string allocations by ~80%
  - Timer resource cleanup prevents memory leaks
  - Optimized serial communication for SSP5A compatibility
  - Reduced "Communication error - count restarted" messages
  - Added verification tools: `verify_optimization.py` and `test_memory_optimization.py`
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
│ GOTO:    GOTO Selected Star / GOTO Comp │
│ SEQ:     Sequence menu / RUN SEQ        │
│ SAVE:    File → Save Data (auto-saved)  │
│ CLEAR:   File → Clear Data              │
│ EXIT:    File → Quit                    │
└─────────────────────────────────────────┘
```

**Remember:** Change filters manually on the photometer, then update the Filter dropdown to match!
