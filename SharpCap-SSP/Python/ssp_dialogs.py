"""
SSP Dialog Windows
==================

Dialog windows for configuration and data entry.

Author: pep-ssp-tools project
Version: 0.1.2
"""

import clr
clr.AddReference('System.Windows.Forms')
clr.AddReference('System.Drawing')
import System
from System.Windows.Forms import *
from System.Drawing import *


class COMPortDialog(Form):
    """Dialog for selecting COM port."""
    
    def __init__(self, current_port):
        """Initialize COM port selection dialog."""
        self.selected_port = current_port
        
        self.Text = "Select SSP COM Port"
        self.Width = 300
        self.Height = 200
        self.StartPosition = FormStartPosition.CenterParent
        self.FormBorderStyle = FormBorderStyle.FixedDialog
        self.MaximizeBox = False
        self.MinimizeBox = False
        
        # Label
        label = Label()
        label.Text = "Select COM port for SSP photometer (1-19):"
        label.Location = Point(20, 20)
        label.Size = Size(250, 30)
        self.Controls.Add(label)
        
        # ComboBox
        self.combo = ComboBox()
        self.combo.Location = Point(20, 50)
        self.combo.Size = Size(240, 25)
        self.combo.DropDownStyle = ComboBoxStyle.DropDownList
        
        # Add COM port options
        for i in range(1, 20):
            self.combo.Items.Add("COM" + str(i))
        
        if current_port > 0:
            self.combo.SelectedIndex = current_port - 1
        
        self.Controls.Add(self.combo)
        
        # Buttons
        ok_btn = Button()
        ok_btn.Text = "OK"
        ok_btn.Location = Point(70, 110)
        ok_btn.Size = Size(70, 30)
        ok_btn.Click += self._on_ok
        self.Controls.Add(ok_btn)
        
        cancel_btn = Button()
        cancel_btn.Text = "Cancel"
        cancel_btn.Location = Point(150, 110)
        cancel_btn.Size = Size(70, 30)
        cancel_btn.Click += self._on_cancel
        self.Controls.Add(cancel_btn)
        
        self.AcceptButton = ok_btn
        self.CancelButton = cancel_btn
    
    def _on_ok(self, sender, event):
        """Handle OK button."""
        if self.combo.SelectedIndex >= 0:
            self.selected_port = self.combo.SelectedIndex + 1
            self.DialogResult = DialogResult.OK
        self.Close()
    
    def _on_cancel(self, sender, event):
        """Handle Cancel button."""
        self.DialogResult = DialogResult.Cancel
        self.Close()


class TimeZoneDialog(Form):
    """Dialog for setting time zone offset."""
    
    def __init__(self, current_offset):
        """Initialize time zone dialog."""
        self.time_zone_offset = current_offset
        
        self.Text = "Set Time Zone"
        self.Width = 350
        self.Height = 220
        self.StartPosition = FormStartPosition.CenterParent
        self.FormBorderStyle = FormBorderStyle.FixedDialog
        self.MaximizeBox = False
        self.MinimizeBox = False
        
        # Label
        label = Label()
        label.Text = "Set time zone difference from UTC:"
        label.Location = Point(20, 20)
        label.Size = Size(300, 20)
        self.Controls.Add(label)
        
        label2 = Label()
        label2.Text = "Negative for west, positive for east (-12 to +12)"
        label2.Location = Point(20, 45)
        label2.Size = Size(300, 20)
        label2.Font = Font(label2.Font, FontStyle.Italic)
        self.Controls.Add(label2)
        
        # NumericUpDown
        self.numeric = NumericUpDown()
        self.numeric.Location = Point(20, 75)
        self.numeric.Size = Size(100, 25)
        self.numeric.Minimum = -12
        self.numeric.Maximum = 12
        self.numeric.Value = current_offset
        self.Controls.Add(self.numeric)
        
        # Example label
        example = Label()
        example.Text = "Examples:\nEST (US East): -5\nCST (US Central): -6\nPST (US West): -8\nUTC: 0"
        example.Location = Point(20, 110)
        example.Size = Size(300, 60)
        example.Font = Font("Courier New", 8)
        self.Controls.Add(example)
        
        # Buttons
        ok_btn = Button()
        ok_btn.Text = "OK"
        ok_btn.Location = Point(170, 140)
        ok_btn.Size = Size(70, 30)
        ok_btn.Click += self._on_ok
        self.Controls.Add(ok_btn)
        
        cancel_btn = Button()
        cancel_btn.Text = "Cancel"
        cancel_btn.Location = Point(250, 140)
        cancel_btn.Size = Size(70, 30)
        cancel_btn.Click += self._on_cancel
        self.Controls.Add(cancel_btn)
        
        self.AcceptButton = ok_btn
        self.CancelButton = cancel_btn
    
    def _on_ok(self, sender, event):
        """Handle OK button."""
        self.time_zone_offset = int(self.numeric.Value)
        self.DialogResult = DialogResult.OK
        self.Close()
    
    def _on_cancel(self, sender, event):
        """Handle Cancel button."""
        self.DialogResult = DialogResult.Cancel
        self.Close()


