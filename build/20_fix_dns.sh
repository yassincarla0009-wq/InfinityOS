#!/usr/bin/env bash
set -e
cd /root/infinityos/work
R=edit

echo "=== Set AdGuard DNS as default + fix resolv.conf ==="

# 1) systemd-resolved global DNS = AdGuard
mkdir -p $R/etc/systemd
cat > $R/etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=94.140.14.14 94.140.15.15 2a10:50c0::ad1:ff 2a10:50c0::ad2:ff
FallbackDNS=1.1.1.1 8.8.8.8
DNSStubListener=yes
EOF

# 2) fix /etc/resolv.conf (our cleanup deleted it) -> point to resolved stub
rm -f $R/etc/resolv.conf
ln -sf /run/systemd/resolve/stub-resolv.conf $R/etc/resolv.conf

# 3) make sure systemd-resolved starts at boot
mkdir -p $R/etc/systemd/system/multi-user.target.wants
ln -sf /lib/systemd/system/systemd-resolved.service \
   $R/etc/systemd/system/multi-user.target.wants/systemd-resolved.service 2>/dev/null || true
ln -sf /lib/systemd/system/systemd-resolved.service \
   $R/etc/systemd/system/dbus-org.freedesktop.resolve1.service 2>/dev/null || true

# 4) force AdGuard for all NetworkManager connections (overrides router DHCP DNS)
mkdir -p $R/etc/NetworkManager/conf.d
cat > $R/etc/NetworkManager/conf.d/00-infinityos-dns.conf <<EOF
[main]
dns=systemd-resolved

[global-dns-domain-*]
servers=94.140.14.14,94.140.15.15
EOF

echo "Created:"
ls -l $R/etc/resolv.conf
cat $R/etc/systemd/resolved.conf | grep -E '^DNS|^FallbackDNS'
echo "DONE_DNS"
