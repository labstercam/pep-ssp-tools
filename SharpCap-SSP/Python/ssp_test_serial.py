"""
SSP Serial Communication Test Script
=====================================

Tests serial connection to SSP photometer and displays raw data.
Run this from command line or SharpCap IronPython console.

Usage:
    python ssp_test_serial.py [COM_PORT]
    
Example:
    python ssp_test_serial.py 5    # Test COM5

Author: pep-ssp-tools project  
Version: 0.1.0
"""

import clr
clr.AddReference('System')
clr.AddReference('System.IO')
clr.AddReference('System.Windows.Forms')
clr.AddReference('Microsoft.VisualBasic')
from System import DateTime
from System.Windows.Forms import MessageBox, MessageBoxButtons, MessageBoxIcon, DialogResult
from Microsoft.VisualBasic import Interaction
import System
import sys
import time

# Ensure module path is accessible
script_dir = System.IO.Path.GetDirectoryName(__file__) if '__file__' in dir() else System.IO.Directory.GetCurrentDirectory()
if script_dir not in sys.path:
    sys.path.append(script_dir)

# Import SSP communicator
import ssp_comm


def test_connection(com_port):
    """Test connection to SSP photometer.
    
    Args:
        com_port: COM port number (1-19)
    """
    print("=" * 60)
    print("SSP Serial Communication Test")
    print("=" * 60)
    print("")
    print("Testing COM" + str(com_port))
    print("")
    
    # Create communicator
    comm = ssp_comm.SSPCommunicator()
    
    # Test connection
    print("Connecting to SSP photometer...")
    success, message = comm.connect(com_port)
    print(message)
    
    if not success:
        print("")
        print("Connection failed. Please check:")
        print("  1. SSP photometer is powered on")
        print("  2. Serial cable is connected")
        print("  3. Correct COM port is selected")
        print("  4. No other program is using the port")
        return False
    
    print("")
    print("Connection successful!")
    print("")
    
    # Test setting gain
    print("Testing gain control...")
    for gain in [1, 10, 100]:
        success, message = comm.set_gain(gain)
        print("  Set gain to " + str(gain) + ": " + message)
        time.sleep(0.5)
    
    print("")
    
    # Test count acquisition
    print("Testing count acquisition...")
    print("")
    
    integration_times = [1000, 5000, 10000]  # 1, 5, 10 seconds
    
    for integ_ms in integration_times:
        integ_sec = integ_ms / 1000.0
        print("Getting count with " + str(integ_sec) + " second integration...")
        print("  Please wait " + str(int(integ_sec + 1)) + " seconds...")
        
        start_time = DateTime.UtcNow
        success, count, error_msg = comm.get_slow_count(integ_ms)
        end_time = DateTime.UtcNow
        elapsed = (end_time - start_time).TotalSeconds
        
        if success:
            print("  Count: " + count)
            print("  Elapsed time: " + str(round(elapsed, 2)) + " seconds")
        else:
            print("  ERROR: " + error_msg)
        
        print("")
    
    # Disconnect
    print("Disconnecting...")
    success, message = comm.disconnect()
    print(message)
    
    print("")
    print("=" * 60)
    print("Test complete!")
    print("=" * 60)
    
    return True


def test_continuous_monitoring(com_port, duration_seconds=60):
    """Test continuous monitoring of SSP photometer.
    
    Connects and displays count data continuously for specified duration.
    
    Args:
        com_port: COM port number
        duration_seconds: How long to monitor (default 60 seconds)
    """
    print("=" * 60)
    print("SSP Continuous Monitoring Test")
    print("=" * 60)
    print("")
    print("Monitoring COM" + str(com_port) + " for " + str(duration_seconds) + " seconds")
    print("Integration time: 1 second")
    print("")
    
    comm = ssp_comm.SSPCommunicator()
    
    # Connect
    success, message = comm.connect(com_port)
    print(message)
    
    if not success:
        return False
    
    # Set gain to 10
    comm.set_gain(10)
    
    print("")
    print("Starting continuous monitoring...")
    print("UTC Time     Count   Notes")
    print("-" * 40)
    
    start = DateTime.UtcNow
    count_num = 0
    
    while (DateTime.UtcNow - start).TotalSeconds < duration_seconds:
        count_num += 1
        ut_time = DateTime.UtcNow.ToString("HH:mm:ss")
        
        success, count, error_msg = comm.get_slow_count(1000)  # 1 second
        
        if success:
            print(ut_time + "  " + count)
        else:
            print(ut_time + "  ERROR  " + error_msg)
    
    print("-" * 40)
    print("Total counts: " + str(count_num))
    
    # Disconnect
    comm.disconnect()
    
    print("")
    print("Monitoring complete!")
    
    return True


def main():
    """Main entry point."""
    # Get COM port from command line or prompt user
    if len(sys.argv) > 1:
        try:
            com_port = int(sys.argv[1])
        except:
            print("Invalid COM port number.")
            com_port = None
    else:
        com_port = None
    
    # Prompt for COM port if not specified
    if com_port is None:
        response = Interaction.InputBox(
            "Enter COM port number (e.g., 5 for COM5):",
            "SSP Serial Test - COM Port Selection",
            "5",
            -1, -1
        )
        if response:
            try:
                com_port = int(response)
            except:
                MessageBox.Show("Invalid input. Using COM5 as default.", "Info", MessageBoxButtons.OK, MessageBoxIcon.Information)
                com_port = 5
        else:
            MessageBox.Show("No input. Using COM5 as default.", "Info", MessageBoxButtons.OK, MessageBoxIcon.Information)
            com_port = 5
    
    # Run connection test
    test_connection(com_port)
    
    # Ask if user wants continuous monitoring
    print("")
    print("Run continuous monitoring test? (This will take 60 seconds)")
    result = MessageBox.Show(
        "Run continuous monitoring test?\n\nThis will take 60 seconds.",
        "Continue?",
        MessageBoxButtons.YesNo,
        MessageBoxIcon.Question
    )
    
    if result == DialogResult.Yes:
        print("")
        test_continuous_monitoring(com_port, 60)


if __name__ == "__main__":
    main()
