"""
SSP Dialog Windows
==================

Dialog windows for configuration and data entry.

Author: pep-ssp-tools project
Version: 0.2.0
"""

import clr
clr.AddReference('System.Windows.Forms')
clr.AddReference('System.Drawing')
import System
from System.Windows.Forms import *
from System.Drawing import *

try:
    import ssp_sequence
except Exception:
    ssp_sequence = None


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
        self.AutoScaleMode = AutoScaleMode.Dpi
        self.AutoScaleDimensions = System.Drawing.SizeF(96, 96)
        
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
        self.AutoScaleMode = AutoScaleMode.Dpi
        self.AutoScaleDimensions = System.Drawing.SizeF(96, 96)
        
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
        self.AutoScaleMode = AutoScaleMode.Dpi
        self.AutoScaleDimensions = System.Drawing.SizeF(96, 96)
        
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
        self.AutoScaleMode = AutoScaleMode.Dpi
        self.AutoScaleDimensions = System.Drawing.SizeF(96, 96)
        
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
        self.radio_bar2.Location = Point(110, 110)
        self.radio_bar2.Size = Size(50, 22)
        self.radio_bar2.CheckedChanged += self._on_bar_changed
        self.Controls.Add(self.radio_bar2)
        
        self.radio_bar3 = RadioButton()
        self.radio_bar3.Text = "3"
        self.radio_bar3.Location = Point(110, 150)
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
    
    def __init__(self, current_lat, current_lon, current_elev, current_city=''):
        """Initialize location dialog.
        
        Args:
            current_lat: Current latitude in decimal degrees (-90 to +90)
            current_lon: Current longitude in decimal degrees (-180 to +180)
            current_elev: Current elevation in meters
            current_city: Current city/town name (optional)
        """
        self.latitude = current_lat
        self.longitude = current_lon
        self.elevation = current_elev
        self.city = current_city
        
        self.Text = "Observer Location"
        self.Width = 650
        self.Height = 730
        self.StartPosition = FormStartPosition.CenterParent
        self.FormBorderStyle = FormBorderStyle.FixedDialog
        self.MaximizeBox = False
        self.MinimizeBox = False
        self.AutoScaleMode = AutoScaleMode.Dpi
        self.AutoScaleDimensions = System.Drawing.SizeF(96, 96)
        
        y_pos = 20
        
        # Title label
        title_label = Label()
        title_label.Text = "Enter Observer Location"
        title_label.Location = Point(20, y_pos)
        title_label.Size = Size(600, 25)
        title_label.Font = Font(title_label.Font.FontFamily, 11, FontStyle.Bold)
        self.Controls.Add(title_label)
        
        y_pos += 40  # Extra spacing
        
        # Step 1: Google Maps link
        maps_link = LinkLabel()
        maps_link.Text = "Step 1: Open in Google Maps"
        maps_link.Location = Point(20, y_pos)
        maps_link.Size = Size(300, 20)
        maps_link.Font = Font(maps_link.Font.FontFamily, 9, FontStyle.Bold)
        maps_link.LinkClicked += self._on_open_maps
        self.Controls.Add(maps_link)
        
        y_pos += 35  # Extra spacing
        
        # Instructions
        instructions = Label()
        instructions.Text = ("   a. Drop a pin at your observing location\n" +
                           "   b. Right-click the pin and select the coordinates (top of list)\n" +
                           "   c. Return here and click 'Paste Coordinates' below")
        instructions.Location = Point(20, y_pos)
        instructions.Size = Size(610, 75)
        instructions.Font = Font(instructions.Font, FontStyle.Italic)
        instructions.ForeColor = Color.DarkBlue
        self.Controls.Add(instructions)
        
        y_pos += 75  # Extra spacing
        
        # Step 2: Paste button
        paste_coords_btn = Button()
        paste_coords_btn.Text = "Step 2: Paste Coordinates"
        paste_coords_btn.Location = Point(20, y_pos)
        paste_coords_btn.Size = Size(220, 32)
        paste_coords_btn.Font = Font(paste_coords_btn.Font.FontFamily, 9, FontStyle.Bold)
        paste_coords_btn.Click += self._on_paste_coordinates
        self.Controls.Add(paste_coords_btn)
        
        y_pos += 55  # Extra spacing
        
        # Latitude section
        lat_label = Label()
        lat_label.Text = "Latitude (decimal degrees):"
        lat_label.Location = Point(20, y_pos)
        lat_label.Size = Size(220, 25)
        self.Controls.Add(lat_label)
        
        y_pos += 28
        
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
        lat_help.Size = Size(470, 25)
        lat_help.Font = Font(lat_help.Font, FontStyle.Italic)
        self.Controls.Add(lat_help)
        
        y_pos += 50  # Extra spacing
        
        # Longitude section
        lon_label = Label()
        lon_label.Text = "Longitude (decimal degrees):"
        lon_label.Location = Point(20, y_pos)
        lon_label.Size = Size(230, 25)
        self.Controls.Add(lon_label)
        
        y_pos += 28
        
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
        lon_help.Size = Size(470, 25)
        lon_help.Font = Font(lon_help.Font, FontStyle.Italic)
        self.Controls.Add(lon_help)
        
        y_pos += 50  # Extra spacing
        
        # Elevation section
        elev_label = Label()
        elev_label.Text = "Elevation (meters above sea level):"
        elev_label.Location = Point(20, y_pos)
        elev_label.Size = Size(280, 25)
        self.Controls.Add(elev_label)
        
        y_pos += 28
        
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
        lookup_elev_btn.Size = Size(140, 32)
        lookup_elev_btn.Click += self._on_lookup_elevation
        self.Controls.Add(lookup_elev_btn)
        
        elev_help = Label()
        elev_help.Text = "(Optional, for atmospheric corrections)"
        elev_help.Location = Point(320, y_pos + 3)
        elev_help.Size = Size(320, 25)
        elev_help.Font = Font(elev_help.Font, FontStyle.Italic)
        self.Controls.Add(elev_help)
        
        y_pos += 50  # Extra spacing
        
        # City/Town name section
        city_label = Label()
        city_label.Text = "City/Town (optional):"
        city_label.Location = Point(20, y_pos)
        city_label.Size = Size(200, 25)
        self.Controls.Add(city_label)
        
        y_pos += 28
        
        self.city_text = TextBox()
        self.city_text.Location = Point(20, y_pos)
        self.city_text.Size = Size(250, 25)
        self.city_text.Text = current_city
        self.Controls.Add(self.city_text)
        
        # Lookup City button
        lookup_city_btn = Button()
        lookup_city_btn.Text = "Lookup City"
        lookup_city_btn.Location = Point(280, y_pos)
        lookup_city_btn.Size = Size(120, 32)
        lookup_city_btn.Click += self._on_lookup_city
        self.Controls.Add(lookup_city_btn)
        
        city_help = Label()
        city_help.Text = "Looks up city from coords"
        city_help.Location = Point(410, y_pos + 3)
        city_help.Size = Size(230, 25)
        city_help.Font = Font(city_help.Font, FontStyle.Italic)
        self.Controls.Add(city_help)
        
        y_pos += 55  # Extra spacing
        
        # Examples section
        examples_label = Label()
        examples_label.Text = "Examples:"
        examples_label.Location = Point(20, y_pos)
        examples_label.Size = Size(600, 25)
        examples_label.Font = Font(examples_label.Font, FontStyle.Bold)
        self.Controls.Add(examples_label)
        
        y_pos += 28
        
        examples = Label()
        examples.Text = ("Greenwich, UK:      51.4769 N,   -0.0005 E,     0 m\n" +
                        "Auckland, NZ:      -36.8485 S,  174.7633 E,    42 m\n" +
                        "Mauna Kea, HI:      19.8207 N, -155.4681 W, 4207 m\n" +
                        "Sydney, AU:        -33.8688 S,  151.2093 E,    58 m")
        examples.Location = Point(20, y_pos)
        examples.Size = Size(550, 80)
        examples.Font = Font("Courier New", 8.5)
        self.Controls.Add(examples)
        
        y_pos += 95  # Extra spacing
        
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
        self.city = self.city_text.Text.strip()
        self.DialogResult = DialogResult.OK
        self.Close()
    
    def _on_cancel(self, sender, event):
        """Handle Cancel button."""
        self.DialogResult = DialogResult.Cancel
        self.Close()
