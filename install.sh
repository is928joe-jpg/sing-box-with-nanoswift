#!/usr/bin/env bash

set -e 

detect_target() {
    local arch os
    arch="$(uname -m)"
    os="$(uname -s)"

    case "$arch" in
        x86_64|amd64)
            [[ "$os" == "Darwin" ]] && echo "darwin-amd64" || echo "linux-amd64"
            ;;
        aarch64|arm64)
            [[ "$os" == "Darwin" ]] && echo "darwin-arm64" || echo "linux-arm64"
            ;;
        armv7l|armv7*) echo "linux-arm" ;;
        armv6l|armv6*) echo "linux-armv6" ;;
        mips)          echo "linux-mips" ;;
        mipsel|mipsle) echo "linux-mipsle" ;;
        riscv64)       echo "linux-riscv64" ;;
        *)             echo "unsupported"; return 1 ;;
    esac
}

# 新增函数：获取精选 GitHub 加速后的完整 URL
get_accelerated_url() {
    local raw_url="$1"
    echo "=================================================="
    echo "⚡ 请选择 GitHub 下载加速代理节点:"
    echo "1) 官方原始链接 (不使用代理)"
    echo "2) gh-proxy.com (推荐，经典稳定)"
    echo "3) v6.gh-proxy.org (纯 IPv6 / 校园网环境佳)"
    echo "4) hub.glowp.xyz (备用高速反代)"
    echo "=================================================="
    
    read -p "请输入序号 [1-4] (默认 2): " choice
    [ -z "$choice" ] && choice=2

    case "$choice" in
        1)
            echo "$raw_url"
            ;;
        2)
            echo "https://gh-proxy.com/$raw_url"
            ;;
        3)
            echo "https://v6.gh-proxy.org/$raw_url"
            ;;
        4)
            echo "https://hub.glowp.xyz/$raw_url"
            ;;
        *)
            echo "💡 输入无效，回退到默认加速节点 (gh-proxy.com)"
            echo "https://gh-proxy.com/$raw_url"
            ;;
    esac
}

