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

cat > $ROOT/tmp/retry.sh <<'EOS'
#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

echo "=== Clean + robust apt update (fix hash mismatch) ==="
dpkg --add-architecture i386
for i in 1 2 3; do
  rm -rf /var/lib/apt/lists/* ; apt-get clean
  if apt-get update -y; then echo "APT UPDATE OK (try $i)"; break; fi
  echo "retry apt update..."; sleep 3
done

echo "=== WineHQ (run .exe/.msi) ==="
install -d -m 0755 /etc/apt/keyrings
wget -q -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key || true
wget -q -O /etc/apt/sources.list.d/winehq-jammy.sources https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources || true
apt-get update -y || true
apt-get install -y --install-recommends winehq-stable || apt-get install -y wine winetricks || apt-get install -y wine || true
apt-get install -y winetricks || true
command -v wine >/dev/null 2>&1 && echo "STATUS WINE OK ($(wine --version 2>/dev/null))" || echo "STATUS WINE MISSING"

echo "=== Gaming stack ==="
apt-get install -y steam-installer lutris gamemode mangohud \
    mesa-vulkan-drivers mesa-vulkan-drivers:i386 libgl1-mesa-dri:i386 vulkan-tools || true
command -v lutris    >/dev/null 2>&1 && echo "STATUS LUTRIS OK"   || echo "STATUS LUTRIS MISSING"
command -v gamemoded >/dev/null 2>&1 && echo "STATUS GAMEMODE OK" || echo "STATUS GAMEMODE MISSING"
command -v mangohud  >/dev/null 2>&1 && echo "STATUS MANGOHUD OK" || echo "STATUS MANGOHUD MISSING"
( [ -e /usr/games/steam ] || [ -e /usr/bin/steam ] ) && echo "STATUS STEAM OK" || echo "STATUS STEAM first-run"

echo "=== Variety (internet wallpapers) + right-click extras ==="
apt-get install -y variety nautilus-admin || true
command -v variety >/dev/null 2>&1 && echo "STATUS VARIETY OK" || echo "STATUS VARIETY MISSING"

echo "=== Ensure Users panel present (multiple accounts) ==="
apt-get install -y gnome-control-center >/dev/null 2>&1 || true
[ -x /usr/bin/gnome-control-center ] && echo "STATUS USERS-PANEL OK" || echo "STATUS USERS-PANEL MISSING"

echo "=== FIX: restore dock + desktop icons (right-click) + user-theme ==="
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
enable-hot-corners=true

[org.gnome.shell]
enabled-extensions=['ubuntu-dock@ubuntu.com', 'ding@rastersoft.com', 'user-theme@gnome-shell-extensions.gcampax.github.com']

[org.gnome.shell.extensions.user-theme]
name='WhiteSur-Dark'
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas || true

echo "=== FINAL STATUS ==="
command -v wine     >/dev/null 2>&1 && echo "FINAL WINE OK"     || echo "FINAL WINE MISSING"
command -v lutris   >/dev/null 2>&1 && echo "FINAL LUTRIS OK"   || echo "FINAL LUTRIS MISSING"
command -v mangohud >/dev/null 2>&1 && echo "FINAL MANGOHUD OK" || echo "FINAL MANGOHUD MISSING"
command -v variety  >/dev/null 2>&1 && echo "FINAL VARIETY OK"  || echo "FINAL VARIETY MISSING"

apt-get clean
rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*
rm -f /etc/resolv.conf /etc/hosts
echo "INNER_RETRY_DONE"
EOS
chmod +x $ROOT/tmp/retry.sh
chroot $ROOT /tmp/retry.sh
rm -f $ROOT/tmp/retry.sh

umount $ROOT/dev/pts 2>/dev/null || true
umount $ROOT/proc 2>/dev/null || true
umount $ROOT/sys  2>/dev/null || true
umount $ROOT/run  2>/dev/null || true
umount $ROOT/dev  2>/dev/null || true
echo "DONE_RETRY"
