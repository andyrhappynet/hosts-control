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
    call :WriteLog "Grupo: %GRUPO%"
) else (
    set GRUPO=ventas
    call :WriteLog "Grupo por defecto: VENTAS"
)

set "HOSTS_URL=%BASE_URL%/%GRUPO%.txt"
set "HOSTS_TEMP=%TEMP%\hosts_%GRUPO%.tmp"

call :WriteLog "Descargando: %HOSTS_URL%"

powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%HOSTS_URL%' -OutFile '%HOSTS_TEMP%' -UseBasicParsing}" 2>nul

if not exist "%HOSTS_TEMP%" (
    call :WriteLog "ERROR: Descarga fallida"
    goto :error
)

set "HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts"
set "HOSTS_BACKUP=%SystemRoot%\System32\drivers\etc\hosts.backup"
copy "%HOSTS_FILE%" "%HOSTS_BACKUP%" >nul 2>&1

set "HOSTS_NEW=%SystemRoot%\System32\drivers\etc\hosts.new"
findstr /v /c:"127.0.0.1" /c:"0.0.0.0" "%HOSTS_BACKUP%" > "%HOSTS_NEW%" 2>nul

echo. >> "%HOSTS_NEW%"
echo # BLOQUEOS HOSTS CONTROL - %date% %time% >> "%HOSTS_NEW%"
echo # Grupo: %GRUPO% >> "%HOSTS_NEW%"
echo. >> "%HOSTS_NEW%"
type "%HOSTS_TEMP%" >> "%HOSTS_NEW%"

move /y "%HOSTS_NEW%" "%HOSTS_FILE%" >nul 2>&1

if %errorLevel% equ 0 (
    call :WriteLog "OK: Hosts actualizado"
    ipconfig /flushdns >nul 2>&1
) else (
    call :WriteLog "ERROR: No se pudo actualizar"
)

:error
call :WriteLog "=== FIN SINCRONIZACION ==="
exit /b

:WriteLog
echo %* >> "%LOG_FILE%"
exit /b
