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

**Revision 2026-11-25:** added Part 7 with two measured soak runs (33 readings undocked,
19 readings docked). The soak data **reverses the Part 3 conclusion**: the growth is
time-linear at ~2.6 MB/s, not event-driven. Part 2.1, Part 3.1, Part 4.6 and Part 4.8
have been corrected accordingly, and the Part 5 priority order has been re-ranked.

**Revision 2026-11-25 (later):** added Part 8 - the Phase 0 control experiment. Five
controlled runs prove the camera pipeline does **not** leak on its own. The leak appears
**only while SSP data collection is running**. This overturns the Part 7 attribution and
restores Phase 3 (move acquisition off the UI thread) as the primary fix.

**Revision 2026-11-25 (latest):** added Part 9 - the first Phase 3 increment is
implemented (integration wait, read-with-timeout loop and mount settle loop now pump UI
messages). **Re-tested and confirmed fixed**, including the GOTO case:

| Condition | Before | After |
|---|---|---|
| Capture, 1 s, no GOTO | +0.558 MB/s | **+0.012 MB/s** (Part 9.6 Run B) |
| GOTO only, no capture | not measured | **+0.024 MB/s** (Part 9.7 Run C) |
| Capture + GOTO (the Part 7 soak profile) | **+2.62 MB/s** | **+0.017 MB/s** (Part 9.7 Run D) |

Projected 100-star session growth fell from ~14.9 GB to under 0.5 GB. See Parts 9.6 and
9.7. One residual kernel-handle drift during readings is flagged for a longer re-check.

**Revision 2026-11-25 (final):** added Part 10 - Phase 2 **partial** fixes implemented:
the close/re-entrancy guard (the exposure the Part 9 pump introduced) and the
`_dock_timer` shutdown leak in `ssp_docking.py`. The rest of Phase 2 is deferred as
hygiene. Phase 4 is not planned.

**Revision 2026-11-25 (soak validation):** added Part 11 - a **99.1-minute soak** with the
camera, mount slews and plate solving measured **+6.64 MB total (+0.001 MB/s)** using two
independent instruments, with SharpCap's camera frame pool and VirtualAlloc allocation
byte-identical at every 30-minute checkpoint. The leak is fixed and validated. Handles
moved -5 over the run, so the Part 9.7 handle-drift observation is treated as noise.

---

## How these numbers were obtained

All figures below were measured on Windows with the .NET runtime instrumented through
`GC.GetTotalMemory(true)`, `Process.HandleCount` and `GetGuiResources` (GDI and USER
handle counts). Every sample forced three full garbage collections
(`GC.Collect` + `WaitForPendingFinalizers`) first, so only *retained* memory is
counted. Source line references were read directly from the files listed above.

**Live instrumentation (added 2026-11-25).** `ssp_dataaq.py` now contains two tagged
helpers, `_print_memory_stats(reading_num)` and `_log_memory_point(label, force_gc)`,
which print working set, private bytes, peak working set, handle count, thread count,
managed heap and GDI/USER handles to the SharpCap log. Both also print an **elapsed time
and a MB/s rate** so the time-linearity of the leak is visible immediately rather than
having to be reconstructed from timestamps. Both call `Process.Dispose()` in a `finally`
block, so the instrumentation does not itself inflate the handle count it measures.
`_log_memory_point` is called around both star-selection dialogs and around the GOTO
slew/settle path. Part 7 contains the results from the first two soak runs.

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

