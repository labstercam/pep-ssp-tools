# SharpCap-SSP Development Notes

## Running IronPython Tests

### Finding IronPython
IronPython is **not** in the system PATH. Use the helper script or search common locations:

```powershell
# Using the helper script (recommended)
.\run_ipy_test.ps1 test_goto.py

# Manual search pattern (from Launch_SSP.bat)
$ipyPaths = @(
    "C:\Program Files\IronPython 3.4\ipy.exe",
    "C:\Program Files (x86)\IronPython 3.4\ipy.exe",
    "C:\Program Files\IronPython 3.4.1\ipy.exe",
    "C:\Program Files (x86)\IronPython 3.4.1\ipy.exe",
    "$env:LOCALAPPDATA\Programs\IronPython 3.4\ipy.exe",
    "$env:USERPROFILE\AppData\Local\Programs\IronPython\ipy.exe"
)
```

### Testing Pattern
- Use `run_ipy_test.ps1` for standalone tests
- Tests run in standalone mode will show `sharpcap_available = False`
- SharpCap-specific features should gracefully degrade in standalone mode

## SharpCap Module Handling - CRITICAL

### The Problem
SharpCap is a **global object** available only in the SharpCap scripting console. When you `import` a module, that module does **NOT** have access to the SharpCap global unless you explicitly pass it.

### WRONG Approach
```python
# In ssp_dataaq.py - THIS FAILS!
def some_function():
    SharpCap.Mounts.SelectedMount  # NameError: name 'SharpCap' is not defined
```

### CORRECT Approach (Follow occultation-manager Pattern)

#### 1. Detect SharpCap in main.py
```python
# main.py - SharpCap is available as a global here
SHARPCAP_AVAILABLE = 'SharpCap' in dir()
if SHARPCAP_AVAILABLE:
    from SharpCap.Base import CoordinateParser  # Import helper classes
else:
    CoordinateParser = None
```

#### 2. Pass Objects to Modules
```python
# main.py - Pass the actual objects, not just a boolean
sharpcap_obj = SharpCap if SHARPCAP_AVAILABLE else None
coord_parser = CoordinateParser if SHARPCAP_AVAILABLE else None
ssp_dataaq.show_data_acquisition_window(sharpcap=sharpcap_obj, coordinate_parser=coord_parser)
```

#### 3. Store as Instance Variables
```python
# ssp_dataaq.py
class SSPDataAcquisitionWindow(Form):
    def __init__(self, sharpcap=None, coordinate_parser=None):
        self.SharpCap = sharpcap
        self.CoordinateParser = coordinate_parser
        self.sharpcap_available = sharpcap is not None
```

#### 4. Use Instance Variables
```python
# ssp_dataaq.py
def _on_goto_target(self, sender, event):
    # Use self.SharpCap, NOT the global SharpCap
    if hasattr(self.SharpCap, 'Mounts'):
        mount = self.SharpCap.Mounts.SelectedMount
    
    # Use self.CoordinateParser, NOT self.SharpCap.CoordinateParser
    coordinates = self.CoordinateParser.Parse(coord_string, True)
```

### SharpCap Classes That Need Importing
From `SharpCap.Base`:
- `CoordinateParser` - Parse RA/Dec coordinate strings
- `RADecPosition` - Coordinate position objects
- `Epoch` - Coordinate epoch handling

From `SharpCap.Interfaces`:
- `PlateSolvePurpose` - Plate solving options

### Why This Matters
- **Scope**: Imported modules have their own namespace
- **exec() Context**: When SharpCap runs scripts via `exec()`, globals are only in that execution context
- **Testing**: Allows standalone testing by passing `None` instead of SharpCap object

## Key Implementation Details

### Module Class Names (Use Correct Names!)
- `ssp_comm.SSPCommunicator` (NOT SSPCommunication)
- `ssp_config.SSPConfig`
- `ssp_catalog.StarCatalog`
- `night_mode.NightMode`

