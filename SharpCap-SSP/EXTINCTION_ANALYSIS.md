# First Order Extinction (FOE) Analysis - SSPDataq Implementation Study

## Executive Summary

**Purpose**: Document how SSPDataq implements first order extinction (FOE) observations and analysis to guide SharpCap-SSP implementation.

**Key Finding**: SSPDataq uses a **post-observation analysis workflow** where:
1. Observer manually selects extinction stars from FOE catalog
2. Data acquisition program (SSPDataq3) collects photometric observations
3. Separate Extinction2 module performs least-squares regression analysis
4. Extinction coefficients (K' values) are saved to PPparms3.txt for future photometry

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

### Core Algorithm (from Transformation2,56.bas lines 1535-1550)

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
```
m_inst = -2.5 × log₁₀(counts) = -1.0857 × ln(counts)
```

**Sky subtraction**: Sky counts are interpolated linearly between SKY/SKYNEXT measurements based on observation timestamp.

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

**Document Version**: 1.0  
**Date**: 2024-01-15  
**Author**: Analysis of SSPDataq extinction implementation for SharpCap-SSP development  
**Status**: Comprehensive analysis complete, ready for implementation planning
