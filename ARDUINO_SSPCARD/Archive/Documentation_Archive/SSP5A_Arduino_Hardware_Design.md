# SSP5A Arduino Controller - Hardware Design & Wiring Instructions

## Overview
This document provides complete hardware design and wiring instructions for building an Arduino-based microcontroller to replace the SSPCARD for SSP5A photometer control. The design uses an Arduino Uno R3, CNC Shield V3, and DRV8825 stepper drivers.

## Components Available
1. Arduino Uno R3
2. CNC Shield V3 (with 4x DRV8825 drivers)
3. 4x heatsinks for DRV8825
4. SSP5A photometer with 9-pin round cable

---

## 1. SSP5A 9-Pin Connector Pinout and Arduino Mapping

### SSP5A 9-Pin Connector Details:
| Pin | Color   | Function        | Voltage/Current | Arduino Connection |
|-----|---------|-----------------|-----------------|--------------------|
| 1   | Red     | +12V Stepper    | +12V @ 500mA    | CNC Shield +12V IN |
| 2   | Yellow  | T4 (Phase 4)    | 12V switched    | Stepper B- (Y- axis) |
| 3   | Brown   | T3 (Phase 3)    | 12V switched    | Stepper B+ (Y+ axis) |
| 4   | Orange  | T2 (Phase 2)    | 12V switched    | Stepper A- (X- axis) |
| 5   | Green   | Signal Ground   | GND             | Arduino GND |
| 6   | Orange  | +12V Logic      | +12V @ 100mA    | 12V Regulator IN |
| 7   | Black   | T1 (Phase 1)    | 12V switched    | Stepper A+ (X+ axis) |
| 8   | Brown   | Power Ground    | GND             | Power GND |
| 9   | Gray    | Pulse Output    | TTL pulses (0-5V) | Arduino INT0 (Pin 2) |

**Important Note** - The Pin numbers are correct, however the wire colours of the SSP5A round 9 pin connector might differ. Ensure you follow the pin numbers and trace the wires with a multi-meter to ensure the connections are correct.


### Pulse Output Details:
- **Signal Type**: TTL-level pulses (likely 0-5V)
- **Pulse Width**: 1-10µs typical
- **Frequency Range**: 0-50kHz (depends on light level)
- **Counting Method**: Rising edge detection

### Stepper Motor Phase Sequence (4-step full step):
```
Step  T1  T2  T3  T4  (SSP5A Pins: 7,4,3,2)
────────────────────────────────────────────
1     On  On  Off Off  Position 1 (U filter)
2     Off On  On  Off  Position 2 (B filter) 
3     Off Off On  On   Position 3 (V filter)
4     On  Off Off On   Position 4 (R filter)
5     On  On  Off Off  Position 5 (I filter) - repeats step 1
6     Off On  On  Off  Position 6 (Dark) - repeats step 2
```

---

## 2. CNC Shield V3 Configuration

See https://mikroshop.ch/pdf/CNC-Shield-Guide.pdf for details and images.

### Board Layout and Features:
```
CNC Shield V3 Pinout (for Arduino Uno R3):
X-axis: Pins D2(STEP), D5(DIR), D12(ENABLE)
Y-axis: Pins D3(STEP), D6(DIR), D13(ENABLE) 
Z-axis: Pins D4(STEP), D7(DIR), D8(ENABLE)
A-axis: Pins D12(STEP), D13(DIR), D8(ENABLE) *shared with Z-axis
```

### DRV8825 Configuration:
```
Microstepping Jumpers (MS1, MS2, MS3):
┌───────────────┬─────────────────────────────────────┐
│ Microstepping │ Jumper Configuration                │
├───────────────┼─────────────────────────────────────┤
│ Full Step     │ MS1=OFF, MS2=OFF, MS3=OFF          │
│ 1/2 Step      │ MS1=ON,  MS2=OFF, MS3=OFF          │
│ 1/4 Step      │ MS1=OFF, MS2=ON,  MS3=OFF          │
│ 1/8 Step      │ MS1=ON,  MS2=ON,  MS3=OFF          │
│ 1/16 Step     │ MS1=ON,  MS2=ON,  MS3=ON           │
└───────────────┴─────────────────────────────────────┘

Recommended: 1/4 or 1/8 microstepping for smooth filter movement
```

