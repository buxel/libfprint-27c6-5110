#!/usr/bin/env bash
# capture-corpus.sh — Capture N raw frames for offline A/B testing
#
# Runs img-capture in a loop, saving raw frames via FP_SAVE_RAW.
# Each capture triggers one sensor read; you press your finger once per capture.
#
# Usage:
#   ./tools/benchmark/capture-corpus.sh [CORPUS_DIR] [N_FRAMES]
#
# Example:
#   ./tools/benchmark/capture-corpus.sh ./corpus/baseline 20
#   ./tools/benchmark/capture-corpus.sh ./corpus/baseline     # default: 20 frames

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="${LIBFPRINT_BUILD_DIR:-$REPO_ROOT/libfprint-fork/build}"
BIN="$BUILD_DIR/examples/img-capture"

CORPUS_DIR="${1:-./corpus/baseline}"
N_FRAMES="${2:-20}"

info() { echo "  [+] $*"; }
warn() { echo "  [!] $*"; }
die()  { echo "  [✗] $*" >&2; exit 1; }

[[ -x "$BIN" ]] || die "img-capture not found: $BIN"

mkdir -p "$CORPUS_DIR"
export FP_SAVE_RAW="$CORPUS_DIR"

info "Corpus capture: $N_FRAMES frames → $CORPUS_DIR"
info "Using: $BIN"
echo ""
echo "  Place your finger on the sensor for each capture."
echo "  Lift and re-place between captures for variation."
echo ""

SUCCESS=0
FAIL=0

for i in $(seq 1 "$N_FRAMES"); do
  OUTFILE="$CORPUS_DIR/capture_$(printf '%04d' "$i").pgm"
  LOGFILE="$CORPUS_DIR/capture_$(printf '%04d' "$i").log"
  printf "  [%02d/%02d] Waiting for finger... " "$i" "$N_FRAMES"

  # Run with debug output to log file only (not terminal — too noisy)
  if G_MESSAGES_DEBUG=all "$BIN" "$OUTFILE" 2>"$LOGFILE"; then
    KP=$(grep -oP 'sigfm keypoints: \K\d+' "$LOGFILE" 2>/dev/null | tail -1)
    printf "✓"
    [[ -n "$KP" ]] && printf " (kp: %s)" "$KP"
    echo ""
    SUCCESS=$((SUCCESS + 1))
  else
    echo "✗ failed (see $LOGFILE)"
    FAIL=$((FAIL + 1))
  fi

  # Let user see the result and lift finger before next capture
  if [[ "$i" -lt "$N_FRAMES" ]]; then
    sleep 0.5
  fi
done

echo ""
echo "  ─── Summary ───────────────────────────"
echo "  Captured: $SUCCESS / $N_FRAMES"
echo "  Failed:   $FAIL"
echo "  Directory: $CORPUS_DIR"

RAW_COUNT=$(find "$CORPUS_DIR" -name 'raw_*.bin' 2>/dev/null | wc -l)
CAL="no"; [[ -f "$CORPUS_DIR/calibration.bin" ]] && CAL="yes"
echo "  Raw frames: $RAW_COUNT"
echo "  Calibration: $CAL"
echo ""
echo "  Next steps:"
echo "    # Replay with default preprocessing:"
echo "    ./tools/benchmark/replay-pipeline --batch $CORPUS_DIR"
echo ""
echo "    # Run SIGFM benchmark (split into enroll + verify sets):"
echo "    ./tools/benchmark/sigfm-batch --enroll $CORPUS_DIR/capture_000{1..9}.pgm $CORPUS_DIR/capture_0010.pgm \\"
echo "                                      --verify $CORPUS_DIR/capture_001{1..9}.pgm $CORPUS_DIR/capture_0020.pgm"
