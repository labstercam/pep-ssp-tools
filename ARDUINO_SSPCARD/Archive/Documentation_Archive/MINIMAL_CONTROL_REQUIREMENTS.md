# Minimal Control Requirements for SSP5A Software Control

## Overview
To maintain full software control of the SSP5A photometer while eliminating the SSPCARD, we need to preserve three critical functions:
1. **Gain control** (1×, 10×, 100×)
2. **Integration time control** (0.001s to 32.78s)
3. **Pulse reading** (photometry data)

This document analyzes what's required and whether a simple TTL-to-USB serial board can be used.

## Critical Analysis of SSPCARD Functions

### Function 1: Gain Control
**Original SSPCARD Function:**
- Receives `SGNNN1` (gain 100), `SGNNN2` (gain 10), `SGNNN3` (gain 1)
- **Inverted mapping**: `SGNNN1` = 100×, `SGNNN2` = 10×, `SGNNN3` = 1×
- Controls analog gain circuitry in SSP5A
- Likely switches resistor networks or amplifier stages
- Response: "!" when complete (~1s timing)

**Critical Question:** Where does the SSPCARD connect to control gain in the SSP5A?

**Answer Needed:** We need to identify:
1. Are there separate gain control pins on the SSP5A connector?
2. Does gain control happen inside SSPCARD or SSP5A?
3. What signals/pins control gain switching?

### Function 2: Integration Time Control
**Original SSPCARD Function:**
- Receives `SInnnn` commands (SI0002, SI0010, SI0100, etc.)
- Controls 8254-2 programmable timer chip:
  - **Timer 0**: Square wave generator (1 KHz reference)
  - **Timer 1**: Digital one-shot (integration duration = N × 0.001 sec)
  - **Timer 2**: Event counter (counts photometer pulses)
- Integration range: 0.001 to 32.780 seconds (N = 1 to 32768)
- Crystal controlled for precision (±5ppm at 25°C)

**Critical Question:** Where does integration time control happen?

### Function 3: Pulse Reading
**Original SSPCARD Function:**
- Receives raw pulses from SSP5A Pin 9 (center pin of 2-pin phono)
- Counts using Timer 2 of 8254 chip (16-bit binary counter)
- Maximum count rate: 10 MHz
- Count range: 0 to 65535 (overflow at 65,536)
- Returns formatted "C=XXXXX" via serial (5-digit count)
- Signal ground on Pin 5 (shell of 2-pin phono)

## Can We Use a Simple TTL-to-USB Serial Board?

### **Yes, BUT with Limitations:**

**What a TTL-to-USB Serial Board CAN Do:**
1. **Serial Communication**: Send/receive commands at 19200 baud
2. **Pulse Reading**: If pulses are TTL-level (0-5V), could count them
3. **Basic Control**: Send commands to something that interprets them

**What a TTL-to-USB Serial Board CANNOT Do:**
1. **Gain Control**: No analog switching capability
2. **Integration Time Control**: No 8254 timer chip functionality
3. **Pulse Processing**: No 16-bit hardware counter (Timer 2)
4. **Stepper Control**: No SAA1027 driver or phase control circuitry

## Serial Protocol Information from Technical Manual

### **Communication Parameters:**
- **Baud Rate**: 19200 fixed
- **Data Format**: 8 data bits, no parity, 1 stop bit
- **Flow Control**: None (ds0,cs0 in connection string)
- **Connector**: Standard DB-9 or DB-25 RS-232
- **Cable**: Shielded RS-232 cable recommended (up to 15 meters)

### **Command Structure:**
All commands follow: `S + CommandLetter + Parameters`
- `S` = Start character (all commands start with 'S')
- `CommandLetter` = Single character identifying command type
- `Parameters` = Command-specific parameters

