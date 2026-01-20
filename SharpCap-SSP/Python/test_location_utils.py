"""
Test Location Utilities
========================

Test the location and elevation lookup utilities.
"""

import clr
import sys
import System

# Add script directory to path
script_dir = System.IO.Path.GetDirectoryName(__file__) if '__file__' in dir() else System.IO.Directory.GetCurrentDirectory()
if script_dir not in sys.path:
    sys.path.append(script_dir)

import ssp_location_utils

def test_location_lookups():
    """Test the location lookup utilities."""
    print("Testing Location Lookup Utilities")
    print("=" * 60)
    
    # Test coordinates
    test_locations = [
        ("Greenwich, UK", 51.4769, -0.0005),
        ("Auckland, NZ", -36.8485, 174.7633),
        ("Mauna Kea, HI", 19.8207, -155.4681),
        ("Sydney, AU", -33.8688, 151.2093),
    ]
    
    for name, lat, lon in test_locations:
        print("\nTesting: {0} ({1:.4f}, {2:.4f})".format(name, lat, lon))
        print("-" * 60)
        
        # Test location name lookup
        print("Looking up location name...")
        location = ssp_location_utils.get_location_name_from_coordinates(lat, lon)
        if location:
            print("  Result: {0}".format(location))
        else:
            print("  Failed to get location name")
        
        # Test elevation lookup
        print("Looking up elevation...")
        elevation = ssp_location_utils.get_elevation_from_coordinates(lat, lon)
        if elevation is not None:
            print("  Result: {0:.1f} meters".format(elevation))
        else:
            print("  Failed to get elevation")
        
        # Rate limiting - wait between requests
        print("  (Waiting for rate limit...)")
        System.Threading.Thread.Sleep(2000)  # 2 second wait
    
    print("\n" + "=" * 60)
    print("Test complete!")
    print("\nNote: The Nominatim API requires 1 second between requests.")
    print("If lookups fail, check internet connection and API availability.")

if __name__ == '__main__':
    clr.AddReference('System')
    test_location_lookups()
