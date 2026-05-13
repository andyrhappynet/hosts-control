@echo off
title Instalador Hosts Control

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ========================================
    echo ERROR: Ejecutar como Administrador
    echo ========================================
    echo Haga clic derecho ^> Ejecutar como administrador
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
echo   SELECCIONE EL GRUPO DEL EQUIPO
echo ========================================
echo.
echo   1 - VENTAS (Restriccion maxima)
echo   2 - RETENCION (Restriccion moderada)
echo   3 - ADMINISTRACION (Restriccion minima)
echo   4 - CALIDAD (Restriccion media)
echo.
set /p OPCION="Opcion (1-4): "

if "%OPCION%"=="1" set GRUPO=ventas
if "%OPCION%"=="2" set GRUPO=retencion
if "%OPCION%"=="3" set GRUPO=administracion
if "%OPCION%"=="4" set GRUPO=calidad

echo %GRUPO% > "%ProgramData%\HostsSync\grupo_actual.txt"
echo [OK] Grupo asignado: %GRUPO%

schtasks /create /tn "HostsSync" /tr "C:\ProgramData\HostsSync\hosts_sync.bat" /sc onstart /ru SYSTEM /f >nul 2>&1
echo [OK] Tarea programada creada

echo.
echo Ejecutando primera sincronizacion...
echo.
echo ========================================
call "C:\ProgramData\HostsSync\hosts_sync.bat"
echo ========================================

echo.
echo ========================================
echo        INSTALACION COMPLETADA
echo ========================================
echo.
echo Grupo configurado: %GRUPO%
echo.
echo El script se ejecutara en cada inicio
echo Logs: C:\ProgramData\HostsSync\sync_log.txt
echo.
echo Para cambiar grupo manualmente:
echo Editar C:\ProgramData\HostsSync\grupo_actual.txt
echo.
pause
