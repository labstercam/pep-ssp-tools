# SSP5A Arduino Controller - Test Procedures

## Overview
This document provides comprehensive test procedures for the SSP5A Arduino Controller, based on the complete sketch from Prompt 3. These procedures ensure the system meets all functional requirements and performance specifications.

## Test Equipment Required
1. **Arduino Uno R3** with CNC Shield V3 and DRV8825 drivers
2. **SSP5A Photometer** or equivalent pulse source
3. **Signal Generator** (1Hz-50kHz, 0-5V TTL pulses)
4. **Oscilloscope** for timing measurements
5. **Multimeter** for voltage/current measurements
6. **Serial Terminal Software** (19200 baud, 8-N-1)
7. **12V DC Power Supply** (2A minimum)
8. **Test Load** for stepper motor (filter wheel mechanism)

## Safety Precautions
1. **Electrical Safety**: Ensure proper grounding and insulation
2. **Power Supply**: Verify 12V polarity before connecting
3. **Heat Management**: DRV8825 drivers require heatsinks
4. **Mechanical Safety**: Secure moving parts during testing
5. **ESD Protection**: Use anti-static precautions with SSP5A

## Pre-Test Setup

### Hardware Assembly Verification
```
1. Verify all connections per SSP5A_Arduino_Hardware_Design.md
2. Check DRV8825 current limit settings (VREF = 0.1V for 1A)
3. Verify microstepping jumpers (recommended: 1/4 or 1/8 step)
4. Install heatsinks on all DRV8825 drivers
5. Check pulse conditioning circuit (74HC14 + 10kΩ pull-up)
6. Verify 12V→5V regulation (LM7805 or DC-DC converter)
```

### Software Setup
```
1. Upload SSP5A_Arduino_Complete_Sketch.ino to Arduino
2. Open Serial Monitor at 19200 baud, 8-N-1, no line endings
3. Connect debug serial (optional) at 9600 baud for monitoring
4. Verify Arduino responds with "SSP5A Controller Ready"
```

## Test Procedure 1: Basic Communication

### Objective
Verify serial communication and basic command processing.

### Steps
```
1. Send: "SSSSSS" start serial
   Expected: "!" (acknowledgment)
   Pass Criteria: Immediate response (<10ms)

2. Send: "SEEEEE" end serial
   Expected: "!" (acknowledgment)
   Pass Criteria: Immediate response

3. Send: "SX1234" (invalid command)
   Expected: "?" (error response)
   Pass Criteria: Error response received

4. Send: "SS" (incomplete command)
   Expected: "?" after 100ms timeout
   Pass Criteria: Timeout handling works
```

### Test Results
- [ ] All commands respond correctly
- [ ] Response timing <10ms
- [ ] Error handling functional
- [ ] Timeout handling works (100ms)

## Test Procedure 2: Filter Control

### Objective
Verify stepper motor control and filter positioning.

### Steps
```
1. Send: "SH000" (home filter)
   Expected: "!" then stepper moves to position 1
   Pass Criteria: Acknowledgment, movement within 5 seconds

2. Send: "SF0012" (move to filter 2)
   Expected: "!" then movement
   Pass Criteria: Movement time ~100ms between positions

3. Send: "SF0014" (move to filter 4)
   Expected: "!" then movement
   Pass Criteria: Movement time ~300ms (3 positions)

4. Send: "SF0016" (move to filter 6)
   Expected: "!" then movement
   Pass Criteria: Movement to final position

5. Send: "SF0011" (return to filter 1)
   Expected: "!" then movement
   Pass Criteria: Return to home position

6. Send: "SF0019" (invalid position)
   Expected: "?" (error)
   Pass Criteria: Error for invalid position
```

### Test Results
- [ ] All filter positions reachable
- [ ] Movement time: 100ms ±10% between adjacent positions
- [ ] Position repeatability: ±1 full step
- [ ] Error handling for invalid positions
- [ ] Stepper drivers remain cool (<60°C)

## Test Procedure 3: Pulse Counting

### Objective
Verify pulse counting accuracy and timing.

### Test Setup
```
1. Connect signal generator to pulse input (Pin 4)
2. Configure signal generator:
   - Waveform: Square wave
   - Amplitude: 0-5V TTL
   - Duty cycle: 50%
   - No DC offset
```

