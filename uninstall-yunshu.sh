#!/bin/bash
# 云枢 (YunShu) 完整卸载脚本
#
# 处理三类残留：
#   1. pacman 管理的包内容          → pacman -Rns 自动清理
#   2. 包运行时产生的凭证与缓存      → 包的 post_remove 清理
#   3. 安装时手工添加的系统配置      → 本脚本清理
#      （[yunshu] 仓库段、/etc/systemd/user 下的 unit、同步缓存）
#
# 用法：
#   sudo bash uninstall-yunshu-github.sh          # 保留用户配置
#   sudo bash uninstall-yunshu-github.sh --purge  # 连同 ~/.config/YunshuCross 一起删

set -uo pipefail

PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

if [ "$(id -u)" -ne 0 ]; then
  echo "请用 sudo 运行：sudo bash $0 [--purge]" >&2
  exit 1
fi

echo "==> 1/5 停止并禁用服务"
systemctl disable --now yunshu-daemon.service yunshu-updater.service 2>/dev/null
# 用户级 UI 服务：对每个真实用户停一次
getent passwd | awk -F: '$3>=1000 && $3<65534 {print $1":"$6}' | while IFS=: read -r u h; do
  sudo -u "$u" XDG_RUNTIME_DIR="/run/user/$(id -u "$u")" \
    systemctl --user disable --now yunshu-cross.service 2>/dev/null
done

echo "==> 2/5 卸载软件包（触发 post_remove 清理凭证）"
if pacman -Q yunshu >/dev/null 2>&1; then
  pacman -Rns --noconfirm yunshu
else
  echo "    未安装，跳过"
fi

echo "==> 3/5 移除 [yunshu] 仓库段"
CONF=/etc/pacman.conf
if grep -q '^\[yunshu\]' "$CONF"; then
  cp "$CONF" "${CONF}.bak-yunshu-$(date +%Y%m%d%H%M%S)"
  # 删除 [yunshu] 段（从段头到下一个 [ 段头或文件尾）
  awk '
    /^\[yunshu\]$/ { skip=1; next }
    skip && /^\[/ { skip=0 }
    !skip { print }
  ' "$CONF" > "${CONF}.new"
  # 收掉可能留下的连续空行
  cat -s "${CONF}.new" > "$CONF"
  rm -f "${CONF}.new"
  echo "    已移除（备份在同目录 .bak-yunshu-*）"
else
  echo "    未找到 [yunshu] 段，跳过"
fi

echo "==> 4/5 清理手工安装遗留与同步缓存"
# 早期手工安装时创建的用户级 unit（不是包内容）
rm -f /etc/systemd/user/yunshu-cross.service
rmdir /etc/systemd/user 2>/dev/null
systemctl daemon-reload 2>/dev/null
systemctl --user daemon-reload 2>/dev/null

# pacman 下载的仓库数据库缓存
rm -f /var/lib/pacman/sync/yunshu.db /var/lib/pacman/sync/yunshu.db.sig \
      /var/lib/pacman/sync/yunshu.files /var/lib/pacman/sync/yunshu.files.sig

echo "==> 5/5 清理用户级自启动与残留"
getent passwd | awk -F: '$3>=1000 && $3<65534 {print $6}' | while read -r h; do
  rm -f "$h/.config/autostart/yunshu.desktop"
done
rm -rf /opt/apps/yunshu 2>/dev/null
rmdir /opt/apps 2>/dev/null

if [ "$PURGE" -eq 1 ]; then
  getent passwd | awk -F: '$3>=1000 && $3<65534 {print $6}' | while read -r h; do
    rm -rf "$h/.config/YunshuCross"
  done
  echo "    已连同 ~/.config/YunshuCross 一并删除"
fi

cat <<'EOF'

┌──────────────────────────────────────────────────────────────┐
│  卸载完成                                                    │
└──────────────────────────────────────────────────────────────┘

EOF

if [ "$PURGE" -eq 0 ] && [ -d "$HOME/.config/YunshuCross" ]; then
  cat <<'EOF'
用户配置目录仍保留（含 Cookies 与登录态）：

    ~/.config/YunshuCross

如需连凭证一起清除：

    rm -rf ~/.config/YunshuCross
    或重新运行本脚本加 --purge

EOF
fi

echo "自查命令（应无输出）："
echo "  pacman -Q yunshu; grep -c '^\[yunshu\]' /etc/pacman.conf; ls /opt/apps/yunshu"
