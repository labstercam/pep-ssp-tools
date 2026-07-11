# SSP5A Manual Filter Operation Conversion Guide

## Overview
This guide explains how to convert an SSP5A photometer from automated filter control to manual operation. There are two approaches:
1. **Complete manual conversion** - Remove SSPCARD, operate filters manually
2. **Manual trigger conversion** - Keep SSPCARD but add manual control options
3. **Software-only workaround** - Use SSPDataq3 in manual mode

## Understanding the SSP5A Filter System

### Original Automated System
```
SSPDataq3 → Serial Commands → SSPCARD → SAA1027 Driver → Stepper Motor → Filter Wheel
```

### Filter Wheel Mechanics
- **6 positions**: U, B, V, R, I, Dark (typically)
- **Stepper motor**: 4-phase unipolar, 12V operation
- **Position sensing**: Likely no sensors (open-loop control)
- **Homing**: Moves to "home" position then counts steps to other positions

## Approach 1: Complete Hardware Conversion to Manual

### Step 1: Remove SSPCARD Dependency

**New Wiring Diagram:**
```
SSP5A Original → Manual Control Board
┌────────────────────────────────────────────┐
│ SSP5A Pin  Function  →  Manual Control     │
├────────────────────────────────────────────┤
│ 1  +12V Stepper  →  Disconnect (cap)       │
│ 2  T4 (Phase 4)  →  Manual switch panel    │
│ 3  T3 (Phase 3)  →  Manual switch panel    │
│ 4  T2 (Phase 2)  →  Manual switch panel    │
│ 5  Signal GND    →  Common ground          │
│ 6  +12V Logic    →  Keep for pulse circuit │
│ 7  T1 (Phase 1)  →  Manual switch panel    │
│ 8  Power GND     →  Keep                   │
│ 9  Pulse Output  →  Keep for photometry    │
└────────────────────────────────────────────┘
```

### Step 2: Build Manual Control Panel

**Simple 4-Switch Design:**
```
Component List:
- 4x SPST toggle switches (T1, T2, T3, T4)
- 1x Rotary switch (6 positions for filters)
- 1x LED indicator (position confirmation)
- 1x 12V power supply
- Project box and wiring

Wiring:
Switch T1 → SSP5A Pin 7 (Black)
Switch T2 → SSP5A Pin 4 (Orange)
Switch T3 → SSP5A Pin 3 (Brown)
Switch T4 → SSP5A Pin 2 (Yellow)
Common → SSP5A Pin 1 (+12V via current limiter)
```

**Position Switch Settings:**
```
Filter  Position  Switches (T1 T2 T3 T4)  Rotary Position
────────────────────────────────────────────────────────
U (1)   Step 0    1   1   0   0           Position 1
B (2)   Step 1    0   1   1   0           Position 2
V (3)   Step 2    0   0   1   1           Position 3
R (4)   Step 3    1   0   0   1           Position 4
I (5)   Step 4    1   1   0   0           Position 5
Dark(6) Step 5    0   1   1   0           Position 6
```

**Note**: Steps 4-5 repeat the sequence since there are only 4 unique phase combinations for a 6-position wheel.

### Step 3: Power Management

**Stepper Motor Power:**
- Original: SSPCARD provides +12V via Pin 1
- Manual: Need external 12V supply with current limiting
- **Important**: Add 1A fuse for motor protection

**Circuit:**
```
12V Supply → 1A Fuse → ON/OFF Switch → Manual Control Panel → Stepper Motor
```

### Step 4: Pulse Output Preservation

**Critical**: The pulse output (Pin 9) must remain connected to the computer for photometry. This circuit is independent of filter control.

**Preserve These Connections:**
- Pin seat (Gray): Pulse output to computer
- Pin 5 (Green): Signal ground
- Pin 6 (Orange): +12V logic power (for detector circuits)
- Pin 8 (Brown): Power ground

### Step 5: Software Configuration

**Configure SSPDataq3 for Manual Mode:**
1. Edit `dparms.txt`:
   ```
   Line 3: AutoManual$ = "M"  # M for Manual mode
   ```
2. Set up filters in SSPDataq3 Setup menu
3. When prompted during observation, manually change filters

## Approach 2: Manual Trigger with SSPCARD Retention

