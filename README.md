# ∞ Infinity OS

A custom Linux desktop — **powered by GNOME**, built by Yassin.

Glassy GNOME desktop with a neon infinity theme. Boots live from USB and installs
to any drive. A real, usable daily OS.

![Infinity OS](https://img.shields.io/badge/Infinity%20OS-1.0-00e5ff)

## ✨ Features
- GNOME desktop with the **WhiteSur "liquid glass"** dark theme
- Neon ∞ boot splash + deep-space wallpaper
- Fully rebranded — **no Ubuntu apps**, only Infinity OS
- **Brave** (default) + make any site a web app (ChromeOS-Flex style)
- **Microsoft 365** web apps (Word, Excel, PowerPoint, Outlook)
- **Firefox**, run Windows apps with **Wine** (.exe / .msi)
- Gaming: **Lutris, GameMode, MangoHud**
- **DVD playback** (VLC + libdvdcss)
- **Variety** internet wallpapers, eject drives, GParted
- **Report a Problem** app, **manual** updates (no forced updates)
- Lightweight (no snapd / tracker) + smooth

## 📥 Download & install
1. Download **all** ISO parts from the [latest Release](../../releases/latest):
   `InfinityOS.iso.001`, `.002`, `.003`
2. Rejoin them:
   - **Windows:** `copy /b InfinityOS.iso.001+InfinityOS.iso.002+InfinityOS.iso.003 InfinityOS.iso`
   - **Linux/macOS:** `cat InfinityOS.iso.* > InfinityOS.iso`
3. Verify: the SHA256 must match `SHA256.txt`
4. Flash to USB with **Rufus / Ventoy / balenaEtcher** — or use the included
   **InfinityOS-USB-Creator.exe** (downloads + rejoins + flashes in one click, Windows).
5. Boot the PC (F12 / Novo button) → **Try or Install Infinity OS**.

## 🔐 Verify
```
Windows:   Get-FileHash InfinityOS.iso -Algorithm SHA256
Linux/mac: sha256sum InfinityOS.iso
```

## 🛠️ Built with
Ubuntu 22.04 LTS base, remastered with squashfs-tools + xorriso.
Build scripts in this repo.

---
**Infinity OS — powered by GNOME — built by Yassin**
