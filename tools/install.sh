#!/usr/bin/env bash
# install.sh — build and install the libfprint-goodixtls511-git AUR package
#
# Usage:  ./install.sh
#
# Must be run from an Arch / CachyOS host (requires makepkg and pacman).
# Do NOT run as root — makepkg refuses to run as root; sudo is invoked
# internally only for the pacman install step.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AUR_DIR="$(cd "$SCRIPT_DIR/../packaging/aur" && pwd)"
LIBFPRINT_REPO="$REPO_ROOT/libfprint-fork"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info() { echo "  [+] $*"; }
die()  { echo "  [✗] $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
[[ $EUID -ne 0 ]] || die "Do not run as root. Run as a regular user: ./install.sh"
command -v makepkg &>/dev/null || die "makepkg not found — this script requires Arch / CachyOS."
command -v pacman  &>/dev/null || die "pacman not found — this script requires Arch / CachyOS."
[[ -f "$AUR_DIR/PKGBUILD" ]] || die "PKGBUILD not found: $AUR_DIR/PKGBUILD"

# ---------------------------------------------------------------------------
# Remove conflicting packages
# ---------------------------------------------------------------------------
# makepkg --noconfirm does not auto-answer pacman's conflict prompt when an
# existing libfprint needs to be replaced. Remove it up-front so the install
# proceeds unattended.
for pkg in libfprint libfprint-goodixtls-git; do
    if pacman -Q "$pkg" &>/dev/null; then
        info "Removing conflicting package: $pkg"
        sudo pacman -Rdd --noconfirm "$pkg"
    fi
done

# ---------------------------------------------------------------------------
# Build and install
# ---------------------------------------------------------------------------
info "Building AUR package from $AUR_DIR (source: $LIBFPRINT_REPO)"
cd "$AUR_DIR"
LIBFPRINT_LOCAL_REPO="$LIBFPRINT_REPO" makepkg -si --noconfirm

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo "  ✓  Installed. pacman now owns the libfprint files."
echo "     Enroll a finger:"
echo "       fprintd-enroll -f right-index-finger \$USER"
echo "     Or via KDE: System Settings → Users → Fingerprint Authentication"
echo ""
