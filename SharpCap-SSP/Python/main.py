"""
SharpCap-SSP Main Module
=========================

Main entry point for SharpCap-SSP photometer control tool.
Provides integration between Optec SSP photometers and SharpCap software.

Author: pep-ssp-tools project
Version: 0.1.0
Date: January 2026
"""

# IronPython CLR imports for .NET integration
import clr
import sys

# Add the script directory to Python path for module imports
import System
script_dir = System.IO.Path.GetDirectoryName(__file__) if '__file__' in dir() else System.IO.Directory.GetCurrentDirectory()
if script_dir not in sys.path:
    sys.path.append(script_dir)

# Add references to .NET assemblies
clr.AddReference('System')
clr.AddReference('System.Windows.Forms')
clr.AddReference('System.Drawing')

# Try to add System.IO.Ports - required for serial communication
# In IronPython 3.4 (.NET Core/5+), this requires the System.IO.Ports NuGet package
SERIAL_PORTS_AVAILABLE = False
try:
    # First try to load from GAC or standard locations
    clr.AddReference('System.IO.Ports')
    SERIAL_PORTS_AVAILABLE = True
except:
    # Try to load from local directory (if installed with install.ps1)
    try:
        import os
        local_dll = os.path.join(script_dir, 'System.IO.Ports.dll')
        if os.path.exists(local_dll):
            clr.AddReferenceToFileAndPath(local_dll)
            SERIAL_PORTS_AVAILABLE = True
        else:
            raise Exception("DLL not found")
    except:
        print("WARNING: System.IO.Ports not available.")
        print("Run install.ps1 to download the required DLL.")
        print("Or run from SharpCap which includes this assembly.")
        print("Serial port functionality will not work.\n")

# Import .NET namespaces
from System import *
from System.Windows.Forms import *
from System.Drawing import *

# Import serial port classes if available
if SERIAL_PORTS_AVAILABLE:
    from System.IO.Ports import SerialPort, Parity, StopBits
else:
    SerialPort = None
    Parity = None
    StopBits = None

# Import SharpCap if available
try:
    import SharpCap
    SHARPCAP_AVAILABLE = True
    SHARPCAP_VERSION = "Detected"
except ImportError:
    SHARPCAP_AVAILABLE = False
    SHARPCAP_VERSION = "N/A"
    print("Warning: SharpCap module not available. Running in standalone mode.")


