"""
SSP Dialog Windows
==================

Dialog windows for configuration and data entry.

Author: pep-ssp-tools project
Version: 0.1.0
"""

import clr
clr.AddReference('System.Windows.Forms')
clr.AddReference('System.Drawing')
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
