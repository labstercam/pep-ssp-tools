SSPCARD 

***IBM PC INTERFACE CARD*** 

**TECHNICAL MANUAL FOR** 

**THEORY OF OPERATION AND OPERATING PROCEDURES** 

**![][image1]*OPTEC, Inc.*** 

**OPTICAL AND ELECTRONIC PRODUCTS 199 Smith St**. **Lowell, MI 49331** 

**U.S.A.** 

**info@optecinc.com (616) 897-9351 http://www.optecinc.com (616) 897-8229 FAX**  
**TABLE OFCONTENTS** 

Revision 4 \- November 1997 

***Section Page*** 1.0 **INTRODUCTION** 1 2.0 **SYSTEM OVERVIEW** 2 

3.0 **SSPCARD INSTALLATION** 4 

3.1 Precautions and Warnings 4 3.2 Systems Check 4 3.3 Installing the SSPCARD 5 

4.0 **PROGRAMMING THE SSPCARD** 7 

4.1 Application Software 7 4.2 I/O Ports 9 4.3 Initialization 11 4.4 Sample Subroutines 12 

5.0 **CCDFILTR.EXE** 14 

5.1 Description 14 5.2 Setup and Use 14 5.3 Compatibility 16 

6.0 **SSPCARD LAYOUT AND CIRCUIT DIAGRAM** 17 7.0 **SPECIFICATIONS** 19

i   
**LIST OF FIGURES** 

***Figure Page*** 2-1 SSPCARD Block Diagram 3 6-1 SSPCARD Circuit Board Layout 17 6-2 SSPCARD Circuit Diagram 18 

**LIST OF TABLES** 

***Table Page*** 3-1 Base Address Switch Settings 5 3-2 Stock Number and Description of SSPCARD Cables 5 3-3 Pin Number and Function for the 15-pin D-connector 6 4-1 SSPCARD I/O Ports 9 4-2 4-bit Control Port for Baseaddress \+ 0 10 4-3 Output Port for Baseaddress \+ 1 10 4-4 Input Port for Baseaddress \+ 2 10 4-5 SSPCARD Initialization Sequence 11

ii   
**SECTION 1.0** 

**INTRODUCTION** 

As an important part of the SSP photometric system, the SSPCARD provides an interface between the photometer and the IBM 80x86,(and compatible) line of computers. This manual provides the basic information necessary to install and use the SSPCARD as well as user instructions for the supplied software. Programming examples and a complete description of the operation of the card are provided to give the user/programmer sufficient information to write his/her own applications if need be. 

Before installing the SSPCARD, the user is advised to read and understand Section 3.0 of this Technical Manual.

1   
**SECTION 2.0** 

**SYSTEM OVERVIEW** 

The following functions are supported when using the SSPCARD with an SSP-3 or SSP-5 photometer: 

1\. Read count data from the photometer. Integration times from 0.001 to 32.78 seconds are available. 

2\. Position the filter rack for photometers equipped with the automatic option (SSP-3A or SSP 5A models). 

3\. Supply operating power for SSP-3A and SSP-5A models. 

4\. Operate the stepper motor functions for selecting filters with the automatic PFE-1A photometric front-end. 

Count data is collected via a 16-bit binary counter which is one channel of the 8254-2 programmable timer. Counts up to 65,536 can be obtained before overflow. Refer to the SSPCARD Block Diagram, Figure 2-1. 

The filter slider's stepper motor is driven by the SAA1027 driver IC. Each filter position requires 33 full steps which normally takes 0.50 seconds to accomplish. 

The computer provides all the power necessary to operate the photometer and the stepper motor through a 15-pin female D-connector. An on board 0.5 amp fast acting fuse protects the computer bus from accidental shorts within the cable or photometer. 

The base address of the SSPCARD is selected with the six position dip-switch. A range of port addresses from 200 Hex to 3F8 Hex are available. Section 3.2 explains how to select the base address. 

The SSPCARD also provides access to the system's hardware interrupts. The interrupt level desired is jumper selectable. 

