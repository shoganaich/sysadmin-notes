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
echo 9. Repair DNS registration
echo 10. Remove stale DNS records
echo 11. Renew DHCP lease remotely
echo.
echo Administrative actions
echo ----------------------
echo 12. Unlock account
echo 13. Reset password
echo.
echo 14. Exit
echo.

set "option="
set /p "option=Select an option: "

if "%option%"=="1" call :run_script "search-user.ps1"
if "%option%"=="2" call :run_script "check-account-status.ps1"
if "%option%"=="3" call :run_script "view-user-groups.ps1"

if "%option%"=="4" call :run_script "search-computer.ps1"
if "%option%"=="5" call :run_script "test-computer-connectivity.ps1"
if "%option%"=="6" call :run_script "view-computer-details.ps1"
if "%option%"=="7" call :run_script "check-laps-information.ps1"

if "%option%"=="8" call :run_script "check-dns-dhcp.ps1"
if "%option%"=="9" call :run_script "repair-dns-registration.ps1"
if "%option%"=="10" call :run_script "remove-stale-dns-records.ps1"
if "%option%"=="11" call :run_script "renew-dhcp-lease.ps1"

if "%option%"=="12" call :run_script "unlock-account.ps1"
if "%option%"=="13" call :run_script "reset-password.ps1"

if "%option%"=="14" goto exit_tool

echo.
echo [ERROR] Invalid option.
timeout /t 2 /nobreak >nul
goto menu


:run_script
cls

set "script_name=%~1"
set "script_path=%~dp0scripts\%script_name%"

if not exist "%script_path%" (
    echo [ERROR] Script not found:
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