**Correction from the Part 7 soak runs:** in practice the dialog is *not* opened once
per reading. Measured GDI growth across 33 readings was **+47 handles (~1.5 per
reading)**, not ~5.2 per reading. The single large step (GDI 107 -> 156, USER 142 ->
155, between readings #14 and #15) is the signature of a dialog actually being opened.
So the realistic dialog budget is **~150 GDI and ~200 USER handles per 100 stars, and
only if the dialog is opened every single time**. The 520/670 figures in this section
are the worst case for a session that opens a dialog for every star.

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

**Confirmed by the Part 7 soak runs:** total measured growth was 4881.70 MB of private
bytes over 33 readings, of which only 18.13 MB was managed. The script's own leak budget
(~54 MB per 100 stars) is roughly **1% of the observed growth**, and the measured GDI
growth was only ~1.5 handles per reading rather than the ~5.2 assumed above. The table in
this section is a worst case for a session that opens a dialog for every single star.

---

## Part 3 - Why memory actually runs out

### 3.1 SharpCap's UI thread is blocked for 1-2 minutes per star

> **Correction from the Part 7 soak runs.** This section originally called thread
> blocking the *dominant cause*. The measured data does not support that. Growth is
> **time-linear at ~2.6 MB/s** and is essentially independent of whether a blocking
> window occurred; GOTO intervals only leak more because they *last longer*. See
> Part 7.2. The blocking described below is real and still worth fixing, but it
> determines *burst size and queue depth*, not the underlying leak rate. Treat this
> section as an explanation of the amplification mechanism, not of the root cause.

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

### 4.6 Exposure: 500 ms is the worse setting, and >1 s changes the capture mode

Halving the exposure doubles the frame rate and therefore doubles the number of
frames buffered during every blocked window. For this specific problem **1000 ms is
about twice as safe as 500 ms**. If the session can tolerate it, use 1000 ms while
the SSP sequence is running.

**Observed behaviour at 2 s exposures (user report, 2026-11-25):** at 2 s the on-screen
behaviour changes qualitatively. After a GOTO, or after the camera update is locked out
during an observation, *a number of frames are loaded quickly and displayed to catch
up*. This indicates the camera switches to a **still/triggered capture mode** above
roughly 1 s exposure, and that SharpCap **queues** those requests and delivers them in
a burst afterwards. So there are two distinct boundaries to respect, not one:

| Exposure | Capture mode | Behaviour during a blocked UI thread |
|---|---|---|
| 500 ms | continuous live | ~2x frames of 1000 ms |
| 1000 ms | continuous live | baseline |
| > 1000 ms (e.g. 2 s) | still / triggered | requests queue, then burst on resume |

The >1 s still mode is the best-behaved option for this specific problem, because the
queue is bounded by the number of requested captures rather than by wall-clock time.

### 4.7 What does not change

The SSP application's own memory is unaffected by camera resolution:

| SSP-side cost | Value |
|---|---|
| Per reading (strings + ListBox + `_update_status`) | ~5 KB |
| 100 readings | ~0.5 MB |

The ~5 KB per-reading figure in Part 1 stands. The camera only changes the host-side
cost of blocking.

### 4.8 Queue or drop? Resolved from the soak runs

This section originally listed queue-vs-drop as an open question. The Part 7 soak data
and the user's 2 s-exposure observation resolve it:

**SharpCap queues, but the queue is bounded.** The evidence:

1. At 2 s exposure the user directly observed a burst of frames delivered to the screen
   after a GOTO or after the camera update was locked out. That is queueing, not dropping.
2. In the 33-reading soak, GOTO intervals leaked **+178.3 MB** on average over ~65 s,
   while non-GOTO intervals leaked **+106.3 MB** over ~45 s. Normalised, that is
   **2.7 MB/s vs 2.4 MB/s** — only a ~1.15x premium, not the 3x+ a growing unbounded
   queue would produce. The queue therefore coalesces or caps at a small depth.

So the "unbounded accumulation" branch is **not** what is happening: the queue caps at a
small depth. Blocking adds only a modest burst on top of whatever is happening anyway.

> **CORRECTION from Part 8.** The "steady-state drain that continues whether or not the UI
> thread is blocked" conclusion above was based on the assumption that the camera pipeline
> leaked on its own. Part 8's control runs disprove that: SharpCap with the camera live but
> no SSP capture is flat (-0.051 MB/s over 7 minutes). There is **no** steady-state drain
> without capture. The queue-caps-at-small-depth finding still stands, and it is the reason
> the leak is bursty rather than smooth.

**Consequence:** the "unpumped GOTO window" is a genuine amplifier, and Part 8 shows it is
the *only* mechanism left standing. Phase 3 in Part 5 is therefore the primary fix, not a
secondary one. Phase 0 is complete and its results are in Part 8.

## Part 5 - Fix plan

> **Re-ranked twice on 2026-11-25.** The Part 7 soak data first suggested a time-linear
> ~2.6 MB/s native leak independent of blocking, which demoted Phase 3. The Part 8 control
> experiment then **reversed that again**: the camera pipeline does not leak on its own,
> and the leak appears only while SSP data collection runs. Phase 3 is therefore restored
> as the primary fix, and Phase 0 is complete.

### Phase 0 - Control experiment (COMPLETE - results in Part 8)

Run 2026-11-25 with five 7-minute runs on SharpCap 4.1 using `tools/monitor_sharpcap.ps1`.

**Result:** SharpCap alone (-0.021 MB/s), SharpCap + camera live (-0.051 MB/s) and
SharpCap + SSP interface open but unconnected (+0.000 MB/s) are all **flat**. Only actual
SSP capture leaks (+0.56 to +0.89 MB/s). The camera pipeline is exonerated; the script
alone is exonerated; the **combination** is the problem. Go to Phase 3.

### Phase 1 - Instrument (confirm before changing behaviour)

1. Add a probe to `_on_start` that logs, once per reading, `Process.WorkingSet64`,
   `Process.HandleCount`, `GC.GetTotalMemory(False)` and GDI/USER handle counts to a
   CSV. This distinguishes "growth during sleeps" (3.1) from "growth during dialogs"
   (2.1) on the user's own hardware.

### Phase 2 - Fix the script's own leaks (low risk, ~54 MB per 100 stars)

> **Status (2026-11-25): implemented, except items 1 and 7.** Items 3 and 7 are in Part 10;
> items 2, 4, 5 and 6 are in Part 10.5. Item 1 (the undisposed `ShowDialog()` sites) and the
> full `_on_start` re-entrancy guard remain deferred - Part 10.4.

1. Wrap every `ShowDialog()` in `try/finally` and call `Dispose()` (8 call sites exist;
   Part 2.1 lists the ones that recur). - *still deferred (Part 10.4)*
2. Reuse one `Font` for `current_target_label` instead of allocating per selection.
   - **DONE (Part 10.5)**
3. Override `FormClosing` in `ssp_docking.py` to stop and dispose `_dock_timer`.
   - **DONE (Part 10.2)**
4. Stop `Image.FromFile` holding `SSP.ico` open for the life of the session (`main.py`).
   - **DONE (Part 10.5)**
5. Reuse a single strikeout `Font` in `_populate_grid` and dispose it on close
   (`ssp_allsky.py`). - **DONE (Part 10.5)**
6. Add an iteration cap to `_clear_buffer` (`ssp_comm.py`). - **DONE (Part 10.5)**
7. Guard against a close mid-acquisition, which the Part 9 pump made reachable
   (`_closing` flag). - **DONE (Part 10.1)**

These are real and cheap. Part 8 confirms they are **not** the main driver - the leak
persists with zero dialogs open - but they cost ~54 MB plus handles per 100 stars and
should be fixed regardless. Camera-side mitigations are in Phase 4.

### Phase 3 - Fix the architecture (the actual fix, per Part 8)

> Part 7 demoted this to "secondary" on the theory that the camera pipeline leaked
> independently of the script. **Part 8 disproved that** (Runs 1-3 flat over 21 minutes
> with no capture), so this is restored as the primary fix. The leak appears only when the
> SSP capture loop blocks the UI thread while the camera runs.

1. Run the acquisition sequence on a worker thread (`System.Threading.Thread`) so
   SharpCap's message pump keeps running.
2. Marshal UI updates back with `Control.Invoke`/`BeginInvoke`.
3. Remove `Application.DoEvents()` from `_update_status`.
4. Keep the START button disabled for the whole operation via `try/finally`.
5. Pump messages during the mount settle loop instead of a bare `time.sleep(1)` for up
   to 30 s (`ssp_dataaq.py:2237-2238`), so the GOTO window is not fully unpumped.
6. Pump the mount async waits too - the slew (`StartSlewToAsync`), `WaitUntilSettled`,
   and the optional `SolveAndSync` - via `_pump_until_complete` (`ssp_dataaq.py`), so no
   part of the GOTO window blocks the frame queue unpumped. (Added with the
   "Plate Solve and Sync" feature, which introduced a further multi-second unpumped
   solve window.) START is locked for the duration so a pumped click cannot start an
   acquisition mid-slew.

   **Measured (2026-11-26, ASI462MM + CGX).** A logged GOTO+solve confirmed the solve
   wait is **async and pollable**: `mount.SolveAndSync()` returns in **0.13 s** and the
   pumped wait runs for **28.62 s** (`pumpable=True`), i.e. the UI message loop refreshes
   ~20x/s for the whole solve and the frame queue drains. The solve window then measures
   **+7.6 MB private / +11.3 MB working set over 28.8 s (+0.27 MB/s)**, reclaimed by the
   `After SolveAndSync` forced-GC checkpoint (private returned *below* its pre-solve
   value). No leak, and the screen updates throughout the GOTO and the solve. (An
   earlier +123 MB reading did not reproduce; it was dominated by the working set
   refilling after the settle loop's forced GC, not by solve growth.)

This stops the host's frame/event queue from building up while the camera is running.
Part 8 shows the queue is what grows during capture, so this is expected to remove the
leak rather than merely reduce it.

### Phase 4 - Camera-side mitigation (reduce the frame source)

These are mitigations, not fixes. Part 8 shows the camera alone does not leak, so the
camera is not the culprit - but it is the frame source whose queuing is amplified by the
blocked UI thread. Reducing it shrinks the burst size while Phase 3 is implemented.

1. **Pause or stop the guide camera's live view while the SSP sequence runs**, if
   SharpCap exposes that control. This removes the frame source entirely and is the
   cheapest large reduction in burst size (see Part 4).
2. **Use 1000 ms exposure rather than 500 ms** while SSP is running, to halve the frames
   buffered during each blocked window (Part 4.6).
3. Consider 2 s+ exposures, which put the camera into still mode and bound the queue by
   the number of requested captures rather than by wall-clock time (Part 4.6).

### Phase 5 - Instrumentation housekeeping

1. `_print_memory_stats` and `_log_memory_point` now call `Process.Dispose()` in a
   `finally` block. Without this the instrumentation itself leaks one process handle per
   sample, which would contaminate the handle-count trend it is trying to measure.

---

## Part 6 - Verification

After Phase 2 and Phase 3, repeat a 100-star session and confirm:

1. `Process.WorkingSet64` stays flat (no upward trend) across readings.
2. GDI and USER handle counts return to baseline after each dialog closes.
3. No `OutOfMemoryException`.

---

## Part 7 - Measured soak results (added 2026-11-25)

Two real soak runs were captured with the instrumentation in `_print_memory_stats`
(`ssp_dataaq.py`). These are the first measurements from the user's own hardware with
the camera running, and they change the diagnosis.

### 7.1 Run 1 - 33 readings, undocked, 1 s exposure

Baseline at module load: **445.59 MB**. Session 21:59:48 -> 22:30:47 = **1859 s**.

| Metric | Reading #1 | Reading #33 | Delta | Per reading |
|---|---|---|---|---|
| Working set | 973.05 MB | 3961.16 MB | +2988.11 | +93.4 MB |
| **Private bytes** | 889.94 MB | 5771.64 MB | **+4881.70** | **+152.6 MB** |
| Managed heap (GC) | 114.11 MB | 132.24 MB | +18.13 | +0.57 MB |
| Handle count | 1822 | 2899 | +1077 | +33.7 |
| GDI handles | 111 | 158 | +47 | +1.47 |
| USER handles | 139 | 156 | +17 | +0.53 |
| Thread count | 58 | 60 | +2 | ~0 |

Three things stand out:

1. **4881.70 MB of private-bytes growth against 18.13 MB of managed-heap growth.**
   That is 99.6% native. The script's own Python allocations are not the leak; the
   ~5 KB per-reading figure in Part 1 is confirmed.
2. **Working set plateaus at 4221.37 MB from reading #26 onward while private bytes
   keeps climbing.** From #26 to #33 the working set *fell* about 234 MB while private
   bytes *rose* 1150 MB. Windows began trimming the working set while committed memory
   kept growing. This is the pre-OOM condition, and it explains why Task Manager showed
   93% while the process itself was still around 4 GB working set.
3. **GDI grew only 47 over 33 readings (~1.5 per reading), not the ~5.2 predicted in
   Part 2.1.** The dialog is not being opened once per reading in practice. The one big
   step (GDI 107 -> 156, USER 142 -> 155, between readings #14 and #15) is the signature
   of a dialog actually being opened.

### 7.2 The leak is time-linear, not event-driven

Normalising each interval by its elapsed time gives a strikingly clean result:

| Window | Elapsed | Private bytes growth | Rate |
|---|---|---|---|
| Session start -> reading #26 (before OS trimming) | 1422 s | 889.94 -> 4621.72 MB = **+3731.78 MB** | **2.62 MB/s** |
| Reading #26 -> reading #33 (after OS trimming began) | 437 s | 4621.72 -> 5771.64 MB = **+1149.92 MB** | **2.63 MB/s** |

**2.62 MB/s and 2.63 MB/s — identical to three significant figures**, across the phase
boundary where the OS started trimming the working set. A leak that tracks wall-clock
time that precisely is not caused by discrete events (GOTOs, dialogs, blocking windows).
It is a clock running continuously in the camera pipeline.

This also dissolves the apparent GOTO effect. Normalised:

| Interval type | Mean change | Mean elapsed | Rate |
|---|---|---|---|
| With GOTO | +178.3 MB | ~65 s | ~2.7 MB/s |
| Without GOTO | +106.3 MB | ~45 s | ~2.4 MB/s |

GOTO intervals only "cost more" because they *last longer*. There is no meaningful GOTO
premium once you divide by time. The earlier "GOTO premium" reading was an artefact of
comparing intervals of different lengths.

### 7.3 Run 2 - 19 readings, docked, 1 s exposure

| Window | Elapsed | Working set growth | Rate |
|---|---|---|---|
| Reading #2 (23:00:55) -> reading #18 (23:16:03) | 908 s | 915.52 -> 3812.65 MB = **+2897.13 MB** | **3.19 MB/s** |

So **docked leaks about 1.2-1.3x faster per second** than undocked (3.19 vs 2.62 MB/s),
and reached ~3962 MB by reading #19-20 versus #33 undocked. That matches the user's
observation that the docked run "got there quicker after only 20 readings".

Plausible reason (unproven): when docked, the SSP panel is a child of SharpCap's main
window, so every `_update_status()` -> `Refresh()` + `Application.DoEvents()` repaint of
the SSP panel can invalidate the camera preview in the same window, allocating an extra
full-HD GDI+ bitmap per repaint. Undocked, the SSP form is a separate top-level window
and its repaints do not touch the preview. This is the only structural difference between
the two runs and is worth confirming.

### 7.4 What the numbers point to

At ~1 fps with 1 s exposures, 2.6 MB/s is approximately **2.6 MB per captured frame** —
almost exactly one 1920x1080 8-bit raw frame buffer (2.07 MB measured, Part 4.2). The most
economical explanation is that **one frame buffer per captured frame is never released**,
inside SharpCap's pipeline or the camera vendor's SDK. The SSP script is a bystander: it
merely keeps the session running long enough to accumulate ~15 GB over 100 readings at
~57 s each.

> **CORRECTION — the "bystander" conclusion above is WRONG.** Part 8's control experiment
> shows SharpCap with the camera live but *no SSP capture* is completely flat
> (-0.05 MB/s over 7 minutes). The frame-buffer-per-frame explanation is therefore
> refuted. The leak requires the SSP capture loop to be running. The camera pipeline is
> not the culprit; the interaction between the SSP script's blocking UI thread and the
> running camera is. See Part 8.

**The decisive experiment was a control run, not another soak:**

> **Phase 0 control experiment - COMPLETE.** SharpCap with the camera live but the SSP
> script not capturing for 7 minutes was **flat** (-0.051 MB/s). The "leaks ~2.6 MB/s with
> no SSP script" branch did not occur, so the script is not exonerated and the camera is
> not blamed. The leak requires both. Results in Part 8.

This single measurement was worth more than any number of further SSP soak runs.

### 7.5 Deployment gap found 2026-11-25 (why the new checkpoints never logged)

The Round 2 and Round 3 instrumentation (`_log_memory_point`, the dialog and GOTO
checkpoints, and the MB/s rate columns) produced **no output** in the 18-reading logs.
That was not because the checkpoints failed to fire. It was because the code containing
them was never loaded.

SharpCap's startup script configuration (verified in the registry at
`HKCU\Software\AstroSharp Limited\SharpCap\4.1` and `\4.2`) points at **different copies**
of the script:

| SharpCap version | Startup script path | Script revision |
|---|---|---|
| 4.1 (stable) | `C:\Users\AstroPC\Documents\SharpCap\SSP\main.py` | Round 1 only |
| 4.2 (Beta) | `C:\Users\AstroPC\Documents\GitHub\pep-ssp-tools\SharpCap-SSP\Python\main.py` | Round 1 + 2 + 3 |

The user runs **4.1**, so the deployed copy in `Documents\SharpCap\SSP` is what actually
executes. Marker counts confirmed the difference:

| Marker | Deployed (4.1) | Repo |
|---|---|---|
| `_print_memory_stats` | present | present |
| `_log_memory_point` | **absent** | present |
| `_mem_last_reading_*` | **absent** | present |
| `MB/s` rate columns | **absent** | present |

Every other module in the deployed folder is byte-identical to the repo. **Only
`ssp_dataaq.py` was out of sync**, so a single-file copy is the complete fix.

**Actions taken:**

1. Backed up the Round 1 copy to `ssp_dataaq.py.round1.bak` (141527 bytes) in the
   deployed folder.
2. Copied the repo `ssp_dataaq.py` (148054 bytes) over the deployed copy. SHA256 now
   matches between repo and deployed.
3. Added `SharpCap-SSP/tools/monitor_sharpcap.ps1`, a fixed-interval external memory
   sampler. It is needed because the control experiment deliberately does *not* load the
   script, so the script's own instrumentation cannot be used. It reports working set,
   private bytes, peak working set, handle count, thread count, GDI handles, USER handles,
   and derived MB/s rates, with private bytes as the primary metric.

**Lesson for future runs:** after editing the script, confirm the deployed copy matches
the repo before trusting a log. A stale deployment is silent — it produces no error, only
missing output.

---

## Part 8 - Phase 0 control experiment results (added 2026-11-25)

Five controlled runs were captured with `tools/monitor_sharpcap.ps1` on SharpCap 4.1
(the version the user actually runs), each 7 minutes at 60 s sampling. The only variable
was what the SSP script was doing.

### 8.1 The five runs

| Run | Condition | Private start -> end | Net | Rate | Verdict |
|---|---|---|---|---|---|
| 1 | PEP button loaded, **no camera** | 311.41 -> 302.48 MB | **-8.93 MB** | **-0.021 MB/s** | flat |
| 2 | PEP loaded, **camera live at 1 s** | 411.08 -> 389.79 MB | **-21.29 MB** | **-0.051 MB/s** | flat |
| 3 | SSP interface open, **not connected** | 429.54 -> 429.65 MB | **+0.11 MB** | **0.000 MB/s** | flat |
| 4 | SSP **doing capture** (1 s) | 457.63 -> 625.27 MB (0-300 s) | **+167.64 MB** | **+0.558 MB/s** | **leak**, then sample lost |
| 5 | SSP **doing capture** (100 ms) | 879.39 -> 1253.26 MB | **+373.87 MB** | **+0.890 MB/s** | **leak** |

Handle and GDI/USER detail:

| Run | Handles | GDI | USER |
|---|---|---|---|
| 1 | 1474 -> 1459 | 67 -> 67 | 66 -> 64 |
| 2 | 1574 -> 1539 | 67 -> 67 | 70 -> 69 |
| 3 | 1541 -> 1536 | 95 -> 95 | 133 -> 131 |
| 4 | 1584 -> 1669 (+85 in 300 s) | 99 -> 106 | 139 -> 142 |
| 5 | 1718 -> 1873 | 106 -> 106 | 143 -> 142 |

**The handle growth during capture is not GDI or USER.** Run 4 gained 85 handles in 300 s
and Run 5 gained 155 in 420 s, while GDI stayed at 106 and USER at 142-143 in both. So the
leak is in **kernel handles** (events, timers, or queue objects), not in window/graphics
resources. That is consistent with frames being queued and their synchronisation objects
being retained, and it means the undisposed-dialog theory in Part 2.1 is *not* what is
driving the handle growth here — that leak is real but separate.

### 8.2 What this proves

**Runs 1-3 are flat.** Over 21 minutes of combined measurement with no SSP capture, net
change was **-30.1 MB** (memory went *down*). SharpCap idle, SharpCap with the camera
live at 1 s, and SharpCap with the SSP interface open but unconnected all show **no leak
whatsoever**.

**Runs 4-5 leak.** Over 12 minutes of valid SSP capture (Run 4's first 300 s plus Run 5's
420 s), net change was **+541.5 MB** at 0.56-0.89 MB/s. Run 4's full-span figure is not
usable because the process became unreadable at 300 s (see 8.4).

This is the answer to the question Part 7 could not answer. **The camera pipeline does not
leak.** Run 2 is the direct disproof: a live 1920x1080 camera at 1 s exposure for 7
minutes *reduced* memory by 21 MB. The Part 7 "one frame buffer per frame is never
released" explanation is refuted.

The leak appears **only when SSP data collection runs**. Run 3 shows that merely opening
the SSP interface is not enough — the interface can be open indefinitely without leaking.
Run 4/5 show that starting capture is what triggers it.

### 8.3 The leak needs BOTH the script and the camera

This is the crucial subtlety. Runs 1-3 establish the three negative controls:

| Run | SSP script | Camera | Result |
|---|---|---|---|
| 1 | loaded, idle | **no** | flat |
| 2 | loaded, idle | **yes** | flat |
| 3 | interface open | **yes** | flat |
| 4/5 | **capturing** | **yes** | **leak** |

The script's own per-reading cost was measured at ~5 KB (Part 1) — roughly 0.26 KB/s at
one reading per 57 s. That is ~3000x too small to explain 0.56-0.89 MB/s. So the leak is
not the script's own allocations either.

What is left is the **interaction**: the SSP capture loop blocks SharpCap's UI thread with
blocking serial reads and `time.sleep()` calls, and pumps it back with
`Application.DoEvents()` (`ssp_dataaq.py:579`, inside `_update_status`). While the thread is
blocked inside each serial read, the running camera's frames queue up; when `DoEvents()`
runs between counts, that backlog is delivered. Part 4.8 already established that SharpCap
**queues** frames during blocking (bounded), and Part 3.1 identified the blocking windows.

Note that the pump is only *partially* blocked: `_update_status()` calls `DoEvents()` once
per count, so the UI thread does run between serial reads. The blocking is per-read, not
continuous. That is why the growth is bursty rather than smooth, and it is why the fix
must eliminate the per-read blocking rather than simply adding more `DoEvents()` calls.

Runs 4 and 5 confirm the amplification but not the mechanism, because the growth is
**bursty rather than smooth**:

| Run 5 interval | Private change | Rate |
|---|---|---|
| 0 -> 60 s | +37.21 MB | 0.62 MB/s |
| 60 -> 120 s | +6.15 MB | 0.10 MB/s |
| 120 -> 180 s | +106.43 MB | 1.77 MB/s |
| 180 -> 240 s | +114.48 MB | 1.91 MB/s |
| 240 -> 300 s | +47.06 MB | 0.78 MB/s |
| 300 -> 360 s | +59.91 MB | 1.00 MB/s |
| 360 -> 420 s | +2.63 MB | 0.04 MB/s |

Run 4 shows the same burstiness, plus a release: +82.74, +98.11, **-10.33**, +2.71,
**-5.59**, then an anomalous sample at 300 s (-587.06, see 8.4). The negative intervals are
direct evidence that memory is *released* between bursts, which is the opposite of a
monotonic leak. Run 5's final interval (+0.04 MB/s) is near-idle, suggesting the queue
drains when nothing is being captured.

Bursty growth is the signature of queued frames being delivered and retained, not of a
steady per-frame leak.

### 8.4 Run 4's anomalous sample at 360 s

Run 4's sample at 360 s shows `working_set 150.13 MB`, `private 38.21 MB`, `handles 0`,
`threads 0`, `gdi 0`, `user 0`. A process with zero handles and zero threads is not a
coherent running application, so this sample is either a measurement artifact or a moment
when SharpCap was terminating. The user reported "may be breaks in the capture," which
matches either reading.

The evidence does **not** cleanly support a restart-and-rebuild:

- The next sample at 420 s shows **898.14 MB**, far above a fresh SharpCap's ~275-350 MB
  baseline. A fresh instance would need to climb ~550 MB in 60 s (9 MB/s), which is 10x
  anything measured.
- Run 5's first sample, two minutes later, is **847.59 MB** — *lower* than Run 4's final
  898.14 MB. A restarted process would not sit at 847 MB.

The most likely reading is that the same process survived, memory was released during a
capture break, and the 360 s sample hit a transient read failure. The observation that
still matters for the investigation is narrower: **the failure mode is not a clean
`OutOfMemoryException` throw.** The process became unstable and memory dropped sharply,
which is the kind of behaviour that ends in a crash rather than a tidy exception.

### 8.5 Why the rate is lower than Part 7's 2.6 MB/s

Part 7 measured 2.62 MB/s during long 100-star soaks; Part 8 measures 0.56-0.89 MB/s
during short capture runs. That is a ~3x difference, and GOTO activity is the most likely
explanation. Part 7's runs included a mount slew per star, each blocking the UI thread for
30-90 s. Part 8's runs were capture-only with no GOTO, so the long unpumped windows were
absent.

There is an honest tension here. Part 4.8 measured the GOTO premium *within* the soak as
only ~1.15x (2.7 vs 2.4 MB/s per second), which on its own would not explain a 3x gap. The
gap is therefore probably not GOTO alone: the soak's non-GOTO intervals were also elevated
relative to Run 5. The likely reason is blocking *duty cycle* — the soak's readings blocked
the UI thread for several seconds per ~50 s cycle, whereas Run 5's monitor sampled a
continuously-capturing script. A higher duty cycle means more queued frames per unit time.
This is a hypothesis, not a measurement; the duty-cycle figure would need to be logged to
confirm it.

### 8.6 Revised conclusion

The crash is caused by **SharpCap's UI thread being blocked while the camera is running**.
Neither the camera alone nor the script alone is sufficient. The fix is therefore the one
Part 7 demoted: **get the blocking serial and mount calls off SharpCap's UI thread**
(Phase 3), so the frame queue never builds up. The script's own leaks (~54 MB per 100
stars, Part 2.7) are real but are ~1000x too small to explain the observed growth and are
a secondary cleanup.

---

## Part 9 - Implemented: targeted message-pump increment (added 2026-11-25)

This is the "Option 2" first increment from Part 5's Phase 3 - the smallest change
that tests the Part 8 diagnosis without restructuring the acquisition flow. It is
implemented in `ssp_comm.py` and `ssp_dataaq.py`, tagged `# Added for memory test`.

### 9.1 What changed

`ssp_comm.py` gains a pump mechanism that does not import Windows.Forms:

| Symbol | Purpose |
|---|---|
| `_pump_callback` | Module-global callback, `None` by default |
| `_pump_slice` | `0.05` s - the pump interval |
| `set_pump_callback(callback)` | Registers the pump (GUI layer supplies `Application.DoEvents`) |
| `pump_sleep(seconds, slice_seconds=None)` | Sleeps in slices, calling the pump between each |

Three blocking sites now pump:

1. **`get_slow_count` integration wait** (`ssp_comm.py`) - `time.sleep(wait_time)`
   became `pump_sleep(wait_time)`. This is the dominant blocking window: 1.15 s per
   count at 1 s integration, up to 10.15 s at 10 s integration, once per count.
2. **`_read_with_timeout` polling loop** (`ssp_comm.py`) - throttled pump at
   `_pump_slice` intervals. A read that times out blocks for up to 2 s.
3. **Mount settle loop** (`ssp_dataaq.py`, `_slew_to_star`) - `time.sleep(2)` and
   `time.sleep(1)` became `pump_sleep(2)` and `pump_sleep(1)`. This window reaches
   ~32 s.

`ssp_dataaq.SSPDataAcquisitionWindow.__init__` registers the callback:
`ssp_comm.set_pump_callback(Application.DoEvents)`.

### 9.2 Deliberately left blocking

- **Filter homing/selection retry pauses** (`ssp_comm.py`, two `time.sleep(2.0)` calls).
  These run inside `select_filter` *before* the START button is disabled, so pumping
  there would open a re-entrancy window into `_on_start`. They are error-path retries,
  not steady-state, so they were left alone.
- **All other `time.sleep` calls** in `ssp_comm.py` are 20-100 ms handshake delays and
  are too short to matter.

### 9.3 Re-entrancy analysis

| Path | Guard | Verdict |
|---|---|---|
| Count integration wait | START button disabled at the top of the loop | Safe |
| Read-with-timeout | Only reached from `get_slow_count` | Safe |
| Mount settle loop | GOTO buttons disabled via `_set_goto_buttons_enabled(False)` in `try/finally` | Safe |

`_do_trial_mode` calls `get_slow_count` without disabling the START button, so a pump
during trial mode could re-enter the handler. This is a pre-existing exposure -
`_update_status` already calls `DoEvents` on the same path - and is not made worse by
this change. A re-entrancy guard remains a Phase 2 item.

**Known edge case: closing the window mid-acquisition.** `_on_form_closing` has no
in-progress guard. Before this change, `DoEvents` ran only between counts, so a close
during a count was unlikely. Pumping now runs *during* the integration wait, so the
window is wider. If the user closes the SSP window mid-count, the port disconnects and
the next `_update_status` call may touch a disposed control. The count loop already
handles serial failures gracefully, so the likely symptom is an exception rather than a
crash. This is not fixed here to keep the increment targeted; it should be addressed in
Phase 2 with a `_closing` flag and a `try/finally` around the count loop.

### 9.4 Verification performed

- `ast.parse` clean on both files.
- `pump_sleep` extracted from the real AST and exercised directly (5 tests):
  no-callback degrades to plain sleep with correct duration; with-callback pumps ~11
  times over 0.51 s; a raising callback does not abort the wait; zero duration returns
  immediately; a custom slice size is honoured. All passed.
- Deployed copies at `C:\Users\AstroPC\Documents\SharpCap\SSP` synced and SHA256-matched.
  Backups: `ssp_comm.py.prepump.bak`, `ssp_dataaq.py.prepump.bak`.

### 9.5 What a re-run would show

If Part 8's diagnosis is right, the same soak should now leak at a much lower rate, and
the difference should be concentrated in the GOTO intervals (Part 8.5 noted GOTO
intervals carry the largest blocking window). If the leak rate is unchanged, the
diagnosis is wrong and the leak is not caused by the unpumped UI thread.

**This is the decisive re-test.** Run the same session profile as Run 1 of Part 7
(~30 readings, undocked, 1 s exposure) and compare the MB/s rate against the 2.62 MB/s
baseline. The `_print_memory_stats` `Private rate` line now reports this directly.

### 9.6 Re-test results with the pump in place (2026-11-25)

Two runs were captured after the pump fix. SharpCap 4.1 was launched at 14:02:54, after
the pumped files were written at 13:53:30 (`ssp_comm.py`) and 13:57:40 (`ssp_dataaq.py`),
so the fixed code was live for both runs. Pump markers verified present in the deployed
copies (`set_pump_callback` x1, `pump_sleep` x3/x2).

| Run | Condition | Span | Private start -> end | Net | Rate | Handles |
|---|---|---|---|---|---|---|
| A | SSP **collecting, no camera** | 180 s | 333.58 -> 315.69 MB | **-17.89 MB** | **-0.099 MB/s** | **-46** |
| B | SSP **collecting, camera at 1 s** | 420 s | 468.55 -> 433.32 MB | **-35.23 MB** | **-0.084 MB/s** | **-56** |

Steady-state rates (excluding the first-minute startup settling) are **-0.017 MB/s** for
Run A and **+0.012 MB/s** for Run B. Both are effectively zero.

**Direct before/after comparison, same 1 s exposure and the same condition (SSP
collecting with the camera running):**

| | Before pump | After pump |
|---|---|---|
| Private-bytes rate | **+0.558 MB/s** (Part 8, Run 4) | **-0.084 MB/s** overall, **+0.012 MB/s** steady state (Run B) |
| Handle trend | **+85** over 300 s | **-56** over 420 s |

**The leak is gone.** Memory now drifts slightly *down* during capture rather than
climbing, and the handle count shrinks instead of growing. Projected over a 95-minute
100-star session:

| | Growth per 100-star session |
|---|---|
| Before pump (Part 8 Run 4 rate) | **+3.2 GB** |
| Before pump (Part 7 soak rate, with GOTO) | **+14.9 GB** |
| After pump (Run B steady state) | **+0.07 GB** |

Run A is also a useful new control: **SSP collecting with no camera is flat**, confirming
that the SSP capture loop on its own does not leak and that the camera running was a
necessary ingredient. That matches Part 8.3.

**Caveats, stated plainly:**

1. **Run B had no GOTO**, so the mount settle pump (`ssp_comm.pump_sleep(2)` /
   `pump_sleep(1)`) is implemented and reasoned about but not directly measured. The
   mechanism is identical, but the GOTO case - which Part 8.5 identified as the largest
   blocking window - remains to be re-tested.
2. Runs were 3 and 7 minutes, versus a ~95-minute real session. The flatness is clear at
   this resolution but the projection is an extrapolation.
3. Run B used 1 s exposure. Part 8 Run 5 showed 100 ms exposure leaking ~1.6x faster than
   1 s, so the 100 ms case is untested with the pump.
4. Sample counts are low (4 and 8), so short-lived bursts would be missed.
5. **The CSVs cannot independently confirm that SSP readings were actually completing.**
   That relies on the description of the runs. Run A's memory profile (WS 362-378 MB,
   GDI 91, USER 127) is very close to Part 8 Run 3, which was "interface open, not
   connected" - so the two are not distinguishable from the sampler alone. The SharpCap
   log would settle it: `_print_memory_stats` emits
   `=== MEMORY TEST [...] Reading #N ===` once per completed reading, so that log would
   confirm the count. Worth checking before treating Run A as an SSP-active control.

