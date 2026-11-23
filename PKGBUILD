# Maintainer: <你的名字> <你的邮箱>
# Contributor: <共同维护者，可选>

pkgname=yunshu
pkgver=2.3.10.30
pkgrel=1
pkgdesc="Enterprise zero-trust (SASE) client by EagleCloud (proprietary)"
arch=('x86_64')
url="https://www.eaglecloud.com"
# 包内不含云枢自身的 EULA，故只能声明 custom:proprietary，
# 不可凭空引用某份具体协议。参考：google-chrome 用 custom:chrome
license=('custom:proprietary')

depends=(
  'gtk3'
  'nss'
  'libxss'
  'libxtst'
  'alsa-lib'
  'libcups'
  'xdg-utils'
  'systemd'
)
optdepends=(
  'pipewire: WebRTC / 屏幕共享'
  'libnotify: 桌面通知'
)

options=('!strip' 'emptydirs')
install="$pkgname.install"

# deb 直取厂商官方 CDN 的裸路径（不带 query string）：
#  - 路径中文件名不含企业标识（企业标识只出现在 ?response-content-disposition 的 filename 里）
#  - 裸路径无需签名参数，curl -I 实测 200 / 165198620 字节 / 支持断点续传
#  - 各企业的 Linux 客户端是同一份通用二进制（本机 _HAINWEI 包与 CDN _opple 包 MD5 一致）
#  - 因此本包不分发软件本体，makepkg 时由用户机器直接从厂商服务器下载
#
# 兜底：若厂商删除旧版本目录导致 404，将该版本 deb 转存到本人 GitHub Release，
#       并把 source 改为 https://github.com/<user>/<repo>/releases/download/<tag>/eaglecloud_yunshu_${pkgver}_amd64.deb
source=("https://pkg-cdn-hz0.sase.eagleyun.com/app/linux/${pkgver}/ubuntu/x86_64/eaglecloud_yunshu_${pkgver}_amd64.deb")
sha256sums=('6d77fbcbd37c8326e72aed9f93a1e6359b632d4f842b945a06b0a25bfb24e72a')

