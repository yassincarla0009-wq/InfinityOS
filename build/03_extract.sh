#!/usr/bin/env bash
set -e
cd /root/infinityos/work

echo "=== Capturing original boot (El Torito) setup ==="
xorriso -indev base.iso -report_el_torito as_mkisofs 2>/dev/null > eltorito_args.txt || true
echo "----- captured args -----"
cat eltorito_args.txt
echo "-------------------------"

echo "=== Extracting ISO filesystem to extract/ ==="
rm -rf extract edit
mkdir -p extract
xorriso -osirrox on -indev base.iso -extract / extract 2>/dev/null
chmod -R u+w extract

SQ=$(find extract -name 'filesystem.squashfs' | head -1)
echo "squashfs found at: $SQ"
if [ -z "$SQ" ]; then echo "ERROR: no filesystem.squashfs (unexpected ISO layout)"; exit 1; fi

echo "=== Unsquashing live root filesystem to edit/ (takes a few min) ==="
rm -rf edit
unsquashfs -d edit "$SQ"
echo "rootfs size:"; du -sh edit | tail -1
echo "DONE_EXTRACT"
