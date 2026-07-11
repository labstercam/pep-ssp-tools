# SSP5A Arduino Controller - Arduino Cloud Serial Monitor Testing Guide

## Overview
This guide provides step-by-step instructions for testing the SSP5A Arduino Controller using the Arduino Cloud Serial Monitor. The goal is to verify that the Arduino sketch correctly emulates the SSPCARD protocol and works with SSPData3 software.

## Prerequisites

### Hardware Requirements
1. **Arduino Uno R3** with CNC Shield V3 and DRV8825 drivers
2. **SSP5A Photometer** or signal generator for pulse testing
3. **12V DC Power Supply** (2A minimum)
4. **USB Cable** for Arduino programming
5. **Pulse Source** (optional: signal generator for testing)

### Software Requirements
1. **Arduino IDE** or **Arduino Cloud Editor**
2. **SSP5A_Arduino_Simple_Test.ino** sketch
3. **Serial Terminal Software** (Arduino Serial Monitor, PuTTY, etc.)

## Step 1: Upload the Sketch to Arduino

### Using Arduino Cloud:
1. **Create Arduino Cloud Account** (if you don't have one)
2. **Create New Sketch** in Arduino Cloud Editor
3. **Copy and Paste** the contents of `SSP5A_Arduino_Simple_Test.ino`
4. **Select Board**: Arduino Uno
5. **Select Port**: Your Arduino's COM port
6. **Click Upload** to compile and upload to Arduino

### Using Arduino IDE:
1. **Open Arduino IDE**
2. **File → Open** → Select `SSP5A_Arduino_Simple_Test.ino`
3. **Tools → Board** → Select "Arduino Uno"
4. **Tools → Port** → Select your Arduino COM port
5. **Click Upload** (Ctrl+U)

### Verification:
- After upload, you should see "Done uploading" message
- The Arduino's built-in LED (Pin 13) should blink 3 times during startup
- Serial output should show: "SSP5A Simple Test Ready"
- Serial output should show: "Send 'SSSSSS' to enter serial mode"

## Step 2: Configure Serial Monitor

### Arduino Cloud Serial Monitor:
1. **Open Serial Monitor** in Arduino Cloud Editor
2. **Set Baud Rate**: 19200
3. **Set Line Ending**: "No line ending" or "Newline"
4. **Set Autoscroll**: Enabled

### Arduino IDE Serial Monitor:
1. **Tools → Serial Monitor** (Ctrl+Shift+M)
2. **Set Baud Rate**: 19200 (bottom right corner)
3. **Set Line Ending**: "No line ending"
4. **Set Autoscroll**: Enabled

## Step 3: Basic Communication Tests

### Test 1: Enter Serial Mode
```
Send: SSSSSS
Expected Response: !
```
**Purpose**: Enters serial mode (required before other commands)
**Notes**: The "!" indicates successful entry into serial mode

### Test 2: Exit Serial Mode
```
Send: EEEEEE
Expected Response: !
```
**Purpose**: Exits serial mode
**Notes**: Use this to return to normal mode

### Test 3: Invalid Command Test
```
Send: SX1234
Expected Response: ?
```
**Purpose**: Tests error handling
**Notes**: Any command not starting with 'S' or invalid format returns "?"

## Step 4: Filter Control Tests

### Test 4: Select Filter Position 1
```
Send: SF0011
Expected Response: !
```
**Purpose**: Moves filter wheel to position 1
**Notes**: You should hear/see stepper motor movement

### Test 5: Select Filter Position 3
```
Send: SF0013
Expected Response: !
```
**Purpose**: Moves filter wheel to position 3
**Notes**: Movement time should be ~200ms (2 positions)

### Test 6: Select Filter Position 6
```
Send: SF0016
Expected Response: !
```
**Purpose**: Moves filter wheel to position 6 (dark)
**Notes**: Final filter position

### Test 7: Invalid Filter Position
```
Send: SF0019
Expected Response: ?
```
**Purpose**: Tests error handling for invalid position
**Notes**: Only positions 1-6 are valid

## Step 5: Pulse Counting Tests

### Test 8: Basic Count Test (No Pulses)
```
Send: SC1000
Expected Response: C=00000
```
**Purpose**: Tests integration without pulse input
**Notes**: Should return zero counts after 1 second integration

### Test 9: Set Integration Time
```
Send: SI0500
Expected Response: !
```
**Purpose**: Sets integration time to 500ms
**Notes**: This time will be used for subsequent count commands

### Test 10: Count with 500ms Integration
```
Send: SC0500
Expected Response: C=00000
```
**Purpose**: Tests integration with custom time
**Notes**: Uses the 500ms set in previous command

## Step 6: Gain Control Tests

### Test 11: Set Gain 1
```
Send: SG0011
Expected Response: !
```
**Purpose**: Sets gain to position 1 (Gain 100)
**Notes**: Acknowledgment only - no visual feedback

### Test 12: Set Gain 2
```
Send: SG0012
Expected Response: !
```
**Purpose**: Sets gain to position 2 (Gain 10)

### Test 13: Set Gain 3
```
Send: SG0013
Expected Response: !
```
**Purpose**: Sets gain to position 3 (Gain 1)

### Test 14: Invalid Gain
```
Send: SG0014
Expected Response: ?
```
**Purpose**: Tests error handling for invalid gain
**Notes**: Only gains 1-3 are valid

## Step 7: Advanced Pulse Counting Tests (with Signal Generator)

### Test Setup:
1. **Connect Signal Generator** to Arduino Pin 4
2. **Configure Signal Generator**:
   - Waveform: Square wave
   - Amplitude: 0-5V TTL
   - Frequency: 1kHz (1000 Hz)
   - Duty Cycle: 50%

### Test 15: 1kHz Pulse Counting (1 second)
```
Send: SC1000
Expected Response: C=01000 (approximately)
```
**Purpose**: Tests pulse counting accuracy
**Notes**: Should return ~1000 counts ±1%

### Test 16: 1kHz Pulse Counting (500ms)
```
Send: SC0500
Expected Response: C=00500 (approximately)
```
**Purpose**: Tests variable integration timing
**Notes**: Should return ~500 counts ±1%

### Test 17: Different Frequencies
Test with various frequencies:
- 100 Hz: `C=00100` (approximately)
- 10 kHz: `C=10000` (approximately)
- 50 kHz: `C=50000` (approximately, maximum)

## Step 8: Timing Tests

### Test 18: Integration Timing Accuracy
1. **Start Stopwatch** when sending command
2. **Send**: `SC1000`
3. **Stop Stopwatch** when response appears
4. **Expected**: Response time = 1000ms + processing overhead (~150ms)

### Test 19: Multiple Sequential Integrations
```
Send: SC1000 (three times in rapid succession)
Expected: All three responses received correctly
```
**Purpose**: Tests command queuing and processing

## Step 9: SSPData3 Software Integration Test

### Test Setup:
1. **Install SSPData3** software on Windows PC
2. **Configure COM Port** in SSPData3:
   - Go to Setup → Select SSP COM Port
   - Choose your Arduino's COM port
   - Set baud rate to 19200

### Test 20: SSPData3 Connection Test
1. **SSPData3**: Click "Connect to SSP"
2. **Expected**: "Connected" message in SSPData3
3. **Arduino**: Should receive "SSSSSS" and respond with "!"

### Test 21: SSPData3 Filter Control
1. **SSPData3**: Select filter from dropdown (e.g., Filter 2)
2. **Expected**: Filter moves to position 2
3. **Arduino**: Should receive "SF0012" and respond with "!"

### Test 22: SSPData3 Pulse Counting
1. **SSPData3**: Set integration time (e.g., 1.00 seconds)
2. **SSPData3**: Click "Get Count"
3. **Expected**: Count value displayed in SSPData3
4. **Arduino**: Should receive "SC1000" and respond with "C=xxxxx"

## Step 10: Troubleshooting Common Issues

### Issue 1: No Serial Response
**Possible Causes**:
1. Incorrect baud rate (must be 19200)
2. Wrong line endings (use "No line ending")
3. Arduino not in serial mode (send "SSSSSS" first)
4. USB cable/port issue

**Solutions**:
1. Verify baud rate in serial monitor
2. Try different line ending settings
3. Ensure Arduino responds to "SSSSSS"
4. Try different USB cable/port

### Issue 2: Stepper Not Moving
**Possible Causes**:
1. DRV8825 enable pin active (should be LOW)
2. Incurrent current limit setting
3. Power supply issues
4. Incorrect wiring

**Solutions**:
1. Check DRV8825 enable pins (should be LOW)
2. Adjust VREF potentiometer (0.1V for 1A)
3. Verify 12V power supply
4. Check stepper wiring connections

### Issue 3: Pulse Counting Not Working
**Possible Causes**:
1. No pulse input signal
2. Incorrect pulse input pin (should be Pin 4)
3. Pulse conditioning circuit issues
4. Interrupt not configured

**Solutions**:
1. Test with signal generator
2. Verify pulse input connects to Arduino Pin 4
3. Check 74HC14 circuit (if used)
4. Verify interrupt configuration in code

### Issue 4: Integration Timing Inaccurate
**Possible Causes**:
1. Arduino clock calibration
2. System load affecting timing
3. Interrupt conflicts

**Solutions**:
1. Use `micros()` for precise timing
2. Minimize code in interrupt routines
3. Test with known pulse frequency

## Step 11: Performance Verification

### Pulse Counting Performance:
- **Maximum Frequency**: 50 kHz (should not miss pulses)
- **Accuracy**: ±1% across full range
- **Interrupt Latency**: <5µs

### Serial Communication Performance:
- **Command Processing**: <1ms typical
- **Response Time**: <10ms for simple commands
- **Integration Response**: Integration time + 150ms overhead

### Stepper Control Performance:
- **Movement Time**: 100ms between adjacent positions
- **Position Accuracy**: ±1 full step
- **Homing**: Returns to position 1 reliably

## Step 12: Complete Test Sequence

Run this complete sequence to verify all functionality:

1. `SSSSSS` → `!` (Enter serial mode)
2. `SF0011` → `!` (Move to filter 1)
3. `SF0013` → `!` (Move to filter 3)
4. `SF0016` → `!` (Move to filter 6)
5. `SF0011` → `!` (Return to filter 1)
6. `SG0012` → `!` (Set gain 2)
7. `SI1000` → `!` (Set integration 1000ms)
8. `SC1000` → `C=00000` (Count with no pulses)
9. `SI0500` → `!` (Set integration 500ms)
10. `SC0500` → `C=00000` (Count with no pulses)
11. `EEEEEE` → `!` (Exit serial mode)

## Step 13: Arduino Cloud Specific Notes

### Cloud Serial Monitor Limitations:
1. **No Local Echo**: Characters typed may not appear
2. **Line Ending Issues**: May need to try different settings
3. **Connection Stability**: Ensure stable internet connection
4. **Buffer Size**: Limited compared to desktop serial monitors

### Recommended Settings for Arduino Cloud:
1. **Baud Rate**: 19200
2. **Line Ending**: "Newline" or "Both NL & CR"
3. **Autoscroll**: Enabled
4. **Clear on Connect**: Disabled (to see startup messages)

### Alternative: Use Desktop Serial Monitor
If Arduino Cloud serial monitor has issues:
1. **Download** Arduino IDE
2. **Use Desktop Serial Monitor** (Tools → Serial Monitor)
3. **More reliable** for testing serial protocols

## Conclusion

By following this testing guide, you can verify that your SSP5A Arduino Controller:
1. **Correctly implements** the SSPCARD serial protocol
2. **Accurately counts pulses** from the SSP5A photometer
3. **Reliably controls** the filter wheel stepper motor
4. **Properly integrates** with SSPData3 software

All tests should pass before using the controller for actual astronomical observations. Document any issues found and refer to the troubleshooting section for solutions.

## Next Steps

After successful testing:
1. **Integrate with SSPData3** for actual photometry
2. **Calibrate filter positions** if needed
3. **Test with actual SSP5A photometer** and telescope
4. **Perform field tests** under observing conditions

## Support and Resources

- **Hardware Design**: `SSP5A_Arduino_Hardware_Design.md`
- **Complete Sketch**: `SSP5A_Arduino_Complete_Sketch.ino`
- **Test Procedures**: `SSP5A_Arduino_Test_Procedures.md`
- **SSPData3 Software**: Included in `SSPDataq/` folder

For additional help, refer to the documentation files or seek assistance from the astronomy/photometry community.