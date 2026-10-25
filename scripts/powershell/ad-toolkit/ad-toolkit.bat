@echo off
setlocal EnableExtensions
title AD Toolkit

:menu
cls

echo AD Toolkit
echo ==========
echo.
echo User tools
echo ----------
echo 1. Search user
echo 2. Check account status
echo 3. View group memberships
echo.
echo Computer tools
echo --------------
echo 4. Search computer
echo 5. Test computer connectivity
echo 6. View computer details
echo 7. Check LAPS information
echo.
echo Network / DNS-DHCP
echo ------------------
echo 8. Check DNS and DHCP records
echo 9. Repair DNS registration    (planned)
echo 10. Remove stale DNS records  (planned)
echo 11. Renew DHCP lease remotely (planned)
echo.
echo Administrative actions
echo ----------------------
echo 12. Unlock account
echo 13. Reset password
echo.
echo 14. Exit
echo.

set "option="
set "script_name="
set /p "option=Select an option: "

if "%option%"=="1" set "script_name=search-user.ps1"
if "%option%"=="2" set "script_name=check-account-status.ps1"
if "%option%"=="3" set "script_name=view-user-groups.ps1"

if "%option%"=="4" set "script_name=search-computer.ps1"
if "%option%"=="5" set "script_name=test-computer-connectivity.ps1"
if "%option%"=="6" set "script_name=view-computer-details.ps1"
if "%option%"=="7" set "script_name=check-laps-information.ps1"

if "%option%"=="8" set "script_name=check-dns-dhcp.ps1"
if "%option%"=="9" set "script_name=repair-dns-registration.ps1"
if "%option%"=="10" set "script_name=remove-stale-dns-records.ps1"
if "%option%"=="11" set "script_name=renew-dhcp-lease.ps1"

if "%option%"=="12" set "script_name=unlock-account.ps1"
if "%option%"=="13" set "script_name=reset-password.ps1"

if "%option%"=="14" goto exit_tool

rem Use goto instead of call so each menu selection does not nest
rem another batch context.
if defined script_name goto run_script

echo.
echo [ERROR] Invalid option.
timeout /t 2 /nobreak >nul
goto menu


:run_script
cls

set "script_path=%~dp0scripts\%script_name%"

if not exist "%script_path%" (
    echo [INFO] This tool is not available yet:
    echo.
    echo %script_path%
    echo.
    goto script_finished
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%script_path%"

if errorlevel 1 (
    echo.
    echo [WARNING] The script completed with an error.
)

:script_finished
echo.
echo ========================================
echo Press any key to return to the menu...
echo ========================================
pause >nul

goto menu


:exit_tool
cls

echo AD Toolkit
echo ==========
echo.
echo Closing AD Toolkit...

timeout /t 1 /nobreak >nul

endlocal
exit /b