### **Critical Commands to Emulate:**
```
SSSSSS     Enter serial mode (responds with "!" or CR)
SEEEEE     Exit serial mode
SInnnn     Set integration time (nnnn = 0002 to 32768)
SGNNNx     Set gain (x = 1,2,3 where 1=100×, 2=10×, 3=1×)
SCnnnn     Start count (returns "C=XXXXX")
SHNNN      Home filter
SFNNNn     Select filter (n = 1-6)
SVIEWx     Set mirror position (x = 0 or 1)
```

### **Integration Time Mapping Examples:**
```
SI0002 = 0.002 seconds (20ms) - SSP-5 only (Very Fast mode)
SI0005 = 0.005 seconds (50ms) - Fast mode
SI0010 = 0.010 seconds (100ms) - Fast mode
SI0050 = 0.050 seconds (500ms) - Fast mode
SI0100 = 1.000 seconds (1s) - Slow/Fast mode
SI0500 = 5.000 seconds (5s) - Slow mode
SI1000 = 10.000 seconds (10s) - Slow mode
```

### **Gain Command Mapping (Inverted):**
```
SGNNN1 = Gain 100 (highest sensitivity)
SGNNN2 = Gain 10
SGNNN3 = Gain 1 (lowest sensitivity)
```

### **SSPCARD Base Address Switch Settings (Table 3-1):**
The SSPCARD uses a 6-position dip switch to set base address (200H to 3F8H range):
```
Position  Value added if "open"  Default
─────────────────────────────────────────
1         8H (8)                 on
2         10H (16)               on
3         20H (32)               on
4         40H (64)               on
5         80H (128)              on
6         100H (256)             open
```

**Factory default**: Only position 6 open = 300H (200H + 100H = 768 decimal)

### **I/O Port Requirements:**
- Requires 8 consecutive I/O ports (base address through base address + 7)
- Typical range: 300H to 317H (768 to 791 decimal) for prototype cards
- Must not conflict with other cards in system

## Required Hardware for Full Software Control

### **Option 1: Complete Microcontroller Solution**

**Components Needed:**
```
1. Microcontroller (Arduino/Teensy) with USB
2. Pulse Counter Circuit (74HC4040 or MCU timer)
3. Gain Control Circuit (Digital pot or analog switches)
4. Stepper Driver (if automated filter control needed)
5. Integration Timer (MCU timers can do this)
```

**Block Diagram:**
```
SSP5A → Interface Board → Microcontroller → USB → Computer
        │                     │
        ├→ Pulse Input → Counter/Timer
        ├→ Gain Control Pins → Digital Pot
        └→ Stepper Pins → Driver (if automated)
```

### **Option 2: Simplified Solution (Manual Filters)**

**Components:**
```
1. Microcontroller (for gain/integration/pulse counting)
2. Gain Control Circuit
3. Pulse Counter
4. Manual filter control (switches)
```

**Preserves:** Gain control, integration control, pulse reading
**Eliminates:** Automated filter control

## Pin Connection Analysis

### **Known SSP5A Pins:**
```
1. Red: +12V to stepper
2. Yellow: T4 to stepper
3. Brown: T3 to stepper
4. Orange: T2 to stepper
5. Green: Signal common
6. Orange: +12V DC (logic power)
7. Black: T1 to stepper
8. Brown: Power ground
9. Gray: Pulse output
```

### **Complete Pinout from SSPCard Technical Manual (Table 3-3):**
```
15-pin D-connector  9-pin circular  2-pin phono  Function
────────────────────────────────────────────────────────────
1                   1               -            +12V to stepper motor
2                   3               -            Pin 11 on SAA1027 driver
3                   7               -            Pin 9 on SAA1027 driver
4                   2               -            Pin 8 on SAA1027 driver
5                   5               shell        Signal Ground
6                   6               -            +12V to photometer
7                   4               -            Pin 6 on SAA1027 driver
8                   8               -            Power return for photometer
9                   9               center       Pulse count from photometer
10                  -               -            Input D4 (future use)
11                  -               -            Output D2 (future use)
12                  -               -            Output D1 (see Note 1)
13                  -               -            Output D0 (future use)
14                  -               -            Input D1 (future use)
15                  -               -            Input D0 (future use)
```

