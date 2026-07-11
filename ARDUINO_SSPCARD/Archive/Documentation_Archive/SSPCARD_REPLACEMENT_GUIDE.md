# SSPCARD Replacement Guide

## Executive Summary
The SSPCARD is a custom interface card for the Optec SSP-5A photometer that provides:
1. **Stepper motor control** for 6-position filter wheel and flip mirror
2. **Photometer pulse counting** with serial output
3. **Gain control** (1×, 10×, 100×)
4. **Serial communication** with SSPDataq3 software

This guide provides detailed information for building or sourcing a replacement, with emphasis on adapting existing controllers as the preferred option.

## Original SSPCARD Analysis

### Pinout and Connections
```
SSP5A 9-PIN CONNECTOR → SSPCARD
┌─────────────────────────────────────┐
│ Pin  Color   Function               │
├─────────────────────────────────────┤
│ 1    Red     +12V to Stepper        │
│ 2    Yellow  T4 (Phase 4)           │
│ 3    Brown   T3 (Phase 3)           │
│ 4    Orange  T2 (Phase 2)           │
│ 5    Green   Signal Common          │
│ 6    Orange  +12V DC (Logic)        │
│ 7    Black   T1 (Phase 1)           │
│ 8    Brown   Power Ground           │
│ 9    Gray    Pulse Output           │
└─────────────────────────────────────┘
```

### Stepper Motor Specifications
- **Driver IC**: Philips SAA1027
- **Motor Type**: 4-phase unipolar stepper
- **Voltage**: 12V DC
- **Current**: Likely 300-500mA per phase
- **Step Sequence**: 4-step full step (see table below)

### Stepping Sequence (4-step full step)
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

### Serial Protocol
- **Baud Rate**: 19200
- **Data**: 8 bits, no parity, 1 stop bit
- **Commands**: ASCII strings starting with 'S'
- **Responses**: "!" for acknowledgment, "C=XXXXX" for counts

## Preferred Option: Adapt Existing Controller

### Why Adapt Existing Controllers?
1. **Faster implementation** - No PCB design needed
2. **Proven reliability** - Commercial products are tested
3. **Lower risk** - Fewer unknowns
4. **Better documentation** - Manufacturer support available
5. **Cost effective** for small quantities

### Candidate Controllers for Adaptation

#### Option A: Arduino + Stepper Shield
**Components:**
1. Arduino Uno/Nano ($5-10)
2. Adafruit Motor Shield v2 ($20)
3. USB-to-Serial adapter ($5)
4. Pulse counter module ($10)

**Advantages:**
- Extensive community support
- Easy prototyping
- Many libraries available
- Cost effective

**Implementation:**
```
SSP5A → Pulse Input → Arduino → USB → Computer
         │                     │
         │                     └→ Stepper Shield → Filter Wheel
         └→ Gain Control Circuit
```

#### Option B: Raspberry Pi Pico + Stepper HAT
**Components:**
1. Raspberry Pi Pico ($4)
2. Stepper Motor HAT ($15-25)
3. Pulse counter IC (74HC4040, $1)
4. USB native interface (built-in)

**Advantages:**
- Dual-core processor
- PIO for precise pulse timing
- Native USB serial
- More memory/processing

#### Option C: Dedicated Stepper Controller + Arduino
**Components:**
1. Arduino Nano ($5)
2. TB6600 Stepper Driver ($15)
3. MAX7219 counter display (optional, $5)
4. USB interface

**Advantages:**
- Higher current capability (3.5A)
- Microstepping support
- Better thermal management

## Detailed Adaptation Guide

### Part 1: Stepper Motor Control Adaptation

#### Understanding the SAA1027 Interface
The SAA1027 uses direct phase control (T1-T4). Modern controllers use STEP/DIR interface.

**Conversion needed:**
- SAA1027: 4-phase direct control
- Modern drivers: STEP pulse + DIR direction

**Mapping Strategy:**
```
SAA1027 States → STEP/DIR Equivalent
Phase State    → Equivalent Microstep Position
─────────────────────────────────────────────
T1=1, T2=1    → Position 0 (0°)
T1=0, T2=1    → Position 1 (90°)
T1=0, T2=0    → Position 2 (180°)
T1=1, T2=0    → Position 3 (270°)
```