### Current Limiting Calculation:
```
Formula: VREF = (Current × 0.2) ÷ 2
Example for 1A per phase: VREF = (1.0 × 0.2) ÷ 2 = 0.1V

Adjustment Procedure:
1. Power OFF the system
2. Place multimeter positive on VREF test point
3. Place multimeter negative on GND
4. Power ON the system
5. Adjust potentiometer until reading matches calculated VREF
```

### Thermal Management:
- Install heatsinks on all 4 DRV8825 chips
- Ensure good airflow in enclosure
- Monitor temperature during extended operation
- Consider adding small fan if temperature >60°C

---

## 3. Complete Wiring Diagram

### SSP5A to Arduino/CNC Shield Connections:
```
┌─────────────────────────────────────────────────────────────────┐
│ SSP5A 9-PIN CONNECTOR → ADAPTER CABLE → ARDUINO/CNC SHIELD      │
├─────────────────────────────────────────────────────────────────┤
│ Pin 1 (Red)     → +12V Power IN → CNC Shield +12V Terminal      │
│ Pin 2 (Yellow)  → Stepper B-    → Y- on CNC Shield              │
│ Pin 3 (Brown)   → Stepper B+    → Y+ on CNC Shield              │
│ Pin 4 (Orange)  → Stepper A-    → X- on CNC Shield              │
│ Pin 5 (Green)   → Signal GND    → Arduino GND                   │
│ Pin 6 (Orange)  → +12V Reg IN   → 12V→5V Regulator → Arduino Vin│
│ Pin 7 (Black)   → Stepper A+    → X+ on CNC Shield              │
│ Pin 8 (Brown)   → Power GND     → CNC Shield GND Terminal       │
│ Pin 9 (Gray)    → Pulse Input   → Arduino Pin 2 (INT0)          │
└─────────────────────────────────────────────────────────────────┘
```

### Power Supply Connections:
```
MAIN POWER (12V 2A DC):
  +12V → Fuse (1A) → ON/OFF Switch → Terminal Block
  GND  → Terminal Block

TERMINAL BLOCK DISTRIBUTION:
  +12V OUT → CNC Shield Power IN
  +12V OUT → 12V→5V Regulator IN
  GND OUT  → CNC Shield GND
  GND OUT  → Regulator GND
  GND OUT  → Arduino GND
  GND OUT  → Arduino GND
```

### CNC Shield Header Pin Identification:
The CNC Shield V3 has 4-pin headers for each axis (X, Y, Z, A) located near the DRV8825 drivers. Each 4-pin header provides connections for both coils of a bipolar stepper motor.

**Standard 4-pin Header Layout:**
```
[4-pin header for X-axis]
┌───┬───┬───┬───┐
│ 1 │ 2 │ 3 │ 4 │
└───┴───┴───┴───┘
```

**Pin Assignments (Typical CNC Shield V3):**
- **Pin 1:** Coil A+ (or 2A) - Connect SSP5A Pin 7 (Black)
- **Pin 2:** Coil A- (or 1A) - Connect SSP5A Pin 4 (Orange)
- **Pin 3:** Coil B+ (or 2B) - Connect SSP5A Pin 3 (Brown)
- **Pin 4:** Coil B- (or 1B) - Connect SSP5A Pin 2 (Yellow)

**Alternative Labeling:** Some CNC shields may label these as:
- X-axis: "A+", "A-", "B+", "B-"
- Or simply numbered 1-4 with coil markings nearby

