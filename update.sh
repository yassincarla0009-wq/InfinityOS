#!/bin/bash
# Infinity OS maintenance fixes — run as root by "Infinity OS Updates".
# Each fix is applied ONCE per laptop (marker in /var/lib/infinityos/applied/),
# so repeat updates are fast and only new fixes actually run.

REPO="https://raw.githubusercontent.com/yassincarla0009-wq/InfinityOS/main"
STATE=/var/lib/infinityos/applied
mkdir -p "$STATE"

# apply_once <id> <function>: run the fix only if it hasn't succeeded before.
# If it fails (e.g. no internet) it is NOT marked, so it retries next update.
apply_once() {
  local id="$1"; local fn="$2"
  if [ -f "$STATE/$id" ]; then
    echo "   [skip] $id (already applied)"
    return 0
  fi
  echo ">> applying: $id"
  if "$fn"; then
    touch "$STATE/$id"
    echo "   [done] $id"
  else
    echo "   [will retry] $id (failed - likely internet)"
  fi
}

# ===== Always-current, instant (just writes files, no apt) =====

install_updater_app() {
  cat > /usr/local/bin/infinityos-update <<'SH'
#!/bin/bash
FIX_URL="https://raw.githubusercontent.com/yassincarla0009-wq/InfinityOS/main/update.sh"
SCRIPT='echo "===== Infinity OS Updates ====="; echo;
echo ">> Updating system packages..."; sudo apt update && sudo apt full-upgrade -y; echo;
echo ">> Applying latest Infinity OS fixes..."; ( wget -qO- '"$FIX_URL"' | sudo bash ) 2>/dev/null || echo "   (no extra fixes)";
echo; echo "Infinity OS is up to date. Press Enter to close."; read'
for t in gnome-terminal x-terminal-emulator xterm konsole; do
  if command -v "$t" >/dev/null 2>&1; then
    if [ "$t" = "gnome-terminal" ]; then exec gnome-terminal -- bash -c "$SCRIPT"; else exec "$t" -e bash -c "$SCRIPT"; fi
  fi
done
exec update-manager
SH
  chmod +x /usr/local/bin/infinityos-update
}

install_notifier() {
  cat > /usr/local/bin/infinityos-update-check <<'SH'
#!/bin/bash
REPO="https://raw.githubusercontent.com/yassincarla0009-wq/InfinityOS/main"
sleep 25
LOCAL=$(cat /etc/infinityos/version 2>/dev/null | tr -dc '0-9'); LOCAL=${LOCAL:-0}
REMOTE=$(wget -qO- "$REPO/version" 2>/dev/null | tr -dc '0-9')
[ -z "$REMOTE" ] && exit 0
if [ "$REMOTE" -gt "$LOCAL" ] 2>/dev/null; then
  notify-send -u normal -i system-software-update \
    "Infinity OS — Update available" \
    "A new update is ready. Open \"Infinity OS Updates\" to install it."
fi
SH
  chmod +x /usr/local/bin/infinityos-update-check
  mkdir -p /etc/xdg/autostart
  cat > /etc/xdg/autostart/infinityos-update-check.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Infinity OS Update Check
Exec=/usr/local/bin/infinityos-update-check
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
}

install_firstboot() {
  cat > /usr/local/bin/infinityos-firstboot <<'SH'
#!/bin/bash
REPO="https://raw.githubusercontent.com/yassincarla0009-wq/InfinityOS/main"
mkdir -p /var/lib/infinityos
if wget -qO- "$REPO/update.sh" 2>/dev/null | bash; then
  touch /var/lib/infinityos/firstboot-done
  systemctl disable infinityos-firstboot.service 2>/dev/null || true
fi
SH
  chmod +x /usr/local/bin/infinityos-firstboot
  cat > /etc/systemd/system/infinityos-firstboot.service <<EOF
[Unit]
Description=Infinity OS first-boot fixes
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/infinityos/firstboot-done

[Service]
Type=oneshot
ExecStart=/usr/local/bin/infinityos-firstboot

[Install]
WantedBy=multi-user.target
EOF
  systemctl enable infinityos-firstboot.service 2>/dev/null || true
}

# ===== One-time fixes (the slow / apt ones) =====

fix_dns() {
  cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=94.140.14.14 94.140.15.15
FallbackDNS=1.1.1.1 8.8.8.8
DNSStubListener=yes
EOF
  [ -e /etc/resolv.conf ] || ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
  systemctl enable systemd-resolved 2>/dev/null || true
  systemctl restart systemd-resolved 2>/dev/null || true
  return 0
}

fix_apt_sources() {
  cat > /etc/apt/sources.list <<EOF
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF
  apt-get update -y    # retries next time if this fails (no internet)
}

feat_cmatrix() {
  apt-get install -y cmatrix
}

fix_camera() {
  apt-get install -y cheese cheese-common \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
    gstreamer1.0-tools gstreamer1.0-libav \
    v4l-utils libv4l-0 || return 1
  apt-get install -y --reinstall cheese cheese-common 2>/dev/null || true
  for u in $(ls /home 2>/dev/null); do usermod -aG video "$u" 2>/dev/null || true; done
  return 0
}

fix_wine_exe() {
  command -v wine >/dev/null 2>&1 || apt-get install -y wine 2>/dev/null || true
  cat > /usr/local/bin/infinityos-run-windows <<'SH'
#!/bin/bash
f="$1"
case "${f,,}" in
  *.msi) exec wine msiexec /i "$f" ;;
  *)     exec wine "$f" ;;
esac
SH
  chmod +x /usr/local/bin/infinityos-run-windows
  cat > /usr/share/applications/infinityos-wine.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Run Windows Program (Wine)
Exec=/usr/local/bin/infinityos-run-windows %f
NoDisplay=true
MimeType=application/x-ms-dos-executable;application/x-msdownload;application/vnd.microsoft.portable-executable;application/x-msdos-program;application/x-msi;
EOF
  update-desktop-database /usr/share/applications 2>/dev/null || true
  local MIMEFILE=/etc/xdg/mimeapps.list
  touch "$MIMEFILE"
  for mt in application/x-ms-dos-executable application/x-msdownload application/vnd.microsoft.portable-executable application/x-msdos-program application/x-msi; do
    sed -i "\\#^${mt}=#d" "$MIMEFILE"
  done
  grep -q '^\[Default Applications\]' "$MIMEFILE" || echo '[Default Applications]' >> "$MIMEFILE"
  sed -i '/^\[Default Applications\]/a application/x-ms-dos-executable=infinityos-wine.desktop\napplication/x-msdownload=infinityos-wine.desktop\napplication/vnd.microsoft.portable-executable=infinityos-wine.desktop\napplication/x-msdos-program=infinityos-wine.desktop\napplication/x-msi=infinityos-wine.desktop' "$MIMEFILE"
  return 0
}

# ===== Run =====
echo "Checking Infinity OS fixes (each applies once per laptop)..."

# keep the update system itself current every time (instant, no apt)
install_updater_app
install_notifier
install_firstboot

# one-time fixes — order matters: sources before the installs
apply_once dns          fix_dns
apply_once apt-sources  fix_apt_sources
apply_once cmatrix      feat_cmatrix
apply_once camera       fix_camera
apply_once wine-exe     fix_wine_exe

# record the version we're now at (so the notifier knows we're current)
mkdir -p /etc/infinityos
wget -qO- "$REPO/version" 2>/dev/null | tr -dc '0-9' > /etc/infinityos/version || true

echo "Infinity OS fixes complete."
