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
Controls added **later** sit **behind** earlier ones (`Controls.Add` appends to the
collection, and child index 0 is the front of the z-order). A later control that
overlaps an earlier one is therefore **hidden behind it** unless it is explicitly
raised.

`BringToFront()` only has an effect **after** the control has been added - called
before `Controls.Add` the control has no parent, so the call is a no-op:

```python
# Correct - raise AFTER Add
self.Controls.Add(self.goto_button)
self.goto_button.BringToFront()

# Wrong - the control has no parent yet, so this does nothing:
# self.goto_button.BringToFront()
# self.Controls.Add(self.goto_button)
```

Verified by rendering two overlapping panels: the first-added panel stays on top
until the second is explicitly `BringToFront()`-ed. Placing a control where an
earlier opaque control (e.g. `current_target_label`) overlaps it hides it
entirely - position new controls to avoid the overlap **and** raise them.

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

# 4. Wait for the mount to stop slewing and settle (_wait_for_mount_settle)
#    Layered, ported from occultation-manager; all waits pump the UI via
#    ssp_comm.pump_sleep so the running camera's frame queue drains.
if hasattr(mount, 'Slewing'):           # motion monitor (300 s cap)
    while mount.Slewing:
        ssp_comm.pump_sleep(0.25)
elif hasattr(mount, 'IsSlewing'):
    while mount.IsSlewing:
        ssp_comm.pump_sleep(0.25)

if hasattr(mount, 'WaitUntilSettled'):  # preferred, non-fatal on ambiguity
    self.SharpCap.SafeGetAsyncResult(mount.WaitUntilSettled(True, CancellationToken()))
else:                                   # best-effort fallback (20 s each)
    if hasattr(mount, 'IsSettled'):
        while not mount.IsSettled:
            ssp_comm.pump_sleep(0.25)
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

### Plate Solve and Sync After GOTO
A "Plate Solve and Sync" checkbox sits on the current-target label row,
left-aligned with the "GOTO Selected Star" button (the target label was narrowed
to 390 px to make room). When ticked,
`_slew_to_star` calls `_solve_and_sync_mount` after the mount reports settled,
which runs SharpCap's `mount.SolveAndSync()` (mirrors occultation-manager).
The tick state is stored in config as `plate_solve_sync` (`0`/`1`). The solve is
skipped when the option is off, when `SolveAndSync` is missing, or when
`CanSync` is `False`, and a failure is non-fatal.

```python
# Inside _slew_to_star, after the settle loop:
self._solve_and_sync_mount(mount, star_type, star, plate_solve)
```

**Per-step override (sequences).** A `GOTO` or `SKY` step may carry
`plate_solve=0` (or `=1`) to override the checkbox for that one slew — used to
slew to an offset/sky position quickly without a solve. `_slew_to_star` and
`_solve_and_sync_mount` take a `plate_solve` kwarg (`None` = use the checkbox,
`0` = skip, `1` = force). The flag is parsed/serialised in `ssp_sequence.py`
(`_parse_goto`, `_coerce_measure`, `_step_to_text`, `step_from_fields`,
`fields_from_step`) and forwarded by `_step_goto` / `_step_sky`:

```
GOTO, V, offset=0.0,0.25, plate_solve=0
SKY, label=SKYLAST, offset=0.0,0.25, plate_solve=0
```

Because both GOTO buttons funnel through `_slew_to_star`, the option applies to
"GOTO Selected Star" and the two-stage "GOTO Comp"/"GOTO Var" button alike.

### Mount Settle Logic
`_wait_for_mount_settle(mount)` replaces the old fixed `time.sleep(2)` + 30 s
`IsSettled` loop. Ported from occultation-manager, it waits in layers:

1. Motion monitor: poll `mount.Slewing` (else `IsSlewing`) up to 300 s so status
   stays "Slewing" until physical motion stops (the async task can complete first).
2. `mount.WaitUntilSettled(True, CancellationToken())` when available; ambiguity
   is non-fatal (`SafeGetAsyncResult`).
3. Fallback best-effort polling of `Slewing`/`IsSlewing` (20 s) then `IsSettled`
   (20 s), each reporting a warning instead of failing.
4. Last resort (no state at all): a 2 s wait.

All waits use `ssp_comm.pump_sleep` (not `time.sleep`) so SharpCap's UI message
pump keeps running and the camera's frame queue drains.

The mount async waits - the slew (`StartSlewToAsync`), `WaitUntilSettled`, and the
optional `SolveAndSync` - are pumped in 0.1 s slices by
`_pump_until_complete(task, timeout_seconds, label)` instead of a raw
`SafeGetAsyncResult`, so the screen keeps updating and the frame queue drains during
the whole GOTO/solve. It degrades to a plain block when the task has no `IsCompleted`,
stops early if `self._closing` is set, and is capped at 300 s. START is locked for the
duration (via `_set_goto_buttons_enabled`) so a pumped click cannot start an
acquisition mid-slew.

## Sequence Engine (Phases 2-4)

Automated PEP runs are driven by `ssp_sequence.py` (pure data + I/O) and an
executor on `SSPDataAcquisitionWindow` in `ssp_dataaq.py`. See
`SEQUENCER_DEVELOPMENT.md` for the full design.

### Key rules
- The executor runs on the **UI thread** and pumps between steps; every wait uses
  `ssp_comm.pump_sleep` (never `time.sleep`), so a running camera's frame queue drains.
- Guard flags: `_sequence_running` (re-entry), `_sequence_abort` (STOP), plus the
  existing `_closing`. All are checked between steps and inside the count loop.
