# SharpCap-SSP Sequencer Development

## Automated PEP Data-Collection Runs — Implementation Plan

**Status:** Design / pre-implementation
**Target release:** v0.2.0
**Author:** pep-ssp-tools project

---

## 1. Purpose and Scope

This document specifies how to add **automated PEP data-collection runs** to
SharpCap-SSP using a **built-in sequence engine** (an in-app sequencer). It
replaces the earlier two-option evaluation: the built-in SharpCap Sequencer is
**out of scope** (see §1.3).

The desired user workflow is:

1. User **manually** connects the SSP photometer and sets the PEP filter, gain,
   integration time, interval and count mode (as today).
2. User **manually** chooses the PEP target (Var / Comp / Check triple) as today
   via `Catalog → Select Target Star`.
3. User specifies the **length of the run** — either in **minutes** or in
   **number of observations**.
4. An automated sequence then runs, for example:
   - **4a.** GOTO a specific star (e.g. Comp) with plate-solve + sync if the
     "Plate Solve and Sync" checkbox is ticked.
   - **4b.** Perform one PEP measurement.
   - **4c.** GOTO the next star (e.g. Var) and perform a PEP measurement.
   - repeat until the run length is reached.
5. Optionally insert **sky readings** (SKY / SKYNEXT / SKYLAST) between targets.
   A sky reading may be taken at the current pointing, or after a mount offset
   specified as an **RA/Dec delta** or an **offset in degrees** from the current
   target.

### 1.1 In scope

- A step/sequence model and an executor that lives inside the SharpCap-SSP
  window.
- Driving the existing GOTO + plate-solve + settle path, and the existing
  measurement logic, from a sequence.
- A minimal UI to load, run and stop a sequence; a richer builder dialog later.
- Run-length control (minutes and/or observations) and clean abort.
- Sky readings with optional RA/Dec offsets.
- Persistence of sequences and run-length defaults.

### 1.2 Out of scope

- The built-in SharpCap Sequencer and any generator for it.
- Fast / Very-Fast SSP modes (the engine drives the existing Slow/Trial paths).
- Data reduction / magnitude calculation (unchanged; that is `ssp_allsky.py`).
- Multi-target queue editing beyond the single selected Var/Comp/Check triple
  (a future extension).

### 1.3 Why the built-in SharpCap Sequencer is out of scope

The stock SharpCap Sequencer controls the camera and mount but cannot perform an
SSP photometer read or record it into SharpCap-SSP's data arrays, and it would
split the workflow across two UIs and require SharpCap Pro. An in-app engine is
self-contained, works standalone, and reuses the existing memory-tested GOTO
path verbatim.

---

## 2. Background — Current Architecture

SharpCap-SSP is an IronPython 3.4 / WinForms application that runs inside
SharpCap's scripting host (or standalone). The modules relevant to sequencing:

| File | Responsibility |
|---|---|
| `Python/main.py` | Entry point; detects the global `SharpCap`, imports `CoordinateParser`, registers the **PEP** toolbar button. |
| `Python/ssp_dataaq.py` | `SSPDataAcquisitionWindow(Form)` — the main window, the measurement routine, GOTO, target selection. |
| `Python/ssp_comm.py` | `SSPCommunicator` — serial protocol, plus the UI message-pump (`set_pump_callback` / `pump_sleep`). |
| `Python/ssp_config.py` | `SSPConfig` — JSON config in `Documents\SharpCap\SSP\ssp_config.json`. |
| `Python/ssp_catalog.py` | `StarData`, `TargetTriple`, `StarCatalog` — coordinates and RA/Dec conversions. |
| `Python/ssp_docking.py` | `DockedDataAcquisitionWindow(SSPDataAcquisitionWindow)` — subclass that adds docking without editing the base class. |
| `Python/ssp_extinction.py` | `AirmassCalculator` — Alt/Az/airmass (Hardie); used by the star dialogs and the sequence `ABORT_IF`. |
| `Python/ssp_location_utils.py` | Online city/elevation lookup for the observer-location dialog. |
| `Python/ssp_dialogs.py` | Utility dialogs (COM port, observer, filter bar, location). |

### 2.1 Reusable building blocks

| Building block | Location | Reusable for sequencing? |
|---|---|---|
| Single measurement routine | `_on_start` (`ssp_dataaq.py` ~1674-1851) | ⚠️ Only via the START button — reads the UI combos directly. **No parameterized API.** |
| Single/trial read | `_do_trial_mode` (~1853-1899) | Partially |
| GOTO + settle + plate solve | `_slew_to_star` (~2473-2573), `_wait_for_mount_settle` (~2666-2749), `_solve_and_sync_mount` (~2575-2632) | ✅ Fully reusable; already pumps the UI. |
| Object/Catalog dropdown sync | `_select_object_display` (~2244), `_star_display_name` (~2221), `_set_catalog_for_object` (~2184) | ✅ |
| Target triple (Var/Comp/Check) | `ssp_catalog.py` `TargetTriple` / `StarData` | ✅ |
| SKY / SKYNEXT / SKYLAST | `object_combo` items + `_on_start` handling (~1708) | ✅ Already valid objects. |
| UI message pump | `ssp_comm.pump_sleep` / `set_pump_callback` | ✅ Mandatory for every long wait. |
| Docked-window subclass pattern | `ssp_docking.py` | ✅ Template for adding a feature without editing the base class. |
| Config persistence | `ssp_config.py` | ✅ |
| Disabled script menu | `File → Open Script File` (`ssp_dataaq.py` ~212-214) | ✅ Hook point for a `.ssp`-style editor. |

### 2.2 Findings that shape the design

1. **Gating item.** There is no headless, parameterized "take one reading with
   *these* parameters" function. `_on_start` reads `self.filter_combo.Text`,
   `self.gain_combo.Text`, `self.integ_combo.Text`, `self.interval_combo.Text`,
   `self.mode_combo.Text`, `self.object_combo.Text` and `self.catalog_combo.Text`
   directly. The engine requires a `take_reading(object, catalog, filter, gain,
   integ, interval, mode)` method (§5).
2. **GOTO is already encapsulated.** `_slew_to_star(star, star_type)` performs
   `CoordinateParser.Parse` → `StartSlewToAsync` → `_pump_until_complete` →
   `_wait_for_mount_settle` → optional `_solve_and_sync_mount`. A sequence can
   call it directly (§9).
3. **This feature existed in the original SSPDataq.** Its `.ssp` script format
   (`LOADCATALOG`, `FILTER`, `GAIN`, `INTEG`, `INTERVAL`, `OBJECT`, `COUNT`,
   `TELESCOPE`, `PAUSE`, `END`) is documented in
   `SSPDataq/Analysis/SSPDataq_Software_Overview.md` §2.4, and the SharpCap-SSP
   `File → Open Script File` menu item is present but **disabled**.
4. **The project already planned this.** `DEVELOPMENT_NOTES.md` lists
   *"Sequence automation (auto-cycle var→comp→check)"* and *"Target queue
   system"* under Planned Features.

### 2.3 Constraints

- **Single UI thread.** The window runs on SharpCap's UI thread; every long wait
  must pump (`ssp_comm.pump_sleep`), never `time.sleep` — see
  `DEVELOPMENT_NOTES.md` §"UI Threading and the Message Pump" and
  `MEMORY_ANALYSIS.md`.
- **Guarded re-entrancy.** A pumped wait can deliver a click or a close; the
  engine needs abort/closing guards (the existing `_closing` / `_trial_busy`
  pattern).
- **Large module.** `ssp_dataaq.py` is ~165 kB; new model/executor helpers should
  live in a new `ssp_sequence.py`.
- **Output format.** Data output must stay byte-compatible with the SSPDataq
  `.raw` / `.tab` formats.

---

## 3. Requirements

### 3.1 Functional requirements

