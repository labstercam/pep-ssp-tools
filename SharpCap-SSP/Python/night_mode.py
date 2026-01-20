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
    
    # Night mode colors (red theme for dark adaptation)
    NIGHT_BACKGROUND = Color.FromArgb(40, 0, 0)
    NIGHT_FOREGROUND = Color.FromArgb(255, 80, 80)
    NIGHT_CONTROL_BG = Color.FromArgb(60, 0, 0)
    NIGHT_BUTTON_BG = Color.FromArgb(80, 0, 0)
    
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
        self._apply_to_controls(form.Controls)
    
    def _apply_to_controls(self, controls):
        """Recursively apply colors to all controls."""
        for control in controls:
            # Apply to control itself
            control.BackColor = self.get_control_background()
            control.ForeColor = self.get_foreground()
            
            # Special handling for buttons
            if control.GetType().Name == 'Button':
                control.BackColor = self.get_button_background()
            
            # Recursively apply to child controls
            if control.Controls.Count > 0:
                self._apply_to_controls(control.Controls)
