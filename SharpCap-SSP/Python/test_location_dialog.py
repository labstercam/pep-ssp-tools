"""
Test Observer Location Dialog
==============================

Simple test to verify the LocationDialog works correctly with lookup features.
"""

import clr
import sys
import System

# Add script directory to path
script_dir = System.IO.Path.GetDirectoryName(__file__) if '__file__' in dir() else System.IO.Directory.GetCurrentDirectory()
if script_dir not in sys.path:
    sys.path.append(script_dir)

clr.AddReference('System.Windows.Forms')
from System.Windows.Forms import Application, DialogResult

import ssp_dialogs
import ssp_config

def test_location_dialog():
    """Test the LocationDialog with lookup features."""
    print("Testing Enhanced Observer Location Dialog")
    print("=" * 50)
    
    # Load current config
    config = ssp_config.SSPConfig()
    
    # Get current values
    lat = config.get('observer_latitude', 0.0)
    lon = config.get('observer_longitude', 0.0)
    elev = config.get('observer_elevation', 0.0)
    
    print("\nCurrent location from config:")
    print("  Latitude:  {0:.6f}".format(lat))
    print("  Longitude: {0:.6f}".format(lon))
    print("  Elevation: {0:.1f} m".format(elev))
    
    print("\nDialog Workflow:")
    print("  Step 1: Click 'Open in Google Maps' link")
    print("          - If coords are 0,0, opens at your location")
    print("          - If coords entered, opens at those coordinates")
    print("  ")
    print("  Step 2: In Google Maps:")
    print("          a. Drop a pin at your observing location")
    print("          b. Right-click the pin and select coordinates (top of list)")
    print("          c. Coordinates are automatically copied to clipboard")
    print("  ")
    print("  Step 3: Return to dialog and click 'Paste Coordinates'")
    print("          - Latitude and longitude fields will auto-populate")
    print("  ")
    print("  Step 4: Click 'Lookup Elevation' to get elevation from coordinates")
    print("  ")
    print("  Step 5: Click 'Lookup City' to get city/town name from coordinates")
    print("  ")
    print("  Step 6: Click OK to save location")
    print("")
    print("Alternative: Enter coordinates manually in the lat/lon fields")
    
    # Show dialog
    print("\nOpening location dialog...")
    dialog = ssp_dialogs.LocationDialog(lat, lon, elev)
    result = dialog.ShowDialog()
    
    if result == DialogResult.OK:
        print("\nUser clicked OK")
        print("New location:")
        print("  Latitude:  {0:.6f}".format(dialog.latitude))
        print("  Longitude: {0:.6f}".format(dialog.longitude))
        print("  Elevation: {0:.1f} m".format(dialog.elevation))
        
        # Save to config
        config.set('observer_latitude', dialog.latitude)
        config.set('observer_longitude', dialog.longitude)
        config.set('observer_elevation', dialog.elevation)
        config.save()
        
        print("\nLocation saved to config file")
        
        # Format for display
        lat_dir = "N" if dialog.latitude >= 0 else "S"
        lon_dir = "E" if dialog.longitude >= 0 else "W"
        lat_str = "{0:.4f}{1}".format(abs(dialog.latitude), lat_dir)
        lon_str = "{0:.4f}{1}".format(abs(dialog.longitude), lon_dir)
        
        print("Formatted: {0}, {1}".format(lat_str, lon_str))
    else:
        print("\nUser cancelled")

if __name__ == '__main__':
    test_location_dialog()
    print("\nTest complete!")