### WinForms Z-Order Issues
Controls added **later** appear **on top**. For overlapping controls:

```python
# Add base controls first
self.Controls.Add(self.status_text)
self.Controls.Add(self.start_button)

# Add GOTO button LAST (at end of _setup_ui) so it's on top
if self.sharpcap_available:
    self.goto_button = Button()
    # ... configure button ...
    self.goto_button.BringToFront()  # Extra insurance
    self.Controls.Add(self.goto_button)
```

### Button Positioning
```python
# Position relative to another control
start_x = self.start_button.Location.X + self.start_button.Size.Width + 10  # 10px gap
start_y = self.start_button.Location.Y
self.goto_button.Location = Point(start_x, start_y)
self.goto_button.Size = Size(150, 30)  # Match height
```

### Conditional UI Elements
Always check `sharpcap_available` before creating SharpCap-specific UI:

```python
if self.sharpcap_available:
    self.goto_button = Button()
    # ... setup ...
    self.Controls.Add(self.goto_button)

# Later, when enabling:
if self.sharpcap_available and hasattr(self, 'goto_button'):
    self.goto_button.Enabled = True
```

### Star Catalog Integration
- CSV file: `starparm_latest.csv` (304 PEP targets)
- Location: Same directory as Python scripts
- Format: 30 columns including RA/Dec, magnitudes, AAVSO IDs
- Each target has: Variable, Comparison, and Check stars

### Object Name Mapping
For differential photometry workflow (V-C-V-C-K):

```python
# Display names vs actual names
self.star_name_map = {
    "V PER": ("V PER", 'V'),              # Variable
    "APASS 001 (Comp)": ("APASS 001", 'C'), # Comparison - display has suffix
    "APASS 002 (Check)": ("APASS 002", 'K') # Check - display has suffix
}

# Strip suffixes when starting data collection
actual_name = self.star_name_map.get(display_name, (display_name, 'V'))[0]
```

### Catalog Auto-Selection
When object is selected, auto-set catalog type:

```python
def _on_object_changed(self, sender, event):
    obj_name = self.object_combo.Text
    if obj_name in self.star_name_map:
        actual_name, catalog_type = self.star_name_map[obj_name]
        self._set_catalog_for_object(catalog_type)

def _set_catalog_for_object(self, catalog_type):
    # 'V' → Var, 'C' → Comp, 'K' → Q'check
    catalog_map = {'V': 'Var', 'C': 'Comp', 'K': "Q'check"}
```

## GOTO Functionality Implementation

### Requirements
1. SharpCap 4.0+ with Mounts API
2. Mount must be connected in SharpCap
3. CoordinateParser from SharpCap.Base

### Workflow
```python
# 1. Get star coordinates
star = self.current_target.variable  # or comparison/check
ra_hours = star.ra_hours + star.ra_minutes/60.0 + star.ra_seconds/3600.0
dec_degrees = star.dec_degrees_decimal

# 2. Parse coordinates
coord_string = "%s;%s" % (ra_hours, dec_degrees)
coordinates = self.CoordinateParser.Parse(coord_string, True)

# 3. Slew using async with blocking wait
mount = self.SharpCap.Mounts.SelectedMount
self.SharpCap.SafeGetAsyncResult(mount.StartSlewToAsync(coordinates, CancellationToken()))

# 4. Wait for settling
time.sleep(2)
if not mount.IsSettled:
    wait_start = time.time()
    while not mount.IsSettled and (time.time() - wait_start) < 30:
        time.sleep(1)
```

### Manual GOTO Fallback
```python
if not self.SharpCap.Mounts.SelectedMount:
    # Copy coordinates to clipboard
    Clipboard.SetText("%.6f, %.6f" % (ra_hours, dec_degrees))
    MessageBox.Show("Use SharpCap Push To Assistant...")
```