**Verdict:** the Part 8 diagnosis is confirmed. Blocking SharpCap's UI thread during the
SSP capture loop *was* the cause of the leak, and pumping the message loop as a targeted
first increment removes it. The remaining Phase 3 work (moving acquisition to a worker
thread) is now optional rather than essential, and the GOTO re-test is the next
measurement worth taking.

### 9.7 GOTO re-test (closes the 9.6 caveat) - 2026-11-25

Part 9.6 caveat 1 was that Run B had no GOTO, leaving the mount settle pump - the largest
blocking window (up to ~32 s) - unmeasured. Two further runs close that gap. SharpCap was
restarted at 14:59:14, after the pumped files were deployed at 13:53:30 and 13:57:40, so
the fixed code was live. Both runs used the same SharpCap instance.

| Run | Condition | Span | Private start -> end | Overall rate | Settling rate | Handles |
|---|---|---|---|---|---|---|
| C | SSP dialog open, **no capture**, camera + **GOTO** | 420 s | 451.34 -> 466.20 MB | **+0.035 MB/s** | **+0.024 MB/s** | **+4** |
| D | **3 x 5 s readings + GOTO**, camera running | 300 s | 436.89 -> 462.25 MB | **+0.084 MB/s** | **+0.017 MB/s** | **+32** |

