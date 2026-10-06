#!/bin/bash
# Infinity OS maintenance fixes — run as root by "Infinity OS Updates".
# Each fix is applied ONCE per laptop (marker in /var/lib/infinityos/applied/),
# so repeat updates are fast and only new fixes actually run.

REPO="https://raw.githubusercontent.com/yassincarla0009-wq/InfinityOS/main"
STATE=/var/lib/infinityos/applied
mkdir -p "$STATE"

# apply_once <id> <function>: run the fix only if it hasn't succeeded before.
# If it fails (e.g. no internet) it is NOT marked, so it retries next update.
apply_once() {
  local id="$1"; local fn="$2"
  if [ -f "$STATE/$id" ]; then
    echo "   [skip] $id (already applied)"
    return 0
  fi
  echo ">> applying: $id"
  if "$fn"; then
    touch "$STATE/$id"
    echo "   [done] $id"
  else
    echo "   [will retry] $id (failed - likely internet)"
  fi
}

# ===== Always-current, instant (just writes files, no apt) =====

install_updater_app() {
  # 1) THE VERIFIER: downloads the update + its GPG signature, verifies the
  #    signature against the trusted public key baked in below, and ONLY runs
  #    the update (as root) if the signature is valid. A tampered or unsigned
  #    update is REFUSED - even if GitHub itself were compromised.
  cat > /usr/local/bin/infinityos-verify-update <<'VERIFYEOF'
#!/bin/bash
REPO="https://raw.githubusercontent.com/yassincarla0009-wq/InfinityOS/main"
command -v gpg >/dev/null 2>&1 || sudo apt-get install -y gnupg >/dev/null 2>&1
tmp=$(mktemp -d)
export GNUPGHOME="$tmp/gnupg"; mkdir -p "$GNUPGHOME"; chmod 700 "$GNUPGHOME"
gpg --batch --import >/dev/null 2>&1 <<'PGP'
-----BEGIN PGP PUBLIC KEY BLOCK-----

mDMEasP5kBYJKwYBBAHaRw8BAQdAHOKliI3g7qP0UMuGwpFoiNOp2aoRlmdjvcgG
QTqVeV20MUluZmluaXR5IE9TIDxpbmZpbml0eW9zQHVzZXJzLm5vcmVwbHkuZ2l0
aHViLmNvbT6IkAQTFgoAOBYhBCJz8x1bN54Hwb7MkV8DUROK/9ikBQJqw/mQAhsj
BQsJCAcCBhUKCQgLAgQWAgMBAh4BAheAAAoJEF8DUROK/9ik930A/1GP6pDdpfCG
1HUJcj/TkSimHTWyj2WLs4Lp021hbHVKAP0QiYLhEh/p1+ti9LjE6Vzf4ySImY1Q
VgaCzX7WTcnABg==
=OGvi
-----END PGP PUBLIC KEY BLOCK-----
PGP
if ! wget -q -O "$tmp/update.sh" "$REPO/update.sh" || ! wget -q -O "$tmp/update.sh.sig" "$REPO/update.sh.sig"; then
  echo "   Could not download the update (check your internet)."; rm -rf "$tmp"; exit 1
fi
if gpg --batch --verify "$tmp/update.sh.sig" "$tmp/update.sh" >/dev/null 2>&1; then
  echo "   Signature verified OK - applying trusted Infinity OS update..."
  sudo bash "$tmp/update.sh"; rc=0
else
  echo "   !!! SIGNATURE INVALID - update REFUSED. Nothing was run; your system is safe."
  echo "       (The script may be tampered with, or its signature is missing.)"
  rc=2
fi
rm -rf "$tmp"
exit $rc
VERIFYEOF
  chmod +x /usr/local/bin/infinityos-verify-update

  # 2) THE LAUNCHER the user clicks ("Infinity OS Updates")
  cat > /usr/local/bin/infinityos-update <<'SH'
#!/bin/bash
SCRIPT='echo "===== Infinity OS Updates ====="; echo;
echo ">> Updating system packages..."; sudo apt update && sudo apt full-upgrade -y; echo;
echo ">> Checking for a SIGNED Infinity OS update..."; /usr/local/bin/infinityos-verify-update;
echo; echo "Infinity OS is up to date. Press Enter to close."; read'
for t in gnome-terminal x-terminal-emulator xterm konsole; do
  if command -v "$t" >/dev/null 2>&1; then
    if [ "$t" = "gnome-terminal" ]; then exec gnome-terminal -- bash -c "$SCRIPT"; else exec "$t" -e bash -c "$SCRIPT"; fi
  fi
done
exec update-manager
SH
  chmod +x /usr/local/bin/infinityos-update
}

install_notifier() {
  cat > /usr/local/bin/infinityos-update-check <<'SH'
#!/bin/bash
REPO="https://raw.githubusercontent.com/yassincarla0009-wq/InfinityOS/main"
sleep 25
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
  mkdir -p /etc/xdg/autostart
  cat > /etc/xdg/autostart/infinityos-update-check.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Infinity OS Update Check
Exec=/usr/local/bin/infinityos-update-check
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
}

install_firstboot() {
  cat > /usr/local/bin/infinityos-firstboot <<'SH'
#!/bin/bash
REPO="https://raw.githubusercontent.com/yassincarla0009-wq/InfinityOS/main"
mkdir -p /var/lib/infinityos
ok=1
if [ -x /usr/local/bin/infinityos-verify-update ]; then
  # signature-checked path (normal case)
  /usr/local/bin/infinityos-verify-update || ok=0
else
  # one-time bootstrap fallback if the verifier isn't installed yet
  wget -qO- "$REPO/update.sh" 2>/dev/null | bash || ok=0
fi
if [ "$ok" = "1" ]; then
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
}

# ===== One-time fixes (the slow / apt ones) =====

fix_dns() {
  cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=94.140.14.14 94.140.15.15
FallbackDNS=1.1.1.1 8.8.8.8
DNSStubListener=yes
EOF
  [ -e /etc/resolv.conf ] || ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
  systemctl enable systemd-resolved 2>/dev/null || true
  systemctl restart systemd-resolved 2>/dev/null || true
  return 0
}

fix_apt_sources() {
  cat > /etc/apt/sources.list <<EOF
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF
  apt-get update -y    # retries next time if this fails (no internet)
}

feat_cmatrix() {
  apt-get install -y cmatrix
}

