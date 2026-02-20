#!/usr/bin/env bash
# debug-capture.sh — run libfprint image capture with verbose diagnostics
#
# Usage:
#   ./host-tools/debug-capture.sh [output.pgm]
#
# Optional environment variables:
#   LIBFPRINT_BUILD_DIR    path to build dir (default: ./libfprint-fork/build)
#   FP_DRIVER_ALLOWLIST    libfprint driver allowlist value (optional)
#
# Example:
#   FP_DRIVER_ALLOWLIST=goodixtls511 ./host-tools/debug-capture.sh capture-1.pgm

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${LIBFPRINT_BUILD_DIR:-$REPO_ROOT/libfprint-fork/build}"
IMG_CAPTURE_BIN="$BUILD_DIR/examples/img-capture"
OUTPUT_FILE="${1:-finger.pgm}"

info() { echo "  [+] $*"; }
die()  { echo "  [✗] $*" >&2; exit 1; }

[[ -x "$IMG_CAPTURE_BIN" ]] || die "img-capture not found/executable: $IMG_CAPTURE_BIN"

info "Using build dir: $BUILD_DIR"
info "Output image: $OUTPUT_FILE"

if [[ -n "${FP_DRIVER_ALLOWLIST:-}" ]]; then
  info "Driver allowlist: $FP_DRIVER_ALLOWLIST"
  export FP_DRIVERS_ALLOWLIST="$FP_DRIVER_ALLOWLIST"
fi

export G_MESSAGES_DEBUG=all
export LIBUSB_DEBUG=3
export FP_DEBUG_TRANSFER=1

info "Running img-capture with maximum debug output"
"$IMG_CAPTURE_BIN" "$OUTPUT_FILE"

echo ""
echo "  ✓ Capture complete: $OUTPUT_FILE"
echo ""
