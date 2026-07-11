*******
# SSP5A Arduino Controller - Prompts for Development

## Overview
This file contains a series of prompts designed to help you build an Arduino-based microcontroller replacement for the SSPCARD. The prompts are broken down into manageable sections to avoid "context too large" errors.

## Background Analysis Summary
From the analysis of SSPCARD documentation:

1. **SSPCARD Functionality**: Controls stepper motors for filter wheel and flip mirror, handles gain switching, and manages pulse counting from SSP5A photometer.

2. **Serial Protocol**: 19200 bps, 8-N-1, no flow control. Commands follow `S + CommandLetter + Parameters` format.

3. **Key Commands**:
   - `SHNNN` - Home filter bar
   - `SFNNN1` to `SFNNN6` - Select filter positions 1-6
   - `SCnnnn` - Get count data
   - `SGNNN1/2/3` - Set gain (inverted: 1=Gain 100, 2=Gain 10, 3=Gain 1)
   - `SVIEW0/1` - Mirror control

4. **Pulse Counting**: SSP5A outputs pulses to Pin 9 of the 9-pin connector.

## Available Components
1. Arduino Uno R3
2. CNC Shield V3 (with 4x DRV8825 drivers)
3. 4x heatsinks for DRV8825
4. SSP5A photometer with 9-pin round cable

---

## Prompt 1: Hardware Design & Wiring Instructions

Based on the analysis of SSPCARD functionality and the SSP5A 9-pin interface, provide detailed hardware design and wiring instructions for:

### Requirements:
1. **Pulse Counting**: Need to count pulses from SSP5A Pin 9
2. **Stepper Motor Control**: Need to control filter wheel stepper (and optionally flip mirror stepper)
3. **Serial Communication**: Need to communicate with SSPData3 software using existing SSP protocol

### Specific Instructions Needed:

#### 1. Pin Mapping for SSP5A 9-pin Connector
Based on the analysis documents, the SSP5A 9-pin connector has these functions:
- Pin 9: Pulse output (needs counting)
- Pins 2,3,4,7: Stepper motor phases (T1-T4)
- Pin 1: +12V stepper power
- Pin 6: +12V logic power
- Pin 8: Power ground
- Pin 5: Signal ground

Provide specific Arduino pin mappings for:
- Pulse input counting
- Stepper motor control (using CNC Shield/DRV8825)
- Any other required connections

#### 2. CNC Shield Configuration
- How to configure the CNC Shield for bipolar stepper motor
- Current limiting settings for DRV8825
- Microstepping configuration
- Power supply requirements

#### 3. Complete Wiring Diagram
- Arduino to CNC Shield connections
- CNC Shield to SSP5A stepper motor connections
- Pulse input circuit (may need voltage conditioning)
- Power supply connections
- Serial communication (USB from Arduino to PC)

#### 4. Power Requirements
- Stepper motor power (likely 12V)
- Logic power (5V from Arduino)
- Current requirements

#### 5. Hardware Assembly Instructions
- Step-by-step assembly guide
- Heatsink installation
- Cable preparation
- Safety considerations

---

## Prompt 2: Pulse Counting & Serial Communication Implementation

Based on the hardware design from Prompt 1 (SSP5A_Arduino_Hardware_Design.md), provide detailed implementation instructions for:

### Hardware-Specific Requirements (from Prompt 1):
1. **Pulse Counting**: Using Arduino Pin 2 (INT0) with 74HC14 Schmitt trigger conditioning
2. **Stepper Control**: Using CNC Shield X and Y axes (Pins: X-STEP=D2, X-DIR=D5, Y-STEP=D3, Y-DIR=D6)
3. **Power Management**: 12V→5V regulation for Arduino (LM7805 or DC-DC converter)
4. **Serial Communication**: 19200 baud, 8-N-1 via USB

### Implementation Requirements:
1. **Pulse Counting Implementation**
   - Hardware interrupt handling on INT0 (Pin 2)
   - Counting during integration periods with overflow handling (16-bit: 0-65535)
   - Background counting with foreground readout
   - Support for pulse frequencies up to 50kHz

