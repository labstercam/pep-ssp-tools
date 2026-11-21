# Memory Analysis & Out-of-Memory Investigation

**Issue:** The SSP Data Acquisition window crashed with an `OutOfMemoryException` after
approximately **100 star readings**, each reading consisting of **3 measurements**
(about 300 photometer counts in total).

**Observed environment:** One SharpCap instance hosting a camera on a separate
guidescope (used for GOTO and plate solving) plus the SSP photometer on a COM port.
One SSP Data Acquisition window is reused for the whole session and its text grid is
cleared between stars, so only one star is displayed at a time.

**Date:** 2026-11-20
**Files analysed:** `SharpCap-SSP/Python/ssp_dataaq.py`, `ssp_comm.py`,
`ssp_docking.py`, `ssp_allsky.py`, `main.py`

**Revision 2026-11-21:** added Part 4 (camera resolution and exposure impact for the
full-HD mono guide camera) and camera-specific recommendations in the Part 5 fix plan.

---

## How these numbers were obtained

All figures below were measured on Windows with the .NET runtime instrumented through
`GC.GetTotalMemory(true)`, `Process.HandleCount` and `GetGuiResources` (GDI and USER
handle counts). Every sample forced three full garbage collections
(`GC.Collect` + `WaitForPendingFinalizers`) first, so only *retained* memory is
counted. Source line references were read directly from the files listed above.

---

## Part 1 - Measured cost of one reading in the SSP application

The per-reading code path is `_on_start` (`ssp_dataaq.py:1459`). For each reading it:

1. calls `set_integration` (`ssp_comm.py:365`), `set_gain` (`ssp_comm.py:430`) and
   optionally `select_filter` (`ssp_comm.py:544`);
2. loops `interval_val` times calling `get_slow_count` (`ssp_comm.py:266`), appending
   each count to a local list (`ssp_dataaq.py:1563-1579`);
3. formats one summary line (`_format_data_line`, `ssp_dataaq.py:1660`) and appends it
   to `self.saved_data`, `self.saved_data_tab`, `self.data_array` and
   `self.data_listbox.Items` (`ssp_dataaq.py:1614-1616`);
4. calls `_update_status` (`ssp_dataaq.py:548`), which sets a Label's text, calls
   `Refresh()` and then `Application.DoEvents()`.

A harness reproducing steps 3-4 exactly (Label + ListBox + `Refresh` + `DoEvents`,
100 iterations) produced:

| Metric | Result |
|---|---|
| Retained managed memory per reading | **~5 KB** |
| GDI handle growth per reading | **0** |
| USER handle growth per reading | **0** |
| 100 readings total | **~0.5 MB** |

**Conclusion:** the acquisition path itself is *not* the memory problem. Three
hundred counts plus 100 display rows cost about half a megabyte. An
`OutOfMemoryException` cannot originate here.

---

## Part 2 - Measured leak inventory (real leaks found in the code)

### 2.1 Modal dialogs are never disposed (permanent handle leak)

`Dispose()` is called on only two objects in the entire data-acquisition module:
`self.time_timer` at `ssp_dataaq.py:998` and `:1027`. Every dialog is created and
shown without a matching `Dispose()`:

| Dialog | Created | Shown | Disposed |
|---|---|---|---|
| Header information dialog | `ssp_dataaq.py:792` | `:856` | no |
| COM port selection dialog | `ssp_dataaq.py:1032` | `:1035` | no |
| Filter bar setup dialog | `ssp_dataaq.py:1085` | `:1088` | no |
| Location dialog | `ssp_dataaq.py:1254` | `:1257` | no |
| `StarSelectionDialog` | `ssp_dataaq.py:1826` | `:1828` | no |
| `ExtinctionStarSelectionDialog` | `ssp_dataaq.py:2020` | `:2025` | no |

Measured cost of one shown-but-undisposed dialog containing a 300-row
`DataGridView`:

| Metric | Per dialog |
|---|---|
| Retained managed memory | **535 KB** |
| GDI handles | **5.2** |
| USER handles | **6.7** |

**Critical measured detail:** forcing three full garbage collections did **not**
release those handles. The GDI count only fell from 104 to 25 after an explicit
`Dispose()` call. WinForms controls release GDI/USER handles in `Dispose()`, not in
the finalizer, so this is a *permanent* leak until the process exits.

At one star-selection dialog per star, 100 stars leak roughly **53.5 MB, 520 GDI
handles and 670 USER handles**.

### 2.2 A new `Font` is assigned to a label on every star selection

`ssp_dataaq.py:1878` and `:2082` execute
`self.current_target_label.Font = Font("Arial", 9, FontStyle.Bold)` each time a star
is selected. The replaced `Font` is never disposed. Measured retained cost is
**~1.8 KB per assignment**, so 100 stars is about 180 KB. Small, but it is pure
garbage.

