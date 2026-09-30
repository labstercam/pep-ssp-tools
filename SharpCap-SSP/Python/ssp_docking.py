"""
SSP Docking Support Module
==========================
Adds bottom-docking to the SSP Data Acquisition window.
No modification to existing ssp_dataaq.py needed.

Usage:
    from ssp_docking import show_docked_data_acquisition_window
    show_docked_data_acquisition_window(sharpcap=SharpCap, ...)
"""

import clr
import System
import ctypes
import sys
import os
from System.Windows.Forms import Timer, ToolStripMenuItem, ToolStripSeparator
from System.Windows.Forms import FormStartPosition

_script_dir = os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else os.getcwd()
if _script_dir not in sys.path:
    sys.path.append(_script_dir)

import ssp_dataaq

user32 = ctypes.windll.user32


class RECT(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long),
                ("right", ctypes.c_long), ("bottom", ctypes.c_long)]


def _get_window_rect(hwnd):
    rect = RECT()
    if user32.GetWindowRect(hwnd, ctypes.byref(rect)):
        return {"left": rect.left, "top": rect.top,
                "right": rect.right, "bottom": rect.bottom,
                "width": rect.right - rect.left,
                "height": rect.bottom - rect.top}
    return None


STATUS_BAR_ESTIMATE = 30
RH_DOCK_ESTIMATE = 280


class DockedDataAcquisitionWindow(ssp_dataaq.SSPDataAcquisitionWindow):
    """Extends SSPDataAcquisitionWindow with bottom-docking.
    Timer-based positioning. No SetParent. Taskbar accessible."""

    def __init__(self, sharpcap=None, coordinate_parser=None):
        super().__init__(sharpcap=sharpcap, coordinate_parser=coordinate_parser)

        self._docked = True
        self._sc_hwnd = 0
        self._dock_height = self.Height
        self._dock_width = self.Width

        if sharpcap is not None:
            try:
                mw = sharpcap.MainWindow
                if hasattr(mw, "Handle"):
                    self._sc_hwnd = int(mw.Handle)
            except:
                pass

        self.ShowInTaskbar = True
        self.StartPosition = FormStartPosition.Manual

        # Restore saved docked size from config
        try:
            saved_w = self.config.get('dock_window_width')
            saved_h = self.config.get('dock_window_height')
            if saved_w and saved_h:
                self.Width = int(saved_w)
                self.Height = int(saved_h)
                self._dock_width = int(saved_w)
                self._dock_height = int(saved_h)
        except:
            pass

        self._add_dock_menu_item()

        self._dock_timer = Timer()
        self._dock_timer.Interval = 200
        self._dock_timer.Tick += self._on_dock_timer
        self.ResizeEnd += self._on_resize_end
        self.Load += self._on_dock_load

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

    def _on_dock_load(self, sender, event):
        self._update_dock_position()
        self._dock_timer.Start()

    def _update_dock_position(self):
        """Snap to SharpCap bottom. Never overrides user height."""
        if not self._docked or self._sc_hwnd == 0:
            return
        try:
            if self.IsDisposed or self.Disposing:
                return
        except:
            return

        if user32.IsIconic(self._sc_hwnd):
            if self.Visible: self.Hide()
            return
        if not self.Visible:
            self.Show()

        rect = _get_window_rect(self._sc_hwnd)
        if rect is None:
            return

        max_width = rect["width"] - RH_DOCK_ESTIMATE
        current_w = self.Width
        if current_w > max_width:
            current_w = max_width

        self.Left = rect["left"]
        self.Top = rect["bottom"] - self.Height - STATUS_BAR_ESTIMATE
        if current_w != self.Width:
            self.Width = current_w

        # Keep window on top of SharpCap without stealing focus
        if self.IsHandleCreated:
            user32.SetWindowPos(
                ctypes.c_int(int(self.Handle)),
                ctypes.c_int(0),  # HWND_TOP
                0, 0, 0, 0,
                0x0002 | 0x0001 | 0x0010  # SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE
            )

    def _on_dock_timer(self, sender, event):
        self._update_dock_position()

    def _toggle_docked(self, sender, event):
        self._docked = not self._docked
        if self._docked:
            self._dock_menu_item.Text = "Undock Window"
            self.Text = "SSP Data Acquisition Program Version 3 [DOCKED]"
            self._update_dock_position()
            self._dock_timer.Start()
        else:
            self._dock_menu_item.Text = "Dock Window"
            self.Text = "SSP Data Acquisition Program Version 3"
            self._dock_timer.Stop()

    def _on_resize_end(self, sender, event):
        self._dock_height = self.Height
        self._dock_width = self.Width
        # Save size to persist between launches
        try:
            self.config.set('dock_window_width', self.Width)
            self.config.set('dock_window_height', self.Height)
            self.config.save()
        except:
            pass


def show_docked_data_acquisition_window(sharpcap=None, coordinate_parser=None,
                                         on_close_callback=None):
    window = DockedDataAcquisitionWindow(
        sharpcap=sharpcap,
        coordinate_parser=coordinate_parser
    )
    if on_close_callback:
        window.FormClosed += lambda sender, event: on_close_callback()
    window.Show()
    return window



