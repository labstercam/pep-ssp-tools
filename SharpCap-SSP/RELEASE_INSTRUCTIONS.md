# Release Package Instructions

## Creating a GitHub Release for SharpCap-SSP

### Files to Include in Release ZIP

Package the following files from `SharpCap-SSP/Python/`:

**Python Source Files:**
- main.py
- ssp_dataaq.py
- ssp_comm.py
- ssp_config.py
- ssp_dialogs.py
- ssp_catalog.py
- ssp_extinction.py
- ssp_allsky.py
- ssp_location_utils.py
- night_mode.py

**Installation & Launch Scripts:**
- install.ps1
- Launch_SSP.bat
- Create_Desktop_Shortcut.bat

**Documentation:**
- QUICK_INSTALL.txt
- SETUP.md
- README.md (copy from parent directory)

**Assets:**
- SSP.ico
- starparm_latest.csv
- first_order_extinction_stars.csv
- requirements.txt

### ZIP Structure

```
SharpCap-SSP/
├── QUICK_INSTALL.txt          <-- Read this first!
├── README.md
├── SETUP.md
├── main.py
├── ssp_dataaq.py
├── ssp_comm.py
├── ssp_config.py
├── ssp_dialogs.py
├── ssp_catalog.py
├── ssp_extinction.py
├── night_mode.py
├── SSP.ico
├── starparm_latest.csv
├── first_order_extinction_stars.csv
├── install.ps1
├── Launch_SSP.bat
├── Create_Desktop_Shortcut.bat
└── requirements.txt
```

### Creating the Release on GitHub

1. **Navigate to repository:**
   - Go to: https://github.com/labstercam/pep-ssp-tools

2. **Create new release:**
   - Click "Releases" (right sidebar)
   - Click "Create a new release"
