"""
SSP Star Catalog Module
========================

Module for loading and managing PEP photometry target star catalogs.
Handles variable, comparison, and check star data from CSV files.

Author: pep-ssp-tools project
Version: 0.1.2
Date: January 2026

CSV Format (30 columns):
1. usename - Variable star abbreviation (e.g., ALF SCO, NSV 6687, V368 HER)
2. auid - Modern AAVSO designation
3. desig - Old AAVSO designation
4-6. vrah, vram, vras - Variable RA (hh, mm, ss)
7-9. vded, vdem, vdes - Variable Dec (dd, mm, ss)
10. vspec - Variable spectral type
11. vvmag - Variable V magnitude
12. vbmv - Variable B-V color index
13. cname - Comparison star ID (HR, HD, SAO)
14-16. crah, cram, cras - Comparison RA (hh, mm, ss)
17-19. cded, cdem, cdes - Comparison Dec (dd, mm, ss)
20. cvmag - Comparison V magnitude
21. cbmv - Comparison B-V color index
22. kname - Check star ID
23-25. krah, kram, kras - Check RA (hh, mm, ss)
26-28. kded, kdem, kdes - Check Dec (dd, mm, ss)
29. kvmag - Check V magnitude
30. deltabmv - Delta (B-V) of variable and comparison
"""

import os
import csv


class StarData:
    """Class representing a single star's data."""
    
    def __init__(self, name, ra_hours, ra_minutes, ra_seconds, 
                 dec_degrees, dec_minutes, dec_seconds, 
                 vmag=None, bv_color=None, spectral_type=None):
        """
        Initialize star data.
        
        Args:
            name: Star name/identifier
            ra_hours: Right Ascension hours (0-23)
            ra_minutes: Right Ascension minutes (0-59)
            ra_seconds: Right Ascension seconds (0-59.999)
            dec_degrees: Declination degrees (-90 to +90)
            dec_minutes: Declination minutes (0-59)
            dec_seconds: Declination seconds (0-59.999)
            vmag: V magnitude (float or None)
            bv_color: B-V color index (float or None)
            spectral_type: Spectral type string (optional)
        """
        self.name = name
        self.ra_hours = self._safe_float(ra_hours, 0)
        self.ra_minutes = self._safe_float(ra_minutes, 0)
        self.ra_seconds = self._safe_float(ra_seconds, 0)
        self.dec_degrees = self._safe_float(dec_degrees, 0)
        self.dec_minutes = self._safe_float(dec_minutes, 0)
        self.dec_seconds = self._safe_float(dec_seconds, 0)
        self.vmag = self._safe_float(vmag)
        self.bv_color = self._safe_float(bv_color)
        self.spectral_type = spectral_type if spectral_type else ""
        
    @staticmethod
    def _safe_float(value, default=None):
        """Safely convert value to float, returning default if conversion fails."""
        if value is None or value == "":
            return default
        try:
            return float(value)
        except (ValueError, TypeError):
            return default
    
    @property
    def ra_degrees(self):
        """Convert RA to decimal degrees (0-360)."""
        return (self.ra_hours + self.ra_minutes/60.0 + self.ra_seconds/3600.0) * 15.0
    
    @property
    def dec_degrees_decimal(self):
        """Convert Dec to decimal degrees with proper sign handling."""
        dec_abs = abs(self.dec_degrees) + self.dec_minutes/60.0 + self.dec_seconds/3600.0
        return dec_abs if self.dec_degrees >= 0 else -dec_abs
    
    def ra_string(self):
        """Format RA as string: HH:MM:SS.S"""
        return "%02d:%02d:%05.2f" % (int(self.ra_hours), int(self.ra_minutes), self.ra_seconds)
    
    def dec_string(self):
        """Format Dec as string: +DD:MM:SS.S"""
        sign = "+" if self.dec_degrees >= 0 else "-"
        return "%s%02d:%02d:%05.2f" % (sign, abs(int(self.dec_degrees)), int(self.dec_minutes), self.dec_seconds)
    
    def __str__(self):
        """String representation for display."""
        mag_str = "V=%.2f" % self.vmag if self.vmag is not None else "V=?"
        return "%s (RA=%s, Dec=%s, %s)" % (self.name, self.ra_string(), self.dec_string(), mag_str)