"Settling rate" excludes the first sample so the post-startup figure is not distorted by
the initial allocation burst (Run D jumped +21.24 MB in its first minute, then flattened).

**Run C isolates GOTO.** GOTO operations with the camera running but no SSP capture
produce **+0.024 MB/s** - flat. So GOTO alone does not leak either, matching Part 8's
finding that the camera alone does not leak.

**Run D is the full scenario** - SSP capture with GOTO between readings, which is exactly
the Part 7 soak profile that measured 2.62 MB/s. It now measures **+0.017 MB/s** steady
state.

| Comparison, same scenario | Rate | vs Run D steady state |
|---|---|---|
| Part 7 soak (capture + GOTO, pre-fix) | **+2.62 MB/s** | **154x higher** |
| Part 8 Run 4 (capture, no GOTO, pre-fix) | +0.558 MB/s | 33x higher |
| Run D (capture + GOTO, post-fix) | **+0.017 MB/s** | - |

**Interpretation.** The GOTO pump works. The largest blocking window no longer leaks, and
the full capture-with-GOTO profile - the one that caused the original crash - is now flat.
Projected over a 95-minute 100-star session:

| Basis | Growth per session |
|---|---|
| Pre-fix soak rate (2.62 MB/s) | **+14.9 GB** (fatal on 7.8 GB) |
| Run D steady state (0.017 MB/s) | **+97 MB** |
| Run D overall, including settling (0.084 MB/s) | **+479 MB** |

