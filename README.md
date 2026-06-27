# 袖珍 sing-box with Nanoswift

<p align="left">
  <strong>⚡ sing-box + nanoswift 体积不到 20M（9-12M），全图形化操作的 sing-box 便捷管理工具 ⚡</strong>
</p>
<p align="left">
  <strong>⚡ 安装之前，请检查1080，9090端口有没有被占用 ⚡</strong>
</p>
<p align="left">
  <strong>⚡ 安装完成之后，面板访问：http://127.0.0.1:9090/ui 默认密码：12345678 ⚡</strong>
</p>
---

既拥有 **sing-box** 的完整强大功能，又兼具 **YACD** 直接管理节点的便利性。  
**全图形化操作，告别手动编写繁琐的配置，就是这么简单！**

## ✨ 核心特性

* **极致轻量**：整体体积不到 20MB(9-12M)，精简高效。
* **全功能保留**：完整保留 sing-box 的所有功能，一键编译集成，紧跟官方升级脚步。
* **图形化管理**：集成 YACD 面板，节点、分流、策略组全可视化操作。
* **小白友好**：无需手动编写 YAML/JSON，点点鼠标即可完成日常管理与切换。不再担心内外网速度互相影响，分流不清，DNS、WebRTC泄漏的麻烦。
---

## 🚀 快速安装/重装

### 🐧 Unix (Linux /Openwrt / macOS) 平台

请根据您的网络环境，选择以下任意一条命令复制到终端执行：

**IPv4 优先下载：**
```bash
bash -c "$(curl -fsSL https://v4.gh-proxy.org/https://raw.githubusercontent.com/is928joe-jpg/sing-box-with-nanoswift/refs/heads/main/install.sh)"
```

**IPv6 优先下载：**
```bash
bash -c "$(curl -fsSL https://v6.gh-proxy.org/https://raw.githubusercontent.com/is928joe-jpg/sing-box-with-nanoswift/refs/heads/main/install.sh)"
```

**CDN 加速下载：**
```bash
bash -c "$(curl -fsSL https://cdn.gh-proxy.org/https://raw.githubusercontent.com/is928joe-jpg/sing-box-with-nanoswift/refs/heads/main/install.sh)"
```

**尝鲜版下载：**
```bash
bash -c "$(curl -fsSL https://cdn.gh-proxy.org/https://raw.githubusercontent.com/is928joe-jpg/sing-box-with-nanoswift/refs/heads/main/install_unix_lastest.sh)"
```

---

### 🪟 Windows 平台

请根据您的网络环境，选择以下任意一条命令在 **PowerShell** 或 **CMD** 中执行：

**IPv4 优先下载：**
```powershell
curl -L -o install_windows.bat https://v4.gh-proxy.org/https://raw.githubusercontent.com/is928joe-jpg/sing-box-with-nanoswift/refs/heads/main/install_windows.bat && install_windows.bat
```

**IPv6 优先下载：**
```powershell
curl -L -o install_windows.bat https://v6.gh-proxy.org/https://raw.githubusercontent.com/is928joe-jpg/sing-box-with-nanoswift/refs/heads/main/install_windows.bat && install_windows.bat
```

**CDN 加速下载：**
```powershell
curl -L -o install_windows.bat https://cdn.gh-proxy.org/https://raw.githubusercontent.com/is928joe-jpg/sing-box-with-nanoswift/refs/heads/main/install_windows.bat && install_windows.bat
```

**尝鲜版下载：**
```bash
bash -c "$(curl -fsSL https://cdn.gh-proxy.org/https://raw.githubusercontent.com/is928joe-jpg/sing-box-with-nanoswift/refs/heads/main/install_windows_lastest.bat)"
```
---

## 📸 界面预览

### 🏠 Nanoswift 首页
<a href="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/nanoswift_index.png?raw=true" target="_blank">
  <img src="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/nanoswift_index.png?raw=true" alt="Nanoswift 首页" width="100%">
</a>

### 📋 分流规则管理
<a href="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/nanoswift_rules.png?raw=true" target="_blank">
  <img src="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/nanoswift_rules.png?raw=true" alt="分流规则管理" width="100%">
</a>

### 🌐 节点池管理
<a href="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/nanoswift_nodes.png?raw=true" target="_blank">
  <img src="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/nanoswift_nodes.png?raw=true" alt="节点池管理" width="100%">
