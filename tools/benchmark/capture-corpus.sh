#!/usr/bin/env bash
# capture-corpus.sh — Capture raw frames for offline A/B testing
#
# Single-finger mode:
#   ./tools/benchmark/capture-corpus.sh [CORPUS_DIR] [N_FRAMES]
#
# Multi-finger mode (captures all 5 fingers on one hand):
#   ./tools/benchmark/capture-corpus.sh --multi [CORPUS_DIR] [N_FRAMES]
#
# Examples:
#   ./tools/benchmark/capture-corpus.sh ./corpus/baseline 20
#   ./tools/benchmark/capture-corpus.sh --multi ./corpus/phase10 30

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="${LIBFPRINT_BUILD_DIR:-$REPO_ROOT/libfprint-fork/build}"
BIN="$BUILD_DIR/examples/img-capture"

FINGERS=(right-thumb right-index right-middle right-ring right-little)

info() { echo "  [+] $*"; }
warn() { echo "  [!] $*"; }
die()  { echo "  [✗] $*" >&2; exit 1; }

# ── Parse arguments ─────────────────────────────────────────────────
MULTI=false
if [[ "${1:-}" == "--multi" ]]; then
  MULTI=true
  shift
fi

CORPUS_DIR="${1:-./corpus/baseline}"
N_FRAMES="${2:-20}"

[[ -x "$BIN" ]] || die "img-capture not found: $BIN"

# ── Capture one finger into a directory ─────────────────────────────
capture_finger() {
  local dir="$1"
  local n="$2"
  local label="$3"

  mkdir -p "$dir"
  export FP_SAVE_RAW="$dir"

  local success=0 fail=0

  for i in $(seq 1 "$n"); do
    local outfile="$dir/capture_$(printf '%04d' "$i").pgm"
    local logfile="$dir/capture_$(printf '%04d' "$i").log"
    printf "  [%02d/%02d] %s — waiting for finger... " "$i" "$n" "$label"

    # img-capture writes debug to stderr; some GLib versions also use stdout
    if G_MESSAGES_DEBUG=all "$BIN" "$outfile" >"$logfile" 2>&1; then
      :
    fi
    # Judge success by whether a valid PGM was produced, not exit code
    # (img-capture has historically returned non-zero even on success)
    if [[ -s "$outfile" ]]; then
      local kp
      kp=$(grep -oP 'sigfm keypoints: \K\d+' "$logfile" 2>/dev/null | tail -1)
      printf "✓"
      [[ -n "${kp:-}" ]] && printf " (kp: %s)" "$kp"
      echo ""
      success=$((success + 1))
    else
      echo "✗ failed (see $logfile)"
      fail=$((fail + 1))
    fi

    [[ "$i" -lt "$n" ]] && sleep 0.5
  done

  echo ""
  echo "  ─── $label ───────────────────────"
  echo "  Captured: $success / $n"
  echo "  Failed:   $fail"
  local raw_count
  raw_count=$(find "$dir" -name 'raw_*.bin' 2>/dev/null | wc -l)
  local cal="no"; [[ -f "$dir/calibration.bin" ]] && cal="yes"
  echo "  Raw frames: $raw_count  |  Calibration: $cal"
}

# ── Single-finger mode ──────────────────────────────────────────────
if [[ "$MULTI" == false ]]; then
  info "Single-finger capture: $N_FRAMES frames → $CORPUS_DIR"
  info "Using: $BIN"
  echo ""
  echo "  Place your finger on the sensor for each capture."
  echo "  Lift and re-place between captures for variation."
  echo ""

  capture_finger "$CORPUS_DIR" "$N_FRAMES" "finger"

  echo ""
  echo "  Next steps:"
  echo "    # Replay with default preprocessing:"
  echo "    ./tools/benchmark/replay-pipeline --batch $CORPUS_DIR"
  echo ""
  echo "    # Run SIGFM benchmark (enroll first half, verify second half):"
  HALF=$((N_FRAMES / 2))
  E_LAST=$(printf '%04d' "$HALF")
  V_FIRST=$(printf '%04d' $((HALF + 1)))
  V_LAST=$(printf '%04d' "$N_FRAMES")
  echo "    ./tools/benchmark/sigfm-batch \\"
  echo "        --enroll $CORPUS_DIR/capture_0001.pgm .. $CORPUS_DIR/capture_$E_LAST.pgm \\"
  echo "        --verify $CORPUS_DIR/capture_$V_FIRST.pgm .. $CORPUS_DIR/capture_$V_LAST.pgm"
  exit 0
fi

# ── Multi-finger mode ───────────────────────────────────────────────
TOTAL_FINGERS=${#FINGERS[@]}
TOTAL_FRAMES=$((N_FRAMES * TOTAL_FINGERS))

info "Multi-finger capture: $TOTAL_FINGERS fingers × $N_FRAMES frames = $TOTAL_FRAMES total"
info "Output: $CORPUS_DIR/{$(IFS=,; echo "${FINGERS[*]}")}"
info "Using: $BIN"
echo ""
echo "  For each finger you'll be prompted $N_FRAMES times."
echo "  Vary pressure and placement between presses."
echo ""

GRAND_SUCCESS=0
GRAND_FAIL=0

for idx in "${!FINGERS[@]}"; do
  finger="${FINGERS[$idx]}"
  finger_dir="$CORPUS_DIR/$finger"
  num=$((idx + 1))

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Finger $num/$TOTAL_FINGERS: $finger"
  echo "  Place your ** ${finger//-/ } ** on the sensor."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  read -rp "  Press Enter when ready (or 'q' to stop) " ans
  [[ "$ans" == "q" ]] && { echo "  Stopped."; break; }

  capture_finger "$finger_dir" "$N_FRAMES" "$finger"

  # count totals from that finger
  local_success=$(find "$finger_dir" -name 'capture_*.pgm' 2>/dev/null | wc -l)
  local_fail=$((N_FRAMES - local_success))
  GRAND_SUCCESS=$((GRAND_SUCCESS + local_success))
  GRAND_FAIL=$((GRAND_FAIL + local_fail))

  echo ""
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Grand total: $GRAND_SUCCESS captured, $GRAND_FAIL failed"
echo "  Corpus: $CORPUS_DIR"
echo ""

# Show per-finger summary
for finger in "${FINGERS[@]}"; do
  d="$CORPUS_DIR/$finger"
  if [[ -d "$d" ]]; then
    n=$(find "$d" -name 'raw_*.bin' 2>/dev/null | wc -l)
    printf "    %-15s  %d raw frames\n" "$finger" "$n"
  fi
done

HALF=$((N_FRAMES / 2))

echo ""
echo "  Next steps — genuine match test (FRR):"
echo "    for f in ${FINGERS[*]}; do"
echo "      echo \"=== \$f ===\""
echo "      ./tools/benchmark/sigfm-batch \\"
echo "          --enroll $CORPUS_DIR/\$f/capture_0001.pgm .. $CORPUS_DIR/\$f/capture_$(printf '%04d' $HALF).pgm \\"
echo "          --verify $CORPUS_DIR/\$f/capture_$(printf '%04d' $((HALF+1))).pgm .. $CORPUS_DIR/\$f/capture_$(printf '%04d' $N_FRAMES).pgm"
echo "    done"
echo ""
echo "  Impostor test (FAR) — enroll one finger, verify against others:"
echo "    ./tools/benchmark/sigfm-batch \\"
echo "        --enroll $CORPUS_DIR/right-index/capture_0001.pgm .. \\"
echo "        --verify $CORPUS_DIR/right-middle/capture_0001.pgm .."
