#!/usr/bin/env bash
cd /root/infinityos/work
R=edit
echo "== half-installed / broken packages =="
chroot $R dpkg --audit 2>&1 | head -25
echo
echo "== ubiquity status + depends =="
chroot $R dpkg -s ubiquity 2>&1 | grep -E '^Status|^Depends'
echo
echo "== key dependency presence =="
for p in ubiquity ubiquity-frontend-gtk ubiquity-casper ubiquity-slideshow-ubuntu \
         python3-pyparted python3-icu gparted parted localechooser-data \
         python3-debconf debconf-communicate; do
  st=$(chroot $R dpkg -s "$p" 2>/dev/null | grep -m1 '^Status')
  if [ -z "$st" ]; then echo "  $p: MISSING"; else echo "  $p: $st"; fi
done
echo
echo "== ubiquity python import test =="
chroot $R python3 -c "import ubiquity; print('ubiquity module OK')" 2>&1 | head -5
chroot $R python3 -c "import ped; print('pyparted(ped) OK')" 2>&1 | head -5
echo "DONE_DIAG"