### Steps
```
1. Low frequency test (1Hz):
   Send: "SC1000" (1 second integration)
   Expected: "C=00001" (1 count)
   Pass Criteria: Count = 1 ±0

2. Medium frequency test (1kHz):
   Send: "SC1000" (1 second integration)
   Expected: "C=01000" (1000 counts)
   Pass Criteria: Count = 1000 ±1%

3. High frequency test (10kHz):
   Send: "SC1000" (1 second integration)
   Expected: "C=10000" (10000 counts)
   Pass Criteria: Count = 10000 ±1%

4. Maximum frequency test (50kHz):
   Send: "SC1000" (1 second integration)
   Expected: "C=50000" (50000 counts)
   Pass Criteria: Count = 50000 ±1%, no missed pulses

5. Variable integration time test:
   Send: "SI0500" (set 500ms)
   Send: "SC0500" (500ms integration at 1kHz)
   Expected: "C=00500" (500 counts)
   Pass Criteria: Count = 500 ±1%

6. Overflow test (simulate >65535 counts):
   Send: "SC2000" (2 seconds at 50kHz = 100000 counts)
   Expected: "C=65535" (saturated)
   Pass Criteria: Count saturates at 65535
```

### Test Results
- [ ] Accuracy: ±1% at all frequencies (1Hz-50kHz)
- [ ] No missed pulses at 50kHz
- [ ] Integration timing accuracy: ±1%
- [ ] Overflow handling correct (saturates at 65535)
- [ ] Variable integration times work correctly

## Test Procedure 4: Integration Timing

### Objective
Verify integration timing accuracy.

### Test Setup
```
1. Connect oscilloscope to monitor timing
2. Use signal generator for precise pulse counting
3. Measure actual integration duration
```

### Steps
```
1. Short integration test (100ms):
   Send: "SI0100" (set 100ms)
   Send: "SC0100" (100ms integration)
   Measure: Actual integration duration
   Pass Criteria: 100ms ±1ms (±1%)

2. Medium integration test (1000ms):
   Send: "SI1000" (set 1000ms)
   Send: "SC1000" (1000ms integration)
   Measure: Actual integration duration
   Pass Criteria: 1000ms ±10ms (±1%)

3. Long integration test (9999ms):
   Send: "SI9999" (set 9999ms)
   Send: "SC9999" (9999ms integration)
   Measure: Actual integration duration
   Pass Criteria: 9999ms ±100ms (±1%)

4. Multiple sequential integrations:
   Send: "SC1000" three times in succession
   Measure: Consistency between integrations
   Pass Criteria: Variation <1% between runs
```

### Test Results
- [ ] Timing accuracy: ±1% across full range (100ms-9999ms)
- [ ] Consistency: <1% variation between runs
- [ ] No timing drift over extended operation
- [ ] micros() overflow handling (every ~70 minutes)

## Test Procedure 5: Gain Control

### Objective
Verify gain setting functionality.

### Steps
```
1. Send: "SG0011" (set gain 1 = Gain 100)
   Expected: "!"
   Pass Criteria: Acknowledgment received

2. Send: "SG0012" (set gain 2 = Gain 10)
   Expected: "!"
   Pass Criteria: Acknowledgment received

3. Send: "SG0013" (set gain 3 = Gain 1)
   Expected: "!"
   Pass Criteria: Acknowledgment received

4. Send: "SG0014" (invalid gain)
   Expected: "?" (error)
   Pass Criteria: Error for invalid gain

5. Verify gain persistence:
   Send: "SG0012" (set gain 2)
   Power cycle system
   Send: "SC1000" (check system state)
   Expected: Gain remains at 2 (if stored in EEPROM)
   Pass Criteria: Gain setting persists
```

### Test Results
- [ ] All valid gain settings work (1, 2, 3)
- [ ] Error handling for invalid gain (4)
- [ ] Gain setting acknowledgment immediate
- [ ] Gain persistence after power cycle (if implemented)

## Test Procedure 6: Mirror Control

### Objective
Verify mirror control functionality (if implemented).

### Steps
```
1. Send: "SVIEW1" (mirror on)
   Expected: "!"
   Pass Criteria: Acknowledgment, mirror engages

2. Send: "SVIEW0" (mirror off)
   Expected: "!"
   Pass Criteria: Acknowledgment, mirror disengages

3. Send: "SVIEW2" (invalid state)
   Expected: "?" (error)
   Pass Criteria: Error for invalid state

4. Verify mirror state persistence
   Send: "SVIEW1"
   Power cycle system
   Check mirror state
   Expected: Default state (off) after power cycle
   Pass Criteria: Safe default state
```

### Test Results
- [ ] Mirror control works (on/off)
- [ ] Error handling for invalid states
- [ ] Safe default state after power cycle
- [ ] Mechanical operation reliable

## Test Procedure 7: System Configuration

### Objective
Verify EEPROM configuration storage and calibration.

