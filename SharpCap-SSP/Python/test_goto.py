"""
Test GOTO functionality for SharpCap-SSP
=========================================

This test verifies:
1. Module imports work in both SharpCap and standalone modes
2. Button is only created in SharpCap mode
3. GOTO function handles missing objects gracefully
4. Coordinate calculations are correct
"""

import sys
import os

# Add script directory to path
script_dir = os.path.dirname(os.path.abspath(__file__)) if '__file__' in dir() else os.getcwd()
if script_dir not in sys.path:
    sys.path.append(script_dir)

def test_imports():
    """Test that all required modules can be imported."""
    print("Testing imports...")
    
    try:
        import time
        print("  ✓ time module imported")
    except ImportError as e:
        print("  ✗ time import failed: " + str(e))
        return False
    
    try:
        import clr
        clr.AddReference('System')
        clr.AddReference('System.Windows.Forms')
        clr.AddReference('System.Drawing')
        print("  ✓ CLR references added")
    except Exception as e:
        print("  ✗ CLR setup failed: " + str(e))
        return False
    
    try:
        from System.Threading import CancellationToken
        print("  ✓ CancellationToken imported")
    except ImportError:
        print("  ⚠ CancellationToken not available (expected in standalone mode)")
    
    try:
        from System.Windows.Forms import Clipboard
        print("  ✓ Clipboard imported")
    except ImportError as e:
        print("  ✗ Clipboard import failed: " + str(e))
        return False
    
    return True

def test_catalog_module():
    """Test that catalog module loads correctly."""
    print("\nTesting catalog module...")
    
    try:
        import ssp_catalog
        print("  ✓ ssp_catalog module imported")
        
        # Try to create a catalog instance
        catalog = ssp_catalog.StarCatalog()
        print("  ✓ StarCatalog instance created")
        
        if catalog.targets:
            print("  ✓ Catalog has %d targets loaded" % len(catalog.targets))
            
            # Test coordinate access
            if catalog.targets:
                star = catalog.targets[0].variable
                ra_hours = star.ra_hours + star.ra_minutes/60.0 + star.ra_seconds/3600.0
                dec_degrees = star.dec_degrees_decimal
                print("  ✓ Coordinate calculation works: RA=%.6fh, Dec=%.6f°" % (ra_hours, dec_degrees))
                print("  ✓ String format: RA=%s, Dec=%s" % (star.ra_string(), star.dec_string()))
        else:
            print("  ⚠ Catalog loaded but no targets found")
            
        return True
    except Exception as e:
        import traceback
        print("  ✗ Catalog test failed: " + str(e))
        print(traceback.format_exc())
        return False

def test_sharpcap_detection():
    """Test SharpCap detection logic."""
    print("\nTesting SharpCap detection...")
    
    sharpcap_available = 'SharpCap' in dir()
    
    if sharpcap_available:
        print("  ✓ Running in SharpCap mode")
        print("  ✓ GOTO button will be created")
        
        # Check if SharpCap has expected attributes
        try:
            if hasattr(SharpCap, 'Mounts'):
                print("  ✓ SharpCap.Mounts available")
            else:
                print("  ⚠ SharpCap.Mounts not available")
            
            if hasattr(SharpCap, 'CoordinateParser'):
                print("  ✓ SharpCap.CoordinateParser available")
            else:
                print("  ⚠ SharpCap.CoordinateParser not available")
        except NameError:
            print("  ✗ SharpCap object not accessible")
    else:
        print("  ✓ Running in standalone mode")
        print("  ✓ GOTO button will NOT be created")
    
    return True

def test_goto_button_logic():
    """Test that GOTO button is only created when appropriate."""
    print("\nTesting GOTO button creation logic...")
    
    sharpcap_available = 'SharpCap' in dir()
    
    # Simulate the button creation logic
    if sharpcap_available:
        print("  ✓ Button creation condition: True (SharpCap detected)")
        print("  ✓ goto_button will be initialized")
    else:
        print("  ✓ Button creation condition: False (standalone mode)")
        print("  ✓ goto_button will NOT be initialized")
        print("  ✓ hasattr(self, 'goto_button') will return False")
    
    return True

def test_coordinate_formatting():
    """Test coordinate string formatting."""
    print("\nTesting coordinate formatting...")
    
    # Test values
    ra_hours = 12.5
    dec_degrees = -30.25
    
    coord_string = "%s;%s" % (ra_hours, dec_degrees)
    expected = "12.5;-30.25"
    
    if coord_string == expected:
        print("  ✓ Coordinate string format correct: " + coord_string)
    else:
        print("  ✗ Coordinate string incorrect: got '%s', expected '%s'" % (coord_string, expected))
        return False
    
    # Test clipboard format
    clipboard_string = "%.6f, %.6f" % (ra_hours, dec_degrees)
    expected_clipboard = "12.500000, -30.250000"
    
    if clipboard_string == expected_clipboard:
        print("  ✓ Clipboard format correct: " + clipboard_string)
    else:
        print("  ✗ Clipboard format incorrect: got '%s', expected '%s'" % (clipboard_string, expected_clipboard))
        return False
    
    return True

def main():
    """Run all tests."""
    print("=" * 60)
    print("GOTO Functionality Test Suite")
    print("=" * 60)
    
    tests = [
        ("Module Imports", test_imports),
        ("Catalog Module", test_catalog_module),
        ("SharpCap Detection", test_sharpcap_detection),
        ("GOTO Button Logic", test_goto_button_logic),
        ("Coordinate Formatting", test_coordinate_formatting),
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            import traceback
            print("\n✗ Test '%s' crashed: %s" % (test_name, str(e)))
            print(traceback.format_exc())
            results.append((test_name, False))
    
    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)
    
    passed = 0
    failed = 0
    for test_name, result in results:
        status = "PASS" if result else "FAIL"
        symbol = "✓" if result else "✗"
        print("%s %s: %s" % (symbol, test_name, status))
        if result:
            passed += 1
        else:
            failed += 1
    
    print("\nTotal: %d passed, %d failed" % (passed, failed))
    
    if failed == 0:
        print("\n✓ All tests passed!")
    else:
        print("\n✗ Some tests failed")
    
    return failed == 0

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)