class TargetTriple:
    """Class representing a variable star with its comparison and check stars."""
    
    def __init__(self, variable, comparison, check, auid="", old_desig="", delta_bv=None):
        """
        Initialize target triple.
        
        Args:
            variable: StarData object for variable star
            comparison: StarData object for comparison star
            check: StarData object for check star
            auid: AAVSO unique identifier
            old_desig: Old AAVSO designation
            delta_bv: Delta B-V between variable and comparison
        """
        self.variable = variable
        self.comparison = comparison
        self.check = check
        self.auid = auid if auid else ""
        self.old_desig = old_desig if old_desig else ""
        self.delta_bv = StarData._safe_float(delta_bv)
        
    def __str__(self):
        """String representation for display."""
        return "Target: %s | Comp: %s | Check: %s" % (
            self.variable.name, self.comparison.name, self.check.name)


class StarCatalog:
    """Class for loading and managing star catalogs."""
    
    def __init__(self, csv_file_path=None):
        """
        Initialize star catalog.
        
        Args:
            csv_file_path: Path to CSV file (optional, can load later)
        """
        self.targets = []  # List of TargetTriple objects
        self.csv_path = None
        
        if csv_file_path:
            self.load_csv(csv_file_path)
    
    def load_csv(self, csv_file_path):
        """
        Load star data from PEP starparm CSV file.
        
        Args:
            csv_file_path: Full path to the CSV file
            
        Returns:
            Number of targets loaded
            
        Raises:
            IOError: If file cannot be read
            ValueError: If CSV format is invalid
        """
        if not os.path.exists(csv_file_path):
            raise IOError("CSV file not found: %s" % csv_file_path)
        
        self.targets = []
        self.csv_path = csv_file_path
        
        with open(csv_file_path, 'r') as f:
            reader = csv.reader(f)
            
            # Read header row
            header = next(reader, None)
            if not header:
                raise ValueError("CSV file is empty")
            
            # Verify expected column count (should be 30)
            expected_cols = 30
            if len(header) != expected_cols:
                raise ValueError("Expected %d columns, found %d" % (expected_cols, len(header)))
            
            # Read data rows
            row_num = 1
            for row in reader:
                row_num += 1
                
                if len(row) != expected_cols:
                    print("Warning: Row %d has %d columns (expected %d), skipping" % 
                          (row_num, len(row), expected_cols))
                    continue
                
                try:
                    # Parse variable star
                    variable = StarData(
                        name=row[0],  # usename
                        ra_hours=row[3],  # vrah
                        ra_minutes=row[4],  # vram
                        ra_seconds=row[5],  # vras
                        dec_degrees=row[6],  # vded
                        dec_minutes=row[7],  # vdem
                        dec_seconds=row[8],  # vdes
                        vmag=row[10],  # vvmag
                        bv_color=row[11],  # vbmv
                        spectral_type=row[9]  # vspec
                    )
                    
                    # Parse comparison star
                    comparison = StarData(
                        name=row[12],  # cname
                        ra_hours=row[13],  # crah
                        ra_minutes=row[14],  # cram
                        ra_seconds=row[15],  # cras
                        dec_degrees=row[16],  # cded
                        dec_minutes=row[17],  # cdem
                        dec_seconds=row[18],  # cdes
                        vmag=row[19],  # cvmag
                        bv_color=row[20]  # cbmv
                    )
                    
                    # Parse check star
                    check = StarData(
                        name=row[21],  # kname
                        ra_hours=row[22],  # krah
                        ra_minutes=row[23],  # kram
                        ra_seconds=row[24],  # kras
                        dec_degrees=row[25],  # kded
                        dec_minutes=row[26],  # kdem
                        dec_seconds=row[27],  # kdes
                        vmag=row[28]  # kvmag
                    )
                    
                    # Create target triple
                    target = TargetTriple(
                        variable=variable,
                        comparison=comparison,
                        check=check,
                        auid=row[1],  # auid
                        old_desig=row[2],  # desig
                        delta_bv=row[29]  # deltabmv
                    )
                    
                    self.targets.append(target)
                    
                except Exception as e:
                    print("Warning: Error parsing row %d: %s" % (row_num, str(e)))
                    continue
        
        print("Loaded %d target stars from %s" % (len(self.targets), os.path.basename(csv_file_path)))
        return len(self.targets)
    
    def get_target_by_name(self, name):
        """
        Find target by variable star name (case-insensitive).
        
        Args:
            name: Variable star name to search for
            
        Returns:
            TargetTriple object or None if not found
        """
        name_upper = name.upper().strip()
        for target in self.targets:
            if target.variable.name.upper() == name_upper:
                return target
        return None
    
    def get_target_by_auid(self, auid):
        """
        Find target by AAVSO unique identifier.
        
        Args:
            auid: AAVSO unique identifier
            
        Returns:
            TargetTriple object or None if not found
        """
        auid_upper = auid.upper().strip()
        for target in self.targets:
            if target.auid.upper() == auid_upper:
                return target
        return None
    
    def get_targets_in_ra_range(self, ra_min, ra_max):
        """
        Find all targets within an RA range (in decimal hours).
        
        Args:
            ra_min: Minimum RA in hours (0-24)
            ra_max: Maximum RA in hours (0-24)
            
        Returns:
            List of TargetTriple objects
        """
        results = []
        for target in self.targets:
            ra_hours = target.variable.ra_hours + target.variable.ra_minutes/60.0 + target.variable.ra_seconds/3600.0
            if ra_min <= ra_hours <= ra_max:
                results.append(target)
        return results
    
    def get_targets_by_magnitude_range(self, mag_min, mag_max):
        """
        Find all targets within a magnitude range.
        
        Args:
            mag_min: Minimum V magnitude
            mag_max: Maximum V magnitude
            
        Returns:
            List of TargetTriple objects
        """
        results = []
        for target in self.targets:
            if target.variable.vmag is not None:
                if mag_min <= target.variable.vmag <= mag_max:
                    results.append(target)
        return results
    
    def get_all_variable_names(self):
        """
        Get list of all variable star names.
        
        Returns:
            List of strings
        """
        return [target.variable.name for target in self.targets]
    
    def get_count(self):
        """Get total number of targets in catalog."""
        return len(self.targets)


