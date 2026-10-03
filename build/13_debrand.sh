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

cat > $ROOT/tmp/deb.sh <<'EOS'
#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

echo "=== Fix all apps (repair packages) ==="
apt-get update -y || true
dpkg --configure -a || true
apt-get -f install -y || true

echo "=== Remove the Ubuntu Desktop Guide (branding) ==="
apt-get purge -y ubuntu-docs 2>/dev/null || true

echo "=== Hide Ubuntu-branded app launchers (show only Infinity OS apps) ==="
hide_desktop() {
  for base in /usr/share/applications /var/lib/snapd/desktop/applications; do
    f="$base/$1"
    if [ -f "$f" ]; then
      grep -q '^NoDisplay=true' "$f" || echo 'NoDisplay=true' >> "$f"
    fi
  done
}
for d in \
  snap-store_ubuntu-software snap-store \
  software-properties-livepatch \
  usb-creator-gtk \
  ubuntu-report \
  update-manager ; do
  hide_desktop "$d.desktop"
done
# keep our own branded updater visible (re-show if the name collided)
sed -i '/^NoDisplay=true/d' /usr/share/applications/infinityos-updates.desktop 2>/dev/null || true

echo "=== Dock favorites = Infinity OS apps ==="
# Build favorites from whatever actually exists
FAVS=""
add_fav() { [ -f "/usr/share/applications/$1" ] && FAVS="$FAVS'$1', "; }
add_fav brave-browser.desktop
add_fav firefox.desktop
add_fav org.gnome.Nautilus.desktop
add_fav ms365-home.desktop
add_fav org.gnome.Terminal.desktop
add_fav steam.desktop
add_fav lutris.desktop
add_fav infinityos-updates.desktop
add_fav gnome-control-center.desktop
FAVS="[ ${FAVS%, } ]"

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

[org.gnome.shell]
favorite-apps=$FAVS
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas || true

echo "Favorites set to: $FAVS"
echo "INNER_DEBRAND_DONE"

apt-get clean
rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*
rm -f /etc/resolv.conf /etc/hosts
EOS
chmod +x $ROOT/tmp/deb.sh
chroot $ROOT /tmp/deb.sh
rm -f $ROOT/tmp/deb.sh

umount $ROOT/dev/pts 2>/dev/null || true
umount $ROOT/proc 2>/dev/null || true
umount $ROOT/sys  2>/dev/null || true
umount $ROOT/run  2>/dev/null || true
umount $ROOT/dev  2>/dev/null || true
echo "DONE_DEBRAND"
