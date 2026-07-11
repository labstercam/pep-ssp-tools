# SSPCARD Interface Analysis for SSP5A Photometer

## Overview
The SSPCARD is an interface card that provides stepper motor control and enhanced serial communication capabilities for the Optec SSP-5A photometer. This document analyzes how the SSPCARD interfaces with the SSP5A photometer and how the SSPDataq3 software communicates with it via serial port.

## Architecture

### SSPCARD Components
The SSPCARD includes:
1. **Stepper Motor Controller** - Controls 6-position filter wheel
2. **Flip Mirror Controller** - Controls view/record mirror position  
3. **Gain Switching Circuitry** - Electronic gain control (1×, 10×, 100×)
4. **Serial Interface** - RS-232 communication with host computer
5. **Microcontroller** - Processes commands and controls hardware

### Physical Connection
```
Computer (RS-232) → SSPCARD → SSP5A Photometer
                    │
                    ├→ Stepper Motor (Filter Wheel)
                    ├→ Stepper Motor (Flip Mirror)
                    └→ Gain Control Circuitry
```

## Serial Communication Protocol

### Physical Interface Specifications

#### RS-232 Pinout
The SSPCARD uses a standard DB-9 or DB-25 RS-232 connector with the following pin assignments:

| DB-9 Pin | DB-25 Pin | Signal | Direction | Description |
|----------|-----------|--------|-----------|-------------|
| 2        | 3         | TXD    | Computer → SSPCARD | Transmitted Data (Commands to SSPCARD) |
| 3        | 2         | RXD    | SSPCARD → Computer | Received Data (Responses from SSPCARD) |
| —        | —         | CTS    | SSPCARD → Computer | **NOT USED** - Hardware flow control disabled |
| —        | —         | RTS    | Computer → SSPCARD | **NOT USED** - Hardware flow control disabled |
| 5        | 7         | GND    | —         | Signal Ground |
| 1, 4, 6, 7, 8, 9 | Various | —      | —         | **NOT CONNECTED** - SSPCARD uses minimal 3-wire connection |

**Important**: The SSPCARD uses a **3-wire connection** (TXD, RXD, GND) with **no hardware flow control**. This is configured in the connection string as `ds0,cs0` (DTR disable, RTS/CTS flow control disable).

#### Electrical Specifications
- **Voltage Levels**: Standard RS-232 (±3V to ±15V)
- **Baud Rate**: Fixed at 19200 bps
- **Data Format**: 8 data bits, no parity, 1 stop bit
- **Cable Type**: Shielded RS-232 cable recommended (up to 15 meters)
- **Connector**: Standard DB-9 male on computer, DB-9 female on SSPCARD

### Command Structure
All commands follow this pattern:
```
S + CommandLetter + Parameters
```

Where:
- `S` = Start character (all SSPCARD commands start with 'S')
- `CommandLetter` = Single character identifying the command type
- `Parameters` = Command-specific parameters (variable length)

### Command Set Reference

#### System Control Commands
| Command | Parameters | Function | Response | Timing |
|---------|-----------|----------|----------|--------|
| `SSSSSS` | None | Enter serial control mode | CR (10) or ! (33) | ~5s max |
| `SEEEEE` | None | Exit serial control mode | None | Immediate |
| `SInnnn` | nnnn=time | Set integration time | ! | ~1s |
| `SGxxx`  | xxx=gain | Set gain (1, 10, or 100) | ! | ~1s |

#### Data Acquisition Commands
| Command | Parameters | Function | Response Format | Timing |
|---------|-----------|----------|----------------|--------|
| `SCnnnn` | None | Single count (slow mode) | `C=XXXXX\r\n` | Integration + overhead |
| `SMXXXX` | XXXX=count | Multiple counts (fast mode) | Raw count values | Variable |
| `SNXXXX` | XXXX=count | Very fast counts (SSP-5 only) | Raw 2-byte values | Variable |

#### Hardware Control Commands (Stepper Motors)
| Command | Parameters | Function | Response | Timing |
|---------|-----------|----------|----------|--------|
| `SHNNN` | None | Home filter bar | ! | ~5s |
| `SFNNNn` | n=1-6 | Select filter position | ! | ~100ms |
| `SVIEWx` | x=0 or 1 | Set mirror position | ! | ~2s |