class ObserverInfoDialog(Form):
    """Dialog for entering observer and telescope information."""
    
    def __init__(self, telescope_name, observer_name):
        """Initialize observer info dialog."""
        self.telescope_name = telescope_name
        self.observer_name = observer_name
        
        self.Text = "Observer Information"
        self.Width = 400
        self.Height = 200
        self.StartPosition = FormStartPosition.CenterParent
        self.FormBorderStyle = FormBorderStyle.FixedDialog
        self.MaximizeBox = False
        self.MinimizeBox = False
        
        # Telescope label and textbox
        tel_label = Label()
        tel_label.Text = "Telescope:"
        tel_label.Location = Point(20, 25)
        tel_label.Size = Size(100, 20)
        self.Controls.Add(tel_label)
        
        self.tel_text = TextBox()
        self.tel_text.Location = Point(130, 23)
        self.tel_text.Size = Size(240, 25)
        self.tel_text.Text = telescope_name
        self.Controls.Add(self.tel_text)
        
        # Observer label and textbox
        obs_label = Label()
        obs_label.Text = "Observer:"
        obs_label.Location = Point(20, 60)
        obs_label.Size = Size(100, 20)
        self.Controls.Add(obs_label)
        
        self.obs_text = TextBox()
        self.obs_text.Location = Point(130, 58)
        self.obs_text.Size = Size(240, 25)
        self.obs_text.Text = observer_name
        self.Controls.Add(self.obs_text)
        
        # Buttons
        ok_btn = Button()
        ok_btn.Text = "OK"
        ok_btn.Location = Point(210, 110)
        ok_btn.Size = Size(70, 30)
        ok_btn.Click += self._on_ok
        self.Controls.Add(ok_btn)
        
        cancel_btn = Button()
        cancel_btn.Text = "Cancel"
        cancel_btn.Location = Point(290, 110)
        cancel_btn.Size = Size(70, 30)
        cancel_btn.Click += self._on_cancel
        self.Controls.Add(cancel_btn)
        
        self.AcceptButton = ok_btn
        self.CancelButton = cancel_btn
    
    def _on_ok(self, sender, event):
        """Handle OK button."""
        self.telescope_name = self.tel_text.Text
        self.observer_name = self.obs_text.Text
        self.DialogResult = DialogResult.OK
        self.Close()
    
    def _on_cancel(self, sender, event):
        """Handle Cancel button."""
        self.DialogResult = DialogResult.Cancel
        self.Close()


