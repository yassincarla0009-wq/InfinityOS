#!/usr/bin/env bash
set -e
cd /root/infinityos/work
ROOT=edit

echo "=== Binding mounts ==="
mount --bind /dev  $ROOT/dev
mount --bind /run  $ROOT/run
mount -t proc proc $ROOT/proc
mount -t sysfs sys $ROOT/sys
mount -t devpts devpts $ROOT/dev/pts 2>/dev/null || true
cp /etc/resolv.conf $ROOT/etc/resolv.conf

cat > $ROOT/tmp/fin.sh <<'EOS'
#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

echo "=== FIX THE OS: repair broken/half-configured packages ==="
apt-get update -y || true
dpkg --configure -a || true
apt-get -f install -y || true
apt-get install -y --reinstall gnome-control-center gnome-control-center-data nautilus || true
# ensure desktop-icons (right-click menu) extension present
apt-get install -y gnome-shell-extension-desktop-icons-ng || true

echo "=== RIGHT-CLICK FIX: drop the extension override, let Ubuntu defaults run ==="
# Remove the override that was disabling dock/desktop-icons; keep ONLY safe GTK theming.
cat > /usr/share/glib-2.0/schemas/99_infinityos.gschema.override <<EOF
[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/infinityos.png'
picture-uri-dark='file:///usr/share/backgrounds/infinityos.png'
picture-options='zoom'
primary-color='#0b1230'

[org.gnome.desktop.screensaver]
picture-uri='file:///usr/share/backgrounds/infinityos.png'
picture-options='zoom'

[org.gnome.desktop.interface]
gtk-theme='WhiteSur-Dark'
icon-theme='WhiteSur-dark'
color-scheme='prefer-dark'
enable-animations=true
enable-hot-corners=true
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas || true

echo "=== Infinity OS Updates (software updates over WiFi) ==="
cat > /usr/local/bin/infinityos-update <<'SH'
#!/bin/bash
# Infinity OS Updater - pulls all software updates over the internet
if command -v update-manager >/dev/null 2>&1; then
    exec update-manager
else
    x-terminal-emulator -e bash -c 'echo "=== Infinity OS Updates ==="; \
      sudo apt update && sudo apt full-upgrade -y; \
      echo; echo "Infinity OS is up to date. Press Enter to close."; read'
fi
SH
chmod +x /usr/local/bin/infinityos-update
cat > /usr/share/applications/infinityos-updates.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Infinity OS Updates
GenericName=Software Updater
Comment=Update Infinity OS and all apps over the internet (WiFi)
Exec=/usr/local/bin/infinityos-update
Icon=system-software-update
Terminal=false
Categories=System;Settings;
Keywords=update;upgrade;software;infinity;
StartupNotify=true
EOF
mkdir -p /etc/skel/Desktop
cp /usr/share/applications/infinityos-updates.desktop /etc/skel/Desktop/ 2>/dev/null || true
chmod +x /etc/skel/Desktop/infinityos-updates.desktop 2>/dev/null || true
# NO forced/automatic updates (unlike Windows) -> fully manual via the Updater
cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
APT::Periodic::Download-Upgradeable-Packages "0";
EOF
systemctl mask unattended-upgrades.service 2>/dev/null || true
systemctl disable unattended-upgrades.service 2>/dev/null || true

echo "=== FINAL CHECK ==="
[ -x /usr/bin/gnome-control-center ] && echo "FINAL SETTINGS OK" || echo "FINAL SETTINGS MISSING"
[ -x /usr/local/bin/infinityos-update ] && echo "FINAL UPDATER OK" || echo "FINAL UPDATER MISSING"
ls /usr/share/gnome-shell/extensions/ 2>/dev/null | grep -qi ding && echo "FINAL DING OK (right-click)" || echo "FINAL DING check-session"

apt-get clean
rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*
rm -f /etc/resolv.conf /etc/hosts
echo "INNER_FIN_DONE"
EOS
chmod +x $ROOT/tmp/fin.sh
chroot $ROOT /tmp/fin.sh
rm -f $ROOT/tmp/fin.sh

umount $ROOT/dev/pts 2>/dev/null || true
umount $ROOT/proc 2>/dev/null || true
umount $ROOT/sys  2>/dev/null || true
umount $ROOT/run  2>/dev/null || true
umount $ROOT/dev  2>/dev/null || true
echo "DONE_FINALFIX"
