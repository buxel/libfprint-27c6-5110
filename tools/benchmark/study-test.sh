#!/usr/bin/env bash
#
# study-test.sh — Template study v2 validation harness
#
# Runs three tests to evaluate whether adaptive template learning improves
# FRR without degrading FAR:
#
#   Test A: Progressive FRR — does FRR decrease as more genuine frames arrive?
#   Test B: Progressive FAR — does FAR remain stable as templates evolve?
#   Test C: Study-threshold sweep — which study gate minimises FRR while
#           keeping FAR safe?
#
# Usage:
#   ./tools/benchmark/study-test.sh <s1_corpus> <s2_corpus> [options]
#
# Options:
#   --thresholds=N,N,...  study-threshold values to sweep (default: 6,8,10,15,20,25)
#   --score-threshold=N   match threshold (default: 6)
#   --enroll-count=N      frames to enroll (default: 20)
#
# Example:
#   ./tools/benchmark/study-test.sh corpus/5finger corpus/5finger-s2
#
# Requires: tools/benchmark/sigfm-batch (build with: make -C tools)
#
# SPDX-License-Identifier: LGPL-2.1-or-later

set -euo pipefail

# ── Argument parsing ─────────────────────────────────────────────────

S1_DIR=""
S2_DIR=""
SCORE_THRESHOLD=6
ENROLL_COUNT=20
STUDY_THRESHOLDS="6,8,10,15,20,25"
STUDY_V2_FLAG=""

for arg in "$@"; do
    case "$arg" in
        --thresholds=*)      STUDY_THRESHOLDS="${arg#*=}" ;;
        --score-threshold=*) SCORE_THRESHOLD="${arg#*=}" ;;
        --enroll-count=*)    ENROLL_COUNT="${arg#*=}" ;;
        --study-v2)          STUDY_V2_FLAG="--study-v2" ;;
        --help|-h)
            sed -n '2,/^$/s/^# \?//p' "$0"
            exit 0
            ;;
        -*)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
        *)
            if [[ -z "$S1_DIR" ]]; then
                S1_DIR="$arg"
            elif [[ -z "$S2_DIR" ]]; then
                S2_DIR="$arg"
            else
                echo "Too many positional arguments" >&2
                exit 1
            fi
            ;;
    esac
done

if [[ -z "$S1_DIR" || -z "$S2_DIR" ]]; then
    echo "Usage: $0 <s1_corpus> <s2_corpus> [options]" >&2
    echo "Run with --help for details." >&2
    exit 1
fi

BATCH="./tools/benchmark/sigfm-batch"
if [[ ! -x "$BATCH" ]]; then
    echo "sigfm-batch not found at $BATCH — run: make -C tools" >&2
    exit 1
fi