**Important Notes:**
1. You only need to use **2 pins from each 4-pin header** for the SSP5A single-phase stepper
2. For X-axis: Use pins 1 and 2 (Coil A)
3. For Y-axis: Use pins 1 and 2 (Coil B)
4. The End Stops panel (with pins labeled X-, X+, Y-, Y+, Z-, Z+) is for limit switches and should NOT be used for stepper motor connections

**Final Connection Summary:**
1. **SSP5A Pin 7 (Black)** → **X-axis header Pin 1** (Coil A+)
2. **SSP5A Pin 4 (Orange)** → **X-axis header Pin 2** (Coil A-)
3. **SSP5A Pin 3 (Brown)** → **Y-axis header Pin 1** (Coil B+)
4. **SSP5A Pin 2 (Yellow)** → **Y-axis header Pin 2** (Coil B-)

### Pulse Conditioning Circuit (Recommended):
```
SSP5A Pin 9 → 10kΩ pull-up resistor → 74HC14 Schmitt Trigger → Arduino Pin 2
               │                       (6x inverter with        (INT0)
               └→ 100nF capacitor to GND   hysteresis)
              
Purpose: Cleans up noisy pulses, provides sharp edges for reliable counting
```

### Serial Communication:
```
Arduino Uno USB → USB Cable → Computer COM Port
(Serial communication at 19200 baud, 8-N-1)
Note: Arduino will emulate SSPCARD serial protocol
```

---

## 4. Power Requirements and Calculations

### Total Power Budget:
```
Component                  Voltage    Current    Power
──────────────────────────────────────────────────────
Stepper Motor (active)     12V        500mA      6W
Stepper Motor (idle)       12V        100mA      1.2W
Arduino Uno                5V         50mA       0.25W
CNC Shield Logic           5V         20mA       0.1W
Pulse Circuit              5V         10mA       0.05W
──────────────────────────────────────────────────────
TOTAL (active)                          560mA    6.6W
TOTAL (idle)                            180mA    1.6W
```

### Power Supply Selection:
- **Minimum**: 12V DC, 1A (12W)
- **Recommended**: 12V DC, 2A (24W) for headroom
- **Regulator**: LM7805 or switching regulator for 12V→5V conversion
- **Fuse**: 1A fast-blow fuse on +12V line

### Voltage Regulation:
```
For LM7805 Linear Regulator:
  Input: 12V from SSP5A Pin 6
  Output: 5V for Arduino
  Heat: (12V - 5V) × 0.05A = 0.35W (needs small heatsink)
  
Alternative: Use DC-DC buck converter for better efficiency
```

---

## 5. Hardware Assembly Instructions

### Step 1: Prepare SSP5A Cable
```
1. Obtain 9-pin circular connector (mate for SSP5A)
2. Label wires according to color code:
   - Red: Pin 1 (+12V Stepper)
   - Yellow: Pin 2 (T4/Phase 4)
   - Brown: Pin 3 (T3/Phase 3)
   - Orange: Pin 4 (T2/Phase 2)
   - Green: Pin 5 (Signal GND)
   - Orange: Pin 6 (+12V Logic)
   - Black: Pin 7 (T1/Phase 1)
   - Brown: Pin 8 (Power GND)
   - Gray: Pin 9 (Pulse Output)
3. Add heat shrink labels to each wire
4. Test continuity from connector pins to wire ends
```

### Step 2: Assemble CNC Shield
```
1. Insert DRV8825 drivers into CNC Shield sockets
2. Install heatsinks on DRV8825 chips (use thermal paste)
3. Set microstepping jumpers:
   - MS1, MS2, MS3 for 1/4 or 1/8 microstepping
4. Connect Arduino Uno to CNC Shield
5. Stack CNC Shield onto Arduino
```

### Step 3: Build Interface Board
```
Components needed:
- Terminal block (2-position)
- LM7805 voltage regulator
- 10µF capacitor (input)
- 10µF capacitor (output)
- 74HC14 Schmitt trigger IC
- 10kΩ resistor
- 100nF capacitor
- Protoboard or custom PCB

Assembly:
1. Mount voltage regulator with heatsink
2. Add input/output capacitors
3. Build pulse conditioning circuit
4. Connect terminal block for power
5. Wire all connections neatly
```

