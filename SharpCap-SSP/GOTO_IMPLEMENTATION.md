# GOTO Functionality Implementation

## Overview
Added telescope GOTO control for SharpCap-SSP to automatically slew the telescope to selected stars from the PEP catalog. The implementation follows the occultation-manager pattern and includes proper error handling, mount settling, and manual fallback.

## Features

### 1. **Smart Target Selection**
- GOTO button slews to whichever star is currently selected in the Object dropdown
- Automatically handles variable, comparison, and check stars
- Shows confirmation dialog with star name and coordinates before slewing
- Syncs the Object dropdown (and Catalog combo) to the slewed-to star (only when an actual catalog star is selected; base items like SKY/CATALOG/New Object are left untouched)

### 2. **SharpCap Integration**
- Uses `SharpCap.Mounts.SelectedMount` API for mount control
- Uses `SharpCap.CoordinateParser.Parse()` for coordinate formatting
- Blocks until slew completes using `SafeGetAsyncResult()`
- Waits for the mount to settle using the SharpCap mount helpers when present
  (`Slewing`/`IsSlewing` motion monitor then `WaitUntilSettled`), falling back to
  best-effort `IsSettled` polling for mounts that expose none of them

### 3. **Manual GOTO Fallback**
- If no mount control available, offers manual GOTO
- Copies coordinates to clipboard for use with SharpCap Push To Assistant
- Shows formatted RA/Dec in both string and decimal formats

### 4. **Conditional UI Display**
- GOTO button only appears in SharpCap mode
- Button disabled until target is selected via "Catalog > Select Target Star"
- No errors or UI artifacts in standalone mode

### 5. **Two-Stage GOTO Button (Comp -> Var)**
- Second GOTO button placed to the right of "GOTO Selected Star"
- Initially labelled "GOTO Comp": slews to the comparison star first
- After the comp slew completes it becomes "GOTO Var": slews to the variable star
- Toggles on every completed slew (Comp -> Var -> Comp ...)
- Resets to "GOTO Comp" whenever a new target star is selected
- Immediately syncs the Object dropdown (and Catalog combo) to the slewed-to star
- Both GOTO buttons are disabled for the duration of a slew (mutual lock)
- Disabled until a catalog target is selected (it needs both Comp and Var stars)
- Left disabled for extinction-star targets (no comparison star available)

### 6. **Plate Solve and Sync After GOTO**
- A "Plate Solve and Sync" checkbox sits on the "Current Target..." label row,
  left-aligned with the "GOTO Selected Star" button
- The target label was narrowed from 800 px to 390 px so the checkbox has its own
  space on that row; it uses `AutoEllipsis` so the rare over-long target line
  ends with "..." instead of hard-clipping
- When ticked, every GOTO (from "GOTO Selected Star" and the two-stage
  "GOTO Comp"/"GOTO Var" button) runs a SharpCap plate solve + sync after the
  slew completes and the mount reports settled
- The tick state is persisted in the config (`plate_solve_sync`, `0`/`1`) and
  restored on the next launch
- Skipped silently when the option is off, when the mount does not expose
  `SolveAndSync`, or when `mount.CanSync` is `False`
- A solve/sync failure is non-fatal - the GOTO has already succeeded, and the
  outcome is reported in the status line
- Because it lives in the shared `_slew_to_star` helper, both GOTO buttons pick
  up the behaviour automatically

## Implementation Details

### Imports Added
```python
import time  # For mount settling delays
from System.Threading import CancellationToken  # For async operations
```

### Key Components

#### 1. SharpCap Detection
```python
# In __init__:
self.sharpcap_available = 'SharpCap' in dir()
self.current_target = None  # Store selected target triple
```

#### 2. GOTO Button Creation
```python
# Only created if SharpCap available:
if self.sharpcap_available:
    self.goto_button = Button()
    self.goto_button.Text = "GOTO Selected Star"
    self.goto_button.Enabled = False  # Disabled until target selected
    self.goto_button.Click += self._on_goto_target
```

#### 3. Target Selection Handler
```python
def _on_select_star(self, sender, event):
    # ... dialog code ...
    if result == DialogResult.OK and dialog.selected_target:
        self.current_target = target  # Store target
        
        # Enable GOTO button
        if self.sharpcap_available and hasattr(self, 'goto_button'):
            self.goto_button.Enabled = True
```

#### 4. GOTO Implementation
```python
def _on_goto_target(self, sender, event):
    # 1. Validate environment and target
    # 2. Determine which star (var/comp/check) to slew to
    # 3. Calculate RA/Dec in decimal format
    # 4. Show confirmation dialog
    # 5. Attempt mount control OR manual fallback
    # 6. Wait for slew completion and mount settling
    # 7. Update status and show completion message
```

## Bug Fixes Applied

### Issue #1: Import Scope
**Problem:** `time` and `CancellationToken` were imported inside the function, causing potential issues.

**Fix:** Moved imports to module level:
```python
import time  # At top of file

try:
    from System.Threading import CancellationToken
except ImportError:
    CancellationToken = None  # Not available in standalone
```

