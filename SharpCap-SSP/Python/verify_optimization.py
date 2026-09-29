#!/usr/bin/env python
"""
Verify the optimization in _read_with_timeout by examining the source code.
"""

import re

def check_optimization(filename):
    """Check if _read_with_timeout has been optimized."""
    with open(filename, 'r') as f:
        content = f.read()
    
    # Find the _read_with_timeout method
    pattern = r'def _read_with_timeout\([^)]+\):(.*?)(?=\n    def |\n\n|\Z)'
    match = re.search(pattern, content, re.DOTALL)
    
    if not match:
        print("✗ Could not find _read_with_timeout method")
        return False
    
    method_body = match.group(1)
    
    print("Analyzing _read_with_timeout method...")
    print("-" * 60)
    
    # Check for optimization indicators
    checks = [
        ("List initialization", 'data_parts = []' in method_body),
        ("List append", 'data_parts.append(chunk)' in method_body or 'data_parts.append(' in method_body),
        ("String join", "''.join(data_parts)" in method_body),
        ("No string concatenation", 'data += chunk' not in method_body),
        ("Optimized end checking", 'chunk.endswith(expected_end)' in method_body),
        ("Periodic checking", 'len(data_parts) >=' in method_body),
    ]
    
    all_passed = True
    for check_name, passed in checks:
        status = "✓" if passed else "✗"
        print(f"{status} {check_name}")
        if not passed:
            all_passed = False
    
    print("-" * 60)
    
    if all_passed:
        print("✓ All optimizations verified!")
        print("\nThe method now uses:")
        print("1. List accumulation instead of string concatenation")
        print("2. Periodic string joining instead of continuous concatenation")
        print("3. Direct chunk end checking for common case")
        print("4. Reduced memory allocations for IronPython 2.7")
        return True
    else:
        print("✗ Some optimizations missing")
        return False

if __name__ == "__main__":
    filename = r"SharpCap-SSP\Python\ssp_comm.py"
    print(f"Checking optimization in: {filename}")
    print("=" * 60)
    
    try:
        if check_optimization(filename):
            print("\n" + "=" * 60)
            print("OPTIMIZATION SUCCESSFULLY IMPLEMENTED!")
            print("=" * 60)
        else:
            print("\n" + "=" * 60)
            print("OPTIMIZATION INCOMPLETE OR MISSING")
            print("=" * 60)
    except Exception as e:
        print(f"Error: {e}")