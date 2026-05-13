@echo off
setlocal enabledelayedexpansion
title Hosts Sync - Auto Actualizable

REM ============================================
REM CONFIGURACION
REM ============================================
set "GITHUB_USER=andyrhappynet"
set "REPO_NAME=hosts-control"
set "BRANCH=main"
set "BASE_URL=https://raw.githubusercontent.com/%GITHUB_USER%/%REPO_NAME%/%BRANCH%"
set "LOG_FILE=%ProgramData%\HostsSync\sync_log.txt"
set "SELF_URL=%BASE_URL%/scripts/hosts_sync.bat"
set "SELF_TEMP=%TEMP%\hosts_sync_new.bat"

if not exist "%ProgramData%\HostsSync" mkdir "%ProgramData%\HostsSync"

call :WriteLog "========================================="
call :WriteLog "INICIO SCRIPT - %date% %time%"
call :WriteLog "========================================="

REM ============================================
REM PASO 1: AUTO-ACTUALIZACION DEL SCRIPT
REM ============================================
call :WriteLog "Paso 1: Verificando actualizaciones del script..."

bitsadmin /transfer "SelfUpdate" /download /priority normal "%SELF_URL%" "%SELF_TEMP%" >nul 2>&1

if not exist "%SELF_TEMP%" (
    powershell -Command "Invoke-WebRequest -Uri '%SELF_URL%' -OutFile '%SELF_TEMP%' -UseBasicParsing" >nul 2>&1
)

if exist "%SELF_TEMP%" (
    REM Comparar versiones (usando el tamaño del archivo como indicador)
    for %%A in ("%SELF_TEMP%") do set NEW_SIZE=%%~zA
    for %%A in ("%~f0") do set OLD_SIZE=%%~zA
    
    if not "!NEW_SIZE!"=="!OLD_SIZE!" (
        call :WriteLog "Nueva version del script detectada. Actualizando..."
        copy "%SELF_TEMP%" "%~f0" /y >nul 2>&1
        if !errorLevel! equ 0 (
            call :WriteLog "Script actualizado exitosamente. Reiniciando..."
            start "" "%~f0"
            exit
        ) else (
            call :WriteLog "ERROR: No se pudo actualizar el script"
        )
    ) else (
        call :WriteLog "Script ya esta actualizado"
    )
    del "%SELF_TEMP%" >nul 2>&1
) else (
    call :WriteLog "ADVERTENCIA: No se pudo verificar actualizaciones"
)

REM ============================================
REM PASO 2: LEER GRUPO ASIGNADO
REM ============================================
call :WriteLog "Paso 2: Leyendo grupo asignado..."

set "GRUPO_FILE=%ProgramData%\HostsSync\grupo_actual.txt"
if exist "%GRUPO_FILE%" (
    set /p GRUPO=<"%GRUPO_FILE%"
    call :WriteLog "Grupo activo: %GRUPO%"
) else (
    set GRUPO=ventas
    echo ventas> "%GRUPO_FILE%"
    call :WriteLog "Grupo por defecto: VENTAS"
)

REM ============================================
REM PASO 3: DESCARGAR BLOQUEOS DEL GRUPO
REM ============================================
call :WriteLog "Paso 3: Descargando bloqueos del grupo %GRUPO%..."

set "HOSTS_URL=%BASE_URL%/grupos/%GRUPO%.txt"
set "HOSTS_TEMP=%TEMP%\hosts_%GRUPO%.tmp"

bitsadmin /transfer "HostsDownload" /download /priority normal "%HOSTS_URL%" "%HOSTS_TEMP%" >nul 2>&1

if not exist "%HOSTS_TEMP%" (
    powershell -Command "Invoke-WebRequest -Uri '%HOSTS_URL%' -OutFile '%HOSTS_TEMP%' -UseBasicParsing" >nul 2>&1
)

if not exist "%HOSTS_TEMP%" (
    call :WriteLog "ERROR: No se pudo descargar %HOSTS_URL%"
    goto :error
)

call :WriteLog "Bloqueos descargados correctamente"

REM ============================================
REM PASO 4: ACTUALIZAR ARCHIVO HOSTS
REM ============================================
call :WriteLog "Paso 4: Actualizando archivo hosts..."

set "HOSTS_FILE=C:\Windows\System32\drivers\etc\hosts"
set "HOSTS_BACKUP=%HOSTS_FILE%.backup"

REM Quitar atributo de solo lectura
attrib -r "%HOSTS_FILE%" >nul 2>&1

REM Hacer backup
copy "%HOSTS_FILE%" "%HOSTS_BACKUP%" >nul 2>&1

REM Eliminar bloqueos anteriores de nuestro sistema
findstr /v /c:"# BLOQUEOS HOSTS CONTROL" "%HOSTS_BACKUP%" > "%HOSTS_FILE%.temp" 2>nul

if not exist "%HOSTS_FILE%.temp" (
    copy "%HOSTS_BACKUP%" "%HOSTS_FILE%.temp" >nul 2>&1
)

REM Agregar nuevos bloqueos
echo. >> "%HOSTS_FILE%.temp"
echo # ==================================== >> "%HOSTS_FILE%.temp"
echo # BLOQUEOS HOSTS CONTROL >> "%HOSTS_FILE%.temp"
echo # Fecha: %date% %time% >> "%HOSTS_FILE%.temp"
echo # Grupo: %GRUPO% >> "%HOSTS_FILE%.temp"
echo # Fuente: %HOSTS_URL% >> "%HOSTS_FILE%.temp"
echo # ==================================== >> "%HOSTS_FILE%.temp"
echo. >> "%HOSTS_FILE%.temp"
type "%HOSTS_TEMP%" >> "%HOSTS_FILE%.temp"

REM Reemplazar archivo hosts
move /y "%HOSTS_FILE%.temp" "%HOSTS_FILE%" >nul 2>&1

if %errorLevel% equ 0 (
    call :WriteLog "OK: Archivo hosts actualizado"
    ipconfig /flushdns >nul 2>&1
    call :WriteLog "OK: DNS cache limpiado"
) else (
    call :WriteLog "ERROR: No se pudo reemplazar el archivo hosts"
    copy /y "%HOSTS_FILE%.temp" "%HOSTS_FILE%" >nul 2>&1
    if !errorLevel! equ 0 (
        call :WriteLog "OK: Hosts actualizado con metodo alternativo"
    ) else (
        call :WriteLog "ERROR CRITICO: No se puede escribir en hosts"
    )
)

:error
call :WriteLog "========================================="
call :WriteLog "FIN SCRIPT - %date% %time%"
call :WriteLog "========================================="
echo.
exit /b

:WriteLog
echo %* >> "%LOG_FILE%"
echo %*
exit /b
