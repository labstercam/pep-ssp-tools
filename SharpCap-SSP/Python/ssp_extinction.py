"""
First Order Extinction Module for SharpCap-SSP
Provides star catalog and airmass calculations for extinction observations.
Version: 0.1.0
"""

import csv
import math
import os
import sys
from datetime import datetime, timezone


class ExtinctionStar:
    """Represents a first order extinction standard star."""
    
    def __init__(self, name, ra_hours, dec_deg, v_mag, b_v, u_b):
        """
        Initialize ExtinctionStar.
        
        Args:
            name: Star designation (e.g., "HD 34968")
            ra_hours: Right Ascension in decimal hours (0-24)
            dec_deg: Declination in decimal degrees (-90 to +90)
            v_mag: V-band magnitude
            b_v: B-V color index
            u_b: U-B color index
        """
        self.name = name
        self.ra_hours = ra_hours
        self.dec_deg = dec_deg
        self.v_mag = v_mag
        self.b_v = b_v
        self.u_b = u_b
    
    @property
    def ra_deg(self):
        """Right Ascension in decimal degrees (0-360)."""
        return self.ra_hours * 15.0
    
    def __repr__(self):
        return "ExtinctionStar({0}, RA={1:.4f}h, DEC={2:.4f}deg, V={3:.2f})".format(
            self.name, self.ra_hours, self.dec_deg, self.v_mag)


class ExtinctionCatalog:
    """
    Manages the first order extinction star catalog.
    Loads stars from CSV file and provides search/filter capabilities.
    """
    
    def __init__(self):
        self.stars = []
        self._stars_by_name = {}
    
    def load_from_csv(self, filepath):
        """
        Load extinction stars from CSV file.
        
        Args:
            filepath: Path to CSV file (tab-delimited)
            
        Returns:
            Number of stars loaded
            
        Format expected:
            Star    R.A. (2000.0)    Decl (2000.0)    V    B-V    U-B
            HD 34968    5.3408    -21.2398    4.70    -0.05    -0.11
        """
        self.stars.clear()
        self._stars_by_name.clear()
        
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f, delimiter='\t')
                
                for row in reader:
                    try:
                        # Extract and uppercase star name
                        star_name = row['Star'].strip().upper()
                        
                        # Convert RA (already in decimal hours) to float
                        ra_hours = float(row['R.A. (2000.0)'])
                        
                        # Convert DEC (already in decimal degrees) to float
                        dec_deg = float(row['Decl (2000.0)'])
                        
                        # Extract magnitudes and color indices
                        v_mag = float(row['V'])
                        b_v = float(row['B-V'])
                        u_b = float(row['U-B'])
                        
                        # Create star object
                        star = ExtinctionStar(
                            name=star_name,
                            ra_hours=ra_hours,
                            dec_deg=dec_deg,
                            v_mag=v_mag,
                            b_v=b_v,
                            u_b=u_b
                        )
                        
                        self.stars.append(star)
                        self._stars_by_name[star_name] = star
                        
                    except (KeyError, ValueError) as e:
                        # Skip malformed rows
                        print(f"Warning: Skipping row due to error: {e}")
                        continue
            
            print("Loaded {0} extinction stars from {1}".format(len(self.stars), filepath))
            return len(self.stars)
            
        except IOError:
            print("Error: Catalog file not found: {0}".format(filepath))
            return 0
        except Exception as e:
            print("Error loading catalog: {0}".format(e))
            return 0
    
    def get_star(self, name):
        """
        Retrieve star by name (case-insensitive).
        
        Args:
            name: Star designation (e.g., "HD 34968" or "hd 34968")
            
        Returns:
            ExtinctionStar object or None if not found
        """
        return self._stars_by_name.get(name.strip().upper())
    
    def filter_by_magnitude(self, min_mag=0.0, max_mag=10.0):
        """
        Filter stars by V magnitude range.
        
        Args:
            min_mag: Minimum V magnitude (brightest)
            max_mag: Maximum V magnitude (faintest)
            
        Returns:
            List of stars within magnitude range
        """
        return [star for star in self.stars if min_mag <= star.v_mag <= max_mag]
    
    def filter_by_dec(self, min_dec=-90.0, max_dec=90.0):
        """
        Filter stars by declination range.
        
        Args:
            min_dec: Minimum declination (degrees)
            max_dec: Maximum declination (degrees)
            
        Returns:
            List of stars within declination range
        """
        return [star for star in self.stars if min_dec <= star.dec_deg <= max_dec]
    
    def get_all_stars(self):
        """Return all stars in catalog."""
        return self.stars[:]
    
    def __len__(self):
        """Return number of stars in catalog."""
        return len(self.stars)
    
    def __repr__(self):
        return "ExtinctionCatalog({0} stars)".format(len(self.stars))


