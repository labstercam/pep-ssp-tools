"""
Night Mode Utilities
====================

Provides red night vision mode for SSP controls.
Placeholder implementation - to be enhanced with occultation-manager code.

Author: pep-ssp-tools project
Version: 0.1.2
"""

import clr
clr.AddReference('System.Drawing')
from System.Drawing import Color


class NightMode:
    """Night mode color manager."""
    
    # Day mode colors
    DAY_BACKGROUND = Color.White
    DAY_FOREGROUND = Color.Black
    DAY_CONTROL_BG = Color.FromArgb(240, 240, 240)
    
    # Night mode colors (SharpCap-style orange/amber on grayscale)
    NIGHT_BACKGROUND = Color.FromArgb(25, 25, 25)       # Very dark gray
    NIGHT_FOREGROUND = Color.FromArgb(255, 140, 0)     # Orange/amber text
    NIGHT_CONTROL_BG = Color.FromArgb(55, 55, 55)      # Medium dark gray for controls
    NIGHT_BUTTON_BG = Color.FromArgb(50, 50, 50)       # Slightly lighter gray for buttons
    
    def __init__(self):
        """Initialize night mode manager."""
        self.is_night_mode = False
    
    def set_night_mode(self, enabled):
        """Enable or disable night mode."""
        self.is_night_mode = enabled
    
    def get_background(self):
        """Get appropriate background color."""
        return self.NIGHT_BACKGROUND if self.is_night_mode else self.DAY_BACKGROUND
    
    def get_foreground(self):
        """Get appropriate foreground color."""
        return self.NIGHT_FOREGROUND if self.is_night_mode else self.DAY_FOREGROUND
    
    def get_control_background(self):
        """Get appropriate control background color."""
        return self.NIGHT_CONTROL_BG if self.is_night_mode else self.DAY_CONTROL_BG
    
    def get_button_background(self):
        """Get appropriate button background color."""
        return self.NIGHT_BUTTON_BG if self.is_night_mode else self.DAY_CONTROL_BG
    
    def apply_to_form(self, form):
        """Apply night mode colors to a form and all its controls."""
        form.BackColor = self.get_background()
        form.ForeColor = self.get_foreground()
        
        # Apply to main menu strip if present
        if hasattr(form, 'MainMenuStrip') and form.MainMenuStrip is not None:
            self._apply_to_menu(form.MainMenuStrip)
        
        self._apply_to_controls(form.Controls)
    
    def _apply_to_controls(self, controls):
        """Recursively apply colors to all controls."""
        for control in controls:
            control_type = control.GetType().Name
            
            # Special handling for labels - use form background
            if control_type == 'Label':
                control.BackColor = self.get_background()
                control.ForeColor = self.get_foreground()
            # Special handling for buttons
            elif control_type == 'Button':
                control.BackColor = self.get_button_background()
                control.ForeColor = self.get_foreground()
            # Special handling for ComboBox - needs FlatStyle set
            elif control_type == 'ComboBox':
                control.BackColor = self.get_control_background()
                control.ForeColor = self.get_foreground()
                # Set FlatStyle to Flat for proper color rendering
                from System.Windows.Forms import FlatStyle
                control.FlatStyle = FlatStyle.Flat
            # Special handling for DataGridView
            elif control_type == 'DataGridView':
                control.BackgroundColor = self.get_control_background()
                control.ForeColor = self.get_foreground()
                control.DefaultCellStyle.BackColor = self.get_control_background()
                control.DefaultCellStyle.ForeColor = self.get_foreground()
                control.ColumnHeadersDefaultCellStyle.BackColor = self.get_background()
                control.ColumnHeadersDefaultCellStyle.ForeColor = self.get_foreground()
                control.AlternatingRowsDefaultCellStyle.BackColor = self.get_background()
                control.AlternatingRowsDefaultCellStyle.ForeColor = self.get_foreground()
                control.GridColor = self.get_foreground()
                if hasattr(control, 'EnableHeadersVisualStyles'):
                    control.EnableHeadersVisualStyles = False
            # All other controls use control background
            else:
                control.BackColor = self.get_control_background()
                control.ForeColor = self.get_foreground()
            
            # Recursively apply to child controls
            if control.Controls.Count > 0:
                self._apply_to_controls(control.Controls)
    
    def _apply_to_menu(self, menu_strip):
        """Apply night mode colors to menu strip and all menu items."""
        # Apply to the menu strip itself
        menu_strip.BackColor = self.get_control_background()
        menu_strip.ForeColor = self.get_foreground()
        
        # Apply to all top-level menu items and their children
        for item in menu_strip.Items:
            self._apply_to_menu_item(item)
    
    def _apply_to_menu_item(self, menu_item):
        """Recursively apply night mode colors to a menu item and its children."""
        # Check if the item has color properties (ToolStripSeparator doesn't)
        if hasattr(menu_item, 'BackColor') and hasattr(menu_item, 'ForeColor'):
            menu_item.BackColor = self.get_control_background()
            menu_item.ForeColor = self.get_foreground()
        
        # Recursively apply to dropdown items
        if hasattr(menu_item, 'DropDownItems') and menu_item.DropDownItems.Count > 0:
            for child_item in menu_item.DropDownItems:
                self._apply_to_menu_item(child_item)
