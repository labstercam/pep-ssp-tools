"""
SSP Data Acquisition Window
============================

Main data acquisition window for SharpCap-SSP.
Replicates SSPDataq3 functionality.

Author: pep-ssp-tools project
Version: 0.1.0
"""

import clr
import sys

# Ensure module path is accessible
import System
script_dir = System.IO.Path.GetDirectoryName(__file__) if '__file__' in dir() else System.IO.Directory.GetCurrentDirectory()
if script_dir not in sys.path:
    sys.path.append(script_dir)

clr.AddReference('System')
clr.AddReference('System.Windows.Forms')
clr.AddReference('System.Drawing')
clr.AddReference('Microsoft.VisualBasic')

from System import *
from System.Windows.Forms import *
from System.Drawing import *
from System.IO import Path

# Import SSP modules
import ssp_config
import ssp_comm
import ssp_dialogs
import night_mode


class SSPDataAcquisitionWindow(Form):
    """Main data acquisition window."""
    
    def __init__(self):
        """Initialize the data acquisition window."""
        # Load configuration
        self.config = ssp_config.SSPConfig()
        
        # Initialize communicator
        self.comm = ssp_comm.SSPCommunicator()
        
        # Initialize night mode
        self.night_mode = night_mode.NightMode()
        self.night_mode.set_night_mode(self.config.get('night_flag', 0) == 1)
        
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
        self.Height = 345
        self.MinimumSize = Size(1100, 345)  # Prevent shrinking below original size
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
        
        night_item = ToolStripMenuItem("Night/Day Screen")
        night_item.Click += self._on_toggle_night_mode
        setup_menu.DropDownItems.Add(night_item)
        
        setup_menu.DropDownItems.Add(ToolStripSeparator())
        
        show_setup_item = ToolStripMenuItem("Show Setup Values")
        show_setup_item.Click += self._on_show_setup
        setup_menu.DropDownItems.Add(show_setup_item)
        
        menu_strip.Items.Add(setup_menu)
        
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
        self.filter_combo.Location = Point(x, y + 20)
        self.filter_combo.Size = Size(80, 25)
        self.filter_combo.DropDownStyle = ComboBoxStyle.DropDownList
        filters = self.config.get('filters', ['U', 'B', 'V', 'R', 'I', 'Dark'])
        for f in filters:
            self.filter_combo.Items.Add(f)
        self.filter_combo.Items.Add("Home")
        # Always default to V filter (index 2)
        v_index = filters.index('V') if 'V' in filters else 0
        self.filter_combo.SelectedIndex = v_index
        self.Controls.Add(self.filter_combo)
        
        x += 90
        
        # Gain
        gain_label = Label()
        gain_label.Text = "Gain:"
        gain_label.Location = Point(x, y)
        gain_label.Size = Size(70, 20)
        self.Controls.Add(gain_label)
        self.gain_combo = ComboBox()
        self.gain_combo.Location = Point(x, y + 20)
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
        self.integ_combo.Location = Point(x, y + 20)
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
        self.interval_combo.Location = Point(x, y + 20)
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
        self.mode_combo.Location = Point(x, y + 20)
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
        self.object_combo.Location = Point(x, y + 20)
        self.object_combo.Size = Size(150, 25)
        self.object_combo.DropDownStyle = ComboBoxStyle.DropDownList
        self.object_combo.Items.Add("New Object")
        self.object_combo.Items.Add("SKY")
        self.object_combo.Items.Add("SKYNEXT")
        self.object_combo.Items.Add("SKYLAST")
        self.object_combo.Items.Add("CATALOG")
        self.object_combo.SelectedIndex = 0
        self.Controls.Add(self.object_combo)
        
        x += 160
        
        catalog_label = Label()
        catalog_label.Text = "Catalog:"
        catalog_label.Location = Point(x, y)
        catalog_label.Size = Size(100, 20)
        self.Controls.Add(catalog_label)
        
        self.catalog_combo = ComboBox()
        self.catalog_combo.Location = Point(x, y + 20)
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
        
        # START button
        x = 300
        self.start_button = Button()
        self.start_button.Text = "START"
        self.start_button.Location = Point(x, y + 20)
        self.start_button.Size = Size(100, 30)
        self.start_button.Click += self._on_start
        self.Controls.Add(self.start_button)
        
        # Status/Message area
        y = y_offset + 140
        x = 10
        
        status_label = Label()
        status_label.Text = "Status:"
        status_label.Location = Point(x, y)
        status_label.Size = Size(820, 20)
        self.Controls.Add(status_label)
        self.status_text = TextBox()
        self.status_text.Location = Point(x, y + 20)
        self.status_text.Size = Size(820, 20)
        self.status_text.Multiline = False
        self.status_text.ReadOnly = True
        self.Controls.Add(self.status_text)
        
        # Data display grid
        y = y_offset + 175
        data_label = Label()
        data_label.Text = "Data:"
        data_label.Location = Point(x, y)
        data_label.Size = Size(1060, 20)
        self.Controls.Add(data_label)
        
        # Fixed column header (doesn't scroll)
        self.header_label = Label()
        self.header_label.Text = "DATE       TIME     C    OBJECT          F  COUNT  COUNT  COUNT  COUNT  IT GN NOTES"
        self.header_label.Location = Point(x, y + 20)
        self.header_label.Size = Size(1060, 15)
        self.header_label.Font = Font("Courier New", 8)
        self.header_label.BackColor = Color.LightGray
        self.Controls.Add(self.header_label)
        
        self.data_listbox = ListBox()
        self.data_listbox.Location = Point(x, y + 35)
        self.data_listbox.Size = Size(1060, 65)
        self.data_listbox.Font = Font("Courier New", 8)
        self.data_listbox.HorizontalScrollbar = True
        self.data_listbox.DoubleClick += self._on_data_doubleclick
        self.Controls.Add(self.data_listbox)
        
        # Store initial positions for resize calculations
        self.data_listbox_initial_width = 820
        self.data_listbox_initial_height = 65
        self.header_label_initial_width = 820
    
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
        
        if dialog.ShowDialog() == DialogResult.OK:
            self.config.set('com_port', dialog.selected_port)
            self.config.save()
            self._update_status("COM port set to: COM" + str(dialog.selected_port))
    
    def _on_toggle_night_mode(self, sender, event):
        """Handle Night/Day Screen menu item."""
        current = self.config.get('night_flag', 0)
        if current == 0:
            result = MessageBox.Show("Set screen for night red?", "Night Mode", 
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


def show_data_acquisition_window():
    """Show the data acquisition window."""
    window = SSPDataAcquisitionWindow()
    window.ShowDialog()