def test_catalog():
    """Test function to demonstrate catalog usage."""
    import sys
    import os
    
    # Find the CSV file - handle both direct execution and exec() contexts
    try:
        if '__file__' in dir():
            script_dir = os.path.dirname(os.path.abspath(__file__))
        else:
            # When exec'd or in interactive mode, use current directory
            script_dir = os.getcwd()
    except:
        script_dir = os.getcwd()
    
    csv_file = os.path.join(script_dir, "starparm_latest.csv")
    
    if not os.path.exists(csv_file):
        print("Error: %s not found" % csv_file)
        print("Current directory: %s" % script_dir)
        return
    
    # Load catalog
    print("Loading star catalog...")
    catalog = StarCatalog(csv_file)
    print("Total targets: %d\n" % catalog.get_count())
    
    # Test: Get first 5 targets
    print("First 5 targets:")
    for i, target in enumerate(catalog.targets[:5]):
        print("%d. %s" % (i+1, target))
        print("   Variable: %s" % target.variable)
        print("   Comparison: %s" % target.comparison)
        print("   Check: %s" % target.check)
        if target.auid:
            print("   AAVSO ID: %s" % target.auid)
        print()
    
    # Test: Search by name
    print("\nSearching for 'OMI CET':")
    target = catalog.get_target_by_name("OMI CET")
    if target:
        print("Found: %s" % target)
        print("Variable V mag: %.3f" % target.variable.vmag)
        print("Comparison V mag: %.3f" % target.comparison.vmag)
        print("Delta B-V: %.3f" % target.delta_bv)
    else:
        print("Not found")
    
    # Test: RA range search
    print("\nTargets with RA between 0h and 1h:")
    targets_in_range = catalog.get_targets_in_ra_range(0, 1)
    print("Found %d targets:" % len(targets_in_range))
    for target in targets_in_range[:3]:  # Show first 3
        print("  - %s (RA=%s)" % (target.variable.name, target.variable.ra_string()))
    
    # Test: Magnitude range search
    print("\nTargets with V magnitude 4.0-5.0:")
    mag_targets = catalog.get_targets_by_magnitude_range(4.0, 5.0)
    print("Found %d targets:" % len(mag_targets))
    for target in mag_targets[:3]:  # Show first 3
        print("  - %s (V=%.2f)" % (target.variable.name, target.variable.vmag))


if __name__ == "__main__":
    # Run test if executed directly
    test_catalog()