**Note 1:** Output D1 connected to pin 12 only if jumper JP2 is in the 2-3 position. Normally JP2 is 1-2 connecting Output D1 to reset pin of SAA1027 stepper motor controller.

### **SSPCARD Power Requirements:**
- **Stepper motor**: +12V @ ~250 mA (Pin 1)
- **Photometer logic**: +12V @ ~100 mA (Pin 6)
- **Total current**: ~350 mA maximum
- **Onboard fuse**: 500 mA fast-acting (type GMA)

### **Missing Information:**
We need to identify:
1. **Gain control pins**: Where does SSPCARD connect to control gain?
2. **Integration control pins**: How does SSPCARD set integration time?
3. **Other control pins**: Are there undocumented pins?

### **SSPCARD Technical Specifications (from Technical Manual):**

#### **Integration Timing:**
- **Range**: 0.001 to 32.780 seconds
- **Increment**: 0.001 seconds
- **Precision**: ±5ppm at 25°C
- **Temperature Coefficient**: +10/-120 ppm
- **Timing Source**: Crystal controlled programmable oscillator

#### **Counter Specifications:**
- **Range**: 0 to 65535 counts (16-bit binary counter)
- **Maximum Count Rate**: 10 MHz
- **Overflow**: At 65,536 counts
- **Counter IC**: 8254-2 programmable timer (Timer 2 for counting)

#### **Stepper Motor Control:**
- **Driver IC**: Philips SAA1027
- **Motor Type**: 4-phase unipolar stepper
- **Voltage**: 12V DC
- **Current per phase**: 375 mA max (800 mA total)
- **Steps per filter position**: 33 full steps
- **Time per position change**: 0.5 seconds normally

#### **Stepping Sequence (4-step full step):**
```
Step  T1  T2  T3  T4  Description
─────────────────────────────────
1     On  On  Off Off Phase A energized (A+ & A-)
2     Off On  On  Off Transition (A- & B+)
3     Off Off On  On  Phase B energized (B+ & B-)
4     On  Off Off On  Transition (A+ & B-)
─────────────────────────────────
CW Rotation: 1→2→3→4→1
CCW Rotation: 1→4→3→2→1
```

## Reverse Engineering Approach

### **Step 1: Examine SSP5A Internals**
**Look for:**
1. Gain switching circuitry inside SSP5A
2. Integration timing components
3. Connections to the 9-pin connector

### **Step 2: Trace SSPCARD Connections**
**Identify:**
1. Which pins on SSPCARD connect to gain control?
2. Which pins control integration timing?
3. What other functions exist?

### **Step 3: Test Signals**
**Measure:**
1. Pulse output characteristics (voltage, frequency)
2. Gain control signals (voltages when commands sent)
3. Integration control signals

## Minimal Viable Solution

### **If We Only Need Pulse Reading + Manual Everything Else:**

**Hardware:**
```
TTL-to-USB Serial Board → Pulse Conditioning Circuit → SSP5A Pin 9
Manual Switches → SSP5A Stepper Pins (1,2,3,4,7)
Manual Gain Switch → SSP5A Gain Pins (if accessible)
Manual Integration → Not possible - SSP5A controls this
```

**Problem:** Integration time MUST be controlled by SSP5A/SSPCARD. Without SSPCARD, we can't set integration times programmatically.

## Integration Time Control Criticality

### **The Challenge:**
Integration time control is handled by the 8254-2 programmable timer on the SSPCARD:
- **Timer 0**: Square wave generator (1 KHz reference from crystal ÷ 2)
- **Timer 1**: Digital one-shot (sets integration duration = N × 0.001 sec)
- **Timer 2**: Event counter (counts photometer pulses)
- **Range**: 0.001 to 32.780 seconds (N = 1 to 32768)

Without SSPCARD, we lose:
1. **Crystal precision** (±5ppm at 25°C)
2. **8254 timer functionality**
3. **Precise 0.001s resolution**