#### Using TB6600 Driver (Recommended)
**Wiring:**
```
Arduino D2 → TB6600 PUL+ (Step)
Arduino D3 → TB6605 DIR+ (Direction)
Arduino D4 → TB6605 ENA+ (Enable)
TB6600 A+, A- → Stepper Coil A
TB6600 B+, B- → Stepper Coil B
+12V → TB6600 VCC
GND → TB6600 GND
```

**Code for TB6600 Control:**
```cpp
// Arduino code to emulate SAA1027 commands
#include <AccelStepper.h>

// Define pins
#define STEP_PIN 2
#define DIR_PIN 3
#define ENA_PIN 4

// Create stepper object
AccelStepper stepper(AccelStepper::DRIVER, STEP_PIN, DIR_PIN);

void setup() {
    pinMode(ENA_PIN, OUTPUT);
    digitalWrite(ENA_PIN, LOW); // Enable driver
    
    // Configure stepper
    stepper.setMaxSpeed(1000);     // steps per second
    stepper.setAcceleration(500);  // steps per second²
    stepper.setCurrentPosition(0); // Home position
    
    // 6-position filter wheel (adjust steps per position)
    // Assuming 200 steps/rev motor and 6 positions
    // 200 steps/rev ÷ 6 positions = 33.33 steps/position
    // Use microstepping to get precise positioning
}

void home_filter() {
    // Home the filter wheel
    // This would need a homing sensor or use current position as reference
    stepper.moveTo(0);
    while(stepper.distanceToGo() != 0) {
        stepper.run();
    }
    Serial.println("!"); // Acknowledge
}

void select_filter(uint8_t position) {
    // Move to filter position (1-6)
    if(position < 1 || position > 6) return;
    
    // Calculate target position
    // 33.33 steps per filter position with 200 steps/rev motor
    long target = (position - 1) * 33;
    
    stepper.moveTo(target);
    while(stepper.distanceToGo() != 0) {
        stepper.run();
    }
    
    delay(100); // Brief pause as in original
    Serial.println("!"); // Acknowledge
}
```

#### Using Adafruit Motor Shield v2
**Simpler but less precise:**
```cpp
#include <Wire.h>
#include <Adafruit_MotorShield.h>
#include "utility/Adafruit_MS_PWMServoDriver.h"

Adafruit_MotorShield AFMS = Adafruit_MotorShield();
Adafruit_StepperMotor *filterWheel = AFMS.getStepper(200, 1);

void setup() {
    AFMS.begin();
    filterWheel->setSpeed(100); // RPM
    filterWheel->release(); // Start with motor off
}

void move_to_filter(uint8_t position) {
    // Release motor first
    filterWheel->release();
    
    // Calculate steps needed (200 steps/rev ÷ 6 positions ≈ 33 steps)
    int steps = (position - 1) * 33;
    
    // Move to position
    filterWheel->step(steps, FORWARD, DOUBLE); // Double coil for more torque
    
    // Release to save power
    filterWheel->release();
}
```

### Part 2: Pulse Counting Adaptation

#### Pulse Characteristics
- **Source**: SSP5A photometer pulse output (Pin 9)
- **Format**: Likely TTL-level pulses (0-5V or 0-12V)
- **Frequency**: Depends on light level (0-50kHz typical)
- **Width**: Likely 1-10µs pulses

#### Counting Options

**Option 1: Arduino Interrupt Counting**
```cpp
volatile unsigned long pulse_count = 0;
unsigned long last_count = 0;
bool counting_active = false;
unsigned long integration_start = 0;
unsigned long integration_time = 1000; // ms

void setup() {
    attachInterrupt(digitalPinToInterrupt(2), count_pulse, RISING);
    Serial.begin(19200);
}

void count_pulse() {
    if(counting_active) {
        pulse_count++;
    }
}

void start_integration() {
    pulse_count = 0;
    counting_active = true;
    integration_start = millis();
    
    // Wait for integration time
    while(millis() - integration_start < integration_time) {
        // Can do other tasks here
    }
    
    counting_active = false;
    
    // Format as "C=XXXXX"
    char buffer[12];
    sprintf(buffer, "C=%05lu\r\n", pulse_count);
    Serial.print(buffer);
}
```