| ID | Requirement |
|---|---|
| FR-1 | After manual setup (COM port, filter/gain/integration/interval/mode) and manual target selection, the user can start an automated run. |
| FR-2 | The run length is configurable as **either** elapsed **minutes** **or** a count of **observations** (whichever limit is reached first stops the run). |
| FR-3 | A run is a configurable ordered list of **steps** (§3.2). |
| FR-4 | A step may slew to a target star (Var / Comp / Check / extinction / sky position) using the existing GOTO path, honouring the "Plate Solve and Sync" option. |
| FR-5 | A step may perform a PEP measurement and append it to the existing data arrays (`saved_data`, `saved_data_tab`, `data_listbox`) so `File → Save Data` works unchanged. |
| FR-6 | A step may take a sky reading labelled SKY / SKYNEXT / SKYLAST, either at the current pointing or after an RA/Dec or degree offset from the current target. |
| FR-7 | A step may wait a fixed time or until a specified UTC date/time. |
| FR-8 | The user can **stop** a running sequence at any time (a STOP SEQUENCE control), and closing the window aborts cleanly. |
| FR-9 | The sequence definition is persistable (saved/reloaded) between sessions, and the last-used sequence + run-length are remembered. |
| FR-10 | In standalone mode (no SharpCap), GOTO steps are skipped gracefully; the measurement steps still run. |
| FR-11 | A failed measurement or GOTO is logged and does not crash the run; communication loss aborts the run. |
| FR-12 | 2-3 built-in sequence templates are provided (e.g. `V-C-V-C`, `C-V-C`, `V-C-K`). |

### 3.2 Step vocabulary

| Step | Parameters | Behaviour |
|---|---|---|
| `GOTO` | `star_ref` = `V` / `C` / `K` / `SKY` / `OFFSET`; optional `ra`,`dec`; optional `d_ra_h`,`d_dec_deg` | Slew via `_slew_to_star`. `V/C/K` resolve against `current_target`. `OFFSET` builds a pseudo-star from the current target ± delta. |
| `MEASURE` | `object`, `catalog`, `filter`, `gain`, `integ`, `interval` | One PEP measurement via `take_reading(...)`. Missing fields inherit the current UI values. |
| `SKY` | `label` = `SKY`/`SKYNEXT`/`SKYLAST`, plus the `MEASURE` params, optional `offset` | Sky reading. If `offset` is given, slew to the offset position first. |
| `WAIT` | `seconds` | Pause (pumps the UI). |
| `WAIT_UNTIL` | `utc_datetime` (`YYYY-MM-DD HH:MM:SS`, UTC) | Pause until that UTC date/time. If it is already past by ≤ 30 min, proceed immediately with a warning; if more than 30 min past, stop the run with a warning. |
| `FILTER` | `filter` | Change filter position (auto mode). |
| `REPEAT` / `END` | `count` (or "infinite" bounded by FR-2) | Repeat the enclosed block. |
| `ABORT_IF` | `alt_below` / `airmass_above` | Stop the run if the current target violates the condition. |

### 3.3 Non-functional requirements

- **NFR-1 Threading.** The sequence runs on SharpCap's UI thread. Every long
  wait must use `ssp_comm.pump_sleep` (never `time.sleep`) so a running camera's
  frame queue drains.
- **NFR-2 Re-entrancy.** The run must carry abort/closing guards checked between
  steps and inside the count loop (the `self._closing` / `self._trial_busy`
  pattern).
- **NFR-3 No modal dialogs mid-run.** The manual-GOTO fallback and the filter
  "continue anyway?" prompt must become non-modal status messages during a run.
- **NFR-4 Theme.** New UI must use `night_mode` and respect the docked window.
- **NFR-5 Compatibility.** Data output stays byte-compatible with `.raw`/`.tab`.
- **NFR-6 Testability.** The engine and the refactored measurement path must be
  testable without a real photometer or mount (fake comm / fake SharpCap), per
  the existing `test_goto.py` pattern.
- **NFR-7 No behaviour change to START.** The manual START path must behave
  identically after the refactor.

---

## 4. Design Overview

### 4.1 Where the code lives

| File | Change |
|---|---|
| `Python/ssp_sequence.py` | **New.** `SequenceStep`, `PEPSequence`, loaders/savers, `build_templates()`. Pure data + I/O, no UI, no SharpCap. |
| `Python/ssp_dataaq.py` | Refactor `_on_start` → `take_reading` / `_collect_counts` / `_filter_position_for_name`; add the executor methods; add UI controls (menu, RUN/STOP buttons); extend `DEFAULT_CONFIG` (in `ssp_config.py`). |
| `Python/ssp_config.py` | Extend `DEFAULT_CONFIG` with sequence keys (§11). |
| `Python/ssp_dialogs.py` | Add `SequenceDialog` (Phase 3). |
| `Python/test_sequence.py` | **New.** Executor + refactor tests (§15). |
| `Python/main.py` | No change (the window is launched unchanged). |
| `SEQUENCER_DEVELOPMENT.md` | This document. |
| `README.md` / `DEVELOPMENT_NOTES.md` | Update status/feature lists once implemented. |

The engine is **added to the existing window** (not a separate docked window),
because it needs `self.comm`, `self.current_target`, `self._slew_to_star` and
`take_reading`. The model and parsing live in `ssp_sequence.py` so
`ssp_dataaq.py` only gains the executor entry points and UI wiring.

### 4.2 Data flow of a run

```
User (manual):  connect -> set filter/gain/integ/interval/mode -> select target
                         |
                         v
Run Sequence  --> run_sequence(sequence)
                         |
             +-----------+-------------------------------------------+
             |  for each pass in repeat:                             |
             |     if _sequence_should_stop(sequence): break         |
             |     for step in sequence.steps:                       |
             |        dispatch step.kind -> handler                  |
             |           GOTO    -> _slew_to_star(star, label)       |
             |           MEASURE -> take_reading(...)  (obs_count++) |
             |           SKY     -> take_reading("SKYLAST"," ",...)  |
             |           WAIT    -> ssp_comm.pump_sleep(seconds)     |
             |           ...                                         |
             +-------------------------------------------------------+
                         |
                         v
   saved_data / saved_data_tab / data_listbox  (unchanged File -> Save Data)
```

### 4.3 New instance state (`SSPDataAcquisitionWindow.__init__`)

Initialised **before** `_setup_ui()` so UI handlers can read them, following the
existing ordering of the memory-test flags:

```python
# Sequence engine state (added for automation)
self._sequence_running = False     # a run is in progress
self._sequence_abort = False       # user pressed STOP / close requested
self._sequence_obs_count = 0       # completed measurements this run
self._sequence_start = None        # DateTime.UtcNow at run start
self._sequence_step_index = 0      # for progress display
self._sequence = None              # the PEPSequence being run
```

---

## 5. Core Refactor — `take_reading`

This is the **gating item**: without a parameterized measurement method the
engine cannot record data correctly. The refactor must not change the manual
START behaviour (NFR-7).

### 5.1 Decomposition of `_on_start`

`_on_start` currently does, in order:

1. Guard `comm.is_connected`.
2. Read the UI combos (`filter/gain/integ/interval/mode/object/catalog`).
3. Resolve `star_name_map` display → actual name; set the catalog code (blank for
   SKY labels).
4. Handle `trial` mode (delegate to `_do_trial_mode`).
5. Reject modes other than `slow`.
6. `set_integration`, `set_gain`, `select_filter` (auto mode).
7. Disable START, loop `interval` × `get_slow_count` (one retry each), bin 6/8.
8. Midpoint UT, format `.raw` + `.tab` lines, append to the data arrays.

Steps 6-8 become `take_reading`; step 7's loop becomes `_collect_counts`.

### 5.2 `take_reading(...)`

