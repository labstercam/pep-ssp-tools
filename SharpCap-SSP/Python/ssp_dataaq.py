"""
SSP Data Acquisition Window
============================

Main data acquisition window for SharpCap-SSP.
Replicates SSPDataq3 functionality.

Author: pep-ssp-tools project
Version: 0.1.6
"""

import clr
import sys
import time
import math

# Ensure module path is accessible
import System
script_dir = System.IO.Path.GetDirectoryName(__file__) if '__file__' in dir() else System.IO.Directory.GetCurrentDirectory()
if script_dir not in sys.path:
    sys.path.append(script_dir)

clr.AddReference('System')
clr.AddReference('System.Windows.Forms')
clr.AddReference('System.Drawing')
clr.AddReference('Microsoft.VisualBasic')

try:
    from System.Threading import CancellationToken
except ImportError:
    CancellationToken = None  # Not available in standalone mode

from System import *
from System.Windows.Forms import *
from System.Drawing import *
from System.IO import Path

# Added for memory test - memory instrumentation imports
from System.Diagnostics import Process
try:
    import ctypes  # Added for memory test - optional GDI/USER handle counts
except Exception:
    ctypes = None

# Added for memory test - baseline captured when SSP module first loads
try:
    _MEM_BASELINE_BYTES = Process.GetCurrentProcess().WorkingSet64
except Exception:
    _MEM_BASELINE_BYTES = 0

# Import SSP modules
import ssp_config
import ssp_comm
import ssp_dialogs
import night_mode
import ssp_catalog
import ssp_sequence


