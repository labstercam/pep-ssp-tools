# SSP5A Serial Interference Fix Guide

## Problem
When you turn on the SSP5A photometer, the Arduino Serial Monitor displays `?` characters (about 10 initially, then 2 per second).

## Root Cause
The SSP5A pulse output is being interpreted as serial data by the Arduino. At 19200 baud, the pulses can create valid serial characters that the Arduino processes as invalid commands, resulting in `?` responses.

## Solution 1: Software Fix (Recommended)

### Upload the Fixed Sketch
1. **Open Arduino IDE** or **Arduino Cloud Editor**
2. **Upload** `SSP5A_Arduino_Fixed_Simple_Test.ino` to your Arduino
3. **This sketch includes:**
   - Only processes serial commands when in serial mode
   - Clears serial buffer on startup
   - Filters non-printable characters
   - Discards serial data when not in serial mode

### Test the Fix
1. **Open Serial Monitor** at 19200 baud
2. **Turn on SSP5A** - Should NOT see `?` characters
3. **Send**: `SSSSSS` → Should receive `!`
4. **Send**: `SC1000` → Should receive `C=00000`

## Solution 2: Hardware Fix

### Pulse Conditioning Circuit
Ensure you have the proper pulse conditioning circuit:
```
SSP5A Pin 9 (Gray) → 10kΩ pull-up resistor → 74HC14 Schmitt Trigger → Arduino Pin 4
                      │                       (6x inverter with        (Pulse input)
                      └→ 100nF capacitor to GND   hysteresis)
```

### Critical Wiring Checks
1. **SSP5A Pin 9** → **Arduino Pin 4** (NOT Pin 0 or Pin 1 - serial pins)
2. **All grounds connected**: SSP5A Pin 5, Arduino GND, power supply GND
3. **74HC14 powered**: 5V to pin 14, GND to pin 7

### Alternative: Use Different Pulse Pin
If using Pin 4 causes issues with CNC Shield:
1. **Change** `#define PULSE_PIN` in the sketch to **Pin 8** or **Pin 9**
2. **Update wiring** accordingly
3. **Update interrupt** if needed (Pins 2 and 3 have interrupts on Uno)

## Solution 3: Combined Approach

### Best Practice
1. **Use the fixed sketch** (`SSP5A_Arduino_Fixed_Simple_Test.ino`)
2. **Build proper pulse conditioning** (74HC14 circuit)
3. **Verify all connections** with multimeter
4. **Test with signal generator** before SSP5A

## Testing Procedure

### Step 1: Without SSP5A
1. Upload fixed sketch
2. Open Serial Monitor
3. Send `SSSSSS` → `!`
4. Send `SC1000` → `C=00000`
5. No `?` characters should appear

### Step 2: With SSP5A (Powered Off)
1. Connect SSP5A (power off)
2. Open Serial Monitor
3. Should see no `?` characters

### Step 3: With SSP5A (Powered On)
1. Turn on SSP5A
2. Should see no `?` characters (or very few)
3. Send `SSSSSS` → `!`
4. Send `SC1000` → `C=xxxxx` (actual counts)

## If Problem Persists

### Check 1: Serial Port Conflicts
1. **Disconnect SSP5A** from Arduino
2. **Test serial communication** alone
3. If still issues, check USB cable/port

### Check 2: Pulse Signal Quality
1. **Use oscilloscope** to view SSP5A Pin 9 output
2. **Should see** clean 0-5V pulses
3. **If noisy**, improve pulse conditioning circuit

### Check 3: Ground Loops
1. **Ensure single ground point** for all components
2. **Check for ground loops** causing noise
3. **Use shielded cable** for pulse signal if needed

## Quick Fix Summary

1. **Upload**: `SSP5A_Arduino_Fixed_Simple_Test.ino`
2. **Wire**: SSP5A Pin 9 → 74HC14 → Arduino Pin 4
3. **Test**: Turn on SSP5A, check for `?` characters
4. **Command**: `SSSSSS` → `!`, `SC1000` → `C=00000`

## Next Steps

After fixing serial interference:
1. **Test filter control**: `SF0011` → `!` (filter movement)
2. **Test gain control**: `SG0012` → `!`
3. **Test with SSPData3**: Use `SSP5A_Arduino_SSPDataq3_Compatible.ino`
4. **Perform full system test** with actual photometry

## Support

If issues persist:
1. **Check all documentation** in the project
2. **Review hardware design**: `SSP5A_Arduino_Hardware_Design.md`
3. **Test with signal generator** instead of SSP5A
4. **Contact astronomy/photometry community** for help