```python
def take_reading(self, object_val, catalog_code, filter_val, gain_val,
                 integ_val, interval_val, mode_val="slow", append=True):
    """Perform one PEP measurement and record it.

    Extracted from _on_start so a sequence can drive it with explicit
    parameters. Reads/writes the same data arrays as _on_start, so
    File -> Save Data is unchanged. Returns (ok, data_line).
    """
    if self._closing or self._sequence_abort:
        return (False, None)

    integ_ms = int(integ_val * 1000)

    success, msg = self.comm.set_integration(integ_ms)
    if not success:
        self._update_status("Error setting integration time: " + msg)
        return (False, None)

    success, msg = self.comm.set_gain(int(gain_val))
    if not success:
        self._update_status("Error setting gain: " + msg)
        return (False, None)

    auto_manual = self.config.get('auto_manual', 'M')
    if auto_manual == 'A' and filter_val and filter_val.lower() != "home":
        position = self._filter_position_for_name(filter_val)
        if position:
            ok, retry, msg = self.comm.select_filter(position)
            if not ok:
                # Non-modal during a run (NFR-3)
                self._update_status("Warning: filter not confirmed - " + msg)

    counts, binning = self._collect_counts(integ_val, interval_val, integ_ms)
    if counts is None:                      # aborted mid-loop
        return (False, None)

    ut_start = DateTime.UtcNow
    total_sec = len(counts) * integ_val * binning
    ut_mid = ut_start.AddSeconds(int(total_sec / 2.0))
    date_s = ut_mid.ToString("MM-dd-yyyy")
    time_s = ut_mid.ToString("HH:mm:ss")
    integ_str = "%.2f" % (float(integ_val) * binning)
    gain_str = str(gain_val)

    line = self._format_data_line(date_s, time_s, catalog_code, object_val,
                                  filter_val, counts, integ_str, gain_str)
    line_tab = self._format_data_line_tab(date_s, time_s, catalog_code,
                                          object_val, filter_val, counts,
                                          integ_str, gain_str)
    if append:
        self.saved_data.append(line)
        self.saved_data_tab.append(line_tab)
        self.data_array.insert(0, line)
        self.data_listbox.Items.Insert(0, line)
    return (True, line)
```

### 5.3 `_collect_counts(...)`

Holds the count loop extracted **verbatim** from `_on_start` (including the 6/8
binning and the single retry). Returns `(counts, binning)` or `(None, 1)` when
the run is aborted. The memory-test `_closing` guards stay here so the binning
step never runs on a short list.

```python
def _collect_counts(self, integ_val, interval_val, integ_ms):
    """Collect `interval_val` slow counts; bin 6/8 to 3/4 readings.

    Extracted from _on_start. Returns (counts, binning); (None, 1) if aborted
    mid-loop (window closing or sequence abort)."""
    counts = []
    binning = 1
    if interval_val in [6, 8]:
        binning = 2

    for i in range(interval_val):
        if self._closing or self._sequence_abort:
            return (None, 1)
        success, count_str, error_msg = self.comm.get_slow_count(integ_ms)
        if success:
            counts.append(count_str)
            self._update_status("Count %d = %s" % (i + 1, count_str))
        else:
            self._update_status("Communication error - count restarted")
            success, count_str, error_msg = self.comm.get_slow_count(integ_ms)
            if success:
                counts.append(count_str)
                self._update_status("Count %d = %s" % (i + 1, count_str))
            else:
                self._update_status("Failed to get count after retry")
                counts.append("00000")

    if self._closing or self._sequence_abort:
        return (None, 1)

    if binning == 2:
        counts = [str(int(counts[i]) + int(counts[i + 1]))
                  for i in range(0, len(counts), 2)]
    return (counts, binning)
```

> **Ordering trap (preserved):** the abort check must come **before** the
> binning step, because binning indexes `counts` in pairs and a mid-loop break
> leaves a short list. The current `_on_start` documents this; the extraction
> keeps the guarantee.

### 5.4 `_filter_position_for_name(name)`

`_on_start` derives the filter position as `self.filter_combo.SelectedIndex + 1`.
`take_reading` must instead map the **name** to a position against the active
filter bar so a sequence step can name a filter directly.

```python
def _filter_position_for_name(self, filter_name):
    """Return the 1-based position of a filter on the active bar, else None."""
    try:
        bar = self.config.get('active_filter_bar', 1)
        names = self.config.get('filter_bars', [])[bar - 1]
        for i, n in enumerate(names):
            if str(n) == str(filter_name):
                return i + 1
    except Exception:
        pass
    return None
```

### 5.5 `_on_start` becomes a thin wrapper

Keep the guards, the combo reads, `star_name_map` resolution, the catalog-code
rule (blank for SKY labels), and the `trial` / non-`slow` branches; then call
`take_reading`. The START-button enable/disable and the "WAIT" label handling
stay in `_on_start`.

```python
def _on_start(self, sender, event):
    if not self.comm.is_connected:
        ...  # unchanged guard
        return
    filter_val = self.filter_combo.Text
    gain_val   = int(self.gain_combo.Text)
    integ_val  = float(self.integ_combo.Text)
    interval_val = int(self.interval_combo.Text)
    mode_val   = self.mode_combo.Text
    object_val = self.object_combo.Text
    catalog_val = self.catalog_combo.Text
    if object_val in self.star_name_map:
        object_val = self.star_name_map[object_val][0]
    catalog_code = (" " if object_val in ["SKY", "SKYNEXT", "SKYLAST"]
                    else (catalog_val[0].upper() if catalog_val else "?"))
    if mode_val.lower() == "trial":
        self._do_trial_mode(filter_val, gain_val, int(integ_val * 1000))
        return
    if mode_val.lower() != "slow":
        ...  # unchanged rejection
        return
    self.start_button.Enabled = False
    self.start_button.Text = "WAIT"
    try:
        self.take_reading(object_val, catalog_code, filter_val, gain_val,
                          integ_val, interval_val, mode_val)
    finally:
        self.start_button.Text = "START"
        self.start_button.Enabled = True
```

### 5.6 Acceptance criteria for the refactor

- START produces **identical** data lines and status text to v0.1.6 (NFR-7).
- 6/8 interval binning is unchanged.
- `take_reading` records into `saved_data`, `saved_data_tab`, `data_array` and
  `data_listbox` exactly as before.
- `take_reading` returns `(False, None)` when `_closing` / `_sequence_abort` is
  set and touches no controls in that case.
- All existing tests still pass, plus the new §15 cases 1-3.

---

## 6. Sequence Model and Formats

### 6.1 `ssp_sequence.py`

Pure data + I/O; no UI and no SharpCap import (so it is importable from tests and
from the standalone interpreter).

```python
class SequenceStep(object):
    """One step in a PEP sequence. 'kind' selects the fields used."""
    def __init__(self, kind, **kw):
        self.kind = kind.upper()        # GOTO | MEASURE | SKY | WAIT | ...
        self.params = kw                # e.g. star_ref='C', filter='V', ...

class PEPSequence(object):
    """Ordered step list plus run-length limits (FR-2)."""
    def __init__(self, name="Untitled"):
        self.name = name
        self.steps = []                 # list[SequenceStep]
        self.max_minutes = None         # FR-2 (minutes)
        self.max_observations = None    # FR-2 (observations)
        self.repeat = 1                 # wrap the whole list N times
```

### 6.2 `.ssp`-style text format (revives `File → Open Script File`)

Comma-separated `COMMAND,value`, extended from `SSPDataq_Software_Overview.md`
§2.4. Blank lines and `#` comments are ignored.

```
# PEP sequence: standard V-C-V-C with sky bookends
# WAIT_UNTIL uses an absolute UTC date/time, e.g.:
#   WAIT_UNTIL, 2026-11-27 02:45:00
MAXMINUTES, 60
REPEAT, 6
  GOTO, C
  MEASURE, filter=V, integ=5, interval=3
  GOTO, V
  MEASURE, filter=V, integ=5, interval=3
  SKY, label=SKYLAST, offset=0.0,0.25
END
```