**Option 2: Dedicated Counter IC (74HC4040)**
```
Circuit:
SSP5A Pin 9 → 74HC4040 Clock Input
74HC4040 Q0-Q11 → Arduino Inputs (12-bit count)
Arduino reads counter, resets via MR pin
```

**Option 3: External Timer/Counter Module**
- **DS3231 RTC with counter**: Precise timing
- **Frequency counter module**: Higher accuracy
- **FPGA/CPLD**: Ultimate precision

### Part 3: Gain Control Adaptation

#### Gain Circuit Options

**Option A: Digital Potentiometer**
```cpp
#include <SPI.h>

// MCP41xxx digital pot
#define CS_PIN 10

void set_gain(uint8_t gain_setting) {
    digitalWrite(CS_PIN, LOW);
    
    switch(gain_setting) {
        case 1:  // Gain 1
            SPI.transfer(0x11); // Command + Data for gain 1
            SPI.transfer(0x00);
            break;
        case 2:  // Gain 10 (actually SGNNN2 = gain 10)
            SPI.transfer(0x11);
            SPI.transfer(0x80); // Mid position
            break;
        case 3:  // Gain 100 (actually SGNNN1 = gain 100)
            SPI.transfer(0x11);
            SPI.transfer(0xFF); // Max position
            break;
    }
    
    digitalWrite(CS_PIN, HIGH);
}
```

**Option B: Analog Switches (CD4051)**
```
Arduino → CD4051 Control Pins → Resistor Network → Gain Stages
                    A,B,C         R1,R2,R3          ×1, ×10, ×100
```

**Option C: Relay Switching**
- Simple but mechanical
- Good for high current/voltage
- Slower switching

### Part 4: Serial Protocol Implementation

#### Complete Command Parser
```cpp
void handle_serial_command() {
    if(Serial.available()) {
        String command = Serial.readStringUntil('\n');
        command.trim();
        
        if(command == "SSSSSS") {
            // Enter serial mode
            Serial.print("!");
            serial_mode = true;
        }
        else if(command == "SEEEEE") {
            // Exit serial mode
            serial_mode = false;
        }
        else if(command.startsWith("SC")) {
            // Start count command
            if(!serial_mode) return;
            
            // Parse integration time (nnnn)
            String time_str = command.substring(2);
            uint16_t integration_ms = parse_integration(time_str);
            
            start_integration(integration_ms);
        }
        else if(command == "SHNNN") {
            // Home filter
            if(!serial_mode) return;
            home_filter();
            Serial.print("!");
        }
        else if(command.startsWith("SFNNN")) {
            // Select filter
            if(!serial_mode) return;
            
            uint8_t filter_pos = command.charAt(5) - '0';
            if(filter_pos >= 1 && filter_pos <= 6) {
                select_filter(filter_pos);
                Serial.print("!");
            }
        }
        else if(command.startsWith("SG")) {
            // Set gain
            if(!serial_mode) return;
            
            String gain_str = command.substring(2);
            uint8_t gain = parse_gain(gain_str);
            set_gain(gain);
            Serial.print("!");
        }
        else if(command.startsWith("SVIEW")) {
            // Set mirror position
            if(!serial_mode) return;
            
            uint8_t mirror_pos = command.charAt(5) - '0';
            set_mirror(mirror_pos);
            Serial.print("!");
        }
    }
}

uint16_t parse_integration(String time_str) {
    // Convert "nnnn" to milliseconds
    // Mapping based on SSPDataq documentation
    if(time_str == "0002") return 20;    // 0.02s
    if(time_str == "0005") return 50;    // 0.05s
    if(time_str == "0010") return 100;   // 0.10s
    if(time_str == "0050") return 500;   // 0.50s
    if(time_str == "0100") return 1000;  // 1.00s
    if(time_str == "0500") return 5000;  // 5.00s
    if(time_str == "1000") return 10000; // 10.00s
    return 1000; // Default
}

uint8_t parse_gain(String gain_str) {
    // SGNNN1 = gain 100
    // SGNNN2 = gain 10
    // SGNNN3 = gain 1
    if(gain_str.endsWith("1")) return 100;
    if(gain_str.endsWith("2")) return 10;
    if(gain_str.endsWith("3")) return 1;
    return 10; // Default
}
```

