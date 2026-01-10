"""
SSP Configuration Management
=============================

Manages configuration settings for SharpCap-SSP.
Supports both JSON (master) and dparms.txt (backward compatibility) formats.

Author: pep-ssp-tools project
Version: 0.1.0
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
        'filters': ['U', 'B', 'V', 'R', 'I', 'Dark'],
        'night_flag': 0,
        'telescope_name': 'Enter Telescope',
        'observer_name': 'Enter Observer',
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
                print("Configuration loaded from: " + self.json_path)
            else:
                print("No configuration file found, using defaults")
                self.save()  # Create default config file
        except Exception as e:
            print("Error loading configuration: " + str(e))
            print("Using default configuration")
    
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
            lines.append('M')  # AutoManual - always manual for now
            
            # Filter names (6 positions for now, expandable later)
            for i in range(6):
                if i < len(self.config['filters']):
                    lines.append(self.config['filters'][i])
                else:
                    lines.append('f' + str(i+1))
            
            # Placeholder filter positions 7-18 (for 3 bars of 6)
            for i in range(12):
                lines.append('f' + str(i+7))
            
            lines.append('1')  # FilterBar = 1
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