- **Pause / Resume**: the PAUSE button (and `Sequence → Pause Sequence`) flips
  `_sequence_paused`; the hold itself happens in `_sequence_wait_if_paused`, checked
  at the top of every `_run_step_list` iteration, so the **current step completes
  first**. The hold pumps the UI (`ssp_comm.pump_sleep`) and
  `_set_sequence_controls_running` re-enables the manual **START/GOTO** buttons while
  paused, so SharpCap and the SSP interface stay usable (GOTO, filter, integration,
  START). STOP ends the run; the flag/button reset in `run_sequence`'s `finally`.
- **No modal dialogs during a run** (NFR-3): `_slew_to_star(..., headless=True)` and
  `take_reading(..., headless=True)` suppress the manual-GOTO and config-error
  dialogs; a failure logs a status line and the run continues.
- `take_reading` **coerces gain to int** (`set_gain` compares against the ints
  1/10/100). MEASURE steps inherit the current UI filter/gain/integration unless the
  step overrides them (e.g. Params = `filter=V, integ=5, interval=3, gain=10`).
- The step list is flat; `REPEAT`/`END` are markers resolved by `_find_matching_end`.
- `WAIT_UNTIL` uses an absolute **UTC date/time**; <= 30 min late proceeds with a
  warning, > 30 min late stops the run.
- `run_sequence` bounds the run: passes until a length limit, or one pass if none is
  set (avoids an unbounded loop).
- **Compulsory autosave**: `take_reading` calls `_autosave_reading`, which appends the
  line to a per-target `.raw` + `.tab` pair (`YYMMDD-HHMMSS-<target>`). It is silent
  (status line only on failure), opens/appends/closes each time (no retained buffers),
  and writes the header once per file — so it does not accumulate memory.

### Target switching & offsets
- `TARGET, <name>` / `TARGET, auid=...` loads a catalog object (and its Var/Comp/
  Check triple) mid-run via `_apply_target`, extracted from `_on_select_star` so the
  manual "Select Target Star" dialog and the step share one code path. Following
  `GOTO V/C/K`, the `MEASURE`/`SKY` defaults and `ABORT_IF` then use the new target.
- Offsets use **one syntax everywhere**: `offset=dRA,dDec` (GOTO and SKY, in the
  `.ssp` text and the editor Params box). `_resolve_step_star` applies the offset
  **on top of** the resolved star/coords via `_offset_star`, so
  `GOTO, V, offset=0,0.05` = variable star + offset. Legacy `GOTO, OFFSET,dRA,dDec`
  / `GOTO, V,dRA,dDec` still parse but are normalised to `offset=`.
- Missing `TARGET` objects: `missing_catalog_targets` warns (popup) when a `TARGET`
  step is added/edited, warns (non-blocking) on editor open / load, and the run
  pre-flight shows a 10 s `CountdownWarningDialog` (cancel aborts); `_step_target`
  skips silently at run time.
- The editor shows the selected command's **syntax and "what it does"** in a help
  panel (`SequenceDialog.COMMAND_HELP` / `_update_help`).

### UI gotcha: ComboBox.Items.Clear() blanks the text
`ComboBox.Items.Clear()` resets a WinForms ComboBox's edit text. `_refresh_sequence_list`
saves and restores the **Sequence** box text around the clear (the same pattern
`filter_combo` uses); without it the name is blanked when the editor opens and
**Save As** hits its empty-name early return — i.e. "does nothing".

### Files
- `ssp_sequence.py` — `SequenceStep`, `PEPSequence`, `.ssp`/JSON I/O,
  `step_from_fields`/`fields_from_step`, catalog-target helpers
  (`find_target_steps`, `resolve_catalog_target`, `missing_catalog_targets`),
  named storage (`save_named`, `load_named`, `list_names`, `delete_named`), templates.
- `ssp_dialogs.SequenceDialog` — the sequence editor (night-mode aware, per-command
  help panel, `CountdownWarningDialog` pre-flight, catalog validation).
- `ssp_dialogs.SequencePickerDialog` — the `Sequence → Load Sequence…` picker
  (saved sequences first, then built-in templates).
- `ssp_dataaq.py` — executor, step handlers (`_step_target`, `_offset_star`),
  `Sequence` menu (Load / Edit / Load Template / Export), RUN SEQ / STOP buttons,
  pre-flight + load warnings. `_on_load_sequence` / `_load_sequence_by_name` load a
  saved sequence (falling back to a template of the same name).
- `test_sequence.py` — regression suite (`.\run_ipy_test.ps1 test_sequence.py`).

## Testing Strategy

### test_goto.py Structure
1. **Import Tests** - Verify all modules load
2. **Catalog Tests** - Check CSV loading and coordinate calculations
3. **SharpCap Detection** - Verify standalone vs SharpCap mode
4. **Button Logic** - Confirm conditional creation
5. **Auto GOTO Stage Logic** - Verify Comp/Var toggle and reset
6. **Coordinate Formatting** - Validate format strings
7. **Plate Solve and Sync Logic** - Verify config mapping/gate and default
8. **Mount Settle Logic** - Verify branch priority (WaitUntilSettled/Slewing/IsSettled/last-resort)
9. **Task Pump Helper** - Verify `_pump_until_complete` pumps until complete, times out, falls back for unpumpable tasks, and stops on close

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
- [x] Plate solve and sync after GOTO
- [ ] Configurable mount settling timeout
- [ ] Auto-focus after GOTO
- [x] Sequence automation (auto-cycle var→comp→check) — see SEQUENCER_DEVELOPMENT.md
- [x] Mid-run catalog object switch (`TARGET` step, by name or AUID)
- [ ] Full target queue editor (ordered multi-target queue)

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
