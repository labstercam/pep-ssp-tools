# SSP5A Arduino Controller - Getting Started Guide

## Overview
This guide provides everything you need to get your SSP5A Arduino controller working with SSPData3 software. You have all the necessary files and documentation to successfully test and deploy your Arduino-based SSPCARD replacement.

## What You Have Available

### 1. Arduino Sketches
- **`SSP5A_Arduino_Simple_Test.ino`** - Your uploaded sketch for basic testing
- **`SSP5A_Arduino_SSPDataq3_Compatible.ino`** - Production version (no startup messages)
- **`SSP5A_Arduino_Complete_Sketch.ino`** - Full-featured version with debug output

### 2. Documentation Files
- **`SSP5A_Arduino_Cloud_Testing_Guide.md`** - Step-by-step testing with Arduino Cloud
- **`SSP_Protocol_Command_Reference.md`** - Complete SSP protocol reference
- **`SSP5A_Arduino_Hardware_Design.md`** - Hardware wiring and assembly
- **`SSP5A_Arduino_Test_Procedures.md`** - Comprehensive testing procedures

### 3. SSPData3 Software
- **`SSPDataq/SSPDataq3_3,21.bas`** - Source code for SSPData3 software
- **`SSPDataq/` folder** - Contains all SSPData3 files and documentation

## Quick Start: Testing Your Arduino Sketch

### Step 1: Upload the Sketch
1. **Open Arduino IDE** or **Arduino Cloud Editor**
2. **Upload** `SSP5A_Arduino_Simple_Test.ino` to your Arduino Uno
3. **Verify** upload is successful (LED blinks 3 times)

### Step 2: Test Basic Communication
1. **Open Serial Monitor** at 19200 baud
2. **Send**: `SSSSSS`
3. **Expected**: `!` (acknowledgment)
4. **Send**: `SC1000`
5. **Expected**: `C=00000` (zero counts with no pulse input)

### Step 3: Test Filter Control
1. **Send**: `SF0011` → `!` (filter position 1)
2. **Send**: `SF0013` → `!` (filter position 3)
3. **Send**: `SF0016` → `!` (filter position 6 - dark)
4. **Listen/observe** stepper motor movement

## Testing with Arduino Cloud Serial Monitor

### Key Settings for Arduino Cloud:
1. **Baud Rate**: 19200
2. **Line Ending**: "Newline" or "Both NL & CR"
3. **Autoscroll**: Enabled
4. **Clear on Connect**: Disabled

### Complete Test Sequence:
Run this sequence to verify all functionality:
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

## Connecting to SSPData3 Software

### Step 1: Prepare for SSPData3
1. **Use the compatible sketch**: `SSP5A_Arduino_SSPDataq3_Compatible.ino`
2. **Upload this sketch** (it has NO startup messages)
3. **Note your Arduino's COM port** (e.g., COM3, COM4)

### Step 2: Configure SSPData3
1. **Run SSPData3 software** from the `SSPDataq/` folder
2. **Setup → Select SSP COM Port** → Choose your Arduino's COM port
3. **Click "Connect to SSP"**
4. **Expected**: "Connected" message in SSPData3

### Step 3: Test SSPData3 Functions
1. **Select filter** from dropdown menu
2. **Set gain** (1, 10, or 100)
3. **Set integration time** (e.g., 1.00 seconds)
4. **Click "Get Count"** to perform measurement

## Troubleshooting Common Issues

### Issue: No Serial Response
**Solution**:
1. Check baud rate is exactly 19200
2. Try different line ending settings
3. Send `SSSSSS` first (enter serial mode)
4. Try Arduino IDE Serial Monitor instead of Cloud

### Issue: Stepper Not Moving
**Solution**:
1. Check DRV8825 enable pins (should be LOW)
2. Verify 12V power supply is connected
3. Check stepper wiring connections
4. Adjust VREF potentiometer (0.1V for 1A)