### Integration Time Mapping
The SSPCARD requires integration times as 4-digit codes:

| Integration Time | Command Code | Notes |
|------------------|--------------|-------|
| 20ms | `SI0002` | SSP-5 only (Very Fast mode) |
|241|50ms | `SI0005` | Fast mode |
| 100ms | `SI0010` | Fast mode |
| 500ms | `SI0050` | Fast mode |
| 1000ms (1s) | `SI0100` | Slow/Fast mode |
| 5000ms (5s) | `SI0500` | Slow mode |
| 10000ms (10s) | `SI1000` | Slow mode |

### Gain Control Mapping
Gain commands use an inverted mapping:

| Gain Value | Command Code | Notes |
|------------|--------------|-------|
| 1 | `SGNNN3` | Lowest sensitivity |
| 10 | `SGNNN2` | Medium sensitivity |
| 100 | `SGNNN1` | Highest sensitivity |

**Note**: The numbering is inverted (3=1×, 2=10×, 1=100×). This likely reflects hardware design choices in the SSPCARD circuitry.

## Communication Flow Analysis

### Initialization Sequence
```
1. Computer opens COM port: 19200,N,8,1,ds0,cs0
2. Computer sends: "SSSSSS" (Enter serial mode)
3. SSPCARD responds: CR (10) or ! (33) ASCII
4. If AutoFilter enabled: Computer sends "SHNNN" (Home filter)
5. SSPCARD homes filter and responds: "!"
6. Connection established
```

### Data Collection Sequence (Slow Mode)
```
1. Computer clears serial buffer
2. Computer sends: "SCnnnn" (Start count)
3. SSPCARD starts integration timer
4. After integration + overhead, SSPCARD sends: "C=XXXXX\r\n"
5. Computer parses count after "=" (5 digits)
6. Process repeats for specified interval count
```

### Stepper Motor Control Sequence
```
Filter Change (Auto Mode):
1. Computer sends: "SFNNNn" (n=1-6)
2. SSPCARD energizes stepper motor coils
3. Motor moves to specified position
4. SSPCARD sends: "!" when complete
5. Computer waits ~100ms before next command

Mirror Control:
1. Computer sends: "SVIEW0" (view) or "SVIEW1" (record)
2. SSPCARD moves flip mirror
3. SSPCARD sends: "!" when complete
4. Computer waits ~2000ms for movement
```

## Signal Timing Analysis

### Serial Timing
- **Baud Rate**: 19200 bps = ~104µs per bit
- **Character Transmission**: 10 bits/char × 104µs = 1.04ms per character
- **Command Transmission**: 
  - `SSSSSS` = 6 chars × 1.04ms = 6.24ms
  - `SCnnnn` = "" = 6 chars × 1.04ms = 6.24ms
  - Full command + response cycle ≈ 10-15ms minimum

### Hardware Timing
| Operation | Time | Notes |
|-----------|------|-------|
| Filter homing | ~5000ms | Full travel from any position to home |
| Filter change | ~100ms | Step between adjacent positions |
| Mirror flip | ~2000ms | 180° rotation |
| Gain switching | ~10ms | Electronic switching (fast) |
| Integration start latency | <10ms | Command processing delay |

### Data Acquisition Timing Overhead
The SSPDataq software adds overhead to integration times:

| Integration | Overhead | Total Wait | Notes |
|-------------|----------|------------|-------|
| 1 second | 15% (150ms) | 1150ms | For serial communication |
| 5 seconds | 3% (150ms) | 5150ms | 5 × 1030ms loops |
| 10 seconds | 1.5% (150ms) | 10150ms | 10 × 1015ms loops |

**Note**: The overhead is approximately 150ms regardless of integration time, but expressed as different percentages.

## Buffer Management

### SSPCARD Buffer
The SSPCARD has an internal buffer for:
1. **Command reception** - Stores incoming commands
2. **Data transmission** - Buffers count data before sending
3. **Stepper motor queue** - Queues motor movements

### Computer Buffer Management
SSPDataq3 manages buffers using:

