# First Order Extinction (FOE) and All Sky Calibration - Complete SSPDataq Analysis

## Executive Summary

**Purpose**: Document how SSPDataq implements first order extinction (FOE) and All Sky calibration observations and analysis to guide SharpCap-SSP implementation.

**Key Findings**: 
1. SSPDataq uses a **post-observation analysis workflow**
2. Observer manually selects extinction stars from FOE catalog
3. Data acquisition program (SSPDataq3) collects photometric observations
4. Separate analysis modules (Extinction2, AllSky2) perform least-squares regression
5. Coefficients (K', ZP) are saved to PPparms3.txt for future photometry

**Analysis Status**: 100% complete analysis of:
- **Extinction2,56.bas** (1469 lines) - First Order Extinction calculation
- **AllSky2,57.bas** (1366 lines) - All-sky calibration
- Complete mathematical verification against source code

**Recommendation for SharpCap-SSP**: Implement **intelligent target selection** with real-time airmass calculations and observability filtering to improve upon SSPDataq's manual workflow.

---

## 1. Overview of Extinction Methodology

### What is First Order Extinction?

First order extinction (K') represents the **linear atmospheric attenuation** of starlight as a function of airmass. The equation is:

```
m_inst = K' × X + m₀
```

Where:
- **m_inst** = instrumental magnitude = -2.5 × log₁₀(counts) = -1.0857 × ln(counts)
- **K'** = first order extinction coefficient (magnitudes per airmass)
- **X** = airmass (dimensionless, typically 1.0 to 3.0)
- **m₀** = instrumental magnitude at zero airmass (intercept)

### Filter Systems Supported

**Johnson/Cousins**: U, B, V, R, I filters → extinction coefficients KU, KB, KV, KR, KI

**Sloan Digital Sky Survey**: u', g', r', i', z' filters → extinction coefficients Ku, Kg, Kr, Ki, Kz

### Second Order Extinction

SSPDataq also supports **second order extinction** (K'') which accounts for color-dependent atmospheric effects:
- **Johnson/Cousins**: K''(b-v) for B-V color index (typically ~-0.05)
- **Sloan**: K''(g-r) for g'-r' color index

---

## 2. SSPDataq Extinction Star Catalog

### FOE Data Files

**Location**: 
- `FOE Data Version 2.txt` (Johnson/Cousins)
- `FOE Data Version 2 Sloan.txt` (Sloan filters)

### Star Catalog Format

```
StarName,Type,RAh,RAm,RAs,DECd,DECm,DECs,Vmag,B-V,U-B,V-R,V-I
```

**Example entries**:
```
BS477,B,1,40,35,40,34,38,4.94,-0.09,0.00,0.00,0.00
BS607,A,2,3,12,0,7,43,5.42,0.14,0.13,0.00,0.00
BS1389,A,4,25,29,17,55,40,4.29,0.04,0.08,0.00,0.00
```

### Star Characteristics

**Source**: Bright Star (BS) catalog and HD catalog stars
- **Magnitudes**: V ≈ 3.7 to 6.7 (bright stars suitable for SSP photometer)
- **Colors**: Mix of A-type (white, B-V ≈ 0.0) and B-type (blue-white, B-V < 0.0) stars
- **Distribution**: All-sky coverage across multiple RA ranges
- **Type field**: 'A' or 'B' classification (possibly spectral type indicator)

**Catalog Size**: ~22 stars (small, focused list of well-characterized standards)

---

## 3. Airmass Calculation

### Core Algorithm (from Extinction2,56.bas lines 1292-1306)

**Source**: Identical implementation in:
- `Extinction2,56.bas` (FOE module)
- `Transformation2,56.bas` (Transformation module)  
- `AllSky2,57.bas` (All-sky calibration)

```basic
[Find_Air_Mass]
    ' Compute hour angle in degrees
    HA = LMST - RA
    if HA < 0 then
        HA = HA + 360
    end if

    ' Convert to radians
    HAradians = HA * 3.1416/180
    DECradians = DEC * 3.1416/180
    LATradians = LAT * 3.1416/180

    ' Compute secant of zenith angle
    secZ = 1/(sin(LAT_rad) × sin(DEC_rad) + cos(LAT_rad) × cos(DEC_rad) × cos(HA_rad))
    
    ' Apply Hardie equation for atmospheric refraction correction
    AirMass = secZ - 0.0018167(secZ - 1) - 0.002875(secZ - 1)² - 0.0008083(secZ - 1)³
    AirMass = secZ - 0.0018167(secZ - 1) - 0.002875(secZ - 1)² - 0.0008083(secZ - 1)³
return
```

### Hardie Equation

The **Hardie (1962) equation** corrects the simple plane-parallel atmosphere approximation (airmass = sec(zenith distance)) for:
- Atmospheric curvature
- Refraction effects
- More accurate at low elevations (high airmass)

**Reference**: Hardie, R.H. 1962, "Photoelectric Reductions", in *Astronomical Techniques*, Chapter 8

### LMST Calculation (Local Mean Sidereal Time)

```basic
[Sidereal_Time]
    ' Mean Sidereal Time at Greenwich
    MST = 280.46061837 + 360.98564736629 × JD + 0.000387933 × JT² - JT³/38710000
    
    ' Convert to Local MST
    LMST = MST + LONGITUDE
    
    ' Normalize to 0-360 degrees
    while LMST > 360: LMST = LMST - 360
    while LMST < 0:   LMST = LMST + 360
return
```

Where:
- **JD** = Julian Date from J2000.0 epoch (days)
- **JT** = Julian Century from J2000.0 = JD / 36525
- **LONGITUDE** = observer longitude in degrees (positive East, negative West)

---

## 4. Observation Strategy

### Data Collection Workflow (from Sample_Extinction.raw)

**Typical sequence**:
1. **Sky background** measurement (SKYNEXT or SKY)
2. **Extinction star** observations through U, B, V, R filters (or u', g', r', i', z')
3. **Repeat** at different airmasses as star moves across sky
4. **Final sky background** measurement

**Example from Sample_Extinction.raw**:
```
02:04:59  SKYNEXT  U  00022 counts
02:05:37  SKYNEXT  B  00047 counts
02:06:17  SKYNEXT  V  00052 counts
02:06:51  SKYNEXT  R  00033 counts

02:08:24  BS458    U  00706 counts  [Star #1, observation set 1]
02:09:01  BS458    B  04382 counts
02:09:38  BS458    V  06785 counts
02:10:23  BS458    R  03533 counts

02:12:54  BS477    U  00755 counts  [Star #2, observation set 1]
02:13:30  BS477    B  03339 counts
02:14:08  BS477    V  03112 counts
02:14:44  BS477    R  01243 counts

02:21:24  SKY      U  00021 counts  [Sky check]
... [~14 minutes later, higher airmass]

02:26:19  BS458    U  00738 counts  [Star #1, observation set 2]
02:27:06  BS458    B  04475 counts
...
```

### Key Observation Parameters

- **Integration time**: 10 seconds (typical)
- **Scale factor**: 1× (no gain scaling)
- **Filters**: All filters (U, B, V, R or u', g', r', i', z') per star
- **Sky measurements**: Before/after star sequences to track sky background changes
- **Time spacing**: ~15-30 minutes between observation sets to achieve significant airmass change

### Optimal Airmass Range

**Target**: X = 1.0 to 2.5
- **X < 1.0**: Not physically achievable (star above zenith)
- **X = 1.0 to 1.5**: Low extinction, easier observations
- **X = 1.5 to 2.5**: Moderate extinction, good dynamic range
- **X > 2.5 to 3.0**: High extinction, increased noise and atmospheric dispersion

---

## 5. Extinction Analysis Module (Extinction2,56.bas)

### Analysis Workflow

#### Step 1: Load Raw Data File
- Read `.raw` file from SSPDataq3
- Parse observation timestamps, star names, filters, counts
- Detect filter system (Johnson/Cousins vs. Sloan)

#### Step 2: Select Comparison Star
- User selects one extinction star from list (e.g., "BS477")
- Program extracts star's RA/DEC from Star Data file

#### Step 3: Compute Airmass for Each Observation
For each observation timestamp:
1. Calculate Julian Date (JD) from UT time
2. Compute Local Mean Sidereal Time (LMST)
3. Calculate Hour Angle (HA = LMST - RA)
4. Compute airmass using Hardie equation

#### Step 4: Convert Counts to Instrumental Magnitudes

**Count normalization** (Extinction2,56.bas lines 942-963):
```basic
' Average up to 4 count readings
CountSum = Count1 + Count2 + Count3 + Count4
Divider = 4 - (number of zero counts)
AverageCount = CountSum / Divider

' Normalize to 10 seconds integration, scale factor 1×
CountFinal = int(AverageCount × (100 / (Integration × Scale)))
```

**Sky subtraction with temporal interpolation** (lines 998-1041):

For each star observation, find bracketing sky measurements:

```basic
' Search backwards for past sky
for I = RawIndex to 5 step -1
    if (StarName = "SKY" OR "SKYNEXT") AND (same filter) then
        SkyPastCount = CountFinal(I)
        PastTime = JD(I)
        exit
        
' Search forwards for future sky
for I = RawIndex to RawIndexMax
    if (StarName = "SKY" OR "SKYLAST") AND (same filter) then
        SkyFutureCount = CountFinal(I)
        FutureTime = JD(I)
        exit
```

**Linear interpolation:**
```basic
' If both past and future sky available:
SkyCurrentCount = SkyPastCount + 
                  ((SkyFutureCount - SkyPastCount) / (FutureTime - PastTime)) × 
                  (JD_observation - PastTime)

CountNet = CountFinal - SkyCurrentCount
```

**Cases handled:**
1. Both sky measurements available → interpolate
2. Only past sky → use past value
3. Only future sky → use future value
4. No sky measurements → error

**Convert to magnitude:**
```
m_inst = -1.0857 × ln(CountNet)
```

**Critical implementation detail**: Sky interpolation uses Julian Date (fractional days) for time, ensuring accurate time-weighting even for observations spanning twilight or changing conditions.

#### Step 5: Least-Squares Regression
For each filter, perform linear regression:
- **X-axis**: Airmass (1.0 to 2.5)
- **Y-axis**: Instrumental magnitude
- **Output**: Slope (K'), Intercept (m₀), Standard Error

**Algorithm** (from lines 1327-1384):
```basic
[Solve_Regression_Matrix]
    ' Linear least squares (Nielson algorithm)
    ' From Henden & Kaitchuck 1982, "Astronomical Photometry"
    
    a1 = N                          ' Number of points
    a2 = Σ X_i                      ' Sum of airmass values
    a3 = Σ X_i²                     ' Sum of airmass squared
    c1 = Σ m_i                      ' Sum of magnitudes
    c2 = Σ (m_i × X_i)              ' Sum of cross products
    
    det = 1 / (a1 × a3 - a2²)
    Intercept = -1 × (a2 × c2 - c1 × a3) × det
    Slope = (a1 × c2 - c1 × a2) × det
    
    ' Standard error
    std_error = sqrt( (1/(N-2)) × Σ(m_i - m_fit)² )
return
```

#### Step 6: Save Coefficients to PPparms3.txt
User can save computed K' values to configuration file for use in:
- Transformation analysis
- Variable star photometry
- All-sky photometry

### Graphical Output

**Plot features**:
- **X-axis**: Airmass (1.0 to 2.5)
- **Y-axis**: Instrumental magnitude
- **Data points**: Colored by filter (blue=b, green=v, red=r, etc.)
- **Best-fit line**: Linear regression through data
- **Annotations**: File name, star name, start/end JD, slope (K'), intercept, standard error

---

## 6. Configuration File (PPparms3.txt)

### Structure

```
Location        N42.9_W085.4      [Latitude/Longitude]
KU              0.000             [U-band extinction]
KB              0.466             [B-band extinction]
KV              0.252             [V-band extinction]
KR              0.115             [R-band extinction]
KI              0.000             [I-band extinction]
KKbv           -0.053             [Second order extinction for b-v]
Eps            -0.030             [Transformation: epsilon for V using B-V]
Psi             1.639             [Transformation: psi for U-B]
Mu              1.047             [Transformation: mu for B-V]
Tau             0.878             [Transformation: tau for V-R]
Eta             1.146             [Transformation: eta for V-I]
EpsR           -0.072             [Transformation: epsilon for V using V-R]
EpsilonFlag     1                 [1=use Eps, 0=use EpsR]
JDFlag          0                 [1=use JD, 0=use HJD]
OBSCODE         XXX               [AAVSO observer code]
MEDUSAOBSCODE   XXX               [MEDUSA observer code]
Ku              0.000             [Sloan u' extinction]
Kg              0.300             [Sloan g' extinction]
Kr              0.200             [Sloan r' extinction]
Ki              0.100             [Sloan i' extinction]
Kz              0.050             [Sloan z' extinction]
KKgr           -0.053             [Second order extinction for g-r]
SEps           -0.034             [Sloan transformation coefficients...]
... [additional transformation parameters]
```

### Typical Extinction Values

**Sea level, clear conditions**:
- **KU**: 0.4-0.6 mag/airmass (large extinction in UV)
- **KB**: 0.25-0.35 mag/airmass
- **KV**: 0.15-0.25 mag/airmass
- **KR**: 0.10-0.15 mag/airmass
- **KI**: 0.05-0.10 mag/airmass (minimal extinction in near-IR)

**Altitude, dry conditions**: Values typically 20-40% lower

---

## 7. Integration with SSPDataq3

### FOE Catalog Selection (SSPDataq3_3,21.bas)

**Script generation**:
- User selects "FOE" radio button in script builder
- Automatically loads FOE Data catalog
- Provides template with 5 extinction targets: "FOE 1", "FOE 2", "FOE 3", "FOE 4", "FOE 5"

**Observation sequence**:
1. User manually selects extinction stars from catalog
2. SSPDataq3 guides through filter sequence (U→B→V→R or u'→g'→r'→i'→z')
3. Sky background measured automatically (SKYNEXT/SKY)
4. Data saved to `.raw` file with timestamps

### Manual vs. Automated Workflow

**Current (SSPDataq)**: 
- Observer decides which stars to observe
- No real-time airmass guidance
- Post-observation analysis only

**Proposed (SharpCap-SSP)**:
- Real-time airmass calculation
- Filter catalog by current observability
- Suggest optimal targets based on airmass range
- Display altitude/azimuth for telescope pointing

---

## 8. Recommendations for SharpCap-SSP Implementation

### Core Features

#### 8.1 FOE Star Catalog Integration
- **Import** FOE Data Version 2.txt and Sloan variant
- **Store** in database with RA, DEC, magnitudes, spectral types
- **Consider** expanding catalog (current 22 stars → 50-100 stars for better sky coverage)

#### 8.2 Real-Time Airmass Calculator
**Inputs**:
- Observer location (latitude, longitude, elevation) from ssp_config.py
- Current UTC time
- Star RA/DEC from catalog

**Outputs**:
- Current airmass (X)
- Current altitude (degrees above horizon)
- Current azimuth (compass direction)
- Hour angle (HA)
- Rise/set times
- Transit time (minimum airmass)

**Implementation**:
```python
import math
from datetime import datetime, timezone

def calculate_airmass(ra_deg, dec_deg, lat_deg, lon_deg, utc_time):
    """
    Calculate airmass using Hardie equation.
    
    Args:
        ra_deg: Right Ascension in degrees (0-360)
        dec_deg: Declination in degrees (-90 to +90)
        lat_deg: Observer latitude in degrees
        lon_deg: Observer longitude in degrees (positive East)
        utc_time: datetime object in UTC
    
    Returns:
        dict with airmass, altitude, azimuth, hour_angle
    """
    # Convert to Julian Date
    jd = utc_to_jd(utc_time)
    jt = jd / 36525.0
    
    # Calculate Local Mean Sidereal Time
    mst = 280.46061837 + 360.98564736629 * jd + 0.000387933 * jt**2 - jt**3/38710000.0
    lmst = (mst + lon_deg) % 360.0
    
    # Hour Angle
    ha = (lmst - ra_deg) % 360.0
    
    # Convert to radians
    ha_rad = math.radians(ha)
    dec_rad = math.radians(dec_deg)
    lat_rad = math.radians(lat_deg)
    
    # Altitude (elevation angle)
    sin_alt = math.sin(lat_rad) * math.sin(dec_rad) + \
              math.cos(lat_rad) * math.cos(dec_rad) * math.cos(ha_rad)
    alt_rad = math.asin(sin_alt)
    alt_deg = math.degrees(alt_rad)
    
    # Zenith distance
    zenith_dist = 90.0 - alt_deg
    
    # Secant of zenith angle
    if alt_deg > 0:
        sec_z = 1.0 / sin_alt
        
        # Hardie equation
        airmass = sec_z - 0.0018167 * (sec_z - 1) - \
                  0.002875 * (sec_z - 1)**2 - \
                  0.0008083 * (sec_z - 1)**3
    else:
        airmass = None  # Star below horizon
    
    # Azimuth
    cos_az = (math.sin(dec_rad) - math.sin(lat_rad) * sin_alt) / \
             (math.cos(lat_rad) * math.cos(alt_rad))
    az_rad = math.acos(np.clip(cos_az, -1, 1))
    az_deg = math.degrees(az_rad)
    if math.sin(ha_rad) > 0:
        az_deg = 360.0 - az_deg
    
    return {
        'airmass': airmass,
        'altitude': alt_deg,
        'azimuth': az_deg,
        'hour_angle': ha,
        'visible': alt_deg > 0
    }
```

#### 8.3 Target Selection UI

**FOE Target List Window**:
```
┌─────────────────────────────────────────────────────────────────────┐
│ First Order Extinction - Target Selection                          │
├─────────────────────────────────────────────────────────────────────┤
│ Observer Location: N42.9, W085.4        UTC: 2024-01-15 02:30:00  │
│ Filter System: ○ Johnson/Cousins  ● Sloan                         │
├─────────────────────────────────────────────────────────────────────┤
│ Star Name  │ RA(J2000) │ DEC      │ Vmag │ Airmass │ Alt  │ Az   │ │
│────────────┼───────────┼──────────┼──────┼─────────┼──────┼──────┤ │
│ BS477   ✓  │ 01:40:35  │ +40:34   │ 4.94 │  1.23   │ 54.2 │ 125  │ │
│ BS607      │ 02:03:12  │ +00:07   │ 5.42 │  1.89   │ 31.8 │ 145  │ │
│ BS1389     │ 04:25:29  │ +17:55   │ 4.29 │  2.45   │ 24.1 │ 98   │ │
│ BS1826     │ 05:28:57  │ -03:18   │ 6.38 │  below horizon         │ │
│ BS2710     │ 07:11:51  │ +05:39   │ 6.08 │  below horizon         │ │
│ ...                                                                 │
├─────────────────────────────────────────────────────────────────────┤
│ Filters: ☑ u'  ☑ g'  ☑ r'  ☑ i'  ☐ z'                            │
│ Airmass Range: [1.0] to [2.5]    ☑ Show only observable stars     │
├─────────────────────────────────────────────────────────────────────┤
│ Selected: BS477  Observations: 2 sets  Next: 02:45:00 (15 min)    │
├─────────────────────────────────────────────────────────────────────┤
│ [Start Observation]  [Export to Script]  [Close]                   │
└─────────────────────────────────────────────────────────────────────┘
```

**Features**:
- ✓ Checkboxes to select multiple targets
- Real-time airmass updates (refresh every 30-60 seconds)
- Color coding: Green (X=1.0-1.5), Yellow (X=1.5-2.0), Orange (X=2.0-2.5), Red (X>2.5 or <horizon)
- Sort by: Name, Airmass, Altitude, RA
- Filter visibility: Show only observable (alt > 10°, airmass < 3.0)

#### 8.4 Observation Guidance

**Timeline view**:
```
Alt (°)
 90 ┤
    │     BS477
 60 ┤    ╱────╲
    │   ╱      ╲        BS607
 30 ┤  ╱        ╲      ╱────╲
    │ ╱          ╲    ╱      ╲
  0 ┼───────────────────────────────
    0h   1h   2h   3h   4h   5h   (time from now)
    
Recommended observation windows:
• BS477:  Now to 03:30 (airmass 1.2 → 1.6)
• BS607:  02:45 to 04:00 (airmass 1.5 → 2.1)
```

#### 8.5 Automated Observation Sequence

**Script generator**:
1. Select N extinction stars (e.g., 3-5 stars)
2. Choose filters (all or subset)
3. Set time interval between observation sets (15-30 minutes)
4. Generate script with:
   - Sky background measurements
   - Star observations in optimal order
   - Automatic airmass tracking
   - Stop conditions (airmass > 2.5, alt < 15°)

#### 8.6 Data Export for External Analysis

**Output format** (CSV):
```csv
Timestamp,Star,Filter,Counts,Airmass,Altitude,Azimuth,RA,DEC
2024-01-15T02:30:15,BS477,u',755,1.23,54.2,125.3,25.146,40.576
2024-01-15T02:30:45,BS477,g',3339,1.24,54.1,125.5,25.146,40.576
...
```

Or **native .raw format** compatible with Extinction2,56.bas for direct import.

---

## 9. Enhanced Features Beyond SSPDataq

### 9.1 Multi-Site Extinction Monitoring
- Store extinction coefficients per site
- Track temporal variations (nightly, seasonal)
- Alert when coefficients deviate from historical mean

### 9.2 Weather Integration
- Check cloud cover / sky transparency forecasts
- Warn if conditions unsuitable for extinction work
- Suggest optimal observing windows

### 9.3 Intelligent Star Selection
**Algorithm**:
1. Filter stars by current visibility (alt > 15°)
2. Prioritize stars with airmass in optimal range (1.2 - 2.2)
3. Ensure diversity: Select stars spanning different azimuths to avoid systematic errors
4. Check expected count rates: Avoid saturated or too-faint targets
5. Optimize observing sequence: Rising stars first, setting stars later

### 9.4 Real-Time Quality Assessment
- Monitor standard error during observations
- Flag outlier points (>3σ from regression line)
- Suggest repeating poor-quality measurements
- Display preliminary K' values after each observation set

### 9.5 Educational Mode
- Display live plots of airmass vs. magnitude
- Explain extinction physics
- Show comparison with typical values
- Highlight second-order effects (color dependence)

---

## 10. Technical Considerations

### 10.1 Time and Coordinate Systems
- **Epoch**: J2000.0 for RA/DEC
- **Time standard**: UTC for observations
- **Julian Date**: From J2000.0 epoch (JD - 2451545.0)
- **Precession**: May need to apply for very old catalogs or high-precision work

### 10.2 Atmospheric Corrections
- **Hardie equation**: Valid for zenith distances up to ~75° (airmass ~3.8)
- **Refraction**: Already included in Hardie formula
- **Differential refraction**: Affects color measurements at high airmass (>2.5)
- **Site altitude**: Extinction typically decreases with elevation

### 10.3 Observational Considerations
- **Sky background**: Must be stable during observation sequence
- **Scattered light**: Moon, twilight, light pollution affect extinction measurements
- **Star colors**: Use range of B-V colors to detect second-order extinction
- **Photometric nights**: Cirrus, haze, aerosols invalidate extinction determinations

### 10.4 Error Sources
- **Sky subtraction errors**: Dominant for faint stars or bright sky
- **Atmospheric variability**: Clouds, haze changing during observations
- **Centering errors**: Star drift in photometer aperture
- **Flat-fielding**: Telescope vignetting vs. field position
- **Color terms**: Instrumental passbands differ from standard system

---

## 11. Implementation Priority

### Phase 1 (MVP - Minimum Viable Product)
✓ **Import FOE star catalog** (22 stars from FOE Data Version 2.txt)  
✓ **Airmass calculator** (Hardie equation implementation)  
✓ **Target list UI** with real-time airmass display  
✓ **Filter by observability** (alt > 10°, airmass < 2.5)  

### Phase 2 (Enhanced Usability)
✓ **Altitude/azimuth display** for telescope pointing  
✓ **Timeline view** showing star visibility over next 4-6 hours  
✓ **Sort/filter** by airmass, altitude, RA  
✓ **Export target list** to CSV or observing log  

### Phase 3 (Automation)
✓ **Script generator** for automated observation sequences  
✓ **Multi-target scheduling** with optimal time spacing  
✓ **Sky background** auto-measurement between star sets  
✓ **Stop conditions** (airmass limits, altitude limits)  

### Phase 4 (Analysis Integration)
⚬ **Live plotting** of airmass vs. instrumental magnitude  
⚬ **Preliminary K' calculation** after 3+ observation sets  
⚬ **Outlier detection** and quality flags  
⚬ **Export to Extinction2.bas format** (or native Python analysis)  

### Phase 5 (Advanced Features)
⚬ **Second-order extinction** analysis  
⚬ **Historical extinction tracking** per site  
⚬ **Weather API integration** for sky conditions  
⚬ **Multi-site extinction database**  

---

## 12. Python Module Structure (Proposed)

```
ssp_extinction.py
├── FOECatalog class
│   ├── load_catalog()          # Read FOE Data Version 2.txt
│   ├── get_star(name)          # Retrieve star by name
│   └── filter_stars(criteria)  # Filter by observability
│
├── AirmassCalculator class
│   ├── set_location(lat, lon)  # Observer coordinates
│   ├── set_time(utc_datetime)  # Current time
│   ├── calculate_lmst()        # Local Mean Sidereal Time
│   ├── calculate_airmass(ra, dec)  # Hardie equation
│   └── calculate_altaz(ra, dec)    # Altitude/azimuth
│
├── FOETargetSelector class
│   ├── update_targets()        # Refresh airmass for all stars
│   ├── filter_observable()     # Remove below-horizon stars
│   ├── sort_by_airmass()       # Optimal ordering
│   └── export_to_csv()         # Save target list
│
└── FOEObservationPlanner class
    ├── generate_script()       # Create observation sequence
    ├── estimate_duration()     # Total observing time
    ├── check_conflicts()       # Detect scheduling issues
    └── export_timeline()       # Visual planning aid
```

---

## 13. Data Structures

### FOE Star Entry
```python
@dataclass
class FOEStar:
    name: str           # "BS477"
    spectral_type: str  # "B" or "A"
    ra_deg: float       # Right Ascension in degrees (0-360)
    dec_deg: float      # Declination in degrees (-90 to +90)
    v_mag: float        # V-band magnitude
    b_v: float          # B-V color index
    u_b: float          # U-B color index
    v_r: float          # V-R color index
    v_i: float          # V-I color index
```

### Observation Result
```python
@dataclass
class FOEObservation:
    timestamp: datetime  # UTC time
    star: FOEStar
    filter_name: str     # 'U', 'B', 'V', 'R', 'I', etc.
    counts: float        # Raw photometer counts
    airmass: float       # X at observation time
    altitude: float      # Degrees above horizon
    azimuth: float       # Compass direction
    sky_counts: float    # Interpolated sky background
    inst_mag: float      # -2.5 * log10(counts - sky)
```

---

## 14. References and Resources

### Scientific References
1. **Hardie, R.H. (1962)**: "Photoelectric Reductions", *Astronomical Techniques*, Chapter 8  
   → Source of the Hardie airmass equation

2. **Henden & Kaitchuck (1982)**: *Astronomical Photometry: A Text and Handbook for the Advanced Amateur and Professional Astronomer*  
   → Comprehensive guide to photometric techniques

3. **Young, A.T. (1994)**: "Air Mass and Refraction", *Applied Optics*, 33, 1108  
   → Modern discussion of atmospheric effects

### Catalog References
4. **Bright Star Catalogue (BSC)**: Hoffleit & Jaschek (1991), 5th Edition  
   → Source of BS star identifications

5. **Landolt Photometric Standards**: Landolt, A.U. (1992), *AJ*, 104, 340  
   → Alternative standard stars (not used in SSPDataq, but widely used)

### Software References
6. **SSPDataq v3.3.21**: Optec, Inc. (2015)  
   → Main data acquisition program

7. **Extinction2.56**: Optec, Inc. (2015)  
   → Extinction analysis module analyzed in this document

---

## 15. Glossary

**Airmass (X)**: Dimensionless quantity representing the path length through the atmosphere relative to the zenith path. X=1 at zenith, X→∞ at horizon.

**First Order Extinction (K')**: Linear coefficient describing magnitude loss per unit airmass. Typically 0.1-0.5 mag/airmass depending on filter.

**Hardie Equation**: Atmospheric refraction correction to the simple sec(z) airmass formula.

**Instrumental Magnitude**: Brightness measured by detector in arbitrary units, m_inst = -2.5 log₁₀(counts).

**LMST (Local Mean Sidereal Time)**: Local time measured by Earth's rotation relative to distant stars (not the Sun).

**Second Order Extinction (K'')**: Color-dependent atmospheric extinction, typically small (~-0.05 mag/airmass).

**Zenith Distance (z)**: Angular distance from the zenith (overhead point), z = 90° - altitude.

---

## Appendix A: Sample Extinction Data

### Sample_Extinction.raw (excerpt)
```
FILENAME=E.RAW       RAW OUTPUT DATA FROM SSP DATA ACQUISITION PROGRAM
UT DATE= 09/23/2007   TELESCOPE= 10" MEADE      OBSERVER= JERRY
CONDITIONS= GOOD

09-23-2007 02:08:24 C BS458  U  00706  00712  00706  0  10 1
09-23-2007 02:09:01 C BS458  B  04382  04400  04404  0  10 1
09-23-2007 02:09:38 C BS458  V  06785  06844  06781  0  10 1
09-23-2007 02:10:23 C BS458  R  03533  03571  03598  0  10 1

[~15 minutes later, higher airmass]
09-23-2007 02:26:19 C BS458  U  00738  00748  00750  0  10 1
09-23-2007 02:27:06 C BS458  B  04475  04537  04535  0  10 1
09-23-2007 02:27:43 C BS458  V  06945  06818  06975  0  10 1

[~30 minutes later, even higher airmass]
09-23-2007 02:57:24 C BS458  U  00808  00799  00798  0  10 1
09-23-2007 02:57:58 C BS458  B  04654  04660  04651  0  10 1
09-23-2007 02:58:32 C BS458  V  07092  07070  07026  0  10 1
```

**Observation**: Notice counts *increase* with time despite star setting → extinction effect clearly visible in data.

---

## Appendix B: PPparms3.txt Sample Configuration

```
N42.9_W085.4          Location (N42.9°, W85.4°)
0.000                 KU (often not determined, set to 0)
0.466                 KB (blue extinction, largest value)
0.252                 KV (visual extinction, reference)
0.115                 KR (red extinction, lower than V)
0.000                 KI (infrared, set to 0 if not determined)
-0.053                K''(b-v) second order extinction
[... transformation coefficients ...]
0.000                 Ku (Sloan u', not determined)
0.300                 Kg (Sloan g')
0.200                 Kr (Sloan r')
0.100                 Ki (Sloan i')
0.050                 Kz (Sloan z')
```

**Typical pattern**: Extinction decreases from blue (B/g') to red (R/i') to infrared (I/z'), consistent with Rayleigh scattering dominance.

---

## Appendix C: All Sky Calibration Module (AllSky2,57.bas)

### Purpose and Scope

**All Sky Calibration** is a separate analysis module in SSPDataq that determines **zero-point constants** and **residual extinction** for wide-field all-sky photometry. Unlike FOE which measures pure atmospheric extinction, All Sky calibration computes instrument-specific calibration parameters.

### Key Differences from FOE

| Aspect | First Order Extinction | All Sky Calibration |
|--------|----------------------|---------------------|
| **Star Type** | "C" (Comparison stars) | "F" (Field/calibration stars) |
| **Purpose** | Measure K' (atmospheric extinction) | Measure ZP (zero-points) and residual K |
| **Observation Strategy** | Multiple airmasses per star | Single or few observations per star |
| **Sky Coverage** | Any stars, focused on good airmass | Distributed across entire sky |
| **Output** | K', K'' for each filter | ZP_v, ZP_bv, K_v, K_bv, std errors |
| **Application** | Differential photometry | All-sky monitoring, patrol cameras |

### Calculation Workflow (AllSky2,57.bas)

#### Step 1: Data Loading and Sky Subtraction (lines 924-973)

**Identical to FOE module**:
- Reads `.raw` file with "F" type stars
- Performs linear sky interpolation between measurements
- Normalizes counts to standard integration/scale

#### Step 2: Airmass Calculation (lines 1199-1212)

**Identical Hardie equation implementation**:
```basic
[Find_Air_Mass]
    HA = LMST - RA(TransIndex)
    if HA < 0 then HA = HA + 360
    
    HAradians = HA * 3.1416/180
    DECradians = DEC(TransIndex) * 3.1416/180
    LATradians = LAT * 3.1416/180
    
    secZ = 1/(sin(LATradians) * sin(DECradians) + cos(LATradians) * cos(DECradians) * cos(HAradians))
    AirMass = secZ - 0.0018167 * (secZ - 1) - 0.002875 * (secZ - 1)^2 - 0.0008083 * (secZ - 1)^3
return
```

#### Step 3: Instrumental Magnitudes (lines 1048-1055)

```basic
InstrumentMag = -1.0857 * log(CountFinal(RawIndex))
```

Stores separately for B and V filters:
```basic
m(TransIndex, 1) = InstrumentMag    ' b (or g for Sloan)
m(TransIndex, 2) = InstrumentMag    ' v (or r for Sloan)
```

#### Step 4: Calibration Quantities (lines 1067-1086)

**For Johnson/Cousins system:**

```
V - v = Catalog magnitude - Instrumental magnitude
B - V = Standard color index (from catalog)
b - v = Instrumental color (measured)

TransColor2 = (V - v) - ε(B-V)     [Equation G.10]
TransColor3 = (B - V) - μ(b-v)     [Equation G.11]
```

**For Sloan system:**

```
r - r' = Catalog magnitude - Instrumental magnitude
g - r = Standard color index (from catalog)
g' - r' = Instrumental color (measured)

TransColor2 = (r - r') - ε(g-r)
TransColor3 = (g - r) - μ(g'-r')
```

Where:
- **ε (epsilon)**: Transformation coefficient for magnitude (from PPparms3.txt)
- **μ (mu)**: Color transformation coefficient (from PPparms3.txt)

#### Step 5: Regression Analysis (lines 1214-1256)

**Two separate linear regressions:**

**Regression 1 - Zero-point for magnitude:**
```
Y = (V - v) - ε(B-V)
X = Average airmass

Linear fit: Y = K_v × X + ZP_v

Output:
  Slope = K_v (residual extinction)
  Intercept = ZP_v (zero-point constant)
  Std Error = E_v
```

**Regression 2 - Zero-point for color:**
```
Y = (B - V) - μ(b-v)
X = Average airmass

Linear fit: Y = K_bv × X + ZP_bv

Output:
  Slope = K_bv (color extinction difference)
  Intercept = ZP_bv (color zero-point)
  Std Error = E_bv
```

### Physical Interpretation

**Zero-point constant (ZP)**: The offset between instrumental and standard magnitudes at zero airmass, accounting for:
- Telescope collecting area
- Detector quantum efficiency
- Filter transmission profile
- System throughput

**Residual extinction (K)**: Small atmospheric extinction component remaining after applying transformation coefficients. Ideally should be close to zero if transformation coefficients are accurate.

### Saved Parameters (lines 1140-1175)

Saved to PPparms3.txt:
```
ZPv   = Zero-point for V (or r for Sloan)
ZPbv  = Zero-point for B-V (or g-r)
Ev    = Standard error for V magnitude
Ebv   = Standard error for B-V color
K_v   = Residual extinction for V
K_bv  = Residual extinction for B-V (difference: KB - KV or Kg - Kr)
```

### Usage in Photometry

When performing all-sky photometry with calibrated system:

```
V_standard = v_inst + K_v × X + ZP_v + ε(B-V)
(B-V)_standard = (b-v)_inst + K_bv × X + ZP_bv + additional_terms
```

### Comparison: FOE vs All Sky

**First Order Extinction workflow:**
1. Observe extinction stars at multiple airmasses (X = 1.0 to 2.5)
2. Measure pure atmospheric extinction: m_inst vs X
3. Determine K' from slope
4. Apply K' to correct all subsequent photometry

**All Sky Calibration workflow:**
1. Observe calibration stars distributed across sky
2. Already have K' from FOE (loaded from PPparms)
3. Determine zero-points and residual extinction
4. Apply ZP + residual K for absolute photometry

**When to use each:**
- **FOE**: Always perform first on photometric nights
- **All Sky**: Optional, for absolute photometry or all-sky cameras
- **Typical workflow**: FOE → Transformation → (optional) All Sky

---

## Appendix D: Complete Mathematical Summary

### All FOE Calculations - End to End

**Complete equation chain from raw observation to extinction coefficient:**

$$\text{CountFinal} = \text{int}\left(\frac{\sum_{i=1}^{N} \text{Count}_i}{N} \times \frac{100}{\text{Integration} \times \text{Scale}}\right)$$

$$\text{SkyInterpolated} = \text{SkyPast} + \frac{\text{SkyFuture} - \text{SkyPast}}{\text{JD}_{\text{future}} - \text{JD}_{\text{past}}} \times (\text{JD}_{\text{obs}} - \text{JD}_{\text{past}})$$

$$\text{CountNet} = \text{CountFinal} - \text{SkyInterpolated}$$

$$m_{\text{inst}} = -1.0857 \times \ln(\text{CountNet}) = -\frac{2.5}{\ln(10)} \times \ln(\text{CountNet})$$

$$\text{JD} = B + C + D - 730550.5 + \text{day} + \frac{\text{hour} + \text{min}/60 + \text{sec}/3600}{24}$$

where:
$$A = \lfloor \text{year}/100 \rfloor, \quad B = 2 - A + \lfloor A/4 \rfloor$$
$$C = \lfloor 365.25 \times \text{year} \rfloor, \quad D = \lfloor 30.6001 \times (\text{month} + 1) \rfloor$$

$$\text{JT} = \frac{\text{JD}}{36525}$$

$$\text{MST} = 280.46061837 + 360.98564736629 \times \text{JD} + 0.000387933 \times \text{JT}^2 - \frac{\text{JT}^3}{38710000}$$

$$\text{LMST} = \text{MST} + \lambda \quad (\text{mod } 360°)$$

$$\text{HA} = \text{LMST} - \alpha \quad (\text{mod } 360°)$$

$$\sec(z) = \frac{1}{\sin(\phi)\sin(\delta) + \cos(\phi)\cos(\delta)\cos(\text{HA})}$$

$$X = \sec(z) - 0.0018167(\sec(z)-1) - 0.002875(\sec(z)-1)^2 - 0.0008083(\sec(z)-1)^3$$

**Linear regression (Nielson method):**

$$\begin{aligned}
a_1 &= N \\
a_2 &= \sum_{i=1}^{N} X_i \\
a_3 &= \sum_{i=1}^{N} X_i^2 \\
c_1 &= \sum_{i=1}^{N} m_i \\
c_2 &= \sum_{i=1}^{N} m_i X_i
\end{aligned}$$

$$\text{det} = \frac{1}{a_1 a_3 - a_2^2}$$

$$K' = \text{Slope} = (a_1 c_2 - c_1 a_2) \times \text{det}$$

$$m_0 = \text{Intercept} = -(a_2 c_2 - c_1 a_3) \times \text{det}$$

$$\sigma_{\text{std}} = \sqrt{\frac{1}{N-2} \sum_{i=1}^{N} (m_i - (K' X_i + m_0))^2}$$

**Result:** $m_{\text{inst}} = K' \times X + m_0$

### Variable Definitions

| Symbol | Name | Units | Description |
|--------|------|-------|-------------|
| $\alpha$ | Right Ascension | degrees | Star RA (0-360°) |
| $\delta$ | Declination | degrees | Star DEC (-90 to +90°) |
| $\phi$ | Latitude | degrees | Observer latitude |
| $\lambda$ | Longitude | degrees | Observer longitude (positive East) |
| HA | Hour Angle | degrees | Time since meridian transit |
| LMST | Local Mean Sidereal Time | degrees | Sidereal time at observer location |
| MST | Mean Sidereal Time | degrees | Sidereal time at Greenwich |
| JD | Julian Date | days | Days from J2000.0 epoch |
| JT | Julian Century | centuries | Centuries from J2000.0 |
| $z$ | Zenith Distance | degrees | Angle from zenith |
| $X$ | Airmass | dimensionless | Path length through atmosphere |
| $K'$ | Extinction Coefficient | mag/airmass | First order extinction |
| $m_{\text{inst}}$ | Instrumental Magnitude | mag | Magnitude from photometer |
| $m_0$ | Zero-airmass Magnitude | mag | Magnitude at top of atmosphere |

### Constants

| Symbol | Value | Description |
|--------|-------|-------------|
| $\pi$ | 3.1416 | Pi (as used in BASIC code) |
| ln(10) | 2.302585 | Natural log of 10 |
| -2.5/ln(10) | -1.0857 | Magnitude conversion factor |
| 730550.5 | | JD adjustment to J2000.0 |
| 280.46061837 | degrees | LMST constant term |
| 360.98564736629 | deg/day | Earth rotation rate |
| 0.000387933 | | LMST quadratic coefficient |
| 38710000 | | LMST cubic denominator |
| 0.0018167 | | Hardie linear coefficient |
| 0.002875 | | Hardie quadratic coefficient |
| 0.0008083 | | Hardie cubic coefficient |

---

**Document Version**: 2.0  
**Date**: 2026-01-27  
**Author**: Complete analysis of SSPDataq FOE and All Sky modules  
**Source Code Analyzed**: 
- Extinction2,56.bas (1469 lines)
- AllSky2,57.bas (1366 lines)
- Supporting documentation and sample data files

**Status**: 100% complete and verified against source code
