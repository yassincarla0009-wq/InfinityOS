#!/usr/bin/env bash
cd /root/infinityos/work
R=edit
echo "== default systemd target =="
ls -l $R/etc/systemd/system/default.target 2>/dev/null || echo "default.target: (unset)"
echo
echo "== display manager enabled? =="
ls -l $R/etc/systemd/system/display-manager.service 2>/dev/null || echo "display-manager.service: NOT set (no DM enabled!)"
echo
echo "== gdm3 wants link =="
ls $R/etc/systemd/system/*.wants/gdm* 2>/dev/null || echo "no gdm wants link"
echo
echo "== key GUI packages =="
for p in gdm3 gnome-shell gnome-session ubuntu-session xorg xserver-xorg xserver-xorg-core \
         xserver-xorg-video-intel xserver-xorg-video-amdgpu mesa-utils; do
  st=$(chroot $R dpkg -s "$p" 2>/dev/null | grep -m1 '^Status')
  if [ -z "$st" ]; then echo "  $p: MISSING"; else echo "  $p: ok"; fi
done
echo
echo "== gdm3 custom.conf (Wayland) =="
cat $R/etc/gdm3/custom.conf 2>/dev/null | grep -vE '^\s*#|^\s*$' || echo "(no custom.conf)"
echo
echo "== broken/half-installed =="
chroot $R dpkg --audit 2>&1 | head -15
echo DONE_DIAG2
