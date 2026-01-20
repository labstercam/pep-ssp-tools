"""
Test Filter Bar Setup Dialog
=============================

Standalone test for the FilterBarSetupDialog.

Usage:
    ipy test_filter_dialog.py
"""

import clr
import sys
import os

# Add current directory to path
script_dir = os.path.dirname(os.path.abspath(__file__)) if '__file__' in dir() else os.getcwd()
if script_dir not in sys.path:
    sys.path.append(script_dir)

clr.AddReference('System.Windows.Forms')
clr.AddReference('System.Drawing')
from System.Windows.Forms import *
from System.Drawing import *

# Import the dialog
import ssp_dialogs

def test_filter_dialog():
    """Test the filter bar setup dialog."""
    print("Testing Filter Bar Setup Dialog")
    print("=" * 50)
    
    # Test data
    filter_bars = [
        ['U', 'B', 'V', 'R', 'I', 'Dark'],  # Bar 1
        ['u', 'g', 'r', 'i', 'z', 'Y'],     # Bar 2
        ['f13', 'f14', 'f15', 'f16', 'f17', 'f18']  # Bar 3
    ]
    active_bar = 1
    
    # Show dialog
    dialog = ssp_dialogs.FilterBarSetupDialog(filter_bars, active_bar)
    result = dialog.ShowDialog()
    
    if result == DialogResult.OK:
        print("\nDialog completed successfully!")
        print("\nActive Bar: %d" % dialog.active_bar)
        print("\nFilter Bars:")
        for i, bar in enumerate(dialog.filter_bars):
            print("  Bar %d: %s" % (i+1, ', '.join(bar)))
        print("\nModified: %s" % dialog.modified)
    else:
        print("\nDialog cancelled")
    
    print("\nTest complete.")

if __name__ == '__main__':
    Application.EnableVisualStyles()
    test_filter_dialog()
