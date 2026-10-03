#!/usr/bin/env bash
set -e
echo "=== InfinityOS build: installing tools ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y p7zip-full squashfs-tools xorriso isolinux \
    grub-pc-bin grub-efi-amd64-bin mtools wget ca-certificates rsync
mkdir -p /root/infinityos/work
echo "=== Tools installed. Versions: ==="
mksquashfs -version | head -1 || true
xorriso --version 2>/dev/null | head -1 || true
echo "=== Free space ==="
df -h /root | tail -1
echo "DONE_PREP"
