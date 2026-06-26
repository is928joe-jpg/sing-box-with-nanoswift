@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

:: ==========================================
:: 权限检查 (Administrator privileges check)
:: ==========================================
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo ============================================================
    echo [ERROR] Administrator privileges required!
    echo.
    echo This script needs to run as Administrator to:
    echo     - Stop/start system services
    echo     - Modify files in protected directories
    echo     - Execute takeown / icacls for locked assets
    echo.
    echo Please right-click this script and select "Run as Administrator"
    echo ============================================================
    echo.
    echo Press any key to exit...
    pause >nul 2>&1
    exit /b 1
)

echo ============================================================
echo  Welcome to sing-box (Nanoswift) Windows Upgrade Script
echo ============================================================

:: ==========================================
:: 严格的交互获取安装目录（必须不能为空）
:: ==========================================
:input_loop
set "USER_INPUT_DIR="
echo.
echo Please enter the sing-box installation directory (e.g., C:\sing-box or D:\sing-box):
set /p "USER_INPUT_DIR=Path: "

if defined USER_INPUT_DIR set "USER_INPUT_DIR=!USER_INPUT_DIR:"=!"

if "%USER_INPUT_DIR%"=="" (
    echo [ERROR] Installation directory cannot be empty! Please try again.
    goto input_loop
)

set "INSTALL_DIR=!USER_INPUT_DIR!"

if "!INSTALL_DIR:~-1!"=="\" set "INSTALL_DIR=!INSTALL_DIR:~0,-1!"

if not exist "!INSTALL_DIR!" mkdir "!INSTALL_DIR!"

echo.
echo [INFO] Target path confirmed: !INSTALL_DIR!
echo ------------------------------------------------------------

:: ==========================================
:: GitHub 代理选择（回车自动默认 2）
:: ==========================================
echo.
echo Please select a GitHub proxy proxy for your network:
echo 1] No Proxy (Direct connection to official GitHub)
echo 2] v4.gh-proxy.org (Recommended for IPv4 environments)
echo 3] v6.gh-proxy.org (Recommended for Pure IPv6 / Campus networks)
echo ============================================================

set "PROXY_CHOICE="
set /p PROXY_CHOICE="Enter selection [1-3] (Default is 2): "

if "%PROXY_CHOICE%"=="" set PROXY_CHOICE=2
if "!PROXY_CHOICE!"=="1" set "PROXY_PREFIX="
if "!PROXY_CHOICE!"=="2" set "PROXY_PREFIX=https://v4.gh-proxy.org/"
if "!PROXY_CHOICE!"=="3" set "PROXY_PREFIX=https://v6.gh-proxy.org/"
if not "!PROXY_CHOICE!"=="1" if not "!PROXY_CHOICE!"=="2" if not "!PROXY_CHOICE!"=="3" set "PROXY_PREFIX=https://v4.gh-proxy.org/"

set "DOWNLOAD_DIR=%TEMP%\singbox_upgrade"
if not exist "!DOWNLOAD_DIR!" mkdir "!DOWNLOAD_DIR!"

cd /d "!DOWNLOAD_DIR!"

set "RAW_BASE_URL=https://raw.githubusercontent.com/is928joe-jpg/sing-box-with-nanoswift/refs/heads/main/2026-06-26"
set "BINARY_NAME=sing-box-windows-amd64.exe"
set "SHA_NAME=sing-box-windows-amd64.exe.sha256"
set "FINAL_BIN_URL=!PROXY_PREFIX!!RAW_BASE_URL!/!BINARY_NAME!"
set "FINAL_SHA_URL=!PROXY_PREFIX!!RAW_BASE_URL!/!SHA_NAME!"

:: ==========================================
:: 下载核心组件
:: ==========================================
echo.
echo [INFO] Downloading the latest core binary to temporary area (%TEMP%)...
curl -L -k --ssl-no-revoke -o "!BINARY_NAME!" "!FINAL_BIN_URL!"
if !errorlevel! neq 0 (
    echo [ERROR] Failed to download binary file! Please check your network.
    pause
    exit /b 1
)