2. **Serial Communication Protocol**
   - Implement SSP serial protocol (19200, 8-N-1)
   - Command parsing for:
     - `SSSSSS` - Enter serial mode
     - `SEEEEE` - Exit serial mode
     - `SHNNN` - Home filter
     - `SFNNN1-6` - Select filter position
     - `SCnnnn` - Get count (slow mode)
     - `SGNNN1/2/3` - Set gain (note: inverted mapping: 1=Gain 100, 2=Gain 10, 3=Gain 1)
     - `SVIEW0/1` - Mirror control (optional)
     - `SInnnn` - Set integration time (1-9999 ms)

3. **Timing Requirements**
   - Integration time accuracy (±1%) using millis() with micros() correction
   - Serial response timing: immediate acknowledgment (!) for control commands
   - Filter movement timing: 100ms for adjacent positions, 5s for homing
   - Count response: within 10ms of integration completion

4. **Data Format**
   - Count response format: `C=XXXXX\r\n` (5 digits, zero-padded)
   - Acknowledgment: `!` character for all hardware control commands
   - Error response: `?` for invalid commands
   - Status response: `S=XXXX` for system status

### Specific Implementation Details Needed:

#### 1. Pulse Counting Implementation
- **Interrupt Configuration**: Use attachInterrupt(digitalPinToInterrupt(2), pulseISR, RISING)
- **ISR Design**: Minimal code in interrupt service routine (increment volatile counter)
- **Count Management**: Use atomic operations or disable interrupts during count read
- **Overflow Handling**: Implement 32-bit counter with 16-bit reporting
- **Integration Timing**: Start/stop counting based on integration period

#### 2. Serial Protocol Implementation
- **Command Parser**: State machine for parsing SSP commands
- **Buffer Management**: Circular buffer for incoming serial data
- **Response Generator**: Format responses according to SSP protocol
- **Timeout Handling**: 100ms timeout for incomplete commands
- **Echo Control**: No echo for SSP protocol compatibility

#### 3. Stepper Motor Control
- **Library Selection**: AccelStepper library for CNC Shield control
- **Pin Configuration**: 
  - X-axis (Coil A): STEP=D2, DIR=D5, ENABLE=D12
  - Y-axis (Coil B): STEP=D3, DIR=D6, ENABLE=D13
- **Movement Logic**: 
  - Full-step sequence matching SSP5A phase pattern
  - Position tracking for 6 filter positions
  - Homing routine (if limit switch implemented)
- **Speed Control**: 100ms per filter position, acceleration/deceleration

#### 4. Integration Timer Implementation
- **Precision Timing**: Use millis() for main timing, micros() for sub-millisecond correction
- **Timer Management**: Non-blocking timer state machine
- **Synchronization**: Coordinate timer with pulse counting and serial responses
- **Multiple Timers**: Support for integration, movement, and communication timeouts

#### 5. System State Management
- **State Variables**: Track integration status, filter position, gain setting
- **Error States**: Handle communication errors, hardware faults
- **Recovery Logic**: Automatic recovery from error conditions
- **Configuration**: EEPROM storage for calibration values

#### 6. Debug and Monitoring
- **Debug Serial**: Separate Serial1 or SoftwareSerial for debug output
- **Status LEDs**: Use onboard LED (D13) for status indication
- **Self-Test**: Power-on self-test routine
- **Performance Monitoring**: Track interrupt latency, buffer usage

---

## Prompt 3: Complete Arduino Sketch

Based on the hardware design (Prompt 1: SSP5A_Arduino_Hardware_Design.md) and implementation details (Prompt 2), provide the complete Arduino sketch that integrates all components:

### Hardware-Specific Integration Requirements:
1. **Pulse Counting**: Interrupt on Pin 2 (INT0) with Schmitt trigger conditioning
2. **Stepper Control**: CNC Shield X and Y axes (AccelStepper library)
3. **Serial Communication**: 19200 baud SSP protocol emulation
4. **Power Management**: Proper initialization of 12V→5V regulated system

### Complete System Integration Requirements:
1. **Main State Machine**
   - Handle SSP protocol commands in real-time
   - Manage integration periods with ±1% timing accuracy
   - Coordinate stepper movements with pulse counting
   - Implement error recovery and fault handling

2. **Hardware-Specific Configuration**
   - CNC Shield pin mappings: X-STEP=D2, X-DIR=D5, Y-STEP=D3, Y-DIR=D6
   - Enable pins: X-ENABLE=D12, Y-ENABLE=D13
   - Pulse input: Pin 2 (INT0) with RISING edge detection
   - Status LED: Pin 13 (built-in) for system status
   - Microstepping: Configured via CNC Shield jumpers (1/4 or 1/8 step)