### 6.3 JSON format (native, for the builder dialog)

Saved to `Documents\SharpCap\SSP\sequences\<name>.json`:

```json
{
  "name": "V-C-V-C with sky",
  "max_minutes": 60,
  "max_observations": null,
  "repeat": 6,
  "steps": [
    {"kind": "GOTO", "star_ref": "C"},
    {"kind": "MEASURE", "filter": "V", "integ": 5, "interval": 3},
    {"kind": "GOTO", "star_ref": "V"},
    {"kind": "MEASURE", "filter": "V", "integ": 5, "interval": 3},
    {"kind": "SKY", "label": "SKYLAST", "d_ra_h": 0.0, "d_dec_deg": 0.25}
  ]
}
```

### 6.4 Loaders / savers

| Function | Behaviour |
|---|---|
| `load_ssp_text(path)` | Parse lines → `PEPSequence`. Unknown commands raise `SequenceParseError` with the line number. `REPEAT`/`END` nest. |
| `save_ssp_text(seq, path)` | Serialise (used by "Export"). |
| `load_json(path)` / `save_json(seq, path)` | JSON round-trip; missing keys default to `None`. |
| `build_templates()` | Returns the FR-12 built-ins (`V-C-V-C`, `C-V-C`, `V-C-K`). |

Parsing rules:

- `MEASURE`/`SKY` inline `k=v` pairs are split on `,` then `=`; numeric values are
  coerced (`integ`→float, `interval`→int).
- `GOTO, C` → `star_ref='C'`; `GOTO, RA,Dec` → `ra`,`dec`; `SKY, offset=ra,dec`
  → `d_ra_h`,`d_dec_deg`.
- `WAIT_UNTIL, 2026-11-27 02:45:00` → `utc_datetime` (UTC; a space or `T`
  separator is accepted, plus an optional trailing `Z`).
- Comments/blank lines skipped; trailing whitespace trimmed.
- A malformed line raises with context so the dialog can point at it.

---

## 7. Executor

The executor lives on the window (`SSPDataAcquisitionWindow`) because it needs
`self.comm`, `self.current_target`, `self._slew_to_star`, `take_reading`, the
config and the UI. It is invoked from a **Run Sequence** button/menu item.

### 7.1 `run_sequence(sequence)`

```python
def run_sequence(self, sequence):
    """Execute a PEPSequence. Runs on the UI thread; pumps between steps."""
    if self._sequence_running:
        return                                   # re-entrancy guard
    if not self.comm.is_connected:
        self._update_status("Error: connect to the SSP before running a sequence")
        return
    if not self.current_target:
        self._update_status("Error: select a target star before running a sequence")
        return

    self._sequence_running = True
    self._sequence_abort = False
    self._sequence_obs_count = 0
    self._sequence = sequence
    self._sequence_start = DateTime.UtcNow
    self._set_sequence_controls_running(True)    # disable START/GOTO, enable STOP
    try:
        self._update_status("Sequence '%s' started" % sequence.name)
        for _ in range(max(1, sequence.repeat)):
            if self._sequence_should_stop(sequence):
                break
            self._run_step_list(sequence.steps, sequence)
    finally:
        self._sequence_running = False
        self._sequence = None
        self._set_sequence_controls_running(False)
        self._update_status("Sequence finished - %d observations"
                            % self._sequence_obs_count)
```

### 7.2 Stop conditions (`_sequence_should_stop`)

```python
def _sequence_should_stop(self, sequence):
    """FR-2 / FR-8 / FR-11: minutes limit, observation limit, abort, comm loss."""
    if self._closing or self._sequence_abort:
        return True
    if not self.comm.is_connected:
        self._update_status("Sequence aborted: SSP disconnected")
        return True
    if sequence.max_observations and \
       self._sequence_obs_count >= sequence.max_observations:
        return True
    if sequence.max_minutes:
        elapsed_min = (DateTime.UtcNow - self._sequence_start).TotalMinutes
        if elapsed_min >= sequence.max_minutes:
            return True
    return False
```

`_sequence_obs_count` increments **only** on a successful measurement, so failed
reads do not consume the observation budget (FR-2). Both limits are checked at
the same point, giving "whichever is reached first".

### 7.3 Step dispatch (`_run_step_list`)

```python
def _run_step_list(self, steps, sequence):
    """Dispatch each step; REPEAT recurses with a nested stop check."""
    i = 0
    n = len(steps)
    while i < n:
        if self._sequence_should_stop(sequence):
            return
        step = steps[i]
        self._sequence_step_index = i + 1
        self._update_step_status(sequence, step)
        kind = step.kind
        if kind == "GOTO":
            self._step_goto(step)
        elif kind == "MEASURE":
            self._step_measure(step)
        elif kind == "SKY":
            self._step_sky(step)
        elif kind == "FILTER":
            self._step_filter(step)
        elif kind == "WAIT":
            self._step_wait(step)
        elif kind == "WAIT_UNTIL":
            self._step_wait_until(step)
        elif kind == "ABORT_IF":
            if self._step_abort_if(step):
                self._sequence_abort = True
                return
        elif kind == "REPEAT":
            end = self._find_matching_end(steps, i)
            count = int(step.params.get('count', 1))
            body = steps[i + 1:end]
            for _ in range(max(1, count)):
                if self._sequence_should_stop(sequence):
                    return
                self._run_step_list(body, sequence)
            i = end
        # END is consumed by REPEAT handling; a stray END is ignored
        i += 1
```

`_find_matching_end` scans forward for the matching `END` (honouring nested
`REPEAT`s); a missing `END` is treated as end-of-list and logged.

### 7.4 Step handlers

