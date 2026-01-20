# SSP Automated Filter Slider Control

## Overview

The SSP photometers (SSP-3a and SSP-5a) support two types of filter systems:
1. **Manual 2-position slider** - User manually changes filters between measurements
2. **Automated 6-position slider** - Motorized filter wheel controlled via serial port

This document describes the automated filter slider control system as implemented in the SSPDataq software.

## Filter System Configuration

### System Selection

The filter system type is configured in `dparms.txt`:
- **AutoManual$**: `"A"` = Auto 6-position slider, `"M"` = Manual 2-position slider

### Filter Bar Organization

The system supports up to **3 filter bars**, each with **6 filter positions**, for a total of 18 possible filter configurations:

```
Filters$(1-6)    = Filter Bar 1, positions 1-6
Filters$(7-12)   = Filter Bar 2, positions 1-6
Filters$(13-18)  = Filter Bar 3, positions 1-6
```

**Active Filter Bar:**
- Stored in `FilterBar` variable (values: 1, 2, or 3)
- Default is 1
- Determines which set of 6 filters is currently loaded in the Combo1$ display array

**Filter Array Mapping:**
```basic
' Load filters for display based on active filter bar
for I = 1 to 6
    Combo1$(I) = Filters$(I + (FilterBar - 1) * 6)
next I
Combo1$(7) = "Home"  ' Position 7 is always "Home" for auto filter mode
```

**Note:** The Combo1$ array has 7 elements (DIM Combo1$(7)):
- Positions 1-6: Filter names from the active filter bar
- Position 7: Always "Home" (used to home the filter bar in auto mode)

**Historical Note:** The code comments mention an "obsolete 10-position slider" system. The current implementation only supports 6-position automated sliders. The 18-position array (3 bars × 6 positions) supersedes any earlier 10-position design.

### Filter Names

Common filter configurations:
- **Johnson/Cousins System** (`FilterSystem$ = "1"`): U, B, V, R, I
- **Sloan System** (`FilterSystem$ = "0"`): u, g, r, i, z

Users can define custom filter names for each of the 18 positions in dparms.txt.

---

## Serial Port Commands

### Overview

All filter commands follow the SSP serial protocol pattern:
```
"S" + command_code + parameters
```

Commands are sent as ASCII text strings without explicit terminators (CR/LF not required for transmission).

### Command Reference

#### 1. SHNNN - Home Filter Bar

**Purpose:** Moves the filter slider to position 1 (home position)

**Syntax:**
```basic
print #commHandle, "SHNNN"
```

**Parameters:** None (NNN is literal text, not a parameter)

**Response:** Returns `"!"` acknowledgment character

**Timing:** 
- Command execution: ~5 seconds maximum
- Acknowledgment timeout: 5 seconds (100 iterations × 50ms)

**Usage Context:**
- Initial connection when AutoManual$ = "A"
- User selection of "Home" option in filter menu (FilterIndex = 7)
- Reset operation to ensure known filter position

**Implementation (SSPDataq3_3,21.bas, lines 904-912):**
```basic
if AutoManual$ = "A" then
    junk$ = input$(#commHandle, lof(#commHandle))  'clear buffer
    print #commHandle, "SHNNN"  'home the filter bar
    print #main.textbox4, "filter slider going to position 1"
    gosub [WaitForAck]
    print #main.textbox4, "filter "; Combo1$(1); " is in position"
    FilterIndex = 2  ' Set to 2 so next filter selection will be position 2
    print #main.combo1, "selectindex 1"  ' UI shows filter 1 is selected
end if
```

**Note on FilterIndex:** After homing, the physical slider is at position 1 (with Combo1$(1) filter in place), but FilterIndex is set to 2. This appears to be preparing for the next filter change operation. The UI displays position 1 as selected via "selectindex 1".

**Error Handling:**
- Retries up to 3 times if acknowledgment not received
- Displays error message: "problem with SSP communication - no Ack received"

