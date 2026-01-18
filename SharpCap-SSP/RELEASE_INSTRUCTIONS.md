# Release Package Instructions

## Creating a GitHub Release for SharpCap-SSP

### Files to Include in Release ZIP

Package the following files from `SharpCap-SSP/Python/`:

**Python Source Files:**
- main.py
- ssp_dataaq.py
- ssp_comm.py
- ssp_config.py
- ssp_dialogs.py
- night_mode.py

**Installation & Launch Scripts:**
- install.ps1
- Launch_SSP.bat
- Create_Desktop_Shortcut.bat

**Documentation:**
- QUICK_INSTALL.txt
- SETUP.md
- README.md (copy from parent directory)

**Assets:**
- SSP.ico
- requirements.txt

### ZIP Structure

```
SharpCap-SSP/
├── QUICK_INSTALL.txt          <-- Read this first!
├── README.md
├── SETUP.md
├── main.py
├── ssp_dataaq.py
├── ssp_comm.py
├── ssp_config.py
├── ssp_dialogs.py
├── night_mode.py
├── SSP.ico
├── install.ps1
├── Launch_SSP.bat
├── Create_Desktop_Shortcut.bat
└── requirements.txt
```

### Creating the Release on GitHub

1. **Navigate to repository:**
   - Go to: https://github.com/labstercam/pep-ssp-tools

2. **Create new release:**
   - Click "Releases" (right sidebar)
   - Click "Create a new release"

3. **Set version tag:**
   - Tag: `v0.1.0`
   - Target: `main` branch
   - Release title: `SharpCap-SSP v0.1.0 - Initial Release`

4. **Write release notes:**
   ```markdown
   # SharpCap-SSP v0.1.0 - Initial Release
   
   Control software for Optec SSP-3a/SSP-5a photometers with SharpCap integration.
   
   ## Features
   - ✅ SharpCap toolbar integration with custom PEP button
   - ✅ Standalone operation with IronPython 3.4
   - ✅ Serial communication (19200,N,8,1)
   - ✅ Slow mode and Trial mode data collection
   - ✅ Export data in SSPDataq-compatible .raw format
   - ✅ Desktop shortcut with icon
   - ✅ Night mode (red screen)
   
   ## Installation
   
   **Download:** [SharpCap-SSP-v0.1.0.zip](link-will-be-auto-generated)
   
   ### Quick Start:
   1. Download and extract the ZIP file
   2. Read `QUICK_INSTALL.txt` for detailed instructions
   3. Choose SharpCap integration OR standalone mode
   
   See [SETUP.md](https://github.com/labstercam/pep-ssp-tools/blob/main/SharpCap-SSP/Python/SETUP.md) for complete documentation.
   
   ## Requirements
   
   **For SharpCap Integration:**
   - SharpCap Pro 4.1+
   
   **For Standalone Mode:**
   - IronPython 3.4+
   - Windows 10/11
   
   ## What's New in v0.1.0
   - Initial public release
   - Full data acquisition functionality
   - SharpCap toolbar integration
   - One-click launcher for standalone mode
   
   ## Known Limitations
   - Fast mode not yet implemented
   - Very fast mode not yet implemented
   - Automatic filter bar control not implemented
   
   ## Documentation
   - [README](https://github.com/labstercam/pep-ssp-tools/blob/main/SharpCap-SSP/README.md)
   - [Setup Guide](https://github.com/labstercam/pep-ssp-tools/blob/main/SharpCap-SSP/Python/SETUP.md)
   - [Quick Start](https://github.com/labstercam/pep-ssp-tools/blob/main/SharpCap-SSP/QUICK_START.md)
   ```

5. **Upload ZIP file:**
   - Create `SharpCap-SSP-v0.1.0.zip` with structure above
   - Drag and drop to "Attach binaries" section

6. **Set as latest release:**
   - Check "Set as the latest release"
   - Click "Publish release"

### After Publishing

The release will be available at:
- Direct link: `https://github.com/labstercam/pep-ssp-tools/releases/latest`
- Download link: `https://github.com/labstercam/pep-ssp-tools/releases/download/v0.1.0/SharpCap-SSP-v0.1.0.zip`

Update README.md with this download link.
