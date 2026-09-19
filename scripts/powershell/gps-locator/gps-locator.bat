@echo off
:menu
cls

set /p host=Host (^ou Q para sair^): 

if /I "%host%"=="Q" exit

echo.
echo A verificar conectividade com %host%...
ping -n 1 %host% >nul

if errorlevel 1 (
    echo.
    echo [ERRO] Host %host% indisponivel ou sem resposta ao ping.
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
echo Prima uma tecla para procurar outro host...
echo =====================================
pause >nul

goto menu