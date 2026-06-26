@echo off
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
    echo     - Stop/start system services
    echo     - Modify files in protected directories
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
echo  Welcome to sing-box (Nanoswift) Windows Upgrade Script
echo ============================================================

:: ==========================================
:: 严格的交互获取安装目录（必须不能为空）
:: ==========================================
:input_loop
set "USER_INPUT_DIR="
echo.
echo 请输入 sing-box 的安装目录 (例如: C:\Program Files\sing-box 或 D:\sing-box)
set /p "USER_INPUT_DIR=请输入路径: "

:: 过滤用户可能不小心输入的双引号
if defined USER_INPUT_DIR set "USER_INPUT_DIR=!USER_INPUT_DIR:"=!"

:: 严格判空逻辑
if "%USER_INPUT_DIR%"=="" (
    echo [错误] 安装目录不能为空！为了安全部署，请重新输入有效的路径。
    goto input_loop
)

set "INSTALL_DIR=!USER_INPUT_DIR!"

:: 去掉用户输入路径末尾可能带有反斜杠 \ 的情况，统一格式
if "!INSTALL_DIR:~-1!"=="\" set "INSTALL_DIR=!INSTALL_DIR:~0,-1!"

:: 自动创建目标目录
if not exist "!INSTALL_DIR!" mkdir "!INSTALL_DIR!"

echo.
echo ⚙️ 目标安装路径已确认: !INSTALL_DIR!
echo ------------------------------------------------------------

echo.
echo 请选择适合你当前网络环境的 GitHub 加速代理:
echo 1] 不使用代理 (直连官方 GitHub)
echo 2] v4.gh-proxy.org (推荐 IPv4 环境使用)
echo 3] v6.gh-proxy.org (纯 IPv6 / 校园网环境首选)
echo ============================================================

set /p PROXY_CHOICE="请输入序号 [1-3] (默认选择 2): "
if "!PROXY_CHOICE!"==" " set PROXY_CHOICE=2
if "!PROXY_CHOICE!"=="1" set "PROXY_PREFIX="
if "!PROXY_CHOICE!"=="2" set "PROXY_PREFIX=https://v4.gh-proxy.org/"
if "!PROXY_CHOICE!"=="3" set "PROXY_PREFIX=https://v6.gh-proxy.org/"
if not "!PROXY_CHOICE!"=="1" if not "!PROXY_CHOICE!"=="2" if not "!PROXY_CHOICE!"=="3" set "PROXY_PREFIX=https://v4.gh-proxy.org/"

:: 定义暂存目录 (Windows 系统临时目录 %TEMP%)
set "DOWNLOAD_DIR=%TEMP%\singbox_upgrade"
if not exist "!DOWNLOAD_DIR!" mkdir "!DOWNLOAD_DIR!"

:: 切换到下载暂存目录，确保下载污染不影响安装目录
cd /d "!DOWNLOAD_DIR!"

:: 配置验证存储库下载路径
set "RAW_BASE_URL=https://raw.githubusercontent.com/is928joe-jpg/sing-box-with-nanoswift/refs/heads/main/2026-06-26"
set "BINARY_NAME=sing-box-windows-amd64.exe"
set "SHA_NAME=sing-box-windows-amd64.exe.sha256"
set "FINAL_BIN_URL=!PROXY_PREFIX!!RAW_BASE_URL!/!BINARY_NAME!"
set "FINAL_SHA_URL=!PROXY_PREFIX!!RAW_BASE_URL!/!SHA_NAME!"

:: ==========================================
:: Download core files via curl into %TEMP%
:: ==========================================
echo.
echo [INFO] 正在下载最新的核心二进制文件到暂存区 (%TEMP%)...
curl -L -o "!BINARY_NAME!" "!FINAL_BIN_URL!"
if !errorlevel! neq 0 (
    echo [ERROR] 下载二进制文件失败！请检查您的网络连接。
    pause
    exit /b 1
)

echo [INFO] 正在下载 SHA256 校验文件...
curl -L -o "!SHA_NAME!" "!FINAL_SHA_URL!"
if !errorlevel! neq 0 (
    echo [ERROR] 下载校验文件失败！
    pause
    exit /b 1
)

