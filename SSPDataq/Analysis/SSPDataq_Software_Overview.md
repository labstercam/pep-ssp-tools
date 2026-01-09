# SSPDataq Software Analysis and Overview

**Document Version:** 1.0  
**Date:** January 10, 2026  
**Purpose:** Analysis of SSPDataq software for potential redevelopment using SharpCap IronPython

---

## Executive Summary

SSPDataq is a comprehensive astronomical photometry data acquisition and analysis suite developed by Jerry Persha for Optec, Inc. The software controls SSP-series single-channel photometers (SSP-3a and SSP-5a models) through serial COM port communication, collects photometric count data from astronomical observations, and provides complete data reduction to standard magnitude systems (UBVRIJH). The software is written in LibertyBasic and compiled for Windows.

### Key Software Components

1. **SSPDataq3_3,21.bas** - Main data acquisition program (4128 lines)
2. **Reduction2,61.bas** - Photometry reduction module (3033 lines)
3. **ShowData2,62.bas** - Data visualization and plotting module (5343 lines)
4. **Data_Editor2,56.bas** - Star catalog database editor (790 lines)
5. **Supporting modules:** Extinction, SOE, Transformation, AllSky calibration
6. **SSPDataqLauncher2,56.bas** - Program launcher interface (135 lines)

---

## SECTION 1: DATA COLLECTION & COM PORT CONNECTION

### 1.1 Serial Communication Architecture

#### COM Port Configuration
- **Configuration File:** dparms.txt stores persistent settings
- **Supported Ports:** COM1 through COM19
- **Serial Parameters:** 19200 baud, no parity, 8 data bits, 1 stop bit, no flow control
- **Connection String Format:** `"com"+str$(ComPort)+":19200,n,8,1,ds0,cs0"`

#### Connection Initialization Process

**Key Subroutine:** `[CONNECT_SERIAL]` (lines 863-922)

```
Connection Sequence:
1. Open COM port with specified parameters
2. Send initialization command "SSSSSS" to put photometer into serial mode
3. Wait up to 5 seconds (100 iterations × 50ms) for acknowledgment
4. Check for valid response (CR=10 or !=33 ASCII)
5. If auto-mirror enabled, send "SVIEW0" to position mirror
6. If auto-filter enabled, send "SHNNN" to home filter bar
7. Set CommFlag = 1 to indicate connection established
```

**Error Handling:**
- `[COMHandler]` (line 2068) - Catches COM port opening errors
- `oncomerror` directive used for error trapping
- Multiple retry mechanism in data collection routines

#### Disconnection Process

**Key Subroutine:** `[DISCONNECT_SERIAL]` (lines 924-953)

```
Disconnection Sequence:
1. Send exit command "SEEEEE" to photometer
2. Close COM port handle (#commHandle)
3. Reset CommFlag = 0
4. Reset all UI combo boxes to default state
5. Clear selection indexes
```

### 1.2 Data Collection Modes

The software supports four distinct collection modes:

#### Mode 1: TRIAL Mode
- **Purpose:** Single test reading for setup verification
- **Process:** Quick count acquisition and display in message box
- **No data storage:** Results not added to data array

#### Mode 2: SLOW Mode (Primary Scientific Mode)
- **Integration Times:** 1, 5, or 10 seconds
- **Intervals:** 1-4 readings per acquisition
- **Command Sequence:**
  1. Clear buffer: `input$(#commHandle, lof(#commHandle))`
  2. Send count command: `print #commHandle, "SCnnnn"`
  3. Wait for integration time + overhead (15%)
  4. Read buffer and extract count value after "=" character
  5. Verify data integrity (check for ASCII 0)
  6. Repeat for specified interval count
  7. Store data in Counts$(I) array

**Key Subroutine:** `[Get_Counts]` (lines 2231-2298)

```
Data Collection Process:
1. Record UT time/date at acquisition start
2. For each interval (1-4):
   a. Clear serial buffer
   b. Send "SCnnnn" command to start count
   c. Wait for integration time + margin
   d. Read serial buffer for count data
   e. Extract 5-digit count value after "=" marker
   f. Error check for communication failures
   g. Retry on error (increase IntervalRecord)
   h. Check for ESC key abort
3. Record final time and return
```

**Data Format:**
- 5-digit count values (format: XXXXX)
- Serial response: "C=XXXXX\r\n"

#### Mode 3: FAST Mode (Rapid Photometry)
- **Integration Times:** 0.05, 0.10, 0.50, 1.0, 5.0, or 10.0 seconds
- **Intervals:** 100, 1000, 2000, or 5000 readings
- **Buffer Management:** Pre-calculates buffer size = Interval × 6 bytes
- **Command:** "SM" + 4-digit interval count

**Key Subroutine:** `[Get_Fast_Counts]` (lines 2326-2361)

```
Fast Collection Process:
1. Clear buffer
2. Format interval as 4-digit string (right-padded with zeros)
3. Synchronize to time change (millisecond precision)
4. Send "SMXXXX" command at time boundary
5. Record start time in milliseconds
6. Calculate expected buffer length (Interval × 6)
7. Poll buffer until full dataset received
8. Update countdown timer during wait
9. Extract data and parse into FastCounts$(I) array
10. Record end time and calculate elapsed
11. Generate time array for each data point
```

**Time Array Generation:** `[Get_Fast_Array]` (lines 2301-2325)
- Calculates individual timestamp for each count
- Interpolates times based on start/end and interval count
- Handles midnight rollover

