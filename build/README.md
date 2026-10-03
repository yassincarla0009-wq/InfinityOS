# Infinity OS — Build Source

These are the scripts that build **Infinity OS** from a stock Ubuntu 22.04 live ISO.
With them, anyone can reproduce the ISO from scratch — this is the "source code" of the OS.

## How it works (high level)

Infinity OS is a **remaster** of Ubuntu 22.04 LTS: the live ISO is unpacked, the
root filesystem is modified inside a chroot (rebranding, apps, theme, DNS, fixes),
then repacked into a new bootable ISO.

Build host: a Linux machine (WSL2 Ubuntu works). Run the numbered scripts in order.

## Scripts (run in order)

| Script | What it does |
|---|---|
| `01_prep.sh` | Install build tools (squashfs-tools, xorriso, etc.) |
| `02_download.sh` | Download the Ubuntu 22.04 base ISO |
| `03_extract.sh` | Unpack the ISO + squashfs root filesystem |
| `04_customize.sh` / `04b_fix.sh` | Core rebrand, apps, repos (Brave, Firefox, Wine…) |
| `05_repack.sh` | Rebuild squashfs + build the bootable ISO (BIOS+UEFI) |
| `06_installer.sh` | Configure the installer (ubiquity) |
| `07_fix_all.sh` / `10_retry_all.sh` | Repair passes |
| `08_gaming.sh` | Lutris, GameMode, MangoHud |
| `09_wallpaper.sh` | Deep-space wallpaper + boot splash |
| `11_office_fps.sh` | Microsoft 365 web apps + FPS/perf tuning |
| `12_finalfix.sh` | Final cleanup |
| `13_debrand.sh` | Remove remaining Ubuntu branding |
| `14_noinstaller.sh` | Remove installer after install |
| `15_report.sh` | "Report a Problem" app |
| `16_dvd.sh` | DVD playback (VLC + libdvdcss) |
| `17_remove_steam.sh` | Remove Steam (users install it themselves) |
| `18_fix_installer.sh` | Fix partitioning (python3-pyparted) |
| `19_fix_gui.sh` | Restore GDM3 / GNOME session / graphical boot |
| `20_fix_dns.sh` | AdGuard DNS defaults |
| `21_updater.sh` | Built-in "Infinity OS Updates" app |
| `diag.sh` / `diag2.sh` | Diagnostics |

## Helpers / assets

- `make_wallpaper.py`, `make_logo.py`, `make_office_icons.py` — generate the branding assets
- `wallpaper.png`, `boot_logo.png`, `grub_bg.png`, `office_icons/` — generated assets

## Live updates

After install, the OS pulls fixes/features from [`update.sh`](../update.sh) in this
repo via the built-in **Infinity OS Updates** app. See the repo root for that.

---
Infinity OS — powered by GNOME — built by Yassin