### Part 5: Complete Wiring Diagram

```
SSP5A Connector → Adapter Board → Controller
┌─────────────────────────────────────────────────────┐
│ SSP5A Pin  Function  →  Adapter  →  Controller      │
├─────────────────────────────────────────────────────┤
│ 1  +12V Stepper  →  +12V        →  Stepper Driver  │
│ 2  T4 (Phase 4)  →  Phase B-    →  Stepper B-      │
│ 3  T3 (Phase 3)  →  Phase B+    →  Stepper B+      │
│ 4  T2 (Phase 2)  →  Phase A-    →  Stepper A-      │
│ 5  Signal GND    →  GND         →  Arduino GND     │
│ 6  +12V Logic    →  +12V Reg    →  Arduino Vin     │
│ 7  T1 (Phase 1)  →  Phase A+    →  Stepper A+      │
│ 8  Power GND     →  GND         →  Power GND       │
│ 9  Pulse Output  →  Pulse In    →  Arduino INT0    │
└─────────────────────────────────────────────────────┘

Additional Connections:
Stepper Driver → Stepper Motor
Arduino TX/RX → USB-to-Serial → Computer
Gain Control Circuit → SSP5A Gain Pins (if accessible)
```

### Part 6: Power Requirements

**Original SSPCARD Power:**
- **Stepper Motor**: +12V @ ~500mA (Pin 1)
- **Logic**: +12V @ ~100mA (Pin 6)
- **Total**: ~7W maximum

**Replacement Power Design:**
```
Power Supply (12V 1A) → Voltage Regulator Circuit
                           ├→ 12V → Stepper Driver
                           ├→ 5V  → Arduino/Controller
                           └→ 3.3V → Optional peripherals
```

## Step-by-Step Implementation Plan

### Phase 1: Prototype Testing

**Week 1-2: Basic Connectivity**
1. **Test pulse counting** with Arduino
   - Connect SSP5A Pin 9 to Arduino interrupt pin
   - Verify pulse detection with LED
   - Measure pulse frequency with different light levels

2. **Test stepper control**
   - Connect stepper motor to driver
   - Test basic movement
   - Verify step sequence matches original

3. **Test serial communication**
   - Implement basic command parser
   - Test with SSPDataq3 in trial mode

**Week 3-4: Integration Testing**
1. **Combine components**
   - Full command set implementation
   - Integration timing verification
   - Error handling

2. **Compatibility testing**
   - Test with SSPDataq3 software
   - Verify all commands work
   - Check timing accuracy

### Phase 2: Adapter Board Design

**Design requirements:**
1. **9-pin connector** matching SSP5A
2. **Stepper driver interface** (TB6600 or similar)
3. **Pulse conditioning circuit** (Schmitt trigger)
4. **Gain control circuit** (digital pot or switches)
5. **Microcontroller** (Arduino Nano or similar)
6. **Power regulation** (12V to 5V/3.3V)

**Suggested PCB layout:**
```
Front:
[9-pin Connector] [Headers] [USB Port]
 
Back:
[Stepper Driver] [MCU] [Voltage Regulator]
```

### Phase 3: Firmware Development

**Core Features:**
1. **Command parser** with full SSP protocol
2. **Precise timing** for integration periods
3. **Pulse counting** with overflow protection
4. **Stepper control** with position tracking
5. **Gain control** with calibration
6. **Error handling** and recovery

**Advanced Features (optional):**
1. **Position memory** after power loss
2. **Self-test routines**
3. **Diagnostic mode**
4. **Configuration via serial**
5. **LED status indicators**

### Phase 4: Testing and Calibration

**Functional Tests:**
1. **Pulse counting accuracy** with signal generator
2. **Stepper positioning accuracy** with encoder
3. **Timing accuracy** with oscilloscope
4. **Gain calibration** with known light sources

**Compatibility Tests:**
1. **SSPDataq3 full feature test**
2. **Long-term reliability** (24-hour test)
3. **Temperature stability** test
4. **Power cycling** test

## Troubleshooting Common Issues

### Issue 1: No Pulse Detection
**Check:**
1. SSP5A power and operation
2. Pulse signal voltage levels
3. Interrupt configuration
4. Pull-up/pull-down resistors