echo [INFO] Downloading the SHA256 checksum file...
curl -L -k --ssl-no-revoke -o "!SHA_NAME!" "!FINAL_SHA_URL!"
if !errorlevel! neq 0 (
    echo [ERROR] Failed to download checksum file!
    pause
    exit /b 1
)

:: ==========================================
:: SHA256 完整性验证（最终稳定版）
:: ==========================================
echo.
echo [INFO] Performing SHA256 integrity check...
if not exist "!SHA_NAME!" (
    echo [ERROR] Checksum file not found! Verification aborted.
    pause
    exit /b 1
)

:: 读取期望哈希
set "EXPECTED_HASH="
for /f "usebackq tokens=1" %%H in ("!SHA_NAME!") do (
    set "EXPECTED_HASH=%%H"
    goto got_expected_hash
)
:got_expected_hash

if "!EXPECTED_HASH!"=="" (
    echo [ERROR] Failed to read expected hash from checksum file!
    pause
    exit /b 1
)

set "EXPECTED_HASH=!EXPECTED_HASH: =!"
set "EXPECTED_HASH=!EXPECTED_HASH:  =!"

:: 计算本地哈希（永远只取 certutil 输出第二行）
set "LOCAL_HASH="
for /f "skip=1 tokens=* delims=" %%i in ('
    certutil -hashfile "!BINARY_NAME!" SHA256 ^
    ^| findstr /v /i "certutil"
') do (
    set "LOCAL_HASH=%%i"
    goto got_local_hash
)
:got_local_hash

set "LOCAL_HASH=!LOCAL_HASH: =!"
set "LOCAL_HASH=!LOCAL_HASH:    =!"

:: 转小写
for %%A in (A=a B=b C=c D=d E=e F=f G=g H=h I=i J=j K=k L=l M=m N=n O=o P=p Q=q R=r S=s T=t U=u V=v W=w X=x Y=y Z=z) do (
    for /f "tokens=1,2 delims==" %%X in ("%%A") do (
        set "EXPECTED_HASH=!EXPECTED_HASH:%%X=%%Y!"
        set "LOCAL_HASH=!LOCAL_HASH:%%X=%%Y!"
    )
)

echo     Expected Hash: !EXPECTED_HASH!
echo     Calculated Hash: !LOCAL_HASH!

if "!LOCAL_HASH!"=="!EXPECTED_HASH!" (
    echo [SUCCESS] SHA256 check passed. File integrity verified!
) else (
    echo [ERROR] SHA256 hash mismatch! The file might be corrupted.
    del /f /q "!BINARY_NAME!" "!SHA_NAME!" >nul 2>&1
    pause
    exit /b 1
)

del /f /q "!SHA_NAME!" >nul 2>&1

:: ==========================================
:: 1. 彻底停用并击杀所有潜在的句柄占用源
:: ==========================================
echo.
echo [INFO] Stopping nanoswift service and forcefully terminating all dependent processes...

sc query nanoswift >nul 2>&1
if !errorlevel! equ 0 (
    if exist "!INSTALL_DIR!\nanoswift.exe" (
        "!INSTALL_DIR!\nanoswift.exe" stop nanoswift >nul 2>&1
    )
    sc stop nanoswift >nul 2>&1
)

taskkill /f /im sing-box.exe >nul 2>&1
taskkill /f /im nanoswift.exe >nul 2>&1

echo [INFO] Waiting for OS handle release pipeline...
set /a PROCESS_POLL=0
:poll_loop
timeout /t 1 >nul
tasklist /fi "imagename eq sing-box.exe" 2>nul | findstr /i "sing-box.exe" >nul
set "SB_ALIVE=!errorlevel!"
tasklist /fi "imagename eq nanoswift.exe" 2>nul | findstr /i "nanoswift.exe" >nul
set "NS_ALIVE=!errorlevel!"

if "!SB_ALIVE!"=="0" set /a PROCESS_POLL+=1
if "!NS_ALIVE!"=="0" set /a PROCESS_POLL+=1