### **Replacement Solutions:**
1. **Microcontroller timers**: Can emulate 8254 functionality (less precise)
2. **External timer IC**: 8254 compatible chip
3. **Software timing**: Acceptable for some applications
4. **External crystal oscillator**: For higher precision

## Gain Control Criticality

### **The Challenge:**
Gain switching requires specific analog circuitry inside SSPCARD/SSP5A.

### **From Technical Manual:**
- Gain switching is electronic within SSPCARD
- Commands use inverted mapping: `SGNNN1`=100×, `SGNNN2`=10×, `SGNNN3`=1×
- Response: "!" when complete (~1s timing)

### **Possible Solutions:**
1. **Digital potentiometer** (MCP41xxx series) - for resistive gain control
2. **Analog switches** (CD4051, ADG series) - for switching gain stages
3. **Programmable gain amplifier** (PGA) - integrated solution
4. **Relay switching** - mechanical, slower but simple
5. **Discover SSP5A gain control pins** - if accessible on 9-pin connector

## Recommended Investigation Steps

### **Immediate Actions:**
1. **Examine SSP5A circuit board** for gain/integration components
2. **Trace 9-pin connector** to internal circuits
3. **Measure signals** during SSPCARD operation (if available)

### **If SSPCARD is Available for Testing:**
1. **Monitor serial commands** and corresponding pin voltages
2. **Identify which pins change** for gain/integration commands
3. **Reverse engineer control protocol**

### **If No SSPCARD Available:**
1. **Test pulse output** with various light levels
2. **Check if gain changes** with external switches
3. **Measure integration behavior** with timing tests

## Practical Interim Solution

### **While Investigating Full Control:**

**Build This Now:**
```
1. TTL-to-USB Serial Board → Read pulses (Pin 9)
2. Manual Filter Control → Switches (Pins 1,2,3,4,7)
3. Fixed Gain → Use SSP5A default (likely 10×)
4. Fixed Integration → Use SSP5A default (likely 1s or 5s)
```

**Software Workaround:**
- Use SSPDataq3 in manual mode
- Set gain/integration once at beginning
- Manually change filters when prompted

## Programming Examples from SSPCard Technical Manual

### **Initialization Sequence (QuickBasic):**
```basic
' Timer 0 to generate a square wave
OUT BASEADDRESS% + 7, 54

' Timer 1 to operate as a digital one shot
OUT BASEADDRESS% + 7, 114

' Timer 2 to operate as an event counter
OUT BASEADDRESS% + 7, 176

' Write divide by 2 to Timer 0 to generate 1 KHz square wave
OUT BASEADDRESS% + 4, 2
OUT BASEADDRESS% + 4, 0

' Write 1000 to Timer 1 to generate a 1 second pulse
OUT BASEADDRESS% + 5, 1000 MOD 256
OUT BASEADDRESS% + 5, 1000 \ 256

' Set output port bit #1 to 1 (enable stepper motor controller)
OUT BASEADDRESS% + 1, 2
```

### **Count Reading Sequence:**
```basic
' Clear Timer 2 counter
OUT BASEADDRESS% + 6, 255
OUT BASEADDRESS% + 6, 255

' Strobe bit 2 of 4-bit control port to initiate counting
OUT BASEADDRESS%, 4
OUT BASEADDRESS%, 0

' Poll Timer 1 status until bit 7 is 1 indicating count complete
DO
    OUT BASEADDRESS% + 7, 228
LOOP UNTIL (INP(BASEADDRESS% + 5) AND 128) = 128

' Read Timer 2 counter (16-bit value)
FREQUENCY# = INP(BASEADDRESS% + 6) + INP(BASEADDRESS% + 6) * 256#
FREQUENCY# = 65536# - FREQUENCY#
```