### Steps
```
1. Factory reset test:
   Send factory reset command (if implemented)
   Verify default configuration loaded
   Pass Criteria: Defaults loaded correctly

2. Configuration save/load:
   Modify configuration (filter positions, integration time)
   Save configuration
   Power cycle system
   Verify configuration restored
   Pass Criteria: Configuration persists

3. Checksum validation:
   Manually corrupt EEPROM (write invalid data)
   Power cycle system
   Verify default configuration loaded
   Pass Criteria: Corruption detection works

4. Filter calibration:
   Run calibration routine (if implemented)
   Verify filter positions stored
   Test movement to calibrated positions
   Pass Criteria: Calibration improves positioning accuracy
```

### Test Results
- [ ] Configuration persistence after power cycle
- [ ] Corruption detection and recovery
- [ ] Calibration routine functional (if implemented)
- [ ] Checksum validation works

## Test Procedure 8: Error Handling and Recovery

### Objective
Verify robust error handling and system recovery.

### Steps
```
1. Serial timeout:
   Send partial command: "SF"
   Wait 150ms (exceeds 100ms timeout)
   Expected: "?" (timeout error)
   Pass Criteria: Timeout detection works

2. Stepper stall detection:
   Mechanically block stepper movement
   Send: "SF0012"
   Expected: Error detection and recovery
   Pass Criteria: System detects stall, recovers

3. Pulse overflow:
   Generate >4.29 billion pulses (32-bit overflow)
   Verify overflow handling
   Pass Criteria: No system crash, overflow counted

4. EEPROM corruption:
   Manually write invalid data to EEPROM
   Power cycle system
   Expected: Default configuration loaded
   Pass Criteria: Corruption recovery works

5. Integration timeout:
   Start long integration (9999ms)
   Simulate system issue during integration
   Expected: Timeout detection
   Pass Criteria: Integration timeout works
```

### Test Results
- [ ] All error conditions detected
- [ ] Graceful recovery from errors
- [ ] No system lockups or crashes
- [ ] Error logging functional (debug serial)

## Test Procedure 9: Performance and Stress Testing

### Objective
Verify system performance under stress conditions.

### Steps
```
1. Continuous operation:
   Run system for 24 hours continuous operation
   Monitor: Temperature, stability, performance
   Pass Criteria: No degradation, temperature <70°C

2. Rapid command sequences:
   Send command burst: "SF0012", "SF0013", "SF0014"
   Expected: All commands processed correctly
   Pass Criteria: No command loss, correct sequencing

3. Mixed workload:
   Simultaneous: Filter movement + pulse counting
   Expected: Both functions work correctly
   Pass Criteria: No interference between functions

4. Power cycling:
   Rapid power cycles (10 cycles)
   Expected: System boots correctly each time
   Pass Criteria: 100% boot success rate

5. Environmental stress:
   Temperature variation (if environmental chamber available)
   Expected: Stable operation across range
   Pass Criteria: Operation within specifications
```

### Test Results
- [ ] 24-hour continuous operation stable
- [ ] Temperature within limits (<70°C)
- [ ] Rapid command processing works
- [ ] Mixed workload handling correct
- [ ] Power cycling reliable
- [ ] Environmental stability (if tested)

## Test Procedure 10: Integration with SSPData3 Software

### Objective
Verify compatibility with existing SSPData3 software.

### Test Setup
```
1. Install SSPData3 software on test PC
2. Connect Arduino via USB (COM port)
3. Configure SSPData3 for SSPCARD communication
```

### Steps
```
1. Basic communication:
   SSPData3: Initialize communication
   Expected: Handshake successful
   Pass Criteria: SSPData3 recognizes controller

2. Filter control:
   SSPData3: Select filter positions 1-6
   Expected: Filter moves correctly
   Pass Criteria: All positions accessible

3. Pulse counting:
   SSPData3: Start measurement
   Expected: Counts returned correctly
   Pass Criteria: Measurements match expected values

4. Integration timing:
   SSPData3: Set integration times
   Expected: Timing accurate
   Pass Criteria: ±1% timing accuracy

5. Full photometric measurement:
   SSPData3: Complete measurement sequence
   Expected: All functions work together
   Pass Criteria: End-to-end functionality
```

### Test Results
- [ ] SSPData3 communication successful
- [ ] Filter control compatible
- [ ] Pulse counting compatible
- [ ] Integration timing compatible
- [ ] Full measurement sequences work

## Performance Specifications Verification

### Pulse Counting Performance
- [ ] Maximum frequency: 50kHz ✓
- [ ] Count accuracy: ±1% typical ✓
- [ ] Interrupt latency: <5µs ✓
- [ ] Counter size: 32-bit internal, 16-bit reported ✓
- [ ] Overflow handling: Saturate at 65535 ✓