Either projection is comfortably survivable.

**One residual worth watching.** Run D's handle count drifts up (+32 over 300 s, ~0.11/s)
while GDI and USER stay flat at 111 and 139-142. That is kernel handles again. It is much
milder than pre-fix (+155 over 420 s, ~0.37/s) but not zero - extrapolated it is ~600
handles over a full session, well inside the ~10,000 per-process limit. Run C's handles
are flat (+4 over 420 s), so the drift correlates with the readings rather than GOTO.
With only 6 samples it could be noise; noting it as a possible residual handle leak to
re-check on a longer run, not as a confirmed problem.

**Caveats:** runs were 5 and 7 minutes versus a ~95-minute session; 5 s integration was
used (the longest single wait tested); sample counts are 6 and 8; and as in 9.6 the CSVs
cannot independently prove the readings completed - the SharpCap log's
`=== MEMORY TEST [...] Reading #N ===` lines would confirm the count.

---

## Part 10 - Phase 2 partial fixes implemented (2026-11-25)

Phase 2 (Part 5) was assessed as **low importance** for the crash, since the crash cause
was already fixed by the Part 9 pump. Two of its items are worth doing on their own
merits, however, and both are now implemented. The rest of Phase 2 remains deferred.

### 10.1 Close/re-entrancy guard (the exposure Part 9 introduced)

