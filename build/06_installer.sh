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

cat > $ROOT/tmp/inst.sh <<'EOS'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

echo "=== Reinstalling the live installer (ubiquity) ==="
apt-get install -y --no-install-recommends \
    ubiquity ubiquity-frontend-gtk ubiquity-slideshow-ubuntu ubiquity-casper || \
apt-get install -y ubiquity ubiquity-frontend-gtk ubiquity-slideshow-ubuntu

echo "=== Verify ==="
which ubiquity && echo "UBIQUITY_OK" || echo "UBIQUITY_STILL_MISSING"

# ---- App-grid launcher ----
cat > /usr/share/applications/install-infinityos.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Install Infinity OS
GenericName=System installer
Comment=Install Infinity OS to a drive you choose
Exec=ubiquity gtk_ui
Icon=ubiquity
Terminal=false
Categories=GNOME;System;
Keywords=install;installer;infinity;setup;
StartupNotify=true
EOF

# ---- Desktop icon for every user (live + installed) via /etc/skel ----
mkdir -p /etc/skel/Desktop
cp /usr/share/applications/install-infinityos.desktop /etc/skel/Desktop/install-infinityos.desktop
chmod +x /etc/skel/Desktop/install-infinityos.desktop

# ---- Also drop it straight into the live user's home if it exists ----
for h in /home/*; do
  [ -d "$h" ] || continue
  mkdir -p "$h/Desktop"
  cp /usr/share/applications/install-infinityos.desktop "$h/Desktop/install-infinityos.desktop"
  chmod +x "$h/Desktop/install-infinityos.desktop"
  chown -R "$(basename "$h")":"$(basename "$h")" "$h/Desktop" 2>/dev/null || true
done

apt-get clean
rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*
rm -f /etc/resolv.conf /etc/hosts
EOS
chmod +x $ROOT/tmp/inst.sh
chroot $ROOT /tmp/inst.sh
rm -f $ROOT/tmp/inst.sh

umount $ROOT/dev/pts 2>/dev/null || true
umount $ROOT/proc 2>/dev/null || true
umount $ROOT/sys  2>/dev/null || true
umount $ROOT/run  2>/dev/null || true
umount $ROOT/dev  2>/dev/null || true
echo "DONE_INSTALLER"
