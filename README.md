# pep-ssp-tools
Tools for operating the Optec Photoelectric Photometers (PEP).

**Current Version: v0.1.5** - Dockable SSP Data Acquisition Window

Use entirely at your own risk. Please contact me with suggestions or feedback through the AAVSO PEP forum or through GitHub.

The SSP series Photometers by Optec have long since gone out of production but are still in use as they are one of the few ways to do high accuracy photometry of very bright stars. The data collection software is still available but is no longer actively supported. This repository is my attempt to port or redevelop the software to run using IronPython in SharpCap. It enables a much more efficient data collection workflow with full telescope and guide camera control, and the possibility of connecting slider and flip mirror actuators using standard SharpCap functionality. It will also bring the development into a modern Python language, which can be run in SharpCap or the open source IronPython console, and should be easy to maintain and distribute.

## SharpCap-SSP
Working prototype of SSP data collection software using SharpCap. Features include:
- ✅ Full serial communication with SSP-3a/SSP-5a photometers
- ✅ Data collection (Slow, Trial modes) with .raw file export
- ✅ **NEW:** .tab file export suited to direct copy into the Excel analysis spreadsheets
- ✅ Star catalog integration with 300+ PEP targets
- ✅ First Order Extinction star selection with airmass filtering (150+ standards)
- ✅ Real-time Alt/Az coordinate display for all targets
- ✅ **NEW:** Dockable SSP Data Acquisition Window — snaps to SharpCap bottom with user-resizable dimensions
- ✅ All Sky Calibration tool for extinction coefficient calculation (K'v, K'bv)
- ✅ Automated and manual filter bar control
- ✅ GOTO telescope integration
- ✅ Night mode UI with proper button highlighting

https://github.com/labstercam/pep-ssp-tools/tree/main/SharpCap-SSP

<img width="1087" height="337" alt="image" src="https://github.com/user-attachments/assets/2c65aa47-65c9-4127-acf0-3284eee6c040" />

## ARDUINO_SSPCARD
Arduino-based replacement for SSPCARD hardware to control SSP5A photometers. Provides modern, open-source hardware alternative with CNC shield stepper control and SSP protocol compatibility. Current status is there is a working Arduino sketch that can collect data from an SSP5 with the round cable connector, replacing the SSPCARD PC card.

https://github.com/labstercam/pep-ssp-tools/tree/main/ARDUINO_SSPCARD

## Optec SSPDataq 3 and 4
The legacy software from Optec.  https://www.optecinc.com/downloads/legacy/sspdataq/ Uses LibertyBasic

## ssp4-control-software
Open-source control software suite for Optec's SSP-4 photometer (NIR J/H-band) distributed under the GPLv3 license.  C# code written by Brian
Kloppenborg. No longer maintained https://github.com/bkloppenborg/ssp4-control-software