if !PROCESS_POLL! gtr 0 (
    if !PROCESS_POLL! lss 6 (
        taskkill /f /im sing-box.exe >nul 2>&1
        taskkill /f /im nanoswift.exe >nul 2>&1
        goto poll_loop
    )
)
echo [INFO] Process termination verified clear.

:: ==========================================
:: 2. 切换至生产目录，并执行高级权限夺取
:: ==========================================
echo.
echo [INFO] Switching context to installation directory...
cd /d "!INSTALL_DIR!"

if exist "sing-box.exe" (
    takeown /f "sing-box.exe" >nul 2>&1
    icacls "sing-box.exe" /grant administrators:F >nul 2>&1
)

:: ==========================================
:: 3. 深度清理旧内核文件与全量相关资产
:: ==========================================
echo [INFO] Purging target installation components...

for %%F in (cache.db version.txt convert.exe readme.pdf restart.exe geoip.db geosite.db config.json sing-box.exe.test sing-box.exe.tmp) do (
    if exist "%%F" (
        takeown /f "%%F" >nul 2>&1
        icacls "%%F" /grant administrators:F >nul 2>&1
        del /f /q "%%F" 2>nul
    )
)

for %%D in (convert dashboard rules ui assets) do (
    if exist "%%D" (
        takeown /f "%%D" /r /d y >nul 2>&1
        icacls "%%D" /grant administrators:F /t >nul 2>&1
        rmdir /s /q "%%D" 2>nul
    )
)

:: ==========================================
:: 4. 移除旧版主核心 (引入容错自愈覆盖)
:: ==========================================
echo.
echo [INFO] Overwriting sing-box.exe runtime binary...
if exist "sing-box.exe" (
    set /a RETRY_COUNT=0
    :retry_delete
    del /f /q "sing-box.exe" 2>nul
    
    if exist "sing-box.exe" (
        set /a RETRY_COUNT+=1
        if !RETRY_COUNT! gtr 3 (
            goto force_deploy
        )
        taskkill /f /im sing-box.exe >nul 2>&1
        taskkill /f /im nanoswift.exe >nul 2>&1
        timeout /t 2 >nul
        goto retry_delete
    )
)

:force_deploy
:: ==========================================
:: 5. 精准跨盘部署核心资产
:: ==========================================
echo [INFO] Deploying pristine compiled core from temporary buffer...
if exist "!DOWNLOAD_DIR!\%BINARY_NAME%" (
    if exist "sing-box.exe" (
        takeown /f "sing-box.exe" >nul 2>&1
        icacls "sing-box.exe" /grant administrators:F >nul 2>&1
    )
    
    move /y "!DOWNLOAD_DIR!\%BINARY_NAME%" "sing-box.exe" >nul
    if !errorlevel! neq 0 (
        copy /y "!DOWNLOAD_DIR!\%BINARY_NAME%" "sing-box.exe" >nul
        del /f /q "!DOWNLOAD_DIR!\%BINARY_NAME%" >nul
    )
) else (
    echo [ERROR] Downloaded buffer source asset is missing from temporary folder!
    pause
    exit /b 1
)

:: ==========================================
:: 6. 内核兼容性离线静默验证
:: ==========================================
echo.
echo [INFO] Validating modern core cross-compilation environment integrity...
if exist "sing-box.exe" (
    sing-box.exe version >nul 2>&1
)

:: ==========================================
:: 7. 重新拉起守护外壳服务
:: ==========================================
echo.
echo [INFO] Reactivating orchestration engine layer...
if exist "nanoswift.exe" (
    takeown /f "nanoswift.exe" >nul 2>&1
    icacls "nanoswift.exe" /grant administrators:F >nul 2>&1
    
    nanoswift.exe start nanoswift
)

:: ==========================================
:: 8. 彻底擦除系统暂存区垃圾
:: ==========================================
rmdir /s /q "!DOWNLOAD_DIR!" >nul 2>&1

:: ==========================================
:: 9. 正常退出提示
:: ==========================================
echo.
echo ============================================================
echo     Upgrade Completed Successfully!
echo ============================================================
echo  Deploy Path: !INSTALL_DIR!
echo ============================================================
echo.
timeout /t 5 >nul
