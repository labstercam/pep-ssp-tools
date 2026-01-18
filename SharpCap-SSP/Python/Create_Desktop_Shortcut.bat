@echo off
REM ============================================================
REM Create Desktop Shortcut for SharpCap-SSP
REM ============================================================

setlocal

REM Get the directory where this batch file is located
set SCRIPT_DIR=%~dp0

echo.
echo ============================================================
echo Create Desktop Shortcut for SharpCap-SSP
echo ============================================================
echo.

REM Create a VBScript to create the shortcut
set VBS_SCRIPT=%TEMP%\create_ssp_shortcut.vbs

REM Write VBScript content
(
echo Set oWS = WScript.CreateObject^("WScript.Shell"^)
echo sLinkFile = oWS.SpecialFolders^("Desktop"^) ^& "\SSP Photometer.lnk"
echo Set oLink = oWS.CreateShortcut^(sLinkFile^)
echo oLink.TargetPath = "%SCRIPT_DIR%Launch_SSP.bat"
echo oLink.WorkingDirectory = "%SCRIPT_DIR%"
echo oLink.IconLocation = "%SCRIPT_DIR%SSP.ico"
echo oLink.Description = "SSP Photometer Control - Standalone"
echo oLink.Save
) > "%VBS_SCRIPT%"

REM Execute the VBScript
cscript //nologo "%VBS_SCRIPT%"

REM Check if successful
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ============================================================
    echo Success!
    echo ============================================================
    echo.
    echo Desktop shortcut created: "SSP Photometer.lnk"
    echo.
    echo You can now:
    echo   - Double-click the desktop icon to launch SSP
    echo   - Drag the icon to your taskbar for quick access
    echo   - Move it to your Start menu folder
    echo.
    echo The shortcut uses the SSP icon and launches the application
    echo in standalone mode without needing to open IronPython console.
    echo.
) else (
    echo.
    echo ============================================================
    echo Error creating shortcut
    echo ============================================================
    echo.
    echo Please create a shortcut manually:
    echo   1. Right-click on Launch_SSP.bat
    echo   2. Select "Create shortcut"
    echo   3. Right-click the shortcut and select "Properties"
    echo   4. Click "Change Icon" and browse to SSP.ico
    echo   5. Move the shortcut to your desktop
    echo.
)

REM Cleanup
del "%VBS_SCRIPT%" >nul 2>&1

echo Press any key to close...
pause >nul