---

#### 2. SFNNN[1-6] - Select Filter Position

**Purpose:** Moves the filter slider to a specific position (1-6)

**Syntax:**
```basic
print #commHandle, "SFNNN"; FilterNumber
```

**Parameters:**
- `FilterNumber`: Position number (1-6)
  - 1 = Position 1 (home position)
  - 2 = Position 2
  - 3 = Position 3
  - 4 = Position 4
  - 5 = Position 5
  - 6 = Position 6

**Response:** Returns `"!"` acknowledgment character

**Timing:**
- Command execution: Variable, depends on current position and target position
- Typical movement: 1-5 seconds
- Acknowledgment timeout: 5 seconds (100 iterations × 50ms)
- Pre-command pause: 10ms buffer clear delay

**Implementation (SSPDataq3_3,21.bas, lines 1522-1540):**
```basic
if AutoManual$ = "A" then
    if CommFlag = 0 then            'check to see if COM port is open
        call CommError
        goto [timeloop]
    end if
    FilterNumber = FilterIndex
    if FilterNumber >= 1 and FilterNumber <= 6 then
        junk$ = input$(#commHandle, lof(#commHandle))  'clear buffer
        call Pause 10
        print #commHandle, "SFNNN"; FilterNumber

        gosub [WaitForAck]          'wait for return ! before proceeding
        if Ack = 0 then             'if Ack not true then repeat command
            AckCounter = AckCounter + 1
            if AckCounter = 3 then  'try three times before giving up
                print #main.textbox4, "problem with SSP communication - no Ack received"
                goto [timeloop]
            else
                goto [SELECT_FILTER.Click]
            end if
            AckCounter = 0
        end if

        print #main.textbox4, "filter "; Combo1$(FilterIndex); " is in position"
    end if
end if
```

**Validation:**
- Only valid for positions 1-6
- Ignored if AutoManual$ = "M" (manual mode)
- Requires active COM port connection (CommFlag = 1)

**Error Handling:**
- Retries up to 3 times if acknowledgment not received
- Displays error message: "problem with SSP communication - no Ack received"
- Returns to main loop after 3 failed attempts

---

### Acknowledgment Protocol

All filter commands use the `[WaitForAck]` subroutine to confirm successful execution.

**Subroutine: [WaitForAck] (SSPDataq3_3,21.bas, lines 2799-2825)**

```basic
[WaitForAck]                                'routine to wait for ! to be returned from SSP
    Ack = 0                                 'set ack flag to false

    for I = 1 to 100                        'find the "!" in the serial input and set ack flag to 1 if found
        call Pause 50                       'this may take up to 5 seconds before sending error message
        numBytes = lof(#commHandle)
        dataRead$ = input$(#commHandle, numBytes)

        for I2 = 1 to numBytes
            if mid$(dataRead$, I2, 1) = "!" then
                Ack = 1
                exit for
            end if
        next I2
        if Ack = 1 then
            exit for
        end if
    next I

    if Ack = 0 then                         'if no "!" received then indicate error condition
        print #main.textbox4, "did not receive Ack from SSP - will try again"
        call Pause 2000
    end if
return
```

**Process:**
1. Initialize Ack flag to 0 (false)
2. Loop up to 100 iterations (5 second timeout):
   - Pause 50 milliseconds
   - Check buffer for available bytes
   - Read all available data
   - Search for "!" character
   - Set Ack = 1 if found and exit
3. If no "!" received after 5 seconds:
   - Print error message
   - Pause 2 seconds
   - Return with Ack = 0 (caller handles retry)

**Total Timeout:** 5 seconds (100 × 50ms)

---

## Buffer Management

### Clear Buffer Before Commands

Critical for reliable communication - always clear the serial buffer before sending filter commands:

```basic
junk$ = input$(#commHandle, lof(#commHandle))  'clear buffer
```

**Purpose:**
- Removes stale data from previous commands
- Ensures only the current command's response is read
- Prevents acknowledgment confusion

