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
    set GRUPO=!GRUPO: =!
    call :WriteLog "Grupo activo: [%GRUPO%]"
) else (
    set GRUPO=ventas
    echo ventas> "%GRUPO_FILE%"
    call :WriteLog "Grupo por defecto: VENTAS"
)

if "!GRUPO!"=="" (
    set GRUPO=ventas
    call :WriteLog "Grupo vacio, usando VENTAS"
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

call :WriteLog "OK: Archivo descargado desde GitHub"

set "HOSTS_FILE=C:\Windows\System32\drivers\etc\hosts"
set "HOSTS_BACKUP=%USERPROFILE%\Desktop\hosts_backup_%date:~0,2%%date:~3,2%%date:~8,4%_%time:~0,2%%time:~3,2%.txt"

REM Hacer backup
copy "%HOSTS_FILE%" "%HOSTS_BACKUP%" >nul 2>&1
call :WriteLog "Backup guardado en: %HOSTS_BACKUP%"

REM Quitar solo lectura
attrib -r "%HOSTS_FILE%" >nul 2>&1

REM Crear NUEVO archivo hosts solo con lineas del sistema (sin bloqueos viejos)
findstr /v /c:"127.0.0.1" /v /c:"0.0.0.0" "%HOSTS_FILE%" > "%HOSTS_FILE%.base" 2>nul

REM Agregar los NUEVOS bloqueos desde GitHub
echo. >> "%HOSTS_FILE%.base"
echo # ======================================== >> "%HOSTS_FILE%.base"
echo # BLOQUEOS HOSTS CONTROL - %date% %time% >> "%HOSTS_FILE%.base"
echo # Grupo: %GRUPO% - Desde GitHub >> "%HOSTS_FILE%.base"
echo # ======================================== >> "%HOSTS_FILE%.base"
echo. >> "%HOSTS_FILE%.base"

REM Agregar CADA linea del archivo descargado
for /f "usebackq delims=" %%a in ("%HOSTS_TEMP%") do (
    echo %%a >> "%HOSTS_FILE%.base"
)

REM Reemplazar el hosts original
move /y "%HOSTS_FILE%.base" "%HOSTS_FILE%" >nul 2>&1

if %errorLevel% equ 0 (
    call :WriteLog "OK: Hosts REEMPLAZADO exitosamente con bloqueos de GitHub"
    ipconfig /flushdns >nul 2>&1
    call :WriteLog "OK: DNS cache limpiado"
    
    REM Verificacion post-actualizacion
    call :WriteLog "Verificando bloqueos aplicados:"
    findstr "netflix" "%HOSTS_FILE%" >> "%LOG_FILE%" 2>nul
) else (
    call :WriteLog "ERROR CRITICO: No se pudo reemplazar el hosts"
)

:error
call :WriteLog "=== FIN SINCRONIZACION ==="
exit /b

:WriteLog
echo %* >> "%LOG_FILE%"
echo %*
exit /b
