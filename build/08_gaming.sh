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

cat > $ROOT/tmp/game.sh <<'EOS'
#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

echo "=== Enable 32-bit (needed for Wine/Steam) ==="
dpkg --add-architecture i386

echo "=== WineHQ repo (latest stable Wine) ==="
install -d -m 0755 /etc/apt/keyrings
wget -q -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key || true
wget -q -O /etc/apt/sources.list.d/winehq-jammy.sources https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources || true
apt-get update -y || true

echo "=== Install Wine (run .exe/.msi) ==="
apt-get install -y --install-recommends winehq-stable || apt-get install -y wine wine64 wine32 || apt-get install -y wine || true
apt-get install -y winetricks || true
if command -v wine >/dev/null 2>&1; then echo "STATUS WINE OK ($(wine --version 2>/dev/null))"; else echo "STATUS WINE MISSING"; fi

echo "=== Gaming stack (Steam/Proton, Lutris, GameMode, MangoHud, Vulkan) ==="
apt-get install -y steam-installer lutris gamemode mangohud \
    mesa-vulkan-drivers mesa-vulkan-drivers:i386 libgl1-mesa-dri:i386 \
    vulkan-tools || true
command -v lutris    >/dev/null 2>&1 && echo "STATUS LUTRIS OK"    || echo "STATUS LUTRIS MISSING"
command -v gamemoded >/dev/null 2>&1 && echo "STATUS GAMEMODE OK"  || echo "STATUS GAMEMODE MISSING"
command -v mangohud  >/dev/null 2>&1 && echo "STATUS MANGOHUD OK"  || echo "STATUS MANGOHUD MISSING"
if [ -e /usr/games/steam ] || [ -e /usr/bin/steam ]; then echo "STATUS STEAM OK"; else echo "STATUS STEAM first-run-downloads"; fi

echo "=== Make .exe / .msi open with Wine by default ==="
mkdir -p /usr/share/applications
cat > /usr/share/applications/wine-exe.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Run with Wine (Windows app)
Exec=wine %f
MimeType=application/x-ms-dos-executable;application/x-msdownload;application/x-msi;application/x-msdos-program;
NoDisplay=true
EOF

echo "=== FINAL GAMING STATUS ==="
command -v wine      >/dev/null 2>&1 && echo "FINAL WINE OK"     || echo "FINAL WINE MISSING"
command -v lutris    >/dev/null 2>&1 && echo "FINAL LUTRIS OK"   || echo "FINAL LUTRIS MISSING"
command -v mangohud  >/dev/null 2>&1 && echo "FINAL MANGOHUD OK" || echo "FINAL MANGOHUD MISSING"

apt-get clean
rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*
rm -f /etc/resolv.conf /etc/hosts
echo "INNER_GAME_DONE"
EOS
chmod +x $ROOT/tmp/game.sh
chroot $ROOT /tmp/game.sh
rm -f $ROOT/tmp/game.sh

umount $ROOT/dev/pts 2>/dev/null || true
umount $ROOT/proc 2>/dev/null || true
umount $ROOT/sys  2>/dev/null || true
umount $ROOT/run  2>/dev/null || true
umount $ROOT/dev  2>/dev/null || true
echo "DONE_GAMING"
