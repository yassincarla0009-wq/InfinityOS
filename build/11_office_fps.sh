#!/usr/bin/env bash
set -e
cd /root/infinityos/work
ROOT=edit

echo "=== Copy Office icons into rootfs ==="
mkdir -p $ROOT/usr/share/icons/infinityos-office
cp /mnt/c/Users/yassi/OneDrive/Desktop/infinityos/office_icons/*.png $ROOT/usr/share/icons/infinityos-office/

echo "=== Binding mounts ==="
mount --bind /dev  $ROOT/dev
mount --bind /run  $ROOT/run
mount -t proc proc $ROOT/proc
mount -t sysfs sys $ROOT/sys
mount -t devpts devpts $ROOT/dev/pts 2>/dev/null || true
cp /etc/resolv.conf $ROOT/etc/resolv.conf

cat > $ROOT/tmp/of.sh <<'EOS'
#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

echo "=== Repair broken packages + fix Settings app ==="
apt-get update -y || true
dpkg --configure -a || true
apt-get -f install -y || true
apt-get install -y --reinstall gnome-control-center gnome-control-center-data || true
command -v gnome-control-center >/dev/null 2>&1 && echo "STATUS SETTINGS OK" || echo "STATUS SETTINGS MISSING"

echo "=== Brave (true web-app engine) ==="
install -d -m 0755 /etc/apt/keyrings
wget -qO /etc/apt/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg || true
echo "deb [signed-by=/etc/apt/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" > /etc/apt/sources.list.d/brave-browser-release.list
apt-get update -y || true
apt-get install -y brave-browser || true
if command -v brave-browser >/dev/null 2>&1; then echo "STATUS BRAVE OK"; WAPP="brave-browser --app="; else echo "STATUS BRAVE MISSING"; WAPP="firefox --new-window "; fi

echo "=== Taskbar-anywhere (Dash to Panel) + tweaks ==="
apt-get install -y gnome-shell-extension-dash-to-panel gnome-tweaks || true

echo "=== Office 365 true web-app launchers ==="
mkapp() {
cat > /usr/share/applications/$4 <<EOF
[Desktop Entry]
Type=Application
Name=$1
Comment=Microsoft 365 web app
Exec=${WAPP}$2
Icon=/usr/share/icons/infinityos-office/$3
Terminal=false
Categories=Office;
StartupNotify=true
EOF
}
mkapp "Microsoft 365" "https://www.microsoft365.com"                          office.png     ms365-home.desktop
mkapp "Word"          "https://www.microsoft365.com/launch/word?auth=2"       word.png       ms365-word.desktop
mkapp "Excel"         "https://www.microsoft365.com/launch/excel?auth=2"      excel.png      ms365-excel.desktop
mkapp "PowerPoint"    "https://www.microsoft365.com/launch/powerpoint?auth=2" powerpoint.png ms365-powerpoint.desktop
mkapp "Outlook"       "https://outlook.office.com/mail/"                      outlook.png    ms365-outlook.desktop

echo "=== Desktop icons ==="
mkdir -p /etc/skel/Desktop
for d in ms365-home brave-browser firefox org.gnome.Nautilus org.gnome.Terminal install-infinityos; do
  src=/usr/share/applications/$d.desktop
  [ -f "$src" ] && cp "$src" /etc/skel/Desktop/ && chmod +x /etc/skel/Desktop/$d.desktop
done

echo "=== FPS / performance tuning ==="
apt-get install -y zram-config preload || true
cat > /etc/sysctl.d/99-infinityos-perf.conf <<EOF
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.max_map_count=2147483642
EOF
grep -q mesa_glthread /etc/environment 2>/dev/null || echo 'mesa_glthread=true' >> /etc/environment
mkdir -p /etc/skel/.config/MangoHud
printf 'fps\nframetime\ncpu_temp\ngpu_temp\ngpu_stats\nposition=top-left\nfont_size=20\n' > /etc/skel/.config/MangoHud/MangoHud.conf

echo "=== Default browser = Brave (so links/redirects open) ==="
if command -v brave-browser >/dev/null 2>&1; then
  DEFB=brave-browser.desktop
  update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/brave-browser 200 2>/dev/null || true
  update-alternatives --set x-www-browser /usr/bin/brave-browser 2>/dev/null || true
  update-alternatives --set gnome-www-browser /usr/bin/brave-browser 2>/dev/null || true
else
  DEFB=firefox.desktop
  update-alternatives --set x-www-browser /usr/bin/firefox 2>/dev/null || true
fi
mkdir -p /etc/skel/.config
cat > /etc/skel/.config/mimeapps.list <<EOF
[Default Applications]
x-scheme-handler/http=$DEFB
x-scheme-handler/https=$DEFB
x-scheme-handler/about=$DEFB
x-scheme-handler/unknown=$DEFB
text/html=$DEFB
application/vnd.debian.binary-package=infinityos-deb.desktop
EOF

echo "=== LIGHTWEIGHT: mask snapd + tracker (keep animations ON) ==="
# stop snap daemon/seeding (we use .deb apps) -> faster boot, less RAM
systemctl mask snapd.service snapd.socket snapd.seeded.service 2>/dev/null || true
rm -f /var/lib/snapd/seed/snaps/firefox_*.snap 2>/dev/null || true
# disable tracker file indexing (big CPU/IO saver on low-end)
systemctl --global mask tracker-miner-fs-3.service tracker-miner-rss-3.service \
    tracker-extract-3.service tracker-writeback-3.service tracker-miner-fs-control-3.service 2>/dev/null || true

echo "=== Shell defaults (extensions + lightweight animations off) ==="
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
enable-animations=true
[org.gnome.shell]
enabled-extensions=['ubuntu-dock@ubuntu.com', 'ding@rastersoft.com', 'user-theme@gnome-shell-extensions.gcampax.github.com']
[org.gnome.shell.extensions.user-theme]
name='WhiteSur-Dark'
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas || true

echo "=== FINAL STATUS ==="
command -v brave-browser >/dev/null 2>&1 && echo "FINAL BRAVE OK" || echo "FINAL BRAVE MISSING"
dpkg -l gnome-shell-extension-dash-to-panel 2>/dev/null | grep -q '^ii' && echo "FINAL DASHPANEL OK" || echo "FINAL DASHPANEL MISSING"
dpkg -l zram-config 2>/dev/null | grep -q '^ii' && echo "FINAL ZRAM OK" || echo "FINAL ZRAM MISSING"

apt-get clean
rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*
rm -f /etc/resolv.conf /etc/hosts
echo "INNER_OF_DONE"
EOS
chmod +x $ROOT/tmp/of.sh
chroot $ROOT /tmp/of.sh
rm -f $ROOT/tmp/of.sh

umount $ROOT/dev/pts 2>/dev/null || true
umount $ROOT/proc 2>/dev/null || true
umount $ROOT/sys  2>/dev/null || true
umount $ROOT/run  2>/dev/null || true
umount $ROOT/dev  2>/dev/null || true
echo "DONE_OFFICE_FPS"