Pumping UI messages during the integration wait widened the window in which the user can
close the SSP window mid-read. `_on_form_closing` had no in-progress guard, so the count
loop would continue after the port disconnected and call `_update_status` on controls
being disposed.

A `_closing` flag now stops the loop cleanly:

| Location | Change |
|---|---|
| `__init__` | `self._closing = False` |
| `_on_form_closing` | sets `self._closing = True` first |
| count loop | `if self._closing: break` before each `get_slow_count` |
| after count loop | `if self._closing: return` - before binning and any control access |
| `_do_trial_mode` | `if self._closing: return` at the top |

The check after the loop matters because the binning step indexes `counts` in pairs; a
mid-loop break would leave a short list and raise `IndexError`. The early return also
avoids touching the START button, which is being disposed.

### 10.2 `_dock_timer` never stopped on close

`ssp_docking.py` creates a 200 ms `Timer` in `DockedDataAcquisitionWindow.__init__` and
starts it in `_on_dock_load`. The base class's `FormClosing` handler disposes `time_timer`
but knows nothing about `_dock_timer`, so the timer kept running after close - keeping the
window, its controls and its event subscriptions alive.

`DockedDataAcquisitionWindow` now overrides `_on_form_closing`: it stops and disposes
`_dock_timer`, then calls `super()._on_form_closing(...)` for the base cleanup.

This relies on Python's dynamic lookup: the base subscribes `self._on_form_closing`
during `super().__init__`, and because `self` is a `DockedDataAcquisitionWindow` the
*override* is what gets bound. Verified with a standalone test - the override is bound,
the base runs exactly once, there is one subscription, and there is no recursion.

### 10.3 Verification

- `ast.parse` clean on `ssp_dataaq.py`, `ssp_docking.py`, `ssp_comm.py`.
- Dispatch semantics test passed (see 10.2).
- Deployed copies synced and SHA256-matched.
  Backups: `ssp_dataaq.py.prephase2.bak`, `ssp_docking.py.prephase2.bak`
  (plus the earlier `ssp_dataaq.py.prepump.bak` and `ssp_dataaq.py.round1.bak`).

### 10.4 Remaining Phase 2 items

Six of the seven Phase 2 items were cheap and independent of the crash, so they were split
out and implemented in a second pass - see 10.5. The other two remain deferred.

