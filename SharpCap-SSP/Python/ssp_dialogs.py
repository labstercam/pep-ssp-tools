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
