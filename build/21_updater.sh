#!/usr/bin/env bash
set -e
cd /root/infinityos/work
R=edit

echo "=== Rewrite Infinity OS Updates: real software update + owner fixes ==="
cat > $R/usr/local/bin/infinityos-update <<'SH'
#!/bin/bash
# Infinity OS Updates - manual software updates over WiFi (never forced).
# Updates system packages AND pulls the latest Infinity OS fixes from the repo.
FIX_URL="https://raw.githubusercontent.com/yassincarla0009-wq/InfinityOS/main/update.sh"
SCRIPT='
echo "===== Infinity OS Updates ====="; echo;
echo ">> Updating system packages..."; sudo apt update && sudo apt full-upgrade -y; echo;
echo ">> Applying latest Infinity OS fixes...";
( wget -qO- '"$FIX_URL"' | sudo bash ) 2>/dev/null || echo "   (no extra fixes right now)";
echo; echo "Infinity OS is up to date. Press Enter to close."; read'
for t in gnome-terminal x-terminal-emulator xterm konsole; do
  if command -v "$t" >/dev/null 2>&1; then
    if [ "$t" = "gnome-terminal" ]; then exec gnome-terminal -- bash -c "$SCRIPT"; else exec "$t" -e bash -c "$SCRIPT"; fi
  fi
done
# fallback: graphical updater
exec update-manager
SH
chmod +x $R/usr/local/bin/infinityos-update

echo "Updater script installed:"
head -3 $R/usr/local/bin/infinityos-update
echo "DONE_UPDATER"
