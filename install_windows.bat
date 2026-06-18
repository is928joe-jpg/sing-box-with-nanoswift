@echo off
cd /d "%~dp0"
setlocal enabledelayedexpansion
chcp 65001 >nul

:: ==========================================
:: Check for Administrator privileges
:: ==========================================
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo ============================================================
    echo [ERROR] Administrator privileges required!
    echo.
    echo This script needs to run as Administrator to:
    echo    - Stop/start system services
    echo    - Modify files in protected directories
    echo.
    echo Please right-click this script and select "Run as Administrator"
    echo or run from an elevated command prompt.
    echo ============================================================
    echo.
    echo Press any key to exit...
    pause >nul 2>&1
    exit /b 1
)

echo ============================================================
echo 🚀 Welcome to sing-box (Nanoswift) Windows Upgrade Script
echo ============================================================
echo ⚡ Please select a GitHub proxy proxy for your network:
echo 1] No Proxy (Direct connection to official GitHub)
echo 2] v4.gh-proxy.org (Recommended for IPv4 environments)
echo 3] v6.gh-proxy.org (Recommended for Pure IPv6 / Campus networks)
echo ============================================================
set /p PROXY_CHOICE="Enter selection [1-3] (Default is 2): "
if "!PROXY_CHOICE!"=="" set PROXY_CHOICE=2

if "!PROXY_CHOICE!"=="1" set "PROXY_PREFIX="
if "!PROXY_CHOICE!"=="2" set "PROXY_PREFIX=https://v4.gh-proxy.org/"
if "!PROXY_CHOICE!"=="3" set "PROXY_PREFIX=https://v6.gh-proxy.org/"
if not "!PROXY_CHOICE!"=="1" if not "!PROXY_CHOICE!"=="2" if not "!PROXY_CHOICE!"=="3" set "PROXY_PREFIX=https://v4.gh-proxy.org/"

:: Configure verified repository download paths
set "RAW_BASE_URL=https://raw.githubusercontent.com/is928joe-jpg/sing-box-with-nanoswift/refs/heads/main/2026-06-18"
set "BINARY_NAME=sing-box-windows-amd64.exe"
set "SHA_NAME=sing-box-windows-amd64.exe.sha256"

set "FINAL_BIN_URL=!PROXY_PREFIX!!RAW_BASE_URL!/!BINARY_NAME!"
set "FINAL_SHA_URL=!PROXY_PREFIX!!RAW_BASE_URL!/!SHA_NAME!"

:: ==========================================
:: Download core files via curl
:: ==========================================
echo.
echo [INFO] Downloading the latest core binary from remote...
curl -L -o "!BINARY_NAME!" "!FINAL_BIN_URL!"
if !errorlevel! neq 0 (
    echo [ERROR] Failed to download binary file! Please check your network.
    pause
    exit /b 1
)

echo [INFO] Downloading the SHA256 checksum file...
curl -L -o "!SHA_NAME!" "!FINAL_SHA_URL!"
if !errorlevel! neq 0 (
    echo [ERROR] Failed to download checksum file!
    pause
    exit /b 1
)

:: ==========================================
:: SHA256 Integrity Verification
:: ==========================================
echo.
echo [INFO] Performing SHA256 integrity check...

if not exist "!SHA_NAME!" (
    echo [ERROR] Checksum file not found! Verification aborted.
    pause
    exit /b 1
)
set /p EXPECTED_HASH_LINE=<"!SHA_NAME!"
set "EXPECTED_HASH=!EXPECTED_HASH_LINE:~0,64!"

set "LOCAL_HASH="
for /f "skip=1 delims=" %%i in ('certutil -hashfile "!BINARY_NAME!" SHA256') do (
    if not defined LOCAL_HASH (
        set "LOCAL_HASH=%%i"
        set "LOCAL_HASH=!LOCAL_HASH: =!"
    )
)

:: Convert both hashes to lowercase for strict comparison
for %%A in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do (
    set "EXPECTED_HASH=!EXPECTED_HASH:%%A=%%A!"
    set "LOCAL_HASH=!LOCAL_HASH:%%A=%%A!"
)

echo    Expected Hash: !EXPECTED_HASH!
echo    Calculated Hash: !LOCAL_HASH!

if /i "!LOCAL_HASH!"=="!EXPECTED_HASH!" (
    echo [SUCCESS] SHA256 check passed. File integrity verified!
) else (
    echo [ERROR] SHA256 hash mismatch! The file might be corrupted.
    del /f /q "!BINARY_NAME!" "!SHA_NAME!" >nul 2>&1
    pause
    exit /b 1
)

:: Clean up temporary checksum file after verification
del /f /q "!SHA_NAME!" >nul 2>&1

:: ==========================================
:: Check UAC status
:: ==========================================
reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA 2>nul | findstr /i "0x1" >nul
if !errorlevel! equ 0 (
    echo [NOTICE] UAC is currently enabled on this system.
    echo.
    timeout /t 2 >nul
)

