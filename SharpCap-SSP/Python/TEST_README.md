# SSP Serial Communication Testing

This directory contains test scripts for verifying SSP photometer communication.

## Test Scripts

### 1. ssp_quick_test.py
**Interactive GUI test tool**

Quick visual test interface for basic SSP functions:
- Connect/disconnect to SSP photometer
- Test gain control (1, 10, 100)
- Get count readings with selectable integration time (1, 5, 10 seconds)
- Real-time logging of all operations

**Usage:**
```python
python ssp_quick_test.py
```

**Features:**
- Simple GUI with buttons and dropdowns
- Connection status indicator
- Live output log with timestamps
- Tests basic serial communication

---

### 2. ssp_test_serial.py
**Command-line comprehensive test**

Automated test suite that verifies all SSP communication functions:
- Connection establishment with "SSSSSS" handshake
- Gain control testing (all three gain values)
- Count acquisition with multiple integration times
- Timing verification
- Optional continuous monitoring mode (60 seconds)

**Usage:**
```bash
python ssp_test_serial.py [COM_PORT]

# Examples:
python ssp_test_serial.py 5     # Test COM5
python ssp_test_serial.py 12    # Test COM12
```

**Test Sequence:**
1. Connect to specified COM port
2. Test gain settings (1, 10, 100)
3. Acquire counts with 1, 5, and 10 second integrations
4. Display elapsed times and verify timing accuracy
5. Optional: Run 60-second continuous monitoring

---

## Testing Procedure

### Prerequisites
- SSP-3a or SSP-5a photometer powered on
- Serial cable connected to PC
- Know your COM port number (check Device Manager)
- No other software using the COM port

### Quick Verification
1. Run **ssp_quick_test.py** for interactive testing
2. Select your COM port from dropdown
3. Click "Connect"
4. Click "Get Count" to verify data acquisition
5. Try different gain settings
6. Click "Disconnect" when done

### Full Test Suite
1. Run **ssp_test_serial.py COM_PORT**
2. Wait for automatic test sequence (about 2 minutes)
3. Review output for any errors
4. Optionally run continuous monitoring test

### Expected Results

**Successful Connection:**
```
Testing COM5
Connecting to SSP photometer...
Connected to COM5

Connection successful!
```

**Count Acquisition:**
```
Getting count with 1.0 second integration...
  Please wait 2 seconds...
  Count: 12345
  Elapsed time: 1.15 seconds
```

**Common Issues:**

| Error | Cause | Solution |
|-------|-------|----------|
| "Not connected - no response" | SSP not powered on | Check power supply |
| "Port already in use" | Another program using port | Close other programs |
| "Access denied" | Permissions issue | Run as administrator |
| "Communication error - null character" | Noisy serial line | Check cable connection |

---

## Serial Protocol Reference

### Commands Tested

| Command | Function | Response |
|---------|----------|----------|
| SSSSSS | Enter serial mode | CR (10) or ! (33) |
| SEEEEE | Exit serial mode | None |
| SGxxx | Set gain (1, 10, 100) | None |
| SCnnnn | Start count | C=XXXXX\r\n |
| SHNNN | Home filter bar | ! acknowledgment |

### Timing
- **Connection timeout:** 5 seconds
- **Count overhead:** Variable by integration time (1s: 15%, 5s: 3%, 10s: 1.5%)
- **Buffer clear:** Before each command
- **Baud rate:** 19200
- **Data bits:** 8
- **Parity:** None
- **Stop bits:** 1

---

## Integration with SharpCap-SSP

These test scripts use the same **ssp_comm.py** module as the main application:
- Same serial protocol implementation
- Same timing and error handling
- Same buffer management
- If tests pass, the main application should work

---

## Troubleshooting

### Test Fails to Connect
1. Verify COM port in Device Manager
2. Check SSP photometer power LED
3. Try different COM ports (1-19)
4. Restart SSP photometer
5. Check USB-to-serial adapter drivers

### Inconsistent Count Values
- Normal for test without light source
- Counts should be stable under constant illumination
- Very low counts (<100) may indicate gain setting issue
- Very high counts (>60000) indicate saturation

### Timing Issues
- Expected: Integration time + overhead (1s: 1.15s, 5s: 5.15s, 10s: 10.15s)
- If much longer: Serial communication delays
- If shorter: Command not completing properly

---

## Development Notes

### Serial Communication Details
The implementation follows SSPDataq3 behavior exactly:
- Buffer cleared before each command ([Get_Counts] line 2241)
- "SCnnnn" command sent for slow mode counts
- Wait with proper overhead (1s: 1.15s, 5s: 5.15s, 10s: 10.15s)
- Parse response for "=" character and extract 5 digits after it
- Verify first character is not null (error detection)
- Retry once on communication errors

### Data Format
Count responses from SSP photometer:
```
C=12345\r\n
  ^^^^^
  5-digit count value
```

The tests verify:
- Response contains "=" character
- 5 characters follow the "="
- First character is not null (ASCII 0)
- Response received within timeout period