**Implementation:**
- `lof(#commHandle)` returns number of bytes in receive buffer
- `input$()` reads and discards those bytes
- Stored in temporary `junk$` variable (not used)

---

## Filter Selection Workflow

### Manual Mode (AutoManual$ = "M")

1. User selects filter from dropdown (Combo1$)
2. Software displays message: "place filter [name] in position"
3. No serial commands sent
4. User manually changes filter and continues

### Automatic Mode (AutoManual$ = "A")

1. User selects filter from dropdown (Combo1$) or selects "Home"
2. Software validates selection:
   - Checks COM port is open (CommFlag = 1)
   - Validates filter position (1-6) or Home (7)
3. Clear serial buffer
4. Send appropriate command:
   - **Home:** Send "SHNNN"
   - **Filter 1-6:** Send "SFNNN[1-6]"
5. Wait for acknowledgment (WaitForAck)
6. Handle acknowledgment:
   - **Success:** Display "filter [name] is in position"
   - **Failure:** Retry up to 3 times
7. Update FilterIndex to reflect current position

### Initial Connection Sequence

When connecting to SSP with automatic filter mode enabled:

```basic
' From SSPDataq3_3,21.bas, lines 904-912
if AutoManual$ = "A" then
    junk$ = input$(#commHandle, lof(#commHandle))  'clear buffer
    print #commHandle, "SHNNN"  'home the filter bar
    print #main.textbox4, "filter slider going to position 1"
    gosub [WaitForAck]
    print #main.textbox4, "filter "; Combo1$(1); " is in position"
    FilterIndex = 2
    print #main.combo1, "selectindex 1"
end if
```

**Process:**
1. Check if auto mode enabled
2. Clear buffer
3. Home the filter bar (position 1)
4. Wait for acknowledgment
5. Update display to show current filter
6. Set FilterIndex to 2 (next selection will be position 2)

---

## SSP Model Differences

### SSP-3a vs SSP-5a Filter Control

**SSP-3a:**
- Supports manual 2-position slider (standard)
- Automated 6-position slider (optional upgrade)
- Uses same serial protocol for automated slider

**SSP-5a:**
- Supports manual 2-position slider (standard)
- Automated 6-position slider (optional upgrade)
- Uses same serial protocol for automated slider
- No protocol differences from SSP-3a for filter control

**Key Point:** The filter control protocol is **identical** for both SSP-3a and SSP-5a models. The only difference is the physical hardware configuration (manual vs. automated slider), not the communication protocol.

### Detection of Filter Capability

**CRITICAL: The SSP firmware cannot detect whether automated filter hardware is physically present.**

The SSP firmware will **always respond with acknowledgment (`!`)** to filter commands (SHNNN, SFNNNn), regardless of whether the automated 6-position filter slider hardware is actually installed. This means:

- ✅ SSP with automated slider: Acknowledges command, slider moves physically
- ✅ SSP without automated slider: Acknowledges command, no physical movement occurs
- ⚠️ Software cannot distinguish between these cases programmatically

**User Configuration Required:**
- User must manually set `AutoManual$` in dparms.txt based on their actual hardware
- No auto-detection possible through the serial protocol
- Incorrect configuration results in:
  - **Manual mode on auto hardware:** User prompted unnecessarily for manual filter changes
  - **Auto mode on manual hardware:** Commands sent and acknowledged, but no physical movement occurs (silent failure)

**SharpCap-SSP Implementation:**
- Displays hardware verification dialog when switching to Auto mode (v0.1.2+)
- Prompts user to confirm they have automated filter slider hardware
- Updates QUICK_START.md documentation with explicit hardware requirements
- Original SSPDataq software has the same limitation - relies on user configuration

**Testing Recommendations:**
- Always visually verify filter movement when first enabling Auto mode
- If filters don't move despite "success" messages, switch to Manual mode
- Standard SSP units (most common) come with manual 2-position sliders
- Automated 6-position slider is an optional upgrade