#### Mode 4: VFAST Mode (Very Fast - SSP-5 only)
- **Integration Time:** 0.02 seconds (20 milliseconds)
- **Intervals:** 2000 or 5000 readings
- **Buffer Management:** Interval × 2 bytes
- **Command:** "SN" + 4-digit interval count
- **Data Format:** 2-byte count values (reduced precision for speed)

**Key Subroutine:** `[Get_Very_Fast_Counts]` (lines 2363-2388)

Similar to Fast mode but with 2-byte data format and different command prefix.

### 1.3 Hardware Control Commands

#### Filter Control
- **Auto Filter (6-position slider):**
  - Home command: "SHNNN"
  - Filter select: Automatic positioning
  - Acknowledgment: Waits for "!" response via `[WaitForAck]`
  
- **Manual Filter (2-position slider):**
  - User prompted for manual filter change
  - No serial commands sent

#### Gain Control
- **Values:** 1, 10, or 100
- **Command:** "SG" + gain value
- **Stored in:** Combo2$ array

#### Integration Time Control
- **Slow Mode Options:** 1.00, 5.00, 10.00 seconds
- **Fast Mode Options:** 0.05, 0.10, 0.50, 1.00, 5.00, 10.00 seconds
- **VFast Mode Option:** 0.02 seconds
- **Format:** Milliseconds sent to device

#### Flip Mirror Control (Optional Hardware)
- **Command Format:** "SVIEW" + position (0=view, 1=record)
- **Timing:** 2-second pause for mechanical movement
- **Auto/Manual Modes:** Configurable in dparms.txt
- **Status Tracking:** MirrorFlag variable (0=view, 1=record)

### 1.4 Communication Protocol Details

#### Command Format
All commands follow pattern: `"S" + command_letter + parameters`

**Command Set:**
- `SSSSSS` - Enter serial control mode
- `SEEEEE` - Exit serial control mode
- `SCnnnn` - Start count (slow mode)
- `SMxxxx` - Start multiple counts (fast mode)
- `SNxxxx` - Start counts (very fast mode)
- `SGxxx` - Set gain
- `SHNNN` - Home filter bar
- `SVIEWx` - Set flip mirror (x=0 view, x=1 record)

#### Acknowledgment Protocol

**Key Subroutine:** `[WaitForAck]` (lines 2799-2825)

```
Acknowledgment Process:
1. Set Ack flag to 0 (false)
2. Loop up to 100 iterations (5 second timeout):
   a. Pause 50 milliseconds
   b. Check buffer length
   c. Read available bytes
   d. Search for "!" character in response
   e. Set Ack=1 if found, exit loop
3. If no acknowledgment received:
   - Print error message
   - Pause 2 seconds
   - Caller typically retries operation
```

#### Buffer Management
- **Read Operation:** `input$(#commHandle, numBytes)`
- **Buffer Check:** `lof(#commHandle)` returns bytes available
- **Clear Buffer:** Read and discard: `junk$ = input$(#commHandle, lof(#commHandle))`

#### Timing and Synchronization

**Key Subroutine:** `SUB Pause mil` (lines 2826-2843)

```
Precise Timing Implementation:
- Uses Windows Kernel32 Sleep() function
- Millisecond-level timing accuracy
- Handles midnight rollover (86400000ms per day)
- Reduces CPU usage during waits
- DLL Call: calldll #kernel32, "Sleep", 1 as ulong, r as void
```

### 1.5 Data Storage and Format

#### In-Memory Arrays
```
DIM Counts$(4000)          - Slow mode count data (5 bytes each)
DIM FastCounts$(5000)      - Fast/VFast mode count data (2-4 bytes)
DIM FastTimeArray$(5000)   - Timestamps for fast mode data
DIM DataArray$(4000)       - Formatted display data
DIM SavedData$(4000)       - Final data with notes for file output
```

#### Temporary Data Handling
- **File:** "Temporary Data.raw"
- **Purpose:** Preserve data across sessions
- **Backup:** Renamed to "Backup Data.raw" if abnormal shutdown detected
- **Initialization:** Checked at program startup

#### Data Display Format

**Key Subroutine:** `[DisplayData]` (lines 2142-2163)

Data formatted for display with following fields:
- UT Date (MM-DD-YYYY)
- UT Time (HH:MM:SS)
- Catalog code (single character)
- Object name (12 characters)
- Filter (single character)
- Count values (up to 4 readings, 5 digits each)
- Integration time (seconds)
- Scale/Gain value
- Comments/Notes (10 characters)

#### Raw Data File Format (.raw files)

**Example Header:**
```
FILENAME=SAMPLE.RAW       RAW OUTPUT DATA FROM SSP DATA ACQUISITION PROGRAM
UT DATE= MM/DD/YYYY   TELESCOPE= [name]      OBSERVER= [name]
CONDITIONS= [description]
MO-DY-YEAR    UT    CAT  OBJECT         F  ----------COUNTS---------- INT SCLE COMMENTS
```

**Data Line Format:**
```
MM-DD-YYYY HH:MM:SS C    OBJECTNAME     F  XXXXX  XXXXX  XXXXX  XXXXX  II SS  NOTES
```

Where:
- C = Catalog code (S, F, T, V, C, M, Q)
- F = Filter (U, B, V, R, I or Sloan equivalents)
- XXXXX = 5-digit count values
- II = Integration time in seconds
- SS = Scale/Gain value

---

## SECTION 2: SUPPORTING FUNCTIONS AND COMPONENTS

### 2.1 Time and Date Management

#### UT Time Calculation
**Key Subroutines:**
- `[FindDateTime]` (line 2175) - Master time/date acquisition
- `[UTtimeFind]` (line 2742) - Convert local to UT time
- `[UTdateFind]` (line 2759) - Calculate UT date
- `[UTtimeCorrected]` (line 2764) - Handle day transitions

