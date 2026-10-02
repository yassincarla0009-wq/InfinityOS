#!/bin/bash
# Infinity OS maintenance fixes — run as root by "Infinity OS Updates".
# Idempotent: safe to run repeatedly. Add new fixes here as they are released.

REPO="https://raw.githubusercontent.com/yassincarla0009-wq/InfinityOS/main"

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

# --- Fix apt sources: clean, reliable main Ubuntu archive + all components ---
cat > /etc/apt/sources.list <<EOF
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF
apt-get update -y || true

# --- Feature update: add cmatrix (Matrix rain in the terminal) ---
apt-get install -y cmatrix || echo "   (cmatrix install failed - check internet)"

# --- Fix the camera (Cheese): restore app + webcam plugins + permissions ---
apt-get install -y cheese cheese-common \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
  gstreamer1.0-tools gstreamer1.0-libav \
  v4l-utils libv4l-0 2>/dev/null || echo "   (camera packages failed - check internet)"
# repair a broken/half-configured Cheese if it was already installed
apt-get install -y --reinstall cheese cheese-common 2>/dev/null || true
# make sure every user can access the webcam device
for u in $(ls /home 2>/dev/null); do usermod -aG video "$u" 2>/dev/null || true; done

# --- Install the "update available" notifier (checks repo, pops a notification) ---
cat > /usr/local/bin/infinityos-update-check <<'SH'
#!/bin/bash
# Checks the repo for a newer version and shows a desktop notification.
REPO="https://raw.githubusercontent.com/yassincarla0009-wq/InfinityOS/main"
sleep 25   # let the network/WiFi come up after login
LOCAL=$(cat /etc/infinityos/version 2>/dev/null | tr -dc '0-9'); LOCAL=${LOCAL:-0}
REMOTE=$(wget -qO- "$REPO/version" 2>/dev/null | tr -dc '0-9')
[ -z "$REMOTE" ] && exit 0
if [ "$REMOTE" -gt "$LOCAL" ] 2>/dev/null; then
  notify-send -u normal -i system-software-update \
    "Infinity OS — Update available" \
    "A new update is ready. Open \"Infinity OS Updates\" to install it."
fi
SH
chmod +x /usr/local/bin/infinityos-update-check

# autostart the check for every user at login
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/infinityos-update-check.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Infinity OS Update Check
Exec=/usr/local/bin/infinityos-update-check
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

# --- Install the first-boot auto-fix service (applies this script once, on first boot) ---
cat > /usr/local/bin/infinityos-firstboot <<'SH'
#!/bin/bash
REPO="https://raw.githubusercontent.com/yassincarla0009-wq/InfinityOS/main"
mkdir -p /var/lib/infinityos
# only mark done if the fixes actually applied (needs internet)
if wget -qO- "$REPO/update.sh" 2>/dev/null | bash; then
  touch /var/lib/infinityos/firstboot-done
  systemctl disable infinityos-firstboot.service 2>/dev/null || true
fi
SH
chmod +x /usr/local/bin/infinityos-firstboot

cat > /etc/systemd/system/infinityos-firstboot.service <<EOF
[Unit]
Description=Infinity OS first-boot fixes
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/infinityos/firstboot-done

[Service]
Type=oneshot
ExecStart=/usr/local/bin/infinityos-firstboot

[Install]
WantedBy=multi-user.target
EOF
systemctl enable infinityos-firstboot.service 2>/dev/null || true

# --- Record the version we just applied (so the notifier knows we're current) ---
mkdir -p /etc/infinityos
wget -qO- "$REPO/version" 2>/dev/null | tr -dc '0-9' > /etc/infinityos/version || true

if command -v cmatrix >/dev/null 2>&1; then
  echo "Infinity OS fixes applied (DNS / AdGuard + updater + cmatrix INSTALLED + notifier)."
  echo "Try it now: run  cmatrix  in a terminal."
else
  echo "Fixes applied, but cmatrix did not install (apt/network issue)."
fi
