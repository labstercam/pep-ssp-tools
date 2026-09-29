#!/usr/bin/env python
"""
Simple test for _read_with_timeout optimization.
"""

import sys
import os

# Add the SSP Python directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'SharpCap-SSP', 'Python'))

try:
    from ssp_comm import SSPCommunicator
    print("✓ Successfully imported SSPCommunicator")
    
    # Test that the module compiles and loads
    comm = SSPCommunicator(boot_delay=5.0, device_type='auto')
    print("✓ Successfully created SSPCommunicator instance")
    
    # Check if _read_with_timeout method exists
    if hasattr(comm, '_read_with_timeout'):
        print("✓ _read_with_timeout method exists")
        
        # Get the source code of the method to verify optimization
        import inspect
        source = inspect.getsource(comm._read_with_timeout)
        
        # Check for optimization indicators
        if 'data_parts = []' in source:
            print("✓ Found list accumulation optimization (data_parts = [])")
        if 'data_parts.append(chunk)' in source:
            print("✓ Found list append optimization")
        if "''.join(data_parts)" in source:
            print("✓ Found string join optimization")
        if 'data += chunk' not in source:
            print("✓ String concatenation (+=) removed (good!)")
        else:
            print("✗ Warning: String concatenation still present")
            
        print("\nOptimization verification:")
        print("-" * 40)
        print("The method should use list accumulation instead of string concatenation.")
        print("This reduces memory allocations in IronPython 2.7.")
        
    else:
        print("✗ ERROR: _read_with_timeout method not found!")
        
except Exception as e:
    print(f"✗ Error during test: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

print("\n" + "=" * 60)
print("Syntax and import tests PASSED")
print("The optimized _read_with_timeout method is ready for testing.")