class AirmassCalculator:
    """
    Calculate airmass and star positions using the Hardie method.
    Implements LMST calculation and Hardie's atmospheric refraction correction.
    """
    
    def __init__(self, latitude, longitude):
        """
        Initialize calculator with observer location.
        
        Args:
            latitude: Observer latitude in decimal degrees (-90 to +90, positive North)
            longitude: Observer longitude in decimal degrees (0 to 360 or -180 to +180, positive East)
        """
        self.latitude = latitude
        self.longitude = longitude if longitude >= 0 else longitude + 360.0
        
    def utc_to_jd(self, utc_time):
        """
        Convert UTC datetime to Julian Date from J2000.0 epoch.
        
        Args:
            utc_time: datetime object in UTC
            
        Returns:
            Julian Date from J2000.0 (JD - 2451545.0)
        """
        # Ensure UTC timezone
        if utc_time.tzinfo is None:
            utc_time = utc_time.replace(tzinfo=timezone.utc)
        
        # Extract date components
        year = utc_time.year
        month = utc_time.month
        day = utc_time.day
        hour = utc_time.hour
        minute = utc_time.minute
        second = utc_time.second + utc_time.microsecond / 1e6
        
        # Julian Date calculation
        a = int(year / 100)
        b = 2 - a + int(a / 4)
        c = int(365.25 * year)
        d = int(30.6001 * (month + 1))
        
        jd = b + c + d - 730550.5 + day + (hour + minute/60.0 + second/3600.0) / 24.0
        
        return jd
    
    def calculate_lmst(self, utc_time):
        """
        Calculate Local Mean Sidereal Time.
        
        Args:
            utc_time: datetime object in UTC
            
        Returns:
            LMST in decimal degrees (0-360)
        """
        jd = self.utc_to_jd(utc_time)
        jt = jd / 36525.0  # Julian century
        
        # Mean Sidereal Time at Greenwich
        mst = 280.46061837 + 360.98564736629 * jd + 0.000387933 * jt**2 - jt**3 / 38710000.0
        
        # Local Mean Sidereal Time
        lmst = (mst + self.longitude) % 360.0
        
        return lmst
    
    def calculate_airmass(self, ra_deg, dec_deg, utc_time):
        """
        Calculate airmass using Hardie equation.
        
        Args:
            ra_deg: Right Ascension in decimal degrees (0-360)
            dec_deg: Declination in decimal degrees (-90 to +90)
            utc_time: datetime object in UTC
            
        Returns:
            Airmass (X) or None if star is below horizon
        """
        # Calculate LMST
        lmst = self.calculate_lmst(utc_time)
        
        # Hour Angle in degrees
        ha = (lmst - ra_deg) % 360.0
        
        # Convert to radians
        ha_rad = math.radians(ha)
        dec_rad = math.radians(dec_deg)
        lat_rad = math.radians(self.latitude)
        
        # Calculate altitude (elevation angle)
        sin_alt = math.sin(lat_rad) * math.sin(dec_rad) + \
                  math.cos(lat_rad) * math.cos(dec_rad) * math.cos(ha_rad)
        
        # Check if star is above horizon
        if sin_alt <= 0:
            return None  # Star below horizon
        
        # Secant of zenith angle
        sec_z = 1.0 / sin_alt
        
        # Hardie equation for atmospheric refraction correction
        # X = sec(z) - 0.0018167(sec(z) - 1) - 0.002875(sec(z) - 1)^2 - 0.0008083(sec(z) - 1)^3
        airmass = sec_z - 0.0018167 * (sec_z - 1) - \
                  0.002875 * (sec_z - 1)**2 - \
                  0.0008083 * (sec_z - 1)**3
        
        return airmass
    
    def calculate_altaz(self, ra_deg, dec_deg, utc_time):
        """
        Calculate altitude and azimuth for a star.
        
        Args:
            ra_deg: Right Ascension in decimal degrees (0-360)
            dec_deg: Declination in decimal degrees (-90 to +90)
            utc_time: datetime object in UTC
            
        Returns:
            Tuple of (altitude, azimuth) in degrees, or (None, None) if below horizon
            Altitude: 0-90 degrees above horizon
            Azimuth: 0-360 degrees (0=North, 90=East, 180=South, 270=West)
        """
        # Calculate LMST
        lmst = self.calculate_lmst(utc_time)
        
        # Hour Angle in degrees
        ha = (lmst - ra_deg) % 360.0
        
        # Convert to radians
        ha_rad = math.radians(ha)
        dec_rad = math.radians(dec_deg)
        lat_rad = math.radians(self.latitude)
        
        # Calculate altitude
        sin_alt = math.sin(lat_rad) * math.sin(dec_rad) + \
                  math.cos(lat_rad) * math.cos(dec_rad) * math.cos(ha_rad)
        
        if sin_alt <= 0:
            return (None, None)  # Below horizon
        
        alt_rad = math.asin(sin_alt)
        altitude = math.degrees(alt_rad)
        
        # Calculate azimuth
        cos_az = (math.sin(dec_rad) - math.sin(lat_rad) * sin_alt) / \
                 (math.cos(lat_rad) * math.cos(alt_rad))
        
        # Clamp to [-1, 1] to avoid numerical errors
        cos_az = max(-1.0, min(1.0, cos_az))
        
        az_rad = math.acos(cos_az)
        azimuth = math.degrees(az_rad)
        
        # Correct azimuth based on hour angle
        if math.sin(ha_rad) > 0:
            azimuth = 360.0 - azimuth
        
        return (altitude, azimuth)
    
    def calculate_hour_angle(self, ra_deg, utc_time):
        """
        Calculate hour angle for a star.
        
        Args:
            ra_deg: Right Ascension in decimal degrees (0-360)
            utc_time: datetime object in UTC
            
        Returns:
            Hour angle in degrees (0-360)
        """
        lmst = self.calculate_lmst(utc_time)
        ha = (lmst - ra_deg) % 360.0
        return ha