3`
   - Target: `main` branch
   - Release title: `SharpCap-SSP v0.1.3 - First Order Extinction & Coordinate Display`

4. **Write release notes:**
   ```markdown
   # SharpCap-SSP v0.1.3 - First Order Extinction & Coordinate Display
   
   Control software for Optec SSP-3a/SSP-5a photometers with SharpCap integration.
   
   ## 🎯 Major Features in v0.1.3
   
   ### First Order Extinction Star Selection
   - ✅ **Extinction standard star catalog** - 150+ standards from Landolt, Cousins, & Graham catalogs
   - ✅ **Airmass-based filtering** - 7 preset filters (1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5) with ±0.15 tolerance
   - ✅ **Automatic filter progression** - Dialog remembers last filter and auto-advances to next on reopen
   - ✅ **Sorted by airmass** - Stars displayed from lowest to highest airmass for optimal observing
   - ✅ **Real-time calculations** - Alt/Az/Airmass computed using observer location and current UTC time
   - ✅ **Catalog integration** - Selecting extinction star sets catalog dropdown to "Foe"
   - ✅ **GOTO support** - Selected extinction stars work with telescope GOTO commands
   
   ### Coordinate Display Improvements
   - ✅ **Alt/Az columns** - Both target star and extinction star grids show altitude and azimuth
   - ✅ **Fixed azimuth calculation** - Corrected to match standard astronomical conventions and planetarium software
   - ✅ **0 decimal place formatting** - Alt/Az displayed as integers for clarity (e.g., "Alt: 61, Az: 7")
   - ✅ **Below-horizon filtering** - Stars below horizon excluded from display automatically
   
   ### Night Mode Enhancements
   - ✅ **Active filter highlighting** - Selected airmass filter button clearly indicated in both normal and night modes
   - ✅ **Dark red theme** - Active buttons use dark red background with bright red border in night mode
   - ✅ **Consistent experience** - All UI elements respect night mode settings
   
   ### Bug Fixes
   - 🐛 Fixed Alt/Az showing "?" in target star selection when coordinates present
   - 🐛 Corrected azimuth calculation for proper east/west orientation
   - 🐛 Fixed auto-filter not applying on extinction dialog open
   - 🐛 Fixed button highlighting not visible in normal and night modes
   
   ## 📋 Previous Features (v0.1.2)-3a/SSP-5a photometers with SharpCap integration.
   
   ## 🎯 Major Features in v0.1.2
   
   ### Filter Control System
   - ✅ **Automated 6-position filter slider support** - Full implementation of SHNNN (Home) and SFNNNn (Select) serial commands
   - ✅ **Manual 2-position slider support** - User prompts for manual filter changes
   - ✅ **Auto/Manual mode toggle** - Setup menu option to switch between filter control modes
   - ✅ **Hardware verification dialog** - Confirms user has automated slider before enabling Auto mode
   - ✅ **Three filter bar configuration** - 18 filter positions (3 bars × 6 positions each)
   - ✅ **Filter Bar Setup dialog** - Edit filter names with double-click, supports Johnson/Cousins and Sloan systems
   - ✅ **"Home" command** - Return filter slider to position 1 in Auto mode
   
   ### SharpCap Integration Improvements
   - ✅ **Non-modal windows** - SharpCap interface remains responsive while SSP window is open
   - ✅ **Launch window minimize/restore** - Launcher minimizes when opening SSP, restores on close
   - ✅ **Improved launcher description** - 8 bullet points highlighting key features
   - ✅ **Enhanced status messages** - Real-time filter position feedback
   
   ### Data Collection
   - ✅ **PEP star catalog integration** - 1000+ standard stars from Arne Henden's catalog
   - ✅ **Catalog search and filtering** - Find stars by name, RA/Dec, constellation
   - ✅ **SharpCap coordinate sync** - Automatically populate target from SharpCap's current pointing
   - ✅ **Slow mode data acquisition** - Scientific photometry with configurable integration times
   - ✅ **Trial mode** - Quick test counts without saving data
   - ✅ **SSPDataq-compatible .raw files** - Export for analysis with existing SSPDataq reduction tools
   
   ### Developer Features
   - ✅ **Extensive console logging** - Detailed serial communication logs for remote debugging
   - ✅ **Filter command tracing** - Step-by-step output of filter selection process
   - ✅ **Connection status tracking** - Clear indication of COM port state and command results
   
   ## Installation
   
   **Download:** [SharpCap-SSP-v0.1.2.zip](link-will-be-auto-generated)
   
   ### Quick Start:
   1. Download and extract the ZIP file
   2. Read `QUICK_INSTALL.txt` for detailed instructions
   3. Choose SharpCap integration OR standalone mode
   
   See [SETUP.md](https://github.com/labstercam/pep-ssp-tools/blob/main/SharpCap-SSP/Python/SETUP.md) for complete documentation.
   
   ## Requirements
   
   **For SharpCap Integration:**
   - SharpCap Pro 4.1+
   
   **For Standalone Mode:**
   - IronPython 3.4+
   - Windows 10/11
   
   ## What's New in v0.1.2
   
   ### Filter Control (Major Enhancement)
   - Implemented automated 6-position filter slider control via serial commands
   - Added manual mode support with user prompts
   - Created Filter Bar Setup dialog (3 bars × 6 positions = 18 filters)
   - Added Auto/Manual Filters toggle in Setup menu
   - Implemented "Home" command to return slider to position 1
   - Added hardware verification dialog when switching to Auto mode
   - Fixed critical bug: Manual mode filter selection was falling through to Auto mode logic
   - Removed redundant Auto mode check after Manual mode handler
   
   ### PEP Star Catalog
   - Integrated 1000+ standard stars from Arne Henden's PEP catalog
   - Catalog search by star name with fuzzy matching
   - Filter by RA/Dec range and constellation
   - SharpCap coordinate synchronization (populate from current telescope pointing)
   - Johnson/Cousins UBVRI and Sloan ugriz filter system support
   
   ### SharpCap Integration
   - Windows now use Show() instead of ShowDialog() to keep SharpCap responsive
   - Launch window minimizes when opening SSP Data Acquisition
   - Launch window automatically restores when SSP window closes
   - Enhanced launcher with feature bullet points
   
   ### UI/UX Improvements
   - Launch window resized: 720×525 (20% wider, 5% taller)
   - Fixed line break issues in description text (Windows CRLF)
   - Status messages updated to reflect implemented features
   - Footer label repositioned to prevent clipping
   
   ### Documentation & Debugging
   - Added comprehensive console logging for filter commands
   - Updated QUICK_START.md with filter mode configuration section
   - Enhanced FILTER_CONTROL.md with hardware detection limitations
   - Added warnings about SSP firmware acknowledging commands without hardware
   
   ## Bug Fixes
   - Fixed Manual mode filter selection handler (was missing entirely)
   - Fixed line breaks in launcher description (required \r\n for Windows TextBox)
   - Fixed footer label clipping with window resize
   - Fixed potential recursion in filter combo box event handling
   
   ## Known Limitations
   - Fast mode not yet implemented
   - Very fast mode not yet implemented
   - SSP firmware cannot detect if automated filter slider hardware is physically present
   - User must manually configure Auto/Manual mode based on their hardware
   
   ## Important Notes
   
   ### Filter Hardware Detection
   **The SSP firmware will acknowledge filter commands even if automated filter hardware is not installed.** This is a hardware/firmware limitation, not a software bug. The software cannot detect hardware presence programmatically. Users must:
   - Verify their hardware configuration (manual vs. automated slider)
   - Select the correct mode in Setup → Auto/Manual Filters
   - Visually confirm filter movement when first enabling Auto mode
   
   See [FILTER_CONTROL.md](https://github.com/labstercam/pep-ssp-tools/blob/main/SharpCap-SSP/FILTER_CONTROL.md) for complete technical documentation.
   
   ## Documentation
   - [README](https://github.com/labstercam/pep-ssp-tools/blob/main/SharpCap-SSP/README.md)
   - [Setup Guide](https://github.com/labstercam/pep-ssp-tools/blob/main/SharpCap-SSP/Python/SETUP.md)
   - [Quick Start](https://github.com/labstercam/pep-ssp-tools/blob/main/SharpCap-SSP/QUICK_START.md)
   - [Filter Control](https://github.com/labstercam/pep-ssp-tools/blob/main/SharpCap-SSP/FILTER_CONTROL.md)
   - [Star Catalog](https://github.com/labstercam/pep-ssp-tools/blob/main/SharpCap-SSP/STAR_CATALOG.md)
   ```

5. **Upload ZIP file:**
   - Create `SharpCap-SSP-v0.1.2.zip` with structure above
   - Drag and drop to "Attach binaries" section

6. **Set as latest release:**
   - Check "Set as the latest release"
   - Check "Set as a pre-release" if this is a beta/testing version
   - Click "Publish release"

### After Publishing

The release will be available at:
- Direct link: `https://github.com/labstercam/pep-ssp-tools/releases/latest`
- Download link: `https://github.com/labstercam/pep-ssp-tools/releases/download/v0.1.2/SharpCap-SSP-v0.1.2.zip`

Update README.md with this download link.

---

## Release Checklist for v0.1.2

Before creating the release, verify:

- [ ] All version numbers updated to 0.1.2 in:
  - [ ] main.py
  - [ ] ssp_dataaq.py
  - [ ] ssp_comm.py
  - [ ] ssp_config.py
  - [ ] ssp_dialogs.py
  - [ ] ssp_catalog.py
  - [ ] night_mode.py

- [ ] Filter control tested:
  - [ ] Auto mode with automated slider (if available)
  - [ ] Manual mode with user prompts
  - [ ] Home command functionality
  - [ ] Filter Bar Setup dialog
  - [ ] Auto/Manual toggle in Setup menu
  - [ ] Hardware verification dialog

- [ ] SharpCap integration tested:
  - [ ] PEP button appears in toolbar
  - [ ] Launch window minimizes when opening SSP
  - [ ] Launch window restores when SSP closes
  - [ ] SharpCap remains responsive with SSP window open
  - [ ] Coordinate sync from SharpCap works

- [ ] Documentation updated:
  - [ ] QUICK_START.md includes filter mode configuration
  - [ ] FILTER_CONTROL.md updated with hardware detection info
  - [ ] README.md reflects v0.1.2 features
  - [ ] RELEASE_INSTRUCTIONS.md has v0.1.2 notes

- [ ] Star catalog functional:
  - [ ] Search by name works
  - [ ] RA/Dec filtering works
  - [ ] Constellation filtering works
  - [ ] SharpCap coordinate populate works

- [ ] Data acquisition verified:
  - [ ] Slow mode saves .raw files correctly
  - [ ] Trial mode displays results
  - [ ] Filter changes logged to console
  - [ ] Status messages accurate

- [ ] Console logging verified:
  - [ ] Filter commands logged with details
  - [ ] Connection status visible
  - [ ] Retry attempts tracked
  - [ ] Acknowledgments reported
