# GOTO Functionality Implementation

## Overview
Added telescope GOTO control for SharpCap-SSP to automatically slew the telescope to selected stars from the PEP catalog. The implementation follows the occultation-manager pattern and includes proper error handling, mount settling, and manual fallback.

## Features

### 1. **Smart Target Selection**
- GOTO button slews to whichever star is currently selected in the Object dropdown
- Automatically handles variable, comparison, and check stars
- Shows confirmation dialog with star name and coordinates before slewing

### 2. **SharpCap Integration**
- Uses `SharpCap.Mounts.SelectedMount` API for mount control
- Uses `SharpCap.CoordinateParser.Parse()` for coordinate formatting
- Blocks until slew completes using `SafeGetAsyncResult()`
- Waits for mount to settle (up to 30 seconds)

### 3. **Manual GOTO Fallback**
- If no mount control available, offers manual GOTO
- Copies coordinates to clipboard for use with SharpCap Push To Assistant
- Shows formatted RA/Dec in both string and decimal formats

### 4. **Conditional UI Display**
- GOTO button only appears in SharpCap mode
- Button disabled until target is selected via "Catalog > Select Target Star"
- No errors or UI artifacts in standalone mode

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
- [x] Mount settling wait works (up to 30s)
- [x] Error handling displays meaningful messages
- [x] No errors in standalone mode

### Test Script
A comprehensive test suite is available in `test_goto.py` that verifies:
1. Module imports
2. Catalog coordinate calculations
3. SharpCap detection logic
4. Button creation conditions
5. Coordinate formatting

## Usage

### With Mount Control
1. Select target using "Catalog > Select Target Star"
2. Choose which star (var/comp/check) from Object dropdown
3. Click "GOTO Selected Star"
4. Confirm coordinates in dialog
5. Telescope slews automatically
6. Wait for mount to settle
7. Completion message appears

### Without Mount Control
1. Select target using "Catalog > Select Target Star"
2. Choose which star (var/comp/check) from Object dropdown
3. Click "GOTO Selected Star"
4. Confirm coordinates in dialog
5. Manual GOTO dialog appears
6. Coordinates copied to clipboard
7. Use SharpCap Push To Assistant to slew manually

## API Reference

### SharpCap Mount API
- `SharpCap.Mounts.SelectedMount` - Currently selected mount
- `mount.StartSlewToAsync(coordinates, token)` - Start async slew
- `SharpCap.SafeGetAsyncResult(task)` - Wait for async completion
- `mount.IsSettled` - Check if mount has stopped moving
- `SharpCap.CoordinateParser.Parse(string, bool)` - Parse coordinate string

### Coordinate Formats
- **Input to API:** `"ra_hours;dec_degrees"` (e.g., "12.5;-30.25")
- **Clipboard format:** `"ra_hours, dec_degrees"` (e.g., "12.500000, -30.250000")
- **Display format:** HMS/DMS strings from `star.ra_string()` and `star.dec_string()`

## Known Limitations
1. Requires SharpCap 4.0 or later with Mounts API
2. Mount must be connected and configured in SharpCap
3. No plate solve/sync after GOTO (could be added if needed)
4. 30-second timeout for mount settling (configurable)

## Future Enhancements
- Optional plate solve and sync after GOTO (like occultation-manager)
- Configuration option for settling timeout
- Auto-focus after GOTO
- Save last GOTO position for quick return
- Sequence automation (var → comp → check)
