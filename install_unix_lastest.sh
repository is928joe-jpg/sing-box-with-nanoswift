#!/usr/bin/env bash
cd /tmp
set -e # 出错时立即退出

# 采用uname -m 
detect_target() {
    local arch os user_space
    arch="$(uname -m)"
    os="$(uname -s)"

    if [[ "$os" == "Linux" && ( "$arch" == "aarch64" || "$arch" == "arm64" ) ]]; then
        if grep -q "ELF 32-bit" /bin/sh 2>/dev/null; then
            user_space="32"
        else
            user_space="64"
        fi
    fi

    case "$arch" in
        x86_64|amd64)
            [[ "$os" == "Darwin" ]] && echo "darwin-amd64" || echo "linux-amd64"
            ;;
        aarch64|arm64)
            if [[ "$os" == "Darwin" ]]; then
                echo "darwin-arm64"
            else
                # 如果用户态是 32 位，强制降级下载 arm 32位版本
                if [[ "$user_space" == "32" ]]; then
                    echo "linux-arm"
                else
                    echo "linux-arm64"
                fi
            fi
            ;;
        armv7l|armv7*) echo "linux-arm" ;;
        armv6l|armv6*) echo "linux-armv6" ;;
        mips)          echo "linux-mips" ;;
        mipsel|mipsle) echo "linux-mipsle" ;;
        riscv64)       echo "linux-riscv64" ;;
        *)             echo "unsupported"; return 1 ;;
    esac
}

if [ "$(id -u)" -eq 0 ] || ! command -v sudo &> /dev/null; then
    sudo() { "$@"; }
fi