### Issue #2: goto_button Reference in Standalone Mode
**Problem:** Code tried to enable `self.goto_button` even when it wasn't created (standalone mode).

**Fix:** Added hasattr check:
```python
if self.sharpcap_available and hasattr(self, 'goto_button'):
    self.goto_button.Enabled = True
```

### Issue #3: Clipboard API Reference
**Problem:** Used fully qualified name `System.Windows.Forms.Clipboard` unnecessarily.

**Fix:** Used imported name:
```python
Clipboard.SetText(...)  # Clipboard already imported via from System.Windows.Forms import *
```

### Issue #4: Missing CancellationToken Check
**Problem:** Code could crash if CancellationToken wasn't available.

**Fix:** Added validation:
```python
if CancellationToken is None:
    MessageBox.Show("GOTO functionality requires SharpCap environment.", ...)
    return
```

## Testing

### Manual Test Checklist
- [x] Button only appears in SharpCap mode
- [x] Button disabled until target selected
- [x] Button enabled after selecting target
- [x] Confirmation dialog shows correct star name and coordinates
- [x] Mount control works with connected mount
- [x] Manual GOTO fallback works when no mount
- [x] Coordinates copied to clipboard correctly
- [x] Mount settling wait works (`Slewing`/`WaitUntilSettled` then `IsSettled` fallback)
- [x] Error handling displays meaningful messages
- [x] No errors in standalone mode
- [x] "Plate Solve and Sync" checkbox sits left-aligned with "GOTO Selected Star" on the target-label row
- [x] Checkbox state persists across restarts
- [x] Tick runs plate solve/sync after each GOTO (both buttons); unticked skips it

### Test Script
A comprehensive test suite is available in `test_goto.py` that verifies:
1. Module imports
2. Catalog coordinate calculations
3. SharpCap detection logic
4. Button creation conditions
5. Coordinate formatting
6. Two-stage GOTO stage toggle/reset logic
7. Plate Solve and Sync config mapping and gate logic

## Usage

### With Mount Control
1. Select target using "Catalog > Select Target Star"
2. Choose which star (var/comp/check) from Object dropdown
3. (Optional) Tick "Plate Solve and Sync" (on the target label row)
4. Click "GOTO Selected Star"
5. Confirm coordinates in dialog
6. Telescope slews automatically
7. Wait for mount to settle
8. If "Plate Solve and Sync" is ticked, a plate solve/sync runs automatically
9. Completion message appears

### Without Mount Control
1. Select target using "Catalog > Select Target Star"
2. Choose which star (var/comp/check) from Object dropdown
3. Click "GOTO Selected Star"
4. Confirm coordinates in dialog
5. Manual GOTO dialog appears
6. Coordinates copied to clipboard
7. Use SharpCap Push To Assistant to slew manually

### Two-Stage GOTO (Comp first, then Var)
1. Select target using "Catalog > Select Target Star"
2. Click "GOTO Comp" - telescope slews to the comparison star
3. Button now reads "GOTO Var" - click again to slew to the variable star
4. After the var slew the button toggles back to "GOTO Comp"
5. Selecting a new target resets the button to "GOTO Comp"

## API Reference

### SharpCap Mount API
- `SharpCap.Mounts.SelectedMount` - Currently selected mount
- `mount.StartSlewToAsync(coordinates, token)` - Start async slew
- `SharpCap.SafeGetAsyncResult(task)` - Wait for async completion
- `mount.Slewing` / `mount.IsSlewing` - Whether the mount is still moving (optional)
- `mount.WaitUntilSettled(bool, token)` - SharpCap settle helper (optional)
- `mount.IsSettled` - Check if mount has stopped moving (optional)
- `mount.CanSync` - Whether the mount supports sync (optional)
- `mount.SolveAndSync()` - Plate solve and sync the mount (returns a task)
- `SharpCap.CoordinateParser.Parse(string, bool)` - Parse coordinate string

### Coordinate Formats
- **Input to API:** `"ra_hours;dec_degrees"` (e.g., "12.5;-30.25")
- **Clipboard format:** `"ra_hours, dec_degrees"` (e.g., "12.500000, -30.250000")
- **Display format:** HMS/DMS strings from `star.ra_string()` and `star.dec_string()`

## Known Limitations
1. Requires SharpCap 4.0 or later with Mounts API
2. Mount must be connected and configured in SharpCap
3. Plate solve/sync requires the mount to expose `SolveAndSync` and support sync
   (`CanSync`); otherwise the option is skipped with a status message
4. Settle detection is best-effort: if a mount exposes no `Slewing`/`IsSlewing`/
   `WaitUntilSettled`/`IsSettled` state, a fixed 2-second settle wait is used and
   a "settle state not confirmed" warning is reported rather than failing the GOTO
5. Motion monitor uses a 300-second cap and the fallback polling a 20-second cap

## Future Enhancements
- Configuration option for settle/motion timeouts
- Auto-focus after GOTO
- Save last GOTO position for quick return
- Sequence automation (var → comp → check)