class SSPMainWindow(Form):
    """Main application window for SharpCap-SSP photometer control."""
    
    def __init__(self):
        """Initialize the main window."""
        self.Text = "SharpCap-SSP Photometer Control v0.1.0"
        self.Width = 600
        self.Height = 500
        self.StartPosition = FormStartPosition.CenterScreen
        self.FormBorderStyle = FormBorderStyle.FixedDialog
        self.MaximizeBox = False
        
        # Initialize components
        self._setup_ui()
        
    def _setup_ui(self):
        """Set up the user interface components."""
        
        # Main panel for layout
        main_panel = Panel()
        main_panel.Dock = DockStyle.Fill
        main_panel.Padding = Padding(10)
        
        # Title label
        title_label = Label()
        title_label.Text = "SharpCap-SSP Photometer Control"
        title_label.Font = Font("Arial", 16, FontStyle.Bold)
        title_label.Location = Point(10, 10)
        title_label.Size = Size(560, 30)
        title_label.TextAlign = ContentAlignment.MiddleCenter
        main_panel.Controls.Add(title_label)
        
        # Description text box (read-only)
        description = TextBox()
        description.Multiline = True
        description.ReadOnly = True
        description.Location = Point(10, 50)
        description.Size = Size(560, 200)
        description.ScrollBars = ScrollBars.Vertical
        description.BackColor = SystemColors.Control
        description.Font = Font("Consolas", 9)
        
        description_text = """ABOUT SHARPCAP-SSP
==================

SharpCap-SSP is a Python-based integration tool for controlling Optec SSP 
single-channel photometers directly within SharpCap astronomical software.

PURPOSE:
This tool replicates the core data collection functionality of the original 
SSPDataq software, enabling:

• Serial COM port communication with SSP-3a and SSP-5a photometers
• Multiple data acquisition modes (Slow, Fast, Very Fast)
• Real-time photometric data collection synchronized with imaging
• Output compatible with existing photometry reduction pipelines

SUPPORTED HARDWARE:
• Optec SSP-3a: Single-channel photometer with PMT detector
• Optec SSP-5a: Enhanced single-channel photometer

SERIAL COMMUNICATION:
• Baud Rate: 19200 bps, 8 data bits, No parity, 1 stop bit
• Command protocol: ASCII text-based SSP command set
• Modes: Trial, Slow (1-4 readings), Fast (100-5000 readings)

DATA COLLECTION MODES:
• Slow Mode: Scientific photometry with 1, 5, or 10-second integrations
• Fast Mode: Rapid photometry for variable phenomena (0.05 to 10 seconds)
• Very Fast Mode: Ultra-rapid 20ms integrations (SSP-5 only)

INTEGRATION:
• Works within SharpCap scripting environment (IronPython)
• Coordinates with SharpCap's telescope and camera control
• Saves data in standard .raw format for reduction software

DEVELOPMENT STATUS:
Version 0.1.0 (Alpha) - User interface framework
Planned: Serial communication, data acquisition, file management

For more information, see the SSPDataq Software Overview document in:
../SSPDataq/Analysis/SSPDataq_Software_Overview.md
"""
        description.Text = description_text
        main_panel.Controls.Add(description)
        
        # Status group box
        status_group = GroupBox()
        status_group.Text = "System Status"
        status_group.Location = Point(10, 260)
        status_group.Size = Size(560, 100)
        
        # SharpCap status
        sharpcap_label = Label()
        sharpcap_label.Text = "SharpCap:"
        sharpcap_label.Location = Point(10, 25)
        sharpcap_label.Size = Size(100, 20)
        status_group.Controls.Add(sharpcap_label)
        
        sharpcap_status = Label()
        if SHARPCAP_AVAILABLE:
            sharpcap_status.Text = "Available - Integrated Mode"
            sharpcap_status.ForeColor = Color.Green
        else:
            sharpcap_status.Text = "Not Available (Standalone Mode)"
            sharpcap_status.ForeColor = Color.Orange
        sharpcap_status.Location = Point(110, 25)
        sharpcap_status.Size = Size(430, 20)
        status_group.Controls.Add(sharpcap_status)
        
        # COM Port status
        com_label = Label()
        com_label.Text = "COM Ports:"
        com_label.Location = Point(10, 50)
        com_label.Size = Size(100, 20)
        status_group.Controls.Add(com_label)
        
        com_status = Label()
        if SERIAL_PORTS_AVAILABLE and SerialPort is not None:
            available_ports = SerialPort.GetPortNames()
            if len(available_ports) > 0:
                com_status.Text = "Available: " + ", ".join(available_ports)
                com_status.ForeColor = Color.Green
            else:
                com_status.Text = "No COM ports detected"
                com_status.ForeColor = Color.Red
        else:
            com_status.Text = "Serial ports not available (missing System.IO.Ports)"
            com_status.ForeColor = Color.Orange
        com_status.Location = Point(110, 50)
        com_status.Size = Size(430, 20)
        status_group.Controls.Add(com_status)
        
        # Module status
        module_label = Label()
        module_label.Text = "Modules:"
        module_label.Location = Point(10, 75)
        module_label.Size = Size(100, 20)
        status_group.Controls.Add(module_label)
        
        module_status = Label()
        module_status.Text = "UI Framework Loaded (Data collection not yet implemented)"
        module_status.ForeColor = Color.Blue
        module_status.Location = Point(110, 75)
        module_status.Size = Size(430, 20)
        status_group.Controls.Add(module_status)
        
        main_panel.Controls.Add(status_group)
        
        # Button panel
        button_panel = Panel()
        button_panel.Location = Point(10, 370)
        button_panel.Size = Size(560, 50)
        
        # Launch SSPDataq3 button
        launch_button = Button()
        launch_button.Text = "Launch SSPDataq3"
        launch_button.Size = Size(130, 30)
        launch_button.Location = Point(160, 10)
        launch_button.Click += self._on_launch_dataaq
        button_panel.Controls.Add(launch_button)
        
        # Close button
        close_button = Button()
        close_button.Text = "Close"
        close_button.Size = Size(100, 30)
        close_button.Location = Point(300, 10)
        close_button.Click += self._on_close_click
        button_panel.Controls.Add(close_button)
        
        main_panel.Controls.Add(button_panel)
        
        # Add main panel to form
        self.Controls.Add(main_panel)
        
        # Footer label
        footer_label = Label()
        footer_label.Text = "Part of the pep-ssp-tools project | Alpha Development Version"
        footer_label.Location = Point(10, 430)
        footer_label.Size = Size(560, 20)
        footer_label.TextAlign = ContentAlignment.MiddleCenter
        footer_label.ForeColor = Color.Gray
        footer_label.Font = Font("Arial", 8, FontStyle.Italic)
        main_panel.Controls.Add(footer_label)
    
    def _on_launch_dataaq(self, sender, event):
        """Handle launch data acquisition button click."""
        try:
            # Ensure module path is set
            import sys
            script_dir = System.IO.Path.GetDirectoryName(__file__) if '__file__' in dir() else System.IO.Directory.GetCurrentDirectory()
            if script_dir not in sys.path:
                sys.path.append(script_dir)
            
            import ssp_dataaq
            ssp_dataaq.show_data_acquisition_window()
            
            # Minimize the launcher window
            self.WindowState = FormWindowState.Minimized
        except Exception as e:
            import traceback
            error_detail = traceback.format_exc()
            MessageBox.Show("Error launching data acquisition window:\n\n" + str(e) + "\n\nDetails:\n" + error_detail, 
                          "Error", MessageBoxButtons.OK, MessageBoxIcon.Error)
        
    def _on_close_click(self, sender, event):
        """Handle close button click."""
        self.Close()


def main():
    """Main entry point for SharpCap-SSP."""
    print("=" * 60)
    print("SharpCap-SSP Photometer Control v0.1.0")
    print("=" * 60)
    print("")
    
    if SHARPCAP_AVAILABLE:
        print("SharpCap detected - Running in integrated mode")
    else:
        print("SharpCap not detected - Running in standalone mode for testing")
    
    print("")
    print("Initializing user interface...")
    
    # Create and show the main window
    Application.EnableVisualStyles()
    window = SSPMainWindow()
    Application.Run(window)
    
    print("SharpCap-SSP closed.")


# Entry point
if __name__ == '__main__':
    main()