```python
def _step_goto(self, step):
    star, label = self._resolve_step_star(step)      # V/C/K/SKY/OFFSET -> StarData
    if star is None:
        self._update_status("GOTO skipped: %s unavailable" % step.params)
        return
    ref = step.params.get('star_ref', 'V')
    if ref in ('V', 'C', 'K'):
        # Sync the Object/Catalog dropdowns (base items left untouched)
        self._select_object_display(self._star_display_name(ref))
    if not self.sharpcap_available:
        self._update_status("GOTO skipped (standalone): %s" % label)   # FR-10
        return
    self._slew_to_star(star, label, headless=True)   # pumps; honours plate solve

def _step_measure(self, step):
    p = step.params
    ok, _line = self.take_reading(
        p.get('object', self.object_combo.Text),
        p.get('catalog', self.catalog_combo.Text),
        p.get('filter', self.filter_combo.Text),
        p.get('gain', self.gain_combo.Text),
        float(p.get('integ', self.integ_combo.Text)),
        int(p.get('interval', self.interval_combo.Text)),
        self.mode_combo.Text)
    if ok:
        self._sequence_obs_count += 1
    else:
        self._update_status("Measurement step failed; continuing")

def _step_sky(self, step):
    p = step.params
    label = p.get('label', 'SKYLAST')
    # Optional offset: slew first, then read sky at that position
    if ('d_ra_h' in p) or ('d_dec_deg' in p) or ('ra' in p):
        self._step_goto(SequenceStep('GOTO', **dict(p, star_ref='OFFSET')))
    ok, _line = self.take_reading(
        label, " ",
        p.get('filter', self.filter_combo.Text),
        p.get('gain', self.gain_combo.Text),
        float(p.get('integ', self.integ_combo.Text)),
        int(p.get('interval', self.interval_combo.Text)),
        self.mode_combo.Text)
    if ok:
        self._sequence_obs_count += 1

def _step_filter(self, step):
    name = step.params.get('filter')
    if name:
        self._select_filter_by_name(name)   # sets combo + (auto) moves the bar

def _step_wait(self, step):
    ssp_comm.pump_sleep(float(step.params.get('seconds', 1)))

def _step_wait_until(self, step):
    """Wait until an absolute UTC date/time.

    The step carries a UTC datetime (YYYY-MM-DD HH:MM:SS). If the target is
    already past by <= 30 minutes, proceed immediately with a warning; if it is
    more than 30 minutes past, stop the run with a warning.
    """
    target = self._parse_utc_datetime(step.params.get('utc_datetime'))
    if target is None:
        self._update_status("WAIT_UNTIL: invalid UTC datetime; skipping step")
        return
    while True:
        if self._sequence_should_stop(self._sequence):
            return
        remaining = (target - DateTime.UtcNow).TotalSeconds
        if remaining <= 0:
            late_min = (-remaining) / 60.0
            if late_min <= 30.0:                     # <= 30 min late
                self._update_status("WAIT_UNTIL: %.1f min late; proceeding"
                                    % late_min)
                return
            self._update_status("WAIT_UNTIL: >30 min late; stopping run")
            self._sequence_abort = True
            return
        ssp_comm.pump_sleep(min(remaining, 5.0))

def _parse_utc_datetime(self, text):
    """Parse 'YYYY-MM-DD HH:MM:SS' or 'YYYY-MM-DDTHH:MM:SSZ' as UTC.

    Returns a UTC DateTime, or None if the string is missing/malformed.
    """
    if not text:
        return None
    try:
        s = str(text).strip().replace('T', ' ').rstrip('Z').strip()
        date_part, time_part = s.split(' ')
        y, mo, d = [int(x) for x in date_part.split('-')]
        hms = time_part.split(':')
        h = int(hms[0])
        mi = int(hms[1])
        sec = int(hms[2]) if len(hms) > 2 else 0
        return DateTime(y, mo, d, h, mi, sec, DateTimeKind.Utc)
    except Exception:
        return None

def _step_abort_if(self, step):
    """Return True if the run should stop (target below alt / above airmass)."""
    if not (self.current_target and self.current_target.variable):
        return False
    alt_below = step.params.get('alt_below')
    airmass_above = step.params.get('airmass_above')
    if alt_below is None and airmass_above is None:
        return False
    # Returns (has_location, alt, airmass); below-horizon -> alt is None.
    has_loc, alt, airmass = self._current_alt_airmass(self.current_target.variable)
    if not has_loc:
        self._update_status("ABORT_IF skipped: observer location not set")
        return False
    if alt is None:                                   # below horizon
        self._update_status("ABORT_IF: target below horizon")
        return True
    if alt_below is not None and alt < float(alt_below):
        self._update_status("ABORT_IF: target below altitude %.0f" % float(alt_below))
        return True
    if airmass_above is not None and airmass is not None and airmass > float(airmass_above):
        self._update_status("ABORT_IF: airmass above %.2f" % float(airmass_above))
        return True
    return False
```

`_current_alt_airmass(star)` reuses **`ssp_extinction.AirmassCalculator`** (the
class the star-selection dialogs use): build it from the configured observer
latitude/longitude and call `calculate_altaz` / `calculate_airmass` at
`DateTime.UtcNow`. It returns a 3-tuple `(has_location, alt, airmass)`:
`has_location` is `False` when the observer location is unset (0,0) so `ABORT_IF`
is skipped; when set, `alt`/`airmass` are `None` if the target is below the
horizon, which `ABORT_IF` treats as an abort.

### 7.5 Star resolution (`_resolve_step_star`)

Maps a `GOTO`/`SKY` step to a `StarData` + a human label.

```python
def _resolve_step_star(self, step):
    """Return (StarData, label) for a GOTO/OFFSET step, or (None, reason)."""
    ref = str(step.params.get('star_ref', 'V')).upper()
    if ref == 'V':
        return (self.current_target.variable, "Variable") if self.current_target else (None, "no target")
    if ref == 'C':
        c = self.current_target.comparison if self.current_target else None
        return (c, "Comparison") if c else (None, "no comparison star")
    if ref == 'K':
        k = self.current_target.check if self.current_target else None
        return (k, "Check") if k else (None, "no check star")
    if ref == 'SKY' or ref == 'OFFSET':
        if 'ra' in step.params and 'dec' in step.params:
            star = self._make_star_from_radec(step.params['ra'], step.params['dec'])
        else:
            star = self._make_offset_star(float(step.params.get('d_ra_h', 0.0)),
                                          float(step.params.get('d_dec_deg', 0.0)))
        return (star, "Sky offset") if star else (None, "no target for offset")
    return (None, "unknown star_ref")
```

### 7.6 Run pseudocode (end to end)

```
run_sequence(seq):
  guard: not running, connected, target selected
  set running/abort/obs_count/start; lock UI (STOP enabled)
  try:
    repeat times:
      if should_stop: break
      run_step_list(seq.steps)
  finally:
    clear running; unlock UI; status "finished - N observations"

run_step_list(steps):
  for each step:
    if should_stop: return
    dispatch step -> handler
      GOTO    -> resolve star; sync dropdowns; if standalone skip; else slew(headless)
      MEASURE -> take_reading(inherit UI); obs_count++
      SKY     -> optional offset slew; take_reading(label, " "); obs_count++
      WAIT    -> pump_sleep(seconds)
      REPEAT  -> find END; loop body (nested stop check)
      ABORT_IF-> evaluate alt/airmass; set abort
```

---

## 8. Sky Readings and Offsets

A sky reading is just a measurement whose object is `SKY`, `SKYNEXT` or
`SKYLAST` with a blank catalog code — `_on_start`/`take_reading` already handle
this (`catalog_code = " "` when the object is a SKY label). Two placement modes:

1. **At the current pointing** (no slew) — the simplest, and what most PEP
   observers use for a "sky last" reading at the target field:
   `SKY, label=SKYLAST, filter=V` → `take_reading("SKYLAST", " ", ...)`.
2. **At an offset position** — build a pseudo-`StarData` from the current target
   plus an RA/Dec delta, slew with `_slew_to_star`, then read.

```python
def _make_offset_star(self, d_ra_h, d_dec_deg, name="SKY-OFF"):
    """Pseudo StarData offset from the current target's variable star.

    Small offsets only: the delta is applied directly to RA hours and Dec
    degrees (precession/refraction ignored) - adequate for a sky patch a few
    tenths of a degree to a few degrees from the target. Returns None if no
    target is selected.
    """
    from ssp_catalog import StarData
    if not self.current_target or not self.current_target.variable:
        return None
    v = self.current_target.variable
    ra_h = (v.ra_hours + v.ra_minutes / 60.0 + v.ra_seconds / 3600.0 + d_ra_h) % 24.0
    dec = v.dec_degrees_decimal + d_dec_deg
    rh = int(ra_h)
    rm = int((ra_h - rh) * 60.0)
    rs = (((ra_h - rh) * 60.0) - rm) * 60.0
    sign = 1 if dec >= 0 else -1
    da = abs(dec)
    dd = int(da) * sign
    dm = int((da - abs(dd)) * 60.0)
    ds = (((da - abs(dd)) * 60.0) - dm) * 60.0
    return StarData(name=name, ra_hours=rh, ra_minutes=rm, ra_seconds=rs,
                    dec_degrees=dd, dec_minutes=dm, dec_seconds=ds)

def _make_star_from_radec(self, ra, dec, name="SKY-ABS"):
    """Pseudo StarData from explicit RA (hours) and Dec (degrees)."""
    from ssp_catalog import StarData
    rh = int(ra); rm = int((ra - rh) * 60.0); rs = (((ra - rh) * 60.0) - rm) * 60.0
    sign = 1 if dec >= 0 else -1; da = abs(dec)
    dd = int(da) * sign; dm = int((da - abs(dd)) * 60.0)
    ds = (((da - abs(dd)) * 60.0) - dm) * 60.0
    return StarData(name=name, ra_hours=rh, ra_minutes=rm, ra_seconds=rs,
                    dec_degrees=dd, dec_minutes=dm, dec_seconds=ds)
```