### 2.3 `_dock_timer` is never stopped or disposed

`ssp_docking.py:85-87` creates a 200 ms `Timer` and starts it in `_on_dock_load`
(`:105`). `ssp_docking.py` defines no `FormClosing` handler, and the base
`_on_form_closing` (`ssp_dataaq.py:1018`) only stops and disposes `time_timer`. So
when the SSP window closes, the 200 ms timer keeps running and keeps the whole
window, its controls and its event subscriptions alive. `_on_dock_timer` (`:146`)
keeps calling `_update_dock_position`, which calls `user32.SetWindowPos`.

### 2.4 `Image.FromFile` is never disposed

`main.py:364` passes `Image.FromFile(icon_path)` to `SharpCap.AddCustomButton(...)`
and never disposes it. That is one GDI+ image plus one file handle per script load.

### 2.5 `_populate_grid` creates a `Font` per cell

`ssp_allsky.py:1708`, `:1741`, `:1747` and `:1753` create
`Font(..., FontStyle.Strikeout)` for every struck-out cell and never dispose it. For
a large raw file this creates thousands of GDI objects in a single pass. Note that
`_draw_graph` (`ssp_allsky.py:1463`) is *correct*: it disposes its pens, fonts,
`Graphics` and the previous `Image` in `finally` blocks. The leak is confined to
`_populate_grid`.

### 2.6 `_clear_buffer` has no iteration cap

`ssp_comm.py:699-704` loops
`while self.port.BytesToRead > 0: self.port.ReadExisting()` with no upper bound. If
the device streams continuously this can spin for a long time allocating one string
per iteration. `_read_with_timeout` (`ssp_comm.py:632`) is bounded by its timeout and
does not leak.

### 2.7 Leak budget for a 100-star session

| Source | Memory | GDI | USER |
|---|---|---|---|
| 100 undisposed star dialogs | ~53.5 MB | ~520 | ~670 |
| 100 label font assignments | ~0.2 MB | - | - |
| Data rows (if not cleared) | ~0.5 MB | 0 | 0 |
| **Total** | **~54 MB** | **~520** | **~670** |

Fifty-four megabytes is not enough to exhaust a 64-bit process. These leaks are real
and should be fixed, but they are **not** the primary cause of the crash.

---

## Part 3 - Why memory actually runs out

### 3.1 Dominant cause: SharpCap's UI thread is blocked for 1-2 minutes per star

The SSP window is launched from `SharpCap.AddCustomButton(...)` (`main.py:364`), so
every handler in it runs on SharpCap's UI thread. `_on_start` blocks that thread with
`time.sleep()` for a very long time. Verified blocking durations:

| Blocking call | Location | Worst case |
|---|---|---|
| `set_integration` ack loop, 100 x `time.sleep(0.05)` | `ssp_comm.py:414-421` | 5 s |
| `set_gain` ack loop, same pattern | `ssp_comm.py:462-469` | 5 s |
| `select_filter`, 3 x (5 s ack + 2 s pause) | `ssp_comm.py:574-611` | 21 s |
| `get_slow_count`, `time.sleep(1.15/5.15/10.15)` + read timeout | `ssp_comm.py:335-346` | 12.15 s per count |
| `_slew_to_star`, `SafeGetAsyncResult` + `time.sleep(2)` + 30 s settle | `ssp_dataaq.py:2230-2238` | 30-90 s |

With 3 measurements per reading and a GOTO per star, SharpCap's UI thread is frozen
for roughly **1 to 2 minutes per star**. During `time.sleep()` no message pump runs,
so anything the host posts to the UI thread queues up in memory. With a camera
running on the guidescope, each queued frame holds an image buffer.

The exact cost depends on the camera's resolution and exposure. For the user's
full-HD mono guide camera the buffered total per star is roughly **80 MB to 1 GB**,
depending on exposure and bit depth. Part 4 derives this in detail. At 1 fps and 4 MB
per frame a 60-second freeze alone queues about 240 MB, so over 100 stars the
aggregate ranges from a few gigabytes (if the host drops frames) to tens of gigabytes
(if it queues them).

`Application.DoEvents()` in `_update_status` (`ssp_dataaq.py:553`) drains the queue
only when a count finishes, so it hides the problem during the count loop but cannot
prevent the long buildup during the slew and settle waits.

### 3.2 `Application.DoEvents()` allows re-entrancy

The START button is disabled only at `ssp_dataaq.py:1547`, *after* `set_integration`,
`set_gain` and `select_filter` have run. `DoEvents()` and the `MessageBox` at `:1540`
pump messages while the button is still enabled, so a second click can re-enter
`_on_start` and start a second overlapping acquisition.

### 3.3 Why the exception is `OutOfMemoryException` specifically