3. **Protocol Implementation**
   - Full SSP command set support
   - Proper response formatting (C=XXXXX, !, ?)
   - Timing compliance with SSPData3 software
   - Buffer management for rapid command sequences

4. **Advanced Features**
   - EEPROM storage for calibration values
   - Self-test and diagnostic routines
   - Debug output via separate serial port
   - Performance monitoring and logging

### Specific Code Modules Needed:

#### 1. Main Program Structure
- **setup()**: Initialize hardware, load configuration, configure interrupts
- **loop()**: Main state machine, command processing, timer management
- **Interrupt Service Routines**: pulseISR() for counting, minimal code
- **Serial Event Handler**: Process incoming SSP commands

#### 2. SSP Protocol Handler Module
- **Command Parser**: State machine for parsing `SXXXXX` format commands
- **Command Dispatcher**: Route commands to appropriate handlers
- **Response Generator**: Format responses per SSP protocol
- **Timeout Manager**: Handle incomplete or timed-out commands

#### 3. Pulse Counting Module
- **Interrupt Handler**: ISR for Pin 2 (INT0) pulse counting
- **Counter Management**: 32-bit counter with 16-bit reporting
- **Integration Timer**: Start/stop counting based on SInnnn command
- **Count Formatter**: Convert count to `C=XXXXX` 5-digit format

#### 4. Stepper Control Module
- **AccelStepper Integration**: Control X and Y axes for bipolar stepper
- **Position Tracking**: Track current filter position (1-6)
- **Movement Logic**: Implement SSP5A phase sequence (4-step full step)
- **Homing Routine**: Optional limit switch homing or software homing

#### 5. Configuration Module
- **EEPROM Storage**: Store calibration values, filter positions, settings
- **Configuration Structure**:
  ```cpp
  struct SSPConfig {
    uint16_t filterPositions[6];  // Step counts for each filter
    uint16_t integrationTime;     // Default integration time
    uint8_t microstepping;        // Microstepping setting (1,2,4,8,16)
    uint8_t currentLimit;         // DRV8825 current limit (0-255)
    uint8_t gainSetting;          // Current gain setting (1,2,3)
    uint8_t checksum;             // Configuration checksum
  };
  ```
- **Calibration Routines**: Learn filter positions, set microstepping
- **Factory Reset**: Restore default configuration

#### 6. System Management Module
- **State Tracking**: Integration status, filter position, gain setting
- **Error Handling**: Communication errors, hardware faults, recovery
- **Performance Monitoring**: Interrupt latency, buffer usage, timing
- **Diagnostic Functions**: Self-test, status reporting, debug output

#### 7. Utility Functions
- **Timing Utilities**: millis() with micros() correction for ±1% accuracy
- **String Processing**: Command parsing, response formatting
- **Math Functions**: Count calculations, overflow handling
- **Debug Output**: Conditional debug messages via separate serial