**Accuracy note (R2).** The offset is a simple linear RA/Dec delta; it ignores
precession, nutation and refraction and does not preserve great-circle distance
at high declination. It is intended for **small offsets** (a sky patch a few
degrees from the target). Absolute `ra`/`dec` is offered for exact placement.

---

## 9. GOTO Reuse and Headless Mode

`_slew_to_star` already performs the full sequence: `CoordinateParser.Parse` →
`StartSlewToAsync` → `_pump_until_complete` (300 s cap) → `_wait_for_mount_settle`
→ optional `_solve_and_sync_mount` (gated on the persisted `plate_solve_sync`
config). The sequence GOTO step therefore needs **no new mount code** — only the
resolver in §7.5.

### 9.1 Headless mode (NFR-3)

`_slew_to_star` currently shows a modal "Manual GOTO Required" dialog when no
mount is connected. Add a keyword so the sequence can suppress it:

```python
def _slew_to_star(self, star, star_type, headless=False):
    ...
    else:
        # No mount control
        Clipboard.SetText("%.6f, %.6f" % (ra_hours, dec_degrees))
        if headless:
            # Sequence: no modal; coordinates copied, step treated as skipped
            self._update_status("No mount: %s coordinates copied to clipboard"
                                % star.name)
            return False
        MessageBox.Show(manual_msg, "Manual GOTO Required", ...)
        return True
```

The existing callers (`_on_goto_target`, `_on_goto_stage`) keep the default
`headless=False`, so manual GOTO is unchanged.

### 9.2 Coordinate parsing

The GOTO path uses `self.CoordinateParser.Parse("%s;%s" % (ra_hours, dec_degrees),
True)`, where `ra_hours` is decimal hours and `dec_degrees` is decimal degrees.
The pseudo-stars from §8 feed the same convention, so no parser changes are
needed. If `self.CoordinateParser` is `None` (should not happen in SharpCap
mode), the step logs and skips.

### 9.3 UI locking during a run

`_set_sequence_controls_running(True)` disables START, both GOTO buttons and
RUN SEQ, and enables STOP. The per-step lock inside `_slew_to_star`
(`_set_goto_buttons_enabled`) is harmless and remains.

---

## 10. User Interface

### 10.1 Menu changes (`_setup_menu`)

- **Enable** the existing `File → Open Script File` item; wire it to load a
  `.ssp`-style sequence and open the Run dialog.
- Add a **Sequence** menu:

| Item | Action |
|---|---|
| `Run Sequence…` | Choose/pick a sequence and run it. |
| `Stop Sequence` | Set `self._sequence_abort = True`. |
| `Edit Sequence…` | Open `SequenceDialog` (Phase 3). |
| `Load Template ▸` | Submenu of the FR-12 templates. |
| `Export Sequence…` | Serialise the current sequence to `.ssp` text. |

### 10.2 Buttons

Add a **RUN SEQ** / **STOP** button pair to the right of the two GOTO buttons,
created only when the sequence feature is enabled. Position relative to
`goto_stage_button` (10 px gap), match the 30 px height, and `BringToFront()`
**after** `Controls.Add` (z-order rule from `DEVELOPMENT_NOTES.md`). Apply
`night_mode` to the new buttons.

### 10.3 `SequenceDialog` (Phase 3)

A new `Form` (in `ssp_dialogs.py` or `ssp_sequence.py`):

```
+-------------------------------------------------------------+
| Sequence: [V-C-V-C with sky      v]   [Load] [Save] [Export] |
|-------------------------------------------------------------|
| Steps:                        | Step editor                 |
|  1 GOTO    C                  |  Kind: [GOTO        v]      |
|  2 MEASURE V, 5s, x3          |  Star: [C           v]      |
|  3 GOTO    V                  |  Filter:[V] Integ:[5] Int:[3]|
|  4 MEASURE V, 5s, x3          |  dRA(h):[0.0] dDec:[0.25]   |
|  5 SKY     SKYLAST +0.25      |                             |
|  [Add][Remove][Up][Down]      |                             |
|-------------------------------------------------------------|
| Run length: minutes [60]  observations [ ]  repeat [6]      |
|                              [Run]   [Stop]   [Close]       |
+-------------------------------------------------------------+
```

- Run-length fields are the FR-2 controls (leave one blank to use only the
  other).
- `Run` builds a `PEPSequence` and calls `window.run_sequence(seq)`; `Stop` sets
  the abort flag.
- Apply `night_mode.apply_to_form(dialog)`.

### 10.4 Night mode and docking

All new controls use `night_mode` and are created before
`night_mode.apply_to_form(self)` runs (i.e. inside `_setup_ui`/`_setup_menu`), so
they inherit the current theme. The docked subclass needs no change beyond
inheriting the new buttons.

---

## 11. Persistence and Configuration

### 11.1 Sequence files

