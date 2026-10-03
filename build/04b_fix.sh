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

cat > $ROOT/tmp/fix.sh <<'EOS'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive
export HOME=/root

# ---- Enable universe + multiverse ----
cat >> /etc/apt/sources.list <<EOF

deb http://archive.ubuntu.com/ubuntu jammy universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security universe multiverse
EOF
apt-get update -y

# ---- Install everything (universe now available) ----
apt-get install -y git || true
apt-get install -y gdebi gdebi-core libfuse2 fuse neofetch gnome-tweaks \
                   htop gparted gnome-shell-extensions sassc || true

# .deb -> GDebi GUI launcher
cat > /usr/share/applications/infinityos-deb.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Install .deb (GDebi)
Exec=gdebi-gtk %f
MimeType=application/vnd.debian.binary-package;
NoDisplay=true
EOF

# ---- WhiteSur "liquid glass" theme ----
cd /tmp
rm -rf WhiteSur-gtk-theme WhiteSur-icon-theme
if git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git; then
  ( cd WhiteSur-gtk-theme && ./install.sh -d /usr/share/themes -c Dark -o normal || ./install.sh -d /usr/share/themes -c Dark || true )
fi
if git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git; then
  ( cd WhiteSur-icon-theme && ./install.sh -d /usr/share/icons || true )
fi

# ---- Re-apply defaults (wallpaper + glass theme + dark) ----
mkdir -p /usr/share/glib-2.0/schemas
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
enabled-extensions=['user-theme@gnome-shell-extensions.gcampax.github.com']

[org.gnome.shell.extensions.user-theme]
name='WhiteSur-Dark'
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas || true

# ---- Neon boot logo (installed-system splash) ----
if [ -f /usr/share/plymouth/infinityos-logo.png ]; then
  cp /usr/share/plymouth/infinityos-logo.png /usr/share/plymouth/ubuntu-logo.png 2>/dev/null || true
  [ -d /usr/share/plymouth/themes/spinner ] && cp /usr/share/plymouth/infinityos-logo.png /usr/share/plymouth/themes/spinner/watermark.png 2>/dev/null || true
  plymouth-set-default-theme spinner 2>/dev/null || true
  update-initramfs -u 2>/dev/null || true
fi

# ---- Report what landed ----
echo "----- INSTALL CHECK -----"
for p in git gdebi libfuse2 neofetch gnome-tweaks gparted sassc; do
  dpkg -l "$p" 2>/dev/null | grep -q '^ii' && echo "OK  $p" || echo "MISSING  $p"
done
ls -d /usr/share/themes/WhiteSur-Dark* 2>/dev/null && echo "OK  WhiteSur theme" || echo "MISSING WhiteSur theme"

apt-get clean
rm -rf /tmp/WhiteSur* /tmp/* /var/tmp/* /var/lib/apt/lists/*
rm -f /etc/resolv.conf /etc/hosts
EOS
chmod +x $ROOT/tmp/fix.sh
chroot $ROOT /tmp/fix.sh
rm -f $ROOT/tmp/fix.sh

umount $ROOT/dev/pts 2>/dev/null || true
umount $ROOT/proc 2>/dev/null || true
umount $ROOT/sys  2>/dev/null || true
umount $ROOT/run  2>/dev/null || true
umount $ROOT/dev  2>/dev/null || true
echo "DONE_FIX"
