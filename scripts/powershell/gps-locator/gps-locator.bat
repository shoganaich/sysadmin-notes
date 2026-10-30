@echo off
:menu
cls

set /p host=Host (or Q to quit): 

if /I "%host%"=="Q" exit

echo.
echo Verifying connectivity with %host%...
ping -n 1 %host% >nul

if errorlevel 1 (
    echo.
    echo [ERROR] Host %host% unavailable or not responding to ping.
    echo.
    timeout /t 3 /nobreak
    goto menu
)

echo.
echo [OK] Host online.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0gps-locator.ps1" "%host%"

echo.
echo =====================================
echo Press any key to search for another host...
echo =====================================
pause >nul

goto menu