@echo off
title Instalador Hosts Control

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ========================================
    echo ERROR: Ejecutar como Administrador
    echo ========================================
    pause
    exit /b 1
)

color 0A
echo ========================================
echo   HOSTS CONTROL - INSTALADOR
echo ========================================
echo.

if not exist "C:\ProgramData\HostsSync" mkdir "C:\ProgramData\HostsSync"

copy "%~dp0hosts_sync.bat" "C:\ProgramData\HostsSync\" /y >nul
echo [OK] Script copiado

echo.
echo ========================================
echo   SELECCIONE EL GRUPO
echo ========================================
echo.
echo   1 - VENTAS
echo   2 - RETENCION
echo   3 - ADMINISTRACION
echo   4 - CALIDAD
echo.
set /p OPCION="Opcion (1-4): "

if "%OPCION%"=="1" set GRUPO=ventas
if "%OPCION%"=="2" set GRUPO=retencion
if "%OPCION%"=="3" set GRUPO=administracion
if "%OPCION%"=="4" set GRUPO=calidad

set GRUPO=%GRUPO: =%
echo %GRUPO%> "C:\ProgramData\HostsSync\grupo_actual.txt"
echo [OK] Grupo: %GRUPO%

REM Tarea al iniciar el equipo
schtasks /create /tn "HostsSync" /tr "C:\ProgramData\HostsSync\hosts_sync.bat" /sc onstart /ru SYSTEM /f >nul 2>&1
echo [OK] Tarea programada (al iniciar)

REM Tarea cada hora (para actualizaciones automaticas)
schtasks /create /tn "HostsSyncHourly" /tr "C:\ProgramData\HostsSync\hosts_sync.bat" /sc hourly /ru SYSTEM /f >nul 2>&1
echo [OK] Tarea programada (cada hora)

echo.
echo Ejecutando primera sincronizacion...
call "C:\ProgramData\HostsSync\hosts_sync.bat"

echo.
echo ========================================
echo        INSTALACION COMPLETADA
echo ========================================
echo.
echo El script se ejecutara:
echo - Al iniciar el equipo
echo - Cada hora automaticamente
echo.
echo Logs: C:\ProgramData\HostsSync\sync_log.txt
echo.
pause
