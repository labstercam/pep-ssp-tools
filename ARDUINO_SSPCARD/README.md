# ARDUINO_SSPCARD - Arduino-based SSPCARD Replacement

This folder contains all Arduino development files for the SSP5A photometer controller replacement project.

## Overview

The Arduino SSPCARD replacement project provides a modern, open-source alternative to the original SSPCARD hardware for controlling SSP5A photometers. This implementation uses an Arduino Uno/Nano with a CNC Shield for stepper motor control and serial communication compatibility with SSPData3 software.

It is still a work in progress. Currently it can read pulse counts and move the stepper motor but still need to calibrate the stepper motor drivers to move the sliders by the correct amount. 

The latest working version is SSP5A_Arduino_SerialOnly.ino which only implements the data collection and works with SharpCap SSP.

## Quick Start

### Main Working Sketch
**`Sketches/SSP5A_Arduino_SerialOnly.ino`** which only implements the data collection and works with SharpCap SSP.

### Alternative Sketches
**`Sketches/SSP5A_Arduino_BothAxes.ino`** - The primary working sketch that:
- Controls filter wheel stepper motor (moves both X and Y axes together)
- Implements SSP protocol for SSPData3 compatibility
- Includes aggressive serial noise filtering
- No startup messages (completely silent on power-up)


- **`Sketches/SSP5A_Arduino_Stepper_NoStartup.ino`** - No startup messages version
- **`Sketches/SSP5A_Stepper_Diagnostic.ino`** - Diagnostic tool for stepper motor testing

## File Organization

### `Sketches/` - Arduino Sketches
- **Current working sketches**: `SSP5A_Arduino_BothAxes.ino`, `SSP5A_Arduino_Stepper_NoStartup.ino`, `SSP5A_Stepper_Diagnostic.ino`
- **Archive sketches**: See `Archive/Sketches_Archive/` for development history

### `Documentation/` - Project Documentation
- `SSP5A_Arduino_Hardware_Design_Updated.md` - Latest hardware design and wiring
- `SSP5A_Arduino_Getting_Started_Guide.md` - Setup and installation guide
- `SSP5A_Arduino_Cloud_Testing_Guide.md` - Testing with Arduino Cloud
- `SSP5A_Arduino_Test_Procedures.md` - Testing procedures
- `SSP5A_Arduino_Controller_Prompts.md` - Controller command reference
- `SSP5A_Serial_Interference_Fix.md` - Serial communication fixes
- `SSP5A_Arduino_Pulse_Counting_Serial_Implementation.md` - Pulse counting implementation
- `SSP_Protocol_Command_Reference.md` - SSP protocol command reference

### `PDFs/` - PDF Documents
- `sspcard technical manual.pdf` - Original SSPCARD technical manual

### `Archive/` - Historical Versions
- `Archive/Sketches_Archive/` - Previous sketch versions
- `Archive/Documentation_Archive/` - Older documentation

## Hardware Requirements

1. **Arduino Uno/Nano** (or compatible)
2. **CNC Shield V3** with DRV8825 stepper drivers
3. **SSP5A Photometer** with 9-pin connector
4. **12V Power Supply** for CNC shield
5. **74HC14 Schmitt Trigger** for pulse conditioning (optional)

## Wiring Configuration

### Stepper Motor Wiring (Option 2 - Working Configuration):
- SSP5A Pin 7 (Black) → Motor Pin B2
- SSP5A Pin 4 (Orange) → Motor Pin B1
- SSP5A Pin 3 (Brown) → Motor Pin A2
- SSP5A Pin 2 (Yellow) → Motor Pin A1

Motor pin layout is not obvious on the board. Each stepper driver (X, Y, Z, A) has a column of four pins on RHS. From bottom up they are A2, A1, B1, B2.

### CNC Shield Connections:
- **X-axis**: Controls Coil A (pins 2-3)
- **Y-axis**: Controls Coil B (pins 1-4)
- **Pulse Input**: Pin A4 (SDA) on CNC shield serial panel

## Testing

1. Upload `SSP5A_Arduino_BothAxes.ino` to Arduino
2. Open Serial Monitor at 19200 baud
3. Send `SSSSSS` to enter serial mode (should receive `!`)
4. Send `SF0011` to move to filter 1 (should hear stepper movement)
5. Send `SF0016` to move to filter 6 (dark)
6. Send `SC1000` to test pulse counting (should receive `C=00000`)

## Compatibility

- **SSPData3 Software**: Fully compatible with SSP protocol
- **Arduino Cloud**: Tested with serial monitor
- **Original SSP5A Hardware**: Uses same 9-pin connector

## Development Notes

This project was developed to replace the original SSPCARD hardware with an Arduino-based solution. Key features:

1. **Stepper Motor Control**: Uses both X and Y axes together for unusual motor winding configuration
2. **Serial Protocol**: Implements exact SSP protocol for software compatibility
3. **Noise Filtering**: Aggressive filtering of SSP5A pulse interference
4. **Modular Design**: Easy to modify and extend

## Troubleshooting

See `SSP5A_Arduino_Test_Procedures.md` for detailed troubleshooting steps.

## License

This project is open source. See the root `LICENSE` file for details.
