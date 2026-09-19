@echo off
setlocal
title AD Toolkit

:menu
cls

echo AD Toolkit
echo ========
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
echo.
echo Administrative actions
echo ----------------------
echo 7. Unlock account
echo 8. Reset password
echo.
echo 9. Exit
echo.

set /p "option=Select an option: "

if "%option%"=="1" call :run_script "search-user.ps1"
if "%option%"=="2" call :run_script "check-account-status.ps1"
if "%option%"=="3" call :run_script "view-user-groups.ps1"
if "%option%"=="4" call :run_script "search-computer.ps1"
if "%option%"=="5" call :run_script "test-computer-connectivity.ps1"
if "%option%"=="6" call :run_script "view-computer-details.ps1"
if "%option%"=="7" call :run_script "unlock-account.ps1"
if "%option%"=="8" call :run_script "reset-password.ps1"
if "%option%"=="9" goto exit

if not "%option%"=="1" if not "%option%"=="2" if not "%option%"=="3" if not "%option%"=="4" if not "%option%"=="5" if not "%option%"=="6" if not "%option%"=="7" if not "%option%"=="8" if not "%option%"=="9" (
    echo.
    echo Invalid option.
    timeout /t 2 /nobreak >nul
)

goto menu

:run_script
cls

set "script_path=%~dp0scripts\%~1"

if not exist "%script_path%" (
    echo [ERROR] Script not found:
    echo %script_path%
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%script_path%"

echo.
echo ========================================
echo Press any key to return to the menu...
echo ========================================
pause >nul

exit /b

:exit
endlocal
exit /b