:: ==========================================
:: SHA256 Integrity Verification
:: ==========================================
echo.
echo [INFO] 正在进行 SHA256 安全校验...
if not exist "!SHA_NAME!" (
    echo [ERROR] 找不到校验文件！校验终止。
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

:: 将两个哈希值转换为小写以进行严格比对
for %%A in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do (
    set "EXPECTED_HASH=!EXPECTED_HASH:%%A=%%A!"
    set "LOCAL_HASH=!LOCAL_HASH:%%A=%%A!"
)

echo     期望哈希: !EXPECTED_HASH!
echo     计算哈希: !LOCAL_HASH!

if /i "!LOCAL_HASH!"=="!EXPECTED_HASH!" (
    echo [SUCCESS] SHA256 校验通过，文件完整性验证成功！
) else (
    echo [ERROR] SHA256 哈希值不匹配！文件可能损坏或已被篡改。
    del /f /q "!BINARY_NAME!" "!SHA_NAME!" >nul 2>&1
    pause
    exit /b 1
)

:: 校验通过后，清理暂存区内的临时哈希文件
del /f /q "!SHA_NAME!" >nul 2>&1


:: ==========================================
:: 1. Stop nanoswift service and kill processes
:: ==========================================
echo.
echo [INFO] 正在停止旧的 nanoswift 服务并结束相关进程...

sc query nanoswift >nul 2>&1
if !errorlevel! equ 0 (
    echo [INFO] 正在发送停止服务指令...
    "!INSTALL_DIR!\nanoswift.exe" stop nanoswift >nul 2>&1
    sc stop nanoswift >nul 2>&1
    timeout /t 3 >nul
)

:: 强制结束可能残留的 sing-box 进程
echo [INFO] 正在终止残留的 sing-box.exe 进程...
taskkill /f /im sing-box.exe >nul 2>&1
if !errorlevel! equ 0 (
    echo     sing-box.exe 进程已成功终止。
) else (
    echo     未发现正在运行的 sing-box.exe 进程。
)

:: 强制结束 nanoswift 守护进程
taskkill /f /im nanoswift.exe >nul 2>&1
timeout /t 3 >nul


:: ==========================================
:: 2. Ensure all handles are released (Target Mode)
:: ==========================================
echo [INFO] 正在验证目标目录中的文件句柄是否已释放...

:check_lock
timeout /t 2 >nul
if exist "!INSTALL_DIR!\sing-box.exe" (
    rem 尝试重命名目标目录下的文件以测试锁定状态
    ren "!INSTALL_DIR!\sing-box.exe" "sing-box.exe.test" >nul 2>&1
    if !errorlevel! equ 0 (
        ren "!INSTALL_DIR!\sing-box.exe.test" "sing-box.exe" >nul 2>&1
        echo     文件未被锁定，正在进入清理部署流程。
    ) else (
        echo     [WARNING] 目标文件仍被锁定，正在尝试二次强制释放...
        taskkill /f /im sing-box.exe >nul 2>&1
        taskkill /f /im nanoswift.exe >nul 2>&1
        timeout /t 5 >nul
        goto check_lock
    )
)


:: ==========================================
:: 3. Remove old files from TARGET INSTALL_DIR
:: ==========================================
echo.
echo [INFO] 正在清理目标目录中的旧 application 缓存及临时组件...

:: 精准切换到用户指定的真正安装目录进行清理
cd /d "!INSTALL_DIR!"

for %%F in (cache.db version.txt convert.exe readme.pdf restart.exe) do (
    if exist "%%F" (
        del /f /q "%%F" 2>nul
        if exist "%%F" (echo     [WARNING] 清理失败: %%F) else (echo     已清理旧文件: %%F)
    )
)

for %%D in (convert dashboard rules) do (
    if exist "%%D" (
        rmdir /s /q "%%D" 2>nul
        if exist "%%D" (echo     [WARNING] 清理失败目录: %%D) else (echo     已清理旧目录: %%D)
    )
)


:: ==========================================
:: 4. Remove old sing-box.exe with Safe Retry Counter
:: ==========================================
echo.
echo [INFO] 正在移除旧版本的 sing-box.exe...
if exist "sing-box.exe" (
    set /a RETRY_COUNT=0
    :retry_delete
    del /f /q "sing-box.exe" 2>nul
    
    if exist "sing-box.exe" (
        set /a RETRY_COUNT+=1
        if !RETRY_COUNT! gtr 4 (
            echo.
            echo [FATAL] 经过多次尝试，sing-box.exe 仍被系统或杀毒软件强行锁定。
            echo         请手动打开任务管理器结束相关进程后重试。
            pause
            exit /b 1
        )
        echo     [WARNING] 文件被占用，正在重试 (!RETRY_COUNT!/4) 3秒后继续...
        taskkill /f /im sing-box.exe >nul 2>&1
        taskkill /f /im nanoswift.exe >nul 2>&1
        timeout /t 3 >nul
        goto retry_delete
    )
    echo     已成功移除旧内核。
)


:: ==========================================
:: 5. Copy and Deploy new binary version from %TEMP%
:: ==========================================
echo.
echo [INFO] 正在将新版本内核从暂存区部署至目标目录...
if exist "!DOWNLOAD_DIR!\sing-box-windows-amd64.exe" (
    :: 使用 move 跨盘符安全移动或覆盖
    move /y "!DOWNLOAD_DIR!\sing-box-windows-amd64.exe" "sing-box.exe" >nul
    if !errorlevel! equ 0 (
        echo     部署成功: sing-box-windows-amd64.exe -^> !INSTALL_DIR!\sing-box.exe
    ) else (
        echo     [ERROR] 移动文件失败，正在尝试备用复制方案...
        copy /y "!DOWNLOAD_DIR!\sing-box-windows-amd64.exe" "sing-box.exe" >nul
        if !errorlevel! equ 0 (
            del /f /q "!DOWNLOAD_DIR!\sing-box-windows-amd64.exe" >nul
            echo     备用部署成功。
        ) else (
            echo     [FATAL] 无法部署新内核。请手动复制暂存区文件。
            pause
            exit /b 1
        )
    )
) else (
    echo     [ERROR] 暂存区中未发现已下载的 sing-box-windows-amd64.exe 文件！
    pause
    exit /b 1
)


:: ==========================================
:: 6. Verify core executable integrity
:: ==========================================
echo.
echo [INFO] 正在验证新部署核心的系统兼容性...
if exist "sing-box.exe" (
    sing-box.exe version >nul 2>&1
    if !errorlevel! equ 0 (
        echo     sing-box.exe 环境验证通过。
    ) else (
        echo     [WARNING] sing-box.exe 无法正常响应内核版本查询，请留意配置。
    )
) else (
    echo     [ERROR] 找不到目标运行核心 sing-box.exe！
    pause
    exit /b 1
)
timeout /t 2 >nul


:: ==========================================
:: 7. Restart background service wrapper
:: ==========================================
echo.
echo [INFO] 正在重新拉起 nanoswift 后台守护服务...
if exist "nanoswift.exe" (
    nanoswift.exe start nanoswift
    if !errorlevel! equ 0 (
        echo     nanoswift 后台服务已成功拉起并开始托管内核。
    ) else (
        echo     [WARNING] 唤醒系统服务失败，可能需要手动启动。
    )
) else (
    echo     [ERROR] 找不到守护外壳 nanoswift.exe，核心无法实现后台自启。
    pause
    exit /b 1
)


:: ==========================================
:: 8. Clean up Temporary Download Directory
:: ==========================================
:: 升级圆满完成，完全擦除 %TEMP% 暂存目录，不留一点系统垃圾
rmdir /s /q "!DOWNLOAD_DIR!" >nul 2>&1

::
:: ==========================================
:: 9. Complete execution info
:: ==========================================
echo.
echo ============================================================
echo     升级成功完成！已完美部署至目标目录。
echo ============================================================
echo 目标路径: !INSTALL_DIR!
echo 后台服务已自动完成重启切换。
echo ============================================================
echo.
timeout /t 5 >nul