**Process:**
1. Get local system time
2. Apply TimeZoneDiff (from dparms.txt, range -12 to +12)
3. Handle day rollover for UT calculation
4. Store in UTtime$, UTdate$, Days variables

#### Julian Date Conversion
Used by reduction modules for astronomical calculations:
- Converts UT date to Julian Day number
- Stores as Days variable
- Accounts for month/year transitions

### 2.2 User Interface Components

#### Main Window Structure
**Dimensions:** 860×315 pixels (WindowWidth × WindowHeight)

**UI Elements:**
- **Combo Box 1** (Combo1$) - Filter selection (6 filters + Home)
- **Combo Box 2** (Combo2$) - Gain values (1, 10, 100)
- **Combo Box 3** (Combo3$) - Integration time values
- **Combo Box 4** (Combo4$) - Interval values (1-4 slow, 100-5000 fast)
- **Combo Box 5** (Combo5$) - Count mode (trial, slow, fast, Vfast, ABORT)
- **Combo Box 6** (Combo6$) - Object selection (up to 4000 objects)
- **Combo Box 7** (Combo7$) - Catalog selection
- **Button 1** - START button (trigger data collection)
- **Button 3** - Mirror control button (VIEW/RECORD)
- **TextBox 1** - UT time display
- **TextBox 2** - Local time display
- **TextBox 4** - Message/status display
- **ListBox 1** - Data display area (with scroll bars)

#### Display Modes
- **Day Mode** (NightFlag=0) - Standard colors
- **Night Mode** (NightFlag=1) - Red screen for dark adaptation

### 2.3 Object and Catalog Management

#### Object Types
```
Combo6$ Array:
  Index 1: "New Object" - Manual entry
  Index 2: "SKY" - Sky background measurement
  Index 3: "SKYNEXT" - Sky at next filter
  Index 4: "SKYLAST" - Sky at previous filter
  Index 5+: "CATALOG" - Stars from loaded catalogs
```

#### Catalog Types (Combo7$)
```
1. Astar - General astronomical objects
2. Foe - First Order Extinction calibration stars
3. Soe - Second Order Extinction calibration stars
4. Comp - Comparison stars for differential photometry
5. Var - Variable stars (observation targets)
6. Moving - Moving objects (asteroids, comets)
7. Trans - Transformation calibration stars
8. Q'check - Quality check stars
```

#### Star Database Arrays
```
DIM CatalogStars$(4000)    - Star names from loaded catalogs
DIM TypeArray$(400)        - Object type codes
DIM RAArray(400)           - Right Ascension in degrees
DIM DECArray(400)          - Declination in degrees
DIM SDitem$(4000,13)       - Individual star data items
```

**Key Subroutines:**
- `[Load_Catalog_Stars]` (line 3029) - Load star data from files
- `[Select_Catalog_Stars]` (line 2859) - UI for star selection
- `[Select_All_Objects]` (line 3057) - Batch load all catalog objects
- `[Reset_Object_Combobox]` (line 2710) - Clear and reinitialize object list

### 2.4 Script Automation System

#### Script File Format (.ssp files)
Comma-separated command,value pairs:
```
LOAD, ObjectName
LOADCATALOG, CatalogName
FILTER, FilterName
GAIN, GainValue
INTEG, IntegrationTime
INTERVAL, IntervalCount
OBJECT, ObjectName
COUNT
MIRROR, Position
PAUSE, Seconds
TELESCOPE, RA,DEC
END
```

#### Script Execution
**Key Sections:**
- `[OPEN_SCRIPT]` (line 577) - Load and parse script file
- `[CONTINUE_SCRIPT]` - Execute script commands sequentially
- Script array: `DIM Script$(10000)` stores parsed commands

**Script Control:**
- ScriptFlag - Indicates script window is open
- ScriptHold - Pauses script execution
- ScriptLine - Current line being executed
- ESC key - Abort script execution

**Script Features:**
- Sequential command execution
- Object and catalog loading
- Hardware control (filter, gain, mirror)
- Automated data collection sequences
- Telescope pointing integration (optional)
- Pause/delay commands
- Error handling and recovery

### 2.5 Telescope Control Integration

#### Supported Telescope Types
```
TelescopeType values (from dparms.txt):
  0 - No telescope control
  1 - Meade LX200
  2 - Celestron old GT
  3 - Celestron N5 & N8
  4 - Celestron new GT
```

#### Telescope Control Components
- **Separate COM Port:** TelescopeCOM (independent of photometer)
- **Enable/Disable:** TelescopeFlag (0=disabled, 1=enabled)
- **Coordinate Systems:** RA/DEC in degrees, converted to telescope format

**Key Subroutines:**
- `[Move_Meade_Telescope]` (line 2542) - LX200 protocol
- `[Move_Celestron]` (line 2449) - Old GT, N5/N8 protocol
- `[Move_Celestron_New_GT]` (line 2501) - New GT protocol
- `[Find_Meade_Coordinates]` (line 2198) - Convert degrees to HMS/DMS
- `[Precess_Coordinates]` (line 2666) - Epoch conversion

**Integration with Data Collection:**
- Script commands can include telescope slew
- Coordinates loaded from catalog files
- Automated pointing for scripted observation sequences

### 2.6 Configuration Management