### Step 4: Wiring Connections
```
A. Power Connections:
   1. Connect +12V power supply to terminal block
   2. Connect terminal block +12V to CNC Shield power input
   3. Connect terminal block GND to CNC Shield GND
   4. Connect 12V→5V regulator output to Arduino Vin

B. SSP5A Connections:
   1. Connect SSP5A Pin 1 to CNC Shield +12V terminal
   2. Connect SSP5A Pins 2,3,4,7 to CNC Shield stepper outputs
   3. Connect SSP5A Pin 5 to Arduino GND
   4. Connect SSP5A Pin 6 to regulator input
   5. Connect SSP5A Pin 8 to power GND
   6. Connect SSP5A Pin 9 to pulse conditioning circuit

C. Stepper Connections:
   1. Connect CNC Shield X-axis to Stepper Coil A
   2. Connect CNC Shield Y-axis to Stepper Coil B
   3. Verify coil wiring with multimeter (typically 2-10Ω per coil)
```

### Step 5: Enclosure and Final Assembly
```
1. Choose enclosure large enough for all components
2. Mount Arduino/CNC Shield assembly
3. Mount interface board
4. Mount terminal blocks and connectors
5. Add ventilation holes for cooling
6. Label all connectors and switches
7. Secure all cables with strain relief
```

---

## 6. Safety Considerations

### Electrical Safety:
1. **Fuse Protection**: Always include 1A fuse on +12V line
2. **Proper Grounding**: Connect all grounds together (signal, power, shield)
3. **Voltage Rating**: Ensure all components rated for 12V DC operation
4. **Insulation**: Use heat shrink tubing on all connections
5. **Polarity Protection**: Consider adding reverse polarity diode

### Mechanical Safety:
1. **Cable Strain Relief**: Secure SSP5A cable to prevent connector damage
2. **Heat Management**: Ensure adequate cooling for DRV8825 drivers
3. **Enclosure**: Use non-conductive material for enclosure
4. **Accessibility**: Position components for easy maintenance
5. **Labeling**: Clearly label all connections and switches

### Photometer Protection:
1. **Power Sequencing**: Don't apply stepper power while changing filters
2. **Pulse Circuit Isolation**: Keep pulse counting circuit separate
3. **Static Protection**: Use anti-static precautions when handling
4. **Cable Routing**: Avoid sharp bends in SSP5A cable

---

## 7. Initial Testing Procedure

### Before Power On:
```
1. Visual inspection of all connections
2. Continuity test for shorts (+12V to GND)
3. Verify fuse is installed
4. Check voltage regulator connections
```

### Power On Test:
```
1. Apply power, check LED indicators
2. Measure voltages:
   - +12V at CNC Shield power input
   - +5V at Arduino Vin
   - +3.3V at Arduino 3.3V pin (if needed)
3. Verify no components overheating
```

### Stepper Motor Test:
```
1. Send test commands via serial monitor
2. Verify stepper moves smoothly
3. Check current draw (should be <500mA)
4. Test all 6 filter positions
5. Verify homing routine works
```

### Pulse Counting Test:
```
1. Connect test signal generator to pulse input
2. Send count commands via serial
3. Verify pulse counting accuracy
4. Test at different frequencies (1Hz to 50kHz)
5. Check for missed pulses
```

### Serial Communication Test:
```
1. Connect to Arduino via USB
2. Open serial monitor at 19200 baud
3. Send "SSSSSS" command, should receive "!"
4. Test all SSP protocol commands
5. Verify timing matches SSPDataq expectations
```

---

## 8. Parts List