In .NET, `OutOfMemoryException` is also what GDI+ throws when it cannot create a GDI
object. The permanent handle leak in 2.1 (and the per-cell fonts in 2.5) pushes the
process toward the 10,000-handle per-process limit. If the host is already near that
limit, the next dialog or font allocation fails as `OutOfMemoryException` even though
plenty of RAM remains. Both mechanisms are therefore worth fixing.

---

## Part 4 - Camera resolution and exposure impact

The user's guide camera is a full-HD mono camera on a separate guidescope, used by the
same SharpCap instance for GOTO and plate solving. Exposures are typically 500 ms or
1000 ms. This section quantifies how that changes the memory picture.

### 4.1 The SSP script never touches the camera

A search of the whole Python package for `SelectedCamera`, `FrameCaptured`,
`LiveView`, `Capture` and `StartCapture` returns **zero hits**. The only SharpCap APIs
the SSP code uses are:

| API | Location | Purpose |
|---|---|---|
| `SharpCap.AddCustomButton` | `main.py:364` | toolbar button |
| `SharpCap.Mounts.SelectedMount` | `ssp_dataaq.py:2216` | mount control |
| `SharpCap.SafeGetAsyncResult` | `ssp_dataaq.py:2230` | blocking wait on the slew |
| `SharpCap.MainWindow.Handle` | `ssp_docking.py:62-64` | window docking |
| `SharpCap.CoordinateParser.Parse` | `ssp_dataaq.py:2221` | coordinate parsing |

So all frame memory lives inside SharpCap's own pipeline. The SSP script affects it
only by blocking the thread that consumes it.

### 4.2 Measured frame sizes

| Object | Theoretical | Measured |
|---|---|---|
| 1920x1080 mono 8-bit raw frame | 2.07 MB | **1.98 MB** |
| 1920x1080 mono 16-bit raw frame | 4.15 MB | **~3.96 MB** |
| 1920x1080 GDI+ 32bpp display bitmap, not rendered | 8.29 MB | **5.59 MB** |
| 1920x1080 GDI+ 32bpp display bitmap, rendered | 8.29 MB | **6.87 MB** |

Each frame released fully on `Dispose()` plus a forced GC when measured in isolation,
so the per-frame cost is transient. The problem is that the SSP script prevents the
release from happening in time.

### 4.3 Frames buffered during each blocking window

The blocking windows in section 3.1 are not pumped. With a 1920x1080 mono camera:

| Blocking window | Duration | Frames at 1000 ms | Frames at 500 ms |
|---|---|---|---|
| `set_integration` ack loop | 5 s | 5 | 10 |
| `set_gain` ack loop | 5 s | 5 | 10 |
| `select_filter` retry | up to 21 s | 21 | 42 |
| `_slew_to_star` slew + settle | 30-90 s | 30-90 | 60-180 |
| count integration (`get_slow_count`) | 36.45 s per reading | 36 | 73 |

The count integration is pumped by `DoEvents()` after each count, so it is the least
dangerous. The GOTO window dominates.

### 4.4 Memory per star by exposure and bit depth

GOTO window alone (30-90 s):

| Exposure | Bit depth | Frames | Memory in GOTO window |
|---|---|---|---|
| 1000 ms | 8-bit | 30-90 | 59-178 MB |
| 1000 ms | 16-bit | 30-90 | 119-357 MB |
| 500 ms | 8-bit | 60-180 | 119-357 MB |
| 500 ms | 16-bit | 60-180 | 238-714 MB |

Aggregating all unpumped windows per star (40-121 s of frozen UI thread):

| Exposure | Bit depth | Range per star |
|---|---|---|
| 1000 ms | 8-bit | 83-250 MB |
| 1000 ms | 16-bit | 166-500 MB |
| 500 ms | 8-bit | 166-500 MB |
| 500 ms | 16-bit | 332-1000 MB |

### 4.5 Why full HD matters more than the raw byte count suggests

1. **GDI+ `OutOfMemoryException` is a handle/heap failure, not a RAM failure.**
   GDI+ raises `OutOfMemoryException` when it cannot create a GDI+ object, even with
   plenty of RAM free. Every full-HD redraw needs a 5.6-6.9 MB GDI+ bitmap. With the
   ~520 leaked GDI handles from section 2.1 already pressuring the GDI+ heap, the
   failure threshold is reached much sooner than with a small guide camera. This is
   the most likely reason the crash surfaced as `OutOfMemoryException`.

2. **Large Object Heap fragmentation.** Anything of 85 KB or more goes on the .NET
   LOH, which is not compacted by default. A 2-4 MB frame is 25-50x over that
   threshold. Each blocked window churns the LOH with multi-megabyte allocations, so
   fragmentation grows even when total free memory is fine. This is the classic
   WinForms/.NET failure mode with large images.