#### dparms.txt Structure
```
Line 1:  ComPort (integer 0-19)
Line 2:  TimeZoneDiff (integer -12 to +12)
Line 3:  AutoManual$ ("A" or "M" for filter mode)
Lines 4-21: Filters$(1-18) - 18 filter names (3 bars × 6 positions)
Line 22: FilterBar (1-3, current bar selection)
Line 23: NightFlag (0=day, 1=night screen)
Line 24: AutoMirrorFlag (0=no, 1=confirm, 2=auto)
Line 25: TelescopeFlag (0=disabled, 1=enabled)
Line 26: TelescopeCOM (0-19)
Line 27: TelescopeType (0-4)
Line 28: Telescope$ (telescope name string)
Line 29: Observer$ (observer name string)
Line 30: FilterSystem$ (1=Johnson/Cousins, 0=Sloan)
```

**Key Subroutine:** `[SaveDparms]` (line 2721) - Write configuration to file

#### PPparms3.txt Structure
Used by reduction modules:
```
Location data (latitude/longitude)
First order extinction coefficients (KU, KB, KV, KR, KI)
Second order extinction coefficient (KKbv)
Transformation coefficients
Color terms
Observer code (AAVSO)
Other photometry parameters
```

### 2.7 Menu System

#### File Menu
- Save Data - Write SavedData$ array to .raw file
- Clear Data - Reset data arrays
- Open Script File - Load automation script
- Quit - Exit with cleanup

#### Setup Menu
- Connect to SSP - Initiate serial connection
- Disconnect from SSP - Close serial port
- Select SSP COM Port - Choose COM1-19
- Time Zone - Set UT offset
- Filter Bar Setup - Configure 3 filter bars
- Auto/Manual Filters - Toggle automatic filter control
- Auto/Manual Mirror - Configure flip mirror behavior
- Night/Day Screen - Toggle red night mode
- Show Setup Values - Display current configuration

#### Script Menu
- Open Script File - Load .ssp file
- Make Script - Script creation tool
- Filter System - Select Johnson/Cousins or Sloan

#### Telescope Menu
- Telescope Control - Enable/disable telescope integration
- Select Telescope - Choose telescope type
- Select Telescope COM port - Choose telescope COM port
- Show Setup Values - Display telescope configuration

#### Help Menu
- SSPDataq3 Help - Launch SSPDataq3.chm help file
- Photometry Help - Launch Photometry2.chm help file
- About - Version and license information

---

## SECTION 3: RELATED MODULES AND PROGRAMS

### 3.1 Reduction Module (Reduction2,61.bas)

**Purpose:** Convert raw photometer counts to calibrated standard magnitudes

**Key Functions:**
- First order extinction correction
- Second order extinction correction (for b-v)
- Transformation coefficient application
- Magnitude calculation in UBVRI filter system
- Standard error computation
- AAVSO format output

**Input:** .raw data files from SSPDataq3
**Output:** Calibrated magnitudes with error estimates

**Major Processing Steps:**
1. Load raw count data
2. Select comparison and variable stars
3. Apply sky background subtraction
4. Calculate instrumental magnitudes
5. Apply extinction corrections (airmass dependent)
6. Apply transformation coefficients
7. Compute differential magnitudes
8. Calculate standard magnitudes
9. Estimate measurement errors

**Data Flow:**
```
Raw Counts → Sky Subtraction → Instrumental Mag → 
Extinction Correction → Transformation → Standard Mag
```

### 3.2 ShowData Module (ShowData2,62.bas)

**Purpose:** Visualization and analysis of reduced photometry data

**Key Features:**
- **Graphical Plotting:**
  - Time series plots (magnitude vs. time)
  - Customizable time scales (minutes to hours)
  - Magnitude scales (0.02 to 1.0 mag ranges)
  - Cursor readout with coordinate display
  
- **Data Export Formats:**
  - AAVSO format submission files
  - MEDUZA format
  - BRNO format
  - ETD (Exoplanet Transit Database) format
  - Period04 input files
  
- **Analysis Tools:**
  - Time of minimum determination
  - Phase calculation
  - Eclipsing binary analysis
  - Period search integration
  - Parabolic curve fitting
  
- **Display Options:**
  - Color index plotting
  - Multiple filter display
  - Label annotations
  - Graph printing and export (.bmp files)

**Array Structures:**
```
DIM TimeString$(3000,2)      - JD and magnitude pairs
DIM TimeSeriesData$(3000)    - Formatted time series
DIM ErrorMag(200)            - Magnitude errors
DIM TimeScale$(15)           - Time axis options
DIM MagScale$(7)             - Magnitude axis options
```

### 3.3 Data Editor Module (Data_Editor2,56.bas)

**Purpose:** Create and maintain star catalogs for observations

**Key Features:**
- **Catalog Management:**
  - Open/Edit/Save star databases
  - Support for multiple catalog types (Comp/Var/Check, SOE, FOE, Trans)
  - Johnson/Cousins and Sloan filter systems
  
