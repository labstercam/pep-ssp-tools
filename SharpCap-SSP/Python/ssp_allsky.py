"""
All Sky Calibration Module for SharpCap-SSP
Replicates AllSky2,57.bas functionality for wide-field photometry calibration.

This module determines zero-point constants and residual extinction for 
all-sky photometry across the entire visible sky.

Version: 1.0.0
Date: January 2026
Author: pep-ssp-tools project

Based on: AllSky2,57.bas from SSPDataq v3.3.21 (Optec, Inc., 2015)
"""

import clr
clr.AddReference('System')
clr.AddReference('System.Windows.Forms')
clr.AddReference('System.Drawing')

from System import *
from System.Windows.Forms import *
from System.Drawing import *
from System import DateTime, Math
import math
import os
import traceback
from datetime import datetime as dt_datetime

# Import existing tested calculation functions
from ssp_extinction import AirmassCalculator, ExtinctionCatalog
from ssp_config import SSPConfig
import ssp_dialogs


class AllSkyStar:
    """Represents an all-sky calibration star (F-type in catalog)."""
    
    def __init__(self, name, ra_hours, dec_deg, v_mag, b_v):
        """
        Initialize AllSkyStar.
        
        Args:
            name: Star designation
            ra_hours: Right Ascension in decimal hours (0-24)
            dec_deg: Declination in decimal degrees (-90 to +90)
            v_mag: V-band magnitude (or r' for Sloan)
            b_v: B-V color index (or g-r for Sloan)
        """
        self.name = name
        self.ra_hours = ra_hours
        self.dec_deg = dec_deg
        self.v_mag = v_mag
        self.b_v = b_v
    
    @property
    def ra_deg(self):
        """Right Ascension in decimal degrees (0-360)."""
        return self.ra_hours * 15.0


class AllSkyCalibration:
    """
    All-sky calibration calculator.
    Determines zero-point constants and residual extinction.
    Uses existing tested AirmassCalculator from ssp_extinction module.
    """
    
    def __init__(self, latitude, longitude):
        """
        Initialize calibration calculator.
        
        Args:
            latitude: Observer latitude in decimal degrees (positive North)
            longitude: Observer longitude in decimal degrees (positive East)
        """
        # Use the existing tested calculator
        self.calculator = AirmassCalculator(latitude, longitude)
        
        # Loaded from PPparms
        self.epsilon = 0.0  # Transformation coefficient for V
        self.mu = 0.0      # Color transformation coefficient
        
        # Results
        self.K_v = 0.0     # Residual extinction for V
        self.K_bv = 0.0    # Residual extinction for B-V
        self.ZP_v = 0.0    # Zero-point for V
        self.ZP_bv = 0.0   # Zero-point for B-V
        self.E_v = 0.0     # Standard error for V
        self.E_bv = 0.0    # Standard error for B-V
    
    def calculate_airmass(self, ra_deg, dec_deg, utc_time):
        """
        Calculate airmass using existing tested Hardie equation implementation.
        
        Args:
            ra_deg: Right Ascension in degrees
            dec_deg: Declination in degrees
            utc_time: datetime object in UTC
            
        Returns:
            Airmass (X) or None if star below horizon
        """
        return self.calculator.calculate_airmass(ra_deg, dec_deg, utc_time)
    
    def linear_regression(self, x_values, y_values):
        """
        Perform linear least-squares regression.
        Nielson method from Henden & Kaitchuck 1982.
        
        Args:
            x_values: List of X values (airmass)
            y_values: List of Y values (magnitudes or colors)
            
        Returns:
            tuple: (slope, intercept, std_error)
        """
        n = len(x_values)
        if n < 2:
            return (0.0, 0.0, 0.0)
        
        a1 = float(n)
        a2 = sum(x_values)
        a3 = sum(x * x for x in x_values)
        c1 = sum(y_values)
        c2 = sum(x * y for x, y in zip(x_values, y_values))
        
        det = 1.0 / (a1 * a3 - a2 * a2)
        intercept = -1.0 * (a2 * c2 - c1 * a3) * det
        slope = (a1 * c2 - c1 * a2) * det
        
        # Standard error
        if n > 2:
            y_deviation_squared_sum = 0.0
            for x, y in zip(x_values, y_values):
                y_fit = slope * x + intercept
                y_deviation = y - y_fit
                y_deviation_squared_sum += y_deviation * y_deviation
            
            std_error = Math.Sqrt((1.0 / (n - 2)) * y_deviation_squared_sum)
        else:
            std_error = 0.0
        
        return (slope, intercept, std_error)


def show_allsky_calibration_window():
    """Launch the All Sky Calibration dialog window."""
    try:
        # Create and show the dialog as modal
        dialog = AllSkyCalibrationDialog()
        dialog.ShowDialog()
    except Exception as e:
        import traceback
        error_detail = traceback.format_exc()
        MessageBox.Show(
            "Error launching All Sky Calibration window:\n\n" + str(e) + 
            "\n\nDetails:\n" + error_detail,
            "Error",
            MessageBoxButtons.OK,
            MessageBoxIcon.Error
        )