### Two-Stage GOTO Button
A second GOTO button sits to the right of "GOTO Selected Star". It slews to the
comparison star first, then the variable star, toggling on every completed slew.

```python
# Shared slew helper - both GOTO buttons use this
def _slew_to_star(self, star, star_type):  # returns True on success, False on failure
    ...

def _on_goto_stage(self, sender, event):
    if self.auto_goto_stage == 'comp':
        star, star_type = self.current_target.comparison, "Comparison"
    else:
        star, star_type = self.current_target.variable, "Variable"
    if self._slew_to_star(star, star_type):
        # Toggle Comp <-> Var and update the button label
        ...
```

`self.auto_goto_stage` starts as `'comp'` and is reset in `_on_select_star`
whenever a new target is selected. The button is left disabled for extinction
targets (they have no comparison star).

### Object Dropdown Sync on GOTO
The GOTO buttons sync the Object dropdown (and Catalog combo) to the star being
slewed to, so the data OBJECT column and the data grid match where the scope
points. The two-stage button always syncs; "GOTO Selected Star" only syncs when
an actual catalog star is selected (base items like SKY/CATALOG/New Object are
left untouched).

```python
# _star_display_name('V'/'C'/'K') -> combo display name ("... (Comp)", "... (Check)")
# _select_object_display(name)    -> sets Object combo + syncs Catalog combo
```

**Gotcha:** `object_combo.SelectionChangeCommitted` (bound to `_on_object_changed`)
does NOT fire for programmatic `SelectedIndex` changes, so `_select_object_display`
calls `_set_catalog_for_object()` directly and guards with `self.updating_object_combo`.

### Mutual GOTO Button Lock
Both GOTO buttons are disabled for the duration of a slew so a second slew cannot
be started mid-move (the slew runs `Application.DoEvents()` via `_update_status`).

```python
self._set_goto_buttons_enabled(False)   # before the slew
try:
    ...
finally:
    self._set_goto_buttons_enabled(True)  # stage button only re-enabled if a comp star exists
```

## Testing Strategy

### test_goto.py Structure
1. **Import Tests** - Verify all modules load
2. **Catalog Tests** - Check CSV loading and coordinate calculations
3. **SharpCap Detection** - Verify standalone vs SharpCap mode
4. **Button Logic** - Confirm conditional creation
5. **Auto GOTO Stage Logic** - Verify Comp/Var toggle and reset
6. **Coordinate Formatting** - Validate format strings

### Debug Output Pattern
```python
print("DEBUG: sharpcap_available = %s" % self.sharpcap_available)
print("DEBUG: Creating GOTO button at position (%d, %d)" % (x, y))
print("DEBUG: Button visible=%s, enabled=%s" % (btn.Visible, btn.Enabled))
```

View output in SharpCap's **Scripting Console** (View menu or Ctrl+Shift+S).

## Common Gotchas

### 1. ListBox Display Issues
```python
# WRONG - scroll position retained
self.star_list.Items.Clear()
self.star_list.Items.AddRange(filtered_items)

# RIGHT - reset scroll position
self.star_list.BeginUpdate()
self.star_list.Items.Clear()
self.star_list.Items.AddRange(filtered_items)
self.star_list.TopIndex = 0  # Reset scroll!
self.star_list.EndUpdate()
```

### 2. WinForms Layout Overlap
```python
# Dock order must be REVERSE of visual order
# Bottom elements first, top elements last
self.data_listbox.Dock = DockStyle.Fill      # Add first - fills remaining
self.search_panel.Dock = DockStyle.Bottom    # Add second - bottom area
self.header_panel.Dock = DockStyle.Top       # Add last - top area
```

### 3. IronPython __file__ Detection
```python
# WRONG in exec() context
script_dir = os.path.dirname(__file__)

# RIGHT - handles both modes
if '__file__' in dir():
    script_dir = os.path.dirname(__file__)
else:
    script_dir = os.getcwd()

# Or using System.IO
script_dir = System.IO.Path.GetDirectoryName(__file__) if '__file__' in dir() else System.IO.Directory.GetCurrentDirectory()
```