```vb
' Clear buffer before command
junk$ = input$(#commHandle, lof(#commHandle))

' Send command
print #commHandle, command$

' Check for data
IF lof(#commHandle) > 0 THEN
    response$ = input$(#commHandle, lof(#commHandle))
END IF
```

### Fast/Very Fast Mode Buffering
For rapid photometry:
- **Fast Mode**: Buffer size = Interval × 6 bytes
- **Very Fast Mode**: Buffer size = Interval × 2 bytes
- Computer polls buffer until full dataset received

## Error Handling and Recovery

### SSPCARD Error Indicators
1. **No response** - SSPCARD not powered or disconnected
2. **Invalid response** - Communication corruption
3. **Timeout** - SSPCARD busy or malfunctioning

### Error Recovery Strategies
```vb
SUB WaitForAck
    Ack = 0
    FOR i = 1 TO 100          ' 100 iterations × 50ms = 5 second timeout
        CALL Pause 50
        IF lof(#commHandle) > 0 THEN
            response$ = input$(#commHandle, lof(#commHandle))
            IF INSTR(response$, "!") > 0 THEN
                Ack = 1
                EXIT FOR
            END IF
        END IF
    NEXT i
    
    IF Ack = 0 THEN
        ' Retry or report error
        PRINT "No acknowledgment received"
        CALL Pause 2000
    END IF
END SUB
```

### Common Error Conditions
1. **Stepper motor stall** - Filter/mirror stuck
2. **Gain switching failure** - Electronic fault
3. **Count data corruption** - Serial noise
4. **Buffer overflow** - Too rapid commands

## Hardware Interface Details

### Stepper Motor Control
The SSPCARD controls two stepper motors:

#### Filter Wheel Stepper
- **Type**: Bipolar stepper motor
- **Steps/revolution**: 200 steps (1.8°/step)
- **Microstepping**: Likely 1/2 or 1/4 microstepping for smoother motion
- **Positions**: 6 predefined positions (U, B, V, R, I, Dark)
- **Current control**: Chopper driver for consistent torque

#### Flip Mirror Stepper
- **Type**: Smaller bipolar stepper
- **Positions**: 2 (View/Record)
- **Movement**: 180° rotation
- **Timing**: ~2000ms for full movement

### Gain Control Circuitry
The SSPCARD provides electronic gain switching:
- **Gain 1**: Direct connection (no amplification)
- **Gain 10**: ×10 amplifier stage
- **Gain 100**: ×100 amplifier stage (cascaded ×10 stages)

### Photodiode/PMT Interface
The SSPCARD interfaces with the SSP5A detector:
- **Analog input**: Photocurrent from detector
- **Integration capacitor**: Programmable integration time
- **ADC**: Likely 16-bit analog-to-digital converter
- **Digital output**: 5-digit count values (0-65535 range)

## Protocol Implementation Details

### Character Encoding
- **All commands**: ASCII characters
- **Responses**: ASCII characters or binary data
- **Count values**: ASCII digits '0'-'9'
- **Control characters**: CR (13), LF (10), ! (33)

### Timing Precision
SSPDataq3 uses Windows Kernel32 for precise timing:

```vb
SUB Pause mil
    ' Millisecond-level timing using Windows API
    calldll #kernel32, "Sleep", 1 as ulong, r as void
END SUB
```

### Synchronization
1. **Command-response synchronization** - Wait for acknowledgment
2. **Timing synchronization** - Precise wait intervals
3. **Buffer synchronization** - Clear buffers between commands

## Configuration Parameters

### dparms.txt Settings Affecting SSPCARD
```
Line 3:  AutoManual$         ; "A"=Auto filter, "M"=Manual filter
Line System24: AutoMirrorFlag     ; 0=Manual, 1=Auto+confirm, 2=Auto
Line 30: FilterSystem$       ; 1=Johnson/Cousins, 0=Sloan
```

### Filter Configuration
The SSPCARD supports 3 filter bars with 6 positions each:
```
Bar 1 (Positions 1-6): U, B, V, R, I, Dark
Bar 2 (Positions 1-6): Custom filters
Bar 3 (Positions 1-6): Custom filters
```

## Testing and Diagnostics