---

## Complete Serial Protocol Summary

### All SSP Serial Commands

| Command | Parameters | Function | Response | Timeout |
|---------|-----------|----------|----------|---------|
| **SSSSSS** | None | Enter serial control mode | CR (10) or ! (33) | 5s |
| **SEEEEE** | None | Exit serial control mode | None | N/A |
| **SCnnnn** | None | Single count (slow mode) | C=XXXXX\r\n | Integration + 150ms |
| **SMxxxx** | xxxx = count | Multiple counts (fast mode) | Multiple values | Variable |
| **SNxxxx** | xxxx = count | Multiple counts (vfast mode) | Multiple values | Variable |
| **SGNNN3** | None | Set gain to 1 | ! | 5s |
| **SGNNN2** | None | Set gain to 10 | ! | 5s |
| **SGNNN1** | None | Set gain to 100 | ! | 5s |
| **SI0002** | None | Set integration to 0.02s | ! | 5s |
| **SI0005** | None | Set integration to 0.05s | ! | 5s |
| **SI0010** | None | Set integration to 0.10s | ! | 5s |
| **SI0050** | None | Set integration to 0.50s | ! | 5s |
| **SI0100** | None | Set integration to 1.00s | ! | 5s |
| **SI0500** | None | Set integration to 5.00s | ! | 5s |
| **SI1000** | None | Set integration to 10.00s | ! | 5s |
| **SHNNN** | None | Home filter bar (position 1) | ! | 5s |
| **SFNNN[1-6]** | 1-6 | Select filter position | ! | 5s |
| **SVIEW0** | None | Flip mirror to VIEW | ! | 2s + 5s ack |
| **SVIEW1** | None | Flip mirror to RECORD | ! | 2s + 5s ack |

### Serial Port Configuration

```
Baud Rate:    19200
Data Bits:    8
Parity:       None
Stop Bits:    1
Flow Control: None (ds0, cs0)
```

### Integration Time Command Details

Integration time commands specify time in hundredths of a second:
- **SI0002** → 0.02s (20ms) - SSP-5 only, very fast mode
- **SI0005** → 0.05s (50ms) - Fast mode only
- **SI0010** → 0.10s (100ms) - Fast mode only
- **SI0050** → 0.50s (500ms) - Fast mode only
- **SI0100** → 1.00s (1000ms) - Fast or slow mode
- **SI0500** → 5.00s (5000ms) - Fast or slow mode
- **SI1000** → 10.00s (10000ms) - Fast or slow mode

**Format:** "SI" + 4-digit hundredths of a second value

### Gain Command Details

Note the **inverted** mapping for gain commands:
- Gain 1 → **SGNNN3**
- Gain 10 → **SGNNN2**
- Gain 100 → **SGNNN1**

This is consistent across all SSP models.

---

## Error Handling

### Connection Errors

**CommError Subroutine:**
```basic
SUB CommError                    'routine to print port no opened message
    print #main.textbox4, "port not open - please connect"
    #main.combo1 "selectindex 0"
    print #main.combo1, "!select"
    #main.combo2 "selectindex 0"
    print #main.combo2, "!select"
    #main.combo3 "selectindex 0"
END SUB
```

Called when CommFlag = 0 (port not open) during filter selection attempt.

### Acknowledgment Timeout

If no "!" received after 5 seconds (100 × 50ms):
1. Set Ack = 0
2. Display: "did not receive Ack from SSP - will try again"
3. Pause 2 seconds
4. Caller increments AckCounter and retries

### Maximum Retries

Commands retry up to **3 times** before giving up:

```basic
if Ack = 0 then             'if Ack not true then repeat command
    AckCounter = AckCounter + 1
    if AckCounter = 3 then  'try three times before giving up
        print #main.textbox4, "problem with SSP communication - no Ack received"
        goto [timeloop]
    else
        goto [SELECT_FILTER.Click]
    end if
    AckCounter = 0
end if
```