- Directory: `Documents\SharpCap\SSP\sequences\` (created on demand).
- Native format: JSON (`<name>.json`, §6.3). `.ssp` text is also loadable/exportable.
- Built-in templates are shipped in `ssp_sequence.build_templates()` (not files),
  and are copied into the directory on first "Save".

### 11.2 `ssp_config.py` `DEFAULT_CONFIG` additions

```python
# --- Sequence automation (added) ---
'last_sequence_name': '',          # last used sequence
'sequence_max_minutes': 60,        # FR-2 default (minutes)
'sequence_max_observations': 0,    # 0 = unlimited (use minutes)
'sequence_repeat': 1,              # default passes over the step list
'sequence_enable_run_button': 1,   # show the RUN SEQ button
```

`SSPConfig.load()` already merges missing keys from `DEFAULT_CONFIG`, so existing
config files upgrade cleanly with no migration step.

### 11.3 Remembering run-length

On each run, persist the effective run-length (minutes/observations/repeat) so the
next session restores it (FR-9). Guard the write so a mid-run close cannot leave
a partially written config (write only in the `finally` of `run_sequence`).

---

## 12. Standalone Behaviour

`self.sharpcap_available` is `False` without SharpCap (see `main.py`). In that
case:

- `GOTO` steps **skip** with a status message (FR-10); `_step_goto` checks
  `sharpcap_available` before calling `_slew_to_star`.
- `MEASURE`, `SKY`, `WAIT`, `WAIT_UNTIL`, `FILTER`, `REPEAT` and `ABORT_IF` run
  normally, so the engine is useful for **bench testing** with a real photometer
  but no mount.
- The `Sequence` menu and RUN/STOP buttons are created regardless; only the GOTO
  button (already SharpCap-only) is absent.

---

## 13. Detailed Design Notes

### 13.1 Threading and the pump (NFR-1)

The executor runs on SharpCap's UI thread (the window is created from
`SharpCap.AddCustomButton`). The rules from `DEVELOPMENT_NOTES.md`
§"Rules for new blocking code" apply verbatim:

1. Never `time.sleep()` in a handler — use `ssp_comm.pump_sleep()`.
2. `WAIT` / `WAIT_UNTIL` steps use `ssp_comm.pump_sleep()` in short slices.
3. Any wait that can deliver a click or a close must have a guard flag checked at
   the top of the handler and cleared in a `finally`. The sequence reuses
   `self._closing` and adds `self._sequence_abort`.

The measurement and GOTO waits already pump (they call `get_slow_count` /
`_pump_until_complete` / `_wait_for_mount_settle`), so the engine inherits safe
waits for free.

### 13.2 Abort and re-entrancy (NFR-2, FR-8)

- A **STOP SEQUENCE** button sets `self._sequence_abort = True`. The flag is
  checked in `_sequence_should_stop` (between steps), inside `_collect_counts`
  (between counts, alongside `_closing`), and before each GOTO.
- `_on_form_closing` already sets `self._closing`; the executor's checks make a
  mid-run close unwind safely. The run owns no timers or controls, so no new
  disposal path is needed.
- `self._sequence_running` blocks re-entry (a pumped click on RUN SEQ while
  running is ignored).

### 13.3 Avoiding modal dialogs (NFR-3)

| Modal prompt | Location | Sequence behaviour |
|---|---|---|
| Manual-GOTO fallback | `_slew_to_star` (no mount) | `headless=True` → status message, coordinates copied, step skipped (§9.1). |
| Filter "continue anyway?" | `_on_start` (~1755) | Not reached — `take_reading` logs a warning only (§5.2). |

### 13.4 Run-length accounting (FR-2)

- `_sequence_obs_count` increments **only** on a successful measurement, so failed
  reads do not consume the observation budget.
- The minutes limit uses `DateTime.UtcNow` deltas, consistent with the module's UT
  handling.
- Both limits are checked in `_sequence_should_stop`, giving "whichever is reached
  first" for free.

### 13.5 Progress and status

Reuse `self._update_status(...)` (refreshes + pumps). `_update_step_status` shows
`Sequence 'X' - step 3/10 - obs 12/50 - 08:14 elapsed`. Keep messages short (the
status control is single-line).

### 13.6 Error handling (FR-11)

- A failed **measurement** logs and continues.
- A failed **GOTO** logs and continues (unless the step is required — a future
  flag); a missing star skips the step.
- **Communication loss** aborts the run (`_sequence_should_stop`).
- A `SolveAndSync` failure is already non-fatal.

### 13.7 Memory

The engine reuses the pumped waits, so it does not reintroduce the frame-queue
OOM fixed in v0.1.6. Keep the existing `_print_memory_stats` /
`_log_memory_point` instrumentation active during runs (it is called inside
`take_reading`'s callees and the GOTO path) so long unattended runs remain
observable (R4).

---

## 14. Implementation Plan

Work is split into five phases. Each phase is independently shippable and has
explicit acceptance criteria. Phases 1-2 deliver the core value; 3-4 polish.

### Phase 0 — Spikes and decisions (0.5 day)

| Task | Decision |
|---|---|
| Filter→position mapping | `_filter_position_for_name` maps the **active bar** (`filter_bars[active_filter_bar-1]`) to positions 1-6; `"Home"`/unknown names → `None`. The sequence moves the bar via `comm.select_filter(position)` **directly** (never `_on_filter_changed`, which is modal), auto mode only, and also updates the visible combo with `updating_filter_combo = True`. A filter not on the active bar → warn + **skip the step**. Manual mode → recorded name only. |
| Alt/Az/airmass for `ABORT_IF` | Reuse **`ssp_extinction.AirmassCalculator`** (the class the star dialogs use), **not** `ssp_location_utils`. Unset observer location (0,0) → skip the check; below horizon → abort. |
| `WAIT_UNTIL` semantics | Absolute **UTC date and time** (`YYYY-MM-DD HH:MM:SS`). If the target is ≤ 30 min past, proceed immediately with a warning; if more than 30 min past, stop the run with a warning. |

*Acceptance:* decisions recorded here and in §16; **no code**.

### Phase 1 — Core refactor (1-1.5 days)

| Task | Detail |
|---|---|
| Extract `take_reading` | §5.2 |
| Extract `_collect_counts` | §5.3 (preserve binning + ordering trap) |
| Add `_filter_position_for_name` | §5.4 |
| Reduce `_on_start` to a wrapper | §5.5 |
| Unit tests 1-3 | §15 |

*Acceptance:* §5.6 — START output byte-identical to v0.1.6; all existing tests
pass; new tests 1-3 pass. **No UI change.**

### Phase 2 — Engine + minimal UI (2-3 days)

| Task | Detail |
|---|---|
| `ssp_sequence.py` model | §6.1 |
| `.ssp`-text + JSON loaders/savers | §6.2-6.4 |
| Executor + handlers + resolver | §7.1-7.5 |
| `headless` flag on `_slew_to_star` | §9.1 |
| Sky/offset helpers | §8 |
| Config keys | §11.2 |
| Minimal UI: enable `Open Script File`, `Sequence` menu, RUN/STOP buttons | §10.1-10.2 |
| Tests 4-13 | §15 |

*Acceptance:* a user can load a `.ssp` sequence and run it to completion; run
stops on minutes/observations/STOP; a mid-run close unwinds cleanly; GOTO steps
honour Plate Solve and Sync; standalone mode skips GOTO and still measures.

### Phase 3 — Builder dialog + templates (2-3 days)

| Task | Detail |
|---|---|
| `SequenceDialog` | §10.3 |
| `build_templates()` (FR-12) | §6.4 |
| Persist last sequence + run-length | §11.3 |
| Night-mode coverage | §10.4 |
| Tests 14 | §15 |

*Acceptance:* sequences can be created/edited/saved without hand-writing text;
templates load; the dialog respects night mode.

### Phase 4 — Polish (1-2 days)

| Task | Detail |
|---|---|
| `ABORT_IF` airmass/altitude wired to the real Alt/Az code | §7.4 |
| Optional "save `.raw` at end" (Q2) | §16 |
| Update `README.md` / `DEVELOPMENT_NOTES.md` / `QUICK_START.md` | Docs |
| Release notes + version bump to v0.2.0 | Release |

*Acceptance:* documented in `QUICK_START.md`; release zip builds via
`create_release_zip.ps1` with the new `ssp_sequence.py` and `test_sequence.py`
included.

### Dependency order

```
Phase 0 ─▶ Phase 1 ─▶ Phase 2 ─▶ Phase 3 ─▶ Phase 4
             (gating)   (engine)  (builder)  (polish)