### 4. Import Order Matters
```python
# Must import in this order:
import time                              # Standard library first
from System.Threading import CancellationToken  # .NET references
from System.Windows.Forms import *       # WinForms
import ssp_config                        # Local modules last
```

## File Structure
```
SharpCap-SSP/Python/
├── main.py                  # Entry point, detects SharpCap, creates launcher
├── ssp_dataaq.py           # Main data acquisition window (1600+ lines)
├── ssp_catalog.py          # Star catalog classes (StarData, TargetTriple, StarCatalog)
├── ssp_comm.py             # SSPCommunicator for serial communication
├── ssp_config.py           # SSPConfig for JSON configuration
├── ssp_dialogs.py          # Utility dialogs
├── night_mode.py           # Night mode theme manager
├── Launch_SSP.bat          # Standalone launcher (searches for ipy.exe)
├── run_ipy_test.ps1        # PowerShell helper for running tests
├── test_goto.py            # Test suite for GOTO functionality
├── test_catalog.py         # Test suite for catalog functionality
└── starparm_latest.csv     # PEP star catalog (302 targets)
```

## Quick Reference: Occultation-Manager Pattern

When in doubt, check how occultation-manager does it:
- SharpCap object passing: `main.py` → `OccultationManagerGUI.__init__(config, theme, SharpCap, PlateSolvePurpose, CoordinateParser)`
- Import pattern: `from SharpCap.Base import CoordinateParser`
- Usage: `self.coordinate_parser.Parse(...)` (stored as instance variable)

## Future Enhancements

### Planned Features
- [ ] Plate solve and sync after GOTO
- [ ] Configurable mount settling timeout
- [ ] Auto-focus after GOTO
- [ ] Sequence automation (auto-cycle var→comp→check)
- [ ] Target queue system

### Refactoring Ideas
- Extract GOTO logic into separate module
- Create base class for SharpCap-aware windows
- Add unit tests for coordinate calculations
- Create mock SharpCap object for testing

## Debugging Checklist

When GOTO button doesn't appear:
1. ✅ Check `sharpcap_available = True` in console output
2. ✅ Verify button creation debug message appears
3. ✅ Check button is added LAST in `_setup_ui()`
4. ✅ Verify `hasattr(self, 'goto_button')` before enabling
5. ✅ Check z-order with `BringToFront()`
6. ✅ Verify SharpCap object passed from main.py

When GOTO fails:
1. ✅ Check mount is connected: `SharpCap.Mounts.SelectedMount`
2. ✅ Verify CoordinateParser is not None
3. ✅ Check CancellationToken imported
4. ✅ Validate RA/Dec format: `"ra_hours;dec_degrees"`
5. ✅ Review SharpCap console for error messages

## Version History Notes

### Key Milestones
- **v0.1.0**: Initial implementation with catalog integration
- **GOTO Feature**: Added following occultation-manager pattern
  - Fixed SharpCap detection (try/except → passed object)
  - Fixed CoordinateParser access (import from SharpCap.Base)
  - Fixed button positioning (next to START button)
  - Fixed z-order issues (add button last)

### Breaking Changes
- Changed `show_data_acquisition_window()` signature to accept `sharpcap` and `coordinate_parser`
- Changed `SSPDataAcquisitionWindow.__init__()` to accept same parameters
- Must pass actual SharpCap object, not just boolean flag

## UI Threading and the Message Pump (Memory Fix)

### The Problem

Every handler in the SSP window runs on **SharpCap's UI thread** (the window is launched
from `SharpCap.AddCustomButton`). A blocking `time.sleep()` in that thread stops the
Windows message pump. If a camera is running, its frames queue up in SharpCap instead of
being released, and memory climbs until the process dies.

