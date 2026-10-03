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

cat > $ROOT/tmp/dvd.sh <<'EOS'
#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive
apt-get update -y || true

echo "=== DVD playback: VLC + libdvd + decryption (libdvdcss) ==="
apt-get install -y vlc libdvdread8 libdvdnav4 libdvd-pkg || true
# build/install libdvdcss (decrypt commercial DVDs) - needs compilers temporarily
apt-get install -y build-essential fakeroot || true
dpkg-reconfigure -f noninteractive libdvd-pkg 2>/dev/null || true
# verify
( ls /usr/lib/x86_64-linux-gnu/libdvdcss* >/dev/null 2>&1 || ls /usr/lib/libdvdcss* >/dev/null 2>&1 ) \
  && echo "STATUS LIBDVDCSS OK" || echo "STATUS LIBDVDCSS maybe-missing"
command -v vlc >/dev/null 2>&1 && echo "STATUS VLC OK" || echo "STATUS VLC MISSING"

echo "=== Strip compilers back out (stay lightweight) ==="
apt-get purge -y build-essential g++ gcc cpp 2>/dev/null || true
apt-get autoremove -y || true

apt-get clean
rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*
rm -f /etc/resolv.conf /etc/hosts
echo "INNER_DVD_DONE"
EOS
chmod +x $ROOT/tmp/dvd.sh
chroot $ROOT /tmp/dvd.sh
rm -f $ROOT/tmp/dvd.sh

umount $ROOT/dev/pts 2>/dev/null || true
umount $ROOT/proc 2>/dev/null || true
umount $ROOT/sys  2>/dev/null || true
umount $ROOT/run  2>/dev/null || true
umount $ROOT/dev  2>/dev/null || true
echo "DONE_DVD"
