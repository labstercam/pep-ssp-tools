# SSP5 Pulse Output Software Handling Analysis

## Overview
This document explains exactly how the SSP5 photometer's pulse output is handled by the SSPDataq3 software. The SSP5 generates pulse outputs that represent photon detections or integrated photocurrent, and the software processes these pulses through a multi-stage pipeline.

## Complete Pulse Handling Pipeline

### Stage 1: Pulse Generation (SSP5 Hardware)
```
Light → Detector → Pulse Processing → Count Buffer → Serial Output
       (PMT/APD)   (Discrimination,   (16-bit)      (ASCII/Binary)
                     Shaping,         (0-65535)
                     Counting)
```

### Stage 2: Software Command Sequence

#### **1. Send Integration Command**
```vb
' SSPDataq3 LibertyBasic Code
print #commHandle, "SCnnnn"
```
Where "nnnn" tells the SSP5 to start integrating/counting pulses for the specified time period.

#### **2. Integration Period**
The SSP5 internally:
1. **Resets its counter** to 0
2. **Starts timing** using crystal oscillator
3. **Counts pulses** from the detector
4. **Stores count** in internal 16-bit register

#### **3. Data Retrieval**
```vb
' Wait exact integration time + overhead
SELECT CASE Integ
    CASE 1000: CALL Pause 1150      ' 1s + 15% overhead
    CASE 5000: FOR i = 1 TO 5: CALL Pause 1030: NEXT  ' 5s + 3% overhead
    CASE 10000: FOR i = 1 TO 10: CALL Pause 1015: NEXT ' 10s + 1.5% overhead
END SELECT

' Read response from SSP5
response$ = input$(#commHandle, lof(#commHandle))
```

### Stage 3: Pulse Data Format

#### **Response Format:** `C=XXXXX\r\n`
- `C` = "Count" identifier
- `=` = Separator
- `XXXXX` = 5-digit ASCII count (0-65535)
- `\r\n` = Carriage return + Line feed (ASCII 13 + 10)

#### **Example Responses:**
```
C=12345\r\n     ' 12,345 counts
C=00015\r\n     ' 15 counts (very faint)
C=65535\r\n     ' Maximum count (saturation)
```

### Stage 4: Data Parsing and Validation

#### **Extraction Logic**
```vb
' Find equals sign
equalsPos = INSTR(response$, "=")

IF equalsPos > 0 THEN
    ' Extract 5 characters after "="
    count$ = MID$(response$, equalsPos + 1, 5)
    
    ' Validate first character not null (ASCII 0)
    IF ASC(MID$(count$, 1, 1)) <> 0 THEN
        ' Count is valid
        Counts$(I) = count$
    ELSE
        ' Communication error - retry
        GOTO [RetryCount]
    END IF
ELSE
    ' Format error - no "=" found
    GOTO [RetryCount]
END IF
```

#### **Error Detection**
1. **Null character check**: First character ASCII 0 = communication error
2. **Format validation**: Must contain "C="
3. **Length validation**: Must be exactly 5 digits after "="
4. **Character validation**: Must be digits '0'-'9'

### Stage 5: Data Storage and Processing

#### **In-Memory Storage**
```vb
DIM Counts$(4000)        ' Store raw count strings
DIM DataArray$(4000)     ' Store formatted display lines
DIM SavedData$(4000)     ' Store for file output
```

#### **Formatting for Display**
```vb
' Create display line
line$ = UTdateCorrected$ + " " + UTtimeCorrected$ + _
        " " + TempCatalog$ + "    " + LEFT$(object$ + "            ", 12) + _
        "   " + filter$ + "  " + _
        RIGHT$(Counts$(1), 5) + "  " + RIGHT$(Counts$(2), 5) + "  " + _
        RIGHT$(Counts$(3), 5) + "  " + RIGHT$(Counts$(4), 5) + _
        "  " + Integ$ + " " + Gain$
```

**Result:** `MM-DD-YYYY HH:MM:SS C    OBJECTNAME     F  XXXXX  XXXXX  XXXXX  XXXXX  II GG`

### Stage 6: File Output

#### **.RAW File Format**
```
FILENAME=SAMPLE.RAW       RAW OUTPUT DATA FROM SSP DATA ACQUISITION PROGRAM
UT DATE= MM/DD/YYYY   TELESCOPE= [name]      OBSERVER= [name]
CONDITIONS= [description]
MO-DY-YEAR    UT    CAT  OBJECT         F  ----------COUNTS---------- INT SCLE COMMENTS
MM-DD-YYYY HH:MM:SS C    OBJECTNAME     F  XXXXX  XXXXX  XXXXX  XXXXX  II SS  NOTES
```

