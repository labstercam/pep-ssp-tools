"""
SSP Quick Test
==============

Quick interactive test for SSP photometer connection.
Can be run from SharpCap IronPython console or standalone.

Author: pep-ssp-tools project
Version: 0.1.0
"""

import clr
clr.AddReference('System')
clr.AddReference('System.Windows.Forms')
clr.AddReference('System.Drawing')
clr.AddReference('System.IO')
from System import DateTime
from System.Windows.Forms import *
from System.Drawing import *
import System
import sys

# Ensure module path is accessible
script_dir = System.IO.Path.GetDirectoryName(__file__) if '__file__' in dir() else System.IO.Directory.GetCurrentDirectory()
if script_dir not in sys.path:
    sys.path.append(script_dir)

import ssp_comm


class SSPQuickTestForm(Form):
    """Quick test form for SSP photometer."""
    
    def __init__(self):
        """Initialize test form."""
        self.comm = ssp_comm.SSPCommunicator()
        
        # Setup form
        self.Text = "SSP Quick Test"
        self.Width = 500
        self.Height = 500
        self.StartPosition = FormStartPosition.CenterScreen
        
        # COM Port selection
        y = 10
        lbl = Label()
        lbl.Text = "COM Port:"
        lbl.Location = Point(10, y)
        lbl.Size = Size(80, 20)
        self.Controls.Add(lbl)
        
        self.com_combo = ComboBox()
        self.com_combo.Location = Point(100, y)
        self.com_combo.Size = Size(80, 25)
        for i in range(1, 20):
            self.com_combo.Items.Add(str(i))
        self.com_combo.SelectedIndex = 4  # COM5 default
        self.Controls.Add(self.com_combo)
        
        # Connect button
        self.connect_btn = Button()
        self.connect_btn.Text = "Connect"
        self.connect_btn.Location = Point(190, y)
        self.connect_btn.Size = Size(80, 25)
        self.connect_btn.Click += self._on_connect
        self.Controls.Add(self.connect_btn)
        
        # Disconnect button
        self.disconnect_btn = Button()
        self.disconnect_btn.Text = "Disconnect"
        self.disconnect_btn.Location = Point(280, y)
        self.disconnect_btn.Size = Size(90, 25)
        self.disconnect_btn.Click += self._on_disconnect
        self.disconnect_btn.Enabled = False
        self.Controls.Add(self.disconnect_btn)
        
        y += 35
        
        # Integration time
        lbl = Label()
        lbl.Text = "Integration (sec):"
        lbl.Location = Point(10, y)
        lbl.Size = Size(120, 20)
        self.Controls.Add(lbl)
        
        self.integ_combo = ComboBox()
        self.integ_combo.Location = Point(140, y)
        self.integ_combo.Size = Size(80, 25)
        self.integ_combo.Items.Add("1")
        self.integ_combo.Items.Add("5")
        self.integ_combo.Items.Add("10")
        self.integ_combo.SelectedIndex = 0
        self.Controls.Add(self.integ_combo)
        
        # Get Count button
        self.count_btn = Button()
        self.count_btn.Text = "Get Count"
        self.count_btn.Location = Point(230, y)
        self.count_btn.Size = Size(90, 25)
        self.count_btn.Click += self._on_get_count
        self.count_btn.Enabled = False
        self.Controls.Add(self.count_btn)
        
        y += 35
        
        # Gain control
        lbl = Label()
        lbl.Text = "Gain:"
        lbl.Location = Point(10, y)
        lbl.Size = Size(80, 20)
        self.Controls.Add(lbl)
        
        self.gain_combo = ComboBox()
        self.gain_combo.Location = Point(100, y)
        self.gain_combo.Size = Size(80, 25)
        self.gain_combo.Items.Add("1")
        self.gain_combo.Items.Add("10")
        self.gain_combo.Items.Add("100")
        self.gain_combo.SelectedIndex = 1
        self.Controls.Add(self.gain_combo)
        
        # Set Gain button
        self.gain_btn = Button()
        self.gain_btn.Text = "Set Gain"
        self.gain_btn.Location = Point(190, y)
        self.gain_btn.Size = Size(80, 25)
        self.gain_btn.Click += self._on_set_gain
        self.gain_btn.Enabled = False
        self.Controls.Add(self.gain_btn)
        
        y += 40
        
        # Output textbox
        lbl = Label()
        lbl.Text = "Output:"
        lbl.Location = Point(10, y)
        lbl.Size = Size(80, 20)
        self.Controls.Add(lbl)
        
        y += 25
        
        self.output_text = TextBox()
        self.output_text.Location = Point(10, y)
        self.output_text.Size = Size(460, 320)
        self.output_text.Multiline = True
        self.output_text.ScrollBars = ScrollBars.Vertical
        self.output_text.Font = Font("Courier New", 9)
        self.output_text.ReadOnly = True
        self.Controls.Add(self.output_text)
        
        self._log("SSP Quick Test ready")
        self._log("Select COM port and click Connect")
    
    def _log(self, message):
        """Add message to output."""
        timestamp = DateTime.Now.ToString("HH:mm:ss")
        self.output_text.Text += "[" + timestamp + "] " + message + "\r\n"
        # Scroll to bottom
        self.output_text.SelectionStart = len(self.output_text.Text)
        self.output_text.ScrollToCaret()
    
    def _on_connect(self, sender, event):
        """Handle Connect button."""
        com_port = int(self.com_combo.Text)
        self._log("Connecting to COM" + str(com_port) + "...")
        
        success, message = self.comm.connect(com_port)
        self._log(message)
        
        if success:
            self.connect_btn.Enabled = False
            self.disconnect_btn.Enabled = True
            self.count_btn.Enabled = True
            self.gain_btn.Enabled = True
            self.com_combo.Enabled = False
    
    def _on_disconnect(self, sender, event):
        """Handle Disconnect button."""
        self._log("Disconnecting...")
        
        success, message = self.comm.disconnect()
        self._log(message)
        
        if success:
            self.connect_btn.Enabled = True
            self.disconnect_btn.Enabled = False
            self.count_btn.Enabled = False
            self.gain_btn.Enabled = False
            self.com_combo.Enabled = True
    
    def _on_set_gain(self, sender, event):
        """Handle Set Gain button."""
        gain = int(self.gain_combo.Text)
        self._log("Setting gain to " + str(gain) + "...")
        
        success, message = self.comm.set_gain(gain)
        self._log(message)
    
    def _on_get_count(self, sender, event):
        """Handle Get Count button."""
        integ_sec = int(self.integ_combo.Text)
        integ_ms = integ_sec * 1000
        
        self._log("Getting count with " + str(integ_sec) + " sec integration...")
        self.count_btn.Enabled = False
        self.count_btn.Text = "Wait..."
        
        # Process events to update UI
        Application.DoEvents()
        
        ut_start = DateTime.UtcNow
        success, count, error_msg = self.comm.get_slow_count(integ_ms)
        ut_end = DateTime.UtcNow
        
        elapsed = (ut_end - ut_start).TotalSeconds
        
        if success:
            self._log("Count: " + count + " (elapsed: " + str(round(elapsed, 1)) + " sec)")
        else:
            self._log("ERROR: " + error_msg)
        
        self.count_btn.Enabled = True
        self.count_btn.Text = "Get Count"


def main():
    """Run the quick test form."""
    Application.EnableVisualStyles()
    form = SSPQuickTestForm()
    Application.Run(form)


if __name__ == "__main__":
    main()
