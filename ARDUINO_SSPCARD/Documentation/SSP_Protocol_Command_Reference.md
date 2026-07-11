# SSP Protocol Command Reference

## Overview
This document provides a complete reference for the SSP (SSPCARD) serial protocol commands used by SSPData3 software and emulated by the Arduino controller.

## Communication Parameters
- **Baud Rate**: 19200
- **Data Bits**: 8
- **Stop Bits**: 1
- **Parity**: None
- **Flow Control**: None
- **Line Endings**: CR/LF or none (commands are 6 characters)

## Command Format
All commands follow this format:
```
SXnnnn
│ │  └── Parameter (4 digits)
│ └───── Command letter
└─────── Start character (always 'S')
```

## Response Format
- **Success**: `!` (single character)
- **Error**: `?` (single character)
- **Count Response**: `C=nnnnn` (5 digits, zero-padded)

## Command Reference

### 1. Enter Serial Mode
**Command**: `SSSSSS`
**Response**: `!`
**Purpose**: Enters serial command mode (required before other commands)
**Notes**: Must be sent first to establish communication

### 2. Exit Serial Mode
**Command**: `EEEEEE`
**Response**: `!`
**Purpose**: Exits serial command mode
**Notes**: Returns to idle state

### 3. Home Filter
**Command**: `SH0000`
**Response**: `!`
**Purpose**: Moves filter wheel to home position (position 1)
**Notes**: Takes up to 5 seconds to complete

### 4. Select Filter Position
**Command**: `SF00nn` (where nn = 01-06)
**Examples**:
- `SF0011` → Filter position 1
- `SF0012` → Filter position 2
- `SF0013` → Filter position 3
- `SF0014` → Filter position 4
- `SF0015` → Filter position 5
- `SF0016` → Filter position 6 (dark)

**Response**: `!`
**Purpose**: Moves filter wheel to specified position
**Notes**: Movement time ~100ms between adjacent positions

### 5. Get Count
**Command**: `SCnnnn` (where nnnn = integration time in ms, 0001-9999)
**Examples**:
- `SC0100` → 100ms integration
- `SC0500` → 500ms integration
- `SC1000` → 1000ms (1 second) integration
- `SC5000` → 5000ms (5 seconds) integration
- `SC9999` → 9999ms integration

**Response**: `C=nnnnn` (5-digit count, zero-padded)
**Purpose**: Performs integration and returns pulse count
**Notes**: Actual wait time = integration time + overhead (15% for ≤1000ms, 3% for ≤5000ms, 1.5% for >5000ms)

### 6. Set Gain
**Command**: `SG00nn` (where nn = 01-03)
**Examples**:
- `SG0011` → Gain 1 (Gain 100)
- `SG0012` → Gain 2 (Gain 10)
- `SG0013` → Gain 3 (Gain 1)

**Response**: `!`
**Purpose**: Sets amplifier gain
**Notes**: Gain values: 1=100x, 2=10x, 3=1x

### 7. Mirror Control
**Command**: `SVIEWn` (where n = 0 or 1)
**Examples**:
- `SVIEW0` → Mirror to VIEW position
- `SVIEW1` → Mirror to RECORD position

**Response**: `!`
**Purpose**: Controls flip mirror position
**Notes**: Takes ~2 seconds to move, SSPData3 waits 2000ms after command

### 8. Set Integration Time
**Command**: `SInnnn` (where nnnn = integration time in ms, 0001-9999)
**Examples**:
- `SI0100` → Set to 100ms
- `SI1000` → Set to 1000ms
- `SI9999` → Set to 9999ms

**Response**: `!`
**Purpose**: Sets default integration time for subsequent count commands
**Notes**: This time is used if `SC` command doesn't specify time

## Error Conditions

### Invalid Commands
- **Wrong start character**: Any command not starting with 'S' → `?`
- **Invalid command letter**: `SXnnnn` where X is not valid → `?`
- **Wrong length**: Command not exactly 6 characters → `?` (after timeout)
- **Invalid parameters**: Parameter out of range → `?`

### Timeout Handling
- **Command timeout**: 100ms (if partial command received)
- **Serial mode timeout**: 5 minutes (auto-exits serial mode)

## SSPData3 Communication Sequence

