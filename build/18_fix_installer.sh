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

cat > $ROOT/tmp/fi.sh <<'EOS'
#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y || true

echo "=== Restore the missing partitioning library + ubiquity deps ==="
apt-get install -y python3-pyparted || true
apt-get install -y --reinstall ubiquity ubiquity-frontend-gtk ubiquity-casper \
                   ubiquity-slideshow-ubuntu || true
# make sure every ubiquity dependency is satisfied (NO autoremove this time!)
apt-get -f install -y || true
dpkg --configure -a || true

echo "=== VERIFY ==="
(dpkg -s python3-pyparted 2>/dev/null | grep -m1 '^Status') || echo "PYPARTED MISSING"
python3 -c "import parted; print('STATUS PYPARTED-IMPORT OK')" 2>&1 | head -3
(dpkg -s ubiquity 2>/dev/null | grep -m1 '^Status') && echo "STATUS UBIQUITY OK"

apt-get clean
rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*
rm -f /etc/resolv.conf /etc/hosts
echo "INNER_FI_DONE"
EOS
chmod +x $ROOT/tmp/fi.sh
chroot $ROOT /tmp/fi.sh
rm -f $ROOT/tmp/fi.sh

umount $ROOT/dev/pts 2>/dev/null || true
umount $ROOT/proc 2>/dev/null || true
umount $ROOT/sys  2>/dev/null || true
umount $ROOT/run  2>/dev/null || true
umount $ROOT/dev  2>/dev/null || true
echo "DONE_FIX_INSTALLER"