### Keep SSPCARD but Add Manual Control

**Circuit:**
```
Manual Trigger Button → Relay/Transistor → SSPCARD Filter Command Pins
                           │
Computer Serial Commands ──┘
```

### Option A: Parallel Manual Control

**Add manual buttons that simulate serial commands:**
```
Components:
- 6x Momentary push buttons (one per filter)
- Arduino Nano (to generate serial commands)
- 2x SPDT relays (computer/manual selection)

Operation:
1. Normally: Computer controls via serial
2. Manual mode: Buttons send "SFNNN1" through "SFNNN6" commands
```

**Arduino Code for Manual Trigger:**
```cpp
#include <SoftwareSerial.h>

SoftwareSerial sspSerial(2, 3); // RX, TX

void setup() {
    sspSerial.begin(19200);
    
    // Configure button inputs
    for(int i = 4; i <= 9; i++) {
        pinMode(i, INPUT_PULLUP);
    }
}

void loop() {
    // Check each filter button
    for(int filter = 1; filter <= 6; filter++) {
        if(digitalRead(filter + 3) == LOW) { // Button pressed
            select_filter(filter);
            delay(200); // Debounce
        }
    }
}

void select_filter(uint8_t filter) {
    char command[7];
    sprintf(command, "SFNNN%d", filter);
    sspSerial.print(command);
    
    // Wait for acknowledgment
    delay(1000); // SSPCARD needs time to move
}
```

### Option B: Hardware Bypass Switch

**Add DPDT switch to choose control source:**
```
Position 1: Computer Control
  Computer TX → SSPCARD RX
  Computer RX ← SSPCARD TX

Position 2: Manual Control
  Arduino TX → SSPCARD RX
  Manual Buttons → Arduino Inputs
```

## Approach 3: Software-Only Workaround

### Use SSPDataq3's Built-in Manual Mode

**Configuration:**
1. **Set AutoManual$ = "M"** in dparms.txt
2. **Configure filter names** in Setup → Filter Bar Setup
3. **During observation**:
   - When filter change needed, SSPDataq3 shows dialog
   - Manually move filter wheel
   - Click "OK" to continue

**SSPDataq3 Manual Mode Behavior:**
- No serial commands sent for filter changes
- User prompted when filter needs changing
- Timing pauses while user changes filter
- Resume automatically after confirmation

### Custom Script for Manual Operation

**Create .ssp script file:**
```
LOADCATALOG,Astar
FILTER,U
GAIN,10
INTEG,5
INTERVAL,3
OBJECT,HD12345
COUNT
PAUSE,30          # Time to manually change filter
FILTER,B
COUNT
PAUSE,30
FILTER,V
COUNT
# etc...
```

**Advantage**: Automated timing with manual filter changes

## Detailed Hardware Conversion Instructions

### Method A: Direct Switch Control (Simplest)

**Components Required:**
- 4x SPST toggle switches
- 1x 6-position rotary switch
- Project enclosure
- 12V DC power supply (2A recommended)
- Wire, connectors, fuse holder

**Wiring Instructions:**

1. **Power Connection:**
   ```
   12V+ → Fuse → Master Switch → Terminal Block
   GND → Terminal Block
   ```

2. **Switch Wiring:**
   ```
   Terminal Block +12V → Rotary Switch Common
   Rotary Position 1 → T1 & T2 switches common
   Rotary Position 2 → T2 & T3 switches common
   Rotary Position 3 → T3 & T4 switches common
   Rotary Position 4 → T4 & T1 switches common
   Rotary Position 5 → T1 & T2 switches common (repeat)
   Rotary Position 6 → T2 & T3 switches common (repeat)
   ```

3. **Output to SSP5A:**
   ```
   T1 Switch Output → SSP5A Pin 7
   T2 Switch Output → SSP5A Pin 4
   T3 Switch Output → SSP5A Pin 3
   T4 Switch Output → SSP5A Pin 2
   ```

4. **Power to Stepper:**
   ```
   Terminal Block +12V → SSP5A Pin 1
   Terminal Block GND → SSP5A Pin 8
   ```

### Method B: Microcontroller-Based Manual Control

**More flexible but more complex:**