package() {
  local _deb="eaglecloud_yunshu_${pkgver}_amd64.deb"

  # 只解 Debian 的 data 负载，绝不执行原厂 preinst/postinst：
  #  - postinst 会做 DLP 注入（setuid LD_PRELOAD、改 ld.so.conf、hook cupsd 与浏览器）
  #  - postinst 会 systemctl enable 服务（违反 Arch 规范）
  bsdtar -xf "$_deb" -C "$srcdir" data.tar.xz
  bsdtar -xf "$srcdir/data.tar.xz" -C "$pkgdir"

  # deb 内布局为 ./apps/yunshu，规整到 /opt/apps/yunshu
  install -dm755 "$pkgdir/opt/apps"
  if [ -d "$pkgdir/apps/yunshu" ]; then
    mv "$pkgdir/apps/yunshu" "$pkgdir/opt/apps/"
    rmdir "$pkgdir/apps" 2>/dev/null || true
  fi

  local _app="$pkgdir/opt/apps/$pkgname"
  [ -d "$_app" ] || { error "解包后未找到 apps/yunshu，上游包结构可能已变"; exit 1; }

  # ── 移除 DLP / 杀毒 / 截图组件 ──────────────────────────────
  # files/plugin 约 237MB，内含 libeagleaudit.so、libsavapi.so、libhids.so、
  # libse.so、libwinehook_*.so 等 DLp 与杀毒模块。
  # 核心程序（yunshu-cross / yunshu-daemon / libtunnel.so）经 ldd 确认不依赖其中任何库。
  # 截图服务在厂商 daemon.sh 中被 `if [ -f libeagleaudit.so ]` 包裹，
  # 即它本就属于 DLP 功能，去掉 DLP 后不应保留。
  rm -rf "$_app/files/plugin"
  rm -f  "$_app/files/bin/screenshot_server"
  rm -f  "$_app/files/script/yunshu_screenshot.sh"
  rm -f  "$_app/files/system/yunshu-screenshot.service"
  # 注意：不要删 files/resources/app.asar.unpacked/node_modules/sdk
  # 它是 Electron 主进程启动时 require 的原生模块（含 package.json、index.js、
  # libsdk.so、ysapi_node.linux-x64-gnu.node）。删掉会导致主进程抛
  # `ENOENT ... node_modules/sdk/package.json`，应用无法启动。

  # ── 移除运行时产物，避免把凭证打进包 ────────────────────────
  # config.db 是运行时生成的 SQLite，内含有效 JWT、corp_code、设备序列号。
  # 策略缓存目录为 32 位 hex 命名，同样属运行时数据。
  #
  # 注意：socket/tmp/logs 这三个目录原厂 deb 里就有（内容是空的），
  # daemon 启动时要往里建 unix socket，缺了会启动即退出。
  # 所以只清空内容，目录本身必须保留。
  rm -f  "$_app/files/config/config.db"
  rm -rf "$_app"/files/config/[0-9a-f]*/
  find "$_app/files/tmp" "$_app/files/socket" "$_app/files/logs" \
       -mindepth 1 -delete 2>/dev/null || true
  install -dm755 "$_app"/files/{config,tmp,socket,logs}

  # ── 静态提供原厂 postinst 才会生成的配置 ────────────────────
  # 不放 post_install：静态文件可预测、卸载时随包自动清干净。
  # corpcode 留空，由用户首次登录时填写（各企业自行输入自己的标识）。
  if [ ! -f "$_app/files/config/private_ctl.conf" ]; then
    echo 'https://sp.eagleyun.cn' > "$_app/files/config/private_ctl.conf"
  fi
  if [ ! -f "$_app/files/config/app_config.json" ]; then
    printf '{\n  "corpcode":"",\n  "sp_addr":"https://sp.eagleyun.cn"\n}\n' \
      > "$_app/files/config/app_config.json"
  fi

  # ── 权限 ───────────────────────────────────────────────────
  # chrome-sandbox 刻意保持 0755，不设 setuid：
  # Arch 默认 kernel.unprivileged_userns_clone=1，Chromium 沙箱可正常工作。
  # 实测现有 UI 以 `--disable-http2` 启动（无 --no-sandbox）且零沙箱报错。
  chmod 755 "$_app/files/chrome-sandbox"

  # 原厂 deb 里部分二进制没有可执行位（实测 yunshu-daemon 是 -rw-r--r--），
  # 靠 postinst 里的 `chmod +x` 补。我们不跑 postinst，必须在此补上，
  # 否则 systemd 启动会报 status=203/EXEC。
  chmod 755 "$_app/files/bin/yunshu-daemon"
  chmod 755 "$_app"/files/bin/yunshu* 2>/dev/null || true

  # 注意：`u+rwX,go+rX` 里的 X 只对目录和「本已有 x 位」的文件加执行权限，
  # 不会给原本没有 x 位的普通文件补上——这正是上面需要显式 chmod 的原因。
  chmod -R u+rwX,go+rX "$_app"

  # ── systemd 单元 ────────────────────────────────────────────
  # 只投放 daemon 与 updater 的 unit；不 enable（遵循 Arch 规范）。
  # 不投放 yunshu-screenshot.service（属 DLP）。
  install -Dm644 "$_app/files/system/${pkgname}-daemon.service" \
    "$pkgdir/usr/lib/systemd/system/${pkgname}-daemon.service"
  install -Dm644 "$_app/files/system/${pkgname}-updater.service" \
    "$pkgdir/usr/lib/systemd/system/${pkgname}-updater.service"

  # 用户级 UI 服务：UI 是 Electron 图形程序，应在用户会话内运行
  install -dm755 "$pkgdir/usr/lib/systemd/user"
  cat > "$pkgdir/usr/lib/systemd/user/${pkgname}-cross.service" <<-EOF
	[Unit]
	Description=yunshu-cross (YunShu ZeroTrust client UI)
	PartOf=graphical-session.target
	After=graphical-session.target

	[Service]
	ExecStart=/opt/apps/${pkgname}/files/${pkgname}-cross --disable-http2
	RestartPreventExitStatus=SIGABRT
	Restart=on-abnormal
	StandardOutput=null

	[Install]
	WantedBy=graphical-session.target
	EOF

  # ── shell 入口与桌面集成 ────────────────────────────────────
  install -dm755 "$pkgdir/usr/bin"
  ln -sf "/opt/apps/${pkgname}/files/bin/${pkgname}" "$pkgdir/usr/bin/${pkgname}"

  install -Dm644 "$_app/entries/applications/${pkgname}.desktop" \
    "$pkgdir/usr/share/applications/${pkgname}.desktop"
  install -Dm644 "$_app/entries/icons/hicolor/scalable/apps/${pkgname}.png" \
    "$pkgdir/usr/share/icons/hicolor/scalable/apps/${pkgname}.png"

  # ── 修补上游缺陷：desktop 的 Name= 为空 ─────────────────────
  # 原文件只有 Name[zh_CN]=云枢，Name= 是空串，非中文 locale 下菜单显示空白。
  # Name 是 desktop 规范的必填默认值，此处补英文名，保留中文名。
  sed -i 's/^Name=$/Name=YunShu/' "$pkgdir/usr/share/applications/${pkgname}.desktop"
}