### Typical Connection Sequence:
1. SSPData3 opens COM port at 19200 baud
2. SSPData3 sends: `SSSSSS`
3. Arduino responds: `!`
4. SSPData3 sends: `SH0000` (home filter)
5. Arduino responds: `!`
6. SSPData3 sends: `SVIEW0` (mirror to view)
7. Arduino responds: `!`
8. SSPData3 waits 2000ms

### Typical Measurement Sequence:
1. SSPData3 sends: `SF00nn` (select filter)
2. Arduino responds: `!`
3. SSPData3 sends: `SG00nn` (set gain)
4. Arduino responds: `!`
5. SSPData3 sends: `SCnnnn` (get count)
6. Arduino responds: `C=nnnnn`
7. SSPData3 processes count value

## Arduino Implementation Notes

### Command Processing Flow:
1. Read serial characters into buffer
2. On CR/LF or timeout, process complete command
3. Validate command format (6 chars, starts with 'S')
4. Parse command letter and parameters
5. Execute corresponding function
6. Send response (`!`, `?`, or `C=nnnnn`)

### Timing Considerations:
- **Command processing**: <1ms typical
- **Filter movement**: 100ms between positions
- **Mirror movement**: 2000ms
- **Integration overhead**: 15% for short times, decreasing for longer times
- **Response delay**: Immediate for simple commands, integration time for count commands

### Memory Usage:
- **Serial buffer**: 16-32 characters
- **Command processing**: Minimal state machine
- **Response formatting**: Fixed buffers for efficiency

## Testing Commands

### Basic Test Sequence:
```
SSSSSS  → ! (Enter serial mode)
SF0011  → ! (Move to filter 1)
SF0013  → ! (Move to filter 3)
SF0016  → ! (Move to filter 6)
SF0011  → ! (Return to filter 1)
SG0012  → ! (Set gain 2)
SC1000  → C=00000 (Count with no pulses)
EEEEEE  → ! (Exit serial mode)
```

### Advanced Test Sequence (with pulse source):
```
SSSSSS  → ! (Enter serial mode)
SI0500  → ! (Set integration to 500ms)
SC0500  → C=00250 (Count at 500Hz = 250 pulses)
SC1000  → C=01000 (Count at 1kHz = 1000 pulses)
SC2000  → C=02000 (Count at 1kHz = 2000 pulses)
EEEEEE  → ! (Exit serial mode)
```

## Troubleshooting

### No Response:
1. Check baud rate (must be 19200)
2. Check line endings (try with/without CR/LF)
3. Send `SSSSSS` first (enter serial mode)
4. Check COM port selection

### Wrong Responses:
1. Verify command format (exactly 6 characters)
2. Check parameter ranges (filters 1-6, gains 1-3)
3. Ensure no extra characters or spaces

### Timing Issues:
1. Integration times may have overhead (15% for 1 second)
2. Filter movement takes ~100ms per position
3. Mirror movement takes 2000ms

## Compatibility Notes

### SSPData3 Expectations:
1. **No startup messages**: Arduino must not output anything at startup
2. **Immediate responses**: Commands should be acknowledged immediately
3. **Exact timing**: Integration times must match SSPCARD behavior
4. **Error handling**: Invalid commands must return `?`

### Arduino Implementation:
1. **Simple Test Sketch**: Has startup messages (for testing)
2. **SSPData3 Compatible Sketch**: No startup messages (for production)
3. **Complete Sketch**: Full features with debug output

## Quick Reference Card

### Essential Commands:
```
SSSSSS  - Enter serial mode
EEEEEE  - Exit serial mode
SF001n  - Select filter n (1-6)
SCnnnn  - Get count for nnnn ms
SG001n  - Set gain n (1-3)
SVIEWn  - Mirror control (0=view, 1=record)
SH0000  - Home filter
SInnnn  - Set integration time
```

### Common Sequences:
**Connect**: `SSSSSS` → `SH0000` → `SVIEW0`
**Measure**: `SF00nn` → `SG00nn` → `SCnnnn`
**Disconnect**: `EEEEEE`

### Error Responses:
`?` - Invalid command, wrong format, or parameter out of range

## Conclusion
This protocol provides a simple but effective interface for controlling the SSP5A photometer. The Arduino implementation must exactly match the SSPCARD behavior to ensure compatibility with existing SSPData3 software.