| Item | Status |
|---|---|
| 8 undisposed `ShowDialog()` sites | **still deferred** - ~54 MB + handles per 100 stars, ~1000x below the fixed leak |
| Per-star `Font` reassignment (2 sites) | **DONE (10.5)** - ~180 KB per 100 stars |
| Per-cell strikeout `Font` (4 sites in `ssp_allsky.py`) | **DONE (10.5)** - GDI churn in one pass only |
| `Image.FromFile` not disposed (`main.py`) | **DONE (10.5)** - 1 image + 1 file handle per script load |
| `_clear_buffer` no iteration cap | **DONE (10.5)** - defensive only |
| Full re-entrancy guard on `_on_start` (disable START before the first blocking call) | **still deferred** - needs a ~170-line `try/finally`; the button-disable already blocks re-entry during the loop |

None of these are expected to matter for the crash. They are hygiene items.

---

### 10.5 Phase 2b - remaining hygiene items implemented (2026-11-25)

The cheap, control-flow-neutral items listed in 10.4 were implemented in a second pass.

**Item 2 - one `Font` for `current_target_label`** (`ssp_dataaq.py`)

A bold `Font` was allocated on every target selection. `Label.Font` does not take ownership
of the font assigned to it, so the replaced font was never released - one `Font` plus its
GDI handle leaked per star.

`_get_target_label_bold_font()` now creates the font on first use and returns the same
instance thereafter. It is released in a new `_on_form_closed` handler rather than in
`_on_form_closing`, because at `FormClosing` the label is still alive and a repaint with a
disposed font would throw; `FormClosed` fires once the controls are gone. The handler
reads the attribute via `getattr(..., None)` so it is safe for an instance that never
selected a star, and it is idempotent.

**Item 5 - one strikeout `Font` per `RawFileDataViewer`** (`ssp_allsky.py`)

`_populate_grid` called `Font(self.grid.Font, FontStyle.Strikeout)` for every struck-out
cell - potentially thousands of GDI fonts in one pass over a large raw file. All four sites
now share a lazily created `_get_strikeout_font()`, released with the same `FormClosed`
pattern as item 2.

**Item 4 - `Image.FromFile` in `main.py`**

This needed evidence first, because the obvious fix (immediately `Dispose()` the `Image`
after `AddCustomButton`) is wrong if SharpCap keeps a reference. A lock test against the
running SharpCap settled it:

```
SSP.ico            LOCKED
ssp_config.json    NOT locked
ssp_dataaq.py      NOT locked
dparms.txt         NOT locked
```

Only the icon was locked and nothing else in the folder, so `Image.FromFile` was holding
it - which also proves SharpCap *retains* the image for the toolbar button. Disposing it
would have broken the icon.

The icon is therefore built from memory instead, and both objects are held in module-level
references so neither can be collected (GDI+ requires the source stream to outlive the
`Image`):

```python
_ssp_icon_stream = MemoryStream(System.IO.File.ReadAllBytes(icon_path))
_ssp_icon_image = Image.FromStream(_ssp_icon_stream)
SharpCap.AddCustomButton("PEP", _ssp_icon_image, "SSP Photometer Control", launch_ssp_photometer)
```

`ReadAllBytes` closes the file immediately. Verified against real `System.Drawing` using
two separate copies of `SSP.ico` (separate copies so a still-alive image from one pattern
could not confound the measurement of the other):

| Pattern | File held open while the `Image` is alive |
|---|---|
| `Image.FromFile` | **yes** - leak reproduced |
| `ReadAllBytes` -> `MemoryStream` -> `Image.FromStream` | **no** - fixed |

The two load paths produce an identical image: 32x32, `Format32bppArgb`, **0 differing
pixels** across every channel including alpha. A `Bitmap` copy was deliberately rejected as
it can alter icon alpha.

**Item 6 - `_clear_buffer` iteration cap** (`ssp_comm.py`)

Draining was `while self.port.BytesToRead > 0`, bounded in practice by the device's output
but able to spin indefinitely against a continuously-streaming device. It is now capped at
`_CLEAR_BUFFER_MAX_READS = 1000` reads.

#### Verification

- Reproducible checks live in `tools/`: `verify_phase2_hygiene.py` (buffer cap and both
  Font caches, extracted from the shipped source with `ast` and run against fakes) and
  `verify_icon_handle.ps1` (file-handle behaviour and pixel identity against real
  `System.Drawing`). Both exit non-zero on failure.
- `py_compile` clean on all four modules.
- `pyflakes` across all 13 modules, before and after: **32 non-noise messages in both**.
  With line numbers normalised the message sets are **identical** - zero new or removed
  diagnostics. (The 1138-1146 raw messages are the known star-import false positives.)
- The shipped `_clear_buffer` was extracted from source with `ast` and run against a fake
  port: finite buffers drain fully, a 10**9-byte runaway stream stops at exactly 1000
  reads, and a closed port or `port=None` is a no-op.
- The shipped cache helpers were extracted the same way and run with a fake `Font`:
  **1 allocation for 501 calls** (`current_target_label`) and **1 for 5001 calls**
  (strikeout), always the same instance; `_on_form_closed` disposes it, clears the
  reference, is idempotent, and tolerates an absent attribute.
- Deployed copies synced and SHA256-matched. Backups: `ssp_dataaq.py.prephase2b.bak`,
  `ssp_comm.py.prephase2b.bak`, `ssp_allsky.py.prephase2b.bak`, `main.py.prephase2b.bak`.

#### Cost note

These were not measurable against the 99-minute soak (Part 11), where the app grew
+6.64 MB in total. They matter for the reason Phase 2 gave: they are real, they are cheap,
and at ~54 MB per 100 stars the remaining ones are worth removing now that the mechanism
is understood.

---
## Part 11 - 99-minute soak validation (2026-11-25)

The Part 9 and Part 10 fixes were validated over a full-length session - the closest thing
so far to the original crash scenario. Two **independent** instruments recorded the same
session: the external sampler introduced in Part 9, and SharpCap's own 30-minute memory
watchdog, which writes to SharpCap's log file.

### 11.1 Run facts

| | |
|---|---|
| Log file | `memory_run_20261125_152915.csv` |
| Duration | **99.1 minutes** (15:29:15 -> 17:08:24) |
| Samples | 100, one per 60 s |
| SharpCap | 4.1.14310.0 (X64), PID 5972 |
| Session start | 14:59:14 - **no restart during the run** |
| Script loaded | `...\Documents\SharpCap\SSP\main.py` at 14:59:23 |
| Fix live? | Yes - the deployed copies carried `pump_sleep` and `set_pump_callback` |

Activity confirmed from the same SharpCap log: camera **ZWO ASI462MM**, mount via
**CPWI**, plate solving, and Capture/Frame events. Log activity spans every 15-minute
bucket from 15:15 to 17:00, and `ssp_config.json` + `dparms.txt` were written at 15:29:22,
right at soak start. This was a genuine observing session, not an idle run.

### 11.2 Independent measurement 1 - the external sampler

| Metric | Start | End | Net | Rate |
|---|---|---|---|---|
| Private bytes | 466.37 MB | 473.01 MB | **+6.64 MB** | **+0.001 MB/s** (+0.1 MB/min) |
| Working set | 295.30 MB | 265.69 MB | -29.61 MB | - |
| Handles | 1610 | 1605 | **-5** | - |
| GDI handles | 111 | 111 | **0** | - |
| USER handles | 137 | 138 | **+1** | - |

Working set stayed within **114.9 - 296.3 MB** for the whole run.

The shape check is what matters:

| Movement | Count | Sum |
|---|---|---|
| Positive intervals | 55 | **+473.33 MB** |
| Negative intervals | 44 | **-466.69 MB** |
| **Net** | 99 | **+6.64 MB** |

About 473 MB churned up and 467 MB released, netting roughly zero. A leak ratchets; this
oscillates.

