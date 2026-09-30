# SharpCap-SSP Docking Guide

## Overview

This document describes how to make a SharpCap scripting window dock to the
bottom of SharpCap's main window. It covers all research findings, failed
approaches, the final working solution, and implementation patterns so that
any developer or AI coding agent can implement or modify docking behavior
for SharpCap scripting windows.

**Platform:**
- SharpCap 4.1/4.2 (64-bit)
- .NET 8.0
- IronPython 3.4.2
- WeifenLuo.WinFormsUI.Docking v2.9.3.0 (internal SharpCap use only)

---

## 1. Architecture Facts

### SharpCap's UI Framework

SharpCap is built on **WPF** (Windows Presentation Foundation), not WinForms.
This is the single most important fact for docking. Evidence:
- Window class: `HwndWrapper[SharpCap;...]`
- `Control.FromHandle()` returns `None` for SharpCap HWND
- All UI elements render inside a single Win32 HWND

### The SharpCap Object

| Property | Type | Value |
|----------|------|-------|
| `SharpCap` | `SharpCap.Models.Application` | Global scripting entry point |
| `SharpCap.MainWindow` | `SharpCap.UI.WindowProxy` | Main window proxy |
| `SharpCap.MainWindow.Handle` | `System.IntPtr` | **Win32 HWND** for tracking |
| `SharpCap.AddCustomButton()` | Method | Only public UI extension |

### What IS Available

| Item | Available? | Notes |
|------|-----------|-------|
| `SharpCap.MainWindow.Handle` (IntPtr) | **YES** | Win32 `GetWindowRect()` |
| `WeifenLuo.WinFormsUI.Docking` | **YES** | Internal use; no public API |
| `System.Windows.Forms.Form` | **YES** | Standard WinForms work |
| `FormBorderStyle.SizableToolWindow` | **YES** | Tool window style |
| `FormBorderStyle.Sizable` | **YES** | Full resize + taskbar |

### What is NOT Available

| Item | Notes |
|------|-------|
| `SharpCap.AddCustomPanel()` | Does not exist |
| `SharpCap.AddDockableWindow()` | Does not exist |
| `SharpCap.MainWindow.Control` | WindowProxy no WPF control access |
| `Control.FromHandle(SharpCapHWND)` | WPF not registered with WinForms |
| `Form.Show(SharpCapOwner)` | WPF ownership not bridgeable |

---

## 2. Failed Approaches

### Approach A: SetWindowLong(GWL_HWNDPARENT) -- FAILED

Sets SharpCap as owner via Win32. WPF windows don't participate in WinForms
ownership. The SSP window still goes behind SharpCap when activated.

### Approach B: Form.Show(ownerNativeWindow) -- FAILED

Same root cause. Internally calls SetWindowLong(GWL_HWNDPARENT), which
doesn't work for WPF-owned HWNDs.

### Approach C: SetParent (Child Window) -- PARTIAL SUCCESS

Make SSP a child of SharpCap. Window stays inside SharpCap (never behind),
but overlaps WPF-rendered UI (status bar, RH dock). Complex disposal.
Undock re-parenting causes invisible windows.

### Approach D: SetWindowPos(HWND_TOPMOST) -- OVERKILL

Stays above ALL windows, not just SharpCap.

---

## 3. Working Solution

### Core Strategy: Timer-Based Positioning + Z-Order Boost

| Technique | Purpose |
|-----------|---------|
| **Timer** (200ms) | Snaps window to SharpCap bottom |
| **ShowInTaskbar = True** | User can find/bring-forward window |
| **SetWindowPos(HWND_TOP)** each tick | Keeps above SharpCap, no focus steal |

### Why This Works

1. Timer positions window via `GetWindowRect()` on SharpCap HWND.
   Handles move, resize, minimize.

2. `ShowInTaskbar = True` gives taskbar button. If window goes behind,
   click taskbar to bring forward.

3. `SetWindowPos(HWND_TOP)` with `SWP_NOACTIVATE` pops window on top
   every 200ms without stealing keyboard focus.

### Critical Details

- **Never override user size:** Timer only sets Left/Top. Width/Height
  never changed (except clamping if SharpCap narrower).
- **SWP_NOACTIVATE (0x0010):** Prevents focus steal. User keeps working.
- **200ms interval:** ~0.33ms CPU per second. Negligible cost.
- **Hide when minimized:** `IsIconic()` check hides/shows with SharpCap.
- **No serial interference:** Win32 window API and serial I/O are separate
  subsystems. Timer cost (~0.33ms/sec) doesn't affect data collection.

---

## 4. API Reference

### Win32 Functions

```python
import ctypes
user32 = ctypes.windll.user32

class RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long),
                ("right", ctypes.c_long), ("bottom", ctypes.c_long)]

def get_window_rect(hwnd):
    rect = RECT()
    if user32.GetWindowRect(hwnd, ctypes.byref(rect)):
        return {"left": rect.left, "top": rect.top,
                "right": rect.right, "bottom": rect.bottom,
                "width": rect.right - rect.left,
                "height": rect.bottom - rect.top}
    return None

# Check minimized
if user32.IsIconic(hwnd): ...

# Z-order boost (no focus steal)
user32.SetWindowPos(
    ctypes.c_int(int(self.Handle)),
    ctypes.c_int(0),        # HWND_TOP
    0, 0, 0, 0,
    0x0002 | 0x0001 | 0x0010  # NOMOVE | NOSIZE | NOACTIVATE
)
```

