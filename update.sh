#!/bin/bash
# Infinity OS maintenance fixes — run as root by the "Infinity OS Updates" app.
# Idempotent: safe to run repeatedly. Add new fixes here as they are released.

echo "Applying Infinity OS fixes..."

# --- DNS / AdGuard (fixes early builds that shipped without a resolver) ---
cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=94.140.14.14 94.140.15.15
FallbackDNS=1.1.1.1 8.8.8.8
DNSStubListener=yes
EOF
if [ ! -e /etc/resolv.conf ]; then
  ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
fi
systemctl enable systemd-resolved 2>/dev/null || true
systemctl restart systemd-resolved 2>/dev/null || true

echo "Infinity OS fixes applied (DNS / AdGuard)."
