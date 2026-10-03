#!/usr/bin/env bash
set -e
cd /root/infinityos/work
R=edit

echo "=== Report-a-Problem app (emails Yassin) ==="
cat > $R/usr/local/bin/infinityos-report <<'SH'
#!/bin/bash
# Infinity OS - Report a Problem. Opens a pre-filled Gmail compose to Yassin.
TO="yassincarla0009@gmail.com"
RESP=$(zenity --forms --title="Report a Problem - Infinity OS" \
  --text="Tell Yassin what went wrong. Leave your email so he can reply to you." \
  --add-entry="Your email (for a reply)" \
  --add-entry="What is the problem?" 2>/dev/null) || exit 0
[ -z "$RESP" ] && exit 0
EMAIL="${RESP%%|*}"
PROB="${RESP#*|}"
ENC() { python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1"; }
SUBJ=$(ENC "Infinity OS Problem Report")
BODY=$(ENC "Problem:
$PROB

Reply to: $EMAIL

--- Sent from Infinity OS Report a Problem ---")
URL="https://mail.google.com/mail/?view=cm&fs=1&to=$TO&su=$SUBJ&body=$BODY"
xdg-open "$URL" >/dev/null 2>&1 &
zenity --info --title="Infinity OS" \
  --text="Opening your browser to send the report to Yassin.\nJust review it and press Send." 2>/dev/null || true
SH
chmod +x $R/usr/local/bin/infinityos-report

cat > $R/usr/share/applications/infinityos-report.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Report a Problem
GenericName=Problem Reporter
Comment=Send a problem report to Infinity OS (Yassin will reply by email)
Exec=/usr/local/bin/infinityos-report
Icon=help-faq
Terminal=false
Categories=System;
Keywords=report;problem;bug;help;error;support;
StartupNotify=true
EOF

mkdir -p $R/etc/skel/Desktop
cp $R/usr/share/applications/infinityos-report.desktop $R/etc/skel/Desktop/
chmod +x $R/etc/skel/Desktop/infinityos-report.desktop

echo "Created:"
ls -l $R/usr/local/bin/infinityos-report
ls -l $R/usr/share/applications/infinityos-report.desktop
echo "DONE_REPORT"
