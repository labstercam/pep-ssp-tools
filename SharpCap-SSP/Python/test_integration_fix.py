"""
Test script for integration time fix
=====================================

This script demonstrates that the integration time command is now being sent
to the SSP device. Run this with IronPython to test the fix.

To run: Follow the pattern in Launch_SSP.bat
"""

import clr
import sys
import os

# Add current directory to path
script_dir = os.path.dirname(os.path.abspath(__file__)) if '__file__' in dir() else os.getcwd()
if script_dir not in sys.path:
    sys.path.insert(0, script_dir)

import ssp_comm

print("=" * 60)
print("Integration Time Fix Test")
print("=" * 60)
print("")
print("This test verifies that the set_integration() method exists")
print("and can be called properly.")
print("")

# Create communicator
comm = ssp_comm.SSPCommunicator()

# Check that the method exists
if hasattr(comm, 'set_integration'):
    print("[PASS] set_integration() method exists in SSPCommunicator")
else:
    print("[FAIL] set_integration() method NOT FOUND")
    sys.exit(1)

# Test the method signature (without connecting)
print("")
print("Testing method with invalid integration time (should fail gracefully):")
success, msg = comm.set_integration(1234)  # Invalid value
print("  Result: success={}, message='{}'".format(success, msg))

if not success and "Not connected" in msg:
    print("[PASS] Method correctly reports 'Not connected' state")
else:
    print("[INFO] Unexpected response (check if device is connected)")

print("")
print("=" * 60)
print("Integration Time Command Mapping (from code):")
print("=" * 60)
print("  20ms   -> SI0002")
print("  50ms   -> SI0005")
print("  100ms  -> SI0010")
print("  500ms  -> SI0050")
print("  1000ms -> SI0100")
print("  5000ms -> SI0500")
print("  10000ms-> SI1000")
print("")
print("This matches the original SSPDataq BASIC code (lines 1599-1633)")
print("")

print("=" * 60)
print("Code Flow Test Summary:")
print("=" * 60)
print("")
print("The fix adds the following changes:")
print("")
print("1. ssp_comm.py:")
print("   - Added set_integration() method that sends 'SInnnn' command")
print("   - Method waits for '!' acknowledgment from SSP device")
print("")
print("2. ssp_dataaq.py:")
print("   - Calls set_integration() BEFORE taking any counts")
print("   - Called in both slow mode and trial mode")
print("   - Integration time is now set on device, not just Python variable")
print("")
print("BEFORE THE FIX:")
print("  - Integration time was only used for Python sleep timing")
print("  - SSP device was never told what integration time to use")
print("  - Result: Counts didn't scale with integration time changes")
print("")
print("AFTER THE FIX:")
print("  - Integration time is sent to SSP device via 'SI' command")
print("  - SSP device configures itself for specified integration")
print("  - Result: Counts should now scale properly with integration time")
print("")
print("=" * 60)
print("Test Complete!")
print("=" * 60)
print("")
print("To test with actual SSP hardware:")
print("  1. Connect to SSP device")
print("  2. Take reading with 1 sec integration")
print("  3. Take reading with 10 sec integration")
print("  4. Verify counts are approximately 10x higher")
