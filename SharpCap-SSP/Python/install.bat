@echo off
REM SharpCap-SSP Installation Script for IronPython 3.4
REM This script installs the required System.IO.Ports package

echo ============================================================
echo SharpCap-SSP Setup for IronPython 3.4
echo ============================================================
echo.
echo This script will download System.IO.Ports NuGet package
echo and extract it for use with IronPython.
echo.
pause
echo.

REM Check if dotnet CLI is available
where dotnet >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Found .NET CLI - using dotnet to install package...
    echo.
    
    REM Create temp directory
    if not exist "temp_nuget" mkdir temp_nuget
    cd temp_nuget
    
    REM Create a temporary project to install the package
    echo Creating temporary project...
    dotnet new console -n TempProj >nul 2>&1
    cd TempProj
    
    echo Installing System.IO.Ports...
    dotnet add package System.IO.Ports
    
    if %ERRORLEVEL% EQU 0 (
        echo.
        echo ============================================================
        echo Installation successful!
        echo ============================================================
        echo.
        echo DLL location:
        dir /s /b System.IO.Ports.dll 2>nul
        echo.
        cd ..\..\n    ) else (
        echo Installation failed with dotnet.
        cd ..\..
    )
) else (
    echo .NET CLI not found.
    echo.
    echo ============================================================
    echo MANUAL INSTALLATION REQUIRED
    echo ============================================================
    echo.
    echo Option 1: Download NuGet Package ^(Recommended^)
    echo   1. Go to: https://www.nuget.org/packages/System.IO.Ports
    echo   2. Click "Download package"
    echo   3. Rename .nupkg to .zip and extract
    echo   4. Copy System.IO.Ports.dll to this folder
    echo.
    echo Option 2: Install .NET SDK
    echo   1. Download from: https://dotnet.microsoft.com/download
    echo   2. Run this script again
    echo.
    echo Option 3: Run from SharpCap
    echo   - SharpCap includes all required assemblies
    echo   - See SETUP.md for instructions
    echo.
)

echo.
echo See SETUP.md for more installation options.
echo.
pause