An on board crystal controlled programmable oscillator circuit allows accurate integration times in the range from 0.001 to 32.780 seconds to be selected with the default initialization. Integration time is selected in increments of 0.001 seconds. Longer integration times are possible with simple program changes.

2   

Three output and three input digital ports are independently programmable. Normally, one of the output ports (output bit \#1 of port base address \+ 1\) is connected to the stepper motor controller in order to set the phase of the stepper to a known state. Use of the I/O ports is for future enhancements of the SSP-3 and SSP-5 photometers.

3   
**SECTION 3.0** 

**SSPCARD INSTALLATION** 

**3.1 PRECAUTIONS AND WARNINGS** 

The user is fully responsible for the proper installation of the SSPCARD. Care must be taken then selecting the base I/O port address with the 6-position dip switch. Incorrect setting of this switch MAY CAUSE DAMAGE TO THE COMPUTER SYSTEM. 

Read and understand all of Sections 3.0 and 4.0 before installing the SSPCARD. Optec, Inc. cannot be held responsible for damage caused by an improperly installed card. 

**3.2 SYSTEM CHECKLIST** 

Determine what I/O port addresses are available within your computer. Your computer technical reference manual should summarize the ports used by the system. If an additional option cards are installed, consult the manufacturer's technical specifications to determine what additional ports (if any) are being used. The SSPCARD requires eight consecutive I/O ports (base address through base address \+ 7). The user must be certain that the base address selected and the next 7 address locations are not used by any other option card. The factory setting is 300 Hex through 307 Hex which is normally reserved for prototype cards in the standard IBM I/O port map. 

If an I/O port address is selected other than the factory default setting, use Table 3-1 to set the 6- position dip switch to the proper base address. The sum of the switch settings is added to 200 Hex (512 Decimal) to form the base address. For Example: If switch positions 3 and 5 are "open", and positions 1, 2, 4, and 6 are "closed" or "on", the base address would be 2A0 Hex (200 Hex \+ 80 Hex \+ 20 Hex). Only switch position 6 should "open" for the factory default setting making the base address equal to 300 Hex (200 Hex \+ 100 Hex). Typically, the base address would be set within the range of 300 Hex to 317 Hex (768 Decimal to 791 Decimal) which are available for prototype and option cards. 

The interrupt option is disabled. The default position of the interrupt jumper is the "X" position. 

Jumper JP2 normally has pins 1 and 2 connected which allows the stepper motor controller to be reset by output port bit D1. If pins 2 and 3 are connected, this output is connected to the pin 12 of the 15-pin D-connector for external use. 

The maximum current consumption of the card and photometer is about 250 ma of 12 V power and about 100 ma of 5 V power. This current drain should not tax the computer power supply unless it is already nearly overloaded.

4   
A stand alone computer system running DOS 3.3 or higher and comprising of a hard/floppy disk, VGA/EGA/CGA card, modem, COM1 \- COM4 serial ports, LPT1-LPT2 parallel ports and a bus mouse should provide no conflict with the SSPCARD using the factory settings. However, network cards, data acquisition cards and other special option cards could cause a conflict. 

| Position  | Value added if “open”  |  | Default |
| :---: | :---: | :---- | :---: |
| 1 |  8 H |  8  | on |
| 2 |  10 H |  16  | on |
| 3 |  20 H |  32  | on |
| 4 |  40 H |  64  | on |
| 5 |  80 H |  128  | on |
| 6  | 100 H |  256  | open |

*Table 3-1. Base Address Switch Settings.* 

**3.3 INSTALLING THE SSPCARD** 

To install the SSPCARD in your computer, first disconnect all power to the computer and select an 8-bit or 16-bit slot. Remove the back plate cover bracket which normally covers all unused slot positions. Carefully insert the card into the edge connector and push down. Make sure the card is fully seated in the edge connector and not wedged. Secure the card to the back plate with the small screw that was removed with the blank cover bracket. 

Attach the control cable to the 15-pin D-connector and connect the other end to the photometer. There are two ready made cables supplied by Optec for connecting the SSPCARD to the photometer. The descriptions and stock numbers of cables for the SSPCARD are given in Table 3-2. 

| Stock No.  | Description |
| :---: | ----- |
| \#17151  | 9-ft. \- 2-conductor cable for SSP-3 and SSP-5 photometers. This cable is used to acquire the pulse count only. |
| \#17152  | 9-ft. \- 9-conductor cable for Model PFE-1A front end for CCD cameras. This cable is used to operate the motorized. |
| \#17153  | 9-ft. \- 15-conductor cable for SSP-3A and SSP-5A photometers. This cable is used to operate the motorized 6 and 10 position filter rack and control the high voltage supply of the SSP-5A. |
| \#17155  | Custom cable \- extra length of any type priced per foot. |

*Table 3-2. Stock Number and Description of SSPCARD Cables.*

5   
Custom cables of any length can made to order. Consult the current price list for additional charges. Refer to stock number 17155\. 

Refer to Table 3-3 for a complete description of the pin functions of the 15-pin D-connector used on the SSPCARD and the SSP-5A and SSP-3A photometers. The 9-pin connector used on the PFE-A and the 2-pin connector used on the SSP-3 and SSP-5 are a subset of the 15-pin connector and are also indicated in Table 3-3. 

An onboard 500 mA fuse type GMA protects the photometer and computer from shorts on the 12 VDC line. If the user notices this fuse is blown, replace with identical fuse type and inspect the cable for shorts between the 12 VDC line and ground. If this fuse continues to blow, contact Optec for service. 

| Function  | 15-pin  D-connector  | 9-pin  circular  | 2-pin  phono |
| ----- | :---: | ----- | ----- |
| \+12 Volts to stepper motor  | 1  | 1 |  |
| Pin 11 on SAA1027 driver  | 2  | 3 |  |
| Pin 9 on SAA1027 driver  | 3  | 7 |  |
| Pin 8 on SAA1027 driver  | 4  | 2 |  |
| Signal Ground  | 5  | 5  | shell |
| \+12 Volts to photometer  | 6  | 6 |  |
| Pin 6 on SAA1027 driver  | 7  | 4 |  |
| Power return for photometer  | 8  | 8 |  |
| Pulse count from photometer  | 9  | 9  | center |
| Input D4  | 10 |  |  |
| Output D2  | 11 |  |  |
| Output D1 (see Note 1\)  | 12 |  |  |
| Output D0  | 13 |  |  |
| Input D1  | 14 |  |  |
| Input D0  | 15 |  |  |

*Table 3-3. Pin Number and Function for the 15-pin D-connector.* 

Note 1: Output D1 connected to pin 12 only if jumper JP2 is in the 2-3 position.

6   
**SECTION 4.0** 

**PROGRAMMING THE SSPCARD** 

**4.1 APPLICATION SOFTWARE** 

The following application and utility programs are available on the distribution disks supplied with each SSPCARD. 

README. Latest information and corrections for files on the distribution disks. Please read this file first. 

SSPTEST.BAS Qbasic source program that demonstrates the operation of the SSPCARD and supplies the user with various subroutine examples for incorporation into the user's program. Allows testing of all features of the SSPCARD with a photometer to verify proper function of the card and photometer. While not intended for data acquisition, the program will allow the user to acquire count data and control filter position for simple photometric measurements. Data logging features are not available. 

SSPTEST.EXE Same as SSPTEST.BAS except compiled to run without an interpreter. 

BASECHK.EXE Utility program to examine selected I/O ports for the SSPCARD to see if they are available for use. If FF Hex values are reported for the 8 I/O ports, then the area is probably free and available for SSPCARD use. 

CCDFILTR.EXE Memory resident (TSR) program that allows the user to select a filter when using the SSPCARD with PFE-1A front end, SSP-3A or SSP-5A automatic photometers. This program is especially useful with the PFE-1A front end for CCD cameras since it will allow the selection of filters while the CCD camera image acquisition program is running. 

SETUP.EXE Program to setup SSPCARD.CFG file for running CCDFILT.EXE. Allows the user to select, BaseAddress, filter designations and step rate to customize the program for the users computer and photometer setup. 

SSPCARD.CFG Binary configuration file for CCDFILTR.EXE

7   
The following application programs to operate the SSPCARD are available as options. CCDFILTR.EXE Memory resident control program fully described in Section 5.0 

DTAK.EXE Part of the extensive RPHOT photometric data acquisition and reduction package. DTAK fully operates the SSP-3A and SSP-5A photometers and acquires count data. Data is logged in files for later reduction with other programs in the application package. Consult RPHOT product literature and manual for a full description., 

SSPDATAQ.EXE Data acquisition software capable of controlling SSP photometers and producing RPHOT readable data files. Visit the Optec FTP web server at ftp://ftp.optecinc.com for the latest version. 

CCDRT.EXE Part of the Henden, Kaitchuck and Truax CCD photometry program that controls both the Lynxx PC CCD camera and the auto version of the PFE 1 photometric front end with 6-position filter rack.

8   
**4.2 I/O PORTS** 

The SSPCARD uses eight I/O ports starting at the base address (default of 300hex). These ports and the specific bits for selected ports are outlined in Tables 4-1 through 4-4. 

| Address  | I/O  | Description |
| ----- | ----- | ----- |
| Base \+ 0  | O  | 4-bit Control Port. This port is used to index the stepper motor, set the rotation direction of the stepper, initiate the count cycle and enable the SSPCARD hardware stepper, initiate the count cycle and enable the SSPCARD hardware interrupt. See Table 4-2 for a more complete description of this port. |
| Base \+ 1  | O  | 3-bit Output Port. See Table 4-3 for a description of this port. |
| Base \+ 2  | I  | 3-bit Input Port. See Table 4-4 for a description of this port. |
| Base \+ 3  |  | Not Used |
| Base \+ 4  | I/O  | Timer 0 Counter and Status Port \- Used to read or preset timer 0’s counter. The status of timer 0 can also be read. Timer 0 is used to generate a 1 KHz square wave which is then used as an input to Timer 1\. |
| Base \+ 5  | I/O  | Timer 1 Counter and Status Port. Used to read or preset timer 1's counter. The status of timer 1 can also be read. Timer 1 is used as a digital one-shot. The duration of output pulse which is the integration time is N times 0.001 sec. N is a number between 1 and 32768\. |
| Base \+ 6  | I/O  | Timer 2 Counter and Status Port. Used to read or preset timer 2's counter. The status of timer 2 can also be read. Timer 2 is where the count from the photometer is read. |
| Base \+ 7  | O  | Timer Control Word Port. Used to program and latch status information for Timers 0, 1 and 2\. See Table 4-5 for a more complete description of this port. |

*Table 4-1. SSPCARD I/O Ports*

9 

| Bit \#  | Description |
| ----- | ----- |
| 0  | Stepper Motor Index. To strobe this bit will cause the stepper motor to index one complete step. At computer power up, this bit is reset to 0\. |
| 1  | Stepper Motor Rotation Direction. 0 \= CCW 1 \= CW. At computer power up, this bit is reset to 0\. |
| 2  | Timer 1 Gate Input. To strobe this bit will trigger timer one which is programmed to operate as a digital one-shot at initialization. At power up this bit is reset to 0\. |
| 3  | Interrupt Enable. Setting this bit to 1 enables the jumper selectable hardware interrupt. At computer power up, this bit is reset to 0\. |

*Table 4-2. 4-bit Control Port for Baseaddress \+ 0\.* 

| Bit \#  | Description |
| :---: | ----- |
| 0  | Connected to pin 13 of the 15-pin output D-connector. (future use) |
| 1  | With a jumper in the 1-2 position for JP2, this line is connected to the reset pin of the SAA1027 stepper motor controller. With a jumper in the 2-3 position for JP2, this line is connected to pin 12 of the 15-pin output D-connector. |
| 2  | Connected to pin 11 of the 15-pin output D-connector. (future use) |

*Table 4-3. Output Port for Baseaddress \+ 1\.* 

| Bit \#  | Description |
| :---: | ----- |
| 0  | Connected to pin 15 of the 15-pin output D-connector. (future use) |
| 1  | Connected to pin 14 of the 15-pin output D-connector. (future use) |
| 4  | Connected to pin 10 of the 15-pin output D-connector. (future use) |

*Table 4-4. Input Port for Base address \+ 2\.*

10   
**4.3 INITIALIZATION** 

Before the SSPCARD can be used, it must be initialized. This consists of the six step procedure summarized in Table 4-5. 

| Step  | Description |
| :---: | ----- |
| 1  | Program Timer 0 to operate as a square wave generator. This is accomplished by writing 54 to the Timer Control Word Port at base address \+ 7\. See note 1\. |
| 2  | Program Timer 1 to operate as a digital one shot. This is done by writing 114 to the Timer Control Word Port at base address 7\. See note 1\. |
| 3  | Program Timer 2 to operate as an event counter. This is done by writing 176 to the Timer Control Word Port at base address \+ 7\. See note 1\. |
| 4  | Preset Timer 0 to generate a 1 KHz square wave. This is accomplished by writing 2 to base address \+ 4\. |
| 5  | Preset Timer 1 to generate a 1 second pulse. This is accomplished by writing 1000 to base address \+ 5\. Other pulse durations (integration times) could also be selected. |
| 6  | Enable stepper motor controller. This is done by writing 2 to the Output Port at base address \+ 1\. Jumper JP2 should have pins 1 and 2 connected. |

*Table 4-5. SSPCARD Initialization Sequence* 

NOTE 1: The value used to program the specified timer channel was obtained from the INTEL Microsystems Components Handbook, Vol. II. All 

counters are programmed for 6-bit binary operation. 

*.*

11   
**4.4 SAMPLE SUBROUTINES** 

The following is a listing from the SSPCARD.BAS program along with comments that can be used in the users own program. The examples are written in QuickBasic compatible code. 

SSPINITIALIZE: Initialize the SSPCARD 

' Timer 0 to generate a square wave   
OUT BASEADDRESS% \+ 7, 54 

' Timer 1 to operate as a digital one shot   
OUT BASEADDRESS% \+ 7, 114 

' Timer 2 to operate as an event counter   
OUT BASEADDRESS% \+ 7, 176 

' Write divide by 2 to Timer 0 to generate 1 KHz square wave, LSB and then MSB. OUT BASEADDRESS% \+ 4, 2 

OUT BASEADDRESS% \+ 4, 0 

' Write 1000 to Timer 1 to generate a 1 second pulse, LSB and then MSB OUT BASEADDRESS% \+ 5, 1000 MOD 256 

OUT BASEADDRESS% \+ 5, 1000 \\ 256 

' Set output port bit \#0 to 0 bit \#1 to 1 and bit \#2 to 0   
OUT BASEADDRESS% \+ 1, 2 

RETURN 

SSPINTEGRATION: 'Counter integration period set 

' Change period in seconds to an integer times 1000   
ACTPER% \= CINT(PERIOD \* 1000\) 

' Write integration time to Timer 1, LSB and then MSB   
OUT BASEADDRESS% \+ 5, ACTPER% MOD 256   
OUT BASEADDRESS% \+ 5, ACTPER% \\ 256 

RETURN 

SSPCOUNT: 'Read photometer 

' Clear Timer 2 counter   
OUT BASEADDRESS% \+ 6, 255   
OUT BASEADDRESS% \+ 6, 255 

' Strobe bit 2 of 4-bit control port to initiate counting   
OUT BASEADDRESS%, 4   
OUT BASEADDRESS%, 0 

' Delay polling of Timer 1 status long enough for Timer 1 output to go low ' If 0 counts are obtained, increase number of loops 

FOR I \= 1 TO 5   
J \= I \+ 1   
NEXT I 

' Poll Timer 1 status until bit 7 is 1 indicating that the count is disabled DO 

OUT BASEADDRESS% \+ 7, 228   
LOOP UNTIL (INP(BASEADDRESS% \+ 5\) AND 128\) \= 128 

' Check if any pulses were received thus loading Timer 2's counter with a valid count OUT BASEADDRESS% \+ 7, 232 

IF (INP(BASEADDRESS% \+ 6\) AND 64\) \<\> 0 THEN   
FREQUENCY\# \= 0 'Count \= 0, return to program if no pulses received

12   
RETURN   
END IF   
' If the counter's contents is valid, read it in   
FREQUENCY\# \= INP(BASEADDRESS% \+ 6\) \+ INP(BASEADDRESS% \+ 6\) \* 256\# FREQUENCY\# \= 65536\# \- FREQUENCY\# 

RETURN 

SSPFILTER: 'Index filter rack 

' If direction variable is not a 1 or a 0, return to program   
IF (DIR% \<\> 1\) AND (DIR% \<\> 0\) THEN   
RETURN   
END IF   
' Set direction   
OUT BASEADDRESS%, DIR% \* 2 

' Move to filter position specified by integer variable ICNT%   
FOR I \= 1 TO ICNT% 

' Send 33 pulses to the stepper motor controller trigger input   
FOR J \= 1 TO 33 

' Delay loop, adjust the value of FILTERDELAY% so that each filter position changes ' takes 0.5 seconds. 

' Start with a value of 50 for an AT class computer.   
FOR K \= 1 TO FILTERDELAY%   
NEXT K   
'Move motor one step in direction given by DIR%   
OUT BASEADDRESS%, (DIR% \* 2 \+ 1\)   
OUT BASEADDRESS%, (DIR% \* 2\)   
NEXT J   
NEXT I   
RETURN 

SSPHOME: 'Reset motor controller & home filter rack   
' Reset stepper motor controller   
OUT BASEADDRESS% \+ 1, 0   
OUT BASEADDRESS% \+ 1, 2   
' Move filter rack enough steps to put slider against cover wall and stall motor FOR I \= 1 TO 300 

' Delay loop, adjust the value of FILTERDELAY% so that each filter position changes ' takes 0.5 seconds. 

' Start with a value of 50 for an AT class computer.   
FOR K \= 1 TO FILTERDELAY%   
NEXT K 

' Move stepper motor one step in direction 1   
OUT BASEADDRESS%, 3   
OUT BASEADDRESS%, 2   
NEXT I   
RETURN

13   
**SECTION 5.0** 

**CCDFILTR.EXE** 

Documentation for the CCDFILTR.EXE memory resident driver for selecting filters using the SSPCARD and a 6- or 10-position filter sliders with the PFE-1A or the automatic SSP models. 

**5.1 DESCRIPTION** 

CCDFILTR.EXE is an improved memory resident program designed primarily for use with the automatic Model PFE-1A photometric front-end for astronomical CCD cameras. CCDFILTR.EXE will work with most IBM AT/386 or 486 compatible computers when using the SSPCARD IBM PC interface card. With CCDFILTR, the filter slider is initialized when loading the program. The user can select any filter by simply using the CTRL-LEFT SHIFT key combination with any user defined key. For example, to select the Johnson Visual filter the user need only press the CTRL-LEFT SHIFT-V keys simultaneously. The filter is positioned and an integration (exposure) may be started. Positional accuracy is maintained with any subsequent selection of the V filter. 

**5.2 SETUP AND USE** 

CCDFILTR.EXE should be loaded prior to running the data acquisition program supplied with the CCD camera. A number of shareware programs are readily available for tagging memory resident programs for easy removal from memory. INSTALL & REMOVE and MARK, FMARK & RELEASE are two such program bundles which are available from most computer bulletin boards (BBS's). 

Before loading CCDFILTR for the first time, the user should run the SETUP.EXE program. SETUP will prompt the user for the SSPCARD settings, whether a 6- or 10- position filter slider is being used, and the desired "hot-key" combinations for the filters to be used. The information provided will be written to the binary file SSPCARD.CFG. A complete description of the prompts and typical responses is given below: 

A:\\\>SETUP 

CCDFILTR configuration program V2.0   
Enter the base address of the SSP card \-\> 

The default setting for the SSPCARD as shipped from Optec and outlined in the SSPCARD Technical Manual is 768\. 

Enter the step delay in milliseconds (see CCDFILTR.DOC) \-\>

14   
A delay is required between the steps of the of the stepper motor to ensure proper performance. Version 2.0 of CCDFILTR.EXE uses an internal delay loop rather than requiring the user to determine computer bus speeds and enter the divide-by jumper position on the SSPCARD. The default setting for the SSPCARD is 20 milliseconds. However, the user is encouraged to try other delays for optimal performance. With some "turbo" PC computers, CCDFILTR has been shown to exhibit occasional timing problems which manifest themselves as missed steps. If this problem is seen, try using different delay settings. Contact Optec if this problem persists. 

Enter the number of filters in your SSP (6 or 10\) \-\> 

Enter 6 or 10 depending on the size of your filter slider. The default is 6\. 

Press key for filter 1 \-\> 

Press the key you wish to represent your first filter. This is the left-most filter for the PFE-1A (right-most for SSP-3A/SSP5A photometers) when looking from behind the instrument. The default is B. 

Press key for filter... 

Continue selecting keys to represent the remaining filters in your filter slider. The defaults here are V, R, I, C, d. (C represents the Clear filter, d represents the dark or opaque filter.) 

After running the SETUP program, the SSPCARD.CFG file will be updated. SETUP need not be run again unless the user changes the SSPCARD or filter order. Of course, SETUP can be run again to change the desired "hot-key" combinations. 

Load CCDFILTR.EXE into memory by simply typing CCDFILTR at the DOS command line. Be sure the PFE or SSP is properly connected to the SSPCARD. The following lines will scroll down the screen and the filter slider should initialize. 

CCDFILTR \- A memory-resident driver for selecting filters using the SSPCARD and Automatic Models of the SSP and PFE series photometers. 

SSPCARD Base Address: 768   
SSPCARD Step Delay: 20 

Filter \#1 Ctrl-Shift B   
Filter \#2 Ctrl-Shift V   
Filter \#3 Ctrl-Shift R   
Filter \#4 Ctrl-Shift I   
Filter \#5 Ctrl-Shift C   
Filter \#6 Ctrl-Shift d 

Version 2.0, (c) 1994 \- OPTEC, Inc.   
SSPCARD Filter Slider Driver Installed

15   
**5.3 COMPATIBILITY** 

CCDFILTR.EXE has been tested on a number of computer types and the following CCD packages: 

PCLYNXX.EXE Lynxx PC CCD software   
CCD.EXE SBIG ST-4 software   
ST6OPS.EXE SBIG ST-6 software   
AIP.EXE AstroIP software 

**Note**: Some timing problems have been noticed with CCDFILTR when used on XT computers. Optec does not recommend using CCDFILTR with computers with having 8088 or 8086 processors. Most CCD manufacturers recommend an 80286 computer as the minimum configuration for running the CCD acquisition and control software. 

Contact Optec with any compatibility problems, comments, or suggestions.

16   
**SECTION 6.0** 

**SSPCARD LAYOUT AND CIRCUIT DIAGRAM** 

The layout for the SSPCARD is shown in Figure 6-1 below. A circuit diagram is provided in Figure 6-2.

 
**SECTION 7.0** 

**SPECIFICATIONS** 

**INTEGRATION** 

Range: 0.001 to 32.768 seconds Precision of Integration Time: ±5ppm at 25 °C Temperature Coefficient: \+10/-120 ppm 

**COUNTER** 

Range: 0 to 65536 Maximum Count Rate: 10 MHz 

**STEPPER CONTROLLER** 

Maximum Output Current: 800 ma 

Maximum Current per Phase: 375 ma 

Type: Unipolar 

Voltage: 12 VDC 

**OUTPUT PORTS** 

Number: 3 

Output High Voltage: 3.5 VDC typ. Output Low Voltage: 0.25 VDC typ. Output High Current: \-0.4 ma max. Output Low Current: 8.0 ma max. 

**INPUT PORTS** 

Number: 3 

Input High Voltage: 2.0 VDC min. Input Low Voltage: 0.8 VDC max. Input High Current: 20 µA Max. Input Low Current: \-0.2 ma Max. 

**COMPUTER INTERFACE** 

Base Address Range: 200H to 3F8H Bus: ISA \- single XT slot Interrupts: 2, 3, 4, 5, 6, 7 and none

19 