```

Phase 1 is the hard dependency for everything else; nothing else can start until
`take_reading` exists.

---

## 15. Testing Plan

Follow the existing pattern: `test_goto.py` builds a `_FakeWindow` with fake
`SharpCap`, fake `CoordinateParser` and a fake communicator, then calls the real
methods directly. A new **`test_sequence.py`** mirrors this.

| # | Test | Verifies | Phase |
|---|---|---|---|
| 1 | `take_reading` with explicit params records a line | Refactor parity with `_on_start` (same arrays, same format) | 1 |
| 2 | `take_reading` respects `_closing` / `_sequence_abort` | NFR-2 guards | 1 |
| 3 | 6/8 interval binning unchanged | `_collect_counts` extraction is behaviour-preserving | 1 |
| 4 | Executor runs steps in order | `_run_step_list` dispatch | 2 |
| 5 | `max_observations` stops the run | FR-2 | 2 |
| 6 | `max_minutes` stops the run (fake clock) | FR-2 | 2 |
| 7 | `_sequence_abort` stops between steps | FR-8 | 2 |
| 8 | `REPEAT` nesting honours the stop check | FR-3 / inner loop bound | 2 |
| 9 | `_make_offset_star` math (RA wrap, Dec sign) | FR-6 offset correctness | 2 |
| 10 | SKY/SKYNEXT/SKYLAST produce blank catalog code | FR-6 / existing SKY handling | 2 |
| 11 | GOTO step skipped when `sharpcap_available == False` | FR-10 | 2 |
| 12 | `headless` GOTO does not raise a modal | NFR-3 | 2 |
| 13 | `.ssp`-style loader round-trips a sample file | §6.2 | 2 |
| 14 | JSON save/load round-trip | FR-9 | 3 |

Run with the existing helper:

```powershell
.\run_ipy_test.ps1 test_sequence.py
```

Tests must pass in **standalone** mode (`sharpcap_available = False`), which is
how `run_ipy_test.ps1` executes them. The fake communicator returns scripted
count strings so no hardware is needed; the fake clock lets the minutes limit be
exercised without waiting.

### 15.1 Manual test checklist (Phase 2)

- [ ] Load a `.ssp` sequence; the steps list matches the file.
- [ ] Run with a real photometer and no mount → measurements recorded, GOTO skipped.
- [ ] Run with a mount → GOTO + plate solve/sync per ticked option.
- [ ] Run-length: stops at N observations; stops after M minutes.
- [ ] STOP aborts within one step; status shows "finished".
- [ ] Close the window mid-run → clean unwind, no exception in the log.
- [ ] `File → Save Data` writes the sequence-collected rows unchanged.

---

## 16. Risks and Open Questions

| # | Risk / question | Mitigation / decision |
|---|---|---|
| R1 | `_slew_to_star` gains a parameter (signature change) | Keyword with default `False`; existing callers unchanged. |
| R2 | Offset math ignores precession/refraction; not great-circle at high Dec | Documented "small offsets only" (§8); absolute `ra`/`dec` offered. |
| R3 | A pumped wait delivering a click/close mid-run | `_sequence_running` + `_sequence_abort` + `_closing` guards (NFR-2). |
| R4 | Long unattended runs and memory | Reuses pumped waits; keeps memory instrumentation active (§13.7). |
| R5 | Modal dialogs from the GOTO path | `headless` flag (§9.1, §13.3). |
| R6 | Plate-solve every GOTO is slow | Gated by `plate_solve_sync`; per-step override is a future item. |
| R7 | `ssp_dataaq.py` is already ~165 kB / 3000+ lines | Model/parsers live in `ssp_sequence.py`; only executor entry points added to the window. |
| R8 | `WAIT_UNTIL` scheduled window already passed | Absolute UTC date/time; ≤ 30 min late → proceed with a warning; > 30 min late → stop the run with a warning. No midnight/DST ambiguity (all UTC). |
| Q1 | `WAIT_UNTIL` semantics | **Decided:** absolute UTC date/time; ≤ 30 min late → proceed with a warning; > 30 min late → stop the run with a warning. |
| Q2 | Auto-save the `.raw` file at the end of a run? | Deferred to Phase 4; reuse `_save_raw_file` behind a "save at end" flag. |
| Q3 | Per-step override of Plate Solve and Sync? | Future; the global option is used in Phase 2. |

---

## 17. Appendices

### 17.1 Proposed API surface

New methods on `SSPDataAcquisitionWindow` (`ssp_dataaq.py`):

| Method | Purpose |
|---|---|
| `take_reading(object, catalog, filter, gain, integ, interval, mode, append=True)` | One PEP measurement with explicit params (extracted from `_on_start`). |
| `_collect_counts(integ_val, interval_val, integ_ms)` | The count loop + 6/8 binning + retry, extracted. |
| `_filter_position_for_name(name)` | Map a filter name to a bar position. |
| `_select_filter_by_name(name)` | Set the filter combo (and move the bar in auto mode). |
| `run_sequence(sequence)` | Execute a `PEPSequence` (entry point). |
| `_run_step_list(steps, sequence)` | Dispatch steps (handles `REPEAT`). |
| `_sequence_should_stop(sequence)` | Minutes / observations / abort / comm check. |
| `_resolve_step_star(step)` | Map `V/C/K/SKY/OFFSET` to a `StarData` + label. |
| `_make_offset_star(d_ra_h, d_dec_deg, name)` | Build an offset pseudo-star. |
| `_make_star_from_radec(ra, dec, name)` | Build a pseudo-star from absolute RA/Dec. |
| `_step_goto/_step_measure/_step_sky/_step_filter/_step_wait/_step_wait_until/_step_abort_if` | Step handlers. |
| `_parse_utc_datetime(text)` | Parse a `YYYY-MM-DD HH:MM:SS` UTC string for `WAIT_UNTIL`. |
| `_current_alt_airmass(star)` | Returns `(has_location, alt, airmass)` via `ssp_extinction.AirmassCalculator` for `ABORT_IF`. |
| `_update_step_status(sequence, step)` | Progress line. |
| `_set_sequence_controls_running(running)` | Enable/disable START/GOTO/RUN; toggle STOP. |
| `_on_run_sequence`, `_on_stop_sequence` | UI handlers. |
| `_slew_to_star(star, star_type, headless=False)` | Existing method, new keyword. |

New module `ssp_sequence.py`:

| Symbol | Purpose |
|---|---|
| `SequenceStep` | One step (`kind` + `params`). |
| `PEPSequence` | Step list + run-length limits + repeat. |
| `SequenceParseError` | Raised by the `.ssp` loader with a line number. |
| `load_ssp_text(path)` / `save_ssp_text(seq, path)` | `.ssp`-style text I/O. |
| `load_json(path)` / `save_json(seq, path)` | JSON I/O. |
| `build_templates()` | FR-12 built-in templates. |

### 17.2 `.ssp`-style command reference (extended)

| Command | Argument | Notes |
|---|---|---|
| `MAXMINUTES` | minutes | Run-length limit (FR-2). |
| `MAXOBS` | count | Run-length limit (FR-2). |
| `REPEAT` / `END` | count | Repeat block. |
| `GOTO` | `V`/`C`/`K`/`SKY` | Slew to a target star. |
| `GOTO` | `RA,Dec` | Slew to absolute coordinates. |
| `MEASURE` | `filter=,gain=,integ=,interval=` | One measurement. |
| `SKY` | `label=,offset=ra,dec` | Sky reading (optional offset). |
| `FILTER` | filter name | Change filter (auto mode). |
| `WAIT` | seconds | Pause. |
| `WAIT_UNTIL` | `YYYY-MM-DD HH:MM:SS` (UTC) | Pause until that UTC date/time; ≤ 30 min late → proceed with a warning, > 30 min late → stop the run with a warning. |
| `ABORT_IF` | `airmass_above=`, `alt_below=` | Conditional stop. |
| `#` | comment | Ignored line. |

Original SSPDataq commands (`LOAD`, `LOADCATALOG`, `GAIN`, `INTEG`, `INTERVAL`,
`OBJECT`, `COUNT`, `MIRROR`, `PAUSE`, `TELESCOPE`, `END`) remain accepted for
backward compatibility where they map cleanly (`COUNT` → `MEASURE`, `PAUSE` →
`WAIT`, `TELESCOPE` → `GOTO`).

### 17.3 Requirement coverage

| Requirement | Covered by |
|---|---|
| FR-1 | §5 refactor + §7.1 `run_sequence` entry |
| FR-2 | §7.2 `_sequence_should_stop`, §13.4 |
| FR-3 | §6 model + formats |
| FR-4 | §7.4 `_step_goto`, §9 `_slew_to_star` reuse |
| FR-5 | §5.2 `take_reading` appends to existing arrays |
| FR-6 | §8 sky/offset |
| FR-7 | §7.4 `WAIT`/`WAIT_UNTIL`, §13.1 pump |
| FR-8 | §13.2 abort/re-entrancy |
| FR-9 | §6, §11 persistence |
| FR-10 | §12 standalone |
| FR-11 | §7.2, §13.6 error handling |
| FR-12 | §6.4 `build_templates`, §14 Phase 3 |
| NFR-1 | §13.1 |
| NFR-2 | §13.2 |
| NFR-3 | §9.1, §13.3 |
| NFR-4 | §10.4 |
| NFR-5 | §5.2 (formatting unchanged) |
| NFR-6 | §15 test plan |
| NFR-7 | §5.6 acceptance criteria |

### 17.4 Document history

| Date | Change |
|---|---|
| 2026-11-26 | Initial evaluation (two options). |
| 2026-11-26 | Refined to Option 1 only (in-app sequence engine); removed the built-in SharpCap Sequencer option; expanded design, UI, persistence and phased implementation plan. |
| 2026-11-26 | Phase 0 decisions recorded: filter mapping via `comm.select_filter` (auto only) + combo sync with `updating_filter_combo`; Alt/Az via `ssp_extinction.AirmassCalculator` (unset location → skip, below horizon → abort); `WAIT_UNTIL` uses an absolute UTC date/time (≤ 30 min late → proceed with a warning, > 30 min late → stop the run with a warning). |
















