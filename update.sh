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

# record the version we're now at (so the notifier knows we're current)
mkdir -p /etc/infinityos
wget -qO- "$REPO/version" 2>/dev/null | tr -dc '0-9' > /etc/infinityos/version || true

echo "Infinity OS fixes complete."