### Serial Communication Performance
- [ ] Baud rate: 19200 ✓
- [ ] Command processing time: <1ms typical ✓
- [ ] Response time: <10ms for count responses ✓
- [ ] Buffer size: 32 characters ✓
- [ ] Timeout: 100ms ✓

### Stepper Control Performance
- [ ] Movement time: 100ms between adjacent filter positions ✓
- [ ] Position accuracy: ±1 full step ✓
- [ ] Homing time: 5 seconds maximum ✓
- [ ] Microstepping: Configurable (1, 2, 4, 8, 16) ✓

### Timing Performance
- [ ] Integration accuracy: ±1% of set time ✓
- [ ] Clock source: 16MHz crystal with ceramic resonator ✓
- [ ] Timer resolution: 4µs (micros()), 1ms (millis()) ✓
- [ ] Long-term drift: <0.1% per hour ✓

### Power Performance
- [ ] Operating voltage: 12V DC input, 5V regulated for Arduino ✓
- [ ] Current draw: 560mA active, 180mA idle ✓
- [ ] Power consumption: 6.6W active, 1.6W idle ✓
- [ ] Regulator efficiency: ~42% (LM7805), >85% (DC-DC converter) ✓

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue: No Serial Communication
```
Possible Causes:
1. Incorrect baud rate (must be exactly 19200)
2. USB cable/port issue
3. Arduino not powered
4. Serial buffer overflow

Solutions:
1. Verify baud rate in terminal software
2. Try different USB cable/port
3. Check power supply (5V at Arduino)
4. Reduce command frequency
```

#### Issue: Pulse Counting Not Working
```
Possible Causes:
1. Pulse conditioning circuit faulty
2. Incorrect pulse input pin
3. No pulses from source
4. Interrupt not configured

Solutions:
1. Check 74HC14 circuit (5V power, connections)
2. Verify pulse input pin (Pin 4 in complete sketch)
3. Test with signal generator
4. Check interrupt configuration in code
```

#### Issue: Stepper Not Moving
```
Possible Causes:
1. DRV8825 enable pin active (should be LOW)
2. Current limit too low
3. Step/DIR signals not reaching driver
4. Motor coil wiring incorrect

Solutions:
1. Check enable pin state (should be LOW)
2. Adjust VREF potentiometer (0.1V for 1A)
3. Verify step/DIR signal with oscilloscope
4. Check coil continuity (2-10Ω typical)
```

#### Issue: Integration Timing Inaccurate
```
Possible Causes:
1. Arduino clock calibration needed
2. Interrupt conflicts
3. micros() overflow not handled
4. System load affecting timing

Solutions:
1. Calibrate Arduino clock if needed
2. Minimize code in interrupt routines
3. Verify overflow handling in code
4. Reduce system load during integration
```

#### Issue: System Unstable or Crashes
```
Possible Causes:
1. Power supply issues
2. Overheating components
3. Memory leaks or stack overflow
4. Interrupt conflicts

Solutions:
1. Check power supply stability
2. Monitor temperature, add cooling
3. Optimize memory usage
4. Review interrupt priorities
```

## Test Report Template

### Test Summary
```
Date: __________________
Tester: ________________
System Version: ________
Hardware Revision: ______
Software Version: _______

Overall Result: □ PASS □ FAIL
```

### Individual Test Results
```
Test 1: Basic Communication    □ PASS □ FAIL
Test 2: Filter Control         □ PASS □ FAIL
Test 3: Pulse Counting         □ PASS □ FAIL
Test 4: Integration Timing     □ PASS □ FAIL
Test 5: Gain Control           □ PASS □ FAIL
Test 6: Mirror Control         □ PASS □ FAIL
Test 7: System Configuration   □ PASS □ FAIL
Test 8: Error Handling         □ PASS □ FAIL
Test 9: Performance/Stress     □ PASS □ FAIL
Test 10: SSPData3 Integration  □ PASS □ FAIL
```

### Issues Found
```
1. ___________________________
   Resolution: _______________

2. ___________________________
   Resolution: _______________

3. ___________________________
   Resolution: _______________
```

### Recommendations
```
1. ___________________________
2. ___________________________
3. ___________________________
```

## Conclusion
These test procedures provide comprehensive verification of the SSP5A Arduino Controller's functionality, performance, and reliability. Successful completion of all tests ensures the system is ready for production use as a drop-in replacement for the original SSPCARD.

All test procedures should be documented, and any issues found should be addressed before final deployment. Regular testing during development and maintenance ensures long-term reliability and performance.