**Components:**
- Arduino Nano
- 6x momentary push buttons
- 4x MOSFETs or relays (for T1-T4)
- 12V to 5V voltage regulator

**Circuit:**
```
Arduino Pins D8-D11 → MOSFET Gates → SSP5A Pins 7,4,3,2
6x Buttons → Arduino Analog Input (voltage divider)
12V → Voltage Regulator → Arduino 5V
```

**Code for Manual Stepping:**
```cpp
// Define output pins for T1-T4
const int t1 = 8;
const int t2 = 9;
const int t3 = 10;
const int t4 = 11;

// Define button pins (analog multiplex)
const int buttonPin = A0;

// Current position (0-5 for 6 filters)
int current_pos = 0;

// Phase table for 4-step sequence
bool phases[6][4] = {
    {1,1,0,0}, // Position 0/U
    {0,1,1,0}, // Position 1/B
    {0,0,1,1}, // Position 2/V
    {1,0,0,1}, // Position 3/R
    {1,1,0,0}, // Position 4/I (repeat)
    {0,1,1,0}  // Position 5/Dark (repeat)
};

void setup() {
    pinMode(t1, OUTPUT);
    pinMode(t2, OUTPUT);
    pinMode(t3, OUTPUT);
    pinMode(t4, OUTPUT);
    
    // Set initial position
    set_position(0);
}

void loop() {
    // Read button press
    int buttonValue = analogRead(buttonPin);
    
    // Determine which button pressed
    int button = read_button(buttonValue);
    
    if(button >= 0 && button <= 5) {
        // Move to selected position
        set_position(button);
        delay(500); // Movement time
    }
}

void set_position(int pos) {
    current_pos = pos;
    
    digitalWrite(t1, phases[pos][0]);
    digitalWrite(t2, phases[pos][1]);
    digitalWrite(t3, phases[pos][2]);
    digitalWrite(t4, phases[pos][3]);
}

int read_button(int analogValue) {
    // Button mapping via voltage divider
    if(analogValue < 50) return 0;   // Button 0/U
    if(analogValue < 150) return 1;  // Button 1/B
    if(analogValue <}x0) return 2;   // Button 2/V
    if(analogValue < 350) return 3;  // Button 3/R
    if(analogValue < 450) return 4;  // Button 4/I
    if(analogValue < 550) return 5;  // Button 5/Dark
    return -1; // No button
}
```

## Software Considerations

### SSPDataq3 Configuration for Manual Mode

**1. Edit dparms.txt:**
```
Line 3: AutoManual$ = "M"          # Manual filter mode
Line 23: NightFlag = 1             # Optional: Night mode
Line 30: FilterSystem$ = "1"       # 1=Johnson/Cousins, 0=Sloan
```

**2. Filter Setup in SSPDataq3:**
- Go to Setup → Filter Bar Setup
- Enter filter names for positions 1-6
- Typical: U, B, V, R, I, Dark
- Save configuration

**3. Observation Workflow:**
```
1. Select filter from dropdown
2. Click START
3. When filter change needed:
   - Dialog appears: "Change filter to X"
   - Manually rotate filter wheel
   - Click OK to continue
4. Data collection resumes
```

### Alternative Software: SharpCap-SSP

The Python reimplementation supports manual mode natively:

**Configuration:**
```python
# In SSPDataq3.py or configuration
auto_filter = False  # Set to False for manual mode
```

**Operation:**
- Filter dropdown selects desired filter
- User prompted to manually change filter
- Software waits for confirmation
- Timing adjusted automatically

## Safety Considerations

### Electrical Safety
1. **Fuse protection**: Always include 1A fuse on +12V line
2. **Proper grounding**: Connect all grounds together
3. **Voltage rating**: Ensure switches rated for 12V DC, 1A
4. **Insulation**: Properly insulate all connections

### Mechanical Safety
1. **Smooth operation**: Ensure filter wheel moves freely
2. **Position stops**: Consider adding mechanical stops
3. **Locking mechanism**: Filter should stay in position
4. **Force limitation**: Don't force if stuck

### Photometer Protection
1. **Power sequencing**: Don't apply power to stepper while changing
2. **Pulse circuit**: Keep pulse output circuit isolated
3. **Detector protection**: Avoid moving while measuring
4. **Cable management**: Don't strain SSP5A connector