class SSPDataAcquisitionWindow(Form):
    """Main data acquisition window."""
    
    def __init__(self, sharpcap=None, coordinate_parser=None):
        """Initialize the data acquisition window.
        
        Args:
            sharpcap: SharpCap object if running in SharpCap, None if standalone
            coordinate_parser: CoordinateParser class if running in SharpCap, None if standalone
        """
        Form.__init__(self)
        
        # Initialize SSP communication and configuration
        self.config = ssp_config.SSPConfig()
        self.comm = ssp_comm.SSPCommunicator(
            boot_delay=self.config.get('boot_delay', 5.0),
            device_type=self.config.get('device_type', 'auto'),
            config=self.config
        )
        
        # Added for memory test - let ssp_comm pump UI messages during long
        # serial waits. Without this the integration wait and the mount settle
        # loop block SharpCap's UI thread while the camera keeps running, so
        # frames queue up faster than they are released.
        try:
            # Wrapped in a lambda: a bare .NET static method reference is not
            # reliably callable across IronPython versions.
            ssp_comm.set_pump_callback(lambda: Application.DoEvents())
        except Exception:
            pass
        
        # Initialize night mode
        self.night_mode = night_mode.NightMode()
        self.night_mode.set_night_mode(self.config.get('night_flag', 0) == 1)
        
        # Initialize star catalog
        self.catalog = None
        self._load_star_catalog()
        
        # Initialize extinction star catalog
        self.extinction_catalog = None
        self._load_extinction_catalog()
        self.last_extinction_filter = None  # Track last used extinction filter
        
        # Store SharpCap object and CoordinateParser (passed from main.py)
        self.SharpCap = sharpcap
        self.CoordinateParser = coordinate_parser
        self.sharpcap_available = sharpcap is not None
        
        if self.sharpcap_available:
            pass
        else:
            pass
        
        # Dictionary to map object combo display names to (actual_name, catalog_type)
        # catalog_type: 'V' for variable, 'C' for comparison, 'K' for check
        self.star_name_map = {}
        
        # Flag to prevent recursion during filter combo updates
        self.updating_filter_combo = False
        
        # Flag to prevent recursion during object combo updates
        self.updating_object_combo = False
        
        # Store currently selected target triple for GOTO functionality
        self.current_target = None
        
        # Two-stage auto-GOTO button state: 'comp' (slew to comparison first) or 'var'
        self.auto_goto_stage = 'comp'
        
        # Data arrays
        self.data_array = []
        self.saved_data = []
        self.saved_data_tab = []
        self.data_saved_count = 0  # Track how many entries have been saved to file
        self.data_notes = {}  # Dictionary to store notes: {data_line: note}
        
        # Added for memory test - set while the window is closing. The capture
        # loop now pumps UI messages during long waits, so a close can land in
        # the middle of a read; this lets the loop stop before it touches
        # controls that are being disposed.
        self._closing = False
        # Added for memory test - re-entrancy guard for trial mode, which runs
        # without disabling the START button
        self._trial_busy = False
        # Added for the sequence engine - set when a sequence run is aborted
        # (STOP SEQUENCE) or when the window is closing. Checked alongside
        # _closing in take_reading and the count loop. Always False outside a
        # sequence run, so the manual START path is unaffected.
        self._sequence_abort = False
        # Sequence engine state (Phase 2 - automated PEP runs)
        self.sequence = None              # currently loaded PEPSequence (or None)
        self._sequence = None             # the sequence being run
        self._sequence_running = False
        self._sequence_obs_count = 0
        self._sequence_start = None
        self._sequence_step_index = 0
        self._sequence_steps_total = 0
        # Added for memory test (Phase 2) - cached bold Font for the target
        # label, created on first use and disposed in _on_form_closed
        self._target_label_font = None
        # Added for memory test - per-instance memory tracking state
        self._mem_last = _MEM_BASELINE_BYTES
        self._mem_reading_count = 0
        self._mem_last_point = _MEM_BASELINE_BYTES  # Added for memory test - checkpoint baseline
        # Added for memory test - time-normalised leak rate tracking
        # _mem_last_* is shared by _log_memory_point checkpoints; the _mem_last_reading_*
        # set is dedicated to _print_memory_stats so an interleaved checkpoint cannot
        # shorten the interval used for the per-reading rate.
        self._mem_last_private = _MEM_BASELINE_BYTES
        self._mem_last_ts = DateTime.Now
        self._mem_last_reading_private = _MEM_BASELINE_BYTES
        self._mem_last_reading_ts = DateTime.Now
        
        # Setup window
        self.Text = "SSP Data Acquisition Program Version 3"
        self.Width = 1100
        self.Height = 450
        self.MinimumSize = Size(1100, 450)  # Prevent shrinking below original size
        self.StartPosition = FormStartPosition.CenterScreen
        self.FormBorderStyle = FormBorderStyle.Sizable  # Allow resizing
        self.MaximizeBox = True  # Enable maximize button
        
        # Add resize event handler
        self.Resize += self._on_window_resize
        
        # Add closing event handler to disconnect COM port
        self.FormClosing += self._on_form_closing
        # Added for memory test (Phase 2) - release the cached target-label font
        # once the form is fully closed (its controls no longer reference it)
        self.FormClosed += self._on_form_closed
        
        # Setup UI (must be done before starting timer)
        self._setup_menu()
        self._setup_ui()
        
        # Apply night mode if enabled
        if self.night_mode.is_night_mode:
            self.night_mode.apply_to_form(self)
        
        # Timer for time display (start AFTER UI is created)
        self.time_timer = Timer()
        self.time_timer.Interval = 1000  # 1 second
        self.time_timer.Tick += self._update_time_display
        self.time_timer.Start()
        
        # Update initial display
        self._update_status("Ready. Please connect to SSP photometer.")
    
    def _setup_menu(self):
        """Setup menu bar."""
        menu_strip = MenuStrip()
        
        # File Menu
        file_menu = ToolStripMenuItem("File")
        
        save_item = ToolStripMenuItem("Save Data")
        save_item.Click += self._on_save_data
        file_menu.DropDownItems.Add(save_item)
        
        clear_item = ToolStripMenuItem("Clear Data")
        clear_item.Click += self._on_clear_data
        file_menu.DropDownItems.Add(clear_item)
        
        file_menu.DropDownItems.Add(ToolStripSeparator())
        
        script_item = ToolStripMenuItem("Open Script File")
        script_item.Click += self._on_open_script
        file_menu.DropDownItems.Add(script_item)
        
        file_menu.DropDownItems.Add(ToolStripSeparator())
        
        quit_item = ToolStripMenuItem("Quit")
        quit_item.Click += self._on_quit
        file_menu.DropDownItems.Add(quit_item)
        
        menu_strip.Items.Add(file_menu)
        
        # Setup Menu
        setup_menu = ToolStripMenuItem("Setup")
        
        connect_item = ToolStripMenuItem("Connect to SSP")
        connect_item.Click += self._on_connect
        setup_menu.DropDownItems.Add(connect_item)
        
        disconnect_item = ToolStripMenuItem("Disconnect from SSP")
        disconnect_item.Click += self._on_disconnect
        setup_menu.DropDownItems.Add(disconnect_item)
        
        setup_menu.DropDownItems.Add(ToolStripSeparator())
        
        com_port_item = ToolStripMenuItem("Select SSP COM Port")
        com_port_item.Click += self._on_select_com_port
        setup_menu.DropDownItems.Add(com_port_item)
        
        setup_menu.DropDownItems.Add(ToolStripSeparator())
        
        device_type_item = ToolStripMenuItem("SSP Device Type...")
        device_type_item.Click += self._on_device_type
        setup_menu.DropDownItems.Add(device_type_item)
        
        setup_menu.DropDownItems.Add(ToolStripSeparator())
        
        filter_bar_item = ToolStripMenuItem("Filter Bar Setup")
        filter_bar_item.Click += self._on_filter_bar_setup
        setup_menu.DropDownItems.Add(filter_bar_item)
        
        auto_manual_item = ToolStripMenuItem("Auto/Manual Filters")
        auto_manual_item.Click += self._on_auto_manual_filters
        setup_menu.DropDownItems.Add(auto_manual_item)
        
        setup_menu.DropDownItems.Add(ToolStripSeparator())
        
        location_item = ToolStripMenuItem("Observer Location...")
        location_item.Click += self._on_observer_location
        setup_menu.DropDownItems.Add(location_item)
        
        setup_menu.DropDownItems.Add(ToolStripSeparator())
        
        night_item = ToolStripMenuItem("Night/Day Screen")
        night_item.Click += self._on_toggle_night_mode
        setup_menu.DropDownItems.Add(night_item)
        
        setup_menu.DropDownItems.Add(ToolStripSeparator())
        
        show_setup_item = ToolStripMenuItem("Show Setup Values")
        show_setup_item.Click += self._on_show_setup
        setup_menu.DropDownItems.Add(show_setup_item)
        
        menu_strip.Items.Add(setup_menu)
        
        # Catalog Menu
        catalog_menu = ToolStripMenuItem("Catalog")
        
        select_star_item = ToolStripMenuItem("Select Target Star")
        select_star_item.Click += self._on_select_star
        catalog_menu.DropDownItems.Add(select_star_item)
        
        select_extinction_item = ToolStripMenuItem("Select 1st Order Ext")
        select_extinction_item.Click += self._on_select_extinction_star
        catalog_menu.DropDownItems.Add(select_extinction_item)
        
        catalog_menu.DropDownItems.Add(ToolStripSeparator())
        
        reload_catalog_item = ToolStripMenuItem("Reload Catalog")
        reload_catalog_item.Click += self._on_reload_catalog
        catalog_menu.DropDownItems.Add(reload_catalog_item)
        
        menu_strip.Items.Add(catalog_menu)
        
        # Sequence Menu (Phase 2 - automated PEP runs)
        sequence_menu = ToolStripMenuItem("Sequence")
        
        run_seq_item = ToolStripMenuItem("Run Sequence")
        run_seq_item.Click += self._on_run_sequence
        sequence_menu.DropDownItems.Add(run_seq_item)
        
        stop_seq_item = ToolStripMenuItem("Stop Sequence")
        stop_seq_item.Click += self._on_stop_sequence
        sequence_menu.DropDownItems.Add(stop_seq_item)
        
        sequence_menu.DropDownItems.Add(ToolStripSeparator())
        
        edit_seq_item = ToolStripMenuItem("Edit Sequence...")
        edit_seq_item.Click += self._on_edit_sequence
        sequence_menu.DropDownItems.Add(edit_seq_item)
        
        load_tmpl_menu = ToolStripMenuItem("Load Template")
        for tmpl_name in ssp_sequence.build_templates().keys():
            tmpl_item = ToolStripMenuItem(tmpl_name)
            tmpl_item.Click += (lambda sender, event, n=tmpl_name:
                                self._on_load_template(n))
            load_tmpl_menu.DropDownItems.Add(tmpl_item)
        sequence_menu.DropDownItems.Add(load_tmpl_menu)
        
        export_seq_item = ToolStripMenuItem("Export Sequence...")
        export_seq_item.Click += self._on_export_sequence
        sequence_menu.DropDownItems.Add(export_seq_item)
        
        menu_strip.Items.Add(sequence_menu)
        
        self.MainMenuStrip = menu_strip
        self.Controls.Add(menu_strip)
    
    def _setup_ui(self):
        """Setup user interface controls."""
        y_offset = 30  # Account for menu bar
        
        # Top row - Filter, Gain, Integration, Interval, Count Mode
        x = 10
        y = y_offset + 10
        
        # Filter
        filter_label = Label()
        filter_label.Text = "Filter:"
        filter_label.Location = Point(x, y)
        filter_label.Size = Size(80, 20)
        self.Controls.Add(filter_label)
        
        self.filter_combo = ComboBox()
        self.filter_combo.Location = Point(x, y + 25)
        self.filter_combo.Size = Size(80, 25)
        self.filter_combo.DropDownStyle = ComboBoxStyle.DropDownList
        self.filter_combo.SelectedIndexChanged += self._on_filter_changed
        # Use new filter bar configuration system
        self._update_filter_combo()
        self.Controls.Add(self.filter_combo)
        
        x += 90
        
        # Gain
        gain_label = Label()
        gain_label.Text = "Gain:"
        gain_label.Location = Point(x, y)
        gain_label.Size = Size(70, 20)
        self.Controls.Add(gain_label)
        self.gain_combo = ComboBox()
        self.gain_combo.Location = Point(x, y + 25)
        self.gain_combo.Size = Size(70, 25)
        self.gain_combo.DropDownStyle = ComboBoxStyle.DropDownList
        self.gain_combo.Items.Add("1")
        self.gain_combo.Items.Add("10")
        self.gain_combo.Items.Add("100")
        self.gain_combo.SelectedIndex = self.config.get('last_gain_index', 0)
        self.Controls.Add(self.gain_combo)
        
        x += 80
        
        # Integration Time
        integ_label = Label()
        integ_label.Text = "Integ(sec):"
        integ_label.Location = Point(x, y)
        integ_label.Size = Size(80, 20)
        self.Controls.Add(integ_label)
        
        self.integ_combo = ComboBox()
        self.integ_combo.Location = Point(x, y + 25)
        self.integ_combo.Size = Size(80, 25)
        self.integ_combo.DropDownStyle = ComboBoxStyle.DropDownList
        self.integ_combo.Items.Add("0.02")  # SSP-5 only, very fast mode
        self.integ_combo.Items.Add("0.05")  # fast mode only
        self.integ_combo.Items.Add("0.10")  # fast mode only
        self.integ_combo.Items.Add("0.50")  # fast mode only
        self.integ_combo.Items.Add("1.00")  # fast or slow mode
        self.integ_combo.Items.Add("5.00")  # fast or slow mode
        self.integ_combo.Items.Add("10.00") # fast or slow mode
        self.integ_combo.SelectedIndex = self.config.get('last_integ_index', 4)  # Default to 1.00
        self.Controls.Add(self.integ_combo)
        
        x += 90
        
        # Interval
        interval_label = Label()
        interval_label.Text = "Interval:"
        interval_label.Location = Point(x, y)
        interval_label.Size = Size(70, 20)
        self.Controls.Add(interval_label)
        self.interval_combo = ComboBox()
        self.interval_combo.Location = Point(x, y + 25)
        self.interval_combo.Size = Size(70, 25)
        self.interval_combo.DropDownStyle = ComboBoxStyle.DropDownList
        self.interval_combo.Items.Add("1")    # slow mode only
        self.interval_combo.Items.Add("2")    # slow mode only
        self.interval_combo.Items.Add("3")    # slow mode only
        self.interval_combo.Items.Add("4")    # slow mode only
        self.interval_combo.Items.Add("6")    # slow mode only
        self.interval_combo.Items.Add("8")    # slow mode only
        self.interval_combo.Items.Add("100")  # fast mode only
        self.interval_combo.Items.Add("1000") # fast mode only
        self.interval_combo.Items.Add("2000") # fast and very fast modes
        self.interval_combo.Items.Add("5000") # fast and very fast modes
        self.interval_combo.SelectedIndex = self.config.get('last_interval_index', 0)
        self.Controls.Add(self.interval_combo)
        
        x += 80
        
        # Count Mode
        mode_label = Label()
        mode_label.Text = "Count:"
        mode_label.Location = Point(x, y)
        mode_label.Size = Size(80, 20)
        self.Controls.Add(mode_label)
        
        self.mode_combo = ComboBox()
        self.mode_combo.Location = Point(x, y + 25)
        self.mode_combo.Size = Size(80, 25)
        self.mode_combo.DropDownStyle = ComboBoxStyle.DropDownList
        self.mode_combo.Items.Add("trial")
        self.mode_combo.Items.Add("slow")
        self.mode_combo.Items.Add("fast")
        self.mode_combo.Items.Add("Vfast")
        self.mode_combo.SelectedIndex = self.config.get('last_mode_index', 1)
        self.Controls.Add(self.mode_combo)
        
        # Time display (top right)
        x = 600
        pc_label = Label()
        pc_label.Text = "PC:"
        pc_label.Location = Point(x, y)
        pc_label.Size = Size(50, 20)
        self.Controls.Add(pc_label)
        
        self.pc_time_text = TextBox()
        self.pc_time_text.Location = Point(x + 55, y)
        self.pc_time_text.Size = Size(90, 20)
        self.pc_time_text.ReadOnly = True
        self.Controls.Add(self.pc_time_text)
        
        utc_label = Label()
        utc_label.Text = "UTC:"
        utc_label.Location = Point(x, y + 25)
        utc_label.Size = Size(50, 20)
        self.Controls.Add(utc_label)
        
        self.utc_time_text = TextBox()
        self.utc_time_text.Location = Point(x + 55, y + 25)
        self.utc_time_text.Size = Size(90, 20)
        self.utc_time_text.ReadOnly = True
        self.Controls.Add(self.utc_time_text)
        
        # Second row - Object and Catalog
        y = y_offset + 80
        x = 10
        
        object_label = Label()
        object_label.Text = "Object:"
        object_label.Location = Point(x, y)
        object_label.Size = Size(150, 20)
        self.Controls.Add(object_label)
        self.object_combo = ComboBox()
        self.object_combo.Location = Point(x, y + 25)
        self.object_combo.Size = Size(150, 25)
        self.object_combo.DropDownStyle = ComboBoxStyle.DropDownList
        self.object_combo.Items.Add("New Object")
        self.object_combo.Items.Add("SKY")
        self.object_combo.Items.Add("SKYNEXT")
        self.object_combo.Items.Add("SKYLAST")
        self.object_combo.Items.Add("CATALOG")
        self.object_combo.SelectedIndex = 0
        self.object_combo.SelectionChangeCommitted += self._on_object_changed
        self.Controls.Add(self.object_combo)
        
        x += 160
        
        catalog_label = Label()
        catalog_label.Text = "Catalog:"
        catalog_label.Location = Point(x, y)
        catalog_label.Size = Size(100, 20)
        self.Controls.Add(catalog_label)
        
        self.catalog_combo = ComboBox()
        self.catalog_combo.Location = Point(x, y + 25)
        self.catalog_combo.Size = Size(100, 25)
        self.catalog_combo.DropDownStyle = ComboBoxStyle.DropDownList
        self.catalog_combo.Items.Add("Astar")
        self.catalog_combo.Items.Add("Foe")
        self.catalog_combo.Items.Add("Soe")
        self.catalog_combo.Items.Add("Comp")
        self.catalog_combo.Items.Add("Var")
        self.catalog_combo.Items.Add("Moving")
        self.catalog_combo.Items.Add("Trans")
        self.catalog_combo.Items.Add("Q'check")
        self.catalog_combo.SelectedIndex = 0
        self.Controls.Add(self.catalog_combo)
        
        # Current target label (shows selected var/comp/check)
        x = 10
        y = y + 60
        self.current_target_label = Label()
        self.current_target_label.Text = "No target selected - Use Catalog > Select Target Star"
        self.current_target_label.Location = Point(x, y)
        # Narrower than the old 800 so the "Plate Solve and Sync" checkbox can sit
        # on this row, left-aligned with the GOTO button, without overlapping it.
        # AutoEllipsis marks the rare over-long target line instead of hard-clipping.
        self.current_target_label.Size = Size(390, 25)
        self.current_target_label.AutoEllipsis = True
        self.current_target_label.ForeColor = Color.Gray
        self.current_target_label.Font = Font("Arial", 9, FontStyle.Italic)
        self.Controls.Add(self.current_target_label)
        
        # START button - align with Object/Catalog dropdowns
        x = 300
        y = y_offset + 80  # Same as dropdown row
        self.start_button = Button()
        self.start_button.Text = "START"
        self.start_button.Location = Point(x, y + 25)  # Align with combobox position
        self.start_button.Size = Size(100, 30)
        self.start_button.Click += self._on_start
        self.Controls.Add(self.start_button)
        
        # Status/Message area
        y = y_offset + 170
        x = 10
        
        status_label = Label()
        status_label.Text = "Status:"
        status_label.Location = Point(x, y)
        status_label.Size = Size(820, 25)
        self.Controls.Add(status_label)
        self.status_text = TextBox()
        self.status_text.Location = Point(x, y + 20)
        self.status_text.Size = Size(820, 20)
        self.status_text.Multiline = False
        self.status_text.ReadOnly = True
        self.Controls.Add(self.status_text)
        
        # Data display grid
        y = y_offset + 215
        data_label = Label()
        data_label.Text = "Data:"
        data_label.Location = Point(x, y)
        data_label.Size = Size(1060, 25)
        self.Controls.Add(data_label)
        
        # Fixed column header (doesn't scroll)
        self.header_label = Label()
        self.header_label.Text = "DATE       TIME     C    OBJECT          F  COUNT  COUNT  COUNT  COUNT  IT GN NOTES"
        self.header_label.Location = Point(x, y + 28)
        self.header_label.Size = Size(1060, 15)
        self.header_label.Font = Font("Courier New", 8)
        self.header_label.BackColor = Color.LightGray
        self.Controls.Add(self.header_label)
        
        self.data_listbox = ListBox()
        self.data_listbox.Location = Point(x, y + 46)
        self.data_listbox.Size = Size(1060, 65)
        self.data_listbox.Font = Font("Courier New", 8)
        self.data_listbox.HorizontalScrollbar = True
        self.data_listbox.DoubleClick += self._on_data_doubleclick
        self.Controls.Add(self.data_listbox)
        
        # Store initial positions for resize calculations
        self.data_listbox_initial_width = 820
        self.data_listbox_initial_height = 65
        self.header_label_initial_width = 820
        
        # GOTO button (added last so it's on top of z-order, only in SharpCap mode)
        if self.sharpcap_available:
            # Position next to START button at same Y coordinate
            start_y = self.start_button.Location.Y
            start_x = self.start_button.Location.X + self.start_button.Size.Width + 10  # 10px gap
            self.goto_button = Button()
            self.goto_button.Text = "GOTO Selected Star"
            self.goto_button.Location = Point(start_x, start_y)
            self.goto_button.Size = Size(150, 30)  # Match START button height
            self.goto_button.Enabled = False  # Disabled until target selected
            self.goto_button.Click += self._on_goto_target
            self.Controls.Add(self.goto_button)
            self.goto_button.BringToFront()  # Raise AFTER Add - z-order requires it
            
            # Two-stage GOTO button (Comp <-> Var) to the right of the GOTO button
            stage_x = start_x + self.goto_button.Size.Width + 10  # 10px gap
            self.goto_stage_button = Button()
            self.goto_stage_button.Text = "GOTO Comp"
            self.goto_stage_button.Location = Point(stage_x, start_y)
            self.goto_stage_button.Size = Size(150, 30)  # Match GOTO button size
            self.goto_stage_button.Enabled = False  # Disabled until target selected
            self.goto_stage_button.Click += self._on_goto_stage
            self.Controls.Add(self.goto_stage_button)
            self.goto_stage_button.BringToFront()  # Raise AFTER Add - z-order requires it
            
            # "Plate Solve and Sync" option, on the current-target label row,
            # left-aligned with the "GOTO Selected Star" button. When ticked,
            # every GOTO (from either GOTO button) runs a SharpCap plate solve +
            # sync after the mount settles. The state is persisted in the config.
            self.plate_solve_sync_checkbox = CheckBox()
            self.plate_solve_sync_checkbox.Text = "Plate Solve and Sync"
            self.plate_solve_sync_checkbox.Location = Point(
                start_x,
                self.current_target_label.Location.Y)
            self.plate_solve_sync_checkbox.Size = Size(200, 22)
            self.plate_solve_sync_checkbox.Checked = (self.config.get('plate_solve_sync', 0) == 1)
            self.plate_solve_sync_checkbox.CheckedChanged += self._on_plate_solve_sync_changed
            self.Controls.Add(self.plate_solve_sync_checkbox)
            self.plate_solve_sync_checkbox.BringToFront()  # Raise AFTER Add - z-order requires it
        else:
            pass

        # RUN SEQ / STOP buttons (Phase 2) - created in SharpCap and standalone
        if self.config.get('sequence_enable_run_button', 1):
            run_y = self.start_button.Location.Y
            if self.sharpcap_available and hasattr(self, 'goto_stage_button'):
                run_x = (self.goto_stage_button.Location.X +
                         self.goto_stage_button.Size.Width + 10)
            else:
                run_x = (self.start_button.Location.X +
                         self.start_button.Size.Width + 10)
            self.run_seq_button = Button()
            self.run_seq_button.Text = "RUN SEQ"
            self.run_seq_button.Location = Point(run_x, run_y)
            self.run_seq_button.Size = Size(100, 30)
            self.run_seq_button.Click += self._on_run_sequence
            self.Controls.Add(self.run_seq_button)
            self.run_seq_button.BringToFront()  # Raise AFTER Add - z-order requires it

            self.stop_seq_button = Button()
            self.stop_seq_button.Text = "STOP"
            self.stop_seq_button.Location = Point(run_x + 110, run_y)
            self.stop_seq_button.Size = Size(80, 30)
            self.stop_seq_button.Enabled = False
            self.stop_seq_button.Click += self._on_stop_sequence
            self.Controls.Add(self.stop_seq_button)
            self.stop_seq_button.BringToFront()  # Raise AFTER Add - z-order requires it
    
    def _update_time_display(self, sender, event):
        """Update time display."""
        # PC local time
        pc_time = DateTime.Now
        self.pc_time_text.Text = pc_time.ToString("HH:mm:ss")
        
        # UTC time (for data collection)
        utc_time = DateTime.UtcNow
        self.utc_time_text.Text = utc_time.ToString("HH:mm:ss")
    
    def _on_window_resize(self, sender, event):
        """Handle window resize to adjust data display size."""
        # Calculate size changes from original window size
        width_delta = self.ClientSize.Width - 1100
        height_delta = self.ClientSize.Height - (345 - 30)  # Subtract menu height
        
        # Adjust data listbox size (expand/contract with window)
        new_width = self.data_listbox_initial_width + width_delta
        new_height = self.data_listbox_initial_height + height_delta
        
        if new_width > 0 and new_height > 0:
            self.data_listbox.Size = Size(new_width, new_height)
            self.header_label.Size = Size(new_width, 15)
    
    def _update_status(self, message):
        """Update status message."""
        timestamp = DateTime.Now.ToString("HH:mm:ss")
        self.status_text.Text = "[" + timestamp + "] " + message
        self.status_text.Refresh()  # Force immediate UI update
        Application.DoEvents()  # Process pending UI events
    
    def _on_data_doubleclick_old_buggy(self, sender, event):
        """Original buggy version of handle double-click on data listbox to edit notes."""
        if self.data_listbox.SelectedIndex < 0:
            return
        
        selected_item = self.data_listbox.Items[self.data_listbox.SelectedIndex]
        selected_text = str(selected_item)
        
        # Extract the data line (without existing note)
        # Look for data line in notes dictionary
        data_line = selected_text
        current_note = ""
        
        # Try to find matching key in notes dictionary
        for key in self.data_notes:
            if selected_text.startswith(key):
                data_line = key
                current_note = self.data_notes[key]
                break
        
        # If no match found, the selected text IS the data line (no note yet)
        if data_line == selected_text and len(self.data_notes) > 0:
            # Check if this line matches start of any saved data
            for saved_line in self.saved_data:
                if saved_line.startswith(selected_text[:50]):  # Match by substantial prefix
                    # Extract base data without any existing note
                    parts = saved_line.split()
                    if len(parts) > 10:  # Should have DATE TIME C OBJECT F COUNT... IT GN at minimum
                        # Reconstruct data line without note
                        data_line = saved_line
                        break
        
        # Show input dialog for note
        from Microsoft.VisualBasic import Interaction
        new_note = Interaction.InputBox(
            "Enter note/comment for this observation:",
            "Edit Note",
            current_note,
            -1, -1
        )
        
        if new_note is not None and new_note != current_note:  # User clicked OK and changed
            # Store or update note
            if new_note.strip():
                self.data_notes[data_line] = new_note.strip()
                # Update display
                updated_line = data_line + " " + new_note.strip()
                self.data_listbox.Items[self.data_listbox.SelectedIndex] = updated_line
            else:
                # Remove note if empty
                if data_line in self.data_notes:
                    del self.data_notes[data_line]
                self.data_listbox.Items[self.data_listbox.SelectedIndex] = data_line
            
            # Update in data arrays - more robust matching
            date_time_key = data_line[:17] if len(data_line) >= 17 else data_line  # MM-dd-yyyy HH:mm
            
            for i in range(len(self.data_array)):
                if self.data_array[i].startswith(date_time_key):
                    if new_note.strip():
                        # Find the base line without any existing note
                        base_line = self.data_array[i]
                        for key in self.data_notes:
                            if self.data_array[i].startswith(key) and key != data_line:
                                base_line = key
                                break
                        self.data_array[i] = data_line + " " + new_note.strip()
                    else:
                        self.data_array[i] = data_line
                    break
            
            for i in range(len(self.saved_data)):
                if self.saved_data[i].startswith(date_time_key):
                    if new_note.strip():
                        self.saved_data[i] = data_line + " " + new_note.strip()
                        self.saved_data_tab[i] = self.saved_data_tab[i] + "\t" + new_note.strip()
                    else:
                        self.saved_data[i] = data_line
                    break

    def _on_data_doubleclick(self, sender, event):
        """Handle double-click on data listbox to edit notes."""
        if self.data_listbox.SelectedIndex < 0:
            return
        
        # Get the selected index in the listbox
        selected_index = self.data_listbox.SelectedIndex
        
        # The listbox displays data in reverse chronological order (newest first)
        # self.data_array is also in reverse chronological order (newest first via insert(0, ...))
        # self.saved_data and self.saved_data_tab are in chronological order (oldest first)
        
        # Calculate the corresponding index in the chronological arrays
        # Formula: chronological_index = (total_items - 1) - selected_index
        total_items = len(self.data_array)
        if total_items == 0:
            return
        
        chronological_index = (total_items - 1) - selected_index
        
        # Get the selected item text
        selected_item = self.data_listbox.Items[selected_index]
        selected_text = str(selected_item)
        
        # Extract base data line without any existing note
        # Check if the selected text contains a note by looking in data_notes
        data_line = selected_text
        current_note = ""
        
        # Try to find if this selected text corresponds to a data_line with note
        for key, note_value in self.data_notes.items():
            if selected_text == key + " " + note_value:
                # This is a data line with a note
                data_line = key
                current_note = note_value
                break
            elif selected_text.startswith(key) and selected_text[len(key):].strip() == note_value:
                # Handle potential extra spaces
                data_line = key
                current_note = note_value
                break
        
        # If no note found but selected_text might be in data_notes (as a key with empty note)
        if current_note == "" and selected_text in self.data_notes:
            # This shouldn't normally happen, but handle it
            current_note = self.data_notes[selected_text]
        
        # Show input dialog for note
        from Microsoft.VisualBasic import Interaction
        new_note = Interaction.InputBox(
            "Enter note/comment for this observation:",
            "Edit Note",
            current_note,
            -1, -1
        )
        
        if new_note is not None and new_note != current_note:  # User clicked OK and changed
            # Store or update note
            if new_note.strip():
                self.data_notes[data_line] = new_note.strip()
                # Update display
                updated_line = data_line + " " + new_note.strip()
                self.data_listbox.Items[selected_index] = updated_line
            else:
                # Remove note if empty
                if data_line in self.data_notes:
                    del self.data_notes[data_line]
                self.data_listbox.Items[selected_index] = data_line
            
            # Update in data arrays using index-based approach
            # Update data_array (reverse chronological order)
            if selected_index < len(self.data_array):
                if new_note.strip():
                    self.data_array[selected_index] = data_line + " " + new_note.strip()
                else:
                    self.data_array[selected_index] = data_line
            
            # Update saved_data and saved_data_tab (chronological order)
            if 0 <= chronological_index < len(self.saved_data):
                if new_note.strip():
                    self.saved_data[chronological_index] = data_line + " " + new_note.strip()
                    # For tab data, append note as a new tab-separated column
                    # First check if the tab line already has a note column
                    tab_line = self.saved_data_tab[chronological_index]
                    # Split by tabs to see if it already has a note
                    parts = tab_line.split('\t')
                    # The last part after the gain is the note if it exists
                    if len(parts) > 8:  # Already has note column
                        # Replace the note part
                        parts[-1] = new_note.strip()
                        self.saved_data_tab[chronological_index] = '\t'.join(parts)
                    else:
                        # Add note as new column
                        self.saved_data_tab[chronological_index] = tab_line + "\t" + new_note.strip()
                else:
                    self.saved_data[chronological_index] = data_line
                    # Remove note column from tab data
                    tab_line = self.saved_data_tab[chronological_index]
                    parts = tab_line.split('\t')
                    if len(parts) > 8:  # Has note column
                        # Keep only the first 8 columns (date, time, catalog, object, filter, counts, integ, gain)
                        self.saved_data_tab[chronological_index] = '\t'.join(parts[:8])

    def _on_save_data(self, sender, event):
        """Handle Save Data menu item."""
        if len(self.saved_data) == 0:
            MessageBox.Show("No data to save", "Save Data", MessageBoxButtons.OK, MessageBoxIcon.Information)
            return
        
        sfd = SaveFileDialog()
        sfd.Filter = "Raw Data Files (*.raw)|*.raw|All Files (*.*)|*.*"
        sfd.DefaultExt = "raw"
        
        last_dir = self.config.get('last_data_directory', '')
        if last_dir:
            sfd.InitialDirectory = last_dir
        
        if sfd.ShowDialog() == DialogResult.OK:
            # Check if file exists (append mode) or new file (get header info)
            file_exists = System.IO.File.Exists(sfd.FileName)
            
            if not file_exists:
                # Get header information for new file
                header_info = self._get_header_information()
                if header_info is None:
                    return  # User cancelled
            else:
                header_info = None  # Will append without new header
            
            try:
                # Save data in SSPDataq .raw format
                self._save_raw_file(sfd.FileName, header_info)
                # Save data in .tab format
                self._save_tab_file(sfd.FileName.replace('.raw','.tab'), header_info)
                self.data_saved_count = len(self.saved_data)  # Update saved count
                self.config.set('last_data_directory', Path.GetDirectoryName(sfd.FileName))
                self.config.save()
                
                if file_exists:
                    self._update_status("Data appended to: " + sfd.FileName)
                    MessageBox.Show("Data appended successfully", "Save Data",
                                  MessageBoxButtons.OK, MessageBoxIcon.Information)
                else:
                    self._update_status("Data saved to: " + sfd.FileName)
                    MessageBox.Show("Data saved successfully", "Save Data",
                                  MessageBoxButtons.OK, MessageBoxIcon.Information)
            except Exception as e:
                MessageBox.Show("Error saving file: " + str(e), "Error", MessageBoxButtons.OK, MessageBoxIcon.Error)
                self._update_status("Error saving file: " + str(e))
    
    def _get_header_information(self):
        """Display dialog to get header information for new data file.
        
        Returns:
            dict: {'telescope': str, 'observer': str, 'conditions': str} or None if cancelled
        """
        # Create form
        dialog = Form()
        dialog.Text = "Data File Header Information"
        dialog.Width = 315
        dialog.Height = 230
        dialog.StartPosition = FormStartPosition.CenterParent
        dialog.FormBorderStyle = FormBorderStyle.FixedDialog
        dialog.MaximizeBox = False
        dialog.MinimizeBox = False
        
        # Create labels and textboxes
        y = 15
        
        tel_label = Label()
        tel_label.Text = "Telescope:"
        tel_label.Location = Point(15, y)
        tel_label.Size = Size(80, 20)
        dialog.Controls.Add(tel_label)
        
        tel_textbox = TextBox()
        tel_textbox.Location = Point(100, y)
        tel_textbox.Size = Size(180, 25)
        tel_textbox.Text = self.config.get('telescope_name', 'Enter Telescope')
        dialog.Controls.Add(tel_textbox)
        
        y += 35
        
        obs_label = Label()
        obs_label.Text = "Observer:"
        obs_label.Location = Point(15, y)
        obs_label.Size = Size(80, 20)
        dialog.Controls.Add(obs_label)
        
        obs_textbox = TextBox()
        obs_textbox.Location = Point(100, y)
        obs_textbox.Size = Size(180, 25)
        obs_textbox.Text = self.config.get('observer_name', 'Enter Observer')
        dialog.Controls.Add(obs_textbox)
        
        y += 35
        
        cond_label = Label()
        cond_label.Text = "Conditions:"
        cond_label.Location = Point(15, y)
        cond_label.Size = Size(80, 20)
        dialog.Controls.Add(cond_label)
        
        cond_textbox = TextBox()
        cond_textbox.Location = Point(100, y)
        cond_textbox.Size = Size(180, 25)
        cond_textbox.Text = self.config.get('last_conditions', '')
        dialog.Controls.Add(cond_textbox)
        
        y += 45
        
        # Accept button
        accept_button = Button()
        accept_button.Text = "Accept"
        accept_button.Location = Point(80, y)
        accept_button.Size = Size(131, 31)
        accept_button.DialogResult = DialogResult.OK
        dialog.Controls.Add(accept_button)
        dialog.AcceptButton = accept_button
        
        # Show dialog
        if dialog.ShowDialog() == DialogResult.OK:
            telescope = tel_textbox.Text.strip()
            observer = obs_textbox.Text.strip()
            conditions = cond_textbox.Text.strip()
            
            # Save telescope and observer to config if changed
            if telescope != self.config.get('telescope_name', ''):
                self.config.set('telescope_name', telescope)
            if observer != self.config.get('observer_name', ''):
                self.config.set('observer_name', observer)
            # Save last conditions
            self.config.set('last_conditions', conditions)
            self.config.save()
            
            return {
                'telescope': telescope,
                'observer': observer,
                'conditions': conditions
            }
        
        return None
    
    def _save_raw_file(self, filename, header_info=None):
        """Save data in SSPDataq .raw file format.
        
        File format:
        FILENAME=filename.RAW       RAW OUTPUT DATA FROM SSP DATA ACQUISITION PROGRAM
        UT DATE= MM/DD/YYYY   TELESCOPE= [name]      OBSERVER= [name]
        CONDITIONS= [description]
        MO-DY-YEAR    UT    CAT  OBJECT         F  ----------COUNTS---------- INT SCLE COMMENTS
        [data lines]
        
        Args:
            filename: Full path to save file
            header_info: dict with telescope, observer, conditions (None for append mode)
        """
        import System.IO
        
        if header_info is not None:
            # New file - write header and all data
            # Get current UT date for header
            ut_now = DateTime.UtcNow
            ut_date_header = ut_now.ToString("MM/dd/yyyy")
            
            # Extract just the filename for header
            file_only = System.IO.Path.GetFileName(filename)
            
            with open(filename, 'w') as f:
                # Write header - note leading space on all lines to match original
                f.write(" FILENAME=" + file_only.upper() + "       RAW OUTPUT DATA FROM SSP DATA ACQUISITION PROGRAM\n")
                f.write(" UT DATE= " + ut_date_header + "   TELESCOPE= " + header_info['telescope'].upper() + 
                       "      OBSERVER= " + header_info['observer'].upper() + "\n")
                f.write(" CONDITIONS= " + header_info['conditions'].upper() + "\n")
                f.write(" MO-DY-YEAR    UT    CAT  OBJECT         F  ----------COUNTS---------- INT SCLE COMMENTS\n")
                
                # Write data lines (in original order, not display order)
                for data_line in self.saved_data:
                    f.write(" " + data_line + "\n")
        else:
            # Append mode - only add new data since last save
            with open(filename, 'a') as f:
                for i in range(self.data_saved_count, len(self.saved_data)):
                    f.write(" " + self.saved_data[i] + "\n")

    def _save_tab_file(self, filename, header_info=None):
        """Save data in SSPDataq tab file format suitable for import into spreadsheet applications and conforming better to the PEP analysis spreadsheet
        
        File format:
        FILENAME=filename.RAW       RAW OUTPUT DATA FROM SSP DATA ACQUISITION PROGRAM
        UT DATE= MM/DD/YYYY   TELESCOPE= [name]      OBSERVER= [name]
        CONDITIONS= [description]
        CAT OBJECT F MO-DY-YEAR UT COUNT1 COUNT2 COUNT3 COUNT4 INT SCLE COMMENTS
        [data lines]
        
        Args:
            filename: Full path to save file
            header_info: dict with telescope, observer, conditions (None for append mode)
        """
        import System.IO
        
        if header_info is not None:
            # New file - write header and all data
            # Get current UT date for header
            ut_now = DateTime.UtcNow
            ut_date_header = ut_now.ToString("MM/dd/yyyy")
            
            # Extract just the filename for header
            file_only = System.IO.Path.GetFileName(filename)
            
            with open(filename, 'w') as f:
                # Write header - note leading space on all lines to match original
                f.write(" FILENAME=" + file_only.upper() + "       RAW OUTPUT DATA FROM SSP DATA ACQUISITION PROGRAM\n")
                f.write(" UT DATE= " + ut_date_header + "   TELESCOPE= " + header_info['telescope'].upper() + 
                       "      OBSERVER= " + header_info['observer'].upper() + "\n")
                f.write(" CONDITIONS= " + header_info['conditions'].upper() + "\n")
                f.write("CAT\tOBJECT\tF\tMO-DY-YEAR\tUT\tCOUNT1\tCOUNT2\tCOUNT3\tCOUNT4\tINT\tSCLE\tCOMMENTS\n")
                
                # Write data lines (in original order, not display order)
                for data_line in self.saved_data_tab:
                    f.write(data_line + "\n")
        else:
            # Append mode - only add new data since last save
            with open(filename, 'a') as f:
                for i in range(self.data_saved_count, len(self.saved_data_tab)):
                    f.write(self.saved_data_tab[i] + "\n")
    
    def _on_clear_data(self, sender, event):
        """Handle Clear Data menu item."""
        if len(self.data_array) == 0:
            return
        
        result = MessageBox.Show("Do you wish to clear the data array?", "Clear Data", 
                                MessageBoxButtons.YesNo, MessageBoxIcon.Question)
        if result == DialogResult.Yes:
            self.data_array = []
            self.saved_data = []
            self.saved_data_tab = []
            self.data_saved_count = 0  # Reset saved count
            self.data_notes = {}  # Clear notes dictionary
            self.data_listbox.Items.Clear()
            self._update_status("Data array cleared")
    
    def _on_open_script(self, sender, event):
        """Load a .ssp-style sequence file (revives the legacy script menu)."""
        dialog = OpenFileDialog()
        dialog.Filter = ("SSP sequence files (*.ssp;*.txt)|*.ssp;*.txt|"
                         "All files (*.*)|*.*")
        dialog.Title = "Open Sequence File"
        if dialog.ShowDialog(self) != DialogResult.OK:
            return
        try:
            seq = ssp_sequence.load_ssp_text(dialog.FileName)
        except Exception as e:
            MessageBox.Show("Could not load sequence:\n" + str(e),
                            "Open Sequence",
                            MessageBoxButtons.OK, MessageBoxIcon.Error)
            return
        self.sequence = seq
        self.config.set('last_sequence_name', seq.name)
        self.config.save()
        self._update_status("Loaded sequence '%s' (%d steps)"
                            % (seq.name, seq.get_count()))
    
    def _on_quit(self, sender, event):
        """Handle Quit menu item."""
        # Save last used values
        self.config.set('last_gain_index', self.gain_combo.SelectedIndex)
        self.config.set('last_integ_index', self.integ_combo.SelectedIndex)
        self.config.set('last_interval_index', self.interval_combo.SelectedIndex)
        self.config.set('last_mode_index', self.mode_combo.SelectedIndex)
        self.config.save()
        
        # Disconnect if connected
        if self.comm.is_connected:
            self.comm.disconnect()
        
        # Cleanup timer
        self.time_timer.Stop()
        self.time_timer.Dispose()
        self.Close()
    
    def _on_connect(self, sender, event):
        """Handle Connect to SSP menu item."""
        com_port = self.config.get('com_port', 0)
        success, message = self.comm.connect(com_port)
        self._update_status(message)
        
        if success:
            MessageBox.Show(message, "Connection", MessageBoxButtons.OK, MessageBoxIcon.Information)
    
    def _on_disconnect(self, sender, event):
        """Handle Disconnect from SSP menu item."""
        success, message = self.comm.disconnect()
        self._update_status(message)
        
        if success:
            MessageBox.Show(message, "Disconnection", MessageBoxButtons.OK, MessageBoxIcon.Information)
    
    def _on_form_closing(self, sender, event):
        """Handle form closing event - disconnect COM port and cleanup timer."""
        # Added for memory test - signal any in-progress acquisition to stop
        self._closing = True
        
        if self.comm.is_connected:
            success, message = self.comm.disconnect()
            self._update_status(message)
        
        # Cleanup timer (important for memory management)
        if hasattr(self, 'time_timer'):
            self.time_timer.Stop()
            self.time_timer.Dispose()
    
    def _on_form_closed(self, sender, event):
        """Added for memory test (Phase 2) - release the cached target-label font.
        
        Disposed here rather than in _on_form_closing because the label is still
        live at FormClosing, and Control.Dispose() does not dispose a Font that
        was assigned to it. Once FormClosed has fired, nothing references it.
        """
        try:
            if getattr(self, '_target_label_font', None) is not None:
                self._target_label_font.Dispose()
                self._target_label_font = None
        except Exception:
            pass
    
    def _on_select_com_port(self, sender, event):
        """Handle Select SSP COM Port menu item."""
        current_port = self.config.get('com_port', 0)
        dialog = ssp_dialogs.COMPortDialog(current_port)
        self.night_mode.apply_to_form(dialog)
        
        if dialog.ShowDialog() == DialogResult.OK:
            self.config.set('com_port', dialog.selected_port)
            self.config.save()
            self._update_status("COM port set to: COM" + str(dialog.selected_port))
    
    def _on_toggle_night_mode(self, sender, event):
        """Handle Night/Day Screen menu item."""
        current = self.config.get('night_flag', 0)
        if current == 0:
            result = MessageBox.Show("Set to Night Mode?", "Night Mode", 
                                    MessageBoxButtons.YesNo, MessageBoxIcon.Question)
            if result == DialogResult.Yes:
                self.config.set('night_flag', 1)
                self.night_mode.set_night_mode(True)
                self._update_status("Night mode enabled")
        else:
            result = MessageBox.Show("Return to day mode?", "Day Mode", 
                                    MessageBoxButtons.YesNo, MessageBoxIcon.Question)
            if result == DialogResult.Yes:
                self.config.set('night_flag', 0)
                self.night_mode.set_night_mode(False)
                self._update_status("Day mode enabled")
        
        self.config.save()
        self.night_mode.apply_to_form(self)
    
    def _on_show_setup(self, sender, event):
        """Handle Show Setup Values menu item."""
        com_port = self.config.get('com_port', 0)
        night = "On" if self.config.get('night_flag', 0) == 1 else "Off"
        
        message = "Current Setup:\n\n"
        message += "COM Port: " + str(com_port) + "\n"
        message += "Time: UTC (no timezone offset)\n"
        message += "Night Mode: " + night + "\n"
        message += "Connected: " + ("Yes" if self.comm.is_connected else "No")
        
        MessageBox.Show(message, "Setup Values", MessageBoxButtons.OK, MessageBoxIcon.Information)
    
    def _on_filter_bar_setup(self, sender, event):
        """Handle Filter Bar Setup menu item."""
        # Get current filter bar configuration
        filter_bars = self.config.get('filter_bars', [
            ['U', 'B', 'V', 'R', 'I', 'Dark'],
            ['u', 'g', 'r', 'i', 'z', 'Y'],
            ['f13', 'f14', 'f15', 'f16', 'f17', 'f18']
        ])
        active_bar = self.config.get('active_filter_bar', 1)
        
        # Show filter bar setup dialog
        dialog = ssp_dialogs.FilterBarSetupDialog(filter_bars, active_bar)
        self.night_mode.apply_to_form(dialog)
        
        if dialog.ShowDialog() == DialogResult.OK:
            # Save changes
            self.config.set('filter_bars', dialog.filter_bars)
            self.config.set('active_filter_bar', dialog.active_bar)
            self.config.save()
            
            # Update filter combo box with new active bar
            self._update_filter_combo()
            
            self._update_status("Filter bar configuration saved")
    
    def _on_auto_manual_filters(self, sender, event):
        """Handle Auto/Manual Filters menu item."""
        current_mode = self.config.get('auto_manual', 'M')
        
        # Show dialog with current mode
        current_text = "Auto (6-position slider)" if current_mode == 'A' else "Manual (2-position slider)"
        
        message = "Current mode: " + current_text + "\n\n"
        message += "Select filter mode:\n\n"
        message += "Yes = Auto Filters (6-position slider)\n"
        message += "No = Manual Filters (2-position slider)"
        
        result = MessageBox.Show(message, "Auto/Manual Filter Mode", 
                                MessageBoxButtons.YesNoCancel, MessageBoxIcon.Question)
        
        if result == DialogResult.Yes:
            self._set_auto_manual('A')
        elif result == DialogResult.No:
            self._set_auto_manual('M')
        # Cancel = do nothing
    
    def _set_auto_manual(self, mode):
        """Set auto/manual filter mode."""
        # If switching to Auto mode, show hardware requirement warning
        if mode == 'A':
            warning_msg = "Auto filter mode requires an SSP photometer with a 6-position automated filter slider.\n\n"
            warning_msg += "Do you have this hardware installed?\n\n"
            warning_msg += "YES = I have automated filter slider hardware\n"
            warning_msg += "NO = I only have manual 2-position slider\n\n"
            warning_msg += "Note: If you select YES but don't have the hardware, the SSP will appear to\n"
            warning_msg += "respond to filter commands but no physical filter movement will occur."
            
            result = MessageBox.Show(warning_msg, "Auto Filter Hardware Check",
                                   MessageBoxButtons.YesNo, MessageBoxIcon.Warning)
            
            if result != DialogResult.Yes:
                self._update_status("Auto filter mode cancelled - no hardware")
                return
        
        self.config.set('auto_manual', mode)
        self.config.save()
        
        if mode == 'A':
            self._update_status("Set for auto 6-position filter slider")
            MessageBox.Show("Filter mode set to: Auto (6-position slider)\n\n" +
                          "The SSP will automatically move the filter slider when you change filters.",
                          "Auto Filter Mode", MessageBoxButtons.OK, MessageBoxIcon.Information)
        else:
            self._update_status("Set for manual 2-position slider")
            MessageBox.Show("Filter mode set to: Manual (2-position slider)\n\n" +
                          "You will need to manually change filters when prompted.",
                          "Manual Filter Mode", MessageBoxButtons.OK, MessageBoxIcon.Information)
    
    def _on_device_type(self, sender, event):
        """Handle SSP Device Type menu item."""
        try:
            # Create a simple dialog for device type selection
            dialog = Form()
            dialog.Text = "SSP Device Type Configuration"
            dialog.Width = 400
            dialog.Height = 250
            dialog.StartPosition = FormStartPosition.CenterParent
            
            # Info label
            info_label = Label()
            info_label.Text = "Select SSP device type for communication timing:"
            info_label.Location = Point(20, 20)
            info_label.Size = Size(350, 40)
            info_label.Font = Font(info_label.Font.FontFamily, 9)
            dialog.Controls.Add(info_label)
            
            # Auto detection radio
            auto_radio = RadioButton()
            auto_radio.Text = "Auto (recommended) - Try SSP3 timing first, then SSP5A"
            auto_radio.Location = Point(40, 70)
            auto_radio.Size = Size(330, 30)
            auto_radio.Font = Font(auto_radio.Font.FontFamily, 9)
            dialog.Controls.Add(auto_radio)
            
            # SSP3 radio
            ssp3_radio = RadioButton()
            ssp3_radio.Text = "SSP3 - Original SSPDataq3 hardware (built-in serial)"
            ssp3_radio.Location = Point(40, 100)
            ssp3_radio.Size = Size(330, 30)
            ssp3_radio.Font = Font(ssp3_radio.Font.FontFamily, 9)
            dialog.Controls.Add(ssp3_radio)
            
            # SSP5A radio
            ssp5a_radio = RadioButton()
            ssp5a_radio.Text = "SSP5A - Arduino-based hardware (requires boot delay)"
            ssp5a_radio.Location = Point(40, 130)
            ssp5a_radio.Size = Size(330, 30)
            ssp5a_radio.Font = Font(ssp5a_radio.Font.FontFamily, 9)
            dialog.Controls.Add(ssp5a_radio)
            
            # Set current selection
            current_type = self.config.get('device_type', 'auto')
            if current_type == 'ssp3':
                ssp3_radio.Checked = True
            elif current_type == 'ssp5a':
                ssp5a_radio.Checked = True
            else:
                auto_radio.Checked = True
            
            # Current detection info
            detected = self.config.get('detected_device_type', 'unknown')
            detect_label = Label()
            detect_label.Text = f"Last detected: {detected.upper() if detected != 'unknown' else 'Not yet detected'}"
            detect_label.Location = Point(20, 170)
            detect_label.Size = Size(350, 20)
            detect_label.Font = Font(detect_label.Font.FontFamily, 8, FontStyle.Italic)
            dialog.Controls.Add(detect_label)
            
            # OK button
            ok_btn = Button()
            ok_btn.Text = "OK"
            ok_btn.Location = Point(150, 200)
            ok_btn.Size = Size(90, 30)
            ok_btn.Click += lambda s, e: dialog.Close()
            dialog.Controls.Add(ok_btn)
            
            # Show dialog
            dialog.ShowDialog()
            
            # Save selection
            if auto_radio.Checked:
                new_type = 'auto'
            elif ssp3_radio.Checked:
                new_type = 'ssp3'
            else:
                new_type = 'ssp5a'
            
            if new_type != current_type:
                self.config.config['device_type'] = new_type
                self.config.save()
                
                # Update communicator if already connected
                if hasattr(self, 'comm'):
                    self.comm.device_type = new_type
                
                self._update_status(f"Device type set to: {new_type}")
            
        except Exception as e:
            print(f"[ERROR] Device type dialog error: {str(e)}")
            MessageBox.Show(f"Error configuring device type: {str(e)}", "Error",
                          MessageBoxButtons.OK, MessageBoxIcon.Error)
    def _on_observer_location(self, sender, event):
        """Handle Observer Location menu item."""
        # Get current location from config
        current_lat = self.config.get('observer_latitude', 0.0)
        current_lon = self.config.get('observer_longitude', 0.0)
        current_elev = self.config.get('observer_elevation', 0.0)
        current_city = self.config.get('observer_city', '')
        
        # Show location dialog
        dialog = ssp_dialogs.LocationDialog(current_lat, current_lon, current_elev, current_city)
        self.night_mode.apply_to_form(dialog)
        
        if dialog.ShowDialog() == DialogResult.OK:
            # Save changes
            self.config.set('observer_latitude', dialog.latitude)
            self.config.set('observer_longitude', dialog.longitude)
            self.config.set('observer_elevation', dialog.elevation)
            self.config.set('observer_city', dialog.city)
            self.config.save()
            
            # Format location for status message
            lat_dir = "N" if dialog.latitude >= 0 else "S"
            lon_dir = "E" if dialog.longitude >= 0 else "W"
            lat_str = "{0:.4f}".format(abs(dialog.latitude)) + lat_dir
            lon_str = "{0:.4f}".format(abs(dialog.longitude)) + lon_dir
            
            self._update_status("Location saved: " + lat_str + ", " + lon_str)
    
    def _update_filter_combo(self):
        """Update filter combo box with filters from active bar."""
        active_bar = self.config.get('active_filter_bar', 1)
        filter_bars = self.config.get('filter_bars', [
            ['U', 'B', 'V', 'R', 'I', 'Dark'],
            ['u', 'g', 'r', 'i', 'z', 'Y'],
            ['f13', 'f14', 'f15', 'f16', 'f17', 'f18']
        ])
        
        # Get filters for active bar
        bar_index = active_bar - 1
        if bar_index < len(filter_bars):
            filters = filter_bars[bar_index]
        else:
            filters = ['U', 'B', 'V', 'R', 'I', 'Dark']
        
        # Save current selection if any
        current_selection = self.filter_combo.Text if self.filter_combo.SelectedIndex >= 0 else ""
        
        # Suspend event handling during update to prevent recursion
        self.updating_filter_combo = True
        
        # Update combo box
        self.filter_combo.Items.Clear()
        for f in filters:
            self.filter_combo.Items.Add(f)
        
        # Always add "Home" option (works only in auto mode, but always available)
        self.filter_combo.Items.Add("Home")
        
        # Restore selection or select first item
        if current_selection and (current_selection in filters or current_selection == "Home"):
            self.filter_combo.Text = current_selection
        elif len(filters) > 0:
            self.filter_combo.SelectedIndex = 0
        
        # Resume event handling
        self.updating_filter_combo = False
    
    def _on_filter_changed(self, sender, event):
        """Handle filter selection change.
        
        Implements [SELECT_FILTER.Click] from SSPDataq (lines 1476-1545).
        In Auto mode: sends SHNNN (home) or SFNNn (select) commands to SSP.
        In Manual mode: displays message to manually change filter.
        """
        # Prevent recursion when programmatically updating combo
        if self.updating_filter_combo:
            return
        
        print("\n" + "="*60)
        print("FILTER SELECTION EVENT")
        print("="*60)
        
        if self.filter_combo.SelectedIndex < 0:
            print("No filter selected (index < 0)")
            return
        
        filter_selection = self.filter_combo.Text
        auto_manual = self.config.get('auto_manual', 'M')
        
        print("User selected: " + filter_selection)
        print("Mode: " + ("Automated" if auto_manual == 'A' else "Manual"))
        print("Combo index: " + str(self.filter_combo.SelectedIndex))
        print("Connection status: " + ("Connected" if self.comm.is_connected else "Not connected"))
        
        # Check if "Home" selected in Manual mode (error condition)
        if auto_manual == 'M' and filter_selection == "Home":
            print("ERROR: Home command not allowed in Manual mode")
            MessageBox.Show("Home is for auto-filter option", "Filter Selection",
                          MessageBoxButtons.OK, MessageBoxIcon.Warning)
            self._update_status("Home is for auto-filter option")
            # Reset selection to first filter (prevent recursion)
            self.updating_filter_combo = True
            self.filter_combo.SelectedIndex = 0
            self.updating_filter_combo = False
            print("="*60 + "\n")
            return
        
        # Handle filter selection in Manual mode (not Home)
        if auto_manual == 'M':
            print("Manual mode: Displaying instruction to user")
            message = "Place filter " + filter_selection + " in position"
            print("Status message: " + message)
            self._update_status(message)
            print("="*60 + "\n")
            return
        
        # From here on, we're in Auto mode
        print("Automated mode: Will send serial command to SSP")
        
        # Handle Home command in Auto mode
        if filter_selection == "Home":
            print("Processing Home command...")
            if not self.comm.is_connected:
                print("ERROR: Port not open")
                MessageBox.Show("Port not open - please connect", "Filter Control",
                              MessageBoxButtons.OK, MessageBoxIcon.Warning)
                self._update_status("Port not open - please connect")
                self.updating_filter_combo = True
                self.filter_combo.SelectedIndex = 0
                self.updating_filter_combo = False
                print("="*60 + "\n")
                return
            
            print("Calling comm.home_filter()...")
            self._update_status("Filter slider going to position 1")
            success, retry_count, message = self.comm.home_filter()
            
            print("Home result: success=" + str(success) + ", retries=" + str(retry_count) + ", msg=" + message)
            
            if success:
                # Get filter name for position 1
                filter_bars = self.config.get('filter_bars', [])
                active_bar = self.config.get('active_filter_bar', 1) - 1
                if active_bar < len(filter_bars) and len(filter_bars[active_bar]) > 0:
                    filter_name = filter_bars[active_bar][0]
                else:
                    filter_name = "f1"
                
                status_msg = "Filter " + filter_name + " is in position"
                print("SUCCESS: " + status_msg)
                self._update_status(status_msg)
                # Don't change combo selection - leave it on "Home" to show what was done
            else:
                print("FAILED: " + message)
                self._update_status("Problem with SSP communication - no Ack received")
                error_msg = "No acknowledgment received after 3 attempts.\n\n"
                error_msg += "Possible causes:\n"
                error_msg += "1. SSP hardware does not have automated filter slider\n"
                error_msg += "2. Filter hardware not connected or powered\n"
                error_msg += "3. Communication cable issue\n\n"
                error_msg += "If your SSP does not have automated filters,\n"
                error_msg += "use Setup -> Auto/Manual Filters to select Manual mode."
                MessageBox.Show(error_msg, "Filter Control Error",
                              MessageBoxButtons.OK, MessageBoxIcon.Error)
            print("="*60 + "\n")
            return
        
        # Handle filter selection in Auto mode (positions 1-6)
        print("Processing filter selection in Auto mode...")
        
        if not self.comm.is_connected:
            print("ERROR: Port not open")
            MessageBox.Show("Port not open - please connect", "Filter Control",
                          MessageBoxButtons.OK, MessageBoxIcon.Warning)
            self._update_status("Port not open - please connect")
            self.updating_filter_combo = True
            self.filter_combo.SelectedIndex = 0
            self.updating_filter_combo = False
            print("="*60 + "\n")
            return
        
        # Get filter position (1-6) from combo index
        filter_position = self.filter_combo.SelectedIndex + 1
        print("Filter position: " + str(filter_position) + " (index + 1)")
        
        # Ensure valid filter position
        if filter_position >= 1 and filter_position <= 6:
            print("Calling comm.select_filter(" + str(filter_position) + ")...")
            self._update_status("Filter slider moving to position " + str(filter_position))
            success, retry_count, message = self.comm.select_filter(filter_position)
            
            print("Select result: success=" + str(success) + ", retries=" + str(retry_count) + ", msg=" + message)
            
            if success:
                status_msg = "Filter " + filter_selection + " is in position"
                print("SUCCESS: " + status_msg)
                self._update_status(status_msg)
            else:
                print("FAILED: " + message)
                self._update_status("Problem with SSP communication - no Ack received")
                error_msg = "No acknowledgment received after 3 attempts.\n\n"
                error_msg += "Possible causes:\n"
                error_msg += "1. SSP hardware does not have automated filter slider\n"
                error_msg += "2. Filter hardware not connected or powered\n"
                error_msg += "3. Communication cable issue\n\n"
                error_msg += "If your SSP does not have automated filters,\n"
                error_msg += "use Setup -> Auto/Manual Filters to select Manual mode."
                MessageBox.Show(error_msg, "Filter Control Error",
                              MessageBoxButtons.OK, MessageBoxIcon.Error)
        else:
            print("ERROR: Invalid filter position " + str(filter_position) + " (out of range 1-6)")
        
        print("="*60 + "\n")
    
    # Added for memory test - print memory usage after each SSP reading
    def _print_memory_stats(self, reading_num):
        """Added for memory test - print memory usage after each SSP reading."""
        _proc = None
        try:
            _proc = Process.GetCurrentProcess()
            _proc.Refresh()
            _now = _proc.WorkingSet64
            _private = _proc.PrivateMemorySize64
            _ts = DateTime.Now.ToString("HH:mm:ss.fff")
            _delta_last = _now - self._mem_last
            _delta_start = _now - _MEM_BASELINE_BYTES
            _mb = 1048576.0
            # Added for memory test - time-normalised leak rate (key diagnostic).
            # Uses the reading-dedicated baseline so an interleaved _log_memory_point
            # checkpoint cannot shorten the interval while _delta_last spans the whole
            # reading-to-reading gap.
            _elapsed_sec = (DateTime.Now - self._mem_last_reading_ts).TotalSeconds
            if _elapsed_sec < 0.001:
                _elapsed_sec = 0.001
            _rate_ws = (_delta_last / _mb) / _elapsed_sec
            _rate_pb = ((_private - self._mem_last_reading_private) / _mb) / _elapsed_sec
            print("=== MEMORY TEST [%s] Reading #%d ===" % (_ts, reading_num))
            print("  Current working set : %.2f MB" % (_now / _mb))
            print("  Change since last   : %+.2f MB" % (_delta_last / _mb))
            print("  Change since start  : %+.2f MB" % (_delta_start / _mb))
            print("  Private bytes       : %.2f MB" % (_private / _mb))
            print("  Peak working set    : %.2f MB" % (_proc.PeakWorkingSet64 / _mb))
            print("  Handle count        : %d" % _proc.HandleCount)
            print("  Thread count        : %d" % _proc.Threads.Count)
            print("  Managed heap (GC)   : %.2f MB" % (System.GC.GetTotalMemory(False) / _mb))
            print("  saved_data rows     : %d" % len(self.saved_data))
            print("  ListBox items       : %d" % self.data_listbox.Items.Count)
            print("  Elapsed since last  : %.1f s" % _elapsed_sec)
            print("  WS rate             : %+.3f MB/s" % _rate_ws)
            print("  Private rate        : %+.3f MB/s" % _rate_pb)
            # Added for memory test - optional GDI/USER handle counts via ctypes
            if ctypes is not None:
                try:
                    _h = _proc.Handle.ToInt32()
                    _gdi = ctypes.windll.user32.GetGuiResources(_h, 0)
                    _user = ctypes.windll.user32.GetGuiResources(_h, 1)
                    print("  GDI handles         : %d" % _gdi)
                    print("  USER handles        : %d" % _user)
                except Exception:
                    pass
            self._mem_last = _now
            self._mem_last_private = _private
            self._mem_last_ts = DateTime.Now
            self._mem_last_reading_private = _private
            self._mem_last_reading_ts = DateTime.Now
        except Exception as e:
            print("Memory test error: %s" % str(e))
        finally:
            # Added for memory test - release the Process handle so the
            # instrumentation does not itself inflate the handle count.
            if _proc is not None:
                try:
                    _proc.Dispose()
                except Exception:
                    pass

    # Added for memory test - checkpoint logger for GOTO and dialog paths
    def _log_memory_point(self, label, force_gc=False):
        """Added for memory test - log memory at a named checkpoint."""
        _proc = None
        try:
            _proc = Process.GetCurrentProcess()
            _proc.Refresh()
            _mb = 1048576.0
            _ts = DateTime.Now.ToString("HH:mm:ss.fff")
            _now = _proc.WorkingSet64
            _private = _proc.PrivateMemorySize64
            _delta_start = _now - _MEM_BASELINE_BYTES
            _delta_point = _now - self._mem_last_point
            _gc_now = System.GC.GetTotalMemory(False)
            # Added for memory test - time-normalised rate between checkpoints
            _elapsed_sec = (DateTime.Now - self._mem_last_ts).TotalSeconds
            if _elapsed_sec < 0.001:
                _elapsed_sec = 0.001
            _rate_ws = (_delta_point / _mb) / _elapsed_sec
            _rate_pb = ((_private - self._mem_last_private) / _mb) / _elapsed_sec
            print("=== MEMORY POINT [%s] %s ===" % (_ts, label))
            print("  Current working set : %.2f MB" % (_now / _mb))
            print("  Change since last point : %+.2f MB" % (_delta_point / _mb))
            print("  Change since start  : %+.2f MB" % (_delta_start / _mb))
            print("  Private bytes       : %.2f MB" % (_private / _mb))
            print("  Handle count        : %d" % _proc.HandleCount)
            print("  Thread count        : %d" % _proc.Threads.Count)
            print("  Managed heap (GC)   : %.2f MB" % (_gc_now / _mb))
            print("  Elapsed since last point : %.1f s" % _elapsed_sec)
            print("  WS rate             : %+.3f MB/s" % _rate_ws)
            print("  Private rate        : %+.3f MB/s" % _rate_pb)
            if force_gc:
                # Added for memory test - forced GC variant
                System.GC.Collect()
                System.GC.WaitForPendingFinalizers()
                System.GC.Collect()
                _gc_forced = System.GC.GetTotalMemory(True)
                _proc.Refresh()
                _now = _proc.WorkingSet64
                _private = _proc.PrivateMemorySize64
                print("  Managed heap (forced GC) : %.2f MB" % (_gc_forced / _mb))
                print("  Working set after forced GC : %.2f MB" % (_now / _mb))
                print("  Private bytes after forced GC : %.2f MB" % (_private / _mb))
            if ctypes is not None:
                try:
                    _h = _proc.Handle.ToInt32()
                    _gdi = ctypes.windll.user32.GetGuiResources(_h, 0)
                    _user = ctypes.windll.user32.GetGuiResources(_h, 1)
                    print("  GDI handles         : %d" % _gdi)
                    print("  USER handles        : %d" % _user)
                except Exception:
                    pass
            self._mem_last_point = _now
            self._mem_last_private = _private
            self._mem_last_ts = DateTime.Now
        except Exception as e:
            print("Memory point error: %s" % str(e))
        finally:
            # Added for memory test - release the Process handle so the
            # instrumentation does not itself inflate the handle count.
            if _proc is not None:
                try:
                    _proc.Dispose()
                except Exception:
                    pass

    def _on_start(self, sender, event):
        """Handle START button click.

        Thin wrapper over take_reading(): reads the UI, resolves the object name
        and catalog code, then delegates the measurement. The measurement logic
        lives in take_reading() / _collect_counts() so the sequence engine can
        drive it with explicit parameters (see SEQUENCER_DEVELOPMENT.md).
        """
        if not self.comm.is_connected:
            self._update_status("Error: Not connected to photometer. Use Setup -> Connect to SSP")
            MessageBox.Show("Not connected to photometer. Use Setup -> Connect to SSP", "Error",
                          MessageBoxButtons.OK, MessageBoxIcon.Warning)
            return
        
        # Get selected values
        filter_val = self.filter_combo.Text
        gain_val = int(self.gain_combo.Text)
        integ_text = self.integ_combo.Text
        integ_val = float(integ_text)  # In seconds
        integ_ms = int(integ_val * 1000)  # Convert to milliseconds
        interval_val = int(self.interval_combo.Text)
        mode_val = self.mode_combo.Text
        object_val = self.object_combo.Text
        catalog_val = self.catalog_combo.Text
        
        # Get actual star name (without display suffixes) if in mapping
        if object_val in self.star_name_map:
            actual_name, catalog_type = self.star_name_map[object_val]
            object_val = actual_name  # Use actual name without (Comp) or (Check)
        
        # Get catalog code (first letter)
        # For SKY objects, catalog should be blank (matches SSPDataq lines 1948-1951)
        if object_val in ["SKY", "SKYNEXT", "SKYLAST"]:
            catalog_code = " "
        else:
            catalog_code = catalog_val[0].upper() if len(catalog_val) > 0 else "?"
        
        # Check for trial mode
        if mode_val.lower() == "trial":
            self._do_trial_mode(filter_val, gain_val, integ_ms)
            return
        
        # Check for slow mode only (fast/vfast not yet implemented)
        if mode_val.lower() != "slow":
            self._update_status("Error: Only 'slow' and 'trial' modes implemented")
            MessageBox.Show("Only 'slow' and 'trial' modes are currently implemented", "Error",
                          MessageBoxButtons.OK, MessageBoxIcon.Information)
            return
        
        # Disable button during collection
        self.start_button.Enabled = False
        self.start_button.Text = "WAIT"
        try:
            self.take_reading(object_val, catalog_code, filter_val, gain_val,
                              integ_val, interval_val, mode_val)
        finally:
            # Re-enable only when the window is not closing (matches the
            # original, which left the button disabled after a mid-loop close).
            if not self._closing:
                self.start_button.Text = "START"
                self.start_button.Enabled = True
        
    def take_reading(self, object_val, catalog_code, filter_val, gain_val,
                     integ_val, interval_val, mode_val="slow", append=True,
                     headless=False):
        """Perform one PEP measurement and record it.

        Extracted from the original _on_start so the sequence engine can drive a
        measurement with explicit parameters. Reads/writes the same data arrays
        as _on_start, so File -> Save Data is unchanged.

        Args:
            object_val: Object name for the data line (already resolved, i.e.
                        without the "(Comp)"/"(Check)" display suffixes)
            catalog_code: Single-character catalog code (blank for SKY labels)
            filter_val: Filter name
            gain_val: Gain (1/10/100)
            integ_val: Integration time in seconds
            interval_val: Number of counts (1-8; 6 and 8 are binned to 3/4)
            mode_val: Count mode (currently only "slow")
            append: When True, append the reading to the data arrays
            headless: When True (sequence engine), suppress modal dialogs and
                      log warnings instead (NFR-3)

        Returns:
            (ok, data_line): ok is True when a reading was recorded.
        """
        # Bail out if the window is closing or a sequence abort was requested
        if self._closing or self._sequence_abort:
            return (False, None)

        integ_ms = int(integ_val * 1000)  # Convert to milliseconds

        # === CRITICAL: Set ALL SSP parameters before data collection ===
        # This ensures SSP hardware is synchronized with UI settings
        # Matches SSPDataq behavior where settings are sent when changed

        # Set integration time on photometer (must be done before counts)
        success, msg = self.comm.set_integration(integ_ms)
        if not success:
            self._update_status("Error setting integration time: " + msg)
            if not headless:
                MessageBox.Show("Failed to set integration time:\n" + msg, "SSP Configuration Error",
                              MessageBoxButtons.OK, MessageBoxIcon.Error)
            return (False, None)

        # Set gain on photometer. Coerce to int: the combo/step value may be a
        # string, and set_gain compares against the ints 1/10/100.
        try:
            gain_int = int(gain_val)
        except (ValueError, TypeError):
            gain_int = 0
        success, msg = self.comm.set_gain(gain_int)
        if not success:
            self._update_status("Error setting gain: " + msg)
            if not headless:
                MessageBox.Show("Failed to set gain:\n" + msg, "SSP Configuration Error",
                              MessageBoxButtons.OK, MessageBoxIcon.Error)
            return (False, None)

        # Set filter position (if automated mode)
        auto_manual = self.config.get('auto_manual', 'M')
        if auto_manual == 'A' and filter_val != "" and filter_val.lower() != "home":
            filter_position = self._filter_position_for_name(filter_val)
            if filter_position is not None and 1 <= filter_position <= 6:
                success, retry_count, msg = self.comm.select_filter(filter_position)
                if not success:
                    self._update_status("Warning: Filter position not confirmed - " + msg)
                    if not headless:
                        # Don't abort - allow user to continue (filter might
                        # already be in position)
                        result = MessageBox.Show(
                            "Could not confirm filter position:\n" + msg + "\n\nContinue anyway?",
                            "Filter Warning", MessageBoxButtons.YesNo, MessageBoxIcon.Warning)
                        if result == DialogResult.No:
                            return (False, None)

        # Show initial status message (matches original)
        self._update_status("Getting count data for " + filter_val + " filter - please wait")

        # Record start time (UT) BEFORE the count loop (matches original)
        ut_start = DateTime.UtcNow

        # Collect counts for the specified interval (retry + 6/8 binning inside)
        counts, binning = self._collect_counts(integ_val, interval_val, integ_ms)
        if counts is None:
            # Aborted mid-loop (window closing / sequence abort)
            return (False, None)

        # Calculate mid-point timestamp (matches original SSPDataq [UTtimeCorrected])
        # Original: MidCount = int((IntervalRecord * (Integ/1000))/2)
        # Then adds MidCount seconds to recorded UT time.
        # Correct the total integration time for 6 or 8 readings (sum of pairs)
        # by multiplying by the binning.
        total_integration_sec = len(counts) * integ_val * binning
        mid_count_sec = int(total_integration_sec / 2.0)
        ut_midpoint = ut_start.AddSeconds(mid_count_sec)
        ut_date_str = ut_midpoint.ToString("MM-dd-yyyy")
        ut_time_str = ut_midpoint.ToString("HH:mm:ss")

        # Integration string: matches the original f"{float(integ_text) * binning:0.2f}"
        integ_str = "%.2f" % (float(integ_val) * binning)

        # Format data for display and storage (final summary line)
        # Format: "MM-DD-YYYY HH:MM:SS C OBJECTNAME F XXXXX XXXXX XXXXX XXXXX II GG NOTES"
        data_line = self._format_data_line(
            ut_date_str, ut_time_str, catalog_code, object_val,
            filter_val, counts, integ_str, str(gain_val)
        )
        # Tab format data line
        data_line_tab = self._format_data_line_tab(
            ut_date_str, ut_time_str, catalog_code, object_val,
            filter_val, counts, integ_str, str(gain_val)
        )

        if append:
            # Add to data arrays
            self.saved_data.append(data_line)
            self.saved_data_tab.append(data_line_tab)
            self.data_array.insert(0, data_line)  # Insert at beginning for reverse display

            # Add to listbox (display in reverse chronological order)
            self.data_listbox.Items.Insert(0, data_line)

        self._update_status("Data collection complete - " + str(len(counts)) + " readings." + (" Binned: " + str(binning == 2) if binning == 2 else ""))

        # Added for memory test - print memory stats after each completed reading
        self._mem_reading_count += 1
        self._print_memory_stats(self._mem_reading_count)

        return (True, data_line)
    
    def _collect_counts(self, integ_val, interval_val, integ_ms):
        """Collect `interval_val` slow counts; bin 6/8 to 3/4 readings.

        Extracted from the original _on_start count loop (including the single
        retry and the 6/8 pair-binning). Returns (counts, binning), or
        (None, 1) when the window is closing or a sequence abort was requested
        mid-loop. The abort check is deliberately placed before the binning
        step, which indexes counts in pairs (a mid-loop break would otherwise
        leave a short list and raise IndexError).
        """
        counts = []
        binning = 1
        if interval_val in [6, 8]:
            binning = 2  # Sum pairs of counts for 6 or 8 intervals

        for i in range(interval_val):
            # Added for memory test - stop if the window started closing while
            # the integration wait was pumping messages (also covers a sequence
            # abort, which must not touch controls that are being disposed)
            if self._closing or self._sequence_abort:
                return (None, 1)
            success, count_str, error_msg = self.comm.get_slow_count(integ_ms)

            if success:
                counts.append(count_str)
                # Display count as it's collected (matches original: "Count 1 = 00496")
                self._update_status("Count " + str(i+1) + " = " + count_str)
            else:
                self._update_status("Communication error - count restarted")
                # Retry once on error
                success, count_str, error_msg = self.comm.get_slow_count(integ_ms)
                if success:
                    counts.append(count_str)
                    self._update_status("Count " + str(i+1) + " = " + count_str)
                else:
                    self._update_status("Failed to get count after retry")
                    counts.append("00000")  # Insert zero on failure

        # Added for memory test - if the window is closing (or a sequence abort
        # was requested), stop before the binning step below, which indexes
        # counts in pairs and would raise IndexError on a short list.
        if self._closing or self._sequence_abort:
            return (None, 1)

        # Special treatment when 6 or 8 is chosen: sum pairs of counts to reduce
        # to 3 or 4 readings so the output conforms to the standard. This
        # enables, say, 5s integrations for bright stars instead of 10s to avoid
        # saturation while keeping the output to 3 or 4 values.
        if binning == 2:
            counts = [str(int(counts[i]) + int(counts[i+1])) for i in range(0, len(counts), 2)]

        return (counts, binning)

    def _filter_position_for_name(self, filter_name):
        """Return the 1-based hardware position of a filter, else None.

        Maps a filter *name* to its slider position on the active filter bar so
        the sequence engine can name a filter directly. The manual path used the
        combo index, which equals this position because the combo is populated in
        bar order. "Home" and any name not on the active bar return None so no
        position command is sent.
        """
        try:
            active_bar = self.config.get('active_filter_bar', 1)
            filter_bars = self.config.get('filter_bars', [])
            bar_index = active_bar - 1
            if 0 <= bar_index < len(filter_bars):
                names = filter_bars[bar_index]
                for i in range(len(names)):
                    if str(names[i]) == str(filter_name):
                        return i + 1
        except Exception:
            pass
        return None

    def _do_trial_mode(self, filter_val, gain_val, integ_ms):
        """Execute trial mode (single test reading).
        
        Args:
            filter_val: Filter name
            gain_val: Gain value
            integ_ms: Integration time in milliseconds
        """
        # Added for memory test - bail out if the window is closing (the pumped
        # read below must not touch controls being disposed), or if a previous
        # trial run is still in progress. Trial mode is reached from _on_start
        # before the START button is disabled, so a click delivered by the pump
        # could otherwise nest a second serial transaction on the same port.
        if self._closing or self._trial_busy:
            return
        self._trial_busy = True
        try:
            # Set integration time
            success, msg = self.comm.set_integration(integ_ms)
            if not success:
                self._update_status("Error setting integration time: " + msg)
                return
            
            # Set gain
            success, msg = self.comm.set_gain(gain_val)
            if not success:
                self._update_status("Error setting gain: " + msg)
                return
            
            self._update_status("Trial mode: Getting single count...")
            
            success, count_str, error_msg = self.comm.get_slow_count(integ_ms)
            
            if success:
                msg = "TRIAL COUNT\n\n"
                msg += "Filter: " + filter_val + "\n"
                msg += "Gain: " + str(gain_val) + "\n"
                msg += "Integration: " + str(integ_ms/1000.0) + " sec\n"
                msg += "Count: " + count_str + "\n"
                MessageBox.Show(msg, "Trial Mode Result", MessageBoxButtons.OK, MessageBoxIcon.Information)
                self._update_status("Trial count: " + count_str)
            else:
                MessageBox.Show("Error: " + error_msg, "Trial Mode Failed",
                              MessageBoxButtons.OK, MessageBoxIcon.Error)
                self._update_status("Trial mode failed: " + error_msg)
        finally:
            self._trial_busy = False
    
    def _format_data_line(self, ut_date, ut_time, catalog, object_name, filter_char, counts, integ, gain):
        """Format data line for display and file output.
        
        Follows SSPDataq format from [DisplayData] subroutine:
        MM-DD-YYYY HH:MM:SS C OBJECTNAME F XXXXX XXXXX XXXXX XXXXX II GG NOTES
        
        Args:
            ut_date: UT date string (MM-DD-YYYY)
            ut_time: UT time string (HH:MM:SS)
            catalog: Single character catalog code
            object_name: Object name (truncated to 12 chars)
            filter_char: Filter character
            counts: List of count strings (up to 4)
            integ: Integration time string
            gain: Gain string
            
        Returns:
            str: Formatted data line
        """
        # Pad/truncate object name to 12 characters
        obj_padded = (object_name + " " * 12)[:12]
        
        # Format counts (pad to 4 readings with spaces)
        count_strs = []
        for i in range(4):
            if i < len(counts):
                count_strs.append(counts[i].rjust(5))
            else:
                count_strs.append(" " * 5)
        counts_str = "  ".join(count_strs)
        
        # Integration time (pad to 2 chars)
        integ_padded = integ.replace(".00", "").rjust(2)
        
        # Gain (pad to 2 chars)
        gain_padded = gain.rjust(2)
        
        # Build line
        line = ut_date + " " + ut_time + " " + catalog + "    " + obj_padded + "   " + filter_char + "  " + counts_str + "  " + integ_padded + " " + gain_padded
        
        return line

    def _format_data_line_tab(self, ut_date, ut_time, catalog, object_name, filter_char, counts, integ, gain):
        """Format data line for TAB file output compatible with Excel.
        
        Follows new TAB SSPDataq format from:
        CAT OBJECT F MO-DY-YEAR UT COUNT1 COUNT2 COUNT3 COUNT4 INT SCLE COMMENTS
        
        Args:
            ut_date: UT date string (MM-DD-YYYY)
            ut_time: UT time string (HH:MM:SS)
            catalog: Single character catalog code
            object_name: Object name (truncated to 12 chars)
            filter_char: Filter character
            counts: List of count strings (up to 4)
            integ: Integration time string
            gain: Gain string
            
        Returns:
            str: Formatted data line
        """
        # Pad/truncate object name to 12 characters
        obj_padded = (object_name + " " * 12)[:12].strip()
        
        # Format counts (pad to 4 readings with spaces)
        count_strs = []
        for i in range(4):
            if i < len(counts):
                count_strs.append(counts[i])
            else:
                count_strs.append("")
        counts_str = "\t".join(count_strs)
        
        # Integration time (pad to 2 chars)
        integ_padded = integ.replace(".00", "").strip()
        
        # Gain (pad to 2 chars)
        gain_padded = gain.strip()
        
        # Build line
        line = catalog + "\t" + obj_padded + "\t" + filter_char + "\t" + ut_date + "\t" + ut_time + "\t" +  counts_str + "\t" + integ_padded + "\t" + gain_padded
        
        return line


    def _load_star_catalog(self):
        """Load the star catalog from CSV file."""
        import os
        
        # Get script directory - use module-level script_dir or fallback
        # This works in both SharpCap (exec'd) and standalone (ipy main.py) modes
        try:
            catalog_dir = script_dir
        except NameError:
            # Fallback if script_dir somehow not defined
            import System
            catalog_dir = System.IO.Directory.GetCurrentDirectory()
        
        csv_path = os.path.join(catalog_dir, "starparm_latest.csv")
        
        if not os.path.exists(csv_path):
            print("Warning: Star catalog not found at: " + csv_path)
            self.catalog = None
            return
        
        try:
            self.catalog = ssp_catalog.StarCatalog(csv_path)
            print("Star catalog loaded: %d targets" % self.catalog.get_count())
        except Exception as e:
            import traceback
            print("Error loading star catalog: " + str(e))
            print(traceback.format_exc())
            self.catalog = None
    
    def _load_extinction_catalog(self):
        """Load the first order extinction star catalog from CSV file."""
        import os
        import ssp_extinction
        
        # Get script directory
        try:
            catalog_dir = script_dir
        except NameError:
            import System
            catalog_dir = System.IO.Directory.GetCurrentDirectory()
        
        csv_path = os.path.join(catalog_dir, "first_order_extinction_stars.csv")
        
        if not os.path.exists(csv_path):
            print("Warning: Extinction catalog not found at: " + csv_path)
            self.extinction_catalog = None
            return
        
        try:
            self.extinction_catalog = ssp_extinction.ExtinctionCatalog()
            count = self.extinction_catalog.load_from_csv(csv_path)
            print("Extinction catalog loaded: %d stars" % len(self.extinction_catalog))
        except Exception as e:
            import traceback
            print("Error loading extinction catalog: " + str(e))
            print(traceback.format_exc())
            self.extinction_catalog = None
    
    def _on_reload_catalog(self, sender, event):
        """Handle reload catalog menu click."""
        self._load_star_catalog()
        self._load_extinction_catalog()
        
        catalog_count = self.catalog.get_count() if self.catalog else 0
        extinction_count = len(self.extinction_catalog) if self.extinction_catalog else 0
        
        if self.catalog or self.extinction_catalog:
            MessageBox.Show("Catalogs reloaded successfully.\nTarget stars: %d\nExtinction stars: %d" % (catalog_count, extinction_count),
                          "Catalogs Reloaded", MessageBoxButtons.OK, MessageBoxIcon.Information)
        else:
            MessageBox.Show("Failed to reload catalogs.\nCheck that CSV files are in the Python folder.",
                          "Catalog Error", MessageBoxButtons.OK, MessageBoxIcon.Error)
    
    # Added for memory test (Phase 2) - one cached bold Font for the target
    # label. Label.Font does not own the font assigned to it, so the
    # per-selection allocation in _on_select_star and
    # _on_select_extinction_star leaked a Font and its GDI handle on every star.
    def _get_target_label_bold_font(self):
        """Return the shared bold Font used for current_target_label."""
        if self._target_label_font is None:
            self._target_label_font = Font("Arial", 9, FontStyle.Bold)
        return self._target_label_font
    
    def _on_select_star(self, sender, event):
        """Handle select star menu click."""
        if not self.catalog or self.catalog.get_count() == 0:
            MessageBox.Show("No star catalog loaded.\n\nPlace 'starparm_latest.csv' in the Python folder and use Catalog > Reload Catalog.",
                          "No Catalog", MessageBoxButtons.OK, MessageBoxIcon.Warning)
            return
        
        # Added for memory test - checkpoint before dialog opens
        self._log_memory_point("Before StarSelectionDialog")
        # Create star selection dialog
        dialog = StarSelectionDialog(self.catalog, self.config)
        self.night_mode.apply_to_form(dialog)
        result = dialog.ShowDialog(self)
        # Added for memory test - checkpoint after dialog returns (dialog still referenced)
        self._log_memory_point("After StarSelectionDialog", force_gc=True)
        
        if result == DialogResult.OK and dialog.selected_target:
            target = dialog.selected_target
            
            # Clean up extinction stars and restore normal object list
            # Remove all items except the base ones (New Object, SKY, SKYNEXT, SKYLAST, CATALOG)
            self.updating_object_combo = True
            
            base_items = ["New Object", "SKY", "SKYNEXT", "SKYLAST", "CATALOG"]
            items_to_remove = []
            
            # Find items that need to be removed
            for i in range(self.object_combo.Items.Count):
                item_text = str(self.object_combo.Items[i])
                if item_text not in base_items:
                    items_to_remove.append(item_text)
            
            # Remove non-base items
            for item in items_to_remove:
                self.object_combo.Items.Remove(item)
            
            # Clear star name mapping for removed items
            for item in items_to_remove:
                if item in self.star_name_map:
                    del self.star_name_map[item]
            
            # Store the selected target for GOTO functionality
            self.current_target = target
            
            # Enable GOTO button if in SharpCap mode
            if self.sharpcap_available and hasattr(self, 'goto_button'):
                self.goto_button.Enabled = True
            elif self.sharpcap_available:
                pass
            else:
                pass
            
            # Enable two-stage GOTO button (has both Comp and Var stars) and reset to Comp
            self.auto_goto_stage = 'comp'
            if self.sharpcap_available and hasattr(self, 'goto_stage_button'):
                self.goto_stage_button.Text = "GOTO Comp"
                self.goto_stage_button.Enabled = True
            
            # Update the current target label
            self.current_target_label.Text = "Current Target: Var=%s | Comp=%s | Check=%s" % (
                target.variable.name,
                target.comparison.name,
                target.check.name)
            self.current_target_label.ForeColor = Color.DarkGreen
            # Added for memory test (Phase 2) - reuse the cached font
            self.current_target_label.Font = self._get_target_label_bold_font()
            
            # Prepare display names and actual names
            var_display = target.variable.name
            var_actual = target.variable.name
            comp_display = target.comparison.name + " (Comp)"
            comp_actual = target.comparison.name
            check_display = target.check.name + " (Check)"
            check_actual = target.check.name
            
            # Store mapping: display_name -> (actual_name, catalog_type)
            # catalog_type: 'V'=Var, 'C'=Comp, 'K'=Check
            self.star_name_map[var_display] = (var_actual, 'V')
            self.star_name_map[comp_display] = (comp_actual, 'C')
            self.star_name_map[check_display] = (check_actual, 'K')
            
            # Helper function to add unique item
            def add_unique_item(item_name):
                for i in range(self.object_combo.Items.Count):
                    if str(self.object_combo.Items[i]) == item_name:
                        return i  # Already exists
                self.object_combo.Items.Add(item_name)
                return self.object_combo.Items.Count - 1
            
            # Add all three stars
            var_index = add_unique_item(var_display)
            comp_index = add_unique_item(comp_display)
            check_index = add_unique_item(check_display)
            
            # Select the variable star by default
            self.object_combo.SelectedIndex = var_index
            
            # Re-enable event handling
            self.updating_object_combo = False
            
            # Auto-set catalog to Var
            self._set_catalog_for_object(var_display)
            
            self._update_status("Added target stars: %s, %s, %s - Variable selected" % (
                var_display, comp_display, check_display))
    
    def _on_object_changed(self, sender, event):
        """Handle object selection change - auto-set catalog type."""
        # Prevent recursion when programmatically updating combo
        if self.updating_object_combo:
            return
        
        selected = self.object_combo.Text
        self._set_catalog_for_object(selected)
    
    def _set_catalog_for_object(self, object_name):
        """Set catalog combobox based on selected object.
        
        Args:
            object_name: The display name of the selected object
        """
        # Handle SKY objects - catalog should remain blank/unchanged
        # Matches SSPDataq behavior (lines 1948-1951)
        if object_name in ["SKY", "SKYNEXT", "SKYLAST"]:
            # For SKY objects, catalog is set to blank in the data output
            # Don't change catalog combo - let user keep current selection
            return
        
        if object_name in self.star_name_map:
            actual_name, catalog_type = self.star_name_map[object_name]
            
            # Map catalog type to catalog combo index
            # catalog_type: 'V'=Var, 'C'=Comp, 'K'=Check
            if catalog_type == 'V':
                # Set to "Var"
                for i in range(self.catalog_combo.Items.Count):
                    if str(self.catalog_combo.Items[i]) == "Var":
                        self.catalog_combo.SelectedIndex = i
                        break
            elif catalog_type == 'C':
                # Set to "Comp"
                for i in range(self.catalog_combo.Items.Count):
                    if str(self.catalog_combo.Items[i]) == "Comp":
                        self.catalog_combo.SelectedIndex = i
                        break
            elif catalog_type == 'K':
                # Set to "Q'check"
                for i in range(self.catalog_combo.Items.Count):
                    if str(self.catalog_combo.Items[i]) == "Q'check":
                        self.catalog_combo.SelectedIndex = i
                        break
    
    def _star_display_name(self, catalog_type):
        """Return the Object-dropdown display name for a catalog star type.
        
        Args:
            catalog_type: 'V' (variable), 'C' (comparison), or 'K' (check)
        
        Returns:
            The display name stored in the Object combo / star_name_map, or None
            if the corresponding star is not available.
        """
        if not self.current_target:
            return None
        
        if catalog_type == 'C':
            comp = self.current_target.comparison
            return comp.name + " (Comp)" if comp else None
        elif catalog_type == 'K':
            check = self.current_target.check
            return check.name + " (Check)" if check else None
        else:
            var = self.current_target.variable
            return var.name if var else None
    
    def _select_object_display(self, display_name):
        """Select a star in the Object dropdown and sync the Catalog combo.
        
        The Object combo's SelectionChangeCommitted event does not fire for
        programmatic changes, so the Catalog combo is updated explicitly.
        
        Args:
            display_name: Display name of the star (as stored in the combo)
        """
        if not display_name:
            return
        
        self.updating_object_combo = True
        try:
            for i in range(self.object_combo.Items.Count):
                if str(self.object_combo.Items[i]) == display_name:
                    self.object_combo.SelectedIndex = i
                    break
        finally:
            self.updating_object_combo = False
        
        # Programmatic change won't fire _on_object_changed, so sync catalog here
        self._set_catalog_for_object(display_name)
    
    def _on_select_extinction_star(self, sender, event):
        """Handle select extinction star menu click."""
        if not self.extinction_catalog or len(self.extinction_catalog) == 0:
            MessageBox.Show("No extinction catalog loaded.\n\nPlace 'first_order_extinction_stars.csv' in the Python folder and use Catalog > Reload Catalog.",
                          "No Catalog", MessageBoxButtons.OK, MessageBoxIcon.Warning)
            return
        
        # Create extinction star selection dialog, passing last filter and parent for night mode
        dialog = ExtinctionStarSelectionDialog(self.extinction_catalog, self.config, self.last_extinction_filter, self)
        self.night_mode.apply_to_form(dialog)
        # Update button highlights after night mode is applied
        if hasattr(dialog, '_update_button_highlights'):
            dialog._update_button_highlights()
        # Added for memory test - checkpoint before dialog opens
        self._log_memory_point("Before ExtinctionStarSelectionDialog")
        result = dialog.ShowDialog(self)
        # Added for memory test - checkpoint after dialog returns (dialog still referenced)
        self._log_memory_point("After ExtinctionStarSelectionDialog", force_gc=True)
        
        if result == DialogResult.OK and dialog.selected_star:
            star = dialog.selected_star
            
            # Store the used filter for next time
            self.last_extinction_filter = dialog.used_filter
            
            # Create a pseudo-target object for GOTO functionality
            # We'll use the extinction star as the "variable" and set comp/check to None
            from ssp_catalog import TargetTriple, StarData
            
            # Convert decimal RA/Dec to hours/minutes/seconds format
            ra_hours_int = int(star.ra_hours)
            ra_minutes_float = (star.ra_hours - ra_hours_int) * 60.0
            ra_minutes_int = int(ra_minutes_float)
            ra_seconds = (ra_minutes_float - ra_minutes_int) * 60.0
            
            # Convert decimal Dec to degrees/minutes/seconds format
            dec_sign = 1 if star.dec_deg >= 0 else -1
            dec_abs = abs(star.dec_deg)
            dec_degrees_int = int(dec_abs) * dec_sign
            dec_minutes_float = (dec_abs - int(dec_abs)) * 60.0
            dec_minutes_int = int(dec_minutes_float)
            dec_seconds = (dec_minutes_float - dec_minutes_int) * 60.0
            
            # Create a StarData object from the extinction star data
            pseudo_var = StarData(
                name=star.name,
                ra_hours=ra_hours_int,
                ra_minutes=ra_minutes_int,
                ra_seconds=ra_seconds,
                dec_degrees=dec_degrees_int,
                dec_minutes=dec_minutes_int,
                dec_seconds=dec_seconds,
                vmag=star.v_mag,
                bv_color=star.b_v
            )
            
            # Create pseudo target with only variable set
            self.current_target = TargetTriple(variable=pseudo_var, comparison=None, check=None)
            
            # Enable GOTO button if in SharpCap mode
            if self.sharpcap_available and hasattr(self, 'goto_button'):
                self.goto_button.Enabled = True
            
            # Disable two-stage GOTO button - extinction target has no comparison star
            self.auto_goto_stage = 'comp'
            if self.sharpcap_available and hasattr(self, 'goto_stage_button'):
                self.goto_stage_button.Text = "GOTO Comp"
                self.goto_stage_button.Enabled = False
            
            # Update the current target label
            airmass_str = "Airmass=%.2f" % dialog.selected_airmass if dialog.selected_airmass else "Airmass=N/A"
            self.current_target_label.Text = "Current Target (Extinction): %s (V=%.2f, %s)" % (
                star.name, star.v_mag, airmass_str)
            self.current_target_label.ForeColor = Color.DarkBlue
            # Added for memory test (Phase 2) - reuse the cached font
            self.current_target_label.Font = self._get_target_label_bold_font()
            
            # Clean up previously selected target stars (including comp/check)
            # Remove all items except the base ones (New Object, SKY, SKYNEXT, SKYLAST, CATALOG)
            self.updating_object_combo = True
            
            base_items = ["New Object", "SKY", "SKYNEXT", "SKYLAST", "CATALOG"]
            items_to_remove = []
            
            # Find items that need to be removed (all non-base items)
            for i in range(self.object_combo.Items.Count):
                item_text = str(self.object_combo.Items[i])
                if item_text not in base_items:
                    items_to_remove.append(item_text)
            
            # Remove non-base items (previous target stars and extinction stars)
            for item in items_to_remove:
                self.object_combo.Items.Remove(item)
            
            # Clear star name mapping for removed items
            for item in items_to_remove:
                if item in self.star_name_map:
                    del self.star_name_map[item]
            
            # Add the new extinction star
            self.object_combo.Items.Add(star.name)
            
            # Select the extinction star
            for i in range(self.object_combo.Items.Count):
                if str(self.object_combo.Items[i]) == star.name:
                    self.object_combo.SelectedIndex = i
                    break
            
            self.updating_object_combo = False
            
            # Set catalog combo to "Foe" for first order extinction
            for i in range(self.catalog_combo.Items.Count):
                if str(self.catalog_combo.Items[i]) == "Foe":
                    self.catalog_combo.SelectedIndex = i
                    break
    
    def _on_plate_solve_sync_changed(self, sender, event):
        """Persist the 'Plate Solve and Sync' checkbox state."""
        enabled = self.plate_solve_sync_checkbox.Checked
        self.config.set('plate_solve_sync', 1 if enabled else 0)
        self.config.save()
        if enabled:
            self._update_status("Plate Solve and Sync enabled for GOTO")
        else:
            self._update_status("Plate Solve and Sync disabled for GOTO")
    
    def _set_goto_buttons_enabled(self, enabled):
        """Enable/disable the GOTO buttons and lock START during a slew/solve.
        
        The two-stage button also requires a comparison star, so it stays
        disabled for extinction targets even when enabled is True.
        
        START is locked too: the GOTO path now pumps the UI message loop while it
        runs (see the memory-test notes), so a click delivered by the pump could
        otherwise start an acquisition mid-slew. The previous START state is
        saved when locking and restored when unlocking.
        """
        if hasattr(self, 'goto_button'):
            self.goto_button.Enabled = enabled
        if hasattr(self, 'goto_stage_button'):
            has_comp = bool(self.current_target and self.current_target.comparison)
            self.goto_stage_button.Enabled = enabled and has_comp
        # Added for memory test - lock/restore START for the whole GOTO
        if hasattr(self, 'start_button'):
            if enabled:
                self.start_button.Enabled = getattr(self, '_start_enabled_before_goto', True)
            else:
                self._start_enabled_before_goto = self.start_button.Enabled
                self.start_button.Enabled = False
    
    def _on_goto_target(self, sender, event):
        """Handle GOTO button click - slew telescope to selected star."""
        if not self.sharpcap_available:
            MessageBox.Show("GOTO is only available when running in SharpCap.",
                          "Not Available", MessageBoxButtons.OK, MessageBoxIcon.Information)
            return
        
        if not self.current_target:
            MessageBox.Show("No target selected. Use Catalog > Select Target Star first.",
                          "No Target", MessageBoxButtons.OK, MessageBoxIcon.Warning)
            return
        
        # Get the currently selected object to determine which star to GOTO
        selected_obj = self.object_combo.Text
        
        # Determine which star (var, comp, or check) to slew to
        star = None
        star_type = "Target"
        catalog_type = 'V'  # Default to variable if not found in mapping
        is_catalog_star = selected_obj in self.star_name_map
        
        if is_catalog_star:
            actual_name, catalog_type = self.star_name_map[selected_obj]
            if catalog_type == 'V':
                star = self.current_target.variable
                star_type = "Variable"
            elif catalog_type == 'C':
                star = self.current_target.comparison
                star_type = "Comparison"
            elif catalog_type == 'K':
                star = self.current_target.check
                star_type = "Check"
        else:
            # Default to variable star if no mapping
            star = self.current_target.variable
            star_type = "Variable"
        
        if not star:
            MessageBox.Show("Could not determine target coordinates.",
                          "Error", MessageBoxButtons.OK, MessageBoxIcon.Error)
            return
        
        # Sync the Object dropdown only when an actual catalog star was selected;
        # base items (SKY/CATALOG/New Object) are left untouched
        if is_catalog_star:
            self._select_object_display(self._star_display_name(catalog_type))
        
        # Mutually lock both GOTO buttons during the slew
        self._set_goto_buttons_enabled(False)
        try:
            # Perform the slew (shared with the two-stage GOTO button)
            self._slew_to_star(star, star_type)
        finally:
            self._set_goto_buttons_enabled(True)
    
    def _slew_to_star(self, star, star_type, headless=False):
        """Slew the telescope to a star.
        
        Uses SharpCap mount control when a mount is connected, otherwise falls back
        to a manual GOTO with the coordinates copied to the clipboard.
        
        Args:
            star: StarData object with the target coordinates
            star_type: Human-readable label for status messages (e.g. "Comparison")
            headless: When True (sequence engine), suppress the modal manual-GOTO
                      dialog and just report the copied coordinates (NFR-3)
        
        Returns:
            True if the slew (or manual fallback) was performed, else False
        """
        # Get RA and Dec in decimal hours and degrees
        ra_hours = star.ra_hours + star.ra_minutes/60.0 + star.ra_seconds/3600.0
        dec_degrees = star.dec_degrees_decimal
        
        # Try to slew telescope using SharpCap API
        try:
            # Verify CancellationToken is available (should always be true in SharpCap)
            if CancellationToken is None:
                MessageBox.Show("GOTO functionality requires SharpCap environment.",
                              "Not Available", MessageBoxButtons.OK, MessageBoxIcon.Warning)
                return False
            
            # Check if mount control is available
            if hasattr(self.SharpCap, 'Mounts') and self.SharpCap.Mounts.SelectedMount:
                mount = self.SharpCap.Mounts.SelectedMount
                
                # Parse coordinates using CoordinateParser
                coord_string = "%s;%s" % (ra_hours, dec_degrees)
                coordinates = self.CoordinateParser.Parse(coord_string, True)
                
                # Update status and start slew
                self._update_status("Slewing to %s: %s (RA=%s, Dec=%s)" % (
                    star_type, star.name, star.ra_string(), star.dec_string()))
                
                print("Starting GOTO to: RA %.6fh, Dec %.6f°" % (ra_hours, dec_degrees))
                
                # Added for memory test - checkpoint before slew starts
                self._log_memory_point("Before StartSlewToAsync")
                # Start the slew, then pump the UI message loop while it
                # completes so the running camera's frame queue drains (an
                # unpumped block is what caused the original OOM crash), and
                # unwrap the result with SafeGetAsyncResult.
                slew_task = mount.StartSlewToAsync(coordinates, CancellationToken())
                self._pump_until_complete(slew_task, timeout_seconds=300, label="slew")
                self.SharpCap.SafeGetAsyncResult(slew_task)
                # Added for memory test - checkpoint after SafeGetAsyncResult returns
                self._log_memory_point("After SafeGetAsyncResult")
                
                # Wait for the mount to stop slewing and settle. Uses SharpCap's
                # mount helpers (Slewing / WaitUntilSettled) where available, else
                # best-effort state polling. All waits pump the UI so the running
                # camera's frame queue drains instead of accumulating.
                self._wait_for_mount_settle(mount)
                # Added for memory test - checkpoint after settle loop
                self._log_memory_point("After settle loop", force_gc=True)
                
                # Optionally plate solve + sync the mount after the GOTO.
                # Shared by every GOTO button (they all call _slew_to_star), and
                # only runs when the "Plate Solve and Sync" checkbox is ticked.
                # Added for memory test - bracket the solve with checkpoints so
                # its blocking window is measurable in the memory log.
                self._log_memory_point("Before SolveAndSync")
                self._solve_and_sync_mount(mount, star_type, star)
                self._log_memory_point("After SolveAndSync", force_gc=True)
                
                print("GOTO completed: RA %.4fh, Dec %.4f°" % (ra_hours, dec_degrees))
                self._update_status("GOTO completed to %s: %s" % (star_type, star.name))
                
            else:
                # No mount control - offer manual GOTO with clipboard
                print("Manual GOTO required: RA %.6fh, Dec %.6f°" % (ra_hours, dec_degrees))
                
                manual_msg = ("No mount control available.\n\n" +
                             "Please manually GOTO:\n\n" +
                             "You can use the SharpCap Push To Assistant\n\n" +
                             "RA:  %s (%.6f hours)\n" +
                             "Dec: %s (%.6f°)\n\n" +
                             "These coordinates have been copied to the clipboard.") % (
                                star.ra_string(), ra_hours,
                                star.dec_string(), dec_degrees)
                
                # Copy coordinates to clipboard
                Clipboard.SetText("%.6f, %.6f" % (ra_hours, dec_degrees))

                if headless:
                    # Sequence run: no modal dialog; the coordinates are on the
                    # clipboard and the step is treated as skipped (NFR-3)
                    self._update_status("No mount: %s coordinates copied to clipboard"
                                        % star.name)
                    return False

                MessageBox.Show(manual_msg, "Manual GOTO Required",
                              MessageBoxButtons.OK, MessageBoxIcon.Information)
                
                self._update_status("Manual GOTO: %s - coordinates copied to clipboard" % star.name)
            
            return True
            
        except Exception as e:
            import traceback
            error_msg = "Error slewing telescope:\n\n%s\n\nDetails:\n%s" % (str(e), traceback.format_exc())
            print("GOTO execution error: %s" % str(e))
            MessageBox.Show(error_msg, "GOTO Error", MessageBoxButtons.OK, MessageBoxIcon.Error)
            self._update_status("GOTO failed: " + str(e))
            return False
    
    def _solve_and_sync_mount(self, mount, star_type, star):
        """Plate solve + sync the mount after a GOTO when the option is enabled.
        
        Mirrors the occultation-manager behaviour: skipped silently when the
        "Plate Solve and Sync" checkbox is off, or when the mount cannot sync.
        A failure here is non-fatal - the slew itself already succeeded, so the
        status line reports the outcome and the caller continues.
        
        Args:
            mount: SharpCap mount object (SharpCap.Mounts.SelectedMount)
            star_type: Human-readable label for status messages (e.g. "Variable")
            star: StarData object that was slewed to (used for status text)
        """
        # Only run when the user has ticked the checkbox (persisted config)
        if self.config.get('plate_solve_sync', 0) != 1:
            return
        
        # Some mount drivers/versions do not expose SolveAndSync at all
        if not hasattr(mount, 'SolveAndSync'):
            print("Skipping SolveAndSync: mount API does not expose SolveAndSync")
            self._update_status("Mount settled. Plate solve/sync not available")
            return
        
        # Respect the mount's own capability flag when present
        if hasattr(mount, 'CanSync') and not mount.CanSync:
            print("Skipping SolveAndSync: mount does not support sync (CanSync=False)")
            self._update_status("Mount settled. Sync not supported by mount")
            return
        
        self._update_status("Mount settled. Running plate solve/sync...")
        print("Performing Solve And Sync...")
        try:
            # SolveAndSync() returns a task. Pump the UI message loop while it
            # runs so the running camera's frame queue drains instead of
            # accumulating (an unpumped block during the solve is exactly the
            # mechanism behind the original OutOfMemory crash), then unwrap the
            # bool result with SafeGetAsyncResult.
            #
            # Added for memory test - split the timing so the log shows whether
            # SolveAndSync() itself blocks (synchronous: call >> 0) or returns a
            # task we can pump (async: pump >> 0). This is the diagnostic that
            # decides the fix for the solve window's frame buffering.
            _t0 = time.time()
            solve_task = mount.SolveAndSync()
            _t1 = time.time()
            self._pump_until_complete(solve_task, timeout_seconds=300, label="SolveAndSync")
            _t2 = time.time()
            print("SolveAndSync timing: call=%.2fs pump=%.2fs pumpable=%s"
                  % (_t1 - _t0, _t2 - _t1, hasattr(solve_task, 'IsCompleted')))
            sync_ok = self.SharpCap.SafeGetAsyncResult(solve_task)
            if not sync_ok:
                print("Warning: SolveAndSync reported failure")
                self._update_status("Plate solve/sync to %s completed with warning" % star_type)
            else:
                self._update_status("Plate solve/sync complete for %s: %s" % (star_type, star.name))
        except Exception as sync_ex:
            print("Warning: SolveAndSync failed: %s" % str(sync_ex))
            self._update_status("Plate solve/sync failed; continuing")
    
    def _pump_until_complete(self, task, timeout_seconds=300, label="operation"):
        """Block on a .NET Task while pumping SharpCap's UI message loop.
        
        Added for memory test - an unpumped blocking wait freezes SharpCap's UI
        thread, so a running camera's frames queue up and memory can grow (this
        is the mechanism behind the original OutOfMemory crash; see
        MEMORY_ANALYSIS.md). Pumps in short slices via ssp_comm.pump_sleep until
        the task reports complete, then returns so the caller unwraps the result
        with SafeGetAsyncResult.
        
        Degrades to a plain blocking wait when the task cannot be polled (no
        IsCompleted attribute) or the window is closing, so it is always safe to
        call; the 300 s cap stops the pump spinning forever on a stuck task.
        
        Args:
            task: a .NET Task returned by a SharpCap/mount async call
            timeout_seconds: safety cap for the pump loop
            label: short name, used only for a diagnostic print on timeout
        """
        if not hasattr(task, 'IsCompleted'):
            # Added for memory test - surface the unpumpable case so an unpumped
            # blocking window can be identified directly from the SharpCap log.
            print("_pump_until_complete: '%s' task is not pollable (no IsCompleted)"
                  " - falling back to a plain blocking wait" % label)
            return  # caller falls back to the plain blocking wait
        start = time.time()
        while not task.IsCompleted and (time.time() - start) < timeout_seconds:
            # Added for memory test - stop pumping if the window began closing
            if self._closing:
                break
            ssp_comm.pump_sleep(0.1)
    
    def _wait_for_mount_settle(self, mount):
        """Wait for the mount to stop slewing and report settled.
        
        Ported from occultation-manager's execute_goto_command. Prefers SharpCap's
        mount helpers (Slewing / IsSlewing / WaitUntilSettled) and falls back to
        best-effort state polling for mounts that expose none of them. Never
        raises: settle-state ambiguity is reported and the caller continues (a
        false "still slewing" is preferable to a false failure).
        
        All waits use ssp_comm.pump_sleep so SharpCap's UI message pump keeps
        running - the running camera's frame queue drains instead of accumulating
        (see the memory-test notes).
        
        Args:
            mount: SharpCap mount object (SharpCap.Mounts.SelectedMount)
        """
        poll = 0.25  # seconds between state polls
        
        # 1. Some drivers complete the async task before physical motion fully
        #    stops. Keep the caller's "Slewing to ..." status until the motion
        #    flag clears (up to 300 s).
        if hasattr(mount, 'Slewing'):
            start = time.time()
            while mount.Slewing and (time.time() - start) < 300:
                ssp_comm.pump_sleep(poll)
        elif hasattr(mount, 'IsSlewing'):
            start = time.time()
            while mount.IsSlewing and (time.time() - start) < 300:
                ssp_comm.pump_sleep(poll)
        
        # 2. Prefer SharpCap's settle helper when available. Do not hard-fail on
        #    settle-state ambiguity to avoid false negatives.
        self._update_status("Waiting for mount to settle...")
        if hasattr(mount, 'WaitUntilSettled'):
            try:
                settle_task = mount.WaitUntilSettled(True, CancellationToken())
                self._pump_until_complete(settle_task, timeout_seconds=300, label="settle")
                self.SharpCap.SafeGetAsyncResult(settle_task)
                self._update_status("Mount settled")
            except Exception as settle_ex:
                print("Warning: WaitUntilSettled failed: %s" % str(settle_ex))
                self._update_status("Mount settle status unavailable; continuing")
            return
        
        # 3. Fallback: best-effort polling for mounts without WaitUntilSettled.
        settle_timeout_seconds = 20
        waited = False
        
        if hasattr(mount, 'Slewing'):
            waited = True
            start = time.time()
            while mount.Slewing and (time.time() - start) < settle_timeout_seconds:
                ssp_comm.pump_sleep(poll)
            if mount.Slewing:
                print("Warning: mount still reports slewing after async completion")
                self._update_status("Mount still reports slewing; continuing")
            else:
                self._update_status("Mount settled")
        elif hasattr(mount, 'IsSlewing'):
            waited = True
            start = time.time()
            while mount.IsSlewing and (time.time() - start) < settle_timeout_seconds:
                ssp_comm.pump_sleep(poll)
            if mount.IsSlewing:
                print("Warning: mount still reports IsSlewing after async completion")
                self._update_status("Mount still reports slewing; continuing")
            else:
                self._update_status("Mount settled")
        
        if hasattr(mount, 'IsSettled'):
            waited = True
            start = time.time()
            while (not mount.IsSettled) and (time.time() - start) < settle_timeout_seconds:
                ssp_comm.pump_sleep(poll)
            if not mount.IsSettled:
                print("Warning: mount did not report settled state after async completion")
                self._update_status("Mount settle state not confirmed; continuing")
            else:
                self._update_status("Mount settled")
        
        # 4. Last resort: guarantee a minimum settle if the mount exposes no
        #    motion or settle state at all.
        if not waited:
            ssp_comm.pump_sleep(2)
    
    def _on_goto_stage(self, sender, event):
        """Handle two-stage GOTO button click - slew to Comp, then Var (toggles each time)."""
        if not self.sharpcap_available:
            MessageBox.Show("GOTO is only available when running in SharpCap.",
                          "Not Available", MessageBoxButtons.OK, MessageBoxIcon.Information)
            return
        
        if not self.current_target:
            MessageBox.Show("No target selected. Use Catalog > Select Target Star first.",
                          "No Target", MessageBoxButtons.OK, MessageBoxIcon.Warning)
            return
        
        # Determine which star to slew to based on the current stage
        if self.auto_goto_stage == 'comp':
            star = self.current_target.comparison
            star_type = "Comparison"
        else:
            star = self.current_target.variable
            star_type = "Variable"
        
        if not star:
            MessageBox.Show("The %s star is not available for this target." % star_type.lower(),
                          "Star Not Available", MessageBoxButtons.OK, MessageBoxIcon.Warning)
            return
        
        # Sync the Object dropdown to the star we are about to slew to
        catalog_type = 'C' if self.auto_goto_stage == 'comp' else 'V'
        self._select_object_display(self._star_display_name(catalog_type))
        
        # Mutually lock both GOTO buttons during the slew
        self._set_goto_buttons_enabled(False)
        
        try:
            if self._slew_to_star(star, star_type):
                # Toggle stage and label: Comp -> Var -> Comp
                if self.auto_goto_stage == 'comp':
                    self.auto_goto_stage = 'var'
                    new_text = "GOTO Var"
                else:
                    self.auto_goto_stage = 'comp'
                    new_text = "GOTO Comp"
                
                if hasattr(self, 'goto_stage_button'):
                    self.goto_stage_button.Text = new_text
        finally:
            self._set_goto_buttons_enabled(True)

    # --- Sequence engine (Phase 2) -----------------------------------------

    def _on_run_sequence(self, sender, event):
        """Run the loaded sequence (opening the editor if none is loaded)."""
        seq = self.sequence
        if seq is None:
            self._on_edit_sequence(sender, event)
            return
        if not self.comm.is_connected:
            self._update_status("Error: connect to the SSP before running a sequence")
            return
        if self.current_target is None:
            self._update_status("Note: no target selected - GOTO steps will be skipped")
        # Apply the configured default run length if the sequence has none
        if not seq.max_minutes and not seq.max_observations and not seq.repeat:
            minutes = self.config.get('sequence_max_minutes', 60)
            if minutes:
                seq.max_minutes = float(minutes)
        self._remember_sequence(seq)
        self.run_sequence(seq)

    def _on_edit_sequence(self, sender, event):
        """Open the sequence builder dialog; run the sequence if requested."""
        try:
            dialog = ssp_dialogs.SequenceDialog(
                sequence=self.sequence, sequences_dir=self._sequences_dir(),
                night_mode=self.night_mode)
            dialog.ShowDialog(self)
            self.sequence = dialog.sequence
            if dialog.run_requested:
                self._remember_sequence(self.sequence)
                self.run_sequence(self.sequence)
        except Exception as e:
            import traceback
            print("Sequence editor error: %s" % e)
            print(traceback.format_exc())
            MessageBox.Show("Could not open the sequence editor:\n" + str(e),
                            "Sequence Editor", MessageBoxButtons.OK,
                            MessageBoxIcon.Error)

    def _remember_sequence(self, seq):
        """Persist the last sequence name + run-length defaults (FR-9)."""
        try:
            self.config.set('last_sequence_name', seq.name)
            self.config.set('sequence_max_minutes',
                            int(seq.max_minutes) if seq.max_minutes else 0)
            self.config.set('sequence_max_observations',
                            int(seq.max_observations) if seq.max_observations else 0)
            self.config.set('sequence_repeat',
                            int(seq.repeat) if seq.repeat else 0)
            self.config.save()
        except Exception:
            pass

    def _sequences_dir(self):
        """Return (creating if needed) the sequences dir under the config dir."""
        base = None
        try:
            base = self.config.config_dir
        except Exception:
            base = None
        if not base:
            try:
                base = System.IO.Path.Combine(
                    System.Environment.GetFolderPath(
                        System.Environment.SpecialFolder.MyDocuments),
                    'SharpCap', 'SSP')
            except Exception:
                base = None
        if not base:
            return None
        return ssp_sequence.sequences_dir(base)

    def _on_stop_sequence(self, sender, event):
        """Request the running sequence to stop after the current step."""
        if self._sequence_running:
            self._sequence_abort = True
            self._update_status("Stop requested - finishing current step...")
        else:
            self._update_status("No sequence is running")

    def _on_load_template(self, template_name):
        """Load one of the built-in templates into self.sequence."""
        seq = ssp_sequence.build_templates().get(template_name)
        if seq is None:
            return
        self.sequence = seq
        self.config.set('last_sequence_name', seq.name)
        self.config.save()
        self._update_status("Loaded template '%s' (%d steps)"
                            % (seq.name, seq.get_count()))

    def _on_export_sequence(self, sender, event):
        """Export the loaded sequence to a .ssp-style text file."""
        if self.sequence is None:
            self._update_status("No sequence to export")
            return
        dialog = SaveFileDialog()
        dialog.Filter = "SSP sequence files (*.ssp)|*.ssp|All files (*.*)|*.*"
        dialog.DefaultExt = "ssp"
        dialog.Title = "Export Sequence"
        if dialog.ShowDialog(self) != DialogResult.OK:
            return
        try:
            ssp_sequence.save_ssp_text(self.sequence, dialog.FileName)
            self._update_status("Exported sequence to " + dialog.FileName)
        except Exception as e:
            MessageBox.Show("Could not export sequence:\n" + str(e),
                            "Export Sequence", MessageBoxButtons.OK,
                            MessageBoxIcon.Error)

    def run_sequence(self, sequence):
        """Execute a PEPSequence on the UI thread, pumping between steps.

        Runs full passes over the step list until a run-length limit
        (max_minutes / max_observations), the optional pass cap (repeat), an
        abort, or a disconnect stops it (FR-2, FR-8, FR-11).
        """
        if self._sequence_running:
            return
        if not self.comm.is_connected:
            self._update_status("Error: connect to the SSP before running a sequence")
            return
        if self.current_target is None:
            self._update_status("Note: no target selected - GOTO steps will be skipped")

        self._sequence_running = True
        self._sequence_abort = False
        self._sequence_obs_count = 0
        self._sequence = sequence
        self._sequence_start = DateTime.UtcNow
        self._sequence_step_index = 0
        self._sequence_steps_total = sequence.get_count()
        self._set_sequence_controls_running(True)
        try:
            self._update_status("Sequence '%s' started" % sequence.name)
            print("Sequence '%s' started (%d steps)"
                  % (sequence.name, self._sequence_steps_total))
            passes = 0
            repeat = sequence.repeat
            if not repeat and not sequence.max_minutes and \
                    not sequence.max_observations:
                self._update_status("Sequence has no run-length limit; running one pass")
                repeat = 1
            while not self._sequence_should_stop(sequence):
                self._run_step_list(sequence.steps, sequence)
                passes += 1
                if repeat and passes >= max(1, int(repeat)):
                    break
        finally:
            self._sequence_running = False
            self._sequence = None
            self._set_sequence_controls_running(False)
            self._update_status("Sequence finished - %d observations"
                                % self._sequence_obs_count)
            print("Sequence finished - %d observations" % self._sequence_obs_count)

    def _sequence_should_stop(self, sequence):
        """FR-2 / FR-8 / FR-11: minute/observation limit, abort, or comm loss."""
        if self._closing or self._sequence_abort:
            return True
        if not self.comm.is_connected:
            self._update_status("Sequence aborted: SSP disconnected")
            return True
        if sequence.max_observations and \
                self._sequence_obs_count >= int(sequence.max_observations):
            return True
        if sequence.max_minutes and self._sequence_start is not None:
            elapsed_min = (DateTime.UtcNow - self._sequence_start).TotalMinutes
            if elapsed_min >= float(sequence.max_minutes):
                return True
        return False

    def _run_step_list(self, steps, sequence):
        """Dispatch each step; REPEAT recurses with its own stop check."""
        i = 0
        n = len(steps)
        while i < n:
            if self._sequence_should_stop(sequence):
                return
            step = steps[i]
            self._sequence_step_index = i + 1
            self._update_step_status(sequence, step)
            kind = step.kind
            try:
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
                    count = int(step.params.get('count', 1) or 1)
                    body = steps[i + 1:end]
                    for _ in range(max(1, count)):
                        if self._sequence_should_stop(sequence):
                            return
                        self._run_step_list(body, sequence)
                    i = end
                # END is consumed by REPEAT handling; a stray END is ignored
            except Exception as exc:
                # One failed step must not abort the whole run (FR-11)
                import traceback
                print("Sequence step error (%s): %s" % (kind, exc))
                print(traceback.format_exc())
                self._update_status("Step error (%s): %s" % (kind, exc))
            i += 1

    def _find_matching_end(self, steps, start_index):
        """Return the index of the END matching the REPEAT at start_index."""
        depth = 0
        for j in range(start_index + 1, len(steps)):
            kind = steps[j].kind
            if kind == "REPEAT":
                depth += 1
            elif kind == "END":
                if depth == 0:
                    return j
                depth -= 1
        self._update_status("Warning: REPEAT without matching END")
        return len(steps)

    def _step_goto(self, step):
        """Slew to a target star or offset position (headless - no modal)."""
        star, label = self._resolve_step_star(step)
        if star is None:
            self._update_status("GOTO skipped: %s" % label)
            return
        ref = str(step.params.get('star_ref', 'V')).upper()
        if ref in ('V', 'C', 'K'):
            # Sync the Object/Catalog dropdowns (base items left untouched)
            self._select_object_display(self._star_display_name(ref))
        if not self.sharpcap_available:
            self._update_status("GOTO skipped (standalone): %s" % label)
            return
        self._slew_to_star(star, label, headless=True)

    def _step_measure(self, step):
        """One PEP measurement; missing params inherit the current UI values."""
        p = step.params
        ok, _line = self.take_reading(
            p.get('object', self.object_combo.Text),
            p.get('catalog', self.catalog_combo.Text),
            p.get('filter', self.filter_combo.Text),
            p.get('gain', self.gain_combo.Text),
            float(p.get('integ', self.integ_combo.Text)),
            int(p.get('interval', self.interval_combo.Text)),
            self.mode_combo.Text, headless=True)
        if ok:
            self._sequence_obs_count += 1
        else:
            self._update_status("Measurement step failed; continuing")

    def _step_sky(self, step):
        """A sky reading (SKY/SKYNEXT/SKYLAST), optionally after an offset slew."""
        p = step.params
        label = str(p.get('label', 'SKYLAST'))
        coord = dict((k, p[k]) for k in ('ra', 'dec', 'd_ra_h', 'd_dec_deg')
                     if k in p)
        if coord:
            self._step_goto(ssp_sequence.SequenceStep('GOTO', star_ref='SKY', **coord))
        ok, _line = self.take_reading(
            label, " ",
            p.get('filter', self.filter_combo.Text),
            p.get('gain', self.gain_combo.Text),
            float(p.get('integ', self.integ_combo.Text)),
            int(p.get('interval', self.interval_combo.Text)),
            self.mode_combo.Text, headless=True)
        if ok:
            self._sequence_obs_count += 1

    def _step_filter(self, step):
        """Change the filter (combo + bar move in auto mode)."""
        name = step.params.get('filter')
        if name:
            self._select_filter_by_name(name)

    def _step_wait(self, step):
        """Pause (pumping the UI so the camera frame queue drains)."""
        ssp_comm.pump_sleep(float(step.params.get('seconds', 1) or 0))

    def _step_wait_until(self, step):
        """Wait until an absolute UTC date/time.

        If the target is <= 30 minutes past, proceed immediately with a warning;
        if more than 30 minutes past, stop the run with a warning.
        """
        target = self._parse_utc_datetime(step.params.get('utc_datetime'))
        if target is None:
            self._update_status("WAIT_UNTIL: invalid UTC datetime; skipping step")
            return
        while True:
            if self._sequence is not None and \
                    self._sequence_should_stop(self._sequence):
                return
            remaining = (target - DateTime.UtcNow).TotalSeconds
            if remaining <= 0:
                late_min = (-remaining) / 60.0
                if late_min <= 30.0:
                    self._update_status("WAIT_UNTIL: %.1f min late; proceeding"
                                        % late_min)
                    return
                self._update_status("WAIT_UNTIL: >30 min late; stopping run")
                self._sequence_abort = True
                return
            ssp_comm.pump_sleep(min(remaining, 5.0))

    def _parse_utc_datetime(self, text):
        """Parse 'YYYY-MM-DD HH:MM:SS' or 'YYYY-MM-DDTHH:MM:SSZ' as UTC.

        Returns a UTC System.DateTime, or None if the string is missing or
        malformed.
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
            return DateTime(y, mo, d, h, mi, sec, System.DateTimeKind.Utc)
        except Exception:
            return None

    def _step_abort_if(self, step):
        """Return True if the run should stop (below horizon / over airmass)."""
        if not (self.current_target and self.current_target.variable):
            return False
        alt_below = step.params.get('alt_below')
        airmass_above = step.params.get('airmass_above')
        if alt_below is None and airmass_above is None:
            return False
        has_loc, alt, airmass = self._current_alt_airmass(self.current_target.variable)
        if not has_loc:
            self._update_status("ABORT_IF skipped: observer location not set")
            return False
        if alt is None:                       # below horizon
            self._update_status("ABORT_IF: target below horizon")
            return True
        if alt_below is not None and alt < float(alt_below):
            self._update_status("ABORT_IF: target below altitude %s" % alt_below)
            return True
        if (airmass_above is not None and airmass is not None and
                airmass > float(airmass_above)):
            self._update_status("ABORT_IF: airmass above %s" % airmass_above)
            return True
        return False

    def _resolve_step_star(self, step):
        """Return (StarData, label) for a GOTO/SKY step, or (None, reason)."""
        p = step.params
        ref = str(p.get('star_ref', 'V')).upper()
        if ref == 'V':
            v = self.current_target.variable if self.current_target else None
            return (v, "Variable") if v else (None, "no target selected")
        if ref == 'C':
            c = self.current_target.comparison if self.current_target else None
            return (c, "Comparison") if c else (None, "no comparison star")
        if ref == 'K':
            k = self.current_target.check if self.current_target else None
            return (k, "Check") if k else (None, "no check star")
        if (ref in ('SKY', 'OFFSET') or 'ra' in p or 'd_ra_h' in p or
                'd_dec_deg' in p):
            if 'ra' in p and 'dec' in p:
                star = self._make_star_from_radec(p['ra'], p['dec'])
            else:
                star = self._make_offset_star(float(p.get('d_ra_h', 0.0)),
                                              float(p.get('d_dec_deg', 0.0)))
            return (star, "Sky offset") if star else (None, "no target for offset")
        return (None, "unknown star_ref %r" % ref)

    def _make_offset_star(self, d_ra_h, d_dec_deg, name="SKY-OFF"):
        """Pseudo StarData offset from the current target's variable star.

        Small offsets only: the delta is applied directly to RA hours and Dec
        degrees (precession/refraction ignored) - adequate for a sky patch a few
        tenths of a degree to a few degrees from the target. Returns None if no
        target is selected.
        """
        if not (self.current_target and self.current_target.variable):
            return None
        v = self.current_target.variable
        ra_h = (v.ra_hours + v.ra_minutes / 60.0 + v.ra_seconds / 3600.0 +
                d_ra_h) % 24.0
        dec = v.dec_degrees_decimal + d_dec_deg
        rh = int(ra_h)
        rm = int((ra_h - rh) * 60.0)
        rs = (((ra_h - rh) * 60.0) - rm) * 60.0
        sign = 1 if dec >= 0 else -1
        da = abs(dec)
        dd = int(da) * sign
        dm = int((da - abs(dd)) * 60.0)
        ds = (((da - abs(dd)) * 60.0) - dm) * 60.0
        return ssp_catalog.StarData(name=name, ra_hours=rh, ra_minutes=rm,
                                    ra_seconds=rs, dec_degrees=dd,
                                    dec_minutes=dm, dec_seconds=ds)

    def _make_star_from_radec(self, ra, dec, name="SKY-ABS"):
        """Pseudo StarData from explicit RA (hours) and Dec (degrees)."""
        ra = float(ra) % 24.0
        dec = float(dec)
        rh = int(ra)
        rm = int((ra - rh) * 60.0)
        rs = (((ra - rh) * 60.0) - rm) * 60.0
        sign = 1 if dec >= 0 else -1
        da = abs(dec)
        dd = int(da) * sign
        dm = int((da - abs(dd)) * 60.0)
        ds = (((da - abs(dd)) * 60.0) - dm) * 60.0
        return ssp_catalog.StarData(name=name, ra_hours=rh, ra_minutes=rm,
                                    ra_seconds=rs, dec_degrees=dd,
                                    dec_minutes=dm, dec_seconds=ds)

    def _current_alt_airmass(self, star):
        """Return (has_location, alt, airmass) via ssp_extinction.AirmassCalculator.

        has_location is False when the observer location is unset (0,0); when it
        is set, alt/airmass are None if the target is below the horizon.
        """
        try:
            lat = self.config.get('observer_latitude', 0.0)
            lon = self.config.get('observer_longitude', 0.0)
            if not lat and not lon:
                return (False, None, None)
            import ssp_extinction
            from datetime import datetime, timezone
            calc = ssp_extinction.AirmassCalculator(lat, lon)
            now = datetime.now(timezone.utc)
            ra_deg = (star.ra_hours + star.ra_minutes / 60.0 +
                      star.ra_seconds / 3600.0) * 15.0
            dec_deg = star.dec_degrees_decimal
            alt, _azimuth = calc.calculate_altaz(ra_deg, dec_deg, now)
            airmass = calc.calculate_airmass(ra_deg, dec_deg, now)
            return (True, alt, airmass)
        except Exception as exc:
            print("ABORT_IF alt/airmass error: %s" % exc)
            return (False, None, None)

    def _select_filter_by_name(self, filter_name):
        """Set the filter combo (suppressing its event) and move the bar in auto."""
        if not filter_name:
            return
        self.updating_filter_combo = True
        try:
            for i in range(self.filter_combo.Items.Count):
                if str(self.filter_combo.Items[i]) == str(filter_name):
                    self.filter_combo.SelectedIndex = i
                    break
        finally:
            self.updating_filter_combo = False
        auto_manual = self.config.get('auto_manual', 'M')
        if auto_manual == 'A' and str(filter_name).lower() != "home":
            position = self._filter_position_for_name(filter_name)
            if position is not None and 1 <= position <= 6 and self.comm.is_connected:
                ok, _retry, msg = self.comm.select_filter(position)
                if ok:
                    self._update_status("Filter %s is in position" % filter_name)
                else:
                    self._update_status("Warning: filter not confirmed - " + msg)

    def _update_step_status(self, sequence, step):
        """Short progress line in the status box."""
        try:
            total_min = 0.0
            if self._sequence_start is not None:
                total_min = (DateTime.UtcNow - self._sequence_start).TotalMinutes
            obs = self._sequence_obs_count
            if sequence.max_observations:
                obs_str = "obs %d/%d" % (obs, int(sequence.max_observations))
            else:
                obs_str = "obs %d" % obs
            self._update_status("Seq '%s' step %d/%d - %s - %.1f min"
                                % (sequence.name, self._sequence_step_index,
                                   self._sequence_steps_total, obs_str, total_min))
        except Exception:
            pass

    def _set_sequence_controls_running(self, running):
        """Lock START/GOTO/RUN during a run; toggle STOP."""
        try:
            if hasattr(self, 'start_button'):
                self.start_button.Enabled = not running
            if hasattr(self, 'run_seq_button'):
                self.run_seq_button.Enabled = not running
            if hasattr(self, 'stop_seq_button'):
                self.stop_seq_button.Enabled = running
            if hasattr(self, 'goto_button'):
                self.goto_button.Enabled = (not running) and bool(self.current_target)
            if hasattr(self, 'goto_stage_button'):
                has_comp = bool(self.current_target and
                                self.current_target.comparison)
                self.goto_stage_button.Enabled = (not running) and has_comp
        except Exception:
            pass


class StarSelectionDialog(Form):
    """Dialog for selecting stars from catalog."""
    
    def __init__(self, catalog, config=None):
        """
        Initialize star selection dialog.
        
        Args:
            catalog: StarCatalog object
            config: SSPConfig object (optional, for observer location)
        """
        self.catalog = catalog
        self.config = config
        self.selected_target = None
        
        self.Text = "Select Target Star"
        self.Width = 900
        self.Height = 600
        self.StartPosition = FormStartPosition.CenterParent
        self.FormBorderStyle = FormBorderStyle.FixedDialog
        self.MaximizeBox = False
        self.MinimizeBox = False
        self.AutoScaleMode = AutoScaleMode.Dpi
        self.AutoScaleDimensions = System.Drawing.SizeF(96, 96)
        
        # Calculate Alt/Az if observer location is available
        self.alt_az_data = {}
        if config:
            # Config stores values in a dictionary, not as attributes
            lat = config.get('observer_latitude', 0.0)
            lon = config.get('observer_longitude', 0.0)
            
            if lat != 0.0 and lon != 0.0:
                try:
                    from datetime import datetime, timezone
                    import ssp_extinction
                    
                    # Use current UTC time
                    current_time = datetime.now(timezone.utc)
                    calc = ssp_extinction.AirmassCalculator(lat, lon)
                    
                    # Calculate Alt/Az for each star in catalog
                    for target in catalog.targets:
                        ra_deg = (target.variable.ra_hours + target.variable.ra_minutes/60.0 + 
                                  target.variable.ra_seconds/3600.0) * 15.0
                        dec_deg = target.variable.dec_degrees_decimal
                        
                        altitude, azimuth = calc.calculate_altaz(ra_deg, dec_deg, current_time)
                        self.alt_az_data[target.variable.name] = (altitude, azimuth)
                        
                except Exception as ex:
                    print("Error calculating Alt/Az: %s" % ex)
                    import traceback
                    print(traceback.format_exc())
                    self.alt_az_data = {}
        
        self._setup_ui()
    
    def _setup_ui(self):
        """Setup user interface."""
        # Suspend layout during setup for better performance
        self.SuspendLayout()
        
        # Search panel at top
        search_panel = Panel()
        search_panel.Dock = DockStyle.Top
        search_panel.Height = 75
        search_panel.Padding = Padding(10)
        
        search_label = Label()
        search_label.Text = "Search by name:"
        search_label.Location = Point(10, 15)
        search_label.Size = Size(110, 25)
        search_label.BackColor = self.BackColor
        search_panel.Controls.Add(search_label)
        
        self.search_box = TextBox()
        self.search_box.Location = Point(125, 12)
        self.search_box.Size = Size(300, 25)
        self.search_box.TextChanged += self._on_search_changed
        search_panel.Controls.Add(self.search_box)
        
        search_info = Label()
        search_info.Text = "Type to filter star names (e.g., 'ALF', 'CET', 'NSV')"
        search_info.Location = Point(435, 15)
        search_info.Size = Size(350, 25)
        search_info.BackColor = self.BackColor
        search_info.ForeColor = Color.Gray
        search_panel.Controls.Add(search_info)
        
        # Results counter
        self.results_label = Label()
        self.results_label.Text = "All stars (%d)" % self.catalog.get_count()
        self.results_label.Location = Point(10, 45)
        self.results_label.Size = Size(750, 25)
        self.results_label.BackColor = self.BackColor
        self.results_label.ForeColor = Color.Blue
        self.results_label.Font = Font("Arial", 8, FontStyle.Bold)
        search_panel.Controls.Add(self.results_label)
        
        # Button panel at very bottom
        button_panel = Panel()
        button_panel.Dock = DockStyle.Bottom
        button_panel.Height = 50
        
        ok_button = Button()
        ok_button.Text = "Select"
        ok_button.Size = Size(100, 30)
        ok_button.Location = Point(550, 10)
        ok_button.Click += self._on_ok_click
        button_panel.Controls.Add(ok_button)
        
        cancel_button = Button()
        cancel_button.Text = "Cancel"
        cancel_button.Size = Size(100, 30)
        cancel_button.Location = Point(660, 10)
        cancel_button.Click += self._on_cancel_click
        button_panel.Controls.Add(cancel_button)
        
        # Detail panel above buttons
        detail_panel = Panel()
        detail_panel.Dock = DockStyle.Bottom
        detail_panel.Height = 150
        detail_panel.Padding = Padding(10)
        
        self.detail_text = TextBox()
        self.detail_text.Multiline = True
        self.detail_text.ReadOnly = True
        self.detail_text.Dock = DockStyle.Fill
        self.detail_text.ScrollBars = ScrollBars.Vertical
        self.detail_text.Font = Font("Consolas", 9)
        detail_panel.Controls.Add(self.detail_text)
        
        # DataGridView for stars - fills middle space
        self.star_grid = DataGridView()
        self.star_grid.Dock = DockStyle.Fill
        self.star_grid.Font = Font("Consolas", 9)
        self.star_grid.ReadOnly = True
        self.star_grid.AllowUserToAddRows = False
        self.star_grid.AllowUserToDeleteRows = False
        self.star_grid.SelectionMode = DataGridViewSelectionMode.FullRowSelect
        self.star_grid.MultiSelect = False
        self.star_grid.RowHeadersVisible = False
        self.star_grid.SelectionChanged += self._on_star_selected
        self.star_grid.DoubleClick += self._on_star_double_click
        
        # Add columns - use DataGridViewTextBoxColumn for proper creation
        col_name = DataGridViewTextBoxColumn()
        col_name.Name = "Name"
        col_name.HeaderText = "Name"
        col_name.Width = 150
        # Use getattr to access None enum member since None is a Python keyword
        try:
            none_mode = getattr(DataGridViewAutoSizeColumnMode, 'None')
            col_name.AutoSizeMode = none_mode
        except:
            pass
        self.star_grid.Columns.Add(col_name)
        
        col_vmag = DataGridViewTextBoxColumn()
        col_vmag.Name = "VMag"
        col_vmag.HeaderText = "V Mag"
        col_vmag.Width = 70
        col_vmag.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight
        try:
            none_mode = getattr(DataGridViewAutoSizeColumnMode, 'None')
            col_vmag.AutoSizeMode = none_mode
        except:
            pass
        self.star_grid.Columns.Add(col_vmag)
        
        col_ra = DataGridViewTextBoxColumn()
        col_ra.Name = "RA"
        col_ra.HeaderText = "RA"
        col_ra.Width = 100
        col_ra.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight
        try:
            none_mode = getattr(DataGridViewAutoSizeColumnMode, 'None')
            col_ra.AutoSizeMode = none_mode
        except:
            pass
        self.star_grid.Columns.Add(col_ra)
        
        col_dec = DataGridViewTextBoxColumn()
        col_dec.Name = "Dec"
        col_dec.HeaderText = "Dec"
        col_dec.Width = 100
        col_dec.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight
        try:
            none_mode = getattr(DataGridViewAutoSizeColumnMode, 'None')
            col_dec.AutoSizeMode = none_mode
        except:
            pass
        self.star_grid.Columns.Add(col_dec)
        
        col_alt = DataGridViewTextBoxColumn()
        col_alt.Name = "Alt"
        col_alt.HeaderText = "Alt"
        col_alt.Width = 60
        col_alt.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight
        try:
            none_mode = getattr(DataGridViewAutoSizeColumnMode, 'None')
            col_alt.AutoSizeMode = none_mode
        except:
            pass
        self.star_grid.Columns.Add(col_alt)
        
        col_az = DataGridViewTextBoxColumn()
        col_az.Name = "Az"
        col_az.HeaderText = "Az"
        col_az.Width = 60
        col_az.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight
        try:
            none_mode = getattr(DataGridViewAutoSizeColumnMode, 'None')
            col_az.AutoSizeMode = none_mode
        except:
            pass
        self.star_grid.Columns.Add(col_az)
        
        # Add controls in this specific order
        self.Controls.Add(self.star_grid)      # Fill - add first
        self.Controls.Add(detail_panel)        # Bottom #1 - add second
        self.Controls.Add(button_panel)        # Bottom #2 - add third
        self.Controls.Add(search_panel)        # Top - add last (appears on top)
        
        # Resume layout and force refresh
        self.ResumeLayout(True)
        self.PerformLayout()
        
        # Populate grid
        self._populate_list()
    
    def _populate_list(self, filter_text=""):
        """Populate the star grid with optional filtering."""
        self.star_grid.Rows.Clear()
        
        filter_upper = filter_text.upper().strip()
        match_count = 0
        
        for target in self.catalog.targets:
            # Get name and normalize whitespace
            name = target.variable.name.strip()
            name_upper = name.upper()
            
            # Check if filter matches (case-insensitive substring search)
            if not filter_upper or filter_upper in name_upper:
                vmag_str = "%.2f" % target.variable.vmag if target.variable.vmag is not None else "?.??"
                ra_str = target.variable.ra_string()
                dec_str = target.variable.dec_string()
                
                # Get Alt/Az if calculated
                if name in self.alt_az_data:
                    altitude, azimuth = self.alt_az_data[name]
                    if altitude is not None and altitude >= 0:
                        alt_str = "%d" % round(altitude)
                        az_str = "%d" % round(azimuth)
                    else:
                        alt_str = "<0"
                        az_str = "-"
                else:
                    # Location not set
                    alt_str = "?"
                    az_str = "?"
                
                # Add row to grid
                self.star_grid.Rows.Add(name, vmag_str, ra_str, dec_str, alt_str, az_str)
                match_count += 1
        
        # Update results label
        if filter_upper:
            self.results_label.Text = "Found %d matches for '%s'" % (match_count, filter_text)
            self.results_label.ForeColor = Color.Green if match_count > 0 else Color.Red
        else:
            self.results_label.Text = "All stars (%d)" % match_count
            self.results_label.ForeColor = Color.Blue
        
        if self.star_grid.Rows.Count == 0:
            self.star_grid.Rows.Add("(No matches found)", "", "", "", "", "")
    
    def _on_search_changed(self, sender, event):
        """Handle search text changed."""
        self._populate_list(self.search_box.Text)
    
    def _on_star_selected(self, sender, event):
        """Handle star selection changed."""
        if self.star_grid.SelectedRows.Count == 0:
            return
        
        # Get selected star name from first column
        row = self.star_grid.SelectedRows[0]
        star_name = str(row.Cells[0].Value)
        
        if star_name.startswith("(No matches"):
            return
        
        # Find target in catalog
        target = self.catalog.get_target_by_name(star_name)
        if target:
            self.selected_target = target
            self._show_target_details(target)
    
    def _show_target_details(self, target):
        """Show detailed information about selected target."""
        details = []
        details.append("=" * 70)
        details.append("VARIABLE STAR: " + target.variable.name)
        details.append("=" * 70)
        
        if target.auid:
            details.append("AAVSO ID: " + target.auid)
        if target.old_desig:
            details.append("Old Designation: " + target.old_desig)
        
        details.append("")
        details.append("VARIABLE:")
        details.append("  RA:            " + target.variable.ra_string())
        details.append("  Dec:           " + target.variable.dec_string())
        details.append("  V magnitude:   " + ("%.3f" % target.variable.vmag if target.variable.vmag else "N/A"))
        details.append("  B-V color:     " + ("%.3f" % target.variable.bv_color if target.variable.bv_color else "N/A"))
        details.append("  Spectral type: " + target.variable.spectral_type)
        
        details.append("")
        details.append("COMPARISON STAR: " + target.comparison.name)
        details.append("  RA:          " + target.comparison.ra_string())
        details.append("  Dec:         " + target.comparison.dec_string())
        details.append("  V magnitude: " + ("%.3f" % target.comparison.vmag if target.comparison.vmag else "N/A"))
        details.append("  B-V color:   " + ("%.3f" % target.comparison.bv_color if target.comparison.bv_color else "N/A"))
        
        details.append("")
        details.append("CHECK STAR: " + target.check.name)
        details.append("  RA:          " + target.check.ra_string())
        details.append("  Dec:         " + target.check.dec_string())
        details.append("  V magnitude: " + ("%.3f" % target.check.vmag if target.check.vmag else "N/A"))
        
        if target.delta_bv is not None:
            details.append("")
            details.append("Delta (B-V) [Variable - Comparison]: %.3f" % target.delta_bv)
        
        self.detail_text.Text = "\r\n".join(details)
    
    def _on_star_double_click(self, sender, event):
        """Handle double-click on star (same as clicking OK)."""
        if self.selected_target:
            self.DialogResult = DialogResult.OK
            self.Close()
    
    def _on_ok_click(self, sender, event):
        """Handle OK button click."""
        if self.selected_target:
            self.DialogResult = DialogResult.OK
            self.Close()
        else:
            MessageBox.Show("Please select a star first.", "No Selection",
                          MessageBoxButtons.OK, MessageBoxIcon.Warning)
    
    def _on_cancel_click(self, sender, event):
        """Handle Cancel button click."""
        self.DialogResult = DialogResult.Cancel
        self.Close()


class ExtinctionStarSelectionDialog(Form):
    """Dialog for selecting first order extinction standard stars with airmass filtering."""
    
    def __init__(self, extinction_catalog, config=None, last_filter=None, parent=None):
        """
        Initialize extinction star selection dialog.
        
        Args:
            extinction_catalog: ExtinctionCatalog object
            config: SSPConfig object (optional, for observer location)
            last_filter: Last used airmass filter value (optional)
            parent: Parent window (for night mode access)
        """
        self.extinction_catalog = extinction_catalog
        self.config = config
        self.parent = parent
        self.selected_star = None
        self.selected_airmass = None
        self.active_filter = None  # Track active airmass filter
        self.used_filter = None  # Track which filter was used for selection
        
        self.Text = "Select First Order Extinction Star"
        self.Width = 1100
        self.Height = 600
        self.StartPosition = FormStartPosition.CenterParent
        self.FormBorderStyle = FormBorderStyle.Sizable
        self.MaximizeBox = True
        self.MinimizeBox = False
        self.AutoScaleMode = AutoScaleMode.Dpi
        self.AutoScaleDimensions = System.Drawing.SizeF(96, 96)
        
        # Calculate airmass, altitude, azimuth for all stars if observer location is available
        self.star_airmass = {}
        self.star_altitude = {}
        self.star_azimuth = {}
        if config:
            lat = config.get('observer_latitude', 0.0)
            lon = config.get('observer_longitude', 0.0)
            
            if lat != 0.0 and lon != 0.0:
                try:
                    from datetime import datetime, timezone
                    import ssp_extinction
                    
                    current_time = datetime.now(timezone.utc)
                    calc = ssp_extinction.AirmassCalculator(lat, lon)
                    
                    for star in extinction_catalog.stars:
                        altitude, azimuth = calc.calculate_altaz(star.ra_deg, star.dec_deg, current_time)
                        if altitude is not None and altitude > 0:
                            # Store altitude and azimuth
                            self.star_altitude[star.name] = altitude
                            self.star_azimuth[star.name] = azimuth
                            
                            # Calculate airmass using Hardie formula
                            zenith_angle = 90.0 - altitude
                            zenith_rad = math.radians(zenith_angle)
                            airmass = 1.0 / math.cos(zenith_rad) - 0.0018167 * (1.0 / math.cos(zenith_rad) - 1.0)
                            # Store if reasonable airmass (<= 5)
                            if airmass <= 5.0:
                                self.star_airmass[star.name] = airmass
                except Exception as ex:
                    print("Error calculating airmass: %s" % ex)
                    import traceback
                    print(traceback.format_exc())
        
        # Auto-select next filter if a previous filter was used
        self._auto_select_next_filter(last_filter)
        
        self._setup_ui()
    
    def _auto_select_next_filter(self, last_filter):
        """Automatically select the next airmass filter based on last selection.
        
        Args:
            last_filter: The airmass value of the last used filter
        """
        if last_filter is None:
            return
        
        # Define available filter values
        airmass_values = [1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5]
        
        # Find the next filter value
        try:
            current_index = airmass_values.index(last_filter)
            if current_index < len(airmass_values) - 1:
                # Select next filter in sequence
                self.active_filter = airmass_values[current_index + 1]
            else:
                # At the end, wrap to first
                self.active_filter = airmass_values[0]
        except ValueError:
            # Last filter not in list, don't auto-select
            pass
    
    def _setup_ui(self):
        """Setup user interface."""
        self.SuspendLayout()
        
        # Top panel for filter buttons
        filter_panel = Panel()
        filter_panel.Dock = DockStyle.Top
        filter_panel.Height = 60
        filter_panel.BorderStyle = BorderStyle.FixedSingle
        
        # Filter label
        filter_label = Label()
        filter_label.Text = "Filter by Airmass:"
        filter_label.Location = Point(10, 10)
        filter_label.Size = Size(120, 20)
        filter_label.Font = Font("Arial", 9, FontStyle.Bold)
        filter_panel.Controls.Add(filter_label)
        
        # Filter buttons for airmass ranges
        x_pos = 10
        y_pos = 32
        button_width = 70
        button_spacing = 5
        
        airmass_values = [1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5]
        self.filter_buttons = []
        
        for am_value in airmass_values:
            btn = Button()
            btn.Text = "%.2f" % am_value
            btn.Location = Point(x_pos, y_pos)
            btn.Size = Size(button_width, 24)
            btn.Tag = am_value
            btn.Click += self._on_filter_button_click
            filter_panel.Controls.Add(btn)
            self.filter_buttons.append(btn)
            x_pos += button_width + button_spacing
        
        # Reset filter button
        reset_btn = Button()
        reset_btn.Text = "Reset"
        reset_btn.Location = Point(x_pos + 10, y_pos)
        reset_btn.Size = Size(80, 24)
        reset_btn.Click += self._on_reset_filter
        reset_btn.Font = Font(reset_btn.Font, FontStyle.Bold)
        filter_panel.Controls.Add(reset_btn)
        
        # Bottom panel for buttons
        button_panel = Panel()
        button_panel.Dock = DockStyle.Bottom
        button_panel.Height = 50
        
        select_btn = Button()
        select_btn.Text = "Select"
        select_btn.Location = Point(self.Width // 2 - 90, 10)
        select_btn.Size = Size(80, 30)
        select_btn.Click += self._on_select_click
        button_panel.Controls.Add(select_btn)
        
        cancel_btn = Button()
        cancel_btn.Text = "Cancel"
        cancel_btn.Location = Point(self.Width // 2 + 10, 10)
        cancel_btn.Size = Size(80, 30)
        cancel_btn.Click += self._on_cancel_click
        button_panel.Controls.Add(cancel_btn)
        
        self.AcceptButton = select_btn
        self.CancelButton = cancel_btn
        
        # DataGridView for stars - fills middle space
        self.star_grid = DataGridView()
        self.star_grid.Dock = DockStyle.Fill
        self.star_grid.Font = Font("Consolas", 9)
        self.star_grid.ReadOnly = True
        self.star_grid.AllowUserToAddRows = False
        self.star_grid.AllowUserToDeleteRows = False
        self.star_grid.SelectionMode = DataGridViewSelectionMode.FullRowSelect
        self.star_grid.MultiSelect = False
        self.star_grid.RowHeadersVisible = False
        self.star_grid.DoubleClick += self._on_star_double_click
        
        # Add columns
        col_name = DataGridViewTextBoxColumn()
        col_name.Name = "Name"
        col_name.HeaderText = "Star Name"
        col_name.Width = 150
        try:
            none_mode = getattr(DataGridViewAutoSizeColumnMode, 'None')
            col_name.AutoSizeMode = none_mode
        except:
            pass
        self.star_grid.Columns.Add(col_name)
        
        col_ra = DataGridViewTextBoxColumn()
        col_ra.Name = "RA"
        col_ra.HeaderText = "RA (hours)"
        col_ra.Width = 100
        col_ra.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight
        try:
            none_mode = getattr(DataGridViewAutoSizeColumnMode, 'None')
            col_ra.AutoSizeMode = none_mode
        except:
            pass
        self.star_grid.Columns.Add(col_ra)
        
        col_dec = DataGridViewTextBoxColumn()
        col_dec.Name = "Dec"
        col_dec.HeaderText = "Dec (deg)"
        col_dec.Width = 100
        col_dec.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight
        try:
            none_mode = getattr(DataGridViewAutoSizeColumnMode, 'None')
            col_dec.AutoSizeMode = none_mode
        except:
            pass
        self.star_grid.Columns.Add(col_dec)
        
        col_vmag = DataGridViewTextBoxColumn()
        col_vmag.Name = "VMag"
        col_vmag.HeaderText = "V"
        col_vmag.Width = 60
        col_vmag.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight
        try:
            none_mode = getattr(DataGridViewAutoSizeColumnMode, 'None')
            col_vmag.AutoSizeMode = none_mode
        except:
            pass
        self.star_grid.Columns.Add(col_vmag)
        
        col_bv = DataGridViewTextBoxColumn()
        col_bv.Name = "BV"
        col_bv.HeaderText = "B-V"
        col_bv.Width = 60
        col_bv.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight
        try:
            none_mode = getattr(DataGridViewAutoSizeColumnMode, 'None')
            col_bv.AutoSizeMode = none_mode
        except:
            pass
        self.star_grid.Columns.Add(col_bv)
        
        col_ub = DataGridViewTextBoxColumn()
        col_ub.Name = "UB"
        col_ub.HeaderText = "U-B"
        col_ub.Width = 60
        col_ub.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight
        try:
            none_mode = getattr(DataGridViewAutoSizeColumnMode, 'None')
            col_ub.AutoSizeMode = none_mode
        except:
            pass
        self.star_grid.Columns.Add(col_ub)
        
        col_airmass = DataGridViewTextBoxColumn()
        col_airmass.Name = "Airmass"
        col_airmass.HeaderText = "Airmass"
        col_airmass.Width = 80
        col_airmass.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight
        try:
            none_mode = getattr(DataGridViewAutoSizeColumnMode, 'None')
            col_airmass.AutoSizeMode = none_mode
        except:
            pass
        self.star_grid.Columns.Add(col_airmass)
        
        col_alt = DataGridViewTextBoxColumn()
        col_alt.Name = "Alt"
        col_alt.HeaderText = "Alt"
        col_alt.Width = 60
        col_alt.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight
        try:
            none_mode = getattr(DataGridViewAutoSizeColumnMode, 'None')
            col_alt.AutoSizeMode = none_mode
        except:
            pass
        self.star_grid.Columns.Add(col_alt)
        
        col_az = DataGridViewTextBoxColumn()
        col_az.Name = "Az"
        col_az.HeaderText = "Az"
        col_az.Width = 60
        col_az.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight
        try:
            none_mode = getattr(DataGridViewAutoSizeColumnMode, 'None')
            col_az.AutoSizeMode = none_mode
        except:
            pass
        self.star_grid.Columns.Add(col_az)
        
        # Add controls in order
        self.Controls.Add(self.star_grid)      # Fill
        self.Controls.Add(button_panel)        # Bottom
        self.Controls.Add(filter_panel)        # Top
        
        self.ResumeLayout(True)
        self.PerformLayout()
        
        # Populate grid with auto-selected filter if any
        self._populate_grid(self.active_filter)
    
    def _populate_grid(self, filter_airmass=None):
        """Populate the grid with extinction stars."""
        self.star_grid.Rows.Clear()
        
        # Create list of (star, airmass) tuples for sorting
        star_data = []
        for star in self.extinction_catalog.stars:
            airmass = self.star_airmass.get(star.name)
            
            # Apply filter if active
            if filter_airmass is not None:
                if airmass is None:
                    continue  # Skip stars without airmass
                if abs(airmass - filter_airmass) > 0.15:
                    continue  # Outside filter range
            
            star_data.append((star, airmass))
        
        # Sort by airmass (low to high), putting None values at end
        star_data.sort(key=lambda x: (x[1] is None, x[1] if x[1] is not None else 999))
        
        # Populate grid
        for star, airmass in star_data:
            ra_str = "%.4f" % star.ra_hours
            dec_str = "%+.4f" % star.dec_deg
            vmag_str = "%.2f" % star.v_mag
            bv_str = "%.2f" % star.b_v
            ub_str = "%.2f" % star.u_b
            airmass_str = "%.2f" % airmass if airmass is not None else ""
            
            # Get altitude and azimuth (0 dp format)
            altitude = self.star_altitude.get(star.name)
            azimuth = self.star_azimuth.get(star.name)
            alt_str = "%d" % int(round(altitude)) if altitude is not None else ""
            az_str = "%d" % int(round(azimuth)) if azimuth is not None else ""
            
            row_idx = self.star_grid.Rows.Add(star.name, ra_str, dec_str, vmag_str, bv_str, ub_str, airmass_str, alt_str, az_str)
            self.star_grid.Rows[row_idx].Tag = star
        
        # Update filter button highlights
        self._update_button_highlights()
    
    def _update_button_highlights(self):
        """Update filter button highlights with night mode awareness."""
        # Check if night mode is active
        is_night = self.parent and hasattr(self.parent, 'night_mode') and self.parent.night_mode.is_night_mode
        
        for btn in self.filter_buttons:
            # Use float comparison with small tolerance for button highlighting
            is_active = (self.active_filter is not None and 
                        abs(float(btn.Tag) - float(self.active_filter)) < 0.01)
            
            if is_active:
                if is_night:
                    # Night mode: dark red background with bright red border
                    btn.BackColor = Color.FromArgb(80, 0, 0)  # Dark red
                    btn.ForeColor = Color.FromArgb(255, 100, 100)  # Light red text
                    btn.FlatStyle = FlatStyle.Flat
                    btn.FlatAppearance.BorderColor = Color.FromArgb(255, 50, 50)  # Bright red border
                    btn.FlatAppearance.BorderSize = 2
                else:
                    # Normal mode: light blue with blue border
                    btn.BackColor = Color.LightBlue
                    btn.ForeColor = Color.Black
                    btn.FlatStyle = FlatStyle.Flat
                    btn.FlatAppearance.BorderColor = Color.Blue
                    btn.FlatAppearance.BorderSize = 2
            else:
                if is_night:
                    # Night mode: keep night colors from apply_to_form
                    btn.BackColor = Color.FromArgb(30, 0, 0)
                    btn.ForeColor = Color.FromArgb(255, 100, 100)
                    btn.FlatStyle = FlatStyle.Standard
                else:
                    # Normal mode: default colors
                    btn.BackColor = SystemColors.Control
                    btn.ForeColor = SystemColors.ControlText
                    btn.FlatStyle = FlatStyle.Standard
            btn.Refresh()  # Force visual update
    
    def _on_filter_button_click(self, sender, event):
        """Handle airmass filter button click."""
        self.active_filter = sender.Tag
        self.used_filter = sender.Tag  # Track which filter was used
        self._populate_grid(self.active_filter)
    
    def _on_reset_filter(self, sender, event):
        """Handle reset filter button click."""
        self.active_filter = None
        self.used_filter = None  # Clear used filter on reset
        self._populate_grid()
    
    def _on_select_click(self, sender, event):
        """Handle Select button click."""
        if self.star_grid.SelectedRows.Count == 0:
            MessageBox.Show("Please select a star first.", "No Selection", 
                          MessageBoxButtons.OK, MessageBoxIcon.Warning)
            return
        
        row = self.star_grid.SelectedRows[0]
        self.selected_star = row.Tag
        
        # Get airmass if available
        airmass_str = str(row.Cells[6].Value)
        if airmass_str:
            try:
                self.selected_airmass = float(airmass_str)
            except:
                self.selected_airmass = None
        
        # Store the filter that was active when selection was made
        self.used_filter = self.active_filter
        
        self.DialogResult = DialogResult.OK
        self.Close()
    
    def _on_cancel_click(self, sender, event):
        """Handle Cancel button click."""
        self.DialogResult = DialogResult.Cancel
        self.Close()
    

    def _on_star_double_click(self, sender, event):
        """Handle double-click on star row."""
        if self.star_grid.SelectedRows.Count > 0:
            self._on_select_click(sender, event)


def show_data_acquisition_window(sharpcap=None, coordinate_parser=None, on_close_callback=None):
    """Show the data acquisition window.
    
    Args:
        sharpcap: SharpCap object if running in SharpCap, None if standalone
        coordinate_parser: CoordinateParser class if running in SharpCap, None if standalone
        on_close_callback: Optional callback function to call when window closes
    """
    window = SSPDataAcquisitionWindow(sharpcap=sharpcap, coordinate_parser=coordinate_parser)
    
    # If a close callback is provided, subscribe to the FormClosed event
    if on_close_callback:
        window.FormClosed += lambda sender, event: on_close_callback()
    
    # Use Show() instead of ShowDialog() to keep SharpCap interface responsive
    window.Show()
