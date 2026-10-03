#!/usr/bin/env bash
set -e
cd /root/infinityos/work
R=edit

echo "=== First-boot cleanup: remove installer on the INSTALLED system only ==="
cat > $R/usr/local/bin/infinityos-firstboot.sh <<'SH'
#!/bin/bash
# Runs at boot. On a LIVE session (boot=casper) it does nothing -> installer stays.
# On an INSTALLED system it removes the installer launchers, then disables itself.
if ! grep -q 'boot=casper' /proc/cmdline 2>/dev/null; then
    rm -f /usr/share/applications/install-infinityos.desktop
    rm -f /usr/share/applications/ubiquity.desktop
    rm -f /etc/skel/Desktop/install-infinityos.desktop
    for h in /home/* /root; do
        rm -f "$h/Desktop/install-infinityos.desktop" 2>/dev/null || true
    done
    systemctl disable infinityos-firstboot.service 2>/dev/null || true
    rm -f /etc/systemd/system/multi-user.target.wants/infinityos-firstboot.service
fi
exit 0
SH
chmod +x $R/usr/local/bin/infinityos-firstboot.sh

cat > $R/etc/systemd/system/infinityos-firstboot.service <<'UNIT'
[Unit]
Description=Infinity OS first-boot cleanup (remove installer once installed)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/infinityos-firstboot.sh

[Install]
WantedBy=multi-user.target
UNIT

mkdir -p $R/etc/systemd/system/multi-user.target.wants
ln -sf /etc/systemd/system/infinityos-firstboot.service \
   $R/etc/systemd/system/multi-user.target.wants/infinityos-firstboot.service

echo "Created:"
ls -l $R/usr/local/bin/infinityos-firstboot.sh
ls -l $R/etc/systemd/system/multi-user.target.wants/infinityos-firstboot.service
echo "DONE_NOINSTALLER"