---

## Implementation Recommendations for SharpCap-SSP

### Phase 1: Basic Filter Support

1. **Configuration:**
   - Add AutoManual field to ssp_config.py
   - Store in dparms.txt for SSPDataq compatibility
   - Default to "M" (manual mode) initially

2. **UI Elements:**
   - Filter selection dropdown/buttons
   - Display current filter name
   - Show filter mode (Auto/Manual)

3. **Serial Commands:**
   - Implement `home_filter()` method (SHNNN)
   - Implement `select_filter(position)` method (SFNNN[1-6])
   - Reuse existing WaitForAck logic from gain/count commands

4. **Error Handling:**
   - Timeout detection (5 seconds)
   - Retry logic (3 attempts)
   - User feedback messages

### Phase 2: Enhanced Features

1. **Multi-Bar Support:**
   - Support 3 filter bars × 6 positions
   - Filter bar selection UI
   - Filter name configuration

2. **Auto-Home on Connect:**
   - When AutoManual = "A", automatically home on connection
   - Match SSPDataq behavior

3. **Filter Validation:**
   - Prevent invalid positions
   - Disable auto commands in manual mode
   - Detect mode mismatches

### Phase 3: Advanced Features

1. **Filter Optimization:**
   - Track current position to avoid unnecessary moves
   - Optimize multi-target observation sequences
   - Estimate filter change times

2. **Status Monitoring:**
   - Track filter position state
   - Detect communication failures
   - Log filter change history

---

## Code Examples for Python Implementation

### Home Filter Command

```python
def home_filter(self):
    """Home the filter bar (automatic filter mode).
    
    Sends "SHNNN" command and waits for "!" acknowledgment.
    
    Returns:
        tuple: (success: bool, message: str)
    """
    if not self.is_connected:
        return (False, "Not connected")
    
    try:
        self._clear_buffer()
        self._write("SHNNN")
        
        # Wait for acknowledgment (up to 5 seconds)
        ack_received = False
        for i in range(100):
            time.sleep(0.05)  # 50ms pause
            if self.port.BytesToRead > 0:
                response = self._read_available()
                if "!" in response:
                    ack_received = True
                    break
        
        if ack_received:
            return (True, "Filter bar homed to position 1")
        else:
            return (False, "No acknowledgment received from SSP")
            
    except Exception as e:
        return (False, "Error homing filter: " + str(e))
```

### Select Filter Position Command

```python
def select_filter(self, position):
    """Select filter position (1-6).
    
    Sends "SFNNN[position]" command and waits for "!" acknowledgment.
    
    Args:
        position: Filter position (1-6)
        
    Returns:
        tuple: (success: bool, message: str)
    """
    if not self.is_connected:
        return (False, "Not connected")
    
    if position < 1 or position > 6:
        return (False, "Invalid position. Must be 1-6")
    
    try:
        self._clear_buffer()
        time.sleep(0.01)  # 10ms pause for buffer clear
        self._write("SFNNN" + str(position))
        
        # Wait for acknowledgment (up to 5 seconds)
        ack_received = False
        for i in range(100):
            time.sleep(0.05)  # 50ms pause
            if self.port.BytesToRead > 0:
                response = self._read_available()
                if "!" in response:
                    ack_received = True
                    break
        
        if ack_received:
            return (True, "Filter moved to position " + str(position))
        else:
            return (False, "No acknowledgment received from SSP")
            
    except Exception as e:
        return (False, "Error selecting filter: " + str(e))
```

### Filter Selection with Retry Logic

