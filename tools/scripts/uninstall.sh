#!/usr/bin/env bash
# uninstall.sh — remove the libfprint-goodixtls511-git AUR package
#                and restore the upstream libfprint
#
# Usage:  sudo ./uninstall.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info() { echo "  [+] $*"; }
warn() { echo "  [!] $*"; }
die()  { echo "  [✗] $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
[[ $EUID -eq 0 ]] || die "This script must be run as root (sudo $0)"
command -v pacman &>/dev/null || die "pacman not found — this script requires Arch / CachyOS."

AUR_PKG="libfprint-goodixtls511-git"

# ---------------------------------------------------------------------------
# Remove our package
# ---------------------------------------------------------------------------
if pacman -Q "$AUR_PKG" &>/dev/null 2>&1; then
    info "Removing $AUR_PKG via pacman"
    pacman -R --noconfirm "$AUR_PKG"
else
    warn "$AUR_PKG is not installed — nothing to remove."
fi

# ---------------------------------------------------------------------------
# Restore upstream libfprint
# ---------------------------------------------------------------------------
info "Reinstalling upstream libfprint via pacman"
pacman -S --noconfirm libfprint

# ---------------------------------------------------------------------------
# Refresh udev and fprintd
# ---------------------------------------------------------------------------
info "Updating udev hardware database"
systemd-hwdb update

info "Triggering udev for USB fingerprint devices"
udevadm trigger --subsystem-match=usb --attr-match=idVendor=27c6 2>/dev/null || \
    udevadm trigger --subsystem-match=usb

if systemctl is-active --quiet fprintd 2>/dev/null; then
    info "Restarting fprintd"
    systemctl restart fprintd
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "  ✓  Uninstall complete. Upstream libfprint restored."
echo ""
