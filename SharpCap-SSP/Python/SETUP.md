# SharpCap-SSP Setup Guide

Complete setup instructions for running SharpCap-SSP.

---

## Table of Contents

1. [SharpCap Setup](#sharpcap-setup) - Zero configuration
2. [Standalone IronPython Setup](#standalone-ironpython-setup) - Detailed walkthrough
3. [Troubleshooting](#troubleshooting)

---

## SharpCap Setup

### Requirements
- SharpCap Pro installed
- Windows operating system

### Installation Steps

**No additional packages needed!** SharpCap includes all required assemblies.

---

### Method 1: Automatic Startup (Recommended)

Configure SharpCap to load the SSP control automatically and add a toolbar button.

**Step 1: Copy the Python folder**

1. Copy the entire `SharpCap-SSP\Python` folder to a permanent location
2. Recommended location:
   ```
   C:\Users\YourName\Documents\SharpCap\Scripts\SharpCap-SSP\Python
   ```
3. The folder should contain:
   - `main.py`
   - `SSP.ico`
   - `ssp_*.py` files
   - All other Python modules

**Step 2: Configure SharpCap Startup Script**

1. **Open SharpCap Settings:**
   - Launch SharpCap
   - Go to **Tools → Settings** (or press `F10`)

2. **Navigate to Scripting tab:**
   - In the Settings window, click **"Scripting"** in the left sidebar

3. **Set the startup script:**
   - Find the **"Startup Script"** text field
   - Enter the full path to main.py:
     ```
     C:\Users\YourName\Documents\SharpCap\Scripts\SharpCap-SSP\Python\main.py
     ```
   - Replace `YourName` with your actual Windows username
   - **Important:** Use the full absolute path with backslashes or forward slashes

4. **Save and close:**
   - Click **OK** to save the settings
   - Close the Settings window

**Step 3: Restart SharpCap**

1. Close SharpCap completely
2. Reopen SharpCap
3. Look for the **"PEP"** button with SSP icon in the toolbar
   - The button displays the SSP photometer icon from `SSP.ico`
   - Location: Main SharpCap toolbar (top of window)
4. Click the PEP button to launch the SSP control window

**Verification:**
- The SharpCap console should show: `"PEP custom button added to SharpCap toolbar with icon"`
- You should see the PEP button in the main toolbar with the SSP icon
- Clicking it opens the SSP Photometer Control window

**Note: Running Multiple Startup Scripts**

To run both SharpCap-SSP and other scripts (e.g., occultation-manager) on startup:
1. Create a file called `startup.py` in your scripts folder
2. Add:
   ```python
   exec(open(r'C:\path\to\occultation-manager\main.py').read())
   exec(open(r'C:\path\to\SharpCap-SSP\Python\main.py').read())
   ```
3. Set the startup script to point to `startup.py`

Both toolbars buttons will appear without conflicts. The SSP script uses a unique function name (`launch_ssp_photometer()`) to avoid conflicts with other scripts.

---

### Method 2: Manual Launch (Alternative)

Run the script manually each time you need it.

**Steps:**

1. Open SharpCap
2. Go to **Tools → Scripting Console**
3. In the console, type or paste:
   ```python
   exec(open(r'C:\Users\YourName\Documents\SharpCap\Scripts\SharpCap-SSP\Python\main.py').read())
   ```
4. Press Enter

The application window will appear immediately.

**Note:** With this method, no toolbar button is added. You need to run the command each time.

---

### Using the Application

Once launched (either method):

1. **From the launcher window:**
   - Click **"Launch SSPDataq3"** to open the data acquisition interface
   - Or close the launcher and run the data acquisition directly next time

2. **Configure COM port:**
   - In the data acquisition window: **Setup → Select SSP COM Port**
   - Choose your SSP photometer's COM port

3. **Connect to photometer:**
   - **Setup → Connect to SSP**
   - Wait for connection confirmation

4. **Start collecting data:**
   - Select filter, gain, integration time
   - Enter object name
   - Click **START** to collect readings

---

### Troubleshooting

**"PEP button doesn't appear":**
- Check the SharpCap console for error messages
- Verify the path in startup script is correct
- Ensure `SSP.ico` exists in the Python folder
- Try running manually to see any error messages

**"Script path not found":**
- Verify the full path is correct
- Use raw strings: `r'C:\path\to\file'`
- Or use forward slashes: `'C:/path/to/file'`

**"Window appears behind SharpCap":**
- This is normal - the window uses `.Show()` to stay non-modal
- Click the PEP button again or find the window in the taskbar

**"SSP.ico not found" warning:**
- Button still works, just without icon
- Verify `SSP.ico` is in the same folder as `main.py`

---

## Standalone IronPython Setup

Detailed instructions for running SharpCap-SSP independently without SharpCap.

### Part 1: Install IronPython 3.4

**What is IronPython?**
IronPython is Python for .NET. Version 3.4 is compatible with Python 3.4 syntax and runs on .NET Core/5+.

**Installation:**

1. **Download IronPython 3.4:**
   - Go to: https://github.com/IronLanguages/ironpython3/releases
   - Find the latest 3.4.x release
   - Download the Windows installer: `IronPython.3.4.x.msi`
   - Example: `IronPython.3.4.1.msi`

2. **Run the installer:**
   - Double-click the `.msi` file
   - Follow the installation wizard
   - Use default installation path (usually `C:\Program Files\IronPython 3.4`)
   - The installer will add IronPython to your PATH

3. **Verify installation:**
   Open PowerShell and run:
   ```powershell
   ipy --version
   ```
   
   Expected output:
   ```
   IronPython 3.4.x (.NET 6.0.x) on .NET 6.0.x
   ```

   If command not found:
   - Restart PowerShell/Terminal
   - Or manually add to PATH: `C:\Program Files\IronPython 3.4`

---

### Part 2: Install System.IO.Ports (Serial Communication)

**Why is this needed?**
IronPython 3.4 doesn't include serial port support by default. We need to add the `System.IO.Ports` .NET assembly.

---

#### Installation Method A: PowerShell Script (Recommended)

**This is the easiest method - fully automated!**

**Option 1: Right-Click Method (Easiest)**

1. **Navigate to the Python folder:**
   - Open File Explorer
   - Go to: `C:\Users\YourName\Documents\GitHub\pep-ssp-tools\SharpCap-SSP\Python`
   - Replace `YourName` with your actual username

2. **Run the script:**
   - Find the file `install.ps1`
   - **Right-click** on `install.ps1`
   - Select **"Run with PowerShell"**

3. **Wait for completion:**
   A PowerShell window will open and you'll see:
   ```
   ============================================================
   SharpCap-SSP Setup - Installing System.IO.Ports
   ============================================================
   
   Downloading System.IO.Ports version 8.0.0...
   Download complete!
   
   Extracting package...
   Extraction complete!
   
   Looking for System.IO.Ports.dll...
   Found DLL for net8.0
   
   ============================================================
   Installation successful!
   ============================================================
   
   System.IO.Ports.dll has been copied to:
     C:\...\SharpCap-SSP\Python\System.IO.Ports.dll
   
   Press any key to continue...
   ```

4. **Press any key** to close the window

5. **Verify:**
   In the same folder, you should now see `System.IO.Ports.dll`

**Done!** Skip to [Part 3: Run the Application](#part-3-run-the-application)

---

**Option 2: Command Line Method (Alternative)**

1. **Open PowerShell:**
   - Press `Win + X`
   - Select "Windows PowerShell" or "Terminal"

2. **Navigate to the Python folder:**
   ```powershell
   cd "C:\Users\YourName\Documents\GitHub\pep-ssp-tools\SharpCap-SSP\Python"
   ```
   
   Replace `YourName` with your actual username.

3. **Run the installation script:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File install.ps1
   ```

4. **Wait for completion:**
   You should see the same success message as above.

5. **Verify:**
   Check that `System.IO.Ports.dll` exists in the Python folder:
   ```powershell
   dir System.IO.Ports.dll
   ```

**Done!** Skip to [Part 3: Run the Application](#part-3-run-the-application)

---

#### Installation Method B: Manual Download (Fallback)

**Use this if the PowerShell script doesn't work.**

1. **Download the NuGet package:**
   - Open browser: https://www.nuget.org/packages/System.IO.Ports/
   - Click the **"Download package"** button (right sidebar)
   - Save the file (e.g., `system.io.ports.8.0.0.nupkg`)

2. **Extract the DLL:**
   
   Open PowerShell in your Downloads folder:
   ```powershell
   cd $env:USERPROFILE\Downloads
   ```
   
   Rename and extract:
   ```powershell
   # Rename .nupkg to .zip
   Rename-Item system.io.ports.*.nupkg system.io.ports.zip
   
   # Extract the archive
   Expand-Archive system.io.ports.zip -DestinationPath extracted_ports
   
   # List available framework versions
   dir extracted_ports\lib
   ```
   
   You'll see folders like: `net6.0`, `net7.0`, `net8.0`, `netstandard2.0`, etc.

3. **Copy the DLL:**
   ```powershell
   # Use net6.0 or newer version
   copy extracted_ports\lib\net6.0\System.IO.Ports.dll "C:\Users\YourName\Documents\GitHub\pep-ssp-tools\SharpCap-SSP\Python\"
   ```
   
   Replace the path with your actual installation location.

4. **Verify:**
   ```powershell
   cd "C:\Users\YourName\Documents\GitHub\pep-ssp-tools\SharpCap-SSP\Python"
   dir System.IO.Ports.dll
   ```
   
   You should see the file listed.

5. **Cleanup (optional):**
   ```powershell
   cd $env:USERPROFILE\Downloads
   Remove-Item system.io.ports.zip
   Remove-Item extracted_ports -Recurse
   ```

---

### Part 3: Run the Application

**Method 1: Interactive Shell**

1. **Open IronPython:**
   ```powershell
   cd "C:\Users\YourName\Documents\GitHub\pep-ssp-tools\SharpCap-SSP\Python"
   ipy
   ```

2. **Run main.py:**
   ```python
   >>> exec(open('main.py').read())
   ```

3. **Application window appears!**
   - Check that COM ports are detected (not showing "Serial ports not available")
   - Status should show: "Available: COM1, COM3, ..." (your actual ports)

**Method 2: Command Line (Quick Launch)**

```powershell
cd "C:\Users\YourName\Documents\GitHub\pep-ssp-tools\SharpCap-SSP\Python"
ipy -c "exec(open('main.py').read())"
```

**Method 3: Create a Launch Script (Most Convenient)**

Create a file named `run.bat` in the Python folder:

```batch
@echo off
cd /d "%~dp0"
ipy -c "exec(open('main.py').read())"
pause
```

Double-click `run.bat` to launch the application!

---

## Troubleshooting

### "ipy is not recognized as a command"

**Cause:** IronPython not in PATH or not installed.

**Solutions:**
1. Restart PowerShell/Terminal after installation
2. Manually add to PATH:
   ```powershell
   $env:PATH += ";C:\Program Files\IronPython 3.4"
   ```
3. Use full path:
   ```powershell
   & "C:\Program Files\IronPython 3.4\ipy.exe"
   ```

---

### "WARNING: System.IO.Ports not available"

**Cause:** The System.IO.Ports.dll was not loaded.

**Check:**
```powershell
dir System.IO.Ports.dll
```

**If file doesn't exist:**
- Run `install.ps1` script again
- Or follow Manual Download instructions above

**If file exists but still not loading:**
- Make sure you're running `ipy` from the Python folder
- Check DLL is not blocked:
  ```powershell
  Unblock-File System.IO.Ports.dll
  ```

---

### "Serial ports not available (missing System.IO.Ports)"

**Cause:** Same as above - DLL not loaded.

**Solution:** Follow the System.IO.Ports installation steps in Part 2.

---

### PowerShell Script Fails to Download

**Cause:** Network/firewall issues or NuGet API unavailable.

**Solution:** Use Manual Download method (Method B) instead.

---

### "Could not add reference to assembly System.IO.Ports"

**Cause:** Wrong .NET version or corrupted DLL.

**Solution:**
1. Delete the existing DLL:
   ```powershell
   Remove-Item System.IO.Ports.dll
   ```
2. Re-download using install.ps1
3. Try a different framework version from the NuGet package (net6.0, net7.0, or net8.0)

---

### Application Crashes on Startup

**Check for errors:**
```python
ipy
>>> exec(open('main.py').read())
```
Look at the error message and line number.

**Common causes:**
- Missing System.IO.Ports: See solutions above
- Wrong IronPython version: Ensure 3.4.x
- File path issues: Use raw strings `r'path'` or double backslashes

---

### Can't Find COM Ports

**Cause:** No physical COM ports or USB-Serial adapters connected.

**Check:**
1. Open Device Manager (Windows)
2. Expand "Ports (COM & LPT)"
3. Verify COM ports are listed
4. If not, install USB-Serial drivers

---

## Additional Resources

- **IronPython Documentation:** https://ironpython.net/
- **System.IO.Ports API:** https://learn.microsoft.com/en-us/dotnet/api/system.io.ports
- **Project Issues:** https://github.com/labstercam/pep-ssp-tools/issues

---

## Quick Reference

### One-Time Setup Checklist

- [ ] Install IronPython 3.4
- [ ] Verify: `ipy --version`
- [ ] Run `install.ps1` or manually download System.IO.Ports.dll
- [ ] Verify: `dir System.IO.Ports.dll`
- [ ] Test run: `ipy -c "exec(open('main.py').read())"`

### Daily Use

```powershell
cd "C:\path\to\SharpCap-SSP\Python"
ipy -c "exec(open('main.py').read())"
```

Or double-click `run.bat`

**No installation needed!** SharpCap includes all required assemblies.

1. Open SharpCap
2. Go to **Tools → Scripting Console**
3. Run:
   ```python
   exec(open(r'C:\Users\AstroPC\Documents\GitHub\pep-ssp-tools\SharpCap-SSP\Python\main.py').read())
   ```

### Method 2: Standalone IronPython (Requires Setup)

You need to install `System.IO.Ports` for serial communication.

---

## Installing System.IO.Ports for IronPython 3.4

### Option A: Using .NET CLI (Recommended if you have .NET SDK)

1. Check if you have .NET SDK:
   ```powershell
   dotnet --version
   ```

2. Run the installation batch file:
   ```powershell
   .\install.bat
   ```

   Or manually:
   ```powershell
   dotnet new console -n TempProj
   cd TempProj
   dotnet add package System.IO.Ports
   ```

3. The DLL will be in: `TempProj\obj\` or `TempProj\bin\`

### Option B: Download NuGet Package Manually

1. **Download the package:**
   - Go to: https://www.nuget.org/packages/System.IO.Ports/
   - Click "Download package" button (right side)
   - Save as `System.IO.Ports.nupkg`

2. **Extract the DLL:**
   ```powershell
   # Rename to .zip
   Rename-Item System.IO.Ports.*.nupkg System.IO.Ports.zip
   
   # Extract
   Expand-Archive System.IO.Ports.zip -DestinationPath extracted
   
   # Find the DLL (look in lib/net6.0 or lib/net5.0 or lib/netstandard2.0)
   dir extracted\lib -Recurse -Filter System.IO.Ports.dll
   ```

3. **Copy DLL to Python folder:**
   ```powershell
   copy extracted\lib\net6.0\System.IO.Ports.dll .
   ```

### Option C: Reference Existing DLL

If you have .NET installed, the DLL might already exist:

```powershell
# Search for it
dir "C:\Program Files\dotnet" -Recurse -Filter System.IO.Ports.dll
```

Common locations:
- `C:\Program Files\dotnet\shared\Microsoft.NETCore.App\6.0.x\System.IO.Ports.dll`
- `C:\Program Files\dotnet\packs\Microsoft.NETCore.App.Ref\6.0.x\ref\net6.0\System.IO.Ports.dll`

---

## Using the DLL with IronPython

Once you have `System.IO.Ports.dll`, you can either:

**Option 1:** Place it in the Python folder (same location as main.py)

**Option 2:** Reference it by full path in your code:

Edit [main.py](main.py) line 32:
```python
# Replace this:
try:
    clr.AddReference('System.IO.Ports')
    SERIAL_PORTS_AVAILABLE = True

# With this:
try:
    clr.AddReferenceToFileAndPath(r'C:\full\path\to\System.IO.Ports.dll')
    SERIAL_PORTS_AVAILABLE = True
```

---

## Running the Application

```powershell
ipy
>>> exec(open('main.py').read())
```

Or with full path:
```powershell
ipy
>>> exec(open('C:\\Users\\AstroPC\\Documents\\GitHub\\pep-ssp-tools\\SharpCap-SSP\\Python\\main.py').read())
```

---

## Troubleshooting

**"pip is not recognized":**
- IronPython 3.4 doesn't include pip by default
- Use one of the manual methods above

**"Could not add reference to assembly System.IO.Ports":**
- The DLL is not in IronPython's search path
- Place System.IO.Ports.dll in the same folder as main.py
- Or use `clr.AddReferenceToFileAndPath()` with full path

**"Serial ports not available" message:**
- System.IO.Ports is not loaded
- Follow the installation steps above
- Or run from SharpCap (Method 1)

**Still having issues?**
- Use Method 1 (Run from SharpCap) - it just works!