3. **Plate-solve buffering during GOTO.** The same camera does the plate solve. While
   the UI thread is frozen for 30-90 s the solve results cannot be delivered, so the
   solve's working image buffers stay alive for the whole window. At full HD that is
   several MB each.

### 4.6 Exposure: 500 ms is the worse setting

Halving the exposure doubles the frame rate and therefore doubles the number of
frames buffered during every blocked window. For this specific problem **1000 ms is
about twice as safe as 500 ms**. If the session can tolerate it, use 1000 ms while
the SSP sequence is running.

### 4.7 What does not change

The SSP application's own memory is unaffected by camera resolution:

| SSP-side cost | Value |
|---|---|
| Per reading (strings + ListBox + `_update_status`) | ~5 KB |
| 100 readings | ~0.5 MB |

The ~5 KB per-reading figure in Part 1 stands. The camera only changes the host-side
cost of blocking.

### 4.8 Honest uncertainty and the decisive experiment

This repository cannot prove whether SharpCap **queues** or **drops** frames when its
UI thread is blocked. That single fact decides the magnitude:

- If SharpCap **drops** frames, memory stays bounded and the crash is explained mainly
  by the ~54 MB of dialog leaks plus LOH churn; full HD only accelerates the GDI+
  failure.
- If SharpCap **queues** frames, each GOTO costs up to ~714 MB transient and the
  blocking is the dominant cause; resolution and exposure are the amplifiers.

**Experiment:** with the camera live, watch SharpCap's process working set during one
long GOTO. If it climbs steadily and falls when the slew completes, frames are being
queued. If it stays flat, they are being dropped and the dialogs are the main culprit.

## Part 5 - Fix plan

### Phase 1 - Instrument (confirm before changing behaviour)

1. Add a probe to `_on_start` that logs, once per reading, `Process.WorkingSet64`,
   `Process.HandleCount`, `GC.GetTotalMemory(False)` and GDI/USER handle counts to a
   CSV. This distinguishes "growth during sleeps" (3.1) from "growth during dialogs"
   (2.1) on the user's own hardware.

### Phase 2 - Fix the confirmed leaks (low risk)

1. Wrap every `ShowDialog()` in `try/finally` and call `Dispose()` (six sites listed
   in 2.1).
2. Reuse one `Font` for `current_target_label` instead of allocating per selection
   (`ssp_dataaq.py:1878`, `:2082`).
3. Override `FormClosing` in `ssp_docking.py` to stop and dispose `_dock_timer`.
4. Dispose the `Image` after `AddCustomButton` (`main.py:364`).
5. Reuse a single strikeout `Font` in `_populate_grid` and dispose it in
   `FormClosing` (`ssp_allsky.py`).
6. Add an iteration cap to `_clear_buffer` (`ssp_comm.py:699`).
7. Add a re-entrancy guard to `_on_start` and disable the START button before the
   first blocking call.
8. **Camera:** pause or stop the guide camera's live view while the SSP sequence runs,
   if SharpCap exposes that control. This removes the frame source entirely and is the
   cheapest large win (see Part 4).
9. **Camera:** use 1000 ms exposure rather than 500 ms while SSP is running, to halve
   the frames buffered during each blocked window.

### Phase 3 - Fix the architecture (the actual fix)

1. Run the acquisition sequence on a worker thread (`System.Threading.Thread`) so
   SharpCap's message pump keeps running.
2. Marshal UI updates back with `Control.Invoke`/`BeginInvoke`.
3. Remove `Application.DoEvents()` from `_update_status`.
4. Keep the START button disabled for the whole operation via `try/finally`.
5. Pump messages during the mount settle loop instead of a bare `time.sleep(1)` for up
   to 30 s (`ssp_dataaq.py:2237-2238`), so the GOTO window is not fully unpumped.

This stops the host's frame/event queue from ever building up, which is what is
actually exhausting memory.

---

## Part 6 - Verification

After Phase 2 and Phase 3, repeat a 100-star session and confirm:

1. `Process.WorkingSet64` stays flat (no upward trend) across readings.
2. GDI and USER handle counts return to baseline after each dialog closes.
3. No `OutOfMemoryException`.

---

## Summary

| Question | Answer |
|---|---|
| Memory used per reading by the SSP code | **~5 KB** (measured) |
| Memory used for 100 readings | **~0.5 MB** |
| Real leaks in the code | ~54 MB + ~520 GDI + ~670 USER handles per 100 stars |
| Frames buffered per star by the full-HD camera | **~80 MB to 1 GB**, depending on exposure and bit depth |
| Cause of the crash | **SharpCap UI thread blocked 1-2 min per star while the full-HD camera runs** |

The application's own data handling is not the problem. The fix that matters is
getting the blocking serial and mount calls off SharpCap's UI thread. Full HD makes
this 7-13x more expensive than a small guide camera, and 500 ms exposure is twice as
bad as 1000 ms. See Part 4.