# 配置安装目录与自启动服务
setup_service() {
    local binary_path="$1"
    
    echo "--------------------------------------------------"
    # 1. 提示输入安装目录（增加非空校验循环）
    while true; do
        read -p "📝 请输入 sing-box 的安装目录 (例如: /opt/sing-box): " INSTALL_DIR
        
        # 如果用户直接回车留空，自动赋予默认值 /opt/sing-box 并跳出循环
        if [ -z "$INSTALL_DIR" ]; then
            INSTALL_DIR="/opt/sing-box"
            echo "💡 检测到输入为空，已使用默认目录: $INSTALL_DIR"
            break
        fi
        
        # 如果输入了内容，则直接跳出循环
        if [ -n "$INSTALL_DIR" ]; then
            break
        fi
    done

    # 去掉用户输入目录末尾可能携带的斜杠 /
    INSTALL_DIR="${INSTALL_DIR%/}"

    echo "📂 正在创建安装目录与运行目录: $INSTALL_DIR/run ..."
    sudo mkdir -p "$INSTALL_DIR/run"

    # 2. 复制下载的文件到安装目录并重命名
    echo "🚚 正在复制二进制文件到 $INSTALL_DIR/sing-box ..."
    sudo cp "$binary_path" "$INSTALL_DIR/sing-box"
    
    # 3. 赋予执行权限
    sudo chmod +x "$INSTALL_DIR/sing-box"

    # 4. 根据系统类型创建自启动服务
    echo "⚙️ 正在检测系统初始化管理器..."
    
    # === 例外处理：检测是否为 OpenWrt 环境 ===
    if [ -f /etc/openwrt_release ] || [ -d /etc/config ]; then
        echo "   检测到系统为 [OpenWrt / ImmortalWrt] 正在配置 UCI 服务..."

        if [ ! -f "$INSTALL_DIR/run/config.json" ]; then
            echo "📝 创建默认空配置文件: $INSTALL_DIR/run/config.json ..."
            echo '{}' | sudo tee "$INSTALL_DIR/run/config.json" > /dev/null
        fi

        # 写入 /etc/config/sing-box
        cat <<EOF | sudo tee /etc/config/sing-box > /dev/null
config sing-box 'main'
    option enabled '1'
    option conffile '$INSTALL_DIR/run/config.json'
    option workdir '$INSTALL_DIR/'
    option log_stderr '1'
    option delay '2'
EOF

        # 写入 /etc/init.d/sing-box
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
    
    # 1. 读取配置文件中的 delay 参数
    config_get delay "main" "delay" "0"

    # 2. 如果设置了延迟，开机时先等待硬盘挂载
    if [ "\$delay" -gt 0 ]; then
        sleep "\$delay"
    fi

    procd_open_instance
    procd_set_param command "\$PROG" run -c "\$config_file" -D "\$working_directory"
    procd_set_param env HOME="\$working_directory"
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
        
        chmod +x /etc/init.d/sing-box
        cp $INSTALL_DIR/run/vanilla.json $INSTALL_DIR/run/config.json
        echo "🔄 正在启用并启动 OpenWrt procd 服务..."
        sudo /etc/init.d/sing-box enable
        sudo /etc/init.d/sing-box start
        echo "✅ OpenWrt UCI/Procd 自启动服务已成功创建并激活！"

    # === 常规系统：检测 systemd (Ubuntu, Debian 等) ===
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

    # === 常规系统：检测 OpenRC (Alpine Linux) ===
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
        cp $INSTALL_DIR/run/vanilla.json $INSTALL_DIR/run/config.json
        sudo rc-service sing-box start
        echo "✅ OpenRC 自启动服务已成功创建并启动！"
    
    else
        echo "⚠️ 未能识别兼容的初始化系统，跳过自启动创建。"
    fi

    # 5. 提示控制面板访问 URL
    
    echo "--------------------------------------------------"
    echo "🎉 🎉 🎉 安装部署成功 🎉 🎉 🎉"
    echo "🔗 控制面板访问 URL: http://127.0.0.1:9090"
    if [ -f /etc/openwrt_release ]; then
        echo "⚙️  OpenWrt 配置文件路径: $INSTALL_DIR/run/config.json"
        echo "🔧 你可以通过 uci 命令或修改 /etc/config/sing-box 管理服务"
    else
        echo "⚙️  配置文件路径: $INSTALL_DIR/config.json"
    fi
    echo "--------------------------------------------------"
}

# ==================== 主流程 ====================

platform=$(detect_target)
if [ "$platform" = "unsupported" ] || [ -z "$platform" ]; then
    echo "❌ 错误: 未知或不受支持的系统平台架构。"
    exit 1
fi
echo "   已检测到平台: $platform"

mkdir -p dist

# 定义原始 Raw 下载路径
RAW_BASE_URL="https://github.com/is928joe-jpg/sing-box-with-nanoswift/raw/refs/heads/main/2026-06-18"
BINARY_NAME="sing-box-${platform}"
SHA_NAME="${BINARY_NAME}.sha256"

# 调用加速选择函数处理完整 URL
FINAL_BIN_URL=$(get_accelerated_url "${RAW_BASE_URL}/${BINARY_NAME}")
FINAL_SHA_URL=$(get_accelerated_url "${RAW_BASE_URL}/${SHA_NAME}")

echo "📥 开始下载二进制文件到 dist/ ..."
curl -L -o "dist/${BINARY_NAME}" "$FINAL_BIN_URL"

echo "📥 开始下载校验文件..."
curl -L -o "$SHA_NAME" "$FINAL_SHA_URL"

echo "🔍 正在验证文件完整性..."
if command -v sha256sum &> /dev/null; then
    sha256sum --check "$SHA_NAME"
elif command -v shasum &> /dev/null; then
    shasum -a 256 -c "$SHA_NAME"
else
    echo "❌ 错误: 找不到 sha256sum 或 shasum 命令，无法完成校验。"
    exit 1
fi

# 调用安装目录与启动服务配置
setup_service "dist/${BINARY_NAME}"