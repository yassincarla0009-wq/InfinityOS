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

cat > $ROOT/tmp/gui.sh <<'EOS'
#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y || true

echo "=== Restore display manager + desktop session (NO autoremove!) ==="
apt-get install -y gdm3 gnome-session gnome-session-bin ubuntu-session \
                   gnome-settings-daemon network-manager network-manager-gnome || true
dpkg --configure -a || true
apt-get -f install -y || true

echo "=== Set graphical boot target ==="
rm -f /etc/systemd/system/default.target
ln -sf /lib/systemd/system/graphical.target /etc/systemd/system/default.target

echo "=== Make sure gdm3 is the enabled display manager ==="
echo "/usr/sbin/gdm3" > /etc/X11/default-display-manager 2>/dev/null || true
ln -sf /lib/systemd/system/gdm3.service /etc/systemd/system/display-manager.service
# default to Xorg session (more compatible on older Intel/AMD than Wayland)
mkdir -p /etc/gdm3
cat > /etc/gdm3/custom.conf <<EOF
[daemon]
WaylandEnable=false
EOF

echo "=== Make GRUB menu visible on the installed system ==="
if [ -f /etc/default/grub ]; then
  sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub
  grep -q '^GRUB_TIMEOUT_STYLE=' /etc/default/grub || echo 'GRUB_TIMEOUT_STYLE=menu' >> /etc/default/grub
  sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub
  grep -q '^GRUB_TIMEOUT=' /etc/default/grub || echo 'GRUB_TIMEOUT=5' >> /etc/default/grub
fi

echo "=== VERIFY ==="
(dpkg -s gdm3 2>/dev/null | grep -m1 '^Status') && echo "STATUS GDM3 OK" || echo "STATUS GDM3 MISSING"
(dpkg -s gnome-session 2>/dev/null | grep -m1 '^Status') && echo "STATUS SESSION OK" || echo "STATUS SESSION MISSING"
(dpkg -s network-manager 2>/dev/null | grep -m1 '^Status') && echo "STATUS NM OK" || echo "STATUS NM MISSING"
ls -l /etc/systemd/system/default.target

apt-get clean
rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*
rm -f /etc/resolv.conf /etc/hosts
echo "INNER_GUI_DONE"
EOS
chmod +x $ROOT/tmp/gui.sh
chroot $ROOT /tmp/gui.sh
rm -f $ROOT/tmp/gui.sh

umount $ROOT/dev/pts 2>/dev/null || true
umount $ROOT/proc 2>/dev/null || true
umount $ROOT/sys  2>/dev/null || true
umount $ROOT/run  2>/dev/null || true
umount $ROOT/dev  2>/dev/null || true
echo "DONE_FIX_GUI"
