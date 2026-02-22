#!/usr/bin/env bash
# debug-capture.sh — run a single libfprint capture/enroll/verify with debug logging
#
# Captures a fingerprint image and saves the debug log alongside it.
# The log contains SIGFM metrics (keypoint count, extraction time, match scores)
# which can be parsed by analyze-capture.py --log.
#
# For capturing many frames for offline A/B testing, use capture-corpus.sh instead.
#
# Usage:
#   ./tools/scripts/debug-capture.sh [output.pgm]
#
# Optional environment variables:
#   LIBFPRINT_BUILD_DIR    path to build dir (default: ./libfprint-fork/build)
#   FP_DRIVER_ALLOWLIST    libfprint driver allowlist value (optional)
#   CAPTURE_MODE           'capture' (default), 'enroll', or 'verify'
#
# Example:
#   ./tools/scripts/debug-capture.sh capture-1.pgm
#   CAPTURE_MODE=enroll ./tools/scripts/debug-capture.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="${LIBFPRINT_BUILD_DIR:-$REPO_ROOT/libfprint-fork/build}"
MODE="${CAPTURE_MODE:-capture}"
OUTPUT_FILE="${1:-finger.pgm}"
LOG_FILE="${OUTPUT_FILE%.pgm}.log"

info() { echo "  [+] $*"; }
die()  { echo "  [✗] $*" >&2; exit 1; }

# Select binary based on mode
case "$MODE" in
  capture) BIN="$BUILD_DIR/examples/img-capture" ;;
  enroll)  BIN="$BUILD_DIR/examples/enroll" ;;
  verify)  BIN="$BUILD_DIR/examples/verify" ;;
  *)       die "Unknown CAPTURE_MODE: $MODE (use capture, enroll, or verify)" ;;
esac

[[ -x "$BIN" ]] || die "Binary not found/executable: $BIN"

info "Mode: $MODE"
info "Using build dir: $BUILD_DIR"
info "Output image: $OUTPUT_FILE"
info "Debug log: $LOG_FILE"

if [[ -n "${FP_DRIVER_ALLOWLIST:-}" ]]; then
  info "Driver allowlist: $FP_DRIVER_ALLOWLIST"
  export FP_DRIVERS_ALLOWLIST="$FP_DRIVER_ALLOWLIST"
fi

export G_MESSAGES_DEBUG=all

# Run with debug output captured to log file (and also shown on terminal).
# Use a named pipe so that stdin stays connected to the terminal (piping
# through tee directly would eat stdin and break interactive prompts).
info "Running $MODE with debug output"
FIFO=$(mktemp -u /tmp/fp-debug-XXXXXX.fifo)
mkfifo "$FIFO"
trap 'rm -f "$FIFO"' EXIT
tee "$LOG_FILE" < "$FIFO" &
TEE_PID=$!

if [[ "$MODE" == "capture" ]]; then
  "$BIN" "$OUTPUT_FILE" > "$FIFO" 2>&1
else
  "$BIN" > "$FIFO" 2>&1
fi

wait "$TEE_PID" 2>/dev/null

echo ""
echo "  ✓ $MODE complete"
echo ""

# ── Parse SIGFM metrics from log ──────────────────────────────────────

parse_metrics() {
  local log="$1"

  local kp
  kp=$(grep -oP 'sigfm keypoints: \K\d+' "$log" 2>/dev/null | tail -1)
  if [[ -n "$kp" ]]; then
    local status="✓"
    (( kp < 25 )) && status="✗ (need ≥25)"
    echo "  Keypoints:    $kp  $status"
  fi

  local time
  time=$(grep -oP 'sigfm extract completed in \K[0-9.]+' "$log" 2>/dev/null | tail -1)
  if [[ -n "$time" ]]; then
    echo "  Extract time: ${time}s"
  fi

  local scores
  scores=$(grep -oP 'sigfm score \K\d+/\d+' "$log" 2>/dev/null)
  if [[ -n "$scores" ]]; then
    while IFS= read -r line; do
      local s="${line%/*}" t="${line#*/}"
      local result="✗ no match"
      (( s >= t )) && result="✓ match"
      echo "  Score:        $s/$t  $result"
    done <<< "$scores"
  fi

  [[ -z "$kp" && -z "$time" && -z "$scores" ]] && return 1
  return 0
}

if parse_metrics "$LOG_FILE"; then
  echo ""
  echo "  Run analysis:  python3 tools/analyze-capture.py $OUTPUT_FILE --log $LOG_FILE"
else
  echo "  No SIGFM metrics in log (img-capture doesn't run SIGFM extraction)."
  echo "  For SIGFM metrics, use:  CAPTURE_MODE=enroll ./tools/debug-capture.sh"
  echo ""
  echo "  Run analysis:  python3 tools/analyze-capture.py $OUTPUT_FILE"
fi
