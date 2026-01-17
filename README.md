# pep-ssp-tools
Tools for operating the SSP3 and 4 Photoelectric Photometers (PEP).

Prototype development at the moment. Use entirely at your own risk. Please contact me with suggestions or feedback.

The SSP series Photometers by Optec have long since gone out of production but are still in use as they are one of the few ways to do high accuracy photometry of very bright stars. The data collection software is still available but is no longer actively supported. This repository is my attempt to port or redevelop the software to run using IronPython in SharpCap. If successful, it will enable a much more efficient data collection workflow with full telescope and guide camera control, and the possibility of connecting slider and flip mirror actuators using standard SharpCap functionality. It will also bring the development into a modern Python language, which can be run in SharpCap or the open source IronPython console, and should be easy to maintain and distribute.

## SharpCap-SSP
Working prototype of SSP data collection software using SharpCap. Does data collection and data export closely following SSPDataq 

https://github.com/labstercam/pep-ssp-tools/tree/main/SharpCap-SSP

<img width="1087" height="337" alt="image" src="https://github.com/user-attachments/assets/2c65aa47-65c9-4127-acf0-3284eee6c040" />

## Optec SSPDataq 3 and 4
The legacy software from Optec.  https://www.optecinc.com/downloads/legacy/sspdataq/ Uses LibertyBasic

## ssp4-control-software
Open-source control software suite for Optec's SSP-4 photometer (NIR J/H-band) distributed under the GPLv3 license.  C# code written by Brian
Kloppenborg. No longer maintained https://github.com/bkloppenborg/ssp4-control-software