setup_service() {
    local binary_path="$1"

    while true; do
        read -p "📝 请输入 sing-box 的安装目录 (例如: /opt/sing-box): " INSTALL_DIR
        
        if [ -z "$INSTALL_DIR" ]; then
            INSTALL_DIR="/opt/sing-box"
            echo "💡 检测到输入为空，已自动为你创建默认目录: $INSTALL_DIR"
            break
        fi
        if [ -n "$INSTALL_DIR" ]; then
            break
        fi
    done

    INSTALL_DIR="${INSTALL_DIR%/}"

    # ========== 🚀 严格在此处：新文件释放前，精准移除除 profile/ 和 static/ 外的全部内容 ==========
    if [ -d "$INSTALL_DIR" ]; then
        echo "🧹 正在释放新文件前清理目录 $INSTALL_DIR ..."
        echo "💡 安全保留提示：仅保留用户数据目录 (static/ 和 profile/)"
        
        # 1. 移除非白名单的一级文件和文件夹（如 version.txt, cache.db, srs_updater 以及旧二进制等）
        #    这里将 profile 和 static 两个核心目录护住，其余（包括旧的 run 目录）直接斩立决
        sudo find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 \
            ! -name "profile" \
            ! -name "static" \
            ! -name "rules" \
            -exec rm -rf {} + 2>/dev/null || true
    fi
    # =======================================================================================

    echo "📂 正在创建必要的系统目录: $INSTALL_DIR/run ..."
    sudo mkdir -p "$INSTALL_DIR/run"

    echo "🚚 正在部署二进制文件到 $INSTALL_DIR/sing-box ..."
    sudo cp "$binary_path" "$INSTALL_DIR/sing-box"
    sudo chmod +x "$INSTALL_DIR/sing-box"

    echo "⚙️ 正在检测系统初始化管理器并配置自启动..."
    
    if [ -f /etc/openwrt_release ] || [ -d /etc/config ]; then
        
        # 1. 生成 UCI 配置文件
        cat <<EOF | sudo tee /etc/config/sing-box > /dev/null
config sing-box 'main'
    option enabled '1'
    option conffile '$INSTALL_DIR/run/config.json'
    option workdir '$INSTALL_DIR/'
    option log_stderr '1'
    option delay '2'
EOF

        # 2. 创建 LuCI 目标目录
        sudo mkdir -p /usr/lib/lua/luci/controller/
        sudo mkdir -p /usr/lib/lua/luci/model/cbi/

        # 3. 生成 LuCI Controller 路由文件
        sudo tee /usr/lib/lua/luci/controller/singbox.lua > /dev/null << '___LUCICONT___'
module("luci.controller.singbox", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/sing-box") then
        return
    end
    entry({"admin", "services", "singbox"}, cbi("singbox"), _("Sing-Box with Nanoswift"), 60).dependent = true
end
___LUCICONT___

        # 4. 生成 LuCI Model 界面文件
        sudo tee /usr/lib/lua/luci/model/cbi/singbox.lua > /dev/null << '___LUCIMODEL___'
local m, s, o

m = Map("sing-box", translate("Sing-Box with Nanoswift"), translate("轻量级通用代理平台控制面板"))

s = m:section(NamedSection, "main", "sing-box")
s.anonymous = true
s.addremove = false

o = s:option(Flag, "enabled", translate("启用状态"), translate("开启或关闭 Sing-Box 服务"))
o.rmempty = false
o.default = "0"

o = s:option(Value, "delay", translate("启动延时 (秒)"), translate("设置 sing-box 启动时的延迟时间（秒）"))
o.datatype = "integer"
o.rmempty = false
o.default = "2"

o = s:option(DummyValue, "workdir", translate("工作目录"))
o = s:option(DummyValue, "conffile", translate("配置文件路径"))

local apply = luci.http.formvalue("cbi.apply")
if apply then
    luci.sys.init.restart("sing-box")
end

return m
___LUCIMODEL___

        # 5. 修正 LuCI 文件权限并清理缓存
        sudo chmod 644 /usr/lib/lua/luci/controller/singbox.lua
        sudo chmod 644 /usr/lib/lua/luci/model/cbi/singbox.lua
        sudo rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
        echo "🎨 LuCI 面板 'Sing-Box with Nanoswift' 已成功同步安装！"

        # 6. 生成 Procd 启动脚本
        cat <<EOF | sudo tee /etc/init.d/sing-box > /dev/null
#!/bin/sh /etc/rc.common

USE_PROCD=1
START=99
PROG="$INSTALL_DIR/sing-box"

start_service() {
    config_load "sing-box"

    local enabled config_file working_directory log_stderr delay
    config_get_bool enabled "main" "enabled" "0"
    [ "\$enabled" -eq "1" ] || return 0

    config_get config_file "main" "conffile" "$INSTALL_DIR/run/config.json"
    config_get working_directory "main" "workdir" "$INSTALL_DIR/"
    config_get_bool log_stderr "main" "log_stderr" "1"
    
    config_get delay "main" "delay" "0"
    if [ "\$delay" -gt 0 ]; then
        sleep "\$delay"
    fi

    procd_open_instance
    procd_set_param command "\$PROG" run -c "\$config_file" -D "\$working_directory"
    procd_set_param env HOME="$working_directory" GOMEMLIMIT="48MiB" GOGC="50"
    procd_set_param file "\$config_file"
    procd_set_param stderr "\$log_stderr"
    procd_set_param limits core="unlimited"
    procd_set_param limits nofile="1000000 1000000"
    procd_set_param respawn
    procd_close_instance
}

service_triggers() {
    procd_add_reload_trigger "sing-box"
}
EOF
        
        sudo chmod +x /etc/init.d/sing-box

        sudo /etc/init.d/sing-box enable
        sudo /etc/init.d/sing-box start
        echo "✅ OpenWrt 自启动服务已成功激活！"

    elif [ -d /run/systemd/system ] || pidof systemd &>/dev/null; then
        echo "   检测到系统使用 [systemd] (Ubuntu/Debian)..."
        
        if [ ! -f "$INSTALL_DIR/config.json" ]; then
            echo '{}' | sudo tee "$INSTALL_DIR/config.json" > /dev/null
        fi

        cat <<EOF | sudo tee /etc/systemd/system/sing-box.service > /dev/null
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=$INSTALL_DIR/sing-box run -c $INSTALL_DIR/config.json
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl daemon-reload
        sudo systemctl enable sing-box
        sudo systemctl start sing-box
        echo "✅ systemd 自启动服务已成功创建并启动！"

    elif [ -f /sbin/openrc-run ] || [ -d /etc/init.d ]; then
        echo "   检测到系统使用 [OpenRC] (Alpine)..."
        
        if [ ! -f "$INSTALL_DIR/config.json" ]; then
            echo '{}' | sudo tee "$INSTALL_DIR/config.json" > /dev/null
        fi

        cat <<EOF | sudo tee /etc/init.d/sing-box > /dev/null
#!/sbin/openrc-run

description="sing-box service"
command="$INSTALL_DIR/sing-box"
command_args="run -c $INSTALL_DIR/config.json"
pidfile="/run/\${RC_SVCNAME}.pid"
command_background="yes"

depend() {
    need net
    after firewall
}
EOF
        sudo chmod +x /etc/init.d/sing-box
        sudo rc-update add sing-box default 2>/dev/null || true
        sudo rc-service sing-box start
        echo "✅ OpenRC 自启动服务已成功创建并启动！"
    
    else
        echo "⚠️ 未能识别兼容的初始化系统，跳过自启动创建。"
    fi

    echo "--------------------------------------------------"
    echo "🎉 🎉 🎉 安装部署成功 🎉 🎉 🎉"
    echo "🔗 控制面板访问 URL: http://127.0.0.1:9090/ui"
    if [ -f /etc/openwrt_release ]; then
        echo "⚙️  OpenWrt 配置文件路径: $INSTALL_DIR/run/config.json"
        echo "🔧 你可以通过 uci 命令或修改 /etc/config/sing-box 管理服务"
    else
        echo "⚙️  配置文件路径: $INSTALL_DIR/config.json"
    fi
    echo "--------------------------------------------------"
}

platform=$(detect_target)
if [ "$platform" = "unsupported" ] || [ -z "$platform" ]; then
    echo "❌ 错误: 未知或不受支持的系统平台架构。"
    exit 1
fi
echo "   已检测到平台: $platform"

cat << 'EOF'
==================================================
🚀 欢迎使用 sing-box 自动化安装脚本
==================================================
⚡ 请选择适合你当前 network 环境的 GitHub 加加速代理:
1) 不使用代理 (直连官方 GitHub)
2) v4.gh-proxy.org (推荐 IPv4 环境使用)
3) v6.gh-proxy.org (纯 IPv6 / 校园网环境首选)
==================================================
EOF
read -p "请输入序号 [1-3] (默认选择 2): " PROXY_CHOICE
[ -z "$PROXY_CHOICE" ] && PROXY_CHOICE=2