#### **File Writing Logic**
```vb
' Write header
PRINT #DataFile, " FILENAME=" + UPPER$(DataFileName$) + _
                 "       RAW OUTPUT DATA FROM SSP DATA ACQUISITION PROGRAM"
PRINT #DataFile, " UT DATE= " + UTdateHeader$ + _
                 "   TELESCOPE= " + UPPER$(Telescope$) + _
                 "      OBSERVER= " + UPPER$(Observer$)
PRINT #DataFile, " CONDITIONS= " + UPPER$(Conditions$)
PRINT #DataFile, " MO-DY-YEAR    UT    CAT  OBJECT         F  ----------COUNTS---------- INT SCLE COMMENTS"

' Write data lines
FOR i = 1 TO DataCounterLast
    PRINT #DataFile, " " + SavedData$(i)   ' Leading space required
NEXT i
```

## Pulse Counting vs. Integration Modes

### **Digital Pulse Counting** (Likely PMT/APD)
```
For each detected photon:
1. Detector generates electrical pulse
2. Discriminator validates pulse > threshold
3. Counter increments by 1
4. Result: Pulse count = Number of photons
```

**Software sees:** Integer count value representing photon arrivals

### **Analog Integration** (Photodiodes)
```
Continuous process:
1. Photocurrent charges capacitor
2. Voltage ∝ total charge collected
3. ADC converts to digital value
4. Result: Integrated signal ∝ total light energy
```

**Software sees:** Scaled value representing integrated photocurrent

## Timing Precision Analysis

### **Integration Timing**
The SSP5 uses crystal-controlled timing:
- **Accuracy**: ±0.01% (100ppm crystal)
- **Resolution**: Likely 1ms steps
- **Stability**: Temperature compensated

### **Software Timing Overhead**
SSPDataq3 adds overhead to account for:
```
Total Overhead = Command Tx + SSP Processing + Response Tx + Software Processing
               ≈ 6ms + 1ms + 6ms + 2ms
               ≈ 15ms fixed + variable serial time
```

### **Mid-Point Timestamp Correction**
```vb
' Calculate mid-point of total integration
total_integration_sec = IntervalRecord * (Integ/1000)
mid_count_sec = INT(total_integration_sec / 2)

' Apply correction to recorded time
UTsec = UTsec + mid_count_sec

' Handle rollover (seconds, minutes, hours, days)
IF UTsec >= 60 THEN
    UTsec = UTsec - 60
    UTmin = UTmin + 1
    ' ... continue for minutes → hours → days
END IF
```

**Reasoning**: Timestamp should represent the midpoint of integration, not the start time.

## Gain and Scale Factors

### **Gain Control Implementation**
```vb
' Set gain on SSP5
SELECT CASE GainIndex
    CASE 1: command$ = "SGNNN3"   ' Gain 1
    CASE 2: command$ = "SGNNN2"   ' Gain 10
    CASE 3: command$ = "SGNNN1"   ' Gain 100
END SELECT

print #commHandle, command$
CALL WaitForAck
```

### **Scale Factor in Display**
The "SCLE" (Scale) field shows gain setting:
- ` 1` = Gain 1
- `10` = Gain 10
- `100` = Gain 100

## Error Handling and Recovery

### **Communication Errors**
```vb
[RetryCount]
IntervalRecord = IntervalRecord + 1   ' Increment retry counter
IF IntervalRecord > Interval THEN
    ' Maximum retries exceeded
    CommErrorFlag = 1
    EXIT SUB
ELSE
    ' Retry this count
    GOTO [StartCount]
END IF
```

### **Data Validation Checks**
1. **Format check**: Must match "C=XXXXX"
2. **Null check**: First digit ≠ ASCII 0
3. **Range check**: 0 ≤ count ≤ 65535
4. **Consistency check**: Multiple readings should be similar

## Fast/Very Fast Mode Differences

### **Fast Mode** (0.05-10.00s)
- **Command**: `SMXXXX` (XXXX = interval count)
- **Response**: Multiple values without delimiters
- **Buffer management**: Pre-calculated buffer size

### **Very Fast Mode** (0.02s, SSP-5 only)
- **Command**: `SNXXXX` (XXXX = interval count)
- **Response**: 2-byte binary values (0-65535)
- **Data format**: Reduced precision for speed

## Background Subtraction Implementation

