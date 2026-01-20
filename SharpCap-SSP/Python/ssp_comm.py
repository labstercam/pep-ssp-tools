"""
SSP Serial Communication
========================

Handles serial communication with SSP photometer.
Implements the SSP-3a/SSP-5a serial protocol.

Author: pep-ssp-tools project
Version: 0.1.2
"""

import clr
clr.AddReference('System')

# Try to import serial port functionality
# In IronPython 3.4 (.NET Core/5+), System.IO.Ports is a separate package
SERIAL_AVAILABLE = False
try:
    from System.IO.Ports import SerialPort, Parity, StopBits
    SERIAL_AVAILABLE = True
except ImportError:
    SerialPort = None
    Parity = None
    StopBits = None

from System.Threading import Thread
from System import TimeSpan, DateTime, Array, Byte
import time


class SSPCommunicator:
    """Manages serial communication with SSP photometer."""
    
    def __init__(self):
        """Initialize communicator."""
        self.port = None
        self.is_connected = False
        self.port_name = ""
        self.buffer_size = 32768
    
    def connect(self, com_port_number):
        """Connect to SSP photometer.
        
        Implements the connection sequence from SSPDataq:
        1. Open COM port (19200,N,8,1)
        2. Send "SSSSSS" command
        3. Wait for acknowledgment (up to 5 seconds)
        4. Check for valid response (CR or !)
        
        Args:
            com_port_number: COM port number (1-19)
            
        Returns:
            tuple: (success: bool, message: str)
        """
        if not SERIAL_AVAILABLE:
            return (False, "Serial port functionality not available. Install System.IO.Ports package.")
        
        if self.is_connected:
            return (False, "Already connected")
        
        if com_port_number == 0:
            return (False, "Please select a COM port in Setup menu")
        
        try:
            self.port_name = "COM" + str(com_port_number)
            
            # Open serial port with SSP parameters
            # Note: Use getattr() to access Parity.None since 'None' is a Python keyword
            self.port = SerialPort(self.port_name, 19200, getattr(Parity, 'None'), 8, StopBits.One)
            self.port.ReadBufferSize = self.buffer_size
            self.port.WriteBufferSize = self.buffer_size
            self.port.ReadTimeout = 5000  # 5 second timeout
            self.port.WriteTimeout = 1000  # 1 second timeout
            self.port.Open()
            
            # Send initialization command to put SSP into serial mode
            self._write("SSSSSS")
            
            # Wait for acknowledgment (up to 5 seconds, 100 iterations × 50ms)
            data_read = ""
            for i in range(100):
                time.sleep(0.05)  # 50ms pause
                if self.port.BytesToRead > 0:
                    data_read = self._read_available()
                    break
            
            # Check for valid response (CR=10 or !=33 ASCII)
            if len(data_read) > 0:
                first_char = ord(data_read[0])
                if first_char == 10 or first_char == 33:  # CR or !
                    self.is_connected = True
                    return (True, "Connected to " + self.port_name)
            
            # Connection failed - no valid response
            self.port.Close()
            self.port = None
            return (False, "Not connected - no response from SSP. Is unit on?")
            
        except Exception as e:
            if self.port and self.port.IsOpen:
                self.port.Close()
            self.port = None
            return (False, "Connection failed: " + str(e))
    
    def disconnect(self):
        """Disconnect from SSP photometer.
        
        Implements the disconnection sequence from SSPDataq:
        1. Send "SEEEEE" command to exit serial mode
        2. Close COM port
        
        Returns:
            tuple: (success: bool, message: str)
        """
        if not self.is_connected:
            return (False, "Not connected")
        
        try:
            # Send exit command
            self._write("SEEEEE")
            time.sleep(0.1)  # Brief pause
            
            # Close port
            if self.port and self.port.IsOpen:
                self.port.Close()
            
            self.port = None
            self.is_connected = False
            return (True, "Disconnected from " + self.port_name)
            
        except Exception as e:
            return (False, "Disconnection failed: " + str(e))
    
    def get_slow_count(self, integration_ms):
        """Get a single count reading in slow mode.
        
        Implements [Get_Counts] subroutine from SSPDataq (lines 2231-2298):
        1. Clear buffer
        2. Send "SCnnnn" command
        3. Wait for integration time with proper overhead (matches original)
        4. Read buffer and extract count after "="
        5. Return 5-digit count value
        
        Original SSPDataq timing:
        - 1 sec (1000ms): Pause 1150ms (15% overhead)
        - 5 sec (5000ms): 5 x 1030ms = 5150ms (3% overhead)
        - 10 sec (10000ms): 10 x 1015ms = 10150ms (1.5% overhead)
        
        Args:
            integration_ms: Integration time in milliseconds (1000, 5000, or 10000)
            
        Returns:
            tuple: (success: bool, count: str or None, error_msg: str)
        """
        if not self.is_connected:
            return (False, None, "Not connected")
        
        try:
            # Clear buffer
            self._clear_buffer()
            
            # Send count command
            self._write("SCnnnn")
            
            # Wait for integration time - match original SSPDataq timing exactly
            if integration_ms == 1000:
                wait_time = 1.150  # 1150ms
            elif integration_ms == 5000:
                wait_time = 5.150  # 5 x 1030ms
            elif integration_ms == 10000:
                wait_time = 10.150  # 10 x 1015ms
            else:
                # Fallback for non-standard integration times
                wait_time = integration_ms * 1.15 / 1000.0
            
            time.sleep(wait_time)
            
            # Read response
            response = self._read_available()
            
            # Find "=" and extract 5 characters after it
            equals_pos = response.find("=")
            if equals_pos >= 0 and len(response) >= equals_pos + 6:
                count_str = response[equals_pos + 1:equals_pos + 6]
                
                # Verify first character is not null (error check)
                if ord(count_str[0]) != 0:
                    return (True, count_str, "")
                else:
                    return (False, None, "Communication error - null character received")
            else:
                return (False, None, "Invalid response format: " + response)
                
        except Exception as e:
            return (False, None, "Error getting count: " + str(e))
    
    def set_gain(self, gain_value):
        """Set photometer gain.
        
        Implements gain setting from SSPDataq (lines 1555-1580):
        1. Send SGNNN command (SGNNN3=gain 1, SGNNN2=gain 10, SGNNN1=gain 100)
        2. Wait for "!" acknowledgment (up to 5 seconds)
        
        Args:
            gain_value: Gain value (1, 10, or 100)
            
        Returns:
            tuple: (success: bool, message: str)
        """
        if not self.is_connected:
            return (False, "Not connected")
        
        # Map gain values to command codes (inverted mapping)
        if gain_value == 1:
            command = "SGNNN3"
        elif gain_value == 10:
            command = "SGNNN2"
        elif gain_value == 100:
            command = "SGNNN1"
        else:
            return (False, "Invalid gain value. Must be 1, 10, or 100")
        
        try:
            self._clear_buffer()
            self._write(command)
            
            # Wait for acknowledgment (matches original [WaitForAck] routine)
            ack_received = False
            for i in range(100):
                time.sleep(0.05)  # 50ms pause (matches original)
                if self.port.BytesToRead > 0:
                    response = self._read_available()
                    if "!" in response:
                        ack_received = True
                        break
            
            if ack_received:
                return (True, "Gain set to " + str(gain_value))
            else:
                return (False, "No acknowledgment received from SSP")
                
        except Exception as e:
            return (False, "Error setting gain: " + str(e))
    
    def home_filter(self):
        """Home the filter bar (automatic filter mode).
        
        Implements SHNNN command from SSPDataq (lines 1493-1515).
        Sends "SHNNN" command and waits for "!" acknowledgment with 3 retries.
        
        Returns:
            tuple: (success: bool, retry_count: int, message: str)
        """
        print("\n=== FILTER HOME COMMAND ===")
        print("Connection status: " + ("Connected" if self.is_connected else "Not connected"))
        
        if not self.is_connected:
            print("ERROR: Cannot home filter - not connected to SSP")
            return (False, 0, "Not connected")
        
        if self.port:
            print("COM Port: " + self.port.PortName)
            print("Port open: " + str(self.port.IsOpen))
        
        # Retry up to 3 times if no acknowledgment
        for retry in range(3):
            print("\nAttempt " + str(retry + 1) + " of 3:")
            try:
                print("  Clearing serial buffer...")
                self._clear_buffer()
                
                print("  Sending command: SHNNN")
                self._write("SHNNN")
                
                # Wait for acknowledgment (up to 5 seconds)
                print("  Waiting for acknowledgment (up to 5 seconds)...")
                ack_received = False
                for i in range(100):
                    time.sleep(0.05)  # 50ms pause
                    if self.port.BytesToRead > 0:
                        response = self._read_available()
                        print("  Received: '" + response + "'")
                        if "!" in response:
                            ack_received = True
                            print("  SUCCESS: Acknowledgment received!")
                            break
                
                if ack_received:
                    print("Filter bar successfully homed (attempt " + str(retry + 1) + ")")
                    print("=" * 30)
                    return (True, retry, "Filter bar homed")
                else:
                    print("  WARNING: No acknowledgment received")
                    # No ack, will retry unless this was the last attempt
                    if retry < 2:
                        print("  Pausing 2 seconds before retry...")
                        time.sleep(2.0)  # 2 second pause before retry
                    else:
                        print("  All retries exhausted")
                    
            except Exception as e:
                print("  EXCEPTION: " + str(e))
                print("=" * 30)
                return (False, retry, "Error homing filter: " + str(e))
        
        # All retries failed
        print("FAILED: No acknowledgment received after 3 attempts")
        print("=" * 30)
        return (False, 3, "No acknowledgment received after 3 attempts")
    
    def select_filter(self, filter_number):
        """Select filter position (automatic filter mode).
        
        Implements SFNNN command from SSPDataq (lines 1520-1543).
        Sends "SFNNNn" command where n is 1-6 for filter position.
        Waits for "!" acknowledgment with 3 retries.
        
        Args:
            filter_number: Filter position (1-6)
            
        Returns:
            tuple: (success: bool, retry_count: int, message: str)
        """
        print("\n=== FILTER SELECT COMMAND ===")
        print("Requested position: " + str(filter_number))
        print("Connection status: " + ("Connected" if self.is_connected else "Not connected"))
        
        if not self.is_connected:
            print("ERROR: Cannot select filter - not connected to SSP")
            return (False, 0, "Not connected")
        
        if filter_number < 1 or filter_number > 6:
            print("ERROR: Invalid filter number (must be 1-6)")
            return (False, 0, "Invalid filter number. Must be 1-6")
        
        if self.port:
            print("COM Port: " + self.port.PortName)
            print("Port open: " + str(self.port.IsOpen))
        
        # Retry up to 3 times if no acknowledgment
        for retry in range(3):
            print("\nAttempt " + str(retry + 1) + " of 3:")
            try:
                print("  Clearing serial buffer...")
                self._clear_buffer()
                
                print("  Pausing 10ms...")
                time.sleep(0.01)  # 10ms pause (matches original "call Pause 10")
                
                command = "SFNNN" + str(filter_number)
                print("  Sending command: " + command)
                self._write(command)
                
                # Wait for acknowledgment (up to 5 seconds)
                print("  Waiting for acknowledgment (up to 5 seconds)...")
                ack_received = False
                for i in range(100):
                    time.sleep(0.05)  # 50ms pause
                    if self.port.BytesToRead > 0:
                        response = self._read_available()
                        print("  Received: '" + response + "'")
                        if "!" in response:
                            ack_received = True
                            print("  SUCCESS: Acknowledgment received!")
                            break
                
                if ack_received:
                    print("Filter " + str(filter_number) + " successfully selected (attempt " + str(retry + 1) + ")")
                    print("=" * 30)
                    return (True, retry, "Filter " + str(filter_number) + " selected")
                else:
                    print("  WARNING: No acknowledgment received")
                    # No ack, will retry unless this was the last attempt
                    if retry < 2:
                        print("  Pausing 2 seconds before retry...")
                        time.sleep(2.0)  # 2 second pause before retry
                    else:
                        print("  All retries exhausted")
                    
            except Exception as e:
                print("  EXCEPTION: " + str(e))
                print("=" * 30)
                return (False, retry, "Error selecting filter: " + str(e))
        
        # All retries failed
        print("FAILED: No acknowledgment received after 3 attempts")
        print("=" * 30)
        return (False, 3, "No acknowledgment received after 3 attempts")
    
    def _write(self, data):
        """Write data to serial port.
        
        Args:
            data: String to write
        """
        if self.port and self.port.IsOpen:
            self.port.Write(data)
    
    def _read_available(self):
        """Read all available data from serial port.
        
        Returns:
            str: Data read from port
        """
        if self.port and self.port.IsOpen and self.port.BytesToRead > 0:
            return self.port.ReadExisting()
        return ""
    
    def _clear_buffer(self):
        """Clear the serial port input buffer."""
        if self.port and self.port.IsOpen:
            # Read and discard any data in buffer
            while self.port.BytesToRead > 0:
                self.port.ReadExisting()
