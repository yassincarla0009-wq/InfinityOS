#!/usr/bin/env bash
set -e
cd /root/infinityos/work
URL="https://releases.ubuntu.com/22.04/ubuntu-22.04.5-desktop-amd64.iso"
echo "=== Downloading base ISO (Ubuntu 22.04.5 GNOME) ==="
wget -c -q --show-progress -O base.iso "$URL"
echo "=== Download complete ==="
ls -lh base.iso
echo "DONE_DOWNLOAD"
