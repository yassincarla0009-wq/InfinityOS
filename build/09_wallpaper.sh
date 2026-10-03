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

cat > $ROOT/tmp/wp.sh <<'EOS'
#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y || true
# Variety: downloads & rotates wallpapers from the internet (Unsplash, Wallhaven, Flickr...)
apt-get install -y variety || true
command -v variety >/dev/null 2>&1 && echo "STATUS VARIETY OK" || echo "STATUS VARIETY MISSING"
apt-get clean
rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*
rm -f /etc/resolv.conf /etc/hosts
echo "INNER_WP_DONE"
EOS
chmod +x $ROOT/tmp/wp.sh
chroot $ROOT /tmp/wp.sh
rm -f $ROOT/tmp/wp.sh

umount $ROOT/dev/pts 2>/dev/null || true
umount $ROOT/proc 2>/dev/null || true
umount $ROOT/sys  2>/dev/null || true
umount $ROOT/run  2>/dev/null || true
umount $ROOT/dev  2>/dev/null || true
echo "DONE_WP"