class FilterBarSetupDialog(Form):
    """Dialog for configuring filter bars (replicates SSPDataq Filter Bar Setup)."""
    
    def __init__(self, filter_bars, active_bar):
        """Initialize filter bar setup dialog.
        
        Args:
            filter_bars: List of 3 lists, each containing 6 filter names
            active_bar: Currently active bar (1, 2, or 3)
        """
        self.filter_bars = [list(bar) for bar in filter_bars]  # Deep copy
        self.active_bar = active_bar
        self.modified = False
        
        self.Text = "Edit Filter Bar"
        self.Width = 450
        self.Height = 340
        self.StartPosition = FormStartPosition.CenterParent
        self.FormBorderStyle = FormBorderStyle.FixedDialog
        self.MaximizeBox = False
        self.MinimizeBox = False
        
        # Instruction label
        inst_label = Label()
        inst_label.Text = "Use uppercase for Johnson/Cousins UBVRI\nand lowercase for Sloan ugriz"
        inst_label.Location = Point(10, 10)
        inst_label.Size = Size(370, 50)
        self.Controls.Add(inst_label)
        
        # Filter Bar selection label
        bar_label = Label()
        bar_label.Text = "Filter Bar"
        bar_label.Location = Point(10, 70)
        bar_label.Size = Size(90, 20)
        self.Controls.Add(bar_label)
        
        # Radio buttons for filter bar selection
        self.radio_bar1 = RadioButton()
        self.radio_bar1.Text = "1"
        self.radio_bar1.Location = Point(110, 70)
        self.radio_bar1.Size = Size(50, 22)
        self.radio_bar1.CheckedChanged += self._on_bar_changed
        self.Controls.Add(self.radio_bar1)
        
        self.radio_bar2 = RadioButton()
        self.radio_bar2.Text = "2"
        self.radio_bar2.Location = Point(110, 105)
        self.radio_bar2.Size = Size(50, 22)
        self.radio_bar2.CheckedChanged += self._on_bar_changed
        self.Controls.Add(self.radio_bar2)
        
        self.radio_bar3 = RadioButton()
        self.radio_bar3.Text = "3"
        self.radio_bar3.Location = Point(110, 140)
        self.radio_bar3.Size = Size(50, 22)
        self.radio_bar3.CheckedChanged += self._on_bar_changed
        self.Controls.Add(self.radio_bar3)
        
        # ListBox for filter positions (create BEFORE setting radio button checked state)
        self.filter_list = ListBox()
        self.filter_list.Location = Point(200, 70)
        self.filter_list.Size = Size(210, 130)
        self.filter_list.Font = Font("Courier New", 9)
        self.filter_list.DoubleClick += self._on_edit_filter
        self.Controls.Add(self.filter_list)
        
        # Set active radio button (this triggers _on_bar_changed which calls _load_filter_list)
        if active_bar == 1:
            self.radio_bar1.Checked = True
        elif active_bar == 2:
            self.radio_bar2.Checked = True
        else:
            self.radio_bar3.Checked = True
        
        # Buttons
        complete_btn = Button()
        complete_btn.Text = "Complete"
        complete_btn.Location = Point(200, 230)
        complete_btn.Size = Size(100, 30)
        complete_btn.Click += self._on_complete
        self.Controls.Add(complete_btn)
        
        cancel_btn = Button()
        cancel_btn.Text = "Cancel"
        cancel_btn.Location = Point(310, 230)
        cancel_btn.Size = Size(100, 30)
        cancel_btn.Click += self._on_cancel
        self.Controls.Add(cancel_btn)
        
        self.AcceptButton = complete_btn
        self.CancelButton = cancel_btn
    
    def _load_filter_list(self):
        """Load filter names for current bar into listbox."""
        self.filter_list.Items.Clear()
        bar_index = self.active_bar - 1
        
        # Ensure the bar exists
        if bar_index >= len(self.filter_bars):
            return
        
        bar = self.filter_bars[bar_index]
        for i in range(6):
            # Get filter name, use default if index out of bounds
            if i < len(bar):
                filter_name = bar[i]
            else:
                filter_name = 'f' + str(bar_index * 6 + i + 1)
            # Format as "Position N: Name"
            self.filter_list.Items.Add("Position " + str(i+1) + ": " + filter_name)
    
    def _on_bar_changed(self, sender, event):
        """Handle filter bar radio button change."""
        if not sender.Checked:
            return
        
        if self.radio_bar1.Checked:
            self.active_bar = 1
        elif self.radio_bar2.Checked:
            self.active_bar = 2
        elif self.radio_bar3.Checked:
            self.active_bar = 3
        
        self._load_filter_list()
    
    def _on_edit_filter(self, sender, event):
        """Handle double-click to edit filter name."""
        if self.filter_list.SelectedIndex < 0:
            return
        
        position = self.filter_list.SelectedIndex
        bar_index = self.active_bar - 1
        current_name = self.filter_bars[bar_index][position]
        
        # Prompt for new filter name
        from Microsoft.VisualBasic import Interaction
        new_name = Interaction.InputBox(
            "Filter Edit\nEnter new filter name:",
            "Edit Filter Position " + str(position + 1),
            current_name,
            -1, -1
        )
        
        # Trim whitespace and check if not empty and different
        if new_name:
            new_name = new_name.strip()
            if new_name and new_name != current_name:
                self.filter_bars[bar_index][position] = new_name
                self.modified = True
                self._load_filter_list()
                # Re-select the edited item
                self.filter_list.SelectedIndex = position
    
    def _on_complete(self, sender, event):
        """Handle Complete button."""
        self.DialogResult = DialogResult.OK
        self.Close()
    
    def _on_cancel(self, sender, event):
        """Handle Cancel button."""
        self.DialogResult = DialogResult.Cancel
        self.Close()


