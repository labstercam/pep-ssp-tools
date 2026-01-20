"""
SSP Location Utilities
======================

Utilities for looking up location names and elevation from coordinates.
Uses free online services (Nominatim and Open-Elevation APIs).

Author: pep-ssp-tools project
Version: 0.1.0
"""

import clr
clr.AddReference('System')
import System
from System.Net import WebRequest, WebException
from System.IO import StreamReader
from System.Text import Encoding
import json
import time


def get_location_name_from_coordinates(latitude, longitude, timeout=10):
    """
    Look up nearest city/town for given coordinates using Nominatim (OpenStreetMap).
    Returns formatted location string, or None if lookup fails.
    
    For US: "City, ST" (e.g., "Atlanta, GA")
    For others: "City, COUNTRY" (e.g., "Auckland, NZ")
    
    Args:
        latitude: Latitude in decimal degrees
        longitude: Longitude in decimal degrees
        timeout: Request timeout in seconds
    
    Returns:
        str: Formatted location string, or None if lookup fails
    """
    try:
        # Nominatim API - free OpenStreetMap geocoding service
        # Important: Must include User-Agent header as per usage policy
        url = "https://nominatim.openstreetmap.org/reverse?format=json&lat={0}&lon={1}&zoom=10&addressdetails=1".format(
            latitude, longitude)
        
        # Create web request
        request = WebRequest.Create(url)
        request.Timeout = timeout * 1000  # Convert to milliseconds
        request.UserAgent = 'SharpCap-SSP/0.1 (Astronomical photometry tool)'
        
        # Nominatim requires 1 second between requests (rate limit)
        time.sleep(1)
        
        # Get response
        response = request.GetResponse()
        stream = response.GetResponseStream()
        reader = StreamReader(stream, Encoding.UTF8)
        json_text = reader.ReadToEnd()
        reader.Close()
        stream.Close()
        response.Close()
        
        # Parse JSON
        data = json.loads(json_text)
        
        if 'address' in data:
            address = data['address']
            country_code = address.get('country_code', '').upper()
            
            # Try to get city/town name with preference for main city over suburbs/districts
            # For conurbations, prefer higher-level administrative areas over local districts
            city = None
            
            # Priority 1: Check county/state/region first for major metropolitan areas
            # This handles cases like "Auckland Region" which should become "Auckland"
            for field in ['state', 'county', 'region', 'state_district']:
                if field in address and address[field]:
                    location_name = address[field]
                    # Extract main city name by removing common suffixes
                    for suffix in [' Region', ' County', ' District', ' Metropolitan Area', ' Council']:
                        if location_name.endswith(suffix):
                            location_name = location_name[:-len(suffix)].strip()
                            break
                    # Use this if it's not a generic administrative term
                    if location_name and location_name.lower() not in ['region', 'county', 'district', 'state']:
                        city = location_name
                        break
            
            # Priority 2: Actual 'city' field (only if not found in county/region)
            if not city and 'city' in address and address['city']:
                city = address['city']
            
            # Priority 3: Town
            if not city and 'town' in address and address['town']:
                city = address['town']
            
            # Priority 4: Village/hamlet/municipality (avoid suburb/city_district as they're too local)
            if not city:
                city = (address.get('village') or 
                       address.get('hamlet') or
                       address.get('municipality'))
            
            if not city:
                print("No city/town found in geocoding result")
                return None
            
            # Format based on country
            if country_code == 'US':
                # US format: City, ST
                state_code = address.get('state_code', address.get('state', ''))
                if state_code:
                    # Extract just the state abbreviation if it's in "US-XX" format
                    if '-' in state_code:
                        state_code = state_code.split('-')[1]
                    location_str = "{0}, {1}".format(city, state_code)
                else:
                    location_str = "{0}, USA".format(city)
            else:
                # International format: City, COUNTRY_CODE
                location_str = "{0}, {1}".format(city, country_code)
            
            print("Location lookup successful: {0}".format(location_str))
            return location_str
        
        print("No address data returned from geocoding API")
        return None
        
    except WebException as e:
        print("Network error during location lookup: {0}".format(e.Message))
        return None
    except Exception as e:
        print("Error looking up location: {0}".format(e))
        return None


def get_elevation_from_coordinates(latitude, longitude, timeout=10):
    """
    Look up elevation for given coordinates using Open-Elevation API.
    Returns elevation in meters relative to WGS84 datum, or None if lookup fails.
    
    Args:
        latitude: Latitude in decimal degrees
        longitude: Longitude in decimal degrees
        timeout: Request timeout in seconds
    
    Returns:
        float: Elevation in meters, or None if lookup fails
    """
    try:
        # Open-Elevation API - free, no API key required
        url = "https://api.open-elevation.com/api/v1/lookup?locations={0},{1}".format(latitude, longitude)
        
        # Create web request
        request = WebRequest.Create(url)
        request.Timeout = timeout * 1000  # Convert to milliseconds
        request.UserAgent = 'SharpCap-SSP/0.1 (Astronomical photometry tool)'
        
        # Get response
        response = request.GetResponse()
        stream = response.GetResponseStream()
        reader = StreamReader(stream, Encoding.UTF8)
        json_text = reader.ReadToEnd()
        reader.Close()
        stream.Close()
        response.Close()
        
        # Parse JSON
        data = json.loads(json_text)
        
        if 'results' in data and len(data['results']) > 0:
            elevation = data['results'][0].get('elevation')
            if elevation is not None:
                print("Elevation lookup successful: {0} meters at {1}, {2}".format(elevation, latitude, longitude))
                return float(elevation)
        
        print("No elevation data returned from API")
        return None
        
    except WebException as e:
        print("Network error during elevation lookup: {0}".format(e.Message))
        return None
    except Exception as e:
        print("Error looking up elevation: {0}".format(e))
        return None