Measured: with SSP capturing and a camera live, private bytes grew ~0.6-0.9 MB/s. With
either one alone, memory was flat. The full record is in `MEMORY_ANALYSIS.md`.

### The Solution: a registerable pump callback

`ssp_comm.py` provides the mechanism. It deliberately does **not** import
`System.Windows.Forms`, so it can be used from a non-GUI context (standalone IronPython,
test scripts) without dragging in WinForms:

```python
# ssp_comm.py
_pump_callback = None
_pump_slice = 0.05  # seconds between pumps

def set_pump_callback(callback):
    """GUI layer supplies Application.DoEvents; None disables pumping."""
    global _pump_callback
    _pump_callback = callback

def pump_sleep(seconds, slice_seconds=None):
    """Sleep in slices, pumping UI messages between them."""
    if _pump_callback is None:
        time.sleep(seconds)          # no UI -> behave like time.sleep
        return
    _slice = _pump_slice if slice_seconds is None else slice_seconds
    remaining = seconds
    while remaining > 0:
        chunk = _slice if remaining > _slice else remaining
        time.sleep(chunk)
        remaining -= chunk
        try:
            _pump_callback()
        except Exception:
            pass                     # a pump failure must not abort the wait
```

The GUI layer registers it once, from `SSPDataAcquisitionWindow.__init__`:

```python
# ssp_dataaq.py - wrapped in a lambda on purpose
ssp_comm.set_pump_callback(lambda: Application.DoEvents())
```

> **Why the lambda?** A bare .NET static method reference (`Application.DoEvents`) is not
> reliably callable across IronPython versions. Wrapping it costs nothing and is portable.

### Which waits pump, and which do not

| Site | File | Window | Pumps? |
|---|---|---|---|
| `get_slow_count` integration wait | `ssp_comm.py` | 1.15-10.15 s per count | **yes** |
| `_read_with_timeout` polling loop | `ssp_comm.py` | up to 2 s | **yes** (throttled to `_pump_slice`) |
| `_slew_to_star` mount settle loop | `ssp_dataaq.py` | up to ~32 s | **yes** |
| Filter home / select retry pauses | `ssp_comm.py` | 2 s each | **no, deliberately** |

The filter retry pauses are left blocking because they run inside `select_filter`, which
`_on_start` calls **before** the START button is disabled. Pumping there would let a click
re-enter `_on_start` mid-command. They are error-path retries, not steady state.

### Re-entrancy: what pumping makes reachable

Because the pump can deliver a click or a close during a wait, three guards exist:

| Guard | Where | Protects against |
|---|---|---|
| `self._closing` | set in `_on_form_closing`; checked in the count loop, after the loop, and in `_do_trial_mode` | touching controls that are being disposed |
| `self._trial_busy` | set/cleared in `_do_trial_mode` with `try/finally` | a second serial transaction nesting on the same port |
| START button disabled | `_on_start`, before the count loop | re-entering the normal acquisition path |

Note the **ordering trap** in `_on_start`: the early return on `_closing` must come
*before* the binning step, because binning indexes `counts` in pairs
(`counts[i] + counts[i+1]`) and a mid-loop break leaves a short list.

### Rules for new blocking code

1. **Never** call `time.sleep()` in a UI-thread handler. Use `ssp_comm.pump_sleep()`.
2. If you add a new long wait in `ssp_comm.py`, use `pump_sleep()` or the `_pump_callback`
   throttle — do not assume a UI exists.
3. If the wait can deliver a click or a close, add a guard flag checked at the top of the
   handler, set before the wait, and cleared in a `finally`.
4. If the guard's early return skips later index-based work, make sure the skipped work
   cannot run on a partial result set.


## Contact & Resources
- Repository: labstercam/pep-ssp-tools
- Reference: occultation-manager (same patterns)
- SharpCap API: Built-in help in SharpCap scripting console
- IronPython: https://github.com/IronLanguages/ironpython3