class SequenceDialog(Form):
    """Editor for PEP sequences (Phase 3 of the sequencer work).

    Build, load, save and order a sequence. After ShowDialog(), check
    ``run_requested``; if True the caller should run ``dialog.sequence``.
    """

    KINDS = ["GOTO", "TARGET", "MEASURE", "SKY", "FILTER", "WAIT",
             "WAIT_UNTIL", "ABORT_IF", "REPEAT", "END"]

    # Help shown in the editor for the currently selected Kind.
    # Each entry is (command, syntax, what_it_does); the first two are the
    # .ssp command name and a one-line syntax summary, the third is the
    # "what it does" explanation (see QUICK_START.md command reference).
    COMMAND_HELP = {
        "GOTO": (
            "GOTO",
            "GOTO, V | GOTO, C | GOTO, K | GOTO, RA,Dec | GOTO, OFFSET,dRA,dDec",
            "Slew to the target's Variable / Comparison / Check star, to absolute "
            "coordinates (RA in decimal hours, Dec in decimal degrees), or to an "
            "offset from the variable star. Value = V / C / K, RA,Dec or "
            "offset=dRA,dDec. Params may add plate_solve=0 to skip the "
            "plate-solve+sync for this step (plate_solve=1 forces it on). An "
            "RA/Dec offset (offset=dRA,dDec - the same syntax SKY uses) may "
            "also be given in the Params box; it is applied on top of Value, "
            "e.g. Value=V with offset=0,0.25 slews to the variable star plus "
            "the offset."),
        "TARGET": (
            "TARGET",
            "TARGET, OMI CET | TARGET, auid=000-BBW-425",
            "Load a new catalog object (by name or AUID) and its Var / Comp / "
            "Check stars for all following steps; GOTO V/C/K, the MEASURE/SKY "
            "defaults and ABORT_IF then use the new target. Params may add "
            "id=auid (or id=name) to force which catalog field is matched."),
        "MEASURE": (
            "MEASURE",
            "MEASURE, filter=V, integ=5, interval=3, gain=10",
            "Take one PEP measurement. Every field is optional; omitted fields "
            "inherit the current main-window setting. Params: filter=, gain= "
            "(1/10/100), integ= (seconds), interval= (counts, 1-8)."),
        "SKY": (
            "SKY",
            "SKY, label=SKYLAST, filter=V [, offset=dRA,dDec, plate_solve=0]",
            "Take a sky reading; label is SKY, SKYNEXT or SKYLAST. An optional "
            "offset slews to an RA/Dec offset from the target first. Params: "
            "filter=, gain=, integ=, interval=, offset=, plate_solve=0/1."),
        "FILTER": (
            "FILTER",
            "FILTER, B",
            "Change the filter (auto mode moves the slider; manual mode just "
            "records it). Value = the filter name on the active bar."),
        "WAIT": (
            "WAIT",
            "WAIT, 30",
            "Pause for the given number of seconds; the UI keeps responding "
            "during the wait."),
        "WAIT_UNTIL": (
            "WAIT_UNTIL",
            "WAIT_UNTIL, 2026-11-27 02:45:00",
            "Wait until that absolute UTC date/time. If it is <= 30 min in the "
            "past it proceeds with a warning; if > 30 min in the past it stops "
            "the run with a warning."),
        "ABORT_IF": (
            "ABORT_IF",
            "ABORT_IF, airmass_above=2.5 | ABORT_IF, alt_below=15",
            "Stop the run if the target is above that airmass or below that "
            "altitude. Skipped when the observer location is not set (0,0)."),
        "REPEAT": (
            "REPEAT",
            "REPEAT, 6 ... END",
            "Repeat the block of steps up to the matching END the given number "
            "of times. Value = the repeat count."),
        "END": (
            "END",
            "END",
            "Close the current REPEAT block."),
    }

    def __init__(self, sequence=None, sequences_dir=None, night_mode=None,
                 catalog=None):
        if ssp_sequence is None:
            raise Exception("ssp_sequence module not available")
        self.sequence = sequence if sequence is not None else ssp_sequence.PEPSequence("New")
        self.sequences_dir = sequences_dir
        self.night_mode = night_mode
        self.catalog = catalog
        self.run_requested = False
        self._loading_fields = False
        # Last kind the user selected; used to clear the Value/Label/Params
        # boxes when the Kind changes (see _on_kind_changed).
        self._last_kind = None

        self.Text = "Edit Sequence"
        self.Width = 720
        self.Height = 470
        self.MinimumSize = Size(720, 470)
        self.StartPosition = FormStartPosition.CenterParent
        self.FormBorderStyle = FormBorderStyle.Sizable
        self.MaximizeBox = True
        self.MinimizeBox = False

        self._build_ui()
        self.kind_combo.SelectedIndex = self.KINDS.index("MEASURE")  # default kind
        self._refresh_sequence_list()
        self._refresh_steps()
        self._write_runlength()
        self._on_kind_changed(None, None)
        # Validate TARGET objects once the window is on screen (so any warning
        # is parented to a visible dialog).
        self.Shown += self._on_shown

        if self.night_mode is not None:
            try:
                self.night_mode.apply_to_form(self)
            except Exception:
                pass

    def _on_shown(self, sender, event):
        self._check_targets()

    def _build_ui(self):
        # Row 1 - saved-sequence picker + file buttons
        seq_label = Label()
        seq_label.Text = "Sequence:"
        seq_label.Location = Point(10, 13)
        seq_label.Size = Size(70, 20)
        self.Controls.Add(seq_label)

        self.seq_combo = ComboBox()
        self.seq_combo.Location = Point(80, 10)
        self.seq_combo.Size = Size(200, 23)
        self.seq_combo.DropDownStyle = ComboBoxStyle.DropDown
        self.seq_combo.Text = self.sequence.name
        self.Controls.Add(self.seq_combo)

        for text, handler, x, w in (("New", self._on_new, 290, 55),
                                    ("Load", self._on_load, 350, 55),
                                    ("Save As", self._on_save, 410, 75),
                                    ("Delete", self._on_delete, 490, 60)):
            btn = Button()
            btn.Text = text
            btn.Location = Point(x, 9)
            btn.Size = Size(w, 25)
            btn.Click += handler
            self.Controls.Add(btn)

        # Row 2 - step list + reorder buttons
        steps_label = Label()
        steps_label.Text = "Steps:"
        steps_label.Location = Point(10, 46)
        steps_label.Size = Size(280, 20)
        self.Controls.Add(steps_label)

        self.steps_list = ListBox()
        self.steps_list.Location = Point(10, 66)
        self.steps_list.Size = Size(280, 220)
        self.steps_list.Font = Font("Courier New", 8)
        self.steps_list.SelectedIndexChanged += self._on_step_selected
        self.Controls.Add(self.steps_list)

        for text, handler, x, w in (("Add", self._on_add, 10, 52),
                                    ("Update", self._on_update, 66, 56),
                                    ("Remove", self._on_remove, 126, 62),
                                    ("Up", self._on_up, 192, 44),
                                    ("Down", self._on_down, 240, 50)):
            btn = Button()
            btn.Text = text
            btn.Location = Point(x, 292)
            btn.Size = Size(w, 26)
            btn.Click += handler
            self.Controls.Add(btn)

        group = GroupBox()
        group.Text = "Step"
        group.Location = Point(300, 46)
        group.Size = Size(396, 272)
        self.Controls.Add(group)

        def add_field(row, caption, box, width, label_width=70):
            lbl = Label()
            lbl.Text = caption
            lbl.Location = Point(12, row * 30 + 26)
            lbl.Size = Size(label_width, 20)
            group.Controls.Add(lbl)
            box.Location = Point(label_width + 12, row * 30 + 24)
            box.Size = Size(width, 23)
            group.Controls.Add(box)
            return box

        self.kind_combo = ComboBox()
        self.kind_combo.DropDownStyle = ComboBoxStyle.DropDownList
        for kind in self.KINDS:
            self.kind_combo.Items.Add(kind)
        self.kind_combo.SelectedIndexChanged += self._on_kind_changed
        add_field(0, "Kind:", self.kind_combo, 150)

        self.value_box = TextBox()
        add_field(1, "Value:", self.value_box, 310)

        self.label_box = TextBox()
        add_field(2, "Label:", self.label_box, 310)

        self.params_box = TextBox()
        add_field(3, "Params:", self.params_box, 310)

        # Command help box - shows the syntax and "what it does" text for the
        # currently selected Kind. Line 1 = Command, line 2 = Syntax, lines 3+
        # = what it does. Refreshed by _update_help() whenever the Kind changes.
        self.help_box = TextBox()
        self.help_box.Location = Point(12, 146)
        self.help_box.Size = Size(372, 116)
        self.help_box.Multiline = True
        self.help_box.ReadOnly = True
        self.help_box.WordWrap = True
        self.help_box.ScrollBars = ScrollBars.Vertical
        self.help_box.TabStop = False
        self.help_box.Font = Font("Courier New", 8)
        group.Controls.Add(self.help_box)

        # Row 3 - run length (units are as labelled; minutes = wall-clock)
        run_label = Label()
        run_label.Text = "Run length:"
        run_label.Location = Point(10, 332)
        run_label.Size = Size(80, 20)
        self.Controls.Add(run_label)

        def add_run_box(caption, x, label_width, box_width=55):
            lbl = Label()
            lbl.Text = caption
            lbl.Location = Point(x, 332)
            lbl.Size = Size(label_width, 20)
            self.Controls.Add(lbl)
            box = TextBox()
            box.Location = Point(x + label_width, 330)
            box.Size = Size(box_width, 23)
            self.Controls.Add(box)
            return box

        self.minutes_box = add_run_box("Max minutes:", 95, 90)
        self.obs_box = add_run_box("Max observations:", 250, 115)
        self.repeat_box = add_run_box("Repeat (0=no limit):", 425, 130)

        run_btn = Button()
        run_btn.Text = "Run"
        run_btn.Location = Point(10, 366)
        run_btn.Size = Size(90, 30)
        run_btn.Click += self._on_run
        self.Controls.Add(run_btn)

        close_btn = Button()
        close_btn.Text = "Close"
        close_btn.Location = Point(110, 366)
        close_btn.Size = Size(90, 30)
        close_btn.Click += self._on_close
        self.Controls.Add(close_btn)

        self.status_label = Label()
        self.status_label.Text = ""
        self.status_label.Location = Point(210, 372)
        self.status_label.Size = Size(486, 20)
        self.status_label.ForeColor = Color.Gray
        self.Controls.Add(self.status_label)

    def _set_status(self, text):
        try:
            self.status_label.Text = text
        except Exception:
            pass

    def _refresh_sequence_list(self):
        if ssp_sequence is None:
            return
        # ComboBox.Items.Clear() resets the edit text, which would blank the
        # Sequence box (and so the name Save As uses). Preserve and restore it.
        current = self.seq_combo.Text
        names = []
        if self.sequences_dir:
            try:
                names = ssp_sequence.list_names(self.sequences_dir)
            except Exception:
                names = []
        try:
            templates = list(ssp_sequence.build_templates().keys())
        except Exception:
            templates = []
        self.seq_combo.Items.Clear()
        for name in names:
            self.seq_combo.Items.Add(name)
        for name in templates:
            if name not in names:
                self.seq_combo.Items.Add(name)
        if current:
            self.seq_combo.Text = current

    def _refresh_steps(self):
        self._loading_fields = True
        try:
            self.steps_list.Items.Clear()
            for i, step in enumerate(self.sequence.steps):
                self.steps_list.Items.Add(ssp_sequence.format_step(step, i + 1))
        finally:
            self._loading_fields = False
        self._set_status("%d steps" % len(self.sequence.steps))

    def _current_name(self):
        return (self.seq_combo.Text or '').strip()

    def _load_name(self, name):
        """Load a saved sequence, else a template, else None."""
        seq = None
        if self.sequences_dir:
            try:
                seq = ssp_sequence.load_named(self.sequences_dir, name)
            except Exception:
                seq = None
        if seq is None:
            try:
                seq = ssp_sequence.build_templates().get(name)
            except Exception:
                seq = None
        return seq

    def _on_new(self, sender, event):
        self.sequence = ssp_sequence.PEPSequence("New")
        self.seq_combo.Text = "New"
        self._refresh_steps()
        self._write_runlength()
        self._set_status("New sequence")

    def _on_load(self, sender, event):
        name = self._current_name()
        if not name:
            self._set_status("Enter a sequence name to load")
            return
        seq = self._load_name(name)
        if seq is None:
            MessageBox.Show("Could not load sequence '%s'" % name, "Load Sequence",
                            MessageBoxButtons.OK, MessageBoxIcon.Warning)
            return
        self.sequence = seq
        self.seq_combo.Text = seq.name
        self._refresh_steps()
        self._write_runlength()
        self._set_status("Loaded '%s'" % seq.name)
        self._check_targets()

    def _on_save(self, sender, event):
        """Save the sequence under the name in the Sequence box (Save As)."""
        name = self._current_name() or (self.sequence.name or '').strip()
        if not name:
            self._set_status("Enter a sequence name to save")
            MessageBox.Show(
                "Type a name in the 'Sequence:' box, then click Save As.",
                "Save Sequence", MessageBoxButtons.OK,
                MessageBoxIcon.Information)
            try:
                self.seq_combo.Focus()
            except Exception:
                pass
            return
        self.sequence.name = name
        self._read_runlength()
        try:
            ssp_sequence.save_named(self.sequence, self.sequences_dir, name)
        except Exception as e:
            MessageBox.Show("Could not save sequence:\n" + str(e), "Save Sequence",
                            MessageBoxButtons.OK, MessageBoxIcon.Error)
            return
        # Reflect the new name in the picker (guarded so a UI hiccup cannot
        # swallow the success message).
        try:
            self._refresh_sequence_list()
            self.seq_combo.Text = name
        except Exception:
            pass
        self._set_status("Saved '%s'" % name)

    def _on_delete(self, sender, event):
        name = self._current_name()
        if not name:
            self._set_status("Nothing to delete")
            return
        answer = MessageBox.Show("Delete sequence '%s'?" % name, "Delete Sequence",
                                 MessageBoxButtons.YesNo, MessageBoxIcon.Question)
        if answer != DialogResult.Yes:
            return
        try:
            ssp_sequence.delete_named(self.sequences_dir, name)
        except Exception:
            pass
        self._refresh_sequence_list()
        self._set_status("Deleted '%s'" % name)

    def _kind(self):
        return str(self.kind_combo.Text or 'GOTO').upper()

    def _on_kind_changed(self, sender, event):
        """Reset and enable/disable the fields for the selected kind.

        When the Kind actually changes, the Value/Label/Params boxes are cleared
        so stale values from the previous command do not carry over (and are not
        left sitting in a now-disabled box). Programmatic changes while loading
        a step (_loading_fields / _populate_fields) do not clear them.
        """
        if self._loading_fields:
            return
        kind = self._kind()
        if kind != self._last_kind:
            self.value_box.Text = ''
            self.label_box.Text = ''
            self.params_box.Text = ''
            self._last_kind = kind
        self.value_box.Enabled = kind in ('GOTO', 'TARGET', 'FILTER', 'WAIT',
                                          'WAIT_UNTIL', 'REPEAT')
        self.label_box.Enabled = (kind == 'SKY')
        self.params_box.Enabled = kind in ('GOTO', 'TARGET', 'MEASURE', 'SKY',
                                           'ABORT_IF')
        self._update_help()

    def _check_targets(self):
        """Warn (non-blocking) if any TARGET step references an unknown object.

        Called when the editor opens and whenever a sequence is loaded, per the
        "check the catalog on edit/load" requirement.
        """
        if ssp_sequence is None:
            return
        try:
            missing = ssp_sequence.missing_catalog_targets(self.sequence,
                                                           self.catalog)
        except Exception:
            return
        if missing is None:
            # No catalog loaded: every TARGET step is unverifiable, so report
            # them all (the caller still wants a warning in that case).
            try:
                missing = [(idx, ident) for idx, ident, _t
                           in ssp_sequence.find_target_steps(self.sequence)]
            except Exception:
                missing = []
        if not missing:
            return
        listing = "\n".join("%d. %s" % (idx, ident) for idx, ident in missing)
        MessageBox.Show(
            "These TARGET objects are not in the loaded star catalog:\n\n"
            + listing +
            "\n\nThey will be skipped at run time unless the catalog is updated.",
            "Unknown Targets", MessageBoxButtons.OK, MessageBoxIcon.Warning)
        self._set_status("Warning: %d TARGET object(s) not in catalog"
                         % len(missing))

    def _check_one_target(self, step):
        """Warn (non-blocking) if a single TARGET step's object is unknown.

        Called when a step is added or updated in the editor, so the catalog is
        checked as soon as the TARGET command is entered. A valid object is
        silent; an unknown (or unverifiable) one shows a warning.
        """
        if ssp_sequence is None or step is None or step.kind != 'TARGET':
            return
        ident = str(step.params.get('object') or '').strip()
        if not ident:
            return
        try:
            catalog_loaded = bool(self.catalog) and self.catalog.get_count() > 0
        except Exception:
            catalog_loaded = False
        if catalog_loaded:
            target = ssp_sequence.resolve_catalog_target(
                self.catalog, ident, step.params.get('id_type'))
            if target is not None:
                return
            message = ("TARGET object '%s' is not in the loaded star catalog.\n\n"
                       "It will be skipped at run time unless the catalog is "
                       "updated." % ident)
        else:
            message = ("TARGET object '%s' cannot be verified - no star catalog "
                       "is loaded.\n\nIt will be skipped at run time unless the "
                       "catalog is loaded." % ident)
        MessageBox.Show(message, "Unknown Target",
                        MessageBoxButtons.OK, MessageBoxIcon.Warning)
        self._set_status("Warning: TARGET '%s' not in catalog" % ident)

    def _update_help(self):
        """Refresh the help box for the currently selected Kind.

        Line 1 = Command, line 2 = Syntax, lines 3+ = "what it does".
        """
        if not hasattr(self, 'help_box'):
            return
        kind = self._kind()
        command, syntax, what = self.COMMAND_HELP.get(
            kind, (kind, kind, "No help available for this command."))
        self.help_box.Text = "\r\n".join(
            ("Command: %s" % command,
             "Syntax: %s" % syntax,
             "What it does: %s" % what))

    def _build_step_from_fields(self):
        return ssp_sequence.step_from_fields(
            self._kind(), self.value_box.Text, self.label_box.Text,
            self.params_box.Text)

    def _populate_fields(self, step):
        self._loading_fields = True
        try:
            kind, value, label, params = ssp_sequence.fields_from_step(step)
            try:
                self.kind_combo.SelectedIndex = self.KINDS.index(kind)
            except ValueError:
                self.kind_combo.SelectedIndex = self.KINDS.index("MEASURE")
            # Record the kind so the trailing _on_kind_changed() call does not
            # treat this programmatic change as a user Kind change and clear the
            # fields we just populated.
            self._last_kind = self._kind()
            self.value_box.Text = str(value)
            self.label_box.Text = str(label)
            self.params_box.Text = str(params)
        finally:
            self._loading_fields = False
        self._on_kind_changed(None, None)

    def _on_step_selected(self, sender, event):
        if self._loading_fields:
            return
        idx = self.steps_list.SelectedIndex
        if 0 <= idx < len(self.sequence.steps):
            self._populate_fields(self.sequence.steps[idx])

    def _on_add(self, sender, event):
        step = self._build_step_from_fields()
        self.sequence.steps.append(step)
        self._refresh_steps()
        self.steps_list.SelectedIndex = len(self.sequence.steps) - 1
        self._set_status("Added %s" % step.kind)
        self._check_one_target(step)

    def _on_update(self, sender, event):
        idx = self.steps_list.SelectedIndex
        if not (0 <= idx < len(self.sequence.steps)):
            self._set_status("Select a step to update")
            return
        step = self._build_step_from_fields()
        self.sequence.steps[idx] = step
        self._refresh_steps()
        self.steps_list.SelectedIndex = idx
        self._set_status("Updated step %d" % (idx + 1))
        self._check_one_target(step)

    def _on_remove(self, sender, event):
        idx = self.steps_list.SelectedIndex
        if not (0 <= idx < len(self.sequence.steps)):
            self._set_status("Select a step to remove")
            return
        del self.sequence.steps[idx]
        self._refresh_steps()
        self._set_status("Removed step %d" % (idx + 1))

    def _move(self, delta):
        idx = self.steps_list.SelectedIndex
        new = idx + delta
        if 0 <= idx < len(self.sequence.steps) and 0 <= new < len(self.sequence.steps):
            steps = self.sequence.steps
            steps[idx], steps[new] = steps[new], steps[idx]
            self._refresh_steps()
            self.steps_list.SelectedIndex = new

    def _on_up(self, sender, event):
        self._move(-1)

    def _on_down(self, sender, event):
        self._move(1)

    def _write_runlength(self):
        self.minutes_box.Text = ("" if not self.sequence.max_minutes
                                 else "%g" % self.sequence.max_minutes)
        self.obs_box.Text = ("" if not self.sequence.max_observations
                             else "%d" % int(self.sequence.max_observations))
        self.repeat_box.Text = ("" if not self.sequence.repeat
                                else "%d" % int(self.sequence.repeat))

    def _read_runlength(self):
        minutes = ssp_sequence._to_float(self.minutes_box.Text, None)
        self.sequence.max_minutes = minutes if minutes else None
        obs = ssp_sequence._to_int(self.obs_box.Text, None)
        self.sequence.max_observations = obs if obs else None
        repeat = ssp_sequence._to_int(self.repeat_box.Text, None)
        self.sequence.repeat = repeat if repeat else None

    def _on_run(self, sender, event):
        self._read_runlength()
        if not self.sequence.steps:
            self._set_status("Add at least one step first")
            return
        if (not self.sequence.max_minutes and not self.sequence.max_observations
                and not self.sequence.repeat):
            answer = MessageBox.Show(
                "No run-length limit set (minutes / observations / repeat).\n"
                "Run a single pass?", "Run Sequence",
                MessageBoxButtons.YesNo, MessageBoxIcon.Question)
            if answer != DialogResult.Yes:
                return
        self.run_requested = True
        self.DialogResult = DialogResult.OK
        self.Close()

    def _on_close(self, sender, event):
        self.DialogResult = DialogResult.Cancel
        self.Close()


