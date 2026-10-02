#!/bin/bash
# Infinity OS maintenance fixes — run as root by "Infinity OS Updates".
# Idempotent: safe to run repeatedly. Add new fixes here as they are released.

echo "Applying Infinity OS fixes..."

# --- DNS / AdGuard (fixes early builds that shipped without a resolver) ---
cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=94.140.14.14 94.140.15.15
FallbackDNS=1.1.1.1 8.8.8.8
DNSStubListener=yes
EOF
[ -e /etc/resolv.conf ] || ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
systemctl enable systemd-resolved 2>/dev/null || true
systemctl restart systemd-resolved 2>/dev/null || true

# --- Upgrade the built-in "Infinity OS Updates" app to the latest version ---
cat > /usr/local/bin/infinityos-update <<'SH'
#!/bin/bash
FIX_URL="https://raw.githubusercontent.com/yassincarla0009-wq/InfinityOS/main/update.sh"
SCRIPT='echo "===== Infinity OS Updates ====="; echo;
echo ">> Updating system packages..."; sudo apt update && sudo apt full-upgrade -y; echo;
echo ">> Applying latest Infinity OS fixes..."; ( wget -qO- '"$FIX_URL"' | sudo bash ) 2>/dev/null || echo "   (no extra fixes)";
echo; echo "Infinity OS is up to date. Press Enter to close."; read'
for t in gnome-terminal x-terminal-emulator xterm konsole; do
  if command -v "$t" >/dev/null 2>&1; then
    if [ "$t" = "gnome-terminal" ]; then exec gnome-terminal -- bash -c "$SCRIPT"; else exec "$t" -e bash -c "$SCRIPT"; fi
  fi
done
exec update-manager
SH
chmod +x /usr/local/bin/infinityos-update

# --- Feature update: add cmatrix (Matrix rain in the terminal) ---
# refresh package lists first (so the package can actually be found)
apt-get update -y || true
# make sure the 'universe' component is enabled (cmatrix lives there)
add-apt-repository -y universe 2>/dev/null || true
apt-get update -y 2>/dev/null || true
apt-get install -y cmatrix || echo "   (cmatrix install failed - check internet / apt sources)"

if command -v cmatrix >/dev/null 2>&1; then
  echo "Infinity OS fixes applied (DNS / AdGuard + updater + cmatrix INSTALLED)."
  echo "Try it now: run  cmatrix  in a terminal."
else
  echo "Fixes applied, but cmatrix did not install (apt/network issue)."
fi
