#!/usr/bin/env bash
set -e
cd /root/infinityos/work
VOL="Infinity OS"
OUT=/root/infinityos/work/InfinityOS.iso
DEST=/mnt/c/Users/yassi/Downloads/InfinityOS.iso

echo "=== Branding boot menu + disk info (TEXT files only) ==="
OLDV=$(grep '^-V' eltorito_args.txt | head -1 | sed "s/^-V //; s/'//g" || true)
echo "Old volume label: [$OLDV]"
# Only edit known text config files (never binaries/fonts/modules)
for f in extract/boot/grub/grub.cfg extract/boot/grub/loopback.cfg \
         extract/isolinux/txt.cfg extract/README.diskdefines; do
  [ -f "$f" ] || continue
  sed -i 's/Ubuntu [0-9][0-9.]* LTS[^"]*/Infinity OS 1.0/g; s/Try or Install Ubuntu/Try or Install Infinity OS/g; s/\bUbuntu\b/Infinity OS/g' "$f" || true
  if [ -n "$OLDV" ]; then sed -i "s|$OLDV|$VOL|g" "$f" || true; fi
done
# Disk name
echo 'Infinity OS 1.0 "Infinity" - Release amd64' > extract/.disk/info 2>/dev/null || true

echo "=== Rebuilding squashfs (this is the slow part, ~10 min) ==="
rm -f extract/casper/filesystem.squashfs
mksquashfs edit extract/casper/filesystem.squashfs -comp xz -b 1M -noappend -no-progress
printf "%s" "$(du -sx --block-size=1 edit | cut -f1)" > extract/casper/filesystem.size

echo "=== Regenerating package manifest ==="
chroot edit dpkg-query -W --showformat='${Package} ${Version}\n' > extract/casper/filesystem.manifest 2>/dev/null || true

echo "=== Regenerating md5sum.txt ==="
( cd extract && rm -f md5sum.txt && \
  find . -type f -not -name md5sum.txt -not -path './isolinux/*' -print0 \
  | xargs -0 md5sum > md5sum.txt )

echo "=== Building bootable InfinityOS.iso ==="
MKARGS=$(grep -v '^-V' eltorito_args.txt | sed "s/'//g" | tr '\n' ' ')
echo "xorriso args: $MKARGS"
rm -f "$OUT"
xorriso -as mkisofs -V "$VOL" -o "$OUT" $MKARGS extract

echo "=== Copying ISO to Windows Desktop ==="
cp "$OUT" "$DEST"
ls -lh "$OUT"
echo "DONE_REPACK"