### **Sky Measurement Protocol**
```vb
' Measure sky background
Object$ = "SKY"
CALL Get_Counts
sky_count = VAL(Counts$(1))   ' Convert string to number

' Measure target
Object$ = target_name$
CALL Get_Counts
target_count = VAL(Counts$(1))

' Calculate net count
net_count = target_count - sky_count
IF net_count < 0 THEN net_count = 0
```

### **Dark Current Measurement**
Typically done at start of session:
1. Cover detector or use shutter
2. Measure counts with no light
3. Subtract from all measurements

## Calibration Factors

### **Counts to Magnitude Conversion**
In Reduction module:
```vb
' Convert counts to instrumental magnitude
instrumental_mag = -2.5 * LOG10(net_count) + zero_point

' Apply extinction correction
extinction_correction = K * airmass

' Apply transformation coefficients
standard_mag = instrumental_mag + extinction_correction + _
               epsilon * (B_V_color) + other_terms
```

### **Zero Point Determination**
From calibration observations of standard stars:
```
zero_point = standard_mag_known + 2.5 * LOG10(counts_measured) - _
             extinction_correction - transformation_terms
```

## Practical Examples

### **Example 1: Bright Star Measurement**
```
Settings: Filter=V, Gain=1, Integration=1s, Interval=3

Raw counts: C=54321, C=54298, C=54315
Sky counts: C=123, C=119, C=121
Net counts: 54200, 54177, 54192 (average: 54190)

Magnitude: V = -2.5 * log10(54190) + zero_point + corrections
```

### **Example 2: Faint Star Measurement**
```
Settings: Filter=V, Gain=100, Integration=10s, Interval=4

Raw counts: C=01543, C=01528, C=01551, C=01537
Sky counts: C=0098, C=0101, C=0095, C=0099
Net counts: 545, 527, 556, 538 (average: 542)

Magnitude: V = -2.5 * log10(542) + zero_point + corrections
```

## Software Architecture for Pulse Handling

### **Main Processing Loop** (Simplified)
```vb
SUB Get_Counts
    FOR i = 1 TO Interval
        [StartCount]
        ' Clear serial buffer
        junk$ = input$(#commHandle, lof(#commHandle))
        
        ' Send count command
        print #commHandle, "SCnnnn"
        
        ' Wait appropriate time
        SELECT CASE Integ
            CASE 1000: CALL Pause 1150
            CASE 5000: FOR j = 1 TO 5: CALL Pause 1030: NEXT
            CASE 10000: FOR j = 1 TO 10: CALL Pause 1015: NEXT
        END SELECT
        
        ' Read response
        response$ = input$(#commHandle, lof(#commHandle))
        
        ' Parse and validate
        equalsPos = INSTR(response$, "=")
        IF equalsPos = 0 OR ASC(MID$(response$, equalsPos+1, 1)) = 0 THEN
            ' Error - retry
            IntervalRecord = IntervalRecord + 1
            IF IntervalRecord <= Interval THEN GOTO [StartCount]
        END IF
        
        ' Store valid count
        Counts$(i) = MID$(response$, equalsPos+1, 5)
    NEXT i
END SUB
```

### **Data Flow Diagram**
```
SSP5 Pulse Output → Serial "C=XXXXX" → SSPDataq3 Parsing → Counts$ Array
       │                              │                    │
       ├→ 16-bit counter              ├→ Format validation ├→ Display formatting
       └→ Crystal timing              └→ Error checking    └→ File output
```

## Key Insights

### **1. Pulse Output is Pre-processed**
The SSP5 does significant processing before sending data:
- Pulse counting/integration
- Digital conversion
- ASCII formatting
- Buffer management

### **2. Software Focuses on Validation**
SSPDataq3's main roles:
- Verify data integrity
- Handle communication errors
- Apply timing corrections
- Format for display/storage

### **3. Timing is Critical**
- Integration timing controlled by SSP5 crystal
- Software adds fixed overhead
- Mid-point timestamp correction applied
- Synchronization maintained through acknowledgments

### **4. Error Handling is Robust**
- Multiple validation checks
- Automatic retry on errors
- User notification of problems
- Graceful degradation on failures

## Conclusion

The SSP5 photometer's pulse output represents a carefully engineered measurement system:

1. **Hardware**: Photon → pulse → count conversion with precise timing
2. **Communication**: ASCII-formatted data transmission with error checking
3. **Software**: Validation, formatting, storage, and error recovery
4. **Calibration**: Conversion to standardized astronomical magnitudes

The "C=XXXXX" format encapsulates years of photometer design experience, balancing simplicity with reliability for astronomical observations.