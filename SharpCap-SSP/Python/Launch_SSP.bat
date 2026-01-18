@echo off
REM ============================================================
REM SharpCap-SSP Standalone Launcher
REM ============================================================
REM Automatically finds IronPython and launches the SSP application
REM Works even if IronPython is not in PATH

setlocal enabledelayedexpansion

REM Get the directory where this batch file is located
set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"

echo.
echo ============================================================
echo SharpCap-SSP Photometer Control
echo ============================================================
echo.

REM Try to find IronPython executable
set IPY_EXE=

REM Method 1: Check if ipy is in PATH
where ipy.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set IPY_EXE=ipy.exe
    echo Found IronPython in PATH
    goto :run_app
)

REM Method 2: Check common installation directories
echo Searching for IronPython installation...

set INSTALL_PATHS[0]=C:\Program Files\IronPython 3.4\ipy.exe
set INSTALL_PATHS[1]=C:\Program Files (x86)\IronPython 3.4\ipy.exe
set INSTALL_PATHS[2]=C:\Program Files\IronPython 3.4.1\ipy.exe
set INSTALL_PATHS[3]=C:\Program Files (x86)\IronPython 3.4.1\ipy.exe
set INSTALL_PATHS[4]=%LOCALAPPDATA%\Programs\IronPython 3.4\ipy.exe
set INSTALL_PATHS[5]=%USERPROFILE%\AppData\Local\Programs\IronPython\ipy.exe

for /L %%i in (0,1,5) do (
    if exist "!INSTALL_PATHS[%%i]!" (
        set IPY_EXE=!INSTALL_PATHS[%%i]!
        echo Found IronPython at: !IPY_EXE!
        goto :run_app
    )
)

REM IronPython not found
echo.
echo ============================================================
echo ERROR: IronPython not found
echo ============================================================
echo.
echo IronPython 3.4 is required to run SharpCap-SSP in standalone mode.
echo.
echo Please install IronPython 3.4:
echo   1. Download from: https://github.com/IronLanguages/ironpython3/releases
echo   2. Install IronPython.3.4.x.msi
echo   3. Run this launcher again
echo.
echo Or use SharpCap integration (no IronPython needed):
echo   See SETUP.md for instructions
echo.
pause
exit /b 1

:run_app
REM Check if System.IO.Ports.dll exists
if not exist "System.IO.Ports.dll" (
    echo.
    echo WARNING: System.IO.Ports.dll not found
    echo Serial port functionality will not work.
    echo.
    echo To install, run: install.ps1
    echo Then restart this launcher.
    echo.
    echo Press any key to continue anyway, or Ctrl+C to cancel...
    pause >nul
)

REM Launch the application
echo.
echo Starting SSP Photometer Control...
echo.

REM Change to script directory and run
cd /d "%SCRIPT_DIR%"
"%IPY_EXE%" main.py

REM Check if there was an error
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ============================================================
    echo Application closed with error code: %ERRORLEVEL%
    echo ============================================================
    echo.
    pause
    exit /b %ERRORLEVEL%
)

REM Success - exit silently
exit /b 0