fix_camera() {
  # load the USB webcam kernel module (most laptop cams are UVC)
  modprobe uvcvideo 2>/dev/null || true

  # every webcam GStreamer plugin Cheese can need
  apt-get install -y \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly gstreamer1.0-tools gstreamer1.0-libav \
    v4l-utils libv4l-0 || return 1

  # fully repair Cheese (clear a broken install, then reinstall clean)
  apt-get install -y --reinstall cheese cheese-common 2>/dev/null \
    || { apt-get install -y cheese cheese-common || true; }

  # reliable backup camera app — works even when Cheese is finicky
  apt-get install -y guvcview || true

  # wipe stale/broken per-user Cheese config that can cause a black screen/crash
  for h in /home/*; do
    [ -d "$h" ] || continue
    rm -rf "$h/.cache/cheese" "$h/.config/cheese" "$h/.local/share/cheese" 2>/dev/null || true
  done

  # camera device permissions for every user
  for u in $(ls /home 2>/dev/null); do usermod -aG video "$u" 2>/dev/null || true; done
  return 0
}

fix_wine_exe() {
  command -v wine >/dev/null 2>&1 || apt-get install -y wine 2>/dev/null || true
  cat > /usr/local/bin/infinityos-run-windows <<'SH'
#!/bin/bash
f="$1"
case "${f,,}" in
  *.msi) exec wine msiexec /i "$f" ;;
  *)     exec wine "$f" ;;
esac
SH
  chmod +x /usr/local/bin/infinityos-run-windows
  cat > /usr/share/applications/infinityos-wine.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Run Windows Program (Wine)
Exec=/usr/local/bin/infinityos-run-windows %f
NoDisplay=true
MimeType=application/x-ms-dos-executable;application/x-msdownload;application/vnd.microsoft.portable-executable;application/x-msdos-program;application/x-msi;
EOF
  update-desktop-database /usr/share/applications 2>/dev/null || true
  local MIMEFILE=/etc/xdg/mimeapps.list
  touch "$MIMEFILE"
  for mt in application/x-ms-dos-executable application/x-msdownload application/vnd.microsoft.portable-executable application/x-msdos-program application/x-msi; do
    sed -i "\\#^${mt}=#d" "$MIMEFILE"
  done
  grep -q '^\[Default Applications\]' "$MIMEFILE" || echo '[Default Applications]' >> "$MIMEFILE"
  sed -i '/^\[Default Applications\]/a application/x-ms-dos-executable=infinityos-wine.desktop\napplication/x-msdownload=infinityos-wine.desktop\napplication/vnd.microsoft.portable-executable=infinityos-wine.desktop\napplication/x-msdos-program=infinityos-wine.desktop\napplication/x-msi=infinityos-wine.desktop' "$MIMEFILE"
  return 0
}

fix_wine_proper() {
  # THE big fix: most .exe fail to launch because 32-bit (i386) support is missing.
  dpkg --add-architecture i386 2>/dev/null || true
  apt-get update -y || true
  # full Wine (64 + 32 bit) + winbind + winetricks (deps) + cabextract
  apt-get install -y --install-recommends wine wine64 wine32 winbind winetricks cabextract 2>/dev/null \
    || apt-get install -y --install-recommends wine winbind winetricks 2>/dev/null \
    || apt-get install -y wine || return 1

  # better run wrapper: own prefix, auto-init on first run, quiet logs
  cat > /usr/local/bin/infinityos-run-windows <<'SH'
#!/bin/bash
export WINEPREFIX="$HOME/.wine-infinity"
export WINEDEBUG=-all
export WINEDLLOVERRIDES="mscoree,mshtml="   # skip mono/gecko nag popups
# first-time setup of the Wine prefix
[ -d "$WINEPREFIX" ] || wineboot -i >/dev/null 2>&1
f="$1"
case "${f,,}" in
  *.msi) exec wine msiexec /i "$f" ;;
  *)     exec wine "$f" ;;
esac
SH
  chmod +x /usr/local/bin/infinityos-run-windows

  # Bottles (Flatpak) = a rock-solid Wine manager for stubborn apps (Flathub works great here)
  if command -v flatpak >/dev/null 2>&1; then
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    flatpak install -y --noninteractive flathub com.usebottles.bottles 2>/dev/null || true
  fi
  return 0
}

fix_glass_look() {
  # tools + the User Themes extension (lets us theme the taskbar/top bar)
  apt-get install -y git sassc gnome-shell-extensions 2>/dev/null || true
  local TMP; TMP=$(mktemp -d)

  # FULL WhiteSur GTK + GNOME-Shell theme (this is what makes the top-bar / control
  # centre menu glass — guarantees the gnome-shell theme actually exists)
  if git clone --depth=1 https://github.com/vinceliuice/WhiteSur-gtk-theme.git "$TMP/wt" 2>/dev/null; then
    ( cd "$TMP/wt" && ./install.sh -d /usr/share/themes -c Dark ) 2>/dev/null \
      || ( cd "$TMP/wt" && ./install.sh -d /usr/share/themes ) 2>/dev/null || true
  fi

  # liquid-glass icons (WhiteSur icon theme)
  if git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git "$TMP/wi" 2>/dev/null; then
    ( cd "$TMP/wi" && ./install.sh -d /usr/share/icons -b ) 2>/dev/null || ( cd "$TMP/wi" && ./install.sh -d /usr/share/icons ) 2>/dev/null || true
  else
    rm -rf "$TMP"; return 1   # no internet -> retry next update
  fi
  rm -rf "$TMP"
  gtk-update-icon-cache /usr/share/icons/WhiteSur 2>/dev/null || true

  # detect the glass GTK/Shell theme name
  local GTK; GTK=$(ls -d /usr/share/themes/WhiteSur-Dark* /usr/share/themes/WhiteSur* 2>/dev/null | head -1)
  GTK=$(basename "${GTK:-WhiteSur-Dark}")
  local EXT="user-theme@gnome-shell-extensions.gcampax.github.com"

  # system-wide defaults (safe extension list keeps the dock + desktop icons working)
  mkdir -p /etc/dconf/profile /etc/dconf/db/local.d
  [ -f /etc/dconf/profile/user ] || printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user
  cat > /etc/dconf/db/local.d/01-infinityos-look <<EOF
[org/gnome/desktop/interface]
icon-theme='WhiteSur'
gtk-theme='$GTK'
enable-animations=true

[org/gnome/shell]
enabled-extensions=['ubuntu-dock@ubuntu.com', 'ding@rastersoft.com', '$EXT']

[org/gnome/shell/extensions/user-theme]
name='$GTK'

[org/gnome/shell/extensions/dash-to-dock]
transparency-mode='FIXED'
customize-alphas=true
min-alpha=0.150000
max-alpha=0.450000
background-opacity=0.250000
EOF
  dconf update 2>/dev/null || true

  # apply LIVE to everyone already logged in: windows + taskbar + icons + GLASS DOCK
  for u in $(ls /home 2>/dev/null); do
    local uid; uid=$(id -u "$u" 2>/dev/null) || continue
    local G="su - $u -c"
    local E="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus"
    $G "$E gnome-extensions enable $EXT" 2>/dev/null || true
    $G "$E gsettings set org.gnome.shell.extensions.user-theme name '$GTK'" 2>/dev/null || true
    $G "$E gsettings set org.gnome.desktop.interface gtk-theme '$GTK'" 2>/dev/null || true
    $G "$E gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur'" 2>/dev/null || true
    $G "$E gsettings set org.gnome.desktop.interface enable-animations true" 2>/dev/null || true
    $G "$E gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED'" 2>/dev/null || true
    $G "$E gsettings set org.gnome.shell.extensions.dash-to-dock customize-alphas true" 2>/dev/null || true
    $G "$E gsettings set org.gnome.shell.extensions.dash-to-dock min-alpha 0.15" 2>/dev/null || true
    $G "$E gsettings set org.gnome.shell.extensions.dash-to-dock max-alpha 0.45" 2>/dev/null || true
    $G "$E gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.25" 2>/dev/null || true
  done
  return 0
}

fix_animations() {
  apt-get install -y git make gettext unzip libglib2.0-bin 2>/dev/null || true

  # 1) force ALL animations on (system default)
  mkdir -p /etc/dconf/db/local.d
  cat > /etc/dconf/db/local.d/02-infinityos-anim <<EOF
[org/gnome/desktop/interface]
enable-animations=true
EOF
  dconf update 2>/dev/null || true

  # 2) Burn-My-Windows: animated open/close on every window, menu & dialog.
  #    Installed only if it genuinely supports this shell version (no forcing).
  local BMW="burn-my-windows@schneegans.github.com"
  local SV; SV=$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1); SV=${SV:-42}
  local BMW_OK=0
  local TMP; TMP=$(mktemp -d)
  if git clone --depth=1 https://github.com/Schneegans/Burn-My-Windows.git "$TMP/bmw" 2>/dev/null; then
    ( cd "$TMP/bmw" && make >/dev/null 2>&1 ) || true
    local ZIP; ZIP=$(ls "$TMP/bmw/"*.zip 2>/dev/null | head -1)
    if [ -n "$ZIP" ]; then
      local STAGE="$TMP/stage"; mkdir -p "$STAGE"
      unzip -o "$ZIP" -d "$STAGE" >/dev/null 2>&1
      # only install if metadata already lists our shell version — do NOT patch it
      if grep -q "\"$SV\"" "$STAGE/metadata.json" 2>/dev/null; then
        rm -rf "/usr/share/gnome-shell/extensions/$BMW"
        mkdir -p "/usr/share/gnome-shell/extensions/$BMW"
        cp -r "$STAGE/." "/usr/share/gnome-shell/extensions/$BMW/"
        [ -d "/usr/share/gnome-shell/extensions/$BMW/schemas" ] && \
          glib-compile-schemas "/usr/share/gnome-shell/extensions/$BMW/schemas" 2>/dev/null || true
        BMW_OK=1
      fi
    fi
  else
    rm -rf "$TMP"; return 1   # no internet -> retry next update
  fi
  rm -rf "$TMP"

  # 3) turn animations on for everyone logged in; enable the effect only if compatible
  local EXT="user-theme@gnome-shell-extensions.gcampax.github.com"
  for u in $(ls /home 2>/dev/null); do
    local uid; uid=$(id -u "$u" 2>/dev/null) || continue
    local G="su - $u -c"
    local E="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus"
    $G "$E gsettings set org.gnome.desktop.interface enable-animations true" 2>/dev/null || true
    if [ "$BMW_OK" = "1" ]; then
      $G "mkdir -p ~/.config/burn-my-windows/profiles" 2>/dev/null || true
      $G "bash -c 'printf \"[burn-my-windows-profile]\nfade-enable=true\nglide-enable=true\n\" > ~/.config/burn-my-windows/profiles/infinity.conf'" 2>/dev/null || true
      $G "$E gnome-extensions enable $BMW" 2>/dev/null || true
      $G "$E GSETTINGS_SCHEMA_DIR=/usr/share/gnome-shell/extensions/$BMW/schemas gsettings set org.gnome.shell.extensions.burn-my-windows active-profile \"/home/$u/.config/burn-my-windows/profiles/infinity.conf\"" 2>/dev/null || true
    fi
  done

  # 4) system default enabled list for fresh users (add BMW only if it's compatible)
  local LIST="'ubuntu-dock@ubuntu.com', 'ding@rastersoft.com', '$EXT'"
  [ "$BMW_OK" = "1" ] && LIST="$LIST, '$BMW'"
  cat >> /etc/dconf/db/local.d/02-infinityos-anim <<EOF

[org/gnome/shell]
enabled-extensions=[$LIST]
EOF
  dconf update 2>/dev/null || true
  return 0
}

fix_flatpak() {
  # Flatpak + Flathub = a real app store (Spotify, Discord, OBS, ...) in Software
  apt-get install -y flatpak gnome-software-plugin-flatpak || return 1
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
  return 0
}

fix_archives() {
  # open/extract every common archive type
  apt-get install -y p7zip-full p7zip-rar unrar unzip zip || return 1
  return 0
}

fix_codecs() {
  # play every common video/audio format
  apt-get install -y ffmpeg libavcodec-extra \
    gstreamer1.0-plugins-ugly gstreamer1.0-plugins-bad gstreamer1.0-libav || return 1
  return 0
}

fix_flathub_webapp() {
  # a "Flathub App Store" web app (opens Flathub in Brave, ChromeOS-Flex style)
  local BRAVE
  BRAVE=$(command -v brave-browser || command -v brave-browser-stable || command -v brave 2>/dev/null)
  [ -z "$BRAVE" ] && BRAVE="brave-browser"
  cat > /usr/share/applications/infinityos-flathub.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Flathub App Store
Comment=Browse and install apps from Flathub
Exec=$BRAVE --app=https://flathub.org --class=Flathub
Icon=system-software-install
Categories=System;PackageManager;Utility;
StartupNotify=true
EOF
  update-desktop-database /usr/share/applications 2>/dev/null || true
  return 0
}

fix_dns_malware() {
  # Cloudflare malware-blocking (1.1.1.2) + AdGuard (ads/trackers/malware) —
  # same protection family as the Windows app, forced over the router's DNS.
  cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=1.1.1.2 1.0.0.2 94.140.14.14 94.140.15.15
FallbackDNS=1.1.1.2 94.140.14.14
DNSStubListener=yes
EOF
  [ -e /etc/resolv.conf ] || ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
  systemctl enable systemd-resolved 2>/dev/null || true
  systemctl restart systemd-resolved 2>/dev/null || true
  mkdir -p /etc/NetworkManager/conf.d
  cat > /etc/NetworkManager/conf.d/00-infinityos-dns.conf <<EOF
[main]
dns=systemd-resolved

[global-dns-domain-*]
servers=1.1.1.2,1.0.0.2,94.140.14.14,94.140.15.15
EOF
  systemctl reload NetworkManager 2>/dev/null || true
  return 0
}

fix_antivirus() {
  # ClamAV (on-demand, light) + ClamTk GUI, branded as "Infinity Antivirus"
  apt-get install -y clamav clamtk || return 1
  systemctl stop clamav-freshclam 2>/dev/null || true
  freshclam 2>/dev/null || true
  systemctl enable --now clamav-freshclam 2>/dev/null || true
  cat > /usr/share/applications/infinityos-antivirus.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Infinity Antivirus
Comment=Scan files and folders for malware (ClamAV)
Exec=clamtk
Icon=clamtk
Categories=System;Security;Utility;
StartupNotify=true
EOF
  update-desktop-database /usr/share/applications 2>/dev/null || true
  return 0
}

fix_dock_pin() {
  # make sure the side dock is on so apps can be pinned (right-click > Pin to Dash)
  cat > /etc/dconf/db/local.d/03-infinityos-dock <<EOF
[org/gnome/shell/extensions/dash-to-dock]
dock-position='LEFT'
dock-fixed=true
show-apps-at-top=true
EOF
  dconf update 2>/dev/null || true
  for u in $(ls /home 2>/dev/null); do
    local uid; uid=$(id -u "$u" 2>/dev/null) || continue
    local G="su - $u -c"
    local E="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus"
    $G "$E gnome-extensions enable ubuntu-dock@ubuntu.com" 2>/dev/null || true
    $G "$E gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'LEFT'" 2>/dev/null || true
    $G "$E gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed true" 2>/dev/null || true
    $G "$E gsettings set org.gnome.shell.extensions.dash-to-dock show-apps-at-top true" 2>/dev/null || true
  done
  return 0
}


fix_teston_studio_update_app_20261006105940() {
  apt-get update
  apt-get install -y tlp tlp-rdw
  systemctl enable tlp.service
  systemctl start tlp.service
  return 0
}


fix_makean_option_for_user_i_20261006123351() {
  apt-get update -y
  apt-get install -y gnome-startup-applications
  return 0
}


fix_makean_option_for_user_i_20261006123637() {
  apt-get update -y
  apt-get install -y gnome-startup-applications
  return 0
}

fix_recovery_menu() {
  apt-get update -y || true
  apt-get install -y zenity timeshift deja-dup || return 1

  cat > /usr/local/bin/infinity-recovery <<'RECOVERY'
#!/bin/bash
# Infinity Recovery - maintenance, backup & restore menu (Ctrl+Alt+R)
run_term() {
  for t in gnome-terminal x-terminal-emulator xterm konsole; do
    if command -v "$t" >/dev/null 2>&1; then
      if [ "$t" = "gnome-terminal" ]; then exec gnome-terminal -- bash -c "$1; echo; read -p 'Press Enter to close...'"; else exec "$t" -e bash -c "$1; echo; read -p 'Press Enter to close...'"; fi
    fi
  done
}
C=$(zenity --list --title="Infinity Recovery" --width=480 --height=440 \
  --text="Choose a recovery option:" --hide-column=1 --print-column=1 \
  --column=key --column="Action" \
  restore   "Restore system to a snapshot (Timeshift)" \
  backup    "Back up your data (GNOME Backups)" \
  reinstall "Re-apply / repair Infinity OS setup" \
  fix       "Fix broken packages" \
  dns       "Reset DNS (AdGuard + Cloudflare)" \
  clean     "Clear cache & free up space" \
  rootterm  "Open a ROOT terminal" \
  reboot    "Restart the computer" 2>/dev/null)
case "$C" in
  restore)   (timeshift-launcher 2>/dev/null || pkexec timeshift-gtk 2>/dev/null) & ;;
  backup)    deja-dup & ;;
  reinstall) /usr/local/bin/infinityos-update & ;;
  fix)       run_term "sudo apt-get --fix-broken install -y; sudo dpkg --configure -a; sudo apt-get update -y" ;;
  dns)       run_term "echo -e '[Resolve]\nDNS=1.1.1.2 94.140.14.14\nFallbackDNS=1.1.1.1 8.8.8.8\nDNSStubListener=yes' | sudo tee /etc/systemd/resolved.conf >/dev/null && sudo systemctl restart systemd-resolved && echo 'DNS reset.'" ;;
  clean)     run_term "sudo apt-get clean; sudo apt-get autoremove -y; rm -rf ~/.cache/thumbnails/* 2>/dev/null; echo 'Cleaned.'" ;;
  rootterm)  run_term "sudo -i" ;;
  reboot)    zenity --question --text="Restart now?" 2>/dev/null && systemctl reboot ;;
esac
RECOVERY
  chmod +x /usr/local/bin/infinity-recovery

  cat > /usr/share/applications/infinity-recovery.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Infinity Recovery
Comment=Backup, restore, and repair Infinity OS
Exec=/usr/local/bin/infinity-recovery
Icon=system-reboot
Categories=System;Utility;
EOF
  update-desktop-database /usr/share/applications 2>/dev/null || true

  # bind Ctrl+Alt+R to the recovery menu for every user
  for u in $(ls /home 2>/dev/null); do
    local uid; uid=$(id -u "$u" 2>/dev/null) || continue
    local G="su - $u -c"
    local E="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus"
    local P="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/infinity-recovery/"
    local S="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$P"
    $G "$E gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \"['$P']\"" 2>/dev/null || true
    $G "$E gsettings set $S name 'Infinity Recovery'" 2>/dev/null || true
    $G "$E gsettings set $S command '/usr/local/bin/infinity-recovery'" 2>/dev/null || true
    $G "$E gsettings set $S binding '<Control><Alt>r'" 2>/dev/null || true
  done
  return 0
}

fix_full_recovery() {
  apt-get install -y zenity timeshift deja-dup 2>/dev/null || true

  # 1) Make the boot menu + Ubuntu's built-in Recovery Mode reachable (SAFE grub settings, with backup + rollback)
  if [ -f /etc/default/grub ]; then
    cp /etc/default/grub /etc/default/grub.infinity.bak 2>/dev/null || true
    for kv in "GRUB_DEFAULT=saved" "GRUB_TIMEOUT_STYLE=menu" "GRUB_TIMEOUT=5" 'GRUB_DISABLE_RECOVERY="false"'; do
      k="${kv%%=*}"
      sed -i "/^[#]*${k}=/d" /etc/default/grub
      echo "$kv" >> /etc/default/grub
    done
    if ! update-grub 2>/dev/null; then
      cp /etc/default/grub.infinity.bak /etc/default/grub 2>/dev/null || true
      update-grub 2>/dev/null || true
    fi
  fi

  # 2) Full recovery menu: restore, backup, reinstall/repair, boot-to-recovery, root terminal
  cat > /usr/local/bin/infinity-recovery <<'RECOVERY'
#!/bin/bash
run_term() {
  for t in gnome-terminal x-terminal-emulator xterm konsole; do
    if command -v "$t" >/dev/null 2>&1; then
      if [ "$t" = "gnome-terminal" ]; then exec gnome-terminal -- bash -c "$1; echo; read -p 'Press Enter to close...'"; else exec "$t" -e bash -c "$1; echo; read -p 'Press Enter to close...'"; fi
    fi
  done
}
boot_recovery() {
  local REC ADV
  REC=$(grep -oP "menuentry '\K[^']*recovery mode[^']*" /boot/grub/grub.cfg 2>/dev/null | head -1)
  ADV=$(grep -oP "submenu '\K[^']*" /boot/grub/grub.cfg 2>/dev/null | head -1)
  if [ -n "$REC" ] && [ -n "$ADV" ]; then
    pkexec grub-reboot "$ADV>$REC" 2>/dev/null && systemctl reboot
  else
    systemctl reboot
  fi
}
C=$(zenity --list --title="Infinity Recovery" --width=500 --height=480 \
  --text="Infinity OS Recovery - choose an option:" --hide-column=1 --print-column=1 \
  --column=key --column="Action" \
  restore    "Restore to a snapshot (Timeshift)" \
  backup     "Back up your data (GNOME Backups)" \
  reinstall  "Reinstall / repair Infinity OS" \
  recovery   "Reboot into Recovery Mode (repair menu)" \
  fix        "Fix broken packages" \
  dns        "Reset DNS (AdGuard + Cloudflare)" \
  clean      "Clear cache & free space" \
  rootterm   "Open a ROOT terminal" \
  reboot     "Restart the computer" 2>/dev/null)
case "$C" in
  restore)   (timeshift-launcher 2>/dev/null || pkexec timeshift-gtk 2>/dev/null) & ;;
  backup)    deja-dup & ;;
  reinstall) run_term "echo 'Reinstalling / repairing Infinity OS...'; sudo apt-get update -y; sudo apt-get install --reinstall -y gnome-shell gdm3 ubuntu-desktop-minimal 2>/dev/null; /usr/local/bin/infinityos-update" ;;
  recovery)  zenity --question --text="Reboot into Recovery Mode now?\n\nYou'll get repair tools: fix packages, root shell, disk check, network, etc." 2>/dev/null && boot_recovery ;;
  fix)       run_term "sudo apt-get --fix-broken install -y; sudo dpkg --configure -a" ;;
  dns)       run_term "echo -e '[Resolve]\nDNS=1.1.1.2 94.140.14.14\nFallbackDNS=1.1.1.1 8.8.8.8\nDNSStubListener=yes' | sudo tee /etc/systemd/resolved.conf >/dev/null && sudo systemctl restart systemd-resolved && echo 'DNS reset.'" ;;
  clean)     run_term "sudo apt-get clean; sudo apt-get autoremove -y; echo Cleaned." ;;
  rootterm)  run_term "sudo -i" ;;
  reboot)    zenity --question --text="Restart now?" 2>/dev/null && systemctl reboot ;;
esac
RECOVERY
  chmod +x /usr/local/bin/infinity-recovery
  return 0
}

fix_recovery_more() {
  apt-get install -y zenity timeshift deja-dup gnome-disk-utility x11-utils 2>/dev/null || true
  cat > /usr/local/bin/infinity-recovery <<'RECOVERY'
#!/bin/bash
run_term() {
  for t in gnome-terminal x-terminal-emulator xterm konsole; do
    if command -v "$t" >/dev/null 2>&1; then
      if [ "$t" = "gnome-terminal" ]; then exec gnome-terminal -- bash -c "$1; echo; read -p 'Press Enter to close...'"; else exec "$t" -e bash -c "$1; echo; read -p 'Press Enter to close...'"; fi
    fi
  done
}
boot_recovery() {
  local REC ADV
  REC=$(grep -oP "menuentry '\K[^']*recovery mode[^']*" /boot/grub/grub.cfg 2>/dev/null | head -1)
  ADV=$(grep -oP "submenu '\K[^']*" /boot/grub/grub.cfg 2>/dev/null | head -1)
  if [ -n "$REC" ] && [ -n "$ADV" ]; then pkexec grub-reboot "$ADV>$REC" 2>/dev/null && systemctl reboot; else systemctl reboot; fi
}
C=$(zenity --list --title="Infinity Recovery" --width=520 --height=560 \
  --text="Infinity OS Recovery - choose an option:" --hide-column=1 --print-column=1 \
  --column=key --column="Action" \
  restore    "Restore to a snapshot (Timeshift)" \
  snapshot   "Create a restore point NOW" \
  backup     "Back up your data (GNOME Backups)" \
  reinstall  "Reinstall / repair Infinity OS" \
  recovery   "Reboot into Recovery Mode (repair menu)" \
  update     "Update everything now" \
  fix        "Fix broken packages" \
  gui        "Fix the desktop / login screen" \
  dns        "Reset DNS (AdGuard + Cloudflare)" \
  network    "Reset network / WiFi" \
  disks      "Open Disks (partitions / USB)" \
  bootrepair "Repair the bootloader (GRUB)" \
  clean      "Clear cache & free space" \
  password   "Change your password" \
  killapp    "Force-close a frozen window" \
  rootterm   "Open a ROOT terminal" \
  reboot     "Restart the computer" \
  poweroff   "Shut down" 2>/dev/null)
case "$C" in
  restore)    (timeshift-launcher 2>/dev/null || pkexec timeshift-gtk 2>/dev/null) & ;;
  snapshot)   run_term "sudo timeshift --create --comments 'Infinity Recovery' --tags D" ;;
  backup)     deja-dup & ;;
  reinstall)  run_term "echo 'Reinstalling / repairing Infinity OS...'; sudo apt-get update -y; sudo apt-get install --reinstall -y gnome-shell gdm3 ubuntu-desktop-minimal 2>/dev/null; /usr/local/bin/infinityos-update" ;;
  recovery)   zenity --question --text="Reboot into Recovery Mode now?" 2>/dev/null && boot_recovery ;;
  update)     run_term "sudo apt-get update -y && sudo apt-get full-upgrade -y && echo 'Everything updated.'" ;;
  fix)        run_term "sudo apt-get --fix-broken install -y; sudo dpkg --configure -a" ;;
  gui)        run_term "sudo apt-get install --reinstall -y gdm3 gnome-shell ubuntu-session 2>/dev/null; echo 'Desktop repaired. Reboot to apply.'" ;;
  dns)        run_term "echo -e '[Resolve]\nDNS=1.1.1.2 94.140.14.14\nFallbackDNS=1.1.1.1 8.8.8.8\nDNSStubListener=yes' | sudo tee /etc/systemd/resolved.conf >/dev/null && sudo systemctl restart systemd-resolved && echo 'DNS reset.'" ;;
  network)    run_term "sudo systemctl restart NetworkManager && echo 'Network restarted.'" ;;
  disks)      (gnome-disks 2>/dev/null || gnome-disk-utility 2>/dev/null) & ;;
  bootrepair) run_term "sudo update-grub && echo 'Bootloader config rebuilt.'" ;;
  clean)      run_term "sudo apt-get clean; sudo apt-get autoremove -y; rm -rf ~/.cache/thumbnails/* 2>/dev/null; echo Cleaned." ;;
  password)   run_term "passwd" ;;
  killapp)    (command -v xkill >/dev/null && xkill || zenity --info --text='xkill not available.') & ;;
  rootterm)   run_term "sudo -i" ;;
  reboot)     zenity --question --text="Restart now?" 2>/dev/null && systemctl reboot ;;
  poweroff)   zenity --question --text="Shut down now?" 2>/dev/null && systemctl poweroff ;;
esac
RECOVERY
  chmod +x /usr/local/bin/infinity-recovery
  return 0
}


fix_set_adguard_cloudflare_d_20261006165005() {
  # (this update previously mis-added a cmatrix alias by mistake - now it REMOVES it)
  sed -i "/alias InfinityOS='cmatrix'/d" /etc/bash.bashrc 2>/dev/null || true
  return 0
}

fix_mr_infinity() {
  command -v python3 >/dev/null 2>&1 || apt-get install -y python3 2>/dev/null || true
  cat > /usr/local/bin/InfinityOS <<'MRINF'
#!/usr/bin/env python3
# Mr Infinity - the built-in AI of Infinity OS. Type: InfinityOS
import os, sys, json, re, shutil, subprocess, urllib.request, urllib.error

CFG_DIR = os.path.expanduser("~/.config/infinityos")
CFG = os.path.join(CFG_DIR, "mrinfinity.json")
UA = "Mozilla/5.0 (X11; Linux x86_64)"
SYSTEM = (
  "You are Mr Infinity, the friendly built-in AI assistant of Infinity OS, a Linux desktop. "
  "You are knowledgeable and helpful - you can answer anything. You can OPEN apps for the user: "
  "when they want to open/launch something, include a line EXACTLY like [[OPEN: <linux command>]] "
  "for example [[OPEN: brave-browser]], [[OPEN: firefox]], [[OPEN: nautilus]], [[OPEN: gnome-terminal]]. "
  "Common apps: brave-browser, firefox, nautilus (files), gnome-terminal, code, gnome-text-editor, "
  "vlc, gnome-calculator, gnome-control-center (settings), gnome-software, infinity-recovery. "
  "Only add [[OPEN:]] when they actually want to open something. Keep replies short and friendly."
)

def load_cfg():
    try:
        with open(CFG) as f: return json.load(f)
    except Exception: return {}

def save_cfg(c):
    os.makedirs(CFG_DIR, exist_ok=True)
    with open(CFG, "w") as f: json.dump(c, f)
    try: os.chmod(CFG, 0o600)
    except Exception: pass

def open_browser(url):
    for b in ["brave-browser", "brave-browser-stable", "firefox", "xdg-open"]:
        if shutil.which(b):
            subprocess.Popen([b, url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return

def pick_model(key):
    prefs = ["llama-3.3-70b-versatile", "openai/gpt-oss-120b", "llama-3.1-70b-versatile",
             "openai/gpt-oss-20b", "llama-3.1-8b-instant", "qwen/qwen3.8-27b"]
    try:
        req = urllib.request.Request("https://api.groq.com/openai/v1/models",
            headers={"Authorization": "Bearer " + key, "User-Agent": UA})
        ids = [m["id"] for m in json.load(urllib.request.urlopen(req, timeout=20))["data"]]
        for p in prefs:
            if p in ids: return p
        for i in ids:
            if not any(x in i for x in ["whisper", "guard", "orpheus", "tts"]): return i
    except Exception:
        pass
    return "llama-3.3-70b-versatile"

def setup():
    print("\n  ∞  Welcome to Mr Infinity - your Infinity OS AI assistant!\n")
    print("  You need a FREE Groq API key (takes about a minute).")
    print("  Opening the Groq console in your browser...")
    open_browser("https://console.groq.com/keys")
    print("  -> Sign in, click 'Create API Key', copy it, then paste it below.\n")
    key = input("  Paste your Groq API key (starts with gsk_): ").strip()
    if not key.startswith("gsk_"):
        print("  That doesn't look like a Groq key. Run 'InfinityOS' again to retry.")
        sys.exit(1)
    print("  Checking your key...")
    cfg = {"key": key, "model": pick_model(key)}
    save_cfg(cfg)
    print("  Saved! (model: %s). You won't have to do this again.\n" % cfg["model"])
    return cfg

def ask(cfg, messages):
    body = json.dumps({"model": cfg["model"], "messages": messages, "temperature": 0.4}).encode()
    req = urllib.request.Request("https://api.groq.com/openai/v1/chat/completions", data=body,
        headers={"Authorization": "Bearer " + cfg["key"], "Content-Type": "application/json", "User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)["choices"][0]["message"]["content"]

def run_opens(text):
    for cmd in re.findall(r"\[\[OPEN:\s*(.+?)\]\]", text):
        try:
            subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            print("  \U0001f680 opening: " + cmd)
        except Exception as e:
            print("  (couldn't open %s: %s)" % (cmd, e))
    return re.sub(r"\[\[OPEN:.*?\]\]", "", text).strip()

def main():
    if len(sys.argv) > 1 and sys.argv[1] in ("--setkey", "--reset", "setup"):
        setup(); return
    cfg = load_cfg()
    if not cfg.get("key"):
        cfg = setup()
    if len(sys.argv) > 1:
        msgs = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": " ".join(sys.argv[1:])}]
        try: print("  Mr Infinity:", run_opens(ask(cfg, msgs)))
        except Exception as e: print("  error:", e)
        return
    print("  ∞ Mr Infinity is ready. Ask me anything, or say 'open <app>'. Type 'exit' to quit.\n")
    msgs = [{"role": "system", "content": SYSTEM}]
    while True:
        try: q = input("  You: ").strip()
        except (EOFError, KeyboardInterrupt): print(); break
        if q.lower() in ("exit", "quit", "bye"): print("  Bye! ∞"); break
        if not q: continue
        msgs.append({"role": "user", "content": q})
        try:
            ans = ask(cfg, msgs)
        except urllib.error.HTTPError as e:
            print("  (API error %s - your key may be invalid; run 'InfinityOS --setkey')" % e.code); continue
        except Exception as e:
            print("  (error: %s)" % e); continue
        msgs.append({"role": "assistant", "content": ans})
        print("  Mr Infinity:", run_opens(ans), "\n")

if __name__ == "__main__":
    main()
MRINF
  chmod +x /usr/local/bin/InfinityOS
  ln -sf /usr/local/bin/InfinityOS /usr/local/bin/infinityos 2>/dev/null || true
  ln -sf /usr/local/bin/InfinityOS /usr/local/bin/mrinfinity 2>/dev/null || true
  return 0
}

fix_infinity_alias() {
  # Remove any old alias that hijacks 'InfinityOS' (e.g. -> cmatrix) so the real
  # Mr Infinity command (/usr/local/bin/InfinityOS) can run.
  local RE="/^[[:space:]]*alias[[:space:]]+(InfinityOS|infinityos|mrinfinity|MrInfinity)=/d"
  for f in /etc/bash.bashrc /etc/profile /etc/zsh/zshrc /etc/profile.d/*.sh; do
    [ -f "$f" ] && sed -i -E "$RE" "$f" 2>/dev/null || true
  done
  for h in /home/* /root; do
    [ -d "$h" ] || continue
    for f in "$h/.bashrc" "$h/.bash_aliases" "$h/.zshrc" "$h/.profile"; do
      [ -f "$f" ] && sed -i -E "$RE" "$f" 2>/dev/null || true
    done
  done
  return 0
}

fix_ai_alias() {
  # 1) nuke the old cmatrix alias from every shell config
  local RE="/alias[[:space:]]+(InfinityOS|infinityos|mrinfinity|MrInfinity|mrinf)=/d"
  for f in /etc/bash.bashrc /etc/profile /etc/zsh/zshrc /etc/profile.d/*.sh; do
    [ -f "$f" ] && sed -i -E "$RE" "$f" 2>/dev/null || true
  done
  for h in /home/* /root; do
    [ -d "$h" ] || continue
    for f in "$h/.bashrc" "$h/.bash_aliases" "$h/.zshrc" "$h/.profile"; do
      [ -f "$f" ] && sed -i -E "$RE" "$f" 2>/dev/null || true
    done
  done
  # 2) make 'mrinf' (and infinityos / mrinfinity) launch Mr Infinity
  if [ -f /usr/local/bin/InfinityOS ]; then
    ln -sf /usr/local/bin/InfinityOS /usr/local/bin/mrinf 2>/dev/null || true
    ln -sf /usr/local/bin/InfinityOS /usr/local/bin/mrinfinity 2>/dev/null || true
    ln -sf /usr/local/bin/InfinityOS /usr/local/bin/infinityos 2>/dev/null || true
  fi
  return 0
}

fix_mr_infinity_v2() {
  command -v python3 >/dev/null 2>&1 || apt-get install -y python3 2>/dev/null || true
  apt-get install -y gdebi-core 2>/dev/null || true   # for installing .deb files
  cat > /usr/local/bin/InfinityOS <<'MRINF'
#!/usr/bin/env python3
# Mr Infinity - the built-in AI of Infinity OS. Type: InfinityOS  (or mrinf)
import os, sys, json, re, shutil, subprocess, urllib.request, urllib.error

CFG_DIR = os.path.expanduser("~/.config/infinityos")
CFG = os.path.join(CFG_DIR, "mrinfinity.json")
UA = "Mozilla/5.0 (X11; Linux x86_64)"
SYSTEM = (
  "You are Mr Infinity, the friendly built-in AI assistant of Infinity OS, a Linux (Ubuntu-based) desktop. "
  "You are knowledgeable and helpful - you can answer anything.\n"
  "You can OPEN apps: include [[OPEN: <command>]] e.g. [[OPEN: brave-browser]], [[OPEN: nautilus]].\n"
  "You can INSTALL software or RUN commands: include [[RUN: <command>]]. The user is asked to confirm first.\n"
  "  - install from repos: [[RUN: sudo apt-get install -y <pkg>]]\n"
  "  - install a snap/flatpak: [[RUN: sudo snap install <pkg>]] or [[RUN: flatpak install -y flathub <id>]]\n"
  "  - install a downloaded .deb file: [[RUN: sudo apt-get install -y /full/path/to/file.deb]]\n"
  "Common apps: brave-browser, firefox, nautilus(files), gnome-terminal, code, vlc, gnome-calculator, "
  "gnome-control-center(settings), gnome-software, infinity-recovery.\n"
  "Only add [[OPEN:]]/[[RUN:]] when the user actually wants it. NEVER suggest destructive commands "
  "(no rm -rf of system paths, no formatting/dd to disks, no fork bombs). Keep replies short and friendly."
)
DANGER = ["rm -rf /", "rm -rf ~", "mkfs", "dd if=", "of=/dev/", ":(){", "chmod -r 777 /",
          "> /dev/sd", "fdisk ", "parted ", "userdel", "deluser", "> /dev/null 2>&1 &"]

def load_cfg():
    try:
        with open(CFG) as f: return json.load(f)
    except Exception: return {}

def save_cfg(c):
    os.makedirs(CFG_DIR, exist_ok=True)
    with open(CFG, "w") as f: json.dump(c, f)
    try: os.chmod(CFG, 0o600)
    except Exception: pass

def open_browser(url):
    for b in ["brave-browser", "brave-browser-stable", "firefox", "xdg-open"]:
        if shutil.which(b):
            subprocess.Popen([b, url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return

def pick_model(key):
    prefs = ["llama-3.3-70b-versatile", "openai/gpt-oss-120b", "llama-3.1-70b-versatile",
             "openai/gpt-oss-20b", "llama-3.1-8b-instant", "qwen/qwen3.8-27b"]
    try:
        req = urllib.request.Request("https://api.groq.com/openai/v1/models",
            headers={"Authorization": "Bearer " + key, "User-Agent": UA})
        ids = [m["id"] for m in json.load(urllib.request.urlopen(req, timeout=20))["data"]]
        for p in prefs:
            if p in ids: return p
        for i in ids:
            if not any(x in i for x in ["whisper", "guard", "orpheus", "tts"]): return i
    except Exception:
        pass
    return "llama-3.3-70b-versatile"

def setup():
    print("\n  ∞  Welcome to Mr Infinity - your Infinity OS AI assistant!\n")
    print("  You need a FREE Groq API key (takes about a minute).")
    print("  Opening the Groq console in your browser...")
    open_browser("https://console.groq.com/keys")
    print("  -> Sign in, click 'Create API Key', copy it, then paste it below.\n")
    key = input("  Paste your Groq API key (starts with gsk_): ").strip()
    if not key.startswith("gsk_"):
        print("  That doesn't look like a Groq key. Run 'mrinf' again to retry."); sys.exit(1)
    print("  Checking your key...")
    cfg = {"key": key, "model": pick_model(key)}
    save_cfg(cfg)
    print("  Saved! (model: %s). You won't have to do this again.\n" % cfg["model"])
    return cfg

def ask(cfg, messages):
    body = json.dumps({"model": cfg["model"], "messages": messages, "temperature": 0.4}).encode()
    req = urllib.request.Request("https://api.groq.com/openai/v1/chat/completions", data=body,
        headers={"Authorization": "Bearer " + cfg["key"], "Content-Type": "application/json", "User-Agent": UA})
    with urllib.request.urlopen(req, timeout=90) as r:
        return json.load(r)["choices"][0]["message"]["content"]

def act(text):
    for cmd in re.findall(r"\[\[OPEN:\s*(.+?)\]\]", text):
        try:
            subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            print("  \U0001f680 opened: " + cmd)
        except Exception as e:
            print("  (couldn't open %s: %s)" % (cmd, e))
    for cmd in re.findall(r"\[\[RUN:\s*(.+?)\]\]", text):
        if any(d in cmd.lower() for d in DANGER):
            print("  ⛔ refused (looks destructive): " + cmd); continue
        print("\n  Mr Infinity wants to run:\n    \033[1m" + cmd + "\033[0m")
        try:
            ok = input("  Run it? [y/N]: ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            ok = "n"
        if ok == "y":
            print("  ---")
            subprocess.call(cmd, shell=True)
            print("  --- done.")
        else:
            print("  Skipped.")
    return re.sub(r"\[\[(OPEN|RUN):.*?\]\]", "", text).strip()

def main():
    if len(sys.argv) > 1 and sys.argv[1] in ("--setkey", "--reset", "setup"):
        setup(); return
    cfg = load_cfg()
    if not cfg.get("key"):
        cfg = setup()
    if len(sys.argv) > 1:
        msgs = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": " ".join(sys.argv[1:])}]
        try: print("  Mr Infinity:", act(ask(cfg, msgs)))
        except Exception as e: print("  error:", e)
        return
    print("  ∞ Mr Infinity is ready. Ask me anything - I can open AND install apps. Type 'exit' to quit.\n")
    msgs = [{"role": "system", "content": SYSTEM}]
    while True:
        try: q = input("  You: ").strip()
        except (EOFError, KeyboardInterrupt): print(); break
        if q.lower() in ("exit", "quit", "bye"): print("  Bye! ∞"); break
        if not q: continue
        msgs.append({"role": "user", "content": q})
        try:
            ans = ask(cfg, msgs)
        except urllib.error.HTTPError as e:
            print("  (API error %s - run 'mrinf --setkey' to re-enter your key)" % e.code); continue
        except Exception as e:
            print("  (error: %s)" % e); continue
        msgs.append({"role": "assistant", "content": ans})
        print("  Mr Infinity:", act(ans), "\n")

if __name__ == "__main__":
    main()
MRINF
  chmod +x /usr/local/bin/InfinityOS
  for n in infinityos mrinfinity mrinf; do ln -sf /usr/local/bin/InfinityOS "/usr/local/bin/$n" 2>/dev/null || true; done
  return 0
}

# ===== Run =====
echo "Checking Infinity OS fixes (each applies once per laptop)..."

# keep the update system itself current every time (instant, no apt)
install_updater_app
install_notifier
install_firstboot

# one-time fixes — order matters: sources before the installs
apply_once dns          fix_dns
apply_once apt-sources  fix_apt_sources
apply_once cmatrix      feat_cmatrix
apply_once camera-v2    fix_camera
apply_once wine-exe     fix_wine_exe
apply_once wine-proper  fix_wine_proper
apply_once glass-look-v2 fix_glass_look
apply_once animations    fix_animations
apply_once flatpak       fix_flatpak
apply_once archives      fix_archives
apply_once codecs        fix_codecs
apply_once flathub-webapp fix_flathub_webapp
apply_once dns-malware    fix_dns_malware
apply_once antivirus      fix_antivirus
apply_once dock-pin       fix_dock_pin

apply_once teston-studio-update-app-20261006105940 fix_teston_studio_update_app_20261006105940

apply_once makean-option-for-user-i-20261006123351 fix_makean_option_for_user_i_20261006123351

apply_once makean-option-for-user-i-20261006123637 fix_makean_option_for_user_i_20261006123637
apply_once recovery-menu  fix_recovery_menu
apply_once full-recovery  fix_full_recovery
apply_once recovery-more  fix_recovery_more
apply_once mr-infinity    fix_mr_infinity
apply_once infinity-alias fix_infinity_alias
apply_once ai-alias-mrinf fix_ai_alias
apply_once mr-infinity-v2 fix_mr_infinity_v2

apply_once set-adguard-cloudflare-d-20261006165005 fix_set_adguard_cloudflare_d_20261006165005

# record the version we're now at (so the notifier knows we're current)
mkdir -p /etc/infinityos
wget -qO- "$REPO/version" 2>/dev/null | tr -dc '0-9' > /etc/infinityos/version || true

echo "Infinity OS fixes complete."
