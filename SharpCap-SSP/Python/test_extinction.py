"""
Test script for ssp_extinction module
Tests star catalog loading, airmass calculations, and star visibility.
"""

import os
import sys
from datetime import datetime, timezone

# Change to script directory to find CSV file and module
script_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(script_dir)
print("Working directory: {0}".format(os.getcwd()))

# Import the extinction module
from ssp_extinction import (
    ExtinctionCatalog,
    AirmassCalculator,
    calculate_star_visibility
)


def main():
    """Run extinction module tests."""
    
    # Load catalog
    print("\n" + "="*60)
    print("EXTINCTION MODULE TEST")
    print("="*60)
    
    catalog = ExtinctionCatalog()
    count = catalog.load_from_csv("first_order_extinction_stars.csv")
    print("\nLoaded {0} stars".format(count))
    
    # Show first 5 stars
    print("\nFirst 5 stars:")
    for star in catalog.get_all_stars()[:5]:
        print("  {0}".format(star))
    
    # Test star lookup
    print("\nLookup test:")
    test_star = catalog.get_star("HD 34968")
    if test_star:
        print("  Found: {0}".format(test_star))
    else:
        print("  Star not found")
    
    # Test filtering
    print("\nBright stars (V < 5.0):")
    bright_stars = catalog.filter_by_magnitude(max_mag=5.0)
    print("  Found {0} bright stars".format(len(bright_stars)))
    for star in bright_stars[:3]:
        print("    {0}".format(star))
    
    # Test airmass calculation
    print("\nAirmass calculation test:")
    print("  Location: S36.8485deg, E174.7633deg (Auckland, NZ)")
    calc = AirmassCalculator(latitude=-36.8485, longitude=174.7633)
    
    test_time = datetime.now(timezone.utc)
    print("  Time: {0}".format(test_time.strftime('%Y-%m-%d %H:%M:%S UTC')))
    
    # Find stars with airmass between 1.0 and 2.5
    print("\nFinding observable stars (airmass 1.0-2.5):")
    observable_stars = []
    for star in catalog.get_all_stars():
        obs = calculate_star_visibility(star, calc, test_time, max_airmass=2.5)
        if obs.is_observable and obs.airmass >= 1.0:
            observable_stars.append(obs)
    
    # Sort by airmass (lowest first)
    observable_stars.sort(key=lambda x: x.airmass)
    
    print("  Found {0} observable stars".format(len(observable_stars)))
    
    if len(observable_stars) > 0:
        print("\n5 LOWEST airmass stars:")
        for obs in observable_stars[:5]:
            print("  {0}".format(obs))
        
        print("\n5 HIGHEST airmass stars (in 1.0-2.5 range):")
        for obs in observable_stars[-5:]:
            print("  {0}".format(obs))
    else:
        print("\n  No stars observable in the 1.0-2.5 airmass range at this time")
    
    print("\n" + "="*60)
    print("TEST COMPLETE")
    print("="*60)


if __name__ == "__main__":
    main()
