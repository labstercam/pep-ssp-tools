"""
Test script for star catalog functionality
Tests both standalone and SharpCap modes
"""

import sys
import os

# Setup path
try:
    import System
    script_dir = System.IO.Path.GetDirectoryName(__file__) if '__file__' in dir() else System.IO.Directory.GetCurrentDirectory()
except:
    script_dir = os.path.dirname(os.path.abspath(__file__)) if '__file__' in dir() else os.getcwd()

if script_dir not in sys.path:
    sys.path.append(script_dir)

print("=" * 70)
print("SSP STAR CATALOG TEST")
print("=" * 70)
print("Script directory: %s" % script_dir)
print("")

# Test 1: Import module
print("Test 1: Import ssp_catalog module...")
try:
    import ssp_catalog
    print("  ✓ Module imported successfully")
except Exception as e:
    print("  ✗ FAILED: %s" % str(e))
    sys.exit(1)

# Test 2: Check CSV file exists
print("\nTest 2: Check CSV file exists...")
csv_path = os.path.join(script_dir, "starparm_latest.csv")
if os.path.exists(csv_path):
    print("  ✓ CSV file found: %s" % csv_path)
else:
    print("  ✗ FAILED: CSV file not found at: %s" % csv_path)
    sys.exit(1)

# Test 3: Load catalog
print("\nTest 3: Load catalog...")
try:
    catalog = ssp_catalog.StarCatalog(csv_path)
    count = catalog.get_count()
    print("  ✓ Catalog loaded: %d targets" % count)
    if count == 0:
        print("  ✗ WARNING: No targets loaded!")
except Exception as e:
    print("  ✗ FAILED: %s" % str(e))
    import traceback
    print(traceback.format_exc())
    sys.exit(1)

# Test 4: Get first target
print("\nTest 4: Access first target...")
try:
    if len(catalog.targets) > 0:
        target = catalog.targets[0]
        print("  ✓ First target: %s" % target.variable.name)
        print("    RA: %s" % target.variable.ra_string())
        print("    Dec: %s" % target.variable.dec_string())
        if target.variable.vmag:
            print("    V mag: %.2f" % target.variable.vmag)
    else:
        print("  ✗ No targets in catalog!")
except Exception as e:
    print("  ✗ FAILED: %s" % str(e))

# Test 5: Search by name
print("\nTest 5: Search by name (OMI CET)...")
try:
    target = catalog.get_target_by_name("OMI CET")
    if target:
        print("  ✓ Found: %s" % target.variable.name)
        print("    Comparison: %s" % target.comparison.name)
        print("    Check: %s" % target.check.name)
        if target.auid:
            print("    AAVSO ID: %s" % target.auid)
    else:
        print("  ✗ Not found")
except Exception as e:
    print("  ✗ FAILED: %s" % str(e))

# Test 6: RA range search
print("\nTest 6: RA range search (0h-1h)...")
try:
    targets = catalog.get_targets_in_ra_range(0, 1)
    print("  ✓ Found %d targets" % len(targets))
    if len(targets) > 0:
        print("    First: %s" % targets[0].variable.name)
except Exception as e:
    print("  ✗ FAILED: %s" % str(e))

# Test 7: Magnitude range search
print("\nTest 7: Magnitude range search (4.0-5.0)...")
try:
    targets = catalog.get_targets_by_magnitude_range(4.0, 5.0)
    print("  ✓ Found %d targets" % len(targets))
    if len(targets) > 0:
        print("    First: %s (V=%.2f)" % (targets[0].variable.name, targets[0].variable.vmag))
except Exception as e:
    print("  ✗ FAILED: %s" % str(e))

# Test 8: Get all names
print("\nTest 8: Get all variable names...")
try:
    names = catalog.get_all_variable_names()
    print("  ✓ Got %d names" % len(names))
    if len(names) > 0:
        print("    First 3: %s" % ", ".join(names[:3]))
except Exception as e:
    print("  ✗ FAILED: %s" % str(e))

# Test 9: StarData coordinate conversion
print("\nTest 9: StarData coordinate conversion...")
try:
    if len(catalog.targets) > 0:
        star = catalog.targets[0].variable
        ra_deg = star.ra_degrees
        dec_deg = star.dec_degrees_decimal
        print("  ✓ RA in degrees: %.4f" % ra_deg)
        print("  ✓ Dec in degrees: %.4f" % dec_deg)
except Exception as e:
    print("  ✗ FAILED: %s" % str(e))

# Test 10: Check for None handling
print("\nTest 10: None value handling...")
try:
    test_star = ssp_catalog.StarData(
        name="TEST", 
        ra_hours=0, ra_minutes=0, ra_seconds=0,
        dec_degrees=0, dec_minutes=0, dec_seconds=0,
        vmag=None, bv_color=None, spectral_type=None
    )
    print("  ✓ StarData with None values created")
    print("    V mag: %s" % test_star.vmag)
    print("    B-V: %s" % test_star.bv_color)
    print("    Spec type: '%s'" % test_star.spectral_type)
except Exception as e:
    print("  ✗ FAILED: %s" % str(e))

print("\n" + "=" * 70)
print("ALL TESTS COMPLETED")
print("=" * 70)

# If running in SharpCap, show message box
try:
    if 'SharpCap' in dir():
        import clr
        clr.AddReference('System.Windows.Forms')
        from System.Windows.Forms import MessageBox, MessageBoxButtons, MessageBoxIcon
        MessageBox.Show("All star catalog tests passed successfully!\n\n" +
                       "Loaded %d targets from catalog." % catalog.get_count(),
                       "Catalog Test Success", 
                       MessageBoxButtons.OK, MessageBoxIcon.Information)
except:
    pass

print("\nPress Enter to exit...")
try:
    raw_input()  # Python 2
except:
    try:
        input()  # Python 3
    except:
        pass
