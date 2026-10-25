@echo off
setlocal

rem Launcher for the Service Desk Toolkit.
rem Starts one PowerShell session for the whole menu, so the execution policy
rem bypass is applied once and the Active Directory module is loaded once.

title Service Desk Toolkit

set "menu_script=%~dp0servicedesk-toolkit.ps1"

if not exist "%menu_script%" (
    echo [ERROR] Menu script not found:
    echo.
    echo %menu_script%
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%menu_script%"

if errorlevel 1 (
    echo.
    echo [ERROR] The Service Desk Toolkit closed with an error.
    pause
)

endlocal
exit /b