### Issue: SSPData3 Won't Connect
**Solution**:
1. Use `SSP5A_Arduino_SSPDataq3_Compatible.ino` (no startup messages)
2. Check COM port selection in SSPData3
3. Verify baud rate is 19200
4. Test with Arduino Serial Monitor first

## Hardware Setup Verification

### Critical Connections:
1. **SSP5A Pin 9 (Gray)** → **Arduino Pin 4** (pulse input in Simple Test sketch)
2. **SSP5A Pins 2,3,4,7** → **CNC Shield stepper outputs**
3. **SSP5A Pin 1 (Red)** → **+12V power input**
4. **SSP5A Pin 5 (Green)** → **Arduino GND**

### Pulse Conditioning Circuit (Recommended):
```
SSP5A Pin 9 → 10kΩ pull-up → 74HC14 Schmitt Trigger → Arduino Pin 4
                │                       (6x inverter with        (INT0)
                └→ 100nF capacitor to GND   hysteresis)
```

## Next Steps After Successful Testing

### 1. Production Deployment
1. **Upload** `SSP5A_Arduino_SSPDataq3_Compatible.ino` for use with SSPData3
2. **Calibrate filter positions** if needed
3. **Test with actual SSP5A photometer**

### 2. Advanced Testing
1. **Use signal generator** to test pulse counting accuracy
2. **Test at various frequencies** (1Hz to 50kHz)
3. **Verify integration timing** with oscilloscope
4. **Perform 24-hour stability test**

### 3. Field Deployment
1. **Integrate with telescope** and SSP5A photometer
2. **Perform actual astronomical observations**
3. **Compare results** with original SSPCARD

## Key Resources

### Documentation Files:
- **Testing Guide**: `SSP5A_Arduino_Cloud_Testing_Guide.md`
- **Protocol Reference**: `SSP_Protocol_Command_Reference.md`
- **Hardware Design**: `SSP5A_Arduino_Hardware_Design.md`
- **Test Procedures**: `SSP5A_Arduino_Test_Procedures.md`

### Arduino Sketches:
- **Simple Test**: `SSP5A_Arduino_Simple_Test.ino` (your uploaded sketch)
- **SSPData3 Compatible**: `SSP5A_Arduino_SSPDataq3_Compatible.ino`
- **Complete Version**: `SSP5A_Arduino_Complete_Sketch.ino`

### SSPData3 Software:
- **Main Program**: `SSPDataq/SSPDataq3_3,21.bas`
- **Configuration**: `SSPDataq/dparms.txt`
- **Help Files**: `SSPDataq/SSPDataq3.chm`

## Support and Community

### If You Encounter Issues:
1. **Refer to troubleshooting sections** in the documentation
2. **Check hardware connections** against wiring diagrams
3. **Test with Arduino Serial Monitor** before SSPData3
4. **Use signal generator** to verify pulse counting

### For Advanced Help:
1. **Review SSP protocol** in command reference
2. **Examine SSPData3 source code** for timing expectations
3. **Consult astronomy/photometry communities**
4. **Refer to original SSPCARD documentation**

## Success Checklist

- [ ] Arduino sketch uploads successfully
- [ ] Serial communication works at 19200 baud
- [ ] Basic commands (`SSSSSS`, `SC1000`) work
- [ ] Filter control commands (`SF001n`) move stepper
- [ ] Gain control commands (`SG001n`) work
- [ ] SSPData3 software connects successfully
- [ ] SSPData3 can control filter positions
- [ ] SSPData3 can perform measurements
- [ ] Pulse counting works with signal generator
- [ ] Integration timing is accurate (±1%)

## Conclusion

You now have a complete Arduino-based SSPCARD replacement system. The provided documentation and test procedures will help you verify that everything works correctly before using it for actual astronomical observations.

Start with the simple tests using Arduino Cloud Serial Monitor, then progress to SSPData3 integration. Once all tests pass, you can confidently use your Arduino controller with the SSP5A photometer for photometric measurements.

Good luck with your astronomical observations!