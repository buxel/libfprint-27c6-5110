#!/usr/bin/env bash
#
# run-tests.sh — Run genuine (FRR) and impostor (FAR) tests on a multi-finger corpus
#
# Usage:
#   ./tools/benchmark/run-tests.sh <corpus_dir> [score_threshold]
#
# Example:
#   ./tools/benchmark/run-tests.sh corpus/5finger 40

set -euo pipefail

CORPUS_DIR="${1:?Usage: $0 <corpus_dir> [threshold]}"
THRESHOLD="${2:-40}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BATCH="$SCRIPT_DIR/sigfm-batch"

if [[ ! -x "$BATCH" ]]; then
    echo "ERROR: sigfm-batch not found at $BATCH — run 'make -C tools' first" >&2
    exit 1
fi

FINGERS=()
for d in "$CORPUS_DIR"/*/; do
    [[ -d "$d" ]] && FINGERS+=("$(basename "$d")")
done

if [[ ${#FINGERS[@]} -eq 0 ]]; then
    echo "ERROR: No finger subdirectories found in $CORPUS_DIR" >&2
    exit 1
fi

echo "Corpus: $CORPUS_DIR"
echo "Fingers: ${FINGERS[*]}"
echo "Threshold: $THRESHOLD"
echo ""

# ── Part 1: Genuine match tests (FRR) ────────────────────────────────

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║        GENUINE MATCH TEST — Per-finger FRR                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

total_match=0
total_fail=0
total_verify=0

for finger in "${FINGERS[@]}"; do
    mapfile -t pgms < <(ls "$CORPUS_DIR/$finger"/capture_*.pgm 2>/dev/null | sort)
    n=${#pgms[@]}
    if [[ $n -lt 4 ]]; then
        echo "  [$finger] SKIP — only $n PGMs (need at least 4)"
        continue
    fi

    n_enroll=10
    if [[ $n -le $n_enroll ]]; then
        n_enroll=$((n / 2))
    fi
    n_verify=$((n - n_enroll))

    echo "── $finger ($n total: $n_enroll enroll, $n_verify verify) ──"

    enroll_args=("${pgms[@]:0:$n_enroll}")
    verify_args=("${pgms[@]:$n_enroll}")

    output=$("$BATCH" \
        --enroll "${enroll_args[@]}" \
        --verify "${verify_args[@]}" \
        --score-threshold="$THRESHOLD" 2>&1) || true

    echo "$output"

    # Parse results
    m=$(echo "$output" | grep -oP 'Matches:\s+\K\d+' || echo 0)
    f=$(echo "$output" | grep -oP 'Rejections:\s+\K\d+' || echo 0)
    total_match=$((total_match + m))
    total_fail=$((total_fail + f))
    total_verify=$((total_verify + m + f))
    echo ""
done

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  GENUINE SUMMARY                                             ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
printf "║  Total verified: %-5d  Matched: %-5d  Rejected: %-5d     ║\n" \
    "$total_verify" "$total_match" "$total_fail"
if [[ $total_verify -gt 0 ]]; then
    frr=$(awk "BEGIN { printf \"%.1f\", $total_fail / $total_verify * 100 }")
    printf "║  FRR: %-6s                                               ║\n" "${frr}%"
fi
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# ── Part 2: Impostor test (FAR) ──────────────────────────────────────

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║        IMPOSTOR TEST — Cross-finger FAR                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Each finger enrolled against itself, then verified with OTHER fingers."
echo "(Any match = false accept)"
echo ""

impostor_match=0
impostor_fail=0
impostor_attempts=0

for enroll_finger in "${FINGERS[@]}"; do
    mapfile -t enroll_pgms < <(ls "$CORPUS_DIR/$enroll_finger"/capture_*.pgm 2>/dev/null | sort)
    n_e=${#enroll_pgms[@]}
    if [[ $n_e -lt 4 ]]; then continue; fi

    n_enroll=10
    if [[ $n_e -le $n_enroll ]]; then
        n_enroll=$((n_e / 2))
    fi

    enroll_args=("${enroll_pgms[@]:0:$n_enroll}")

    for verify_finger in "${FINGERS[@]}"; do
        [[ "$verify_finger" == "$enroll_finger" ]] && continue

        mapfile -t verify_pgms < <(ls "$CORPUS_DIR/$verify_finger"/capture_*.pgm 2>/dev/null | sort)
        n_v=${#verify_pgms[@]}
        if [[ $n_v -eq 0 ]]; then continue; fi

        output=$("$BATCH" \
            --enroll "${enroll_args[@]}" \
            --verify "${verify_pgms[@]}" \
            --score-threshold="$THRESHOLD" 2>&1) || true

        m=$(echo "$output" | grep -oP 'Matches:\s+\K\d+' || echo 0)
        f=$(echo "$output" | grep -oP 'Rejections:\s+\K\d+' || echo 0)
        attempts=$((m + f))

        if [[ $m -gt 0 ]]; then
            echo "  ⚠ FALSE ACCEPT: enrolled=$enroll_finger verify=$verify_finger matches=$m/$attempts"
        else
            echo "  ✓ enrolled=$enroll_finger verify=$verify_finger matches=0/$attempts"
        fi

        impostor_match=$((impostor_match + m))
        impostor_fail=$((impostor_fail + f))
        impostor_attempts=$((impostor_attempts + attempts))
    done
done

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  IMPOSTOR SUMMARY                                           ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
printf "║  Total impostor attempts: %-6d                             ║\n" "$impostor_attempts"
printf "║  False accepts:           %-6d                             ║\n" "$impostor_match"
printf "║  Correct rejections:      %-6d                             ║\n" "$impostor_fail"
if [[ $impostor_attempts -gt 0 ]]; then
    far=$(awk "BEGIN { printf \"%.2f\", $impostor_match / $impostor_attempts * 100 }")
    printf "║  FAR: %-7s                                              ║\n" "${far}%"
fi
echo "╚═══════════════════════════════════════════════════════════════╝"
