@echo off
setlocal enabledelayedexpansion
title Hosts Sync

set "GITHUB_USER=andyrhappynet"
set "REPO_NAME=hosts-control"
set "BRANCH=main"
set "BASE_URL=https://raw.githubusercontent.com/%GITHUB_USER%/%REPO_NAME%/%BRANCH%/grupos"
set "LOG_FILE=%ProgramData%\HostsSync\sync_log.txt"

if not exist "%ProgramData%\HostsSync" mkdir "%ProgramData%\HostsSync"

call :WriteLog "=== INICIO SINCRONIZACION ==="
call :WriteLog "Fecha: %date% %time%"

set "GRUPO_FILE=%ProgramData%\HostsSync\grupo_actual.txt"
if exist "%GRUPO_FILE%" (
    set /p GRUPO=<"%GRUPO_FILE%"
    REM Limpiar espacios y caracteres ocultos
    set GRUPO=!GRUPO: =!
    set GRUPO=!GRUPO:    =!
    call :WriteLog "Grupo activo: [%GRUPO%]"
) else (
    set GRUPO=ventas
    echo ventas> "%GRUPO_FILE%"
    call :WriteLog "Grupo por defecto: VENTAS"
)

REM Validar que GRUPO no esté vacío
if "!GRUPO!"=="" (
    call :WriteLog "ERROR: Grupo vacio, usando ventas por defecto"
    set GRUPO=ventas
)

set "HOSTS_URL=%BASE_URL%/%GRUPO%.txt"
set "HOSTS_TEMP=%TEMP%\hosts_%GRUPO%.tmp"

call :WriteLog "Descargando: %HOSTS_URL%"

bitsadmin /transfer "HostsDownload" /download /priority normal "%HOSTS_URL%" "%HOSTS_TEMP%" >nul 2>&1

if not exist "%HOSTS_TEMP%" (
    powershell -Command "Invoke-WebRequest -Uri '%HOSTS_URL%' -OutFile '%HOSTS_TEMP%' -UseBasicParsing" >nul 2>&1
)

if not exist "%HOSTS_TEMP%" (
    call :WriteLog "ERROR: Descarga fallida"
    goto :error
)

call :WriteLog "OK: Archivo descargado"

set "HOSTS_FILE=C:\Windows\System32\drivers\etc\hosts"
set "HOSTS_BACKUP=%HOSTS_FILE%.backup"

attrib -r "%HOSTS_FILE%" >nul 2>&1
copy "%HOSTS_FILE%" "%HOSTS_BACKUP%" >nul 2>&1

REM Eliminar bloqueos anteriores
findstr /v /c:"# BLOQUEOS HOSTS CONTROL" "%HOSTS_BACKUP%" > "%HOSTS_FILE%.nuevo" 2>nul

REM Agregar nuevos bloqueos
echo. >> "%HOSTS_FILE%.nuevo"
echo # BLOQUEOS HOSTS CONTROL - %date% %time% >> "%HOSTS_FILE%.nuevo"
echo # Grupo: %GRUPO% >> "%HOSTS_FILE%.nuevo"
echo. >> "%HOSTS_FILE%.nuevo"

for /f "usebackq delims=" %%a in ("%HOSTS_TEMP%") do (
    echo %%a >> "%HOSTS_FILE%.nuevo"
)

move /y "%HOSTS_FILE%.nuevo" "%HOSTS_FILE%" >nul 2>&1

if %errorLevel% equ 0 (
    call :WriteLog "OK: Hosts actualizado"
    ipconfig /flushdns >nul 2>&1
    call :WriteLog "OK: DNS cache limpiado"
) else (
    call :WriteLog "ERROR: No se pudo actualizar hosts"
)

:error
call :WriteLog "=== FIN SINCRONIZACION ==="
exit /b

:WriteLog
echo %* >> "%LOG_FILE%"
echo %*
exit /b