</a>

### 📦 节点组管理
<a href="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/nanoswift_group.png?raw=true" target="_blank">
  <img src="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/nanoswift_group.png?raw=true" alt="节点组管理" width="100%">
</a>

### 🪟 Windows 安装界面
<a href="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/nanoswift_windows.png?raw=true" target="_blank">
  <img src="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/nanoswift_windows.png?raw=true" alt="Windows 安装界面" width="100%">
</a>

### 🪟 节点订阅界面
<a href="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/nanoswift_sub.png?raw=true" target="_blank">
  <img src="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/nanoswift_sub.png?raw=true" alt="节点订阅界面" width="100%">
</a>

### 🪟 新版本界面提示
<a href="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/nano_new_version.png?raw=true" target="_blank">
  <img src="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/nano_new_version.png?raw=true" alt="新版本界面提示" width="100%">
</a>

### 🪟 安装在本来吃灰的小米AX3000T上
<a href="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/xiaomi-AX3000T.png?raw=true" target="_blank">
  <img src="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/xiaomi-AX3000T.png?raw=true" alt="小米AX3000T上" width="100%">
</a>
<a href="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/xiaomi-AX3000T-1.png?raw=true" target="_blank">
  <img src="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/xiaomi-AX3000T-1.png?raw=true" alt="小米AX3000T上" width="100%">
</a>
### 小米AX3000T等256M小内存机器可以优化，并给个swap
<a href="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/xiaomi-AX3000T-2.png?raw=true" target="_blank">
  <img src="https://github.com/is928joe-jpg/sing-box-with-nanoswift/blob/main/images/xiaomi-AX3000T-2.png?raw=true" alt="小米AX3000T上" width="100%">
</a>
---

---

## 更新说明与致谢

> **💡 更新摘要**
> 本次更新**修复了 `install.sh` 脚本在部分环境下可能导致平台无法正确识别的问题**。我们采用了兼容性更强的检测方法，以确保脚本在各种系统架构下都能稳定运行。
> 核心提示：**sing-box 核心原生支持全平台**。

这个项目起初只是为了方便自己使用，没想到分享出来后能得到这么多朋友的支持。随着使用人数的增加，难免会遇到一些未知的边界情况。

**开源离不开大家的共同维护！** 如果你在使用过程中遇到任何问题或 Bug，请直接提交 Issue 或指出。每一份反馈都是让它变得更好的动力，期待我们一起把这个工具做得更完美！🤝

---

## 各平台服务移除说明

如果你需要卸载或移除服务，可以参考以下对应平台的命令。本程序为**绿色软件**，在成功停止并执行移除命令后，**直接删除安装目录文件夹即可**，对系统不会残留任何负面影响。

### 🔹 Windows

在**管理员权限**的命令提示符（CMD）中运行：

```cmd
net stop nanoswift
sc delete nanoswift 

```

### 🔹 Linux

```bash
systemctl stop sing-box
systemctl disable sing-box

```

### 🔹 OpenWrt

```bash
/etc/init.d/sing-box stop
/etc/init.d/sing-box disable

```

### 🔹 macOS

根据你当初的安装方式，选择以下一种方法：

**方法 A：通过系统 `launchd` 服务运行（常规手动安装）**

```bash
# 1. 停止并注销服务（若是系统全局服务，需加 sudo）
sudo launchctl bootout system /Library/LaunchDaemons/ch.moe.sing-box.plist

# 2. 删除对应的服务配置文件
sudo rm /Library/LaunchDaemons/ch.moe.sing-box.plist

```

> *注：若你修改过服务名或 `.plist` 文件名，请按实际名称进行替换。*

**方法 B：通过 Homebrew 包管理器安装**

```bash
# 1. 停止并禁用服务
brew services stop sing-box

# 2. 卸载程序核心
brew uninstall sing-box

```

## Star History

<a href="https://www.star-history.com/?type=date&repos=is928joe-jpg%2Fsing-box-with-nanoswift">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=is928joe-jpg/sing-box-with-nanoswift&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=is928joe-jpg/sing-box-with-nanoswift&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=is928joe-jpg/sing-box-with-nanoswift&type=date&legend=top-left" />
 </picture>
</a>