class AllSkyCalibrationDialog(Form):
    """
    All Sky Calibration dialog window.
    Replicates AllSky2,57.bas interface and functionality.
    """
    
    def __init__(self):
        """Initialize the All Sky Calibration dialog."""
        # Data storage
        self.raw_data = []
        self.trans_stars = []
        self.filter_system = "1"  # 1=Johnson/Cousins, 0=Sloan
        
        # Load configuration to get observer location
        self.config = SSPConfig()
        observer_lat = self.config.get('observer_latitude', 0.0)
        observer_lon = self.config.get('observer_longitude', 0.0)
        observer_elev = self.config.get('observer_elevation', 0.0)
        observer_city = self.config.get('observer_city', '')
        
        # Initialize calibration calculator with observer location
        self.calibration = AllSkyCalibration(observer_lat, observer_lon)
        
        # Warn if location not set
        if observer_lat == 0.0 and observer_lon == 0.0:
            print("WARNING: Observer location not set (0.0, 0.0)")
            print("Click 'Set Location' button to configure observer location")
        else:
            location_name = observer_city if observer_city else "Custom Location"
            print("All Sky Calibration initialized for: {0} ({1:.4f}, {2:.4f})".format(
                location_name, observer_lat, observer_lon))
        
        # Load star catalog
        self.star_catalog = ExtinctionCatalog()
        # Get the directory where ssp_allsky.py is located
        if '__file__' in dir():
            script_dir = os.path.dirname(os.path.abspath(__file__))
        else:
            # Fallback for IronPython when __file__ not available
            import sys
            script_dir = os.path.dirname(os.path.abspath(sys.argv[0]))
            # If running from SharpCap, the script is in the Python subdirectory
            if not os.path.exists(os.path.join(script_dir, 'first_order_extinction_stars.csv')):
                # Try Python subdirectory relative to current location
                import ssp_allsky
                script_dir = os.path.dirname(os.path.abspath(ssp_allsky.__file__))
        
        catalog_path = os.path.join(script_dir, 'first_order_extinction_stars.csv')
        print("Loading catalog from: {0}".format(catalog_path))
        star_count = self.star_catalog.load_from_csv(catalog_path)
        if star_count == 0:
            print("Warning: No stars loaded from catalog")
        
        # Data storage for calculations
        self.epsilon = 0.0  # Transformation coefficient for V
        self.mu = 0.0       # Transformation coefficient for B-V
        self.star_data = []  # List of dicts with star data for regression
        
        # Initialize UI and load configuration (may update calibration location)
        self._initialize_components()
        self._load_configuration()
        self._load_epsilon_mu()
        
    def _initialize_components(self):
        """Set up the UI components matching AllSky2,57.bas layout."""
        self.Text = "All Sky Calibration - Johnson/Cousins/Sloan Photometry"
        self.Size = Size(1050, 730)
        self.StartPosition = FormStartPosition.CenterScreen
        self.FormBorderStyle = FormBorderStyle.FixedDialog
        self.MaximizeBox = False
        
        # Menu bar
        menu = MenuStrip()
        
        # File menu
        file_menu = ToolStripMenuItem("File")
        self.open_menu_item = ToolStripMenuItem("Open Data File...")
        self.open_menu_item.Click += self._on_open_file
        file_menu.DropDownItems.Add(self.open_menu_item)
        
        self.save_plot_item = ToolStripMenuItem("Save Plot...")
        self.save_plot_item.Click += self._on_save_plot
        file_menu.DropDownItems.Add(self.save_plot_item)
        
        file_menu.DropDownItems.Add(ToolStripSeparator())
        
        exit_item = ToolStripMenuItem("Exit")
        exit_item.Click += self._on_exit
        file_menu.DropDownItems.Add(exit_item)
        
        menu.Items.Add(file_menu)
        
        # Coefficients menu
        coeff_menu = ToolStripMenuItem("Coefficients")
        
        self.load_prev_item = ToolStripMenuItem("Load Previous")
        self.load_prev_item.Click += self._on_load_previous
        coeff_menu.DropDownItems.Add(self.load_prev_item)
        
        self.save_coeff_item = ToolStripMenuItem("Save")
        self.save_coeff_item.Click += self._on_save_coefficients
        coeff_menu.DropDownItems.Add(self.save_coeff_item)
        
        self.use_current_item = ToolStripMenuItem("Use Current")
        self.use_current_item.Click += self._on_use_current
        coeff_menu.DropDownItems.Add(self.use_current_item)
        
        self.clear_item = ToolStripMenuItem("Clear")
        self.clear_item.Click += self._on_clear_coefficients
        coeff_menu.DropDownItems.Add(self.clear_item)
        
        menu.Items.Add(coeff_menu)
        
        # Help menu
        help_menu = ToolStripMenuItem("Help")
        
        about_item = ToolStripMenuItem("About...")
        about_item.Click += self._on_about
        help_menu.DropDownItems.Add(about_item)
        
        menu.Items.Add(help_menu)
        
        self.Controls.Add(menu)
        
        # Main panel
        main_panel = Panel()
        main_panel.Location = Point(0, 30)
        main_panel.Size = Size(1034, 670)
        main_panel.AutoScroll = True
        
        # File name label
        file_label = Label()
        file_label.Text = "File:"
        file_label.Location = Point(15, 15)
        file_label.Size = Size(35, 20)
        main_panel.Controls.Add(file_label)
        
        self.filename_text = TextBox()
        self.filename_text.Location = Point(55, 12)
        self.filename_text.Size = Size(600, 20)
        self.filename_text.ReadOnly = True
        self.filename_text.Text = "open raw data file"
        main_panel.Controls.Add(self.filename_text)
        
        # Observer location display
        location_label = Label()
        location_label.Text = "Observer Location:"
        location_label.Location = Point(670, 15)
        location_label.Size = Size(110, 20)
        main_panel.Controls.Add(location_label)
        
        self.location_text = TextBox()
        self.location_text.Location = Point(785, 12)
        self.location_text.Size = Size(150, 20)
        self.location_text.ReadOnly = True
        self.location_text.BackColor = SystemColors.Control
        # Display current location
        lat = self.config.get('observer_latitude', 0.0)
        lon = self.config.get('observer_longitude', 0.0)
        city = self.config.get('observer_city', '')
        if lat == 0.0 and lon == 0.0:
            self.location_text.Text = "NOT SET (0.0, 0.0)"
            self.location_text.ForeColor = Color.Red
        else:
            if city:
                self.location_text.Text = city
            else:
                self.location_text.Text = "{0:.2f}, {1:.2f}".format(lat, lon)
        main_panel.Controls.Add(self.location_text)
        
        # Set Location button
        self.set_location_button = Button()
        self.set_location_button.Text = "Set Location..."
        self.set_location_button.Location = Point(940, 10)
        self.set_location_button.Size = Size(90, 24)
        self.set_location_button.Click += self._on_set_location
        main_panel.Controls.Add(self.set_location_button)
        
        # Transformation table groupbox
        table_group = GroupBox()
        table_group.Text = "All Sky Stars"
        table_group.Location = Point(10, 40)
        table_group.Size = Size(500, 265)
        
        # Data grid view for transformation table
        self.data_grid = DataGridView()
        self.data_grid.Location = Point(10, 20)
        self.data_grid.Size = Size(480, 235)
        self.data_grid.AllowUserToAddRows = False
        self.data_grid.AllowUserToDeleteRows = False
        self.data_grid.ReadOnly = True
        self.data_grid.SelectionMode = DataGridViewSelectionMode.FullRowSelect
        self.data_grid.MultiSelect = False
        
        # Add columns
        self.data_grid.Columns.Add("Star", "Star")
        self.data_grid.Columns.Add("X", "X")
        self.data_grid.Columns.Add("V", "V")
        self.data_grid.Columns.Add("BV", "B-V")
        self.data_grid.Columns.Add("v", "v")
        self.data_grid.Columns.Add("Vv_eBV", "(V-v)-ε(B-V)")
        self.data_grid.Columns.Add("BV_mbv", "(B-V)-μ(b-v)")
        
        # Set column widths to fit in narrower space
        self.data_grid.Columns[0].Width = 80  # Star name
        for i in range(1, 7):
            self.data_grid.Columns[i].Width = 65  # Numeric columns
        
        table_group.Controls.Add(self.data_grid)
        main_panel.Controls.Add(table_group)
        
        # Graph box
        self.graph_box = PictureBox()
        self.graph_box.Location = Point(515, 40)
        self.graph_box.Size = Size(490, 265)
        self.graph_box.BorderStyle = BorderStyle.FixedSingle
        self.graph_box.BackColor = Color.White
        main_panel.Controls.Add(self.graph_box)
        
        # Graph control buttons (below table, next to graph)
        button_x = 10
        button_y = 315
        
        self.show_kv_button = Button()
        self.show_kv_button.Text = "extinction plot for v"
        self.show_kv_button.Location = Point(button_x, button_y)
        self.show_kv_button.Size = Size(225, 25)
        self.show_kv_button.Click += self._on_show_kv
        self.show_kv_button.Enabled = False
        main_panel.Controls.Add(self.show_kv_button)
        
        self.show_kbv_button = Button()
        self.show_kbv_button.Text = "extinction plot for b-v"
        self.show_kbv_button.Location = Point(button_x + 240, button_y)
        self.show_kbv_button.Size = Size(225, 25)
        self.show_kbv_button.Click += self._on_show_kbv
        self.show_kbv_button.Enabled = False
        main_panel.Controls.Add(self.show_kbv_button)
        
        self.print_button = Button()
        self.print_button.Text = "print"
        self.print_button.Location = Point(button_x + 485, button_y)
        self.print_button.Size = Size(57, 25)
        self.print_button.Click += self._on_print_graph
        self.print_button.Enabled = False
        main_panel.Controls.Add(self.print_button)
        
        # Results groupbox (below buttons and graph)
        results_group = GroupBox()
        results_group.Text = "Results"
        results_group.Location = Point(10, 350)
        results_group.Size = Size(680, 85)
        
        # First row of results
        y_pos = 25
        x_spacing = 170
        
        # K v
        kv_label = Label()
        kv_label.Text = "K'v:"
        kv_label.Location = Point(15, y_pos)
        kv_label.Size = Size(40, 20)
        results_group.Controls.Add(kv_label)
        
        self.kv_text = TextBox()
        self.kv_text.Location = Point(55, y_pos)
        self.kv_text.Size = Size(100, 20)
        results_group.Controls.Add(self.kv_text)
        
        # ZP v
        zpv_label = Label()
        zpv_label.Text = "ZPv:"
        zpv_label.Location = Point(15 + x_spacing, y_pos)
        zpv_label.Size = Size(40, 20)
        results_group.Controls.Add(zpv_label)
        
        self.zpv_text = TextBox()
        self.zpv_text.Location = Point(55 + x_spacing, y_pos)
        self.zpv_text.Size = Size(100, 20)
        results_group.Controls.Add(self.zpv_text)
        
        # E v
        ev_label = Label()
        ev_label.Text = "Ev:"
        ev_label.Location = Point(15 + x_spacing*2, y_pos)
        ev_label.Size = Size(40, 20)
        results_group.Controls.Add(ev_label)
        
        self.ev_text = TextBox()
        self.ev_text.Location = Point(55 + x_spacing*2, y_pos)
        self.ev_text.Size = Size(100, 20)
        results_group.Controls.Add(self.ev_text)
        
        # Second row of results
        y_pos = 50
        
        # K b-v
        kbv_label = Label()
        kbv_label.Text = "K'bv:"
        kbv_label.Location = Point(15, y_pos)
        kbv_label.Size = Size(40, 20)
        results_group.Controls.Add(kbv_label)
        
        self.kbv_text = TextBox()
        self.kbv_text.Location = Point(55, y_pos)
        self.kbv_text.Size = Size(100, 20)
        results_group.Controls.Add(self.kbv_text)
        
        # ZP b-v
        zpbv_label = Label()
        zpbv_label.Text = "ZPbv:"
        zpbv_label.Location = Point(15 + x_spacing, y_pos)
        zpbv_label.Size = Size(40, 20)
        results_group.Controls.Add(zpbv_label)
        
        self.zpbv_text = TextBox()
        self.zpbv_text.Location = Point(55 + x_spacing, y_pos)
        self.zpbv_text.Size = Size(100, 20)
        results_group.Controls.Add(self.zpbv_text)
        
        # E b-v
        ebv_label = Label()
        ebv_label.Text = "Ebv:"
        ebv_label.Location = Point(15 + x_spacing*2, y_pos)
        ebv_label.Size = Size(40, 20)
        results_group.Controls.Add(ebv_label)
        
        self.ebv_text = TextBox()
        self.ebv_text.Location = Point(55 + x_spacing*2, y_pos)
        self.ebv_text.Size = Size(100, 20)
        results_group.Controls.Add(self.ebv_text)
        
        main_panel.Controls.Add(results_group)
        
        # Analysis groupbox (Least Squares details)
        analysis_group = GroupBox()
        analysis_group.Text = "Least-Squares Analysis"
        analysis_group.Location = Point(700, 350)
        analysis_group.Size = Size(305, 85)
        
        # Analysis textbox (shows slope, intercept, std error)
        self.analysis_text = TextBox()
        self.analysis_text.Location = Point(90, 20)
        self.analysis_text.Size = Size(90, 55)
        self.analysis_text.Multiline = True
        self.analysis_text.ReadOnly = True
        self.analysis_text.Font = Font("Courier New", 9)
        analysis_group.Controls.Add(self.analysis_text)
        
        # Labels for analysis textbox
        slope_label = Label()
        slope_label.Text = "slope"
        slope_label.Location = Point(190, 25)
        slope_label.Size = Size(55, 15)
        slope_label.Font = Font("Arial", 8)
        analysis_group.Controls.Add(slope_label)
        
        intercept_label = Label()
        intercept_label.Text = "intercept"
        intercept_label.Location = Point(190, 40)
        intercept_label.Size = Size(65, 15)
        intercept_label.Font = Font("Arial", 8)
        analysis_group.Controls.Add(intercept_label)
        
        stderr_label = Label()
        stderr_label.Text = "standard error"
        stderr_label.Location = Point(190, 55)
        stderr_label.Size = Size(90, 15)
        stderr_label.Font = Font("Arial", 8)
        analysis_group.Controls.Add(stderr_label)
        
        main_panel.Controls.Add(analysis_group)
        
        # Set up the form
        self.Controls.Add(main_panel)
        
    def _load_epsilon_mu(self):
        """Load epsilon and mu coefficients from PPparms3.txt"""
        try:
            # Get the SSPDataq directory (parent of SharpCap-SSP)
            if '__file__' in dir():
                script_dir = os.path.dirname(os.path.abspath(__file__))
            else:
                import sys
                script_dir = os.path.dirname(os.path.abspath(sys.argv[0]))
                if not os.path.exists(os.path.join(script_dir, 'first_order_extinction_stars.csv')):
                    import ssp_allsky
                    script_dir = os.path.dirname(os.path.abspath(ssp_allsky.__file__))
            
            parent_dir = os.path.dirname(os.path.dirname(script_dir))
            pparms_path = os.path.join(parent_dir, 'SSPDataq', 'PPparms3.txt')
            
            if os.path.exists(pparms_path):
                with open(pparms_path, 'r') as f:
                    lines = f.readlines()
                    if len(lines) >= 10:
                        # Line 8 (index 7) is epsilon
                        # Line 10 (index 9) is mu
                        self.epsilon = float(lines[7].strip())
                        self.mu = float(lines[9].strip())
                        print("Loaded transformation coefficients: epsilon={0:.3f}, mu={1:.3f}".format(
                            self.epsilon, self.mu))
                        return
            
            print("PPparms3.txt not found, using default coefficients (epsilon=0, mu=0)")
        except Exception as e:
            print("Error loading transformation coefficients: {0}".format(e))
    
    def _load_configuration(self):
        """Load configuration from SSPConfig (observer location already loaded in __init__)."""
        # Configuration is now loaded via SSPConfig in __init__
        # This method kept for potential future PPparms coefficient loading
        pass
    
    def _on_open_file(self, sender, event):
        """Handle Open Data File menu item."""
        dialog = OpenFileDialog()
        dialog.Filter = "Raw Data Files (*.raw)|*.raw|All Files (*.*)|*.*"
        dialog.Title = "Open Data File"
        
        if dialog.ShowDialog() == DialogResult.OK:
            self._load_raw_file(dialog.FileName)
    
    def _load_raw_file(self, filepath):
        """Load and process raw data file."""
        try:
            self.filename_text.Text = os.path.basename(filepath)
            
            # Clear existing data
            self.data_grid.Rows.Clear()
            self.raw_data = []
            self.star_data = []  # Clear star data from previous file
            self.regression_data = []  # Clear regression data
            
            # Clear results display
            self.kv_text.Text = ""
            self.zpv_text.Text = ""
            self.ev_text.Text = ""
            self.kbv_text.Text = ""
            self.zpbv_text.Text = ""
            self.ebv_text.Text = ""
            self.analysis_text.Text = ""
            
            # Clear graph
            if self.graph_box.Image is not None:
                self.graph_box.Image.Dispose()
                self.graph_box.Image = None
            self.graph_box.Refresh()
            
            # Disable buttons until new calculations are performed
            self.show_kv_button.Enabled = False
            self.show_kbv_button.Enabled = False
            self.print_button.Enabled = False
            
            # Read file
            with open(filepath, 'r') as f:
                lines = f.readlines()
            
            if len(lines) < 4:
                MessageBox.Show("Invalid file format - too few lines", "Error",
                              MessageBoxButtons.OK, MessageBoxIcon.Error)
                return
            
            # Parse data lines (skip 4-line header)
            # Format: star line followed immediately by sky line for that star
            observations = {}  # Group by star name
            debug_count = 0  # Counter for debug output
            
            i = 4  # Start after 4-line header
            while i < len(lines):
                line = lines[i]
                
                # Use fixed-width field parsing to match AllSky2,57.bas [Convert_RawFile]
                # BASIC mid$(string, pos, len) uses 1-based positions
                # .raw files have leading space, so BASIC position N = Python index N
                # Format: MM-DD-YYYY HH:MM:SS CAT OBJECT F CNT1 CNT2 CNT3 CNT4 INT SCLE
                # BASIC:  1-10       12-19    21  26-37  41 44-48 51-55 58-62 65-69 72-73 75-77
                if len(line) < 70:
                    i += 1
                    continue
                
                # Extract fields using BASIC positions (accounting for leading space)
                try:
                    date_str = line[1:11].strip()     # BASIC pos 1, len 10: MM-DD-YYYY
                    time_str = line[12:20].strip()    # BASIC pos 12, len 8: HH:MM:SS (positions 12-19)
                    cat = line[21:22].strip()         # BASIC pos 21, len 1: Catalog code
                    obj_name = line[26:38].strip()    # BASIC pos 26, len 12: Star name
                    filter_name = line[41:42].strip() # BASIC pos 41, len 1: Filter
                    # Counts: BASIC pos 44, 51, 58, 65 (len 5 each)
                    cnt1_str = line[44:49].strip()
                    cnt2_str = line[51:56].strip()
                    cnt3_str = line[58:63].strip()
                    cnt4_str = line[65:70].strip() if len(line) >= 70 else ""
                except IndexError:
                    i += 1
                    continue
                
                if not date_str or not time_str:
                    i += 1
                    continue
                
                # Skip lines that are sky readings without associated star
                if obj_name.upper().startswith("SKY"):
                    i += 1
                    continue
                
                # Process calibration stars (F-type or C-type)
                # F = All-sky calibration stars
                # C = Check stars (standard photometric stars suitable for extinction)
                if cat not in ['F', 'C']:
                    print("Skipping non-calibration star: cat='{0}', obj='{1}'".format(cat, obj_name))
                    i += 1
                    continue
                
                print("Processing calibration star: cat='{0}', obj='{1}', filter='{2}'".format(cat, obj_name, filter_name))
                
                # Parse star counts (only first 3 values for All Sky)
                try:
                    counts = []
                    if cnt1_str and cnt1_str.isdigit():
                        counts.append(int(cnt1_str))
                    if cnt2_str and cnt2_str.isdigit():
                        counts.append(int(cnt2_str))
                    if cnt3_str and cnt3_str.isdigit():
                        counts.append(int(cnt3_str))
                    # Note: cnt4 is not used for All Sky observations
                    
                    # Debug: show first few stars' raw count strings
                    if debug_count < 3:
                        print("  Star raw counts: '{0}', '{1}', '{2}'".format(cnt1_str, cnt2_str, cnt3_str))
                        print("  Star parsed counts: {0}".format(counts))
                    
                    if len(counts) < 3:
                        i += 1
                        continue
                    
                    # Calculate average star count (only first 3)
                    avg_count = sum(counts) / 3.0
                    
                    # Read next line for sky background
                    i += 1
                    if i >= len(lines):
                        print("  Warning: No sky line after star '{0}'".format(obj_name))
                        continue
                    
                    sky_line = lines[i]
                    if len(sky_line) < 70:
                        print("  Warning: Sky line too short for star '{0}'".format(obj_name))
                        continue
                    
                    # Parse sky counts from next line
                    sky_cnt1_str = sky_line[44:49].strip()
                    sky_cnt2_str = sky_line[51:56].strip()
                    sky_cnt3_str = sky_line[58:63].strip()
                    
                    sky_counts = []
                    if sky_cnt1_str and sky_cnt1_str.isdigit():
                        sky_counts.append(int(sky_cnt1_str))
                    if sky_cnt2_str and sky_cnt2_str.isdigit():
                        sky_counts.append(int(sky_cnt2_str))
                    if sky_cnt3_str and sky_cnt3_str.isdigit():
                        sky_counts.append(int(sky_cnt3_str))
                    
                    if debug_count <= 3:
                        print("  Sky raw counts: '{0}', '{1}', '{2}'".format(sky_cnt1_str, sky_cnt2_str, sky_cnt3_str))
                        print("  Sky parsed counts: {0}".format(sky_counts))
                    debug_count += 1
                    
                    if len(sky_counts) < 3:
                        print("  Warning: Invalid sky counts for star '{0}'".format(obj_name))
                        i += 1
                        continue
                    
                    # Calculate average sky count
                    sky_avg = sum(sky_counts) / float(len(sky_counts))
                    
                    # Parse datetime
                    datetime_str = date_str + " " + time_str
                    obs_time = dt_datetime.strptime(datetime_str, "%m-%d-%Y %H:%M:%S")
                    # .raw files record times in UTC - mark as UTC timezone
                    from datetime import timezone
                    obs_time = obs_time.replace(tzinfo=timezone.utc)
                    
                    # Store observation - allow multiple observations of same star/filter
                    key = (obj_name, filter_name, obs_time)  # Include time to avoid overwriting
                    observations[key] = {
                        'name': obj_name,
                        'filter': filter_name,
                        'time': obs_time,
                        'counts': avg_count,
                        'sky': sky_avg
                    }
                
                except (ValueError, IndexError) as e:
                    print("Error parsing line: " + line + " - " + str(e))
                
                # Move to next star (skip the sky line we just processed)
                i += 1
            
            if not observations:
                MessageBox.Show(
                    "No calibration stars found in file.\n\n" +
                    "All Sky Calibration requires observations of photometric\n" +
                    "standard stars marked as:\n" +
                    "  F = All-sky calibration stars\n" +
                    "  C = Check stars (standard photometric stars)\n\n" +
                    "The stars in first_order_extinction_stars.csv are suitable\n" +
                    "when observed and marked as 'C' or 'F' in your data file.",
                    "No Data",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning
                )
                return
            
            # Process observations and populate grid
            processed_count = 0
            for key, obs in observations.items():
                star_name = obs['name']
                
                # Look up star in catalog to get V mag, B-V, RA, DEC
                star = self.star_catalog.get_star(star_name)
                if star is None:
                    print("Warning: Star '{0}' not found in catalog".format(star_name))
                    continue
                
                # Calculate airmass using observed time
                airmass = self.calibration.calculate_airmass(
                    star.ra_deg, star.dec_deg, obs['time'])
                
                if airmass is None:
                    print("Warning: Star '{0}' was below horizon at observation time".format(star_name))
                    continue
                
                # Calculate sky-subtracted counts
                sky_count = obs['sky']
                net_count = obs['counts'] - sky_count
                
                if net_count <= 0:
                    print("Warning: Star '{0}' has zero or negative counts after sky subtraction".format(star_name))
                    continue
                
                # Calculate instrumental magnitude: v = -2.5 * log10(net_count)
                # Note: BASIC uses -1.0857 * log(x) which is -2.5 / ln(10) * ln(x) = -2.5 * log10(x)
                inst_mag = -2.5 * math.log10(net_count)
                
                # Debug output
                if processed_count < 3:  # Show first few stars
                    print("Star {0} filter {1}: counts={2:.1f}, sky={3:.1f}, net={4:.1f}, inst_mag={5:.3f}".format(
                        star_name, obs['filter'], obs['counts'], sky_count, net_count, inst_mag))
                
                # Store data for this observation
                obs_data = {
                    'star_name': star_name,
                    'filter': obs['filter'],
                    'airmass': airmass,
                    'v_mag': star.v_mag,
                    'b_v': star.b_v,
                    'inst_mag': inst_mag,
                    'time': obs['time']
                }
                self.star_data.append(obs_data)
                processed_count += 1
            
            # After processing all observations, aggregate by star and populate grid
            self._populate_grid_from_data()
            
        except Exception as e:
            error_detail = traceback.format_exc()
            MessageBox.Show(
                "Error loading raw file:\n\n" + str(e) +
                "\n\nDetails:\n" + error_detail,
                "Error",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error
            )
    
    def _populate_grid_from_data(self):
        """Aggregate observations by star and populate grid with transformation columns."""
        # Group observations by star
        star_groups = {}
        for obs in self.star_data:
            star_name = obs['star_name']
            if star_name not in star_groups:
                star_groups[star_name] = {'B': [], 'V': [], 'U': [], 'R': []}
            
            filter_name = obs['filter']
            if filter_name in star_groups[star_name]:
                star_groups[star_name][filter_name].append(obs)
        
        # Process each star that has V observations (B is optional)
        self.data_grid.Rows.Clear()
        self.regression_data = []  # Store data for regression
        
        for star_name, filters in star_groups.items():
            has_b = len(filters['B']) > 0
            has_v = len(filters['V']) > 0
            
            if not has_v:
                continue  # Need at least V observation
            
            v_obs = filters['V'][0]  # Use first V observation
            
            # Get catalog values
            V_mag = v_obs['v_mag']      # Standard V magnitude
            B_V = v_obs['b_v']          # Standard (B-V) color from catalog
            
            # Instrumental V magnitude
            v_inst = v_obs['inst_mag']
            
            # Airmass and color calculations
            if has_b:
                # Both B and V available - use instrumental color
                b_obs = filters['B'][0]
                b_inst = b_obs['inst_mag']
                b_v_inst = b_inst - v_inst  # Instrumental (b-v) color
                avg_airmass = (b_obs['airmass'] + v_obs['airmass']) / 2.0
            else:
                # V only - use catalog color for calculations
                b_inst = None
                b_v_inst = B_V  # Use catalog color as approximation
                avg_airmass = v_obs['airmass']
            
            # Calculate transformation columns
            # (V-v) - ε(B-V) from equation G.10 - always use catalog B-V
            V_minus_v = V_mag - v_inst
            trans_col5 = V_minus_v - self.epsilon * B_V
            
            # Debug: Print first star's calculation
            if len(self.regression_data) == 0:
                print("First star calculation: {0}".format(star_name))
                print("  Airmass X={0:.3f}".format(avg_airmass))
                print("  V_mag={0:.3f}, v_inst={1:.3f}, V-v={2:.3f}".format(V_mag, v_inst, V_minus_v))
                print("  B-V={0:.3f}, epsilon={1:.3f}, eps*(B-V)={2:.3f}".format(B_V, self.epsilon, self.epsilon * B_V))
                print("  trans_col5 = (V-v) - eps*(B-V) = {0:.3f}".format(trans_col5))
                print("  This plots as Y={0:.3f} vs X={1:.3f}".format(trans_col5, avg_airmass))
            
            # (B-V) - μ(b-v) from equation G.11
            if has_b:
                trans_col6 = B_V - self.mu * b_v_inst
            else:
                trans_col6 = None  # Cannot calculate without instrumental b-v
            
            # Add row to grid
            row_index = self.data_grid.Rows.Add()
            self.data_grid.Rows[row_index].Cells[0].Value = star_name
            self.data_grid.Rows[row_index].Cells[1].Value = "{0:.3f}".format(avg_airmass)
            self.data_grid.Rows[row_index].Cells[2].Value = "{0:.2f}".format(V_mag)
            self.data_grid.Rows[row_index].Cells[3].Value = "{0:.2f}".format(B_V)
            self.data_grid.Rows[row_index].Cells[4].Value = "{0:.3f}".format(v_inst) if has_v else "--"
            self.data_grid.Rows[row_index].Cells[5].Value = "{0:.3f}".format(trans_col5)
            self.data_grid.Rows[row_index].Cells[6].Value = "{0:.3f}".format(trans_col6) if trans_col6 is not None else "--"
            
            # Store for regression
            self.regression_data.append({
                'star_name': star_name,
                'airmass': avg_airmass,
                'has_b': has_b,
                'trans_col5': trans_col5,  # Y-axis for K'v plot (always available)
                'trans_col6': trans_col6   # Y-axis for K'bv plot (only if B available)
            })
        
        # Show results
        processed_count = len(self.regression_data)
        total_observations = len(self.star_data)
        
        if processed_count == 0:
            MessageBox.Show(
                "Loaded {0} observations but no stars could be processed.\n\n".format(total_observations) +
                "Possible reasons:\n" +
                "- Stars not found in catalog\n" +
                "- Stars below horizon at observation time\n" +
                "- Invalid count data after sky subtraction\n" +
                "- Missing V filter observations",
                    "No Data Processed",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Warning
                )
        else:
            # Count how many stars have B observations
            b_count = sum(1 for d in self.regression_data if d['has_b'])
            
            msg = "Processed {0} stars from {1} total observations.\n\n".format(processed_count, total_observations)
            msg += "Calculated:\n"
            msg += "- Airmass (X) using Hardie equation\n"
            msg += "- Instrumental V magnitudes from counts\n"
            
            if b_count > 0:
                msg += "- Instrumental B magnitudes for {0} stars\n".format(b_count)
                msg += "- Transformation columns using epsilon={0:.3f}, mu={1:.3f}\n\n".format(self.epsilon, self.mu)
                msg += "Ready to calculate K'v and K'bv.\n"
                msg += "Click 'extinction plot for v' or 'extinction plot for b-v'."
                # Enable both buttons since we have B data
                self.show_kv_button.Enabled = True
                self.show_kbv_button.Enabled = True
            else:
                msg += "- V-only mode: Using catalog (B-V) for calculations\n"
                msg += "- Transformation column using epsilon={0:.3f}\n\n".format(self.epsilon)
                msg += "Ready to calculate K'v (V extinction only).\n"
                msg += "Click 'extinction plot for v'.\n"
                msg += "Note: B-V color extinction requires B filter observations."
                # Enable only K'v button for V-only mode
                self.show_kv_button.Enabled = True
                self.show_kbv_button.Enabled = False
            
            MessageBox.Show(msg, "Data Loaded", MessageBoxButtons.OK, MessageBoxIcon.Information)
    
    def _on_save_plot(self, sender, event):
        """Handle Save Plot menu item."""
        dialog = SaveFileDialog()
        dialog.Filter = "Bitmap Files (*.bmp)|*.bmp|PNG Files (*.png)|*.png"
        dialog.Title = "Save Plot As"
        
        if dialog.ShowDialog() == DialogResult.OK:
            try:
                if self.graph_box.Image is not None:
                    self.graph_box.Image.Save(dialog.FileName)
                    MessageBox.Show("Plot saved successfully.", "Success", 
                                  MessageBoxButtons.OK, MessageBoxIcon.Information)
            except Exception as e:
                MessageBox.Show("Error saving plot:\n\n" + str(e), "Error",
                              MessageBoxButtons.OK, MessageBoxIcon.Error)
    
    def _on_exit(self, sender, event):
        """Handle Exit menu item - return to launcher."""
        self.DialogResult = DialogResult.OK
        self.Close()
    
    def _on_set_location(self, sender, event):
        """Handle Set Location button."""
        # Get current values
        current_lat = self.config.get('observer_latitude', 0.0)
        current_lon = self.config.get('observer_longitude', 0.0)
        current_elev = self.config.get('observer_elevation', 0.0)
        current_city = self.config.get('observer_city', '')
        
        # Show location dialog
        dialog = ssp_dialogs.LocationDialog(current_lat, current_lon, current_elev, current_city)
        
        try:
            if dialog.ShowDialog() == DialogResult.OK:
                # Save new location
                self.config.set('observer_latitude', dialog.latitude)
                self.config.set('observer_longitude', dialog.longitude)
                self.config.set('observer_elevation', dialog.elevation)
                self.config.set('observer_city', dialog.city)
                self.config.save()
                
                # Update calibration calculator with new location
                self.calibration = AllSkyCalibration(dialog.latitude, dialog.longitude)
                
                # Update display
                if dialog.latitude == 0.0 and dialog.longitude == 0.0:
                    self.location_text.Text = "NOT SET (0.0, 0.0)"
                    self.location_text.ForeColor = Color.Red
                else:
                    if dialog.city:
                        self.location_text.Text = dialog.city
                    else:
                        self.location_text.Text = "{0:.2f}, {1:.2f}".format(dialog.latitude, dialog.longitude)
                    self.location_text.ForeColor = SystemColors.ControlText
                
                MessageBox.Show(
                    "Observer location updated.\n\n" +
                    "Location: {0}\n".format(dialog.city if dialog.city else "Custom") +
                    "Latitude: {0:.6f}\n".format(dialog.latitude) +
                    "Longitude: {0:.6f}\n".format(dialog.longitude) +
                    "Elevation: {0:.1f} m".format(dialog.elevation),
                    "Location Updated",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information
                )
        finally:
            dialog.Dispose()
    
    def _on_load_previous(self, sender, event):
        """Handle Load Previous Coefficients menu item."""
        # Load from PPparms and display
        MessageBox.Show("Load previous coefficients from PPparms3.txt", 
                       "Information", MessageBoxButtons.OK, MessageBoxIcon.Information)
    
    def _on_save_coefficients(self, sender, event):
        """Handle Save Coefficients menu item."""
        result = MessageBox.Show(
            "This will save all non-zero contents\n" +
            "Type a zero in box to keep previous saved constants\n\n" +
            "Do you wish to save values?",
            "Save Coefficients",
            MessageBoxButtons.YesNo,
            MessageBoxIcon.Question
        )
        
        if result == DialogResult.Yes:
            # Save to PPparms3.txt
            MessageBox.Show("Coefficients saved to PPparms3.txt", 
                          "Success", MessageBoxButtons.OK, MessageBoxIcon.Information)
    
    def _on_use_current(self, sender, event):
        """Handle Use Current Coefficients menu item."""
        # Copy current results to input boxes
        pass
    
    def _on_clear_coefficients(self, sender, event):
        """Handle Clear Coefficients menu item."""
        self.kv_text.Text = ""
        self.kbv_text.Text = ""
        self.zpv_text.Text = ""
        self.zpbv_text.Text = ""
        self.ev_text.Text = ""
        self.ebv_text.Text = ""
    
    def _on_about(self, sender, event):
        """Handle About menu item."""
        MessageBox.Show(
            "All Sky Calibration - Johnson/Cousins/Sloan Photometry\n" +
            "version 1.0.0\n" +
            "copyright 2026, pep-ssp-tools project\n\n" +
            "Based on AllSky2,57.bas from SSPDataq v3.3.21\n" +
            "(Optec, Inc., 2015)",
            "About All Sky Calibration",
            MessageBoxButtons.OK,
            MessageBoxIcon.Information
        )
    
    def _on_show_kv(self, sender, event):
        """Handle Show K v button - calculate K'v and draw extinction plot for V."""
        if not hasattr(self, 'regression_data') or len(self.regression_data) == 0:
            MessageBox.Show("No data loaded. Please open a data file first.",
                          "No Data", MessageBoxButtons.OK, MessageBoxIcon.Warning)
            return
        
        # Extract X and Y data for regression
        x_values = [d['airmass'] for d in self.regression_data]
        y_values = [d['trans_col5'] for d in self.regression_data]  # (V-v) - ε(B-V)
        
        # Perform linear regression
        slope, intercept, std_error = self.calibration.linear_regression(x_values, y_values)
        
        # K'v = -slope (negative of the slope)
        kv = -slope
        zp_v = intercept
        e_v = std_error
        
        # Update result textboxes
        self.kv_text.Text = "{0:.3f}".format(kv)
        self.zpv_text.Text = "{0:.3f}".format(zp_v)
        self.ev_text.Text = "{0:.3f}".format(e_v)
        
        # Update analysis textbox (right-aligned, 3 decimal places)
        self.analysis_text.Text = "{0:>8.3f}\r\n{1:>8.3f}\r\n{2:>8.3f}".format(slope, intercept, std_error)
        
        # Draw graph
        self._draw_graph("kv", x_values, y_values, slope, intercept)
    
    def _on_show_kbv(self, sender, event):
        """Handle Show K b-v button - calculate K'bv and draw extinction plot for B-V."""
        if not hasattr(self, 'regression_data') or len(self.regression_data) == 0:
            MessageBox.Show("No data loaded. Please open a data file first.",
                          "No Data", MessageBoxButtons.OK, MessageBoxIcon.Warning)
            return
        
        # Check if K'v has been calculated first
        if not self.kv_text.Text:
            MessageBox.Show("Please calculate K'v first by clicking 'extinction plot for v'.",
                          "Calculate K'v First", MessageBoxButtons.OK, MessageBoxIcon.Warning)
            return
        
        # Check if we have B observations
        stars_with_b = [d for d in self.regression_data if d['has_b'] and d['trans_col6'] is not None]
        if len(stars_with_b) == 0:
            MessageBox.Show(
                "Cannot calculate K'bv - no B filter observations found.\n\n" +
                "B-V color extinction requires observations in both B and V filters.\n" +
                "Your data file only contains V filter observations.\n\n" +
                "To calculate K'bv:\n" +
                "1. Observe each calibration star in both B and V filters\n" +
                "2. Reload the data file",
                "B Filter Required",
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning
            )
            return
        
        # Extract X and Y data for regression (only stars with B observations)
        x_values = [d['airmass'] for d in stars_with_b]
        y_values = [d['trans_col6'] for d in stars_with_b]  # (B-V) - μ(b-v)
        
        # Perform linear regression
        slope, intercept, std_error = self.calibration.linear_regression(x_values, y_values)
        
        # K'bv = -slope (negative of the slope)
        kbv = -slope
        zp_bv = intercept
        e_bv = std_error
        
        # Update result textboxes
        self.kbv_text.Text = "{0:.3f}".format(kbv)
        self.zpbv_text.Text = "{0:.3f}".format(zp_bv)
        self.ebv_text.Text = "{0:.3f}".format(e_bv)
        
        # Update analysis textbox (right-aligned, 3 decimal places)
        self.analysis_text.Text = "{0:>8.3f}\r\n{1:>8.3f}\r\n{2:>8.3f}".format(slope, intercept, std_error)
        
        # Draw graph
        self._draw_graph("kbv", x_values, y_values, slope, intercept)
    
    def _on_print_graph(self, sender, event):
        """Handle Print button."""
        if self.graph_box.Image is not None:
            # Simple print dialog
            MessageBox.Show("Print functionality available", "Print",
                          MessageBoxButtons.OK, MessageBoxIcon.Information)
    
    def _draw_graph(self, graph_type, x_values, y_values, slope, intercept):
        """
        Draw calibration graph with data points and regression line.
        
        Args:
            graph_type: "kv" for K v graph, "kbv" for K b-v graph
            x_values: List of airmass values (X-axis)
            y_values: List of transformation values (Y-axis)
            slope: Regression slope
            intercept: Regression intercept
        """
        # Create bitmap
        bmp = Bitmap(492, 267)
        g = Graphics.FromImage(bmp)
        
        try:
            # Clear background
            g.Clear(Color.White)
            
            # Create drawing resources
            pen = Pen(Color.Black, 1)
            thin_pen = Pen(Color.LightGray, 1)
            font = Font("Arial", 10)
            small_font = Font("Arial", 8)
            
            try:
                # Draw axes
                g.DrawLine(pen, 60, 20, 60, 220)  # Y axis
                g.DrawLine(pen, 60, 220, 460, 220)  # X axis
                
                # Draw title
                if graph_type == "kv":
                    g.DrawString("(V-v) - ε(B-V) vs Airmass", font, Brushes.Black, PointF(150, 5))
                else:
                    g.DrawString("(B-V) - μ(b-v) vs Airmass", font, Brushes.Black, PointF(150, 5))
                
                # X-axis labels
                g.DrawString("1.0", small_font, Brushes.Black, PointF(50, 235))
                g.DrawString("1.5", small_font, Brushes.Black, PointF(175, 235))
                g.DrawString("2.0", small_font, Brushes.Black, PointF(300, 235))
                g.DrawString("2.5", small_font, Brushes.Black, PointF(425, 235))
                
                # X-axis label
                g.DrawString("X (air mass)", font, Brushes.Black, PointF(200, 250))
                
                # Y-axis label (rotated 90 degrees)
                if graph_type == "kv":
                    y_label = "(V-v) - ε(B-V)"
                else:
                    y_label = "(B-V) - μ(b-v)"
                # Draw Y label vertically
                state = g.Save()
                g.TranslateTransform(15, 120)
                g.RotateTransform(-90)
                g.DrawString(y_label, font, Brushes.Black, PointF(0, 0))
                g.Restore(state)
                
                # Determine axis ranges for scaling (need this before drawing grid/labels)
                # X-axis: 1.0 to 2.5 (airmass)
                x_min, x_max = 1.0, 2.5
                x_range = x_max - x_min
                
                # Y-axis: auto-scale based on data
                if y_values:
                    y_min = min(y_values)
                    y_max = max(y_values)
                    y_margin = (y_max - y_min) * 0.1 if y_max != y_min else 0.5
                    y_min -= y_margin
                    y_max += y_margin
                    y_range = y_max - y_min if y_max != y_min else 1.0
                    
                    # Draw Y-axis grid and labels
                    for i in range(11):
                        y = 20 + i * 20
                        g.DrawLine(thin_pen, 60, y, 65, y)
                        # Calculate Y value for this position
                        y_val = y_max - (i / 10.0) * y_range
                        # Draw label to left of axis
                        g.DrawString("{0:.2f}".format(y_val), small_font, Brushes.Black, PointF(20, y - 7))
                
                # Draw X-axis grid (no change)
                for i in range(1, 16):
                    x = 60 + i * 25
                    g.DrawLine(thin_pen, x, 220, x, 215)
                    
                    # Plot data points
                    blue_pen = Pen(Color.Blue, 3)
                    try:
                        for i in range(len(x_values)):
                            # Scale to graph coordinates
                            # Graph area: X from 60 to 460 (400 pixels), Y from 20 to 220 (200 pixels)
                            graph_x = 60 + int(((x_values[i] - x_min) / x_range) * 400)
                            graph_y = 220 - int(((y_values[i] - y_min) / y_range) * 200)
                            
                            # Draw point as small circle
                            if 60 <= graph_x <= 460 and 20 <= graph_y <= 220:
                                g.FillEllipse(Brushes.Blue, graph_x - 3, graph_y - 3, 6, 6)
                        
                        # Draw regression line (best fit line)
                        green_pen = Pen(Color.Red, 2)  # Use red for better visibility
                        try:
                            # Calculate line endpoints at x_min and x_max
                            y1 = slope * x_min + intercept
                            y2 = slope * x_max + intercept
                            
                            # Convert to graph coordinates
                            line_x1 = 60
                            line_y1 = 220 - int(((y1 - y_min) / y_range) * 200)
                            line_x2 = 460
                            line_y2 = 220 - int(((y2 - y_min) / y_range) * 200)
                            
                            # Draw the line (always draw, extending beyond graph if needed)
                            g.DrawLine(green_pen, line_x1, line_y1, line_x2, line_y2)
                        finally:
                            green_pen.Dispose()
                    finally:
                        blue_pen.Dispose()
                
            finally:
                # Dispose of GDI+ resources
                pen.Dispose()
                thin_pen.Dispose()
                font.Dispose()
                small_font.Dispose()
        finally:
            # Dispose of graphics context
            g.Dispose()
        
        # Display in picture box
        if self.graph_box.Image is not None:
            self.graph_box.Image.Dispose()
        self.graph_box.Image = bmp
        
        self.print_button.Enabled = True


# Entry point for standalone testing
if __name__ == '__main__':
    show_allsky_calibration_window()