class ObservationData:
    """Represents visibility data for an extinction star at a specific time."""
    
    def __init__(self, star, utc_time, airmass, altitude, azimuth, hour_angle, is_observable):
        """
        Initialize ObservationData.
        
        Args:
            star: ExtinctionStar object
            utc_time: datetime object in UTC
            airmass: Airmass value or None if below horizon
            altitude: Altitude in degrees above horizon or None
            azimuth: Azimuth in degrees (0=N, 90=E, 180=S, 270=W) or None
            hour_angle: Hour angle in degrees
            is_observable: True if above horizon and airmass < max_airmass
        """
        self.star = star
        self.utc_time = utc_time
        self.airmass = airmass
        self.altitude = altitude
        self.azimuth = azimuth
        self.hour_angle = hour_angle
        self.is_observable = is_observable
    
    def __repr__(self):
        if self.is_observable:
            return "{0}: X={1:.2f}, Alt={2:.1f}deg, Az={3:.1f}deg".format(
                self.star.name, self.airmass, self.altitude, self.azimuth)
        else:
            return "{0}: Below horizon or high airmass".format(self.star.name)


def calculate_star_visibility(star, calculator, utc_time, max_airmass=3.0):
    """
    Calculate complete visibility data for a star at a given time.
    
    Args:
        star: ExtinctionStar object
        calculator: AirmassCalculator configured with observer location
        utc_time: datetime object in UTC
        max_airmass: Maximum acceptable airmass (default 3.0)
        
    Returns:
        ObservationData object with complete visibility information
    """
    airmass = calculator.calculate_airmass(star.ra_deg, star.dec_deg, utc_time)
    altitude, azimuth = calculator.calculate_altaz(star.ra_deg, star.dec_deg, utc_time)
    hour_angle = calculator.calculate_hour_angle(star.ra_deg, utc_time)
    
    is_observable = airmass is not None and airmass <= max_airmass
    
    return ObservationData(
        star=star,
        utc_time=utc_time,
        airmass=airmass,
        altitude=altitude,
        azimuth=azimuth,
        hour_angle=hour_angle,
        is_observable=is_observable
    )
