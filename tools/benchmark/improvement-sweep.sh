#!/usr/bin/env bash
#
# improvement-sweep.sh — Benchmark enrollment/template improvements
#
# Tests each improvement independently and in combination:
#   1. Baseline (no improvements)
#   2. --quality-enroll (E4)
#   3. --diversity-prune --max-subtemplates=15 (E5)
#   4. --sort-subtemplates --max-subtemplates=15 (existing)
#   5. --quality-enroll --diversity-prune --max-subtemplates=15 (E4+E5)
#   6. --quality-enroll --sort-subtemplates --max-subtemplates=15 (E4+sort)
#
# Reports per-finger FRR and aggregate FRR + FAR for each configuration.
#
# Usage:
#   ./tools/benchmark/improvement-sweep.sh <s1_corpus> <s2_corpus>
#
# SPDX-License-Identifier: LGPL-2.1-or-later

set -euo pipefail

S1_DIR="${1:?Usage: $0 <s1_corpus> <s2_corpus>}"
S2_DIR="${2:?Usage: $0 <s1_corpus> <s2_corpus>}"

BATCH="./tools/benchmark/sigfm-batch"
ST=6
FINGERS=(right-index right-little right-middle right-ring right-thumb)

if [[ ! -x "$BATCH" ]]; then
    echo "sigfm-batch not found — run: make -C tools" >&2
    exit 1
fi

echo "══════════════════════════════════════════════════════════════"
echo "  Improvement Sweep Benchmark"
echo "══════════════════════════════════════════════════════════════"
echo "  S1 (enroll):  $S1_DIR"
echo "  S2 (verify):  $S2_DIR"
echo "  Fingers:      ${FINGERS[*]}"
echo "  Threshold:    $ST"
echo "──────────────────────────────────────────────────────────────"
echo ""

# Define configurations to test
declare -a CONFIG_NAMES=(
    "baseline"
    "quality-enroll"
    "diversity-15"
    "sort-15"
    "quality+diversity-15"
    "quality+sort-15"
    "diversity-10"
    "quality+diversity-10"
)

declare -a CONFIG_FLAGS=(
    ""
    "--quality-enroll"
    "--diversity-prune --max-subtemplates=15"
    "--sort-subtemplates --max-subtemplates=15"
    "--quality-enroll --diversity-prune --max-subtemplates=15"
    "--quality-enroll --sort-subtemplates --max-subtemplates=15"
    "--diversity-prune --max-subtemplates=10"
    "--quality-enroll --diversity-prune --max-subtemplates=10"
)

NCONFIGS=${#CONFIG_NAMES[@]}

for (( c=0; c<NCONFIGS; c++ )); do
    name="${CONFIG_NAMES[$c]}"
    flags="${CONFIG_FLAGS[$c]}"
    
    echo "── $name ──────────────────────────────────────────"
    
    total_m=0; total_f=0; total_fa=0; total_fa_total=0
    
    for finger in "${FINGERS[@]}"; do
        # Per-finger genuine FRR
        enroll_args=($(ls "$S1_DIR/$finger"/capture_*.pgm | sort))
        verify_args=($(ls "$S2_DIR/$finger"/capture_*.pgm | sort))
        
        csv=$($BATCH --enroll "${enroll_args[@]}" --verify "${verify_args[@]}" \
              --score-threshold=$ST $flags --csv 2>/dev/null) || true
        
        fm=0; ff=0
        while IFS=, read -r idx file result score kp study; do
            [[ "$idx" == "idx" || "$result" == "SKIP" || "$result" == "ERROR" ]] && continue
            [[ "$result" == "MATCH" ]] && fm=$((fm+1)) || ff=$((ff+1))
        done <<< "$csv"
        
        ft=$((fm+ff))
        frr=0
        (( ft > 0 )) && frr=$(awk "BEGIN{printf \"%.1f\", $ff/$ft*100}")
        printf "  %-14s  FRR=%5s%%  (%d/%d)\n" "$finger" "$frr" "$ff" "$ft"
        total_m=$((total_m + fm))
        total_f=$((total_f + ff))
        
        # Per-finger cross-finger FAR  
        for other in "${FINGERS[@]}"; do
            [[ "$other" == "$finger" ]] && continue
            imp_args=($(ls "$S2_DIR/$other"/capture_*.pgm | sort))
            csv=$($BATCH --enroll "${enroll_args[@]}" --verify "${imp_args[@]}" \
                  --score-threshold=$ST $flags --csv 2>/dev/null) || true
            while IFS=, read -r idx file result score kp study; do
                [[ "$idx" == "idx" || "$result" == "SKIP" || "$result" == "ERROR" ]] && continue
                total_fa_total=$((total_fa_total+1))
                [[ "$result" == "MATCH" ]] && total_fa=$((total_fa+1))
            done <<< "$csv"
        done
    done
    
    total=$((total_m + total_f))
    agg_frr=$(awk "BEGIN{printf \"%.1f\", $total_f/$total*100}")
    agg_far=$(awk "BEGIN{printf \"%.2f\", $total_fa/$total_fa_total*100}")
    
    printf "  %-14s  FRR=%5s%%   FAR=%5s%%  (%d fa / %d)\n\n" \
        "AGGREGATE" "$agg_frr" "$agg_far" "$total_fa" "$total_fa_total"
done

echo "══════════════════════════════════════════════════════════════"
echo "  Sweep complete"
echo "══════════════════════════════════════════════════════════════"