### Complete Sketch Structure Example:
```cpp
// SSP5A Arduino Controller - Complete Sketch
// Based on Hardware Design from SSP5A_Arduino_Hardware_Design.md

#include <AccelStepper.h>
#include <EEPROM.h>

// Hardware Configuration (from Prompt 1)
#define PULSE_PIN       2     // INT0 for pulse counting
#define STEPPER_X_STEP  2     // CNC Shield X-STEP (Note: shared with pulse pin?)
#define STEPPER_X_DIR   5     // CNC Shield X-DIR
#define STEPPER_X_EN    12    // CNC Shield X-ENABLE
#define STEPPER_Y_STEP  3     // CNC Shield Y-STEP
#define STEPPER_Y_DIR   6     // CNC Shield Y-DIR
#define STEPPER_Y_EN    13    // CNC Shield Y-ENABLE
#define STATUS_LED      13    // Built-in LED (shared with Y-ENABLE)

// SSP Protocol Constants
#define SSP_BAUD        19200
#define CMD_TIMEOUT_MS  100
#define INTEGRATION_MIN 1     // Minimum integration time (ms)
#define INTEGRATION_MAX 9999  // Maximum integration time (ms)

// Configuration Structure
struct SSPConfig {
  uint16_t filterPositions[6];
  uint16_t integrationTime;
  uint8_t microstepping;
  uint8_t currentLimit;
  uint8_t gainSetting;
  uint8_t checksum;
};

// Global Variables
volatile uint32_t pulseCount = 0;
uint32_t integrationStartTime = 0;
uint16_t integrationDuration = 1000;  // Default 1 second
uint8_t currentFilter = 1;
uint8_t currentGain = 1;
bool integrationActive = false;

// Stepper Objects
AccelStepper stepperX(AccelStepper::DRIVER, STEPPER_X_STEP, STEPPER_X_DIR);
AccelStepper stepperY(AccelStepper::DRIVER, STEPPER_Y_STEP, STEPPER_Y_DIR);

// Configuration
SSPConfig config;

void setup() {
  // Initialize Serial for SSP protocol
  Serial.begin(SSP_BAUD);
  
  // Initialize hardware pins
  pinMode(PULSE_PIN, INPUT);
  pinMode(STATUS_LED, OUTPUT);
  
  // Configure stepper drivers
  pinMode(STEPPER_X_EN, OUTPUT);
  pinMode(STEPPER_Y_EN, OUTPUT);
  digitalWrite(STEPPER_X_EN, LOW);  // Enable drivers
  digitalWrite(STEPPER_Y_EN, LOW);
  
  // Configure AccelStepper
  stepperX.setMaxSpeed(1000);
  stepperX.setAcceleration(500);
  stepperY.setMaxSpeed(1000);
  stepperY.setAcceleration(500);
  
  // Setup interrupt for pulse counting
  attachInterrupt(digitalPinToInterrupt(PULSE_PIN), pulseISR, RISING);
  
  // Load configuration from EEPROM
  loadConfiguration();
  
  // Initial status indication
  digitalWrite(STATUS_LED, HIGH);
  delay(100);
  digitalWrite(STATUS_LED, LOW);
}

void loop() {
  // Main state machine
  handleSerialCommands();
  manageIntegrationTimer();
  updateStepperMotors();
  updateStatusLED();
}

// Interrupt Service Routine for pulse counting
void pulseISR() {
  pulseCount++;
}

// Command handling functions
void handleSerialCommands() {
  // Implement SSP command parsing and execution
}

void manageIntegrationTimer() {
  // Manage integration period timing
}

void updateStepperMotors() {
  // Update stepper movement
  stepperX.run();
  stepperY.run();
}

void updateStatusLED() {
  // Update LED based on system status
}

void loadConfiguration() {
  // Load configuration from EEPROM
}

void saveConfiguration() {
  // Save configuration to EEPROM
}

// Additional module implementations would follow...
```

---

## Reference Documents (Placeholders)
When working on these prompts, refer to these documents for technical details:

### Hardware & Protocol Details:
- `SSPDataq/SSPCARD_ANALYSIS.md` - Contains SSP5A pinout, serial protocol, and command reference
- `SSPDataq/PULSE_OUTPUT_ANALYSIS.md` - Contains pulse counting details and count value interpretation
- `SharpCap-SSP/FILTER_CONTROL.md` - Contains serial command protocol and timing requirements
- `SSPDataq/MANUAL_FILTER_CONVERSION.md` - Contains stepper motor phase details and wiring information

### Software Implementation:
- `SharpCap-SSP/Python/ssp_comm.py` - Python implementation of SSP serial protocol (reference for command handling)
- `SSPDataq/SSPDataq3_3,21.bas` - Original SSPDataq BASIC code (for protocol reference)

### General Documentation:
- `SSPDataq/MINIMAL_CONTROL_REQUIREMENTS.md` - Minimum control requirements
- `SSPDataq/READ ME.txt` - General SSP system documentation

---

## Development Strategy

### Phase 1: Hardware Design (Prompt 1)
1. Design the physical wiring and connections
2. Select appropriate components
3. Create wiring diagrams
4. Test basic connectivity

### Phase 2: Communication Protocol (Prompt 2)
1. Implement serial communication
2. Test command/response cycles
3. Verify timing requirements
4. Integrate pulse counting

### Phase 3: Complete Integration (Prompt 3)
1. Combine all modules
2. Test full functionality
3. Optimize performance
4. Add debug features

### Phase 4: Testing & Validation
1. Test with SSPData3 software
2. Verify pulse counting accuracy
3. Validate filter positioning
4. Performance benchmarking

---

## Notes for Implementation