class CountdownWarningDialog(Form):
    """Modal warning that auto-proceeds after a countdown, unless cancelled.

    Used by the sequence pre-flight: when one or more TARGET objects are missing
    from the catalog the run is announced and the user has ``seconds`` to cancel.
    ``ShowDialog`` returns ``DialogResult.OK`` when the countdown reaches zero
    (the caller proceeds with the run) or ``DialogResult.Cancel`` if the user
    clicks Cancel (the caller aborts and nothing runs).
    """

    def __init__(self, message, title="Sequence Warning", seconds=10,
                 details=None, night_mode=None):
        self._remaining = max(0, int(seconds))
        self._total = self._remaining

        self.Text = title
        self.Width = 580
        self.Height = 320
        self.MinimumSize = Size(520, 280)
        self.StartPosition = FormStartPosition.CenterParent
        self.FormBorderStyle = FormBorderStyle.Sizable
        self.MaximizeBox = False
        self.MinimizeBox = False
        self.DialogResult = DialogResult.Cancel   # safe default (X = abort)

        header = Label()
        header.Text = message
        header.Location = Point(12, 12)
        header.Size = Size(544, 44)
        self.Controls.Add(header)

        detail = TextBox()
        detail.Location = Point(12, 60)
        detail.Size = Size(544, 150)
        detail.Multiline = True
        detail.ReadOnly = True
        detail.WordWrap = True
        detail.ScrollBars = ScrollBars.Vertical
        detail.TabStop = False
        detail.Text = details or ""
        self.Controls.Add(detail)

        self.countdown_label = Label()
        self.countdown_label.Location = Point(12, 222)
        self.countdown_label.Size = Size(360, 24)
        self.countdown_label.Font = Font(self.Font, FontStyle.Bold)
        self.Controls.Add(self.countdown_label)

        cancel_btn = Button()
        cancel_btn.Text = "Cancel Run"
        cancel_btn.Location = Point(452, 218)
        cancel_btn.Size = Size(104, 30)
        cancel_btn.Click += self._on_cancel
        self.Controls.Add(cancel_btn)
        self.AcceptButton = cancel_btn
        self.CancelButton = cancel_btn

        self._timer = Timer()
        self._timer.Interval = 1000
        self._timer.Tick += self._on_tick

        self._update_label()
        # Start the countdown once the dialog is actually on screen, so the
        # first second is not lost while the window is still opening.
        self.Shown += self._on_shown

        if night_mode is not None:
            try:
                night_mode.apply_to_form(self)
            except Exception:
                pass

    def _update_label(self):
        if self._remaining > 0:
            self.countdown_label.Text = (
                "Starting in %d s  -  click 'Cancel Run' to abort."
                % self._remaining)
        else:
            self.countdown_label.Text = "Starting now..."

    def _on_shown(self, sender, event):
        if self._remaining <= 0:
            self.DialogResult = DialogResult.OK
            self.Close()
            return
        self._timer.Start()

    def _on_tick(self, sender, event):
        self._remaining -= 1
        self._update_label()
        if self._remaining <= 0:
            self._timer.Stop()
            self.DialogResult = DialogResult.OK
            self.Close()

    def _on_cancel(self, sender, event):
        try:
            self._timer.Stop()
        except Exception:
            pass
        self.DialogResult = DialogResult.Cancel
        self.Close()


