# yunshu-arch

Arch Linux / CachyOS / Manjaro 上的[云枢（YunShu）](https://www.eaglecloud.com)零信任客户端打包。

提供两种安装方式：pacman 仓库（一条命令）或自行构建。

---

## ⚠️ 本包与原厂安装包的差异

**这不是厂商官方发行版。** 为了让软件能在 Arch 上干净安装、可被 pacman 完整管理，本包主动移除了：

| 组件 | 原厂 | 本包 | 原因 |
|---|---|---|---|
| DLP 数据防泄漏（打印/浏览器/USB 审计） | ✅ | ❌ | 需 setuid 注入 + hook 系统服务 |
| 截图审计服务 | ✅ | ❌ | 属 DLP 功能 |
| 厂商自更新器 `yunshu-updater` | ✅ | ❌ | 会绕过 pacman 覆盖 `/opt` |
| 内核级 hook（setuid `LD_PRELOAD`） | ✅ | ❌ | 会 hook cupsd 与浏览器 |

**如果你的公司要求通过云枢接受 DLP 合规审计，本包无法满足该要求，请使用厂商官方安装包。**

保留的功能：VPN 隧道（`yunshu-daemon`）、登录认证界面（`yunshu-cross`）、桌面集成。

---

## 方式一：pacman 仓库

在 `/etc/pacman.conf` 末尾加入：

```ini
[yunshu]
Server = https://github.com/Drivpe/yunshu-arch/releases/latest/download
SigLevel = Optional TrustAll
```

```bash
sudo pacman -Sy
sudo pacman -S yunshu
```

> **`SigLevel` 那一行不能省。** 本仓库未做 GPG 签名，不加会被 pacman 以「缺少签名」拒绝。
> `TrustAll` 信任此仓库的全部内容。包由本仓库从厂商 CDN 拉取并原样重建，
> 安装前你可自行核对数据库里的 `sha256`。

## 方式二：自行构建

不想放宽签名策略的话：

```bash
git clone https://github.com/Drivpe/yunshu-arch.git
cd yunshu-arch
makepkg -si
```

需要 `base-devel`。包由你本机构建，不经过第三方签名校验。

---

## 安装后

安装过程中会询问是否启用后台服务，回车即启用。若当时跳过了：

```bash
sudo systemctl enable --now yunshu-daemon
```

启动界面：

```bash
yunshu
```

或从应用菜单搜索「云枢 / YunShu」。

**首次登录需填写「企业标识」**，请向你的企业 IT 管理员索取。

---

## 卸载

```bash
sudo pacman -Rns yunshu
```

会清理程序文件、系统集成项，以及 `/opt/apps/yunshu` 下**含登录凭证**的 `config.db` 与策略缓存。

**保留**（遵循 Arch「包不碰家目录」惯例）：

```
~/.config/YunshuCross/
```

该目录含 Cookies 与登录态。要与凭证一起彻底清除：

```bash
rm -rf ~/.config/YunshuCross
```

---

## 这个仓库怎么工作

```
厂商 CDN (eaglecloud_yunshu_<ver>_amd64.deb)
        │
        │  GitHub Actions 每日探测厂商公开版本接口
        ▼
    makepkg 重建
        │
        ├─→ Release 附件：yunshu-<ver>-1-x86_64.pkg.tar.zst（110MB）
        │                  yunshu.db / yunshu.files（pacman 数据库）
        │
        └─→ git：PKGBUILD、yunshu.install、docs/
```

包不进 git（GitHub 单文件上限 100MB），而是作为 Release 附件；
数据库文件也放在 Release，`latest/download` 作为 pacman 的 `Server`。

### 为什么 `source=` 指向厂商 CDN

厂商对所有企业分发的是**同一份通用 Linux 二进制**（实测本地 `_HAINWEI` 包与 CDN 上 `_opple` 包的 MD5 一致），
企业差异靠登录时的 corpcode 区分。CDN 裸路径无需 token，所以：

- 本仓库**不复制、不托管**该软件，`makepkg` 时由你的机器直接从厂商服务器下载
- `pkgver` 变化时 URL 自动跟随

### 已知限制

- 仅 `x86_64`
- 版本探测依赖厂商公开接口，可能滞后于某些企业渠道；发现新版请开 issue
- 厂商若删除旧版本目录，`source=` 会 404，需等维护者转存备用镜像

---

## 许可

本软件为闭源商业软件，版权归杭州亿格云科技（EagleCloud）所有。
本仓库仅提供打包配方，不主张对软件本身的任何权利。
使用前请自行确认你所在组织允许在 Arch 上以本方式使用该客户端。
