@echo off
REM Test script for integration time fix
REM Run this to verify the changes

echo Testing integration time fix...
echo.

REM Use the same IronPython path as Launch_SSP.bat
set IRONPYTHON_PATH=C:\Program Files\SharpCap\IronPython\ipy.exe

REM Check if IronPython exists at expected location
if not exist "%IRONPYTHON_PATH%" (
    echo ERROR: IronPython not found at: %IRONPYTHON_PATH%
    echo Please update this script with the correct path
    pause
    exit /b 1
)

REM Run the test
"%IRONPYTHON_PATH%" "%~dp0test_integration_fix.py"

echo.
pause