### Critical Requirements:
1. **Serial Protocol Compatibility**: Must work with existing SSPData3 software without modifications
2. **Timing Accuracy**: Integration timing must be accurate (±1%) for photometric measurements
3. **Count Format**: Must return 5-digit count values in `C=XXXXX` format
4. **Acknowledgment**: Must return `!` for all hardware control commands
5. **Filter Positions**: Must support 6 filter positions with accurate positioning

### Hardware Considerations:
1. **Pulse Input**: May need voltage conditioning or protection circuit
2. **Stepper Power**: DRV8825 drivers need proper heatsinking
3. **Power Supply**: Clean, regulated power for accurate counting
4. **Grounding**: Proper signal grounding to avoid noise in pulse counting

### Software Considerations:
1. **Interrupt Latency**: Must be minimized for accurate pulse counting
2. **Serial Buffer**: Must handle SSPData3's rapid command sequences
3. **State Management**: Must track integration periods, filter positions, etc.
4. **Error Recovery**: Must handle communication errors gracefully

---

## Expected Deliverables

### From Prompt 1:
1. Complete wiring diagram
2. Parts list with specifications
3. Assembly instructions
4. Configuration settings for CNC Shield

### From Prompt 2:
1. Circuit diagrams for pulse conditioning
2. Interrupt handling code
3. Serial protocol implementation
4. Timing diagrams

### From Prompt 3:
1. Complete Arduino sketch
2. Configuration files
3. Test procedures
4. Troubleshooting guide

---

## Implementation Status

### Prompt 1: Hardware Design & Wiring Instructions
**Status:** COMPLETED
**Output File:** `SSP5A_Arduino_Hardware_Design.md`
**Created:** Contains complete hardware design, wiring diagrams, parts list, and assembly instructions.

### Prompt 2: Pulse Counting & Serial Communication Implementation
**Status:** COMPLETED  
**Output Files:**
- `SSP5A_Arduino_Pulse_Counting_Serial_Implementation.md` - Complete implementation documentation
- `SSP5A_Arduino_Pulse_Counting_Example.ino` - Example Arduino sketch with core functionality

**Contents:**
1. Pulse counting implementation with interrupt handling
2. Serial communication protocol (SSP) implementation
3. Stepper motor control using AccelStepper library
4. System state management and error handling
5. Timing requirements and precision implementation
6. Debug and monitoring capabilities
7. Circuit diagrams and testing procedures

### Prompt 3: Complete Arduino Sketch
**Status:** COMPLETED
**Output Files:**
- `SSP5A_Arduino_Complete_Sketch.ino` - Complete production-ready Arduino sketch
- `SSP5A_Arduino_Test_Procedures.md` - Comprehensive test procedures and troubleshooting guide

**Contents:**
1. Full SSP protocol implementation with all commands
2. Production-ready interrupt-driven pulse counting
3. Non-blocking state machine architecture
4. EEPROM configuration storage with checksum validation
5. Advanced error handling and recovery mechanisms
6. Debug output via SoftwareSerial for monitoring
7. Self-test and diagnostic routines
8. Performance monitoring and logging
9. Complete system integration of all components from Prompts 1 and 2
10. Comprehensive test procedures and troubleshooting guide

**Key Features Implemented:**
- Pin conflict resolution (PULSE_PIN_ALT = Pin 4 instead of Pin 2)
- Micros() overflow handling for long-term timing accuracy
- Configuration management with EEPROM storage and checksums
- Performance monitoring (interrupt latency, buffer usage, etc.)
- Error recovery system with automatic fault detection
- Status LED indication with multiple modes (error, integration, serial)
- Debug serial output for monitoring and troubleshooting
- Self-test routines for system validation
- Filter calibration routines (manual positioning)
- Utility functions for testing and debugging

**Complete System Integration:**
The final sketch integrates all hardware components from Prompt 1:
- Pulse counting with Schmitt trigger conditioning
- CNC Shield stepper control with DRV8825 drivers
- 12V→5V power regulation
- SSP5A 9-pin connector interface

And all software components from Prompt 2:
- SSP serial protocol (19200 baud, 8-N-1)
- Interrupt-driven pulse counting up to 50kHz
- Integration timing with ±1% accuracy
- Filter positioning with 100ms movement time
- Gain setting and mirror control
- System state management and error handling

---

This structured approach ensures each aspect of the project is addressed without overwhelming the context window. All three prompts have been completed, providing a complete Arduino-based SSPCARD replacement solution.