class LocationDialog(Form):
    """Dialog for setting observer location with online lookup capabilities."""
    
    def __init__(self, current_lat, current_lon, current_elev):
        """Initialize location dialog.
        
        Args:
            current_lat: Current latitude in decimal degrees (-90 to +90)
            current_lon: Current longitude in decimal degrees (-180 to +180)
            current_elev: Current elevation in meters
        """
        self.latitude = current_lat
        self.longitude = current_lon
        self.elevation = current_elev
        
        self.Text = "Observer Location"
        self.Width = 520
        self.Height = 620
        self.StartPosition = FormStartPosition.CenterParent
        self.FormBorderStyle = FormBorderStyle.FixedDialog
        self.MaximizeBox = False
        self.MinimizeBox = False
        
        y_pos = 20
        
        # Title label
        title_label = Label()
        title_label.Text = "Enter Observer Location"
        title_label.Location = Point(20, y_pos)
        title_label.Size = Size(470, 25)
        title_label.Font = Font(title_label.Font.FontFamily, 11, FontStyle.Bold)
        self.Controls.Add(title_label)
        
        y_pos += 35
        
        # Step 1: Google Maps link
        maps_link = LinkLabel()
        maps_link.Text = "Step 1: Open in Google Maps"
        maps_link.Location = Point(20, y_pos)
        maps_link.Size = Size(250, 20)
        maps_link.Font = Font(maps_link.Font.FontFamily, 9, FontStyle.Bold)
        maps_link.LinkClicked += self._on_open_maps
        self.Controls.Add(maps_link)
        
        y_pos += 25
        
        # Instructions
        instructions = Label()
        instructions.Text = ("   a. Drop a pin at your observing location\n" +
                           "   b. Right-click the pin and select the coordinates (top of list)\n" +
                           "   c. Return here and click 'Paste Coordinates' below")
        instructions.Location = Point(20, y_pos)
        instructions.Size = Size(470, 60)
        instructions.Font = Font(instructions.Font, FontStyle.Italic)
        instructions.ForeColor = Color.DarkBlue
        self.Controls.Add(instructions)
        
        y_pos += 65
        
        # Step 2: Paste button
        paste_coords_btn = Button()
        paste_coords_btn.Text = "Step 2: Paste Coordinates"
        paste_coords_btn.Location = Point(20, y_pos)
        paste_coords_btn.Size = Size(180, 32)
        paste_coords_btn.Font = Font(paste_coords_btn.Font.FontFamily, 9, FontStyle.Bold)
        paste_coords_btn.Click += self._on_paste_coordinates
        self.Controls.Add(paste_coords_btn)
        
        y_pos += 45
        
        # Latitude section
        lat_label = Label()
        lat_label.Text = "Latitude (decimal degrees):"
        lat_label.Location = Point(20, y_pos)
        lat_label.Size = Size(200, 20)
        self.Controls.Add(lat_label)
        
        y_pos += 25
        
        self.lat_numeric = NumericUpDown()
        self.lat_numeric.Location = Point(20, y_pos)
        self.lat_numeric.Size = Size(140, 25)
        self.lat_numeric.Minimum = -90
        self.lat_numeric.Maximum = 90
        self.lat_numeric.DecimalPlaces = 6
        try:
            self.lat_numeric.Value = System.Decimal(current_lat)
        except:
            self.lat_numeric.Value = 0
        self.Controls.Add(self.lat_numeric)
        
        lat_help = Label()
        lat_help.Text = "North: positive (+), South: negative (-)"
        lat_help.Location = Point(170, y_pos + 3)
        lat_help.Size = Size(320, 20)
        lat_help.Font = Font(lat_help.Font, FontStyle.Italic)
        self.Controls.Add(lat_help)
        
        y_pos += 40
        
        # Longitude section
        lon_label = Label()
        lon_label.Text = "Longitude (decimal degrees):"
        lon_label.Location = Point(20, y_pos)
        lon_label.Size = Size(200, 20)
        self.Controls.Add(lon_label)
        
        y_pos += 25
        
        self.lon_numeric = NumericUpDown()
        self.lon_numeric.Location = Point(20, y_pos)
        self.lon_numeric.Size = Size(140, 25)
        self.lon_numeric.Minimum = -180
        self.lon_numeric.Maximum = 180
        self.lon_numeric.DecimalPlaces = 6
        try:
            self.lon_numeric.Value = System.Decimal(current_lon)
        except:
            self.lon_numeric.Value = 0
        self.Controls.Add(self.lon_numeric)
        
        lon_help = Label()
        lon_help.Text = "East: positive (+), West: negative (-)"
        lon_help.Location = Point(170, y_pos + 3)
        lon_help.Size = Size(320, 20)
        lon_help.Font = Font(lon_help.Font, FontStyle.Italic)
        self.Controls.Add(lon_help)
        
        y_pos += 40
        
        # Elevation section
        elev_label = Label()
        elev_label.Text = "Elevation (meters above sea level):"
        elev_label.Location = Point(20, y_pos)
        elev_label.Size = Size(250, 20)
        self.Controls.Add(elev_label)
        
        y_pos += 25
        
        self.elev_numeric = NumericUpDown()
        self.elev_numeric.Location = Point(20, y_pos)
        self.elev_numeric.Size = Size(140, 25)
        self.elev_numeric.Minimum = -500
        self.elev_numeric.Maximum = 9000
        self.elev_numeric.DecimalPlaces = 0
        try:
            self.elev_numeric.Value = System.Decimal(current_elev)
        except:
            self.elev_numeric.Value = 0
        self.Controls.Add(self.elev_numeric)
        
        # Lookup Elevation button
        lookup_elev_btn = Button()
        lookup_elev_btn.Text = "Lookup Elevation"
        lookup_elev_btn.Location = Point(170, y_pos)
        lookup_elev_btn.Size = Size(130, 28)
        lookup_elev_btn.Click += self._on_lookup_elevation
        self.Controls.Add(lookup_elev_btn)
        
        elev_help = Label()
        elev_help.Text = "(Optional, for atmospheric corrections)"
        elev_help.Location = Point(310, y_pos + 3)
        elev_help.Size = Size(190, 20)
        elev_help.Font = Font(elev_help.Font, FontStyle.Italic)
        self.Controls.Add(elev_help)
        
        y_pos += 40
        
        # City/Town name section
        city_label = Label()
        city_label.Text = "City/Town (optional):"
        city_label.Location = Point(20, y_pos)
        city_label.Size = Size(200, 20)
        self.Controls.Add(city_label)
        
        y_pos += 25
        
        self.city_text = TextBox()
        self.city_text.Location = Point(20, y_pos)
        self.city_text.Size = Size(250, 25)
        self.Controls.Add(self.city_text)
        
        # Lookup City button
        lookup_city_btn = Button()
        lookup_city_btn.Text = "Lookup City"
        lookup_city_btn.Location = Point(280, y_pos)
        lookup_city_btn.Size = Size(110, 28)
        lookup_city_btn.Click += self._on_lookup_city
        self.Controls.Add(lookup_city_btn)
        
        city_help = Label()
        city_help.Text = "(Looks up city name from coordinates)"
        city_help.Location = Point(400, y_pos + 3)
        city_help.Size = Size(90, 40)
        city_help.Font = Font(city_help.Font, FontStyle.Italic)
        self.Controls.Add(city_help)
        
        y_pos += 45
        
        # Examples section
        examples_label = Label()
        examples_label.Text = "Examples:"
        examples_label.Location = Point(20, y_pos)
        examples_label.Size = Size(400, 20)
        examples_label.Font = Font(examples_label.Font, FontStyle.Bold)
        self.Controls.Add(examples_label)
        
        y_pos += 25
        
        examples = Label()
        examples.Text = ("Greenwich, UK:      51.4769 N,   -0.0005 E,     0 m\n" +
                        "Auckland, NZ:      -36.8485 S,  174.7633 E,    42 m\n" +
                        "Mauna Kea, HI:      19.8207 N, -155.4681 W, 4207 m\n" +
                        "Sydney, AU:        -33.8688 S,  151.2093 E,    58 m")
        examples.Location = Point(20, y_pos)
        examples.Size = Size(400, 70)
        examples.Font = Font("Courier New", 8.5)
        self.Controls.Add(examples)
        
        y_pos += 85
        
        # Buttons
        ok_btn = Button()
        ok_btn.Text = "OK"
        ok_btn.Location = Point(220, y_pos)
        ok_btn.Size = Size(90, 32)
        ok_btn.Click += self._on_ok
        self.Controls.Add(ok_btn)
        
        cancel_btn = Button()
        cancel_btn.Text = "Cancel"
        cancel_btn.Location = Point(320, y_pos)
        cancel_btn.Size = Size(90, 32)
        cancel_btn.Click += self._on_cancel
        self.Controls.Add(cancel_btn)
        
        self.AcceptButton = ok_btn
        self.CancelButton = cancel_btn
    
    def _on_lookup_city(self, sender, event):
        """Look up city/town name from coordinates using reverse geocoding."""
        original_text = sender.Text
        try:
            # Get current lat/lon values
            latitude = float(self.lat_numeric.Value)
            longitude = float(self.lon_numeric.Value)
            
            # Check if coordinates are non-zero
            if latitude == 0.0 and longitude == 0.0:
                MessageBox.Show("Please enter latitude and longitude values first.", 
                              "No Coordinates", MessageBoxButtons.OK, MessageBoxIcon.Warning)
                return
            
            # Show working message
            sender.Text = "Looking up..."
            sender.Enabled = False
            self.Refresh()
            
            # Import location lookup function
            import ssp_location_utils
            
            # Lookup location name
            location_name = ssp_location_utils.get_location_name_from_coordinates(latitude, longitude)
            
            # Restore button
            sender.Text = original_text
            sender.Enabled = True
            
            if location_name:
                self.city_text.Text = location_name
            else:
                MessageBox.Show("Could not retrieve location name from the service.\n\n" +
                              "Please check your internet connection or enter location manually.\n\n" +
                              "Note: Nominatim (OpenStreetMap) API requires 1 second between requests.", 
                              "Location Lookup Failed", MessageBoxButtons.OK, MessageBoxIcon.Warning)
        
        except Exception as ex:
            MessageBox.Show("Error during location lookup: {0}".format(ex), 
                          "Error", MessageBoxButtons.OK, MessageBoxIcon.Error)
        finally:
            # Always restore button state
            sender.Text = original_text
            sender.Enabled = True
    
    def _on_lookup_elevation(self, sender, event):
        """Look up elevation from coordinates using online API."""
        original_text = sender.Text
        try:
            # Get current lat/lon values
            latitude = float(self.lat_numeric.Value)
            longitude = float(self.lon_numeric.Value)
            
            # Check if coordinates are non-zero
            if latitude == 0.0 and longitude == 0.0:
                MessageBox.Show("Please enter latitude and longitude values first.", 
                              "No Coordinates", MessageBoxButtons.OK, MessageBoxIcon.Warning)
                return
            
            # Show working message
            sender.Text = "Looking up..."
            sender.Enabled = False
            self.Refresh()
            
            # Import elevation lookup function
            import ssp_location_utils
            
            # Lookup elevation
            elevation = ssp_location_utils.get_elevation_from_coordinates(latitude, longitude)
            
            # Restore button
            sender.Text = original_text
            sender.Enabled = True
            
            if elevation is not None:
                # Clamp elevation to valid range before setting
                elevation_value = max(-500, min(9000, round(elevation, 1)))
                try:
                    self.elev_numeric.Value = System.Decimal(elevation_value)
                except:
                    # If decimal conversion fails, set to 0
                    self.elev_numeric.Value = 0
            else:
                MessageBox.Show("Could not retrieve elevation data from the service.\n\n" +
                              "Please check your internet connection or enter elevation manually.\n\n" +
                              "Note: The Open-Elevation API may be temporarily unavailable.", 
                              "Elevation Lookup Failed", MessageBoxButtons.OK, MessageBoxIcon.Warning)
        
        except Exception as ex:
            MessageBox.Show("Error during elevation lookup: {0}".format(ex), 
                          "Error", MessageBoxButtons.OK, MessageBoxIcon.Error)
        finally:
            # Always restore button state
            sender.Text = original_text
            sender.Enabled = True
    
    def _on_paste_coordinates(self, sender, event):
        """Paste coordinates from clipboard and parse them."""
        try:
            # Get text from clipboard
            if not Clipboard.ContainsText():
                MessageBox.Show("No text found in clipboard.\n\n" +
                              "Copy coordinates in format: latitude, longitude\n" +
                              "Example: -36.8485, 174.7633", 
                              "No Text", MessageBoxButtons.OK, MessageBoxIcon.Warning)
                return
            
            clipboard_text = Clipboard.GetText().strip()
            
            # Try to parse coordinates - support multiple formats
            # Format 1: "lat, lon" (comma-separated)
            # Format 2: "lat lon" (space-separated)
            # Format 3: "lat\tlon" (tab-separated)
            
            coords = None
            
            # Try comma-separated first (most common)
            if ',' in clipboard_text:
                parts = clipboard_text.split(',')
                if len(parts) >= 2:
                    coords = (parts[0].strip(), parts[1].strip())
            
            # Try space or tab separated
            elif ' ' in clipboard_text or '\t' in clipboard_text:
                parts = clipboard_text.replace('\t', ' ').split()
                if len(parts) >= 2:
                    coords = (parts[0], parts[1])
            
            if coords:
                try:
                    lat = float(coords[0])
                    lon = float(coords[1])
                    
                    # Validate ranges
                    if lat < -90 or lat > 90:
                        MessageBox.Show("Latitude must be between -90 and +90 degrees.\nFound: {0}".format(lat), 
                                      "Invalid Latitude", MessageBoxButtons.OK, MessageBoxIcon.Warning)
                        return
                    
                    if lon < -180 or lon > 180:
                        MessageBox.Show("Longitude must be between -180 and +180 degrees.\nFound: {0}".format(lon), 
                                      "Invalid Longitude", MessageBoxButtons.OK, MessageBoxIcon.Warning)
                        return
                    
                    # Set the values
                    self.lat_numeric.Value = System.Decimal(lat)
                    self.lon_numeric.Value = System.Decimal(lon)
                    
                    MessageBox.Show("Coordinates pasted successfully:\nLatitude: {0:.6f}\nLongitude: {1:.6f}".format(lat, lon), 
                                  "Pasted", MessageBoxButtons.OK, MessageBoxIcon.Information)
                
                except ValueError:
                    MessageBox.Show("Could not parse coordinates as numbers.\n\n" +
                                  "Clipboard text: {0}\n\n".format(clipboard_text) +
                                  "Expected format: latitude, longitude\n" +
                                  "Example: -36.8485, 174.7633", 
                                  "Parse Error", MessageBoxButtons.OK, MessageBoxIcon.Warning)
            else:
                MessageBox.Show("Could not find coordinate values in clipboard.\n\n" +
                              "Clipboard text: {0}\n\n".format(clipboard_text) +
                              "Expected format: latitude, longitude\n" +
                              "Example: -36.8485, 174.7633", 
                              "Parse Error", MessageBoxButtons.OK, MessageBoxIcon.Warning)
        
        except Exception as ex:
            MessageBox.Show("Error pasting coordinates: {0}".format(ex), 
                          "Error", MessageBoxButtons.OK, MessageBoxIcon.Error)
    
    def _on_open_maps(self, sender, event):
        """Open Google Maps with current coordinates, or default location if coords are 0,0."""
        try:
            import webbrowser
            latitude = float(self.lat_numeric.Value)
            longitude = float(self.lon_numeric.Value)
            
            # If coordinates are 0,0 (not entered), open Google Maps at default location
            if latitude == 0.0 and longitude == 0.0:
                maps_url = "https://www.google.com/maps"
            else:
                maps_url = "https://www.google.com/maps?q={0},{1}".format(latitude, longitude)
            
            webbrowser.open(maps_url)
        except Exception as ex:
            MessageBox.Show("Error opening Google Maps: {0}".format(ex), 
                          "Error", MessageBoxButtons.OK, MessageBoxIcon.Error)
    
    def _on_ok(self, sender, event):
        """Handle OK button."""
        self.latitude = float(self.lat_numeric.Value)
        self.longitude = float(self.lon_numeric.Value)
        self.elevation = float(self.elev_numeric.Value)
        self.DialogResult = DialogResult.OK
        self.Close()
    
    def _on_cancel(self, sender, event):
        """Handle Cancel button."""
        self.DialogResult = DialogResult.Cancel
        self.Close()