class SequencePickerDialog(Form):
    """Pick a saved sequence (or a built-in template) to load.

    After ShowDialog(), ``selected_name`` holds the chosen sequence name (or
    None if the user cancelled). Saved sequences are listed first, then the
    built-in templates (suffixed with '  (template)').
    """

    def __init__(self, saved_names, template_names, night_mode=None,
                 title="Load Sequence"):
        self.selected_name = None
        self._map = {}          # list item text -> real sequence name

        self.Text = title
        self.Width = 440
        self.Height = 430
        self.MinimumSize = Size(360, 300)
        self.StartPosition = FormStartPosition.CenterParent
        self.FormBorderStyle = FormBorderStyle.Sizable
        self.MaximizeBox = False
        self.MinimizeBox = False
        self.DialogResult = DialogResult.Cancel   # safe default (X = cancel)

        label = Label()
        label.Text = "Select a sequence to load:"
        label.Location = Point(12, 12)
        label.Size = Size(404, 20)
        self.Controls.Add(label)

        self.list_box = ListBox()
        self.list_box.Location = Point(12, 38)
        self.list_box.Size = Size(404, 300)
        self.list_box.DoubleClick += self._on_ok
        self.Controls.Add(self.list_box)

        for name in (saved_names or []):
            self.list_box.Items.Add(name)
            self._map[name] = name
        for name in (template_names or []):
            display = "%s  (template)" % name
            self.list_box.Items.Add(display)
            self._map[display] = name

        if self.list_box.Items.Count == 0:
            self.list_box.Items.Add("(no saved sequences)")
            self.list_box.Enabled = False
        else:
            self.list_box.SelectedIndex = 0

        ok_btn = Button()
        ok_btn.Text = "Load"
        ok_btn.Location = Point(236, 350)
        ok_btn.Size = Size(84, 28)
        ok_btn.Click += self._on_ok
        self.Controls.Add(ok_btn)

        cancel_btn = Button()
        cancel_btn.Text = "Cancel"
        cancel_btn.Location = Point(330, 350)
        cancel_btn.Size = Size(84, 28)
        cancel_btn.Click += self._on_cancel
        self.Controls.Add(cancel_btn)

        self.AcceptButton = ok_btn
        self.CancelButton = cancel_btn

        if night_mode is not None:
            try:
                night_mode.apply_to_form(self)
            except Exception:
                pass

    def _on_ok(self, sender, event):
        try:
            display = self.list_box.SelectedItem
        except Exception:
            display = None
        name = self._map.get(str(display)) if display is not None else None
        if not name:
            return
        self.selected_name = name
        self.DialogResult = DialogResult.OK
        self.Close()

    def _on_cancel(self, sender, event):
        self.DialogResult = DialogResult.Cancel
        self.Close()