### SharpCap API

```python
sharpcap = SharpCap                     # Global from SharpCap
mw = sharpcap.MainWindow                # WindowProxy
hwnd = int(mw.Handle)                   # IntPtr -> int for ctypes
```

---

## 5. Implementation Pattern

### Positioning Formula

```
Window.Left = SharpCap.rect.left
Window.Top  = SharpCap.rect.bottom - Window.Height - STATUS_BAR_MARGIN
Width clamp = min(Window.Width, SharpCap.rect.width - RH_DOCK_MARGIN)
```

### Timer Tick Flow

```
Timer fires (200ms)
  -> Is disposed/disposing? -> return
  -> Is SharpCap minimized? -> Hide window, return
  -> Is window hidden? -> Show it
  -> GetWindowRect(SharpCap)
  -> Clamp width if SharpCap narrower
  -> Set Left, Top (never Height)
  -> SetWindowPos(HWND_TOP, NOACTIVATE)
```

### Menu Integration

```python
def _add_dock_menu_item(self):
    if self.MainMenuStrip is None:
        return
    for item in self.MainMenuStrip.Items:
        if item.Text == "File":
            item.DropDownItems.Add(ToolStripSeparator())
            dock_item = ToolStripMenuItem("Undock Window")
            dock_item.Click += self._toggle_docked
            self._dock_menu_item = dock_item
            item.DropDownItems.Add(dock_item)
            break
```

### Dock/Undock Toggle

```python
def _toggle_docked(self, sender, event):
    self._docked = not self._docked
    if self._docked:
        self._dock_menu_item.Text = "Undock Window"
        self._update_dock_position()
        self._dock_timer.Start()
    else:
        self._dock_menu_item.Text = "Dock Window"
        self._dock_timer.Stop()
```

---

## 6. Integration with SSP Codebase

### File Changes

| File | Change | Lines |
|------|--------|-------|
| `SharpCap-SSP/Python/ssp_docking.py` | **NEW** | ~185 lines |
| `SharpCap-SSP/Python/main.py` | **MODIFIED** | 2 lines |
| `SharpCap-SSP/Python/ssp_dataaq.py` | **UNCHANGED** | 0 lines |

### Inheritance Pattern

```python
class DockedDataAcquisitionWindow(ssp_dataaq.SSPDataAcquisitionWindow):
    """Inherits all existing functionality, adds docking."""
    def __init__(self, sharpcap=None, coordinate_parser=None):
        super().__init__(sharpcap=sharpcap, coordinate_parser=coordinate_parser)
        # ... add dock menu item, create timer, restore size ...
```

### Entry Point

```python
# ssp_docking.py factory function:
def show_docked_data_acquisition_window(sharpcap=None, coordinate_parser=None,
                                         on_close_callback=None):
    window = DockedDataAcquisitionWindow(sharpcap=sharpcap,
                                         coordinate_parser=coordinate_parser)
    if on_close_callback:
        window.FormClosed += lambda sender, event: on_close_callback()
    window.Show()
    return window
```

### main.py Changes (2 lines)

```python
import ssp_docking                          # Added
ssp_docking.show_docked_data_acquisition_window(  # Changed from ssp_dataaq
    sharpcap=sharpcap_obj,
    coordinate_parser=coord_parser,
    on_close_callback=self._restore_launcher
)
```

---

## 7. Tuning Margins

### Constants

```python
STATUS_BAR_ESTIMATE = 30   # Pixels from SharpCap bottom edge
RH_DOCK_ESTIMATE = 280     # Pixels from SharpCap right edge
```

### How to Adjust

- Status bar overlapped? -> Increase `STATUS_BAR_ESTIMATE`
- Gap above status bar? -> Decrease `STATUS_BAR_ESTIMATE`
- RH dock overlapped? -> Increase `RH_DOCK_ESTIMATE`
- Empty space on right? -> Decrease `RH_DOCK_ESTIMATE`

---

## 8. Configuration / Persistence

### Config File

`%USERPROFILE%\Documents\SharpCap\SSP\ssp_config.json`

### Keys

| Key | Type | Description |
|-----|------|-------------|
| `dock_window_width` | int | Saved width |
| `dock_window_height` | int | Saved height |

### Save (on ResizeEnd)

```python
self.config.set("dock_window_width", self.Width)
self.config.set("dock_window_height", self.Height)
self.config.save()
```

### Restore (in __init__)

```python
saved_w = self.config.get("dock_window_width")
saved_h = self.config.get("dock_window_height")
if saved_w and saved_h:
    self.Width = int(saved_w)
    self.Height = int(saved_h)
```

---

## 9. Reference Files

### Production Implementation

`SharpCap-SSP/Python/ssp_docking.py`
- Full integration with SSP Data Acquisition window
- ~185 lines with persistence


---

## Appendix: Version History

| Version | Approach | Outcome |
|---------|----------|---------|
| v1 | Timer positioning only | Disappears behind SharpCap |
| v2 | GWL_HWNDPARENT ownership | WPF can't be WinForms owner |
| v3 | SetParent child window | Visible but overlaps UI |
| v4 | Show(owner) NativeWindow | Same WPF ownership issue |
| v5 Final | HWND_TOP + ShowInTaskbar + Timer | Working solution |