:: ==========================================
:: 1. Check nanoswift service and stop if running
:: ==========================================
echo [INFO] Checking nanoswift service status...
sc query nanoswift >nul 2>&1
if !errorlevel! equ 0 (
    echo [INFO] Stopping running nanoswift service...
    nanoswift.exe stop nanoswift >nul 2>&1
    timeout /t 2 >nul
) else (
    echo [INFO] Launching nanoswift.exe initialization wrapper...
    if exist "nanoswift.exe" (
        start "" /wait nanoswift.exe
    )
)

:: ==========================================
:: 2. Ensure nanoswift service is stopped
:: ==========================================
echo [INFO] Ensuring service handles are released...
if exist "nanoswift.exe" (
    nanoswift.exe stop nanoswift >nul 2>&1
)
timeout /t 2 >nul

:: ==========================================
:: 3. Remove old files and temporary directories
:: ==========================================
echo.
echo [INFO] Cleaning up old application data caches...

if exist "cache.db" (
    del /f /q "cache.db" 2>nul
    if !errorlevel! equ 0 (echo    Deleted: cache.db) else (echo    [WARNING] Failed to delete: cache.db)
)
if exist "convert" (
    rmdir /s /q "convert" 2>nul
    if !errorlevel! equ 0 (echo    Deleted: convert) else (echo    [WARNING] Failed to delete: convert)
)
if exist "dashboard" (
    rmdir /s /q "dashboard" 2>nul
    if !errorlevel! equ 0 (echo    Deleted: dashboard) else (echo    [WARNING] Failed to delete: dashboard)
)
if exist "rules" (
    rmdir /s /q "rules" 2>nul
    if !errorlevel! equ 0 (echo    Deleted: rules) else (echo    [WARNING] Failed to delete: rules)
)
if exist "static" (
    rmdir /s /q "static" 2>nul
    if !errorlevel! equ 0 (echo    Deleted: static) else (echo    [WARNING] Failed to delete: static)
)

if exist "convert.exe" (
    del /f /q "convert.exe" 2>nul
    if !errorlevel! equ 0 (echo    Deleted: convert.exe) else (echo    [WARNING] Failed to delete: convert.exe)
)
if exist "readme.pdf" (
    del /f /q "readme.pdf" 2>nul
    if !errorlevel! equ 0 (echo    Deleted: readme.pdf) else (echo    [WARNING] Failed to delete: readme.pdf)
)
if exist "restart.exe" (
    del /f /q "restart.exe" 2>nul
    if !errorlevel! equ 0 (echo    Deleted: restart.exe) else (echo    [WARNING] Failed to delete: restart.exe)
)
if exist "sing-box.exe" (
    del /f /q "sing-box.exe" 2>nul
    if !errorlevel! equ 0 (echo    Deleted: sing-box.exe) else (echo    [WARNING] Failed to delete: sing-box.exe)
)

:: ==========================================
:: 4. Rename and deploy new binary version
:: ==========================================
echo.
echo [INFO] Deploying new version...
if exist "sing-box-windows-amd64.exe" (
    move /y "sing-box-windows-amd64.exe" "sing-box.exe" >nul
    if !errorlevel! equ 0 (
        echo    Renamed: sing-box-windows-amd64.exe -^> sing-box.exe
    ) else (
        echo    [ERROR] Failed to replace sing-box.exe asset. File might be locked.
        pause
        exit /b 1
    )
) else (
    echo    [ERROR] Deployment target sing-box-windows-amd64.exe missing!
    pause
    exit /b 1
)

:: ==========================================
:: 5. Initialize core executable
:: ==========================================
echo.
echo [INFO] Initializing sing-box environment setup...
if exist "sing-box.exe" (
    start "" /wait sing-box.exe
    echo    sing-box.exe initialization triggered successfully.
) else (
    echo    [ERROR] Runtime binary sing-box.exe not found!
    pause
    exit /b 1
)

timeout /t 2 >nul

:: ==========================================
:: 6. Restart background service wrapper
:: ==========================================
echo.
echo [INFO] Activating nanoswift service daemon...
if exist "nanoswift.exe" (
    nanoswift.exe start nanoswift
    if !errorlevel! equ 0 (
        echo    nanoswift background service started successfully.
    ) else (
        echo    [WARNING] Failed to start system service instance.
    )
) else (
    echo    [ERROR] Daemon wrapper nanoswift.exe is missing. Core service cannot boot.
    pause
    exit /b 1
)

:: ==========================================
:: 7. Complete execution info
:: ==========================================
echo.
echo ============================================================
echo    Upgrade completed successfully!
echo ============================================================
echo.
echo The nanoswift orchestration layer has restarted the core pipeline.
echo.
timeout /t 5 >nul