#!/usr/bin/env bash
set -e
cd /root/infinityos/work
ROOT=edit

echo "=== Binding mounts for chroot ==="
mount --bind /dev  $ROOT/dev
mount --bind /run  $ROOT/run
mount -t proc proc $ROOT/proc
mount -t sysfs sys $ROOT/sys
mount -t devpts devpts $ROOT/dev/pts 2>/dev/null || true
cp /etc/resolv.conf $ROOT/etc/resolv.conf

echo "=== Copying Infinity OS wallpaper + boot logo ==="
cp /mnt/c/Users/yassi/OneDrive/Desktop/infinityos/wallpaper.png $ROOT/usr/share/backgrounds/infinityos.png
cp /mnt/c/Users/yassi/OneDrive/Desktop/infinityos/boot_logo.png $ROOT/usr/share/plymouth/infinityos-logo.png

echo "=== Writing in-chroot customization script ==="
cat > $ROOT/tmp/inside.sh <<'EOS'
#!/usr/bin/env bash
set -e
export DEBIAN_FRONTEND=noninteractive
export HOME=/root

# ---------- Branding (NO Ubuntu) ----------
cat > /etc/os-release <<EOF
NAME="Infinity OS"
VERSION="1.0 (Infinity)"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Infinity OS 1.0"
VERSION_ID="22.04"
HOME_URL="https://infinity.os/"
SUPPORT_URL="https://infinity.os/"
BUG_REPORT_URL="https://infinity.os/"
VERSION_CODENAME=infinity
UBUNTU_CODENAME=jammy
EOF
cat > /etc/lsb-release <<EOF
DISTRIB_ID="Infinity OS"
DISTRIB_RELEASE=1.0
DISTRIB_CODENAME=infinity
DISTRIB_DESCRIPTION="Infinity OS 1.0"
EOF
printf 'Infinity OS 1.0 \\n \\l\n' > /etc/issue
echo "Infinity OS 1.0" > /etc/issue.net
echo "Welcome to Infinity OS" > /etc/motd

# ---------- Apps: Firefox stays; .deb + AppImage support; tools + theme deps ----------
apt-get update -y || true
apt-get install -y gdebi gdebi-core libfuse2 fuse \
                   neofetch gnome-tweaks htop gnome-software gparted \
                   gnome-shell-extensions git sassc || true

# Make .deb open with GDebi GUI
cat > /usr/share/applications/infinityos-deb.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Install .deb (GDebi)
Exec=gdebi-gtk %f
MimeType=application/vnd.debian.binary-package;
NoDisplay=true
EOF

# ---------- "Liquid glass" theme: WhiteSur (glassy, dark) ----------
cd /tmp
if git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git; then
  cd WhiteSur-gtk-theme
  ./install.sh -d /usr/share/themes -c Dark -o normal -i ubuntu || ./install.sh -d /usr/share/themes -c Dark || true
  cd /tmp
fi
if git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git; then
  cd WhiteSur-icon-theme
  ./install.sh -d /usr/share/icons || true
  cd /tmp
fi

# ---------- Defaults: wallpaper + glass theme + dark mode ----------
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

# ---------- Neon boot logo (Plymouth splash on installed system) ----------
if [ -f /usr/share/plymouth/infinityos-logo.png ]; then
  cp /usr/share/plymouth/infinityos-logo.png /usr/share/plymouth/ubuntu-logo.png 2>/dev/null || true
  if [ -d /usr/share/plymouth/themes/spinner ]; then
    cp /usr/share/plymouth/infinityos-logo.png /usr/share/plymouth/themes/spinner/watermark.png 2>/dev/null || true
  fi
  plymouth-set-default-theme spinner 2>/dev/null || true
  update-initramfs -u 2>/dev/null || true
fi

# ---------- Cleanup ----------
apt-get clean
rm -rf /tmp/WhiteSur* /tmp/* /var/tmp/* /var/lib/apt/lists/*
rm -f /etc/resolv.conf /etc/hosts
EOS
chmod +x $ROOT/tmp/inside.sh

echo "=== Entering chroot (rebrand + apps + glass theme) ==="
chroot $ROOT /tmp/inside.sh
rm -f $ROOT/tmp/inside.sh

echo "=== Unmounting ==="
umount $ROOT/dev/pts 2>/dev/null || true
umount $ROOT/proc    2>/dev/null || true
umount $ROOT/sys     2>/dev/null || true
umount $ROOT/run     2>/dev/null || true
umount $ROOT/dev     2>/dev/null || true
echo "DONE_CUSTOMIZE"