### **SSPCARD I/O Port Map (from Table 4-1):**
```
Base + 0: 4-bit Control Port (stepper index, direction, timer gate, interrupt enable)
Base + 1: 3-bit Output Port (pins 13, 12/stepper reset, 11)
Base + 2: 3-bit Input Port (pins 15, 14, 10)
Base + 3: Not Used
Base + 4: Timer 0 Counter and Status Port
Base + 5: Timer 1 Counter and Status Port
Base + 6: Timer 2 Counter and Status Port
Base + 7: Timer Control Word Port
```

## Cost and Complexity

### **Simple Solution (Pulse Reading Only):**
```
TTL-to-USB Serial Board:    $5
Pulse Conditioning:         $5
Manual Switches:           $15
──────────────────────────────
Total:                     $25
```

### **Complete Solution (Full Control):**
```
Microcontroller:           $10
Gain Control Circuit:      $20
Pulse Counter:             $10
Stepper Driver:           $15 (if automated)
PCB/Enclosure:            $20
──────────────────────────────
Total:                     $75
```

## Key Questions to Answer

### **Before Proceeding:**
1. **Does SSP5A have separate gain control pins?**
2. **Does SSP5A have integration control pins?**
3. **Can we operate SSP5A with fixed gain/integration?**
4. **What is the pulse output format?** (TTL? Analog?)

### **Investigation Methods:**
1. **Circuit tracing**: Follow SSP5A PCB traces
2. **Signal measurement**: With oscilloscope
3. **Command monitoring**: If SSPCARD available
4. **Documentation search**: Optec manuals/schematics

## Conclusion

The **SSPCARD Technical Manual provides critical new information** that clarifies our requirements:

### **Key Technical Specifications Now Known:**
1. **Integration timing**: 0.001s to 32.78s range with crystal precision (±5ppm)
2. **Counter specifications**: 16-bit hardware counter (8254 Timer 2), 10 MHz max rate
3. **Stepper control**: SAA1027 driver, 33 steps/position, specific phase sequence
4. **Complete pinout**: 15-pin to 9-pin mapping with all functions identified
5. **Power requirements**: 12V @ ~350mA total, 500mA fuse protection
6. **Protocol details**: Complete command set with inverted gain mapping

A **simple TTL-to-USB serial board CANNOT provide full control** because it lacks:
1. **8254 timer functionality** for precise integration timing
2. **SAA1027 stepper driver** for motor phase control
3. **Analog switching circuitry** for gain control
4. **16-bit hardware counter** for pulse counting

**However**, modern microcontrollers can emulate all SSPCARD functions:
1. **Arduino timers** can replace 8254 functionality (less precise)
2. **TB6600/A4988 drivers** can replace SAA1027 (with phase conversion)
3. **Digital pots/analog switches** can replace gain circuitry
4. **Hardware interrupts/timers** can count pulses precisely

### **Updated Path Forward:**

**Phase 1: Investigation (1-2 weeks)**
1. **Examine SSP5A circuit board** to identify gain control connections
2. **Test pulse signal** on Pin 9 with oscilloscope
3. **Trace SAA1027 connections** to understand stepper interface

**Phase 2: Prototype (2-4 weeks)**
1. **Build pulse counting prototype** with Arduino interrupt
2. **Add stepper control** with TB6600 driver (convert SAA1027 to STEP/DIR)
3. **Implement gain control** with digital potentiometer
4. **Emulate SSP protocol** for SSPDataq3 compatibility

**Phase 3: Integration (1-2 weeks)**
1. **Combine all functions** on custom PCB
2. **Test with SSPDataq3** software
3. **Verify timing accuracy** and functionality

**Phase 4: Production (optional)**
1. **Design custom PCB** based on working prototype
2. **Order small batch** for community testing
3. **Document and share** design files

### **Immediate Actions:**
1. **Review SSP5A internal circuitry** to locate gain control connections
2. **Test pulse output characteristics** with various light levels
3. **Begin Arduino prototype** for pulse counting and basic command parsing

The SSPCard Technical Manual has provided the missing pieces needed to design a complete replacement. With this information, building a functional SSPCARD replacement is now a well-defined engineering task rather than a reverse-engineering mystery.