```python
def select_filter_with_retry(self, position, max_retries=3):
    """Select filter with automatic retry on failure.
    
    Args:
        position: Filter position (1-6)
        max_retries: Maximum number of retry attempts (default 3)
        
    Returns:
        tuple: (success: bool, message: str)
    """
    for attempt in range(max_retries):
        success, message = self.select_filter(position)
        if success:
            return (True, message)
        
        # Failed - wait before retry
        if attempt < max_retries - 1:
            time.sleep(2.0)  # 2 second pause before retry
            print("Retry attempt " + str(attempt + 2) + " of " + str(max_retries))
        else:
            return (False, "Failed after " + str(max_retries) + " attempts: " + message)
```

---

## Configuration File Format (dparms.txt)

### Filter-Related Fields

Line 3: AutoManual mode
```
A          # A = auto 6-position, M = manual 2-position
```

Lines 4-21: Filter names (18 total)
```
B          # Filter Bar 1, Position 1
V          # Filter Bar 1, Position 2
R          # Filter Bar 1, Position 3
I          # Filter Bar 1, Position 4
U          # Filter Bar 1, Position 5
clear      # Filter Bar 1, Position 6
g          # Filter Bar 2, Position 1
r          # Filter Bar 2, Position 2
i          # Filter Bar 2, Position 3
z          # Filter Bar 2, Position 4
u          # Filter Bar 2, Position 5
Y          # Filter Bar 2, Position 6
f13        # Filter Bar 3, Position 1
f14        # Filter Bar 3, Position 2
f15        # Filter Bar 3, Position 3
f16        # Filter Bar 3, Position 4
f17        # Filter Bar 3, Position 5
f18        # Filter Bar 3, Position 6
```

Line 22: Active filter bar
```
1          # 1, 2, or 3
```

---

## Testing Recommendations

### Unit Tests

1. **Command Formatting:**
   - Verify "SHNNN" sends correctly
   - Verify "SFNNN1" through "SFNNN6" send correctly
   - Test invalid positions rejected

2. **Acknowledgment Handling:**
   - Test successful "!" reception
   - Test timeout after 5 seconds
   - Test partial data in buffer

3. **Retry Logic:**
   - Test single success
   - Test success after 1-2 retries
   - Test failure after 3 retries

### Integration Tests

1. **Hardware Connection:**
   - Connect to SSP with auto filter
   - Home filter on connection
   - Verify position 1 reached

2. **Filter Cycling:**
   - Cycle through all 6 positions
   - Verify acknowledgments received
   - Measure actual timing

3. **Error Scenarios:**
   - Disconnect during filter change
   - Test with manual filter system
   - Test with no filter system

---

## Timing Summary

| Operation | Duration | Notes |
|-----------|----------|-------|
| Home filter (SHNNN) | ~5s max | Mechanical movement |
| Select filter (SFNNN) | 1-5s | Depends on distance |
| Acknowledgment timeout | 5s | 100 × 50ms |
| Retry pause | 2s | Between attempts |
| Buffer clear pause | 10ms | Before SFNNN command |
| Per-loop check | 50ms | In WaitForAck |

**Total worst case for filter change with retries:**
- Command time: 5s
- Ack timeout: 5s
- Retry pause: 2s
- 3 attempts: (5s + 5s + 2s) × 3 = 36s maximum

---

## References

### Source Files Analyzed

- **SSPDataq3_3,21.bas** - Main acquisition program
  - Lines 152-180: dparms.txt reading (filter configuration)
  - Lines 870-920: Connection and filter homing
  - Lines 1473-1549: Filter selection click handler
  - Lines 2799-2825: WaitForAck subroutine
  - Lines 2720-2740: dparms.txt saving

- **dparms.txt** - Configuration file
  - Line 3: AutoManual$
  - Lines 4-21: Filters$(1-18)
  - Line 22: FilterBar

### Related Commands

- **SVIEW0/SVIEW1** - Flip mirror control (separate from filter)
- **SGNNN1/2/3** - Gain control (uses same ack protocol)
- **SCnnnn** - Count acquisition (different response format)

---