### Connection Test
```vb
' Simple connection test
OPEN "COM3:19200,n,8,1,ds0,cs0" FOR RANDOM AS #commHandle
print #commHandle, "SSSSSS"
CALL WaitForAck
IF Ack =142 THEN
    PRINT "SSPCARD connected"
ELSE
    PRINT "Connection failed"
END IF
```

### Hardware Test Sequence
1. Test serial communication (`SSSSSS` → `SEEEEE`)
2. Test gain switching (`SGNNN1` → `SGNNN2` → `SGNNN3`)
3. Test filter movement (`SHNNN` → `SFNNN1` → `SFNNN6`)
4. Test mirror movement (`SVIEW0` → `SVIEW1`)
5. Test data acquisition (`SCnnnn` with various integration times)

## Comparison with SSP-3a Interface

### SSP-3a (Without SSPCARD)
- **Manual filter changes** (2-position slider)
- **No stepper motor control**
- **Simpler gain switching**
- **No flip mirror control**
- **Slower maximum integration rate**

### SSP-5a (With SSPCARD)
- **Automatic 6-position filter wheel**
- **Stepper motor control**
- **Enhanced gain control**
- **Flip mirror control**
- **Very fast mode (20ms integrations)**
- **More precise timing**

## Troubleshooting Guide

### No Communication
1. **Check power** to SSP5A and SSPCARD
2. **Verify COM port** in Windows Device Manager
3. **Test cable** with loopback test
4. **Check baud rate** (must be 19200)
5. **Try different COM port**

### Filter Not Moving
1. **Verify AutoManual$ = "A"** in dparms.txt
2. **Listen for motor sounds** during homing
3. **Check stepper motor power**
4. **Test with "SHNNN" command**

### Gain Not Changing
1. **Verify gain command format** (SGNNN1/2/3)
2. **Check acknowledgment** ("!" response)
3. **Test each gain setting** individually

### Data Corruption
1. **Use shielded RS-232 cable**
2. **Ensure proper grounding**
3. **Try shorter cable** (<10 meters)
4. **Check for electrical interference**

## Performance Characteristics

### Maximum Data Rates
| Mode | Integration | Interval Max | Samples/sec | Notes |
|------|-------------|--------------|-------------|-------|
| Very Fast | 20ms | 5000 | 50 | SSP-5 only, 2-byte data |
| Fast | 50ms | 5000 | 20 | Reduced precision |
| Slow | 1000ms | 4 | 4 | Full precision (5-digit) |

### Accuracy Specifications
- **Count resolution**: 16-bit (0-65535 counts)
- **Integration accuracy**: ±1% (crystal oscillator)
- **Filter position accuracy**: ±0.5° (microstepped)
- **Timing accuracy**: ±1ms (Windows Sleep function)

### Power Requirements
- **SSPCARD power**: Likely 12V DC from SSP5A
- **Stepper motor current**: ~1A per phase
- **Logic power**: 5V DC
- **Total consumption**: ~15W maximum

## Implementation Notes for Developers

### Serial Port Initialization
```python
# Python/.NET example
from System.IO.Ports import SerialPort, Parity, StopBits

port = SerialPort("COM3", 19200, Parity.None, 8, StopBits.One)
port.ReadTimeout = 5000      # 5 second timeout
port.WriteTimeout = 1000     # 1 second timeout
port.Open()
```

### Command Sequencing
Always follow this sequence:
1. Clear buffer
2. Send command
3. Wait appropriate time
4. Read response
5. Verify acknowledgment
6. Process data

### Error Handling Best Practices
1. Implement timeout for all operations
2. Retry failed commands (max 3 attempts)
3. Log all communication errors
4. Provide user feedback on status

## Conclusion

The SSPCARD provides a sophisticated interface between the SSP5A photometer and host computer, enabling:
- Automated filter wheel control via stepper motor
- Flip mirror positioning
- Precise gain switching
- High-speed data acquisition
- Reliable serial communication

The protocol is ASCII-based with specific timing requirements and acknowledgment checks. Understanding this protocol is essential for developing software to control SSP5A photometers or troubleshooting communication issues.

The 3-wire RS-232 connection (TXD, RXD, GND) with no hardware flow control simplifies wiring but requires careful software buffer management. The fixed 19200 baud rate provides a balance between speed and reliability for astronomical photometry applications.