case "$PROXY_CHOICE" in
    1) PROXY_PREFIX="" ;;
    2) PROXY_PREFIX="https://v4.gh-proxy.org/" ;;
    3) PROXY_PREFIX="https://v6.gh-proxy.org/" ;;
    *) PROXY_PREFIX="https://v4.gh-proxy.org/" ;;
esac

DATE_DIR="dist/$(date +%Y-%m-%d)"
mkdir -p "$DATE_DIR"

RAW_BASE_URL="https://raw.githubusercontent.com/is928joe-jpg/sing-box-with-nanoswift/refs/heads/main/2026-06-27"
BINARY_NAME="sing-box-${platform}"
SHA_NAME="${BINARY_NAME}.sha256"

FINAL_BIN_URL="${PROXY_PREFIX}${RAW_BASE_URL}/${BINARY_NAME}"
FINAL_SHA_URL="${PROXY_PREFIX}${RAW_BASE_URL}/${SHA_NAME}"

echo "📥 正在从网络获取二进制文件到 ${DATE_DIR}/ ..."
if ! curl -L -o "${DATE_DIR}/${BINARY_NAME}" "$FINAL_BIN_URL"; then
    echo "❌ 错误: 下载二进制文件失败。"
    exit 1
fi

echo "📥 正在从网络获取哈希校验文件..."
if ! curl -L -o "${DATE_DIR}/${SHA_NAME}" "$FINAL_SHA_URL"; then
    echo "❌ 错误: 下载校验文件失败。"
    exit 1
fi

echo "🔍 正在进行 SHA256 安全校验..."
EXPECTED_HASH=$(awk '{print $1}' "${DATE_DIR}/${SHA_NAME}")
if command -v sha256sum &> /dev/null; then
    ACTUAL_HASH=$(sha256sum "${DATE_DIR}/${BINARY_NAME}" | awk '{print $1}')
elif command -v shasum &> /dev/null; then
    ACTUAL_HASH=$(shasum -a 256 "${DATE_DIR}/${BINARY_NAME}" | awk '{print $1}')
else
    echo "❌ 错误: 找不到 sha256sum 或 shasum 命令。"
    exit 1
fi

if [ "$EXPECTED_HASH" = "$ACTUAL_HASH" ]; then
    echo "✅ SHA256 校验成功: ${ACTUAL_HASH}"
else
    echo "❌ SHA256 校验失败！"
    echo "   期望: ${EXPECTED_HASH}"
    echo "   实际: ${ACTUAL_HASH}"
    exit 1
fi

# ========== 在 SHA256 校验通过后、setup_service 之前插入 ==========

echo "🛑 正在停止可能正在运行的旧 sing-box 服务..."
if [ -f /etc/openwrt_release ] || [ -d /etc/config ]; then
    sudo /etc/init.d/sing-box stop 2>/dev/null || true
    sudo /etc/init.d/sing-box disable 2>/dev/null || true
elif [ -d /run/systemd/system ] || pidof systemd &>/dev/null; then
    sudo systemctl stop sing-box 2>/dev/null || true
    sudo systemctl disable sing-box 2>/dev/null || true
elif [ -f /sbin/openrc-run ] || [ -d /etc/init.d ]; then
    sudo rc-service sing-box stop 2>/dev/null || true
    sudo rc-update del sing-box default 2>/dev/null || true
fi
sudo pkill -f "sing-box run" 2>/dev/null || true
sleep 1
echo "✅ 旧服务已停止"

# ======================================================

setup_service "${DATE_DIR}/${BINARY_NAME}"