## Troubleshooting

### Problem: Filter Doesn't Move
**Check:**
1. Power supply (12V present?)
2. Switch connections (continuity?)
3. Stepper motor (coil resistance?)
4. SSP5A connector (proper seating?)

### Problem: Wrong Filter Position
**Check:**
1. Switch settings (correct phase pattern?)
2. Starting position (known reference?)
3. Step sequence (following correct order?)

### Problem: SSPDataq3 Won't Connect
**Check:**
1. dparms.txt configuration (AutoManual$ = "M")
2. COM port settings (correct port selected?)
3. Pulse circuit (Pin 9 connected to computer?)

### Problem: Inconsistent Photometry
**Check:**
1. Filter positioning (repeatable?)
2. Timing (manual changes consistent?)
3. Software configuration (filter names match?)

## Cost Analysis

### Option A: Basic Manual Control
```
4x Toggle switches:          $10
6-Position rotary switch:    $8
Project box:                 $5
Wire, connectors:            $5
12V Power supply:            $15
Fuse holder:                 $3
─────────────────────────────────
Total:                      $46
```

### Option B: Enhanced Manual Control
```
Arduino Nano:                $5
6x Momentary buttons:        $6
4x MOSFETs:                  $4
Prototype board:             $5
Enclosure:                  $10
Power supply:               $15
─────────────────────────────────
Total:                      $45
```

### Option C: Professional Manual Control
```
Custom PCB:                 $25
Industrial switches:        $20
Metal enclosure:            $30
Quality power supply:       $25
Connectors:                 $15
─────────────────────────────────
Total:                      $115
```

## Recommended Approach

### For Occasional Use: Software-Only Workaround
- **Cost**: $0
- **Effort**: Minimal
- **Best for**: Users who rarely change filters

### For Regular Use: Basic Manual Control
- **Cost**: ~$46
- **Effort**: Moderate (basic wiring)
- **Best for**: Most users, reliable operation

### For Observatory Use: Enhanced Manual Control
- **Cost**: ~$45-$115
- **Effort**: Higher (circuit design)
- **Best for**: Frequent use, multiple users

## Step-by-Step Conversion Process

### Week 1: Planning and Parts Acquisition
1. **Assess current setup**: Does SSPCARD work at all?
2. **Choose approach**: Based on usage patterns
3. **Order parts**: From recommended list
4. **Prepare workspace**: Tools, soldering equipment

### Week 2: Hardware Construction
1. **Build control panel**: Wire switches, test continuity
2. **Connect to SSP5A**: Careful connector mating
3. **Test power**: Verify 12V at stepper pins
4. **Test movement**: Verify all positions work

### Week 3: Software Configuration
1. **Configure SSPDataq3**: Set manual mode
2. **Test workflow**: Complete observation sequence
3. **Refine timing**: Adjust manual change intervals
4. **Document setup**: Record all settings

### Week 4: Verification and Refinement
1. **Test photometry**: Compare with automated results
2. **Check repeatability**: Multiple filter cycles
3. **Optimize workflow**: Streamline manual process
4. **Finalize documentation**: Complete guide for future use

## Long-Term Maintenance

### Regular Checks
1. **Switch contacts**: Clean annually
2. **Connectors**: Check for corrosion
3. **Wiring**: Inspect for wear
4. **Power supply**: Verify voltage output

### Performance Monitoring
1. **Filter positioning**: Consistency over time
2. **Photometric stability**: Compare with standards
3. **Timing accuracy**: Manual vs. automated
4. **User feedback**: Adjust workflow as needed

## Conclusion

Converting SSP5A to manual filter operation is straightforward and cost-effective. The simplest approach uses basic switches and maintains compatibility with SSPDataq3 software through its built-in manual mode.

**Key recommendations:**
1. **Start with software-only approach** to test workflow
2. **Build basic manual control** if regular filter changes needed
3. **Consider microcontroller option** for flexibility
4. **Always preserve pulse circuit** for photometry

Manual operation has advantages:
- **Simpler**: No complex electronics
- **Reliable**: Fewer failure points
- **Intuitive**: Direct physical control
- **Cost-effective**: Minimal components

The total cost is under $50 and the conversion can be completed in a weekend for most users.