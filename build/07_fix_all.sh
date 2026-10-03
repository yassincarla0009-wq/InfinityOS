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

# NOTE: inner script does NOT use 'set -e' so one failure can't abort everything
cat > $ROOT/tmp/fixall.sh <<'EOS'
#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y || echo "WARN: apt update had issues"
apt-get install -y wget ca-certificates || true

echo "=== Reinstalling live installer (ubiquity) ==="
apt-get install -y ubiquity ubiquity-frontend-gtk ubiquity-slideshow-ubuntu ubiquity-casper || true
if [ -x /usr/bin/ubiquity ]; then echo "STATUS UBIQUITY OK"; else echo "STATUS UBIQUITY MISSING"; fi

echo "=== Eject / removable-drive tools ==="
apt-get install -y eject gnome-disk-utility udisks2 gvfs gvfs-backends || true
if [ -x /usr/bin/eject ]; then echo "STATUS EJECT OK"; else echo "STATUS EJECT MISSING"; fi

echo "=== Software updater (cloud updates) ==="
apt-get install -y update-manager update-notifier software-properties-gtk || true
if [ -x /usr/bin/update-manager ]; then echo "STATUS UPDATER OK"; else echo "STATUS UPDATER MISSING"; fi

echo "=== Real Firefox (.deb from Mozilla, not snap) ==="
install -d -m 0755 /etc/apt/keyrings
if wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O /etc/apt/keyrings/packages.mozilla.org.asc; then
  echo 'deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main' > /etc/apt/sources.list.d/mozilla.list
  printf 'Package: firefox*\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' > /etc/apt/preferences.d/mozilla
  apt-get update -y || true
  apt-get install -y --allow-downgrades firefox || apt-get install -y firefox || true
fi
if firefox --version >/dev/null 2>&1; then echo "STATUS FIREFOX OK ($(firefox --version 2>/dev/null))"; else echo "STATUS FIREFOX FAIL"; fi
dpkg -l firefox 2>/dev/null | tail -1

echo "=== Install launchers / desktop icon ==="
cat > /usr/share/applications/install-infinityos.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Install Infinity OS
GenericName=System Installer
Comment=Install Infinity OS to a drive you choose
Exec=ubiquity gtk_ui
Icon=ubiquity
Terminal=false
Categories=GNOME;System;
Keywords=install;installer;infinity;setup;
StartupNotify=true
EOF
mkdir -p /etc/skel/Desktop
cp /usr/share/applications/install-infinityos.desktop /etc/skel/Desktop/ 2>/dev/null || true
chmod +x /etc/skel/Desktop/install-infinityos.desktop 2>/dev/null || true
for h in /home/*; do
  [ -d "$h" ] || continue
  u=$(basename "$h"); mkdir -p "$h/Desktop"
  cp /usr/share/applications/install-infinityos.desktop "$h/Desktop/" 2>/dev/null || true
  chmod +x "$h/Desktop/install-infinityos.desktop" 2>/dev/null || true
  chown -R "$u":"$u" "$h/Desktop" 2>/dev/null || true
done

echo "=== FINAL STATUS ==="
[ -x /usr/bin/ubiquity ] && echo "FINAL UBIQUITY OK" || echo "FINAL UBIQUITY MISSING"
[ -x /usr/bin/eject ] && echo "FINAL EJECT OK" || echo "FINAL EJECT MISSING"
firefox --version >/dev/null 2>&1 && echo "FINAL FIREFOX OK" || echo "FINAL FIREFOX FAIL"
[ -f /etc/skel/Desktop/install-infinityos.desktop ] && echo "FINAL ICON OK" || echo "FINAL ICON MISSING"

apt-get clean
rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*
rm -f /etc/resolv.conf /etc/hosts
echo "INNER_DONE"
EOS
chmod +x $ROOT/tmp/fixall.sh
chroot $ROOT /tmp/fixall.sh
rm -f $ROOT/tmp/fixall.sh

umount $ROOT/dev/pts 2>/dev/null || true
umount $ROOT/proc 2>/dev/null || true
umount $ROOT/sys  2>/dev/null || true
umount $ROOT/run  2>/dev/null || true
umount $ROOT/dev  2>/dev/null || true
echo "DONE_FIXALL"