**Solution:** Add Schmitt trigger for pulse conditioning:
```
SSP5A Pin 9 → 10k pull-up → 74HC14 Schmitt trigger → Arduino
```

### Issue 2: Stepper Doesn't Move
**Check:**
1. Power supply (12V @ sufficient current)
2. Stepper driver enable pin
3. Step/direction signals
4. Motor wiring (coil continuity)

**Solution:** Use multimeter to verify signals at each stage.

### Issue 3: SSPDataq3 Connection Fails
**Check:**
1. Baud rate (must be 19200)
2. Flow control (must be disabled)
3. Command formatting (exact strings)
4. Response timing (acknowledgment delay)

**Solution:** Use serial monitor to debug communication.

### Issue 4: Gain Control Not Working
**Check:**
1. Gain control circuit connections
2. SSP5A gain control pins (if accessible)
3. Command parsing (SGNNN1/2/3)
4. Acknowledgment response

**Solution:** Test gain control with multimeter on SSP5A gain pins.

## Cost Analysis

### Option A: Arduino-based Solution
```
Arduino Nano:                    $5
TB6600 Stepper Driver:          $15
USB-to-Serial:                   $5
Components (resistors, caps):    $5
PCB/Protoboard:                  $5
Enclosure:                       $10
─────────────────────────────────────
Total:                          $45
```

### Option B: Raspberry Pi Pico Solution
```
RPi Pico:                        $4
Stepper HAT:                    $20
Components:                      $5
PCB:                            $10
Enclosure:                      $10
─────────────────────────────────────
Total:                          $49
```

### Option C: Professional PCB Solution
```
Custom PCB (5 pieces):          $50
Components (BOM):               $60
Assembly:                       $100
Enclosure:                      $20
─────────────────────────────────────
Total per unit (5 units):       $46
```

## Sourcing Alternatives

### 1. **Ready-Made Components**
- **Stepper Controller**: Geckodrive, Leadshine, Trinamic
- **Pulse Counter**: Frequency counter modules
- **Gain Control**: Programmable gain amplifier modules

### 2. **Adapt Astronomy Equipment**
- **Filter Wheels**: ZWO, Atik, Starlight Xpress
- **Focus Controllers**: Moonlite, Pegasus, Sesto Senso
- **Arduino Astronomy Shields**: OpenAstroTech, AstroEQ

### 3. **Commission Development**
- **Freelance Engineer**: $500-$2000
- **Small Electronics Shop**: $1000-$3000
- **University Project**: Student project option

### 4. **Community Collaboration**
- **Astronomy Forums**: Cloudy Nights, Stargazers Lounge
- **Open Source Projects**: GitHub, Hackaday
- **Local Astronomy Clubs**: Shared development

## Recommended Path Forward

### **Short Term (1-2 months): Arduino Prototype**
1. **Build basic prototype** with Arduino + TB6600
2. **Test pulse counting** and stepper control
3. **Verify SSPDataq3 compatibility**
4. **Refine design** based on testing

### **Medium Term (3-6 months): Custom PCB**
1. **Design custom PCB** based on working prototype
2. **Order small batch** (5-10 units)
3. **Test thoroughly** with multiple SSP5A units
4. **Document and share** with community

### **Long Term (6-12 months): Production Version**
1. **Refine design** based on feedback
2. **Consider commercial production** if demand exists
3. **Create documentation** and support materials
4. **Build community** of users

## Conclusion

Replacing the SSPCARD is entirely feasible with modern components. The key is:

1. **Faithful protocol emulation** - Must work with existing SSPDataq3 software
2. **Precise timing** - Critical for accurate photometry
3. **Reliable stepper control** - For filter positioning
4. **Accurate pulse counting** - Core photometer function

An Arduino-based solution with TB6600 stepper driver offers the best balance of cost, complexity, and capability. The total cost is under $50 and development time is 1-2 months for a working prototype.

**Next Steps:**
1. Purchase Arduino + TB6600 + basic components
2. Build test circuit for pulse counting
3. Implement basic command parser
4. Test with SSPDataq3
5. Iterate based on results

This approach preserves your investment in the SSP5A photometer while using readily available, modern components.