FINGERS=($(ls -d "$S1_DIR"/right-* 2>/dev/null | xargs -n1 basename | sort))
if [[ ${#FINGERS[@]} -eq 0 ]]; then
    echo "No right-* finger directories found in $S1_DIR" >&2
    exit 1
fi

echo "══════════════════════════════════════════════════════════════"
echo "  Template Study v2 — Validation Harness"
echo "══════════════════════════════════════════════════════════════"
echo "  S1 (enroll):       $S1_DIR"
echo "  S2 (verify):       $S2_DIR"
echo "  Fingers:           ${FINGERS[*]}"
echo "  Score threshold:   $SCORE_THRESHOLD"
echo "  Enroll count:      $ENROLL_COUNT"
echo "  Study thresholds:  $STUDY_THRESHOLDS"
if [[ -n "$STUDY_V2_FLAG" ]]; then
echo "  Study algorithm:   v2 (Windows-style multi-layer)"
else
echo "  Study algorithm:   naive (cross-score replacement)"
fi
echo "──────────────────────────────────────────────────────────────"
echo ""

# ── Helper: extract basename from path ───────────────────────────────

basename_noext() {
    local f
    f=$(basename "$1")
    echo "${f%.*}"
}

# ── Helper: get enroll files (first N) ───────────────────────────────

get_enroll_files() {
    local dir="$1"
    ls "$dir"/capture_*.pgm | sort | head -n "$ENROLL_COUNT"
}

# ── Helper: get verify files (all) ───────────────────────────────────

get_verify_files() {
    local dir="$1"
    ls "$dir"/capture_*.pgm | sort
}

# ────────────────────────────────────────────────────────────────────
# Test A: Progressive FRR
#
# For each study-threshold, for each finger:
#   Enroll from S1, verify S2 sequentially with study.
#   Split results into early/middle/late windows.
#   Compare with no-study control.
# ────────────────────────────────────────────────────────────────────

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  TEST A — Progressive FRR                                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Control: no study
echo "── Control (no study) ────────────────────────────────────"
declare -A CTRL_EARLY CTRL_MID CTRL_LATE

for finger in "${FINGERS[@]}"; do
    enroll_args=($(get_enroll_files "$S1_DIR/$finger"))
    verify_args=($(get_verify_files "$S2_DIR/$finger"))

    csv=$($BATCH --enroll "${enroll_args[@]}" --verify "${verify_args[@]}" \
          --score-threshold="$SCORE_THRESHOLD" --csv 2>/dev/null) || true

    # Parse CSV: skip header, count MATCH/FAIL per window
    # Windows: early=0-9, middle=10-19, late=20-29
    early_m=0; early_f=0; mid_m=0; mid_f=0; late_m=0; late_f=0
    while IFS=, read -r idx file result score kp study; do
        [[ "$idx" == "idx" ]] && continue  # header
        [[ "$result" == "SKIP" || "$result" == "ERROR" ]] && continue
        if (( idx < 10 )); then
            [[ "$result" == "MATCH" ]] && early_m=$((early_m + 1)) || early_f=$((early_f + 1))
        elif (( idx < 20 )); then
            [[ "$result" == "MATCH" ]] && mid_m=$((mid_m + 1)) || mid_f=$((mid_f + 1))
        else
            [[ "$result" == "MATCH" ]] && late_m=$((late_m + 1)) || late_f=$((late_f + 1))
        fi
    done <<< "$csv"

    early_total=$((early_m + early_f))
    mid_total=$((mid_m + mid_f))
    late_total=$((late_m + late_f))

    early_frr=0; mid_frr=0; late_frr=0
    (( early_total > 0 )) && early_frr=$(awk "BEGIN{printf \"%.1f\", $early_f/$early_total*100}")
    (( mid_total > 0 ))   && mid_frr=$(awk "BEGIN{printf \"%.1f\", $mid_f/$mid_total*100}")
    (( late_total > 0 ))  && late_frr=$(awk "BEGIN{printf \"%.1f\", $late_f/$late_total*100}")

    CTRL_EARLY[$finger]=$early_frr
    CTRL_MID[$finger]=$mid_frr
    CTRL_LATE[$finger]=$late_frr

    printf "  %-14s  early=%5s%%  mid=%5s%%  late=%5s%%\n" \
        "$finger" "$early_frr" "$mid_frr" "$late_frr"
done
echo ""

# Study runs: one per study-threshold
IFS=',' read -ra THRESH_ARRAY <<< "$STUDY_THRESHOLDS"

for st in "${THRESH_ARRAY[@]}"; do
    echo "── Study threshold = $st ────────────────────────────────"
    for finger in "${FINGERS[@]}"; do
        enroll_args=($(get_enroll_files "$S1_DIR/$finger"))
        verify_args=($(get_verify_files "$S2_DIR/$finger"))

        csv=$($BATCH --enroll "${enroll_args[@]}" --verify "${verify_args[@]}" \
              --score-threshold="$SCORE_THRESHOLD" --study-threshold="$st" $STUDY_V2_FLAG --csv 2>/dev/null) || true

        early_m=0; early_f=0; mid_m=0; mid_f=0; late_m=0; late_f=0
        updates=0
        while IFS=, read -r idx file result score kp study; do
            [[ "$idx" == "idx" ]] && continue
            [[ "$result" == "SKIP" || "$result" == "ERROR" ]] && continue
            [[ "$study" == "1" ]] && updates=$((updates + 1))
            if (( idx < 10 )); then
                [[ "$result" == "MATCH" ]] && early_m=$((early_m + 1)) || early_f=$((early_f + 1))
            elif (( idx < 20 )); then
                [[ "$result" == "MATCH" ]] && mid_m=$((mid_m + 1)) || mid_f=$((mid_f + 1))
            else
                [[ "$result" == "MATCH" ]] && late_m=$((late_m + 1)) || late_f=$((late_f + 1))
            fi
        done <<< "$csv"

        early_total=$((early_m + early_f))
        mid_total=$((mid_m + mid_f))
        late_total=$((late_m + late_f))

        early_frr=0; mid_frr=0; late_frr=0
        (( early_total > 0 )) && early_frr=$(awk "BEGIN{printf \"%.1f\", $early_f/$early_total*100}")
        (( mid_total > 0 ))   && mid_frr=$(awk "BEGIN{printf \"%.1f\", $mid_f/$mid_total*100}")
        (( late_total > 0 ))  && late_frr=$(awk "BEGIN{printf \"%.1f\", $late_f/$late_total*100}")

        ctrl_e=${CTRL_EARLY[$finger]}
        ctrl_l=${CTRL_LATE[$finger]}
        delta_early=$(awk "BEGIN{printf \"%+.1f\", $early_frr - $ctrl_e}")
        delta_late=$(awk "BEGIN{printf \"%+.1f\", $late_frr - $ctrl_l}")

        printf "  %-14s  early=%5s%% (%spp)  mid=%5s%%  late=%5s%% (%spp)  updates=%d\n" \
            "$finger" "$early_frr" "$delta_early" "$mid_frr" "$late_frr" "$delta_late" "$updates"
    done
    echo ""
done

# ────────────────────────────────────────────────────────────────────
# Test B: Progressive FAR
#
# For each study-threshold, for each finger:
#   Enroll from S1. Then interleave:
#     - Verify 5 genuine S2 frames (with study)
#     - Test FAR against all other fingers' S2 frames
#   Report FAR at each checkpoint.
# ────────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  TEST B — Progressive FAR                                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# For this test we need to interleave genuine study and impostor testing.
# Strategy: run genuine study in batches of 5, snapshot template via
# serialised enrollment, then run impostor test.
#
# Implementation: We can't snapshot mid-stream with sigfm-batch, so we
# simulate by running with increasing --verify counts and --csv.
# For each checkpoint C (0,5,10,15,20,25):
#   1. Run: enroll S1[0:20] + verify S2[0:C] with study → template evolves
#   2. Then verify S2[0:C] + impostor_files → but this re-runs genuine...
#
# Better approach: run genuine+impostor in a single --verify pass with CSV,
# where we feed genuine first (with study), then all impostors.
# The CSV output tells us exactly which frame was MATCH/FAIL.
# We parse the impostor section for FAR.

for st in "${THRESH_ARRAY[@]}"; do
    echo "── Study threshold = $st ────────────────────────────────"

    for finger in "${FINGERS[@]}"; do
        enroll_args=($(get_enroll_files "$S1_DIR/$finger"))
        genuine_files=($(get_verify_files "$S2_DIR/$finger"))
        n_genuine=${#genuine_files[@]}

        # Collect impostor files (all other fingers)
        impostor_files=()
        for other in "${FINGERS[@]}"; do
            [[ "$other" == "$finger" ]] && continue
            impostor_files+=($(get_verify_files "$S2_DIR/$other"))
        done
        n_impostor=${#impostor_files[@]}

        # Run: enroll, then verify genuine (with study) followed by impostors.
        # Genuine frames come first so template evolves before impostor test.
        all_verify=("${genuine_files[@]}" "${impostor_files[@]}")

        csv=$($BATCH --enroll "${enroll_args[@]}" --verify "${all_verify[@]}" \
              --score-threshold="$SCORE_THRESHOLD" --study-threshold="$st" $STUDY_V2_FLAG --csv 2>/dev/null) || true

        # Parse: first n_genuine idx values are genuine, rest are impostor
        genuine_match=0; genuine_fail=0
        impostor_fa=0; impostor_total=0

        while IFS=, read -r idx file result score kp study; do
            [[ "$idx" == "idx" ]] && continue  # header
            [[ "$result" == "SKIP" || "$result" == "ERROR" ]] && continue

            if (( idx < n_genuine )); then
                # Genuine region
                [[ "$result" == "MATCH" ]] && genuine_match=$((genuine_match + 1)) || genuine_fail=$((genuine_fail + 1))
            else
                # Impostor region
                impostor_total=$((impostor_total + 1))
                [[ "$result" == "MATCH" ]] && impostor_fa=$((impostor_fa + 1))
            fi
        done <<< "$csv"

        genuine_total=$((genuine_match + genuine_fail))
        frr=0; far=0
        (( genuine_total > 0 )) && frr=$(awk "BEGIN{printf \"%.1f\", $genuine_fail/$genuine_total*100}")
        (( impostor_total > 0 )) && far=$(awk "BEGIN{printf \"%.2f\", $impostor_fa/$impostor_total*100}")

        printf "  %-14s  FRR=%5s%%  FAR=%5s%% (%d/%d fa)  genuine=%d/%d\n" \
            "$finger" "$frr" "$far" "$impostor_fa" "$impostor_total" \
            "$genuine_match" "$genuine_total"
    done

    # Aggregate FAR across all fingers
    echo ""
done

# ────────────────────────────────────────────────────────────────────
# Test C: Summary Table
# ────────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  TEST C — Summary: study-threshold × metric                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Recomputing aggregates across all fingers..."
echo ""

# Control baseline
ctrl_total_m=0; ctrl_total_f=0
for finger in "${FINGERS[@]}"; do
    enroll_args=($(get_enroll_files "$S1_DIR/$finger"))
    verify_args=($(get_verify_files "$S2_DIR/$finger"))

    csv=$($BATCH --enroll "${enroll_args[@]}" --verify "${verify_args[@]}" \
          --score-threshold="$SCORE_THRESHOLD" --csv 2>/dev/null) || true

    while IFS=, read -r idx file result score kp study; do
        [[ "$idx" == "idx" ]] && continue
        [[ "$result" == "SKIP" || "$result" == "ERROR" ]] && continue
        [[ "$result" == "MATCH" ]] && ctrl_total_m=$((ctrl_total_m + 1)) || ctrl_total_f=$((ctrl_total_f + 1))
    done <<< "$csv"
done
ctrl_total=$((ctrl_total_m + ctrl_total_f))
ctrl_frr=$(awk "BEGIN{printf \"%.1f\", $ctrl_total_f/$ctrl_total*100}")

# Control FAR (cross-finger, no study)
ctrl_fa=0; ctrl_fa_total=0
for finger in "${FINGERS[@]}"; do
    enroll_args=($(get_enroll_files "$S1_DIR/$finger"))
    for other in "${FINGERS[@]}"; do
        [[ "$other" == "$finger" ]] && continue
        imp_args=($(get_verify_files "$S2_DIR/$other"))
        csv=$($BATCH --enroll "${enroll_args[@]}" --verify "${imp_args[@]}" \
              --score-threshold="$SCORE_THRESHOLD" --csv 2>/dev/null) || true
        while IFS=, read -r idx file result score kp study; do
            [[ "$idx" == "idx" ]] && continue
            [[ "$result" == "SKIP" || "$result" == "ERROR" ]] && continue
            ctrl_fa_total=$((ctrl_fa_total + 1))
            [[ "$result" == "MATCH" ]] && ctrl_fa=$((ctrl_fa + 1))
        done <<< "$csv"
    done
done
ctrl_far=$(awk "BEGIN{printf \"%.2f\", $ctrl_fa/$ctrl_fa_total*100}")

printf "  %-18s  FRR=%6s%%   FAR=%6s%%\n" "No study (control)" "$ctrl_frr" "$ctrl_far"

for st in "${THRESH_ARRAY[@]}"; do
    total_m=0; total_f=0; total_fa=0; total_fa_total=0

    for finger in "${FINGERS[@]}"; do
        enroll_args=($(get_enroll_files "$S1_DIR/$finger"))
        genuine_files=($(get_verify_files "$S2_DIR/$finger"))
        n_genuine=${#genuine_files[@]}

        impostor_files=()
        for other in "${FINGERS[@]}"; do
            [[ "$other" == "$finger" ]] && continue
            impostor_files+=($(get_verify_files "$S2_DIR/$other"))
        done

        all_verify=("${genuine_files[@]}" "${impostor_files[@]}")

        csv=$($BATCH --enroll "${enroll_args[@]}" --verify "${all_verify[@]}" \
              --score-threshold="$SCORE_THRESHOLD" --study-threshold="$st" $STUDY_V2_FLAG --csv 2>/dev/null) || true

        while IFS=, read -r idx file result score kp study; do
            [[ "$idx" == "idx" ]] && continue
            [[ "$result" == "SKIP" || "$result" == "ERROR" ]] && continue
            if (( idx < n_genuine )); then
                [[ "$result" == "MATCH" ]] && total_m=$((total_m + 1)) || total_f=$((total_f + 1))
            else
                total_fa_total=$((total_fa_total + 1))
                [[ "$result" == "MATCH" ]] && total_fa=$((total_fa + 1))
            fi
        done <<< "$csv"
    done

    total=$((total_m + total_f))
    frr=$(awk "BEGIN{printf \"%.1f\", $total_f/$total*100}")
    far=$(awk "BEGIN{printf \"%.2f\", $total_fa/$total_fa_total*100}")

    # Check pass criteria
    pass="✗"
    far_ok=$(awk "BEGIN{print ($far <= 0.5) ? 1 : 0}")
    frr_delta=$(awk "BEGIN{printf \"%.1f\", $ctrl_frr - $frr}")
    if (( far_ok )); then
        frr_improved=$(awk "BEGIN{print ($frr_delta >= 5.0) ? 1 : 0}")
        if (( frr_improved )); then
            pass="✓"
        fi
    fi

    printf "  study-thresh=%-4s   FRR=%6s%%   FAR=%6s%%   ΔFRR=%+5spp  %s\n" \
        "$st" "$frr" "$far" "$frr_delta" "$pass"
done

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  Pass criteria: FAR ≤ 0.5% AND ΔFRR ≥ 5pp improvement"
echo "══════════════════════════════════════════════════════════════"