- **Star Data Fields:**
  - Star name (12 characters)
  - Spectral type
  - RA 2000.0 (hour, minute, second)
  - DEC 2000.0 (degree, minute, second)
  - V magnitude (or r' for Sloan)
  - B-V index (or g'-r' for Sloan)
  - U-B index (or u'-g' for Sloan)
  - V-R index (or r'-i' for Sloan)
  - V-I index (or r'-z' for Sloan)
  - Object type (V=variable, C=comparison, Q=check, etc.)
  
- **Sorting Functions:**
  - Sort by name, RA, type
  - Sort by magnitude
  - Sort by color indices
  
- **Data Formats:**
  - Text-based catalog files
  - Version 2 format (expanded index support)
  - Sloan filter variants

**Catalog File Examples:**
- Star Data Version 2.txt (Johnson/Cousins)
- Star Data Version 2 Sloan.txt
- FOE Data Version 2.txt
- SOE Data Version 2.txt
- Transformation Data Version 2.txt

### 3.4 Extinction Module (Extinction2,56.bas)

**Purpose:** Calculate first and second order atmospheric extinction coefficients

**Process:**
1. Load calibration star observations from .raw files
2. Select extinction standard stars (wide airmass range)
3. Plot instrumental magnitude vs. airmass
4. Perform linear regression to determine extinction slope
5. Calculate K coefficients for each filter (KU, KB, KV, KR, KI)
6. Determine second order extinction (KKbv) for B-V color term
7. Save coefficients to PPparms3.txt for reduction use

**Extinction Equation:**
```
V = v + K_V × X
Where:
  V = standard magnitude
  v = instrumental magnitude
  K_V = first order extinction coefficient
  X = airmass (sec(zenith distance))
```

### 3.5 SOE Module (SOE2,56.bas)

**Purpose:** Second Order Extinction coefficient determination

**Function:**
- Analyzes color-dependent extinction effects
- Measures extinction variations with stellar color (B-V)
- Critical for precise B-V photometry
- Calculates K'' term for color-dependent extinction

**Input:** SOE calibration star observations spanning color range
**Output:** Second order extinction coefficients for PPparms3.txt

### 3.6 Transformation Module (Transformation2,56.bas)

**Purpose:** Determine transformation coefficients between instrumental and standard photometric systems

**Process:**
1. Observe standard stars with known magnitudes and colors
2. Measure instrumental magnitudes in multiple filters
3. Calculate transformation equations
4. Determine transformation coefficients (ε, μ, ν)
5. Save coefficients to PPparms3.txt

**Transformation Equations:**
```
V = v + TV + ε(B-V)
(B-V) = μ(b-v) + CB
(U-B) = ν(u-b) + CU
(V-R) = ...
(V-I) = ...
```

### 3.7 AllSky Module (AllSky2,57.bas)

**Purpose:** All-sky photometric calibration for wide-field photometry

**Function:**
- Calibrates entire sky for all-sky monitoring
- Handles spatial variations in extinction
- Processes multiple calibration stars across sky
- Suitable for all-sky camera photometry

**Input:** All-sky calibration star observations
**Output:** Sky calibration parameters

### 3.8 Program Launcher (SSPDataqLauncher2,56.bas)

**Purpose:** Central launch point for all SSPDataq suite programs

**UI Structure:**
- Main button interface
- Two groupboxes:
  - "Data Acquisition and Control"
  - "Photometry"
- License holder information display

**Launched Programs (.tkn token files):**
1. SSPDataq3.tkn - Main data acquisition
2. Data_Editor2.tkn - Star database editor
3. Extinction2.tkn - Extinction calculator
4. SOE2.tkn - Second order extinction
5. AllSky.tkn - All-sky calibration
6. Transformation2.tkn - Transformation coefficients
7. Reduction2.tkn - Photometry reduction
8. ShowData2.tkn - Data plotting/analysis

**Help Integration:**
- SSPDataq3.chm - Main program help
- Photometry2.chm - Photometry package help

---

## SECTION 4: DATA FLOW AND WORKFLOW

### 4.1 Observation Workflow

```
SETUP PHASE:
1. Load SSPDataqLauncher
2. Configure dparms.txt (COM port, time zone, filters, telescope)
3. Configure PPparms3.txt (extinction, transformation coefficients)
4. Create/edit star catalogs with Data_Editor

CALIBRATION PHASE:
5. Observe extinction stars → Run Extinction module → Update PPparms
6. Observe SOE stars → Run SOE module → Update PPparms
7. Observe transformation stars → Run Transformation → Update PPparms
8. (Optional) All-sky calibration → Run AllSky module

DATA ACQUISITION PHASE:
9. Launch SSPDataq3
10. Connect to SSP photometer (Setup → Connect to SSP)
11. Load object catalogs (CATALOG selection)
12. Create observation script (optional, Script → Make Script)
13. Configure observation parameters:
    - Select Filter
    - Select Gain
    - Select Integration Time
    - Select Interval
    - Select Object/SKY
14. Acquire data (START button or run script)
15. Save raw data to .raw file (File → Save Data)

REDUCTION PHASE:
16. Launch Reduction module
17. Open raw data file
18. Select comparison and variable stars
19. Process data with extinction and transformation
20. Save reduced magnitudes

ANALYSIS PHASE:
21. Launch ShowData module
22. Open reduced data file
23. Generate plots (time series, light curves)
24. Analyze data (minima, period search)
25. Export to AAVSO or other formats
```

### 4.2 File Dependencies

```
Configuration Files (Input):
  - dparms.txt → SSPDataq3 (COM, time, filter, telescope config)
  - PPparms3.txt → Reduction, Extinction, SOE, Transformation (photometry coefficients)

Catalog Files (Input/Edit):
  - Star Data Version 2.txt → Data_Editor, SSPDataq3
  - FOE Data Version 2.txt → Data_Editor, SSPDataq3
  - SOE Data Version 2.txt → Data_Editor, SSPDataq3
  - Transformation Data Version 2.txt → Data_Editor, SSPDataq3
  - (Sloan variants for Sloan filter system)

Script Files (Input):
  - *.ssp → SSPDataq3 (automation scripts)

Raw Data Files (Output from SSPDataq3, Input to Reduction):
  - *.raw → Contains time-stamped photometer counts

Reduced Data Files (Output from Reduction):
  - Contains calibrated magnitudes

Temporary Files:
  - Temporary Data.raw → SSPDataq3 crash recovery
  - Backup Data.raw → Previous session data if abnormal exit

Help Files:
  - SSPDataq3.chm
  - Photometry2.chm
  - Enter_Minima.chm

Plot Files (Output from ShowData):
  - *.bmp → Graph image exports
```

---

## SECTION 5: CRITICAL COMPONENTS FOR SHARPCAP IRONPYTHON REDEVELOPMENT

### 5.1 Core Functions to Replicate

#### Priority 1: Essential Data Collection
1. **Serial COM Port Management**
   - Open/close COM port with parameters: 19200,n,8,1
   - Send/receive ASCII commands and data
   - Buffer management and clearing
   - Error handling and retry logic

2. **Photometer Command Protocol**
   - Enter/exit serial mode (SSSSSS/SEEEEE)
   - Count acquisition commands (SC, SM, SN)
   - Hardware control (SG, SH, SVIEW)
   - Acknowledgment handling (wait for "!")

3. **Data Acquisition Modes**
   - Slow mode: Single/multiple readings with 5-digit counts
   - Fast mode: Rapid sequential counts with time interpolation
   - Very Fast mode: High-speed 2-byte counts
   - Trial mode: Test readings

4. **Time Management**
   - UT time calculation from local time
   - Millisecond-precision timestamps
   - Midnight rollover handling
   - Time interpolation for fast mode

5. **Data Storage**
   - In-memory arrays for current session
   - .raw file format output with headers
   - Data formatting and validation
   - Sky background integration

#### Priority 2: Essential Configuration
1. **Settings Management**
   - COM port selection
   - Time zone offset
   - Filter configuration
   - Gain and integration time settings

2. **Object Management**
   - Load star catalogs
   - SKY background measurements
   - Object selection and tracking

3. **Basic Error Handling**
   - Communication errors
   - Data validation
   - Timeout management
   - Recovery procedures

### 5.2 SharpCap Integration Opportunities

#### Advantages of SharpCap Platform
1. **Image Acquisition:**
   - SharpCap already handles camera control
   - Photometer data can be synchronized with images
   - Real-time display of target field

2. **Target Management:**
   - Use SharpCap's plate solving for target acquisition
   - Integrate photometer readings with image metadata
   - Coordinate system already handled

3. **User Interface:**
   - Leverage SharpCap's existing UI framework
   - Add photometer control panel as plugin/extension
   - Use SharpCap's configuration management

4. **Automation:**
   - Integrate with SharpCap's sequencing
   - Use SharpCap's scripting for observation sequences
   - Coordinate mount control through SharpCap

#### Python Serial Communication
```python
# Suggested IronPython structure for COM port handling
import clr
clr.AddReference('System')
from System.IO.Ports import SerialPort

class SSPPhotometer:
    def __init__(self, port='COM1'):
        self.port = SerialPort(port, 19200, Parity.None, 8, StopBits.One)
        self.connected = False
        
    def connect(self):
        self.port.Open()
        self.port.Write("SSSSSS")
        response = self.port.ReadExisting()
        if chr(10) in response or chr(33) in response:
            self.connected = True
            return True
        return False
        
    def disconnect(self):
        if self.connected:
            self.port.Write("SEEEEE")
            self.port.Close()
            self.connected = False
            
    def get_count_slow(self, integration_ms):
        self.port.ReadExisting()  # Clear buffer
        self.port.Write("SCnnnn")
        # Wait for integration + overhead
        time.sleep((integration_ms + 150) / 1000.0)
        response = self.port.ReadExisting()
        # Parse response for count value
        return self._extract_count(response)
```

### 5.3 Simplified Architecture Recommendations

#### Modular Design
```
SSPDataq-SharpCap Integration:
├── Communication Module
│   ├── Serial port management
│   ├── Command protocol
│   └── Buffer handling
├── Data Acquisition Module
│   ├── Slow mode collection
│   ├── Fast mode collection
│   ├── Time management
│   └── Data validation
├── Configuration Module
│   ├── Settings persistence
│   ├── Filter/gain/integration setup
│   └── Catalog management
├── Data Storage Module
│   ├── In-memory arrays
│   ├── File I/O (.raw format)
│   └── Temporary data handling
└── SharpCap Interface Module
    ├── UI integration
    ├── Image synchronization
    └── Sequence coordination
```

#### Removed Complexity
For initial SharpCap development, consider excluding:
1. Telescope control (use SharpCap's mount control instead)
2. Script system (use SharpCap sequencing)
3. Flip mirror control (hardware-specific, low priority)
4. Multiple filter bar management (simplify to single bar)
5. Red night mode (SharpCap handles this)
6. Launcher program (not needed as SharpCap plugin)

#### Core Workflow Simplification
```
Simplified SharpCap Workflow:
1. Start SharpCap → Load SSP plugin
2. Configure COM port and photometer settings
3. Load target coordinates (via plate solving or manual)
4. Select filter, gain, integration time
5. Click "Acquire" to collect data
6. Data automatically saved with image metadata
7. Real-time display of counts/magnitude estimate
8. Export to .raw format for existing reduction pipeline
```

### 5.4 Critical Code Sections Reference

For implementation, focus on these LibertyBasic code sections:

**COM Port Communication:**
- Lines 863-922: [CONNECT_SERIAL]
- Lines 924-953: [DISCONNECT_SERIAL]
- Lines 2799-2825: [WaitForAck]

**Data Collection:**
- Lines 2231-2298: [Get_Counts] (slow mode)
- Lines 2326-2361: [Get_Fast_Counts] (fast mode)
- Lines 2363-2388: [Get_Very_Fast_Counts] (very fast mode)
- Lines 2301-2325: [Get_Fast_Array] (time interpolation)

**Time Management:**
- Lines 2175-2186: [FindDateTime]
- Lines 2742-2758: [UTtimeFind]
- Lines 2826-2843: SUB Pause (precise timing)

**Data Formatting:**
- Lines 2142-2163: [DisplayData]
- Lines 2434-2448: Header creation

**Configuration:**
- Lines 154-177: Read dparms.txt
- Lines 2721-2741: [SaveDparms]

---

## SECTION 6: HARDWARE INTERFACE SPECIFICATIONS

### 6.1 SSP Photometer Hardware

**Supported Models:**
- SSP-3a: Single-channel photometer with PMT detector
- SSP-5a: Single-channel photometer with improved detector options

**Detector Options:**
- Photomultiplier tube (PMT) for UBVRI
- Extended red sensitivity detectors
- Near-infrared detectors (to 1.8 microns)

**Hardware Features:**
- 6-position filter wheel (automatic)
- Optional flip mirror (automatic VIEW/RECORD switching)
- Gain control (1×, 10×, 100×)
- Integration times: 0.02s to 10s
- Serial interface (RS-232)

### 6.2 Serial Protocol Summary

**Physical Interface:**
- RS-232 serial communication
- Standard DB-9 or DB-25 connector
- 3-wire connection (TX, RX, GND)

**Electrical Parameters:**
- Baud Rate: 19200 bps
- Data Bits: 8
- Parity: None
- Stop Bits: 1
- Flow Control: None (ds0,cs0)

**Command Structure:**
- All commands start with 'S'
- Fixed-length command strings
- ASCII text protocol
- Commands terminated implicitly (no CR/LF required for sending)

**Response Format:**
- Acknowledgments: Single "!" character
- Count data: "C=XXXXX\r\n" format
- Fast data: Multiple values without delimiters
- Error conditions: No response or unexpected data

### 6.3 Command Reference Table

| Command | Parameters | Function | Response | Timing |
|---------|-----------|----------|----------|--------|
| SSSSSS | None | Enter serial mode | CR or ! | ~5s max |
| SEEEEE | None | Exit serial mode | None | Immediate |
| SCnnnn | None | Single count | C=XXXXX\r\n | Integration time + 150ms |
| SMXXXX | XXXX=count | Fast mode | Multiple values | Variable |
| SNXXXX | XXXX=count | Very fast mode | Multiple values | Variable |
| SGxxx | xxx=gain | Set gain | ! | ~1s |
| SHNNN | None | Home filter | ! | ~5s |
| SVIEWx | x=0 or 1 | Set mirror | ! | ~2s |

### 6.4 Timing Specifications

**Integration Times:**
- Minimum: 0.02 seconds (SSP-5 only)
- Standard fast: 0.05, 0.10, 0.50 seconds
- Slow: 1.0, 5.0, 10.0 seconds
- Overhead: ~150ms per slow mode reading

**Mechanical Actions:**
- Filter change: ~5 seconds (includes homing)
- Mirror flip: ~2 seconds
- Acknowledgment timeout: 5 seconds (100 × 50ms)

**Data Transfer:**
- Slow mode: 8 bytes per reading (C=XXXXX\r\n)
- Fast mode: 6 bytes per reading (including delimiters)
- Very fast mode: 2 bytes per reading (raw binary)
- Buffer size calculation: Interval × bytes_per_reading

---

## SECTION 7: CONCLUSIONS AND RECOMMENDATIONS

### 7.1 Software Architecture Summary

SSPDataq is a mature, well-structured photometry acquisition system with clear separation between:
1. **Hardware control** (serial communication, photometer commands)
2. **Data acquisition** (multiple modes for different science cases)
3. **Data management** (storage, formatting, display)
4. **Analysis pipeline** (reduction, transformation, visualization)

The software demonstrates good practices for:
- Precise timing control
- Robust error handling
- Configuration management
- Modular design

### 7.2 Redevelopment Priorities for SharpCap

**Phase 1: Core Data Collection**
Focus on replicating the COM port communication and basic slow-mode data acquisition:
- Serial port management
- Command protocol implementation
- Slow mode (1-4 readings) with proper timing
- Basic .raw file output
- Time/date management

**Phase 2: Enhanced Collection Modes**
Add fast and very fast modes:
- Buffer management for multiple readings
- Time interpolation
- Fast mode data handling

**Phase 3: SharpCap Integration**
Integrate with SharpCap ecosystem:
- Plugin/extension architecture
- Coordinate with image acquisition
- Leverage existing mount/sequence control
- Synchronized metadata

**Phase 4: Advanced Features**
Add convenience features:
- Catalog management
- Sky background automation
- Real-time magnitude estimation
- Quality indicators

### 7.3 Key Challenges for Python Implementation

1. **Serial Communication:**
   - Use System.IO.Ports (IronPython/CLR)
   - Implement proper timeout and retry logic
   - Handle buffer management carefully

2. **Timing Accuracy:**
   - IronPython timing may differ from LibertyBasic
   - Use System.Threading for precise delays
   - Verify millisecond-level accuracy for fast mode

3. **Data Integrity:**
   - Implement robust parsing of serial responses
   - Validate count values (check for ASCII 0, malformed data)
   - Handle communication errors gracefully

4. **SharpCap Threading:**
   - Coordinate with SharpCap's main thread
   - Avoid blocking UI during long integrations
   - Use background workers for data collection

### 7.4 Testing Recommendations

**Unit Testing:**
- Serial port communication (with loopback or simulator)
- Command parsing and validation
- Time calculation and conversion
- Data formatting

**Integration Testing:**
- Hardware connection and disconnection
- Data acquisition in all modes
- File I/O and data persistence
- Error recovery scenarios

**Field Testing:**
- Actual photometer hardware
- Various integration times and intervals
- Different target types (bright/faint)
- Long observation sequences
- Comparison with original SSPDataq output

### 7.5 Maintenance of Compatibility

**Data Format Compatibility:**
Maintain .raw file format to ensure compatibility with existing reduction pipeline:
- Same header structure
- Same data line format
- Same field widths and separators
- Preserve catalog codes and object naming

**Configuration Compatibility:**
Consider reading dparms.txt and PPparms3.txt for seamless transition:
- Import existing user configurations
- Maintain same parameter names and ranges
- Support existing catalog file formats

**Workflow Compatibility:**
Preserve overall workflow so users can transition smoothly:
- Similar observation sequences
- Equivalent data collection modes
- Compatible output for analysis modules

---

## APPENDIX A: File Inventory

### Source Code Files (.bas)
- SSPDataq3_3,21.bas (4128 lines) - Main acquisition program
- Reduction2,61.bas (3033 lines) - Photometry reduction
- ShowData2,62.bas (5343 lines) - Data visualization
- Data_Editor2,56.bas (790 lines) - Catalog editor
- Extinction2,56.bas - Extinction coefficient calculator
- SOE2,56.bas - Second order extinction
- Transformation2,56.bas - Transformation coefficients
- AllSky2,57.bas (1366 lines) - All-sky calibration
- SSPDataqLauncher2,56.bas (135 lines) - Program launcher

### Configuration Files (.txt)
- dparms.txt - SSPDataq configuration
- PPparms3.txt - Photometry parameters

### Catalog Files (.txt)
- Star Data Version 2.txt - Comp/Var/Check stars (Johnson/Cousins)
- Star Data Version 2 Sloan.txt - Stars (Sloan)
- FOE Data Version 2.txt - First order extinction stars
- FOE Data Version 2 Sloan.txt - FOE stars (Sloan)
- SOE Data Version 2.txt - Second order extinction stars
- Transformation Data Version 2.txt - Transformation stars
- Transformation Data Version 2 Sloan.txt - Transformation (Sloan)

### Help Files (.chm)
- SSPDataq3.chm - Main program help
- Photometry2.chm - Photometry package help
- Enter_Minima.chm - Minima entry help

### Sample Data Files (.raw)
- Sample_SOE.raw - SOE observation example
- Sample_Extinction.raw - Extinction observation example
- Sample_Transformation.RAW - Transformation observation example
- AllSky Sample.Raw - All-sky observation example
- AG PEG 11-04-2015.raw - Variable star observation example

### Other Files
- READ ME.txt - Compilation instructions
- Readme.md - Software overview
- SSP.ico - Program icon
- Period/ - Period search tools subdirectory
- HelpNDoc/ - Help file source subdirectory

---

## APPENDIX B: Key Variables and Arrays

### Global Configuration Variables
```
ComPort                 - COM port number (0-19)
CommFlag               - Connection status (0=disconnected, 1=connected)
TimeZoneDiff           - UT offset (-12 to +12)
AutoManual$            - Filter mode ("A"=auto, "M"=manual)
FilterBar              - Current filter bar (1-3)
FilterSystem$          - Filter system ("1"=Johnson/Cousins, "0"=Sloan)
NightFlag              - Screen mode (0=day, 1=night)
AutoMirrorFlag         - Mirror control (0=manual, 1=auto+confirm, 2=auto)
MirrorFlag             - Mirror position (0=view, 1=record)
TelescopeFlag          - Telescope control (0=disabled, 1=enabled)
TelescopeCOM           - Telescope COM port
TelescopeType          - Telescope model (0-4)
```

### Observation Parameters
```
Gain                   - Amplifier gain (1, 10, or 100)
GainIndex              - Gain selection index
Integ                  - Integration time (milliseconds)
IntegIndex             - Integration selection index
Interval               - Number of readings per acquisition
IntervalIndex          - Interval selection index
CountMode              - Collection mode (1=trial, 2=slow, 3=fast, 4=vfast)
Filter$                - Current filter name
FilterIndex            - Filter position
Object$                - Current object name
ObjectIndex            - Object array index
ObjectIndexMax         - Maximum objects loaded
Catalog$               - Current catalog code
```

### Data Arrays
```
Counts$(4000)          - Slow mode count values
FastCounts$(5000)      - Fast/vfast mode count values
FastTimeArray$(5000)   - Fast mode timestamps
DataArray$(4000)       - Display data array
SavedData$(4000)       - Output data array
CatalogStars$(4000)    - Loaded star names
Combo6$(4000)          - Object selection list
TypeArray$(400)        - Object types
RAArray(400)           - Right ascensions (degrees)
DECArray(400)          - Declinations (degrees)
SDitem$(4000,13)       - Star data items
Filters$(18)           - Filter names (3 bars × 6 positions)
```

### Script Variables
```
Script$(10000)         - Script command array
ScriptFlag             - Script window open (0=no, 1=yes)
ScriptHold             - Script pause status
ScriptLine             - Current script line
```

### Time/Date Variables
```
UTtime$                - UT time string (HH:MM:SS)
UTdate$                - UT date string (MM/DD/YYYY)
Days                   - Julian day number
UTtimeRecord$          - Stored start time
UTdateRecord$          - Stored start date
UTDaysRecord           - Stored Julian day
```

---

**Document End**

*This analysis document provides a comprehensive overview of the SSPDataq software system, with particular focus on the data collection functionality and COM port communication as requested. This information should serve as a foundation for redeveloping the data acquisition components using SharpCap IronPython.*
