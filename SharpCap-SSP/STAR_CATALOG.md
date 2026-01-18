# Star Catalog Integration

## Overview

SharpCap-SSP now includes integrated support for the PEP (Precision Eclipsing Binaries and Pulsators) star catalog, containing 300+ variable stars with their comparison and check stars for differential photometry.

## Files

### ssp_catalog.py
Complete star catalog module with classes and methods for managing photometry targets.

**Key Classes:**
- `StarData` - Individual star with RA/Dec coordinates, magnitude, color indices
- `TargetTriple` - Variable star paired with comparison and check stars
- `StarCatalog` - Catalog loader and search interface

**Key Features:**
- Load from PEP starparm_latest.csv format (30 columns)
- Search by star name or AAVSO unique identifier
- Filter by RA range or magnitude range
- Coordinate conversion (RA/Dec to decimal degrees)

### starparm_latest.csv
PEP photometry target catalog with 304 stars.

**Data Format (30 columns):**
1. usename - Variable star abbreviation (e.g., "ALF SCO", "OMI CET")
2. auid - Modern AAVSO designation
3. desig - Old AAVSO designation  
4-6. vrah, vram, vras - Variable RA (hours, minutes, seconds)
7-9. vded, vdem, vdes - Variable Dec (degrees, minutes, seconds)
10. vspec - Variable spectral type
11. vvmag - Variable V magnitude
12. vbmv - Variable B-V color index
13. cname - Comparison star ID (HR, HD, or SAO number)
14-16. crah, cram, cras - Comparison RA
17-19. cded, cdem, cdes - Comparison Dec
20. cvmag - Comparison V magnitude
21. cbmv - Comparison B-V color index
22. kname - Check star ID
23-25. krah, kram, kras - Check RA
26-28. kded, kdem, kdes - Check Dec
29. kvmag - Check V magnitude
30. deltabmv - Delta (B-V) of variable and comparison

**Source:**
PEP (Precision Eclipsing Binaries and Pulsators) project variable star list.
Maintained by AAVSO for standardized differential photometry.

## User Interface Integration

### Menu: Catalog
Added to ssp_dataaq.py main data acquisition window.

**Menu Items:**
- **Select Target Star** - Opens searchable star selection dialog
- **Reload Catalog** - Reloads CSV file (useful after updates)

### Star Selection Dialog
Full-featured star picker with:
- **Search box** - Filter by partial name match
- **Star list** - Shows all targets with RA/Dec and magnitude
- **Detail panel** - Full information about selected target:
  - Variable star coordinates, magnitude, B-V, spectral type
  - Comparison star coordinates and magnitude
  - Check star coordinates and magnitude
  - AAVSO identifiers
  - Delta B-V color index

### Object Combobox Integration
When a star is selected from the catalog:
- Automatically added to the Object combobox
- Format: "VAR_NAME | Comp: COMP_NAME | Check: CHECK_NAME"
- Selected as current object for data collection

## Usage Example

### Basic Usage
```python
import ssp_catalog

# Load catalog
catalog = ssp_catalog.StarCatalog("starparm_latest.csv")
print("Loaded %d targets" % catalog.get_count())

# Search by name
target = catalog.get_target_by_name("OMI CET")
if target:
    print(target.variable)      # Variable star info
    print(target.comparison)    # Comparison star
    print(target.check)         # Check star

# Search by AAVSO ID
target = catalog.get_target_by_auid("000-BBD-706")

# Find stars in RA range (0h to 2h)
targets = catalog.get_targets_in_ra_range(0, 2)

# Find stars by magnitude (4th to 6th magnitude)
targets = catalog.get_targets_by_magnitude_range(4.0, 6.0)

# Get all variable names
names = catalog.get_all_variable_names()
```

### In Data Acquisition Window
1. Launch SSPDataq3 window
2. Menu: **Catalog → Select Target Star**
3. Type search term (e.g., "OMI")
4. Click on "OMI CET" in list
5. Review variable, comparison, and check star details
6. Click **Select**
7. Target appears in Object combobox
8. Proceed with data collection as normal

## Technical Details

### Coordinate Handling
- **Input:** CSV contains RA/Dec in sexagesimal format (HH:MM:SS, DD:MM:SS)
- **Storage:** StarData objects store as separate hours/minutes/seconds
- **Conversion:** Properties convert to decimal degrees when needed
  - `ra_degrees` - RA in degrees (0-360)
  - `dec_degrees_decimal` - Dec in degrees (-90 to +90)
- **Display:** Methods format back to sexagesimal strings
  - `ra_string()` - "HH:MM:SS.SS"
  - `dec_string()` - "+DD:MM:SS.SS"

### Error Handling
- Missing or invalid CSV values default to None
- Parsing errors skip individual rows with warnings
- Empty catalog handled gracefully in UI
- File not found displays helpful error message

### Performance
- Full catalog (304 targets) loads in <0.1 seconds
- Search operations are instant (linear scan)
- No database required - simple CSV file

## Data Source Information

The starparm_latest.csv file comes from the PEP (Precision Eclipsing Binaries and Pulsators) project's standardized list of photometry targets. This list evolves over time as new targets are added and data is refined.

**Key Features of PEP Catalog:**
- Target, comparison, and check stars for differential photometry
- Comparison stars are always identified by HR, HD, or SAO numbers
- Variables occasionally identified by catalog numbers
- Greek letter ambiguity resolved (MU/NU vs MIU/NIU)
- Some stars have synonym abbreviations (appear twice)
- Sorted by Right Ascension for convenient observing planning

**Change Log:**
The PEP website maintains a change log showing updates to the catalog. Users can download the latest version and replace starparm_latest.csv, then use **Catalog → Reload Catalog** in the application.

## Future Enhancements

Potential additions for future versions:
- [ ] Direct observation sequence generation (V-C-V-C-K pattern)
- [ ] Automatic filter suggestions based on spectral type
- [ ] Export selected targets to observing list
- [ ] Integration with telescope pointing (if SharpCap connected)
- [ ] Chart generation showing variable, comp, and check positions
- [ ] Airmass calculations based on observation site and time
- [ ] Finding charts from online surveys
- [ ] Multi-target observing session planning

## Testing

To test the catalog module independently:
```bash
ipy ssp_catalog.py
```

This runs the built-in test function that:
- Loads the catalog
- Displays the first 5 targets
- Searches for "OMI CET"
- Demonstrates RA range search
- Demonstrates magnitude range search

## Documentation References

- **CSV Format:** See module docstring in ssp_catalog.py
- **PEP Project:** Variable star photometry standardization project
- **AAVSO:** American Association of Variable Star Observers
- **SSPDataq:** Original LibertyBasic software used similar star database

## Version History

**v0.1.0 (January 2026)**
- Initial implementation
- Full catalog loading from CSV
- Search and filter capabilities
- UI integration with data acquisition window
- Star selection dialog with details view