### Essential Components:
```
1. Arduino Uno R3                             $25
2. CNC Shield V3                              $15
3. 4x DRV8825 Stepper Drivers                 $20
4. 4x DRV8825 Heatsinks                       $5
5. 12V 2A DC Power Supply                     $15
6. 9-pin Circular Connector (mate)            $10
7. LM7805 Voltage Regulator                   $2
8. 74HC14 Schmitt Trigger IC                  $1
9. Assorted Resistors/Capacitors              $5
10. Terminal Blocks                           $3
11. Protoboard/PCB                            $5
12. Project Enclosure                         $10
13. Hook-up Wire                              $5
14. USB Cable                                 $5
15. Fuse Holder & 1A Fuse                     $3
──────────────────────────────────────────────
TOTAL ESTIMATED COST:                         $125
```

### Optional/Recommended Components:
```
16. DC-DC Buck Converter (12V→5V)            $5
17. Cooling Fan (40mm)                       $5
18. Status LEDs                              $2
19. Emergency Stop Button                    $5
20. Power Switch with LED                    $5
21. Cable Strain Reliefs                     $3
22. Cable Markers/Labels                     $2
23. Multimeter                               $20
24. Oscilloscope (for pulse testing)         $50+
```

---

## 9. Troubleshooting Guide

### Problem: No Power
```
Check:
1. Power supply output (12V present?)
2. Fuse continuity
3. Switch operation
4. Terminal block connections
5. Voltage regulator output
```

### Problem: Stepper Doesn't Move
```
Check:
1. DRV8825 enable pin (should be LOW)
2. Microstepping jumper settings
3. Current limit potentiometer setting
4. Coil continuity (2-10Ω typical)
5. Step/DIR signals from Arduino
```

### Problem: No Pulse Detection
```
Check:
1. SSP5A pulse output (voltage present?)
2. Pulse conditioning circuit
3. Arduino interrupt configuration
4. Pull-up resistor value
5. Ground connections
```

### Problem: Serial Communication Fails
```
Check:
1. Baud rate (must be 19200)
2. Command formatting (exact strings)
3. Serial buffer clearing
4. Response timing
5. USB cable/port functionality
```

### Problem: Overheating
```
Check:
1. DRV8825 heatsink contact
2. Current limit setting (too high?)
3. Airflow in enclosure
4. Power supply voltage (too high?)
5. Duty cycle (continuous operation?)
```

---

## 10. Next Steps

### Immediate Next Steps:
1. **Order components** from parts list
2. **Build interface board** and test circuits
3. **Assemble hardware** following wiring diagram
4. **Test each subsystem** individually
5. **Begin software development** (Prompt 2)

### For Prompt 2 (Pulse Counting & Serial Communication):
Key considerations based on this hardware design:
1. **Pulse Input**: Using Arduino INT0 (Pin 2) with Schmitt trigger conditioning
2. **Stepper Control**: Using CNC Shield X and Y axes (Pins 2,3,5,6)
3. **Power Management**: 12V→5V regulation for Arduino
4. **Serial Protocol**: Arduino will emulate SSPCARD at 19200 baud

### Updates Needed for Later Prompts:
Based on this hardware design, Prompt 2 should focus on:
1. **Interrupt-driven pulse counting** on Pin 2
2. **AccelStepper library** for CNC Shield control
3. **Serial command parsing** for SSP protocol
4. **Integration timing** using millis() with precision

---

## Summary

This hardware design provides a complete solution for building an Arduino-based SSPCARD replacement. The design:
1. **Matches SSP5A pinout** exactly for compatibility
2. **Uses CNC Shield V3** for reliable stepper control
3. **Includes pulse conditioning** for accurate counting
4. **Provides power management** for all components
5. **Ensures safety** with proper fusing and grounding

The total estimated cost is approximately $125, with most components readily available from electronics suppliers like Adafruit, SparkFun, Amazon, or AliExpress.

Once hardware assembly is complete, proceed to **Prompt 2: Pulse Counting & Serial Communication Implementation** for the software development phase.