### 11.3 Independent measurement 2 - SharpCap's own watchdog

SharpCap logs its own memory status every 30 minutes. Four dumps fall inside the soak:

| Time | GC heap | Working set | Private | VirtualAlloc | Camera frame pool |
|---|---|---|---|---|---|
| 15:29:16 | 106.46 MB | 292.91 MB | 466.36 MB | **36.42 MB** | 3 x 4,243,712 B + 2 x 2,121,856 B + 2 x 4,243,712 B |
| 15:59:16 | 124.15 MB | 264.58 MB | 491.81 MB | **36.42 MB** | identical |
| 16:29:16 | 97.92 MB | 233.46 MB | 435.13 MB | **36.42 MB** | identical |
| 16:59:17 | 108.48 MB | 252.79 MB | 459.69 MB | **36.42 MB** | identical |

Private memory **466.36 -> 459.69 MB = -6.67 MB over 90 minutes**. The GC heap oscillates
around 110 MB with no trend.

### 11.4 The frame-pool constancy is the mechanism proof

The strongest single piece of evidence is the last column of 11.3. **VirtualAlloc is
byte-identical at 36.42 MB across all four dumps**, and the camera buffer pool never moves
from **3 pooled buffers of 4,243,712 bytes (12.141 MB), plus 2 x 2,121,856 (4.047 MB) and
2 x 4,243,712 (8.094 MB) unpooled**.

That is precisely the quantity the diagnosis predicted would grow. Parts 8.3 and 8.6
reasoned that the blocked UI thread caused the running camera's frames to queue; a growing
queue would show up as more buffers in this pool. It is pinned instead.

This is not merely "memory is flat". It is the specific mechanism that was identified,
measured, and found constant.

### 11.5 Comparison with the original crash

| | Rate | Over 99 minutes |
|---|---|---|
| Pre-fix soak (Part 7) | 2.62 MB/s | **+15.6 GB** - fatal on a 7.75 GB machine |
| This soak (post-fix) | 0.001 MB/s | **+6.6 MB** |
| **Reduction** | **~2,600x** | |

The original failure was `OutOfMemoryException` after roughly 100 readings with a camera
running. This run is the same configuration, sustained, and the growth is under 7 MB.

### 11.6 Environment note

Available physical memory during the run was only **0.99 - 2.47 GB of 7.75 GB**. The
machine runs other heavy applications (VS Code, GitHub Desktop, node, StarNet2 and
GraXpert are all on PATH). SharpCap's own private memory is ~460 MB, so this is not a
SharpCap or SSP problem - but headroom for any growth is thin, which is why the flat
result matters.

### 11.7 Caveats

1. SharpCap's main log does not mirror the IronPython console, so the exact number of
   completed `=== MEMORY TEST [...] Reading #N ===` readings could not be counted from it.
   The memory conclusion does not depend on that count.
2. Camera and mount activity are confirmed from the same log, but the script's own reading
   count is not independently recorded.
3. Handles moved **-5** over the run. Part 9.7 flagged a possible mild kernel-handle drift
   (+32 in 5 minutes during readings). Over 99 minutes it does not reproduce, so the
   earlier observation can be treated as noise rather than a residual leak.

### 11.8 Verdict

The leak is fixed, measured over 99 minutes with two independent instruments, on the
hardware and firmware that produced the original crash. The projection language used in
Parts 9 and 10 ("under 0.5 GB per session") can now be replaced with the measurement:
**+6.6 MB over 99 minutes, with the camera frame pool fully pinned.**

---


## Summary

| Question | Answer |
|---|---|
| Memory used per reading by the SSP code | **~5 KB** (measured) |
| Memory used for 100 readings | **~0.5 MB** |
| Real leaks in the script | ~54 MB + ~150-520 GDI + ~200-670 USER handles per 100 stars (worst case; measured GDI growth was only ~1.5/reading) |
| **Does SharpCap leak with no camera?** | **No** — -0.021 MB/s over 7 min (Part 8, Run 1) |
| **Does SharpCap leak with the camera live?** | **No** — -0.051 MB/s over 7 min (Part 8, Run 2) |
| **Does SharpCap leak with the SSP interface open?** | **No** — +0.000 MB/s over 7 min (Part 8, Run 3) |
| **Does SharpCap leak during SSP capture?** | **Yes** — +0.56 and +0.89 MB/s (Part 8, Runs 4 and 5) |
| **Measured leak rate during capture** | **0.56-0.89 MB/s** without GOTO; **2.6-3.2 MB/s** with GOTO per star (Part 7) |
| Growth pattern | **Bursty, not monotonic** — negative intervals occur (Part 8.3) |
| Queue or drop during blocking? | **Queues, bounded** — only a ~1.15x per-second premium on GOTO intervals |
| Managed vs native split | **18.13 MB managed vs 4881.70 MB native** over 33 readings (99.6% native) |
| **Cause of the crash** | **SharpCap's UI thread blocked by the SSP capture loop while the camera runs.** Neither the camera alone nor the script alone leaks; the combination does. |
| **Fix applied** | Message pump (`ssp_comm.pump_sleep`) in the integration wait, the read loop and the mount settle loop (Part 9) |
| **Leak after fix — capture, 1 s, no GOTO** | **+0.012 MB/s** steady state, handles **-56** (Part 9.6 Run B) - was **+0.558 MB/s, +85** |
| **Leak after fix — GOTO only, no capture** | **+0.024 MB/s**, handles **+4** (Part 9.7 Run C) |
| **Leak after fix — capture + GOTO (the soak profile)** | **+0.017 MB/s** steady state (Part 9.7 Run D) - was **+2.62 MB/s** |
| **Measured growth over a 99-minute soak (post-fix)** | **+6.64 MB total**, **+0.001 MB/s**, handles **-5** (Part 11) |
| **VirtualAlloc + camera frame pool over 99 min** | **byte-identical at every dump** - 36.42 MB and 3+2+2 buffers (Part 11.4) |
| **Projected growth per 100-star session** | **under 0.5 GB** after the fix, versus **~14.9 GB** before |
| **Residual** | The Part 9.7 kernel-handle drift **did not reproduce** over 99 minutes (handles moved -5). Treated as noise |

The application's own data handling is not the problem, and the camera pipeline is not the
problem either — Part 8 disproves that directly. The problem was the **interaction**: the
SSP capture loop blocked SharpCap's UI thread during serial reads and mount slews, so the
running camera's frames queued up faster than they were released.

**This has been confirmed by re-test, including the GOTO case.** Pumping the message loop
during those waits removes the leak (Parts 9.6 and 9.7):

| Scenario | Before | After |
|---|---|---|
| Capture, 1 s, no GOTO | +0.558 MB/s | **+0.012 MB/s** |
| GOTO only, no capture | not measured | **+0.024 MB/s** |
| Capture + GOTO (the original soak profile) | **+2.62 MB/s** | **+0.017 MB/s** |

**Validated over a full-length session.** A 99.1-minute soak with the camera running, mount
slews and plate solving measured **+6.64 MB total**, with two independent instruments
agreeing (Part 11). VirtualAlloc and the camera frame pool were byte-identical at every
30-minute checkpoint - the specific mechanism the fix targets.

**Remaining work:**

1. **Long soak validation — DONE** (Part 11): 99.1 minutes, +6.64 MB, frame pool pinned.
   No further validation is needed for the crash.
2. **Phase 2 (partial)** — the close/re-entrancy guard and the `_dock_timer` shutdown are
   done (Part 10). The remaining items (~54 MB + handles per 100 stars) are hygiene only.
3. **Phase 4 — not planned.** Camera-side mitigation was a workaround for a leak that no
   longer exists.


