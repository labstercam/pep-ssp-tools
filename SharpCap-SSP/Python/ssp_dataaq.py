"""
SSP Data Acquisition Window
============================

Main data acquisition window for SharpCap-SSP.
Replicates SSPDataq3 functionality.

Author: pep-ssp-tools project
Version: 0.1.2
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

# Import SSP modules
import ssp_config
import ssp_comm
import ssp_dialogs
import night_mode
import ssp_catalog


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
        self.comm = ssp_comm.SSPCommunicator()
        self.config = ssp_config.SSPConfig()
        
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
        
        print("DEBUG: sharpcap_available = %s" % self.sharpcap_available)
        if self.sharpcap_available:
            print("DEBUG: Running in SharpCap mode - GOTO button will be created")
        else:
            print("DEBUG: Running in standalone mode - GOTO button will NOT be created")
        
        # Dictionary to map object combo display names to (actual_name, catalog_type)
        # catalog_type: 'V' for variable, 'C' for comparison, 'K' for check
        self.star_name_map = {}
        
        # Flag to prevent recursion during filter combo updates
        self.updating_filter_combo = False
        
        # Store currently selected target triple for GOTO functionality
        self.current_target = None
        
        # Data arrays
        self.data_array = []
        self.saved_data = []
        self.data_saved_count = 0  # Track how many entries have been saved to file
        self.data_notes = {}  # Dictionary to store notes: {data_line: note}
        self.data_notes = {}  # Dictionary to store notes: {data_line: note}
        self.data_notes = {}  # Dictionary to store notes: {data_line: note}
        
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
        script_item.Enabled = False  # Disabled for now
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
        self.current_target_label.Size = Size(800, 25)
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
            print("DEBUG: Creating GOTO button at position (%d, %d)" % (start_x, start_y))
            self.goto_button = Button()
            self.goto_button.Text = "GOTO Selected Star"
            self.goto_button.Location = Point(start_x, start_y)
            self.goto_button.Size = Size(150, 30)  # Match START button height
            self.goto_button.Enabled = False  # Disabled until target selected
            self.goto_button.Click += self._on_goto_target
            self.goto_button.BringToFront()  # Ensure it's on top
            self.Controls.Add(self.goto_button)
            print("DEBUG: GOTO button created and added to form")
            print("DEBUG: Button visible=%s, enabled=%s" % (self.goto_button.Visible, self.goto_button.Enabled))
        else:
            print("DEBUG: Skipping GOTO button creation (not in SharpCap)")
    
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
    
    def _on_data_doubleclick(self, sender, event):
        """Handle double-click on data listbox to edit notes."""
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
                    else:
                        self.saved_data[i] = data_line
                    break
    
    # Menu event handlers
    
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
    
    def _on_clear_data(self, sender, event):
        """Handle Clear Data menu item."""
        if len(self.data_array) == 0:
            return
        
        result = MessageBox.Show("Do you wish to clear the data array?", "Clear Data", 
                                MessageBoxButtons.YesNo, MessageBoxIcon.Question)
        if result == DialogResult.Yes:
            self.data_array = []
            self.saved_data = []
            self.data_saved_count = 0  # Reset saved count
            self.data_notes = {}  # Clear notes dictionary
            self.data_listbox.Items.Clear()
            self._update_status("Data array cleared")
    
    def _on_open_script(self, sender, event):
        """Handle Open Script File menu item."""
        MessageBox.Show("Script functionality not yet implemented", "Open Script", 
                       MessageBoxButtons.OK, MessageBoxIcon.Information)
    
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
        """Handle form closing event - disconnect COM port."""
        if self.comm.is_connected:
            success, message = self.comm.disconnect()
            self._update_status(message)
    
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
    
    def _on_start(self, sender, event):
        """Handle START button click.
        
        Implements data collection following SSPDataq [Get_Counts] logic:
        1. Record UT date/time at start
        2. Set gain on photometer  
        3. Get count readings for specified interval
        4. Format and display data
        5. Store in data arrays
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
        
        # Set gain on photometer
        success, msg = self.comm.set_gain(gain_val)
        if not success:
            self._update_status("Error setting gain: " + msg)
            return
        
        # Disable button during collection
        self.start_button.Enabled = False
        self.start_button.Text = "WAIT"
        
        # Show initial status message (matches original)
        self._update_status("Getting count data for " + filter_val + " filter - please wait")
        
        # Record start time (UT)
        ut_start = DateTime.UtcNow
        
        # Collect counts for specified interval
        counts = []
        for i in range(interval_val):
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
        
        # Re-enable button
        self.start_button.Text = "START"
        self.start_button.Enabled = True
        
        # Calculate mid-point timestamp (matches original SSPDataq [UTtimeCorrected])
        # Original: MidCount = int((IntervalRecord * (Integ/1000))/2)
        # Then adds MidCount seconds to recorded UT time
        total_integration_sec = len(counts) * integ_val
        mid_count_sec = int(total_integration_sec / 2.0)
        ut_midpoint = ut_start.AddSeconds(mid_count_sec)
        ut_date_str = ut_midpoint.ToString("MM-dd-yyyy")
        ut_time_str = ut_midpoint.ToString("HH:mm:ss")
        
        # Format data for display and storage (final summary line)
        # Format: "MM-DD-YYYY HH:MM:SS C OBJECTNAME F XXXXX XXXXX XXXXX XXXXX II GG NOTES"
        data_line = self._format_data_line(
            ut_date_str, ut_time_str, catalog_code, object_val,
            filter_val, counts, integ_text, str(gain_val)
        )
        
        # Add to data arrays
        self.saved_data.append(data_line)
        self.data_array.insert(0, data_line)  # Insert at beginning for reverse display
        
        # Add to listbox (display in reverse chronological order)
        self.data_listbox.Items.Insert(0, data_line)
        
        self._update_status("Data collection complete - " + str(len(counts)) + " readings")
    
    def _do_trial_mode(self, filter_val, gain_val, integ_ms):
        """Execute trial mode (single test reading).
        
        Args:
            filter_val: Filter name
            gain_val: Gain value
            integ_ms: Integration time in milliseconds
        """
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
    
    def _on_select_star(self, sender, event):
        """Handle select star menu click."""
        if not self.catalog or self.catalog.get_count() == 0:
            MessageBox.Show("No star catalog loaded.\n\nPlace 'starparm_latest.csv' in the Python folder and use Catalog > Reload Catalog.",
                          "No Catalog", MessageBoxButtons.OK, MessageBoxIcon.Warning)
            return
        
        # Create star selection dialog
        dialog = StarSelectionDialog(self.catalog, self.config)
        self.night_mode.apply_to_form(dialog)
        result = dialog.ShowDialog(self)
        
        if result == DialogResult.OK and dialog.selected_target:
            target = dialog.selected_target
            
            # Store the selected target for GOTO functionality
            self.current_target = target
            
            # Enable GOTO button if in SharpCap mode
            if self.sharpcap_available and hasattr(self, 'goto_button'):
                print("DEBUG: Enabling GOTO button for target: %s" % target.variable.name)
                self.goto_button.Enabled = True
                print("DEBUG: GOTO button enabled=%s, visible=%s" % (self.goto_button.Enabled, self.goto_button.Visible))
            elif self.sharpcap_available:
                print("DEBUG: WARNING - sharpcap_available=True but goto_button attribute not found!")
            else:
                print("DEBUG: Not enabling GOTO button (not in SharpCap mode)")
            
            # Update the current target label
            self.current_target_label.Text = "Current Target: Var=%s | Comp=%s | Check=%s" % (
                target.variable.name,
                target.comparison.name,
                target.check.name)
            self.current_target_label.ForeColor = Color.DarkGreen
            self.current_target_label.Font = Font("Arial", 9, FontStyle.Bold)
            
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
            
            # Auto-set catalog to Var
            self._set_catalog_for_object(var_display)
            
            self._update_status("Added target stars: %s, %s, %s - Variable selected" % (
                var_display, comp_display, check_display))
    
    def _on_object_changed(self, sender, event):
        """Handle object selection change - auto-set catalog type."""
        selected = self.object_combo.Text
        self._set_catalog_for_object(selected)
    
    def _set_catalog_for_object(self, object_name):
        """Set catalog combobox based on selected object.
        
        Args:
            object_name: The display name of the selected object
        """
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
        result = dialog.ShowDialog(self)
        
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
            
            # Update the current target label
            airmass_str = "Airmass=%.2f" % dialog.selected_airmass if dialog.selected_airmass else "Airmass=N/A"
            self.current_target_label.Text = "Current Target (Extinction): %s (V=%.2f, %s)" % (
                star.name, star.v_mag, airmass_str)
            self.current_target_label.ForeColor = Color.DarkBlue
            self.current_target_label.Font = Font("Arial", 9, FontStyle.Bold)
            
            # Since extinction stars don't have comp/check, clear the object combo
            self.updating_filter_combo = True
            self.object_combo.Items.Clear()
            self.object_combo.Items.Add(star.name)
            self.object_combo.SelectedIndex = 0
            self.updating_filter_combo = False
            
            # Set catalog combo to "Foe" for first order extinction
            for i in range(self.catalog_combo.Items.Count):
                if str(self.catalog_combo.Items[i]) == "Foe":
                    self.catalog_combo.SelectedIndex = i
                    break
    
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
        
        if selected_obj in self.star_name_map:
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
        
        # Get RA and Dec in decimal hours and degrees
        ra_hours = star.ra_hours + star.ra_minutes/60.0 + star.ra_seconds/3600.0
        dec_degrees = star.dec_degrees_decimal
        
        # Confirm before slewing
        msg = "%s Star: %s\n\nRA:  %s\nDec: %s\n\nSlew telescope to this position?" % (
            star_type, star.name,
            star.ra_string(), star.dec_string())
        
        result = MessageBox.Show(msg, "Confirm GOTO",
                                MessageBoxButtons.YesNo, MessageBoxIcon.Question)
        
        if result != DialogResult.Yes:
            return
        
        # Try to slew telescope using SharpCap API
        try:
            # Verify CancellationToken is available (should always be true in SharpCap)
            if CancellationToken is None:
                MessageBox.Show("GOTO functionality requires SharpCap environment.",
                              "Not Available", MessageBoxButtons.OK, MessageBoxIcon.Warning)
                return
            
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
                
                # Use SafeGetAsyncResult to properly wait for slew completion
                self.SharpCap.SafeGetAsyncResult(mount.StartSlewToAsync(coordinates, CancellationToken()))
                
                # Wait for mount to settle
                time.sleep(2)
                if not mount.IsSettled:
                    print("Waiting for mount to settle...")
                    wait_start = time.time()
                    while not mount.IsSettled and (time.time() - wait_start) < 30:
                        time.sleep(1)
                
                print("GOTO completed: RA %.4fh, Dec %.4f°" % (ra_hours, dec_degrees))
                self._update_status("GOTO completed to %s: %s" % (star_type, star.name))
                
                MessageBox.Show("Telescope has slewed to %s: %s\n\nRA:  %s\nDec: %s" % (
                    star_type, star.name, star.ra_string(), star.dec_string()),
                    "GOTO Complete", MessageBoxButtons.OK, MessageBoxIcon.Information)
                
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
                
                MessageBox.Show(manual_msg, "Manual GOTO Required",
                              MessageBoxButtons.OK, MessageBoxIcon.Information)
                
                self._update_status("Manual GOTO: %s - coordinates copied to clipboard" % star.name)
            
        except Exception as e:
            import traceback
            error_msg = "Error slewing telescope:\n\n%s\n\nDetails:\n%s" % (str(e), traceback.format_exc())
            print("GOTO execution error: %s" % str(e))
            MessageBox.Show(error_msg, "GOTO Error", MessageBoxButtons.OK, MessageBoxIcon.Error)
            self._update_status("GOTO failed: " + str(e))


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
