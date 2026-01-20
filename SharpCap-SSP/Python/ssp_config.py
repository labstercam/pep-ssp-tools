"""
SSP Configuration Management
=============================

Manages configuration settings for SharpCap-SSP.
Supports both JSON (master) and dparms.txt (backward compatibility) formats.

Author: pep-ssp-tools project
Version: 0.1.2
"""

import clr
clr.AddReference('System')
from System.IO import File, Path, Directory
from System.Reflection import Assembly
import json
import sys


class SSPConfig:
    """Configuration manager for SSP settings."""
    
    # Default configuration
    DEFAULT_CONFIG = {
        'com_port': 0,
        'filters': ['U', 'B', 'V', 'R', 'I', 'Dark'],  # Legacy - kept for backward compatibility
        'filter_bars': [
            ['U', 'B', 'V', 'R', 'I', 'Dark'],  # Bar 1
            ['u', 'g', 'r', 'i', 'z', 'Dark'],  # Bar 2 (Sloan filters)
            ['f13', 'f14', 'f15', 'f16', 'f17', 'f18']  # Bar 3
        ],
        'active_filter_bar': 1,  # 1, 2, or 3
        'auto_manual': 'M',  # 'A' = auto 6-position slider, 'M' = manual 2-position slider
        'night_flag': 0,
        'telescope_name': 'Enter Telescope',
        'observer_name': 'Enter Observer',
        'observer_latitude': 0.0,   # Decimal degrees, positive North, -90 to +90
        'observer_longitude': 0.0,  # Decimal degrees, positive East, -180 to +180
        'observer_elevation': 0.0,  # Meters above sea level
        'observer_city': '',        # City/town name (optional)
        'last_filter_index': 2,  # V filter (0-indexed)
        'last_gain_index': 0,
        'last_integ_index': 0,
        'last_interval_index': 0,
        'last_mode_index': 1,  # slow mode
        'last_data_directory': ''
    }
    
    def __init__(self, config_dir=None):
        """Initialize configuration manager."""
        if config_dir is None:
            # Use Documents/SharpCap/SSP directory for config files
            try:
                import System
                docs_folder = System.Environment.GetFolderPath(System.Environment.SpecialFolder.MyDocuments)
                config_dir = Path.Combine(docs_folder, 'SharpCap', 'SSP')
            except:
                # Fallback to temp directory
                config_dir = Path.GetTempPath()
        
        # Ensure directory exists
        if not Directory.Exists(config_dir):
            try:
                Directory.CreateDirectory(config_dir)
            except:
                # If can't create, use temp
                config_dir = Path.GetTempPath()
        
        self.config_dir = config_dir
        self.json_path = Path.Combine(config_dir, 'ssp_config.json')
        self.dparms_path = Path.Combine(config_dir, 'dparms.txt')
        
        self.config = self.DEFAULT_CONFIG.copy()
        self.load()
    
    def load(self):
        """Load configuration from JSON file."""
        try:
            if File.Exists(self.json_path):
                with open(self.json_path, 'r') as f:
                    loaded = json.load(f)
                    # Merge with defaults to handle new settings
                    self.config.update(loaded)
                    # Ensure filter_bars has proper structure
                    self._validate_filter_bars()
                print("Configuration loaded from: " + self.json_path)
            else:
                print("No configuration file found, using defaults")
                self.save()  # Create default config file
        except Exception as e:
            print("Error loading configuration: " + str(e))
            print("Using default configuration")
    
    def _validate_filter_bars(self):
        """Ensure filter_bars has proper structure (3 bars x 6 positions)."""
        filter_bars = self.config.get('filter_bars', [])
        
        # Ensure we have exactly 3 bars
        while len(filter_bars) < 3:
            bar_num = len(filter_bars) + 1
            filter_bars.append(['f' + str((bar_num-1)*6 + i) for i in range(1, 7)])
        
        # Ensure each bar has exactly 6 positions
        for i in range(3):
            if len(filter_bars[i]) < 6:
                # Pad with default names
                while len(filter_bars[i]) < 6:
                    pos = len(filter_bars[i]) + 1
                    filter_bars[i].append('f' + str(i*6 + pos))
            elif len(filter_bars[i]) > 6:
                # Truncate to 6
                filter_bars[i] = filter_bars[i][:6]
        
        self.config['filter_bars'] = filter_bars
    
    def save(self):
        """Save configuration to both JSON and dparms.txt."""
        try:
            # Save JSON (master)
            with open(self.json_path, 'w') as f:
                json.dump(self.config, f, indent=2)
            print("Configuration saved to: " + self.json_path)
            
            # Save dparms.txt (backward compatibility)
            self._save_dparms()
            
        except Exception as e:
            print("Error saving configuration: " + str(e))
    
    def _save_dparms(self):
        """Save configuration in dparms.txt format for SSPDataq compatibility."""
        try:
            lines = []
            lines.append(str(self.config['com_port']))
            lines.append('0')  # TimeZone - always UTC (0) for SharpCap-SSP
            lines.append(self.config.get('auto_manual', 'M'))  # AutoManual mode
            
            # Filter names - all 18 positions (3 bars × 6 positions)
            filter_bars = self.config.get('filter_bars', [
                ['U', 'B', 'V', 'R', 'I', 'Dark'],
                ['u', 'g', 'r', 'i', 'z', 'Y'],
                ['f13', 'f14', 'f15', 'f16', 'f17', 'f18']
            ])
            
            # Write all 18 filter positions
            for bar_index in range(3):
                if bar_index < len(filter_bars):
                    bar = filter_bars[bar_index]
                    for pos_index in range(6):
                        if pos_index < len(bar):
                            lines.append(bar[pos_index])
                        else:
                            lines.append('f' + str(bar_index * 6 + pos_index + 1))
                else:
                    # Default names if bar doesn't exist
                    for pos_index in range(6):
                        lines.append('f' + str(bar_index * 6 + pos_index + 1))
            
            lines.append(str(self.config.get('active_filter_bar', 1)))  # FilterBar (1, 2, or 3)
            lines.append(str(self.config['night_flag']))
            lines.append('0')  # AutoMirrorFlag = 0 (not implemented)
            lines.append('0')  # TelescopeFlag = 0 (not implemented)
            lines.append('0')  # TelescopeCOM = 0
            lines.append('0')  # TelescopeType = 0
            lines.append(self.config['telescope_name'])
            lines.append(self.config['observer_name'])
            lines.append('1')  # FilterSystem = 1 (Johnson/Cousins)
            
            with open(self.dparms_path, 'w') as f:
                f.write('\n'.join(lines) + '\n')
            
            print("dparms.txt saved for backward compatibility")
            
        except Exception as e:
            print("Error saving dparms.txt: " + str(e))
    
    def get(self, key, default=None):
        """Get configuration value."""
        return self.config.get(key, default)
    
    def set(self, key, value):
        """Set configuration value."""
        self.config[key] = value
    
    def get_all(self):
        """Get entire configuration dictionary."""
        return self.config.copy()