## Document Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-20 | pep-ssp-tools | Initial documentation from SSPDataq analysis |
| 1.1 | 2026-01-20 | pep-ssp-tools | Added critical note: SSP firmware cannot detect automated filter hardware presence. Documents that firmware always acknowledges filter commands regardless of physical hardware. Added SharpCap-SSP v0.1.2 hardware verification dialog information. |

---

## Appendix: SSPDataq Code References

### Filter Selection Handler (SSPDataq3_3,21.bas, lines 1476-1549)

```basic
[SELECT_FILTER.Click]
    #main.combo1 "selectionindex? FilterIndex"

    if TrialVersion = 1 then
        if Combo1$(FilterIndex) <> "B" and Combo1$(FilterIndex) <> "V" and FilterIndex <> 7 then
            notice "only B or V filters acceptable in this version"
            goto [timeloop]
        end if
    end if

    if AutoManual$ = "M" and FilterIndex = 7 then
        notice "Home is for auto-filter option"
        goto [timeloop]
    end if

    if AutoManual$ = "A" and FilterIndex = 7 then
        if CommFlag = 0 then            'check to see if COM port is open
            call CommError
            goto [timeloop]
        end if
        junk$ = input$(#commHandle, lof(#commHandle))  'clear buffer
        print #commHandle, "SHNNN"      'home the filter bar
        print #main.textbox4, "filter slider going to position 1"

        gosub [WaitForAck]
        if Ack = 0 then             'if Ack not true then repeat command
            AckCounter = AckCounter + 1
            if AckCounter = 3 then  'try three times before giving up
                print #main.textbox4, "problem with SSP communication - no Ack received"
                goto [timeloop]
            else
                goto [SELECT_FILTER.Click]
            end if
            AckCounter = 0
        end if

        FilterIndex = 1
        print #main.textbox4, "filter "; Combo1$(FilterIndex); " is in position"
        print #main.combo1, "selectindex 1"
        goto [timeloop]
    end if
    if AutoManual$ = "A" then
        if CommFlag = 0 then            'check to see if COM port is open
            call CommError
            goto [timeloop]
        end if
        FilterNumber = FilterIndex
        if FilterNumber >= 1 and FilterNumber <= 6 then
            junk$ = input$(#commHandle, lof(#commHandle))  'clear buffer
            call Pause 10
            print #commHandle, "SFNNN"; FilterNumber

            gosub [WaitForAck]          'wait for return ! before proceeding
            if Ack = 0 then             'if Ack not true then repeat command
                AckCounter = AckCounter + 1
                if AckCounter = 3 then  'try three times before giving up
                    print #main.textbox4, "problem with SSP communication - no Ack received"
                    goto [timeloop]
                else
                    goto [SELECT_FILTER.Click]
                end if
                AckCounter = 0
            end if

            print #main.textbox4, "filter "; Combo1$(FilterIndex); " is in position"
        end if
    else
        print #main.textbox4, "place filter "; Combo1$(FilterIndex); " in position"
    end if
    #main.combo1 "selectindex 0"
    print #main.combo1, "!";Combo1$(FilterIndex)

    if ScriptFlag = 1 then return       'return to script when finished

goto [timeloop]
```

### Connection with Auto-Home (SSPDataq3_3,21.bas, lines 903-912)

```basic
' home filter bar if automatic
if AutoManual$ = "A" then
    junk$ = input$(#commHandle, lof(#commHandle))  'clear buffer
    print #commHandle, "SHNNN"  'home the filter bar
    print #main.textbox4, "filter slider going to position 1"
    gosub [WaitForAck]
    print #main.textbox4, "filter "; Combo1$(1); " is in position"
    FilterIndex = 2  ' Internal variable set to 2 for next operation
    print #main.combo1, "selectindex 1"  ' UI shows position 1 (array index 1)
end if
```

**Note:** The code sets FilterIndex to 2 after homing. This is the internal tracking variable for the next filter selection operation, while the UI correctly shows position 1 is active ("selectindex 1" refers to Combo1$(1)).

---

*End of Document*
