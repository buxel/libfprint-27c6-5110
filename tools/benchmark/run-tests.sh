#!/usr/bin/env bash
#
# run-tests.sh — Run genuine (FRR) and impostor (FAR) tests on a multi-finger corpus
#
# Usage:
#   ./tools/benchmark/run-tests.sh <corpus_dir> [options]
#
# Options:
#   --threshold=N        score threshold (default: 6, matches driver)
#   --enroll-count=N     sub-templates to enroll (default: 20, matches driver)
#   --cross-validate=N   repeat with N random shuffles (default: off)
#
# Examples:
#   ./tools/benchmark/run-tests.sh corpus/5finger
#   ./tools/benchmark/run-tests.sh corpus/5finger --threshold=6 --enroll-count=20
#   ./tools/benchmark/run-tests.sh corpus/5finger --cross-validate=10

set -euo pipefail

# ── Argument parsing ─────────────────────────────────────────────────

CORPUS_DIR=""
THRESHOLD=6        # matches goodix511.c img_dev_class->score_threshold
ENROLL_COUNT=20    # matches goodix511.c dev_class->nr_enroll_stages
CV_ROUNDS=0        # cross-validation rounds (0 = single fixed split)

for arg in "$@"; do
    case "$arg" in
        --threshold=*)      THRESHOLD="${arg#*=}" ;;
        --enroll-count=*)   ENROLL_COUNT="${arg#*=}" ;;
        --cross-validate=*) CV_ROUNDS="${arg#*=}" ;;
        --help|-h)
            sed -n '3,/^$/p' "$0" | sed 's/^# \?//'
            exit 0 ;;
        -*)
            echo "Unknown option: $arg" >&2; exit 1 ;;
        *)
            CORPUS_DIR="$arg" ;;
    esac
done

if [[ -z "$CORPUS_DIR" ]]; then
    echo "Usage: $0 <corpus_dir> [--threshold=N] [--enroll-count=N] [--cross-validate=N]" >&2
    exit 1
fi

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

echo "Corpus:       $CORPUS_DIR"
echo "Fingers:      ${FINGERS[*]}"
echo "Threshold:    $THRESHOLD"
echo "Enroll count: $ENROLL_COUNT"
if [[ $CV_ROUNDS -gt 0 ]]; then
    echo "Cross-val:    $CV_ROUNDS rounds"
fi
echo ""

# ── Helper: run one FRR split ────────────────────────────────────────
# Args: finger_dir enroll_files... -- verify_files...
# Prints: MATCH FAIL GATED (space-separated)

run_one_split() {
    local finger_dir="$1"; shift
    local -a enroll_args=()
    local -a verify_args=()
    local mode=enroll
    for f in "$@"; do
        if [[ "$f" == "--" ]]; then
            mode=verify; continue
        fi
        if [[ "$mode" == "enroll" ]]; then
            enroll_args+=("$f")
        else
            verify_args+=("$f")
        fi
    done

    local output
    output=$("$BATCH" \
        --enroll "${enroll_args[@]}" \
        --verify "${verify_args[@]}" \
        --score-threshold="$THRESHOLD" 2>&1) || true

    local m f g
    m=$(echo "$output" | grep -oP 'Matches:\s+\K\d+' || echo 0)
    f=$(echo "$output" | grep -oP 'Rejections:\s+\K\d+' || echo 0)
    g=$(echo "$output" | grep -oP 'Quality-gated:\s+\K\d+' || echo 0)
    echo "$m $f $g"
}

# ── Fisher-Yates shuffle (deterministic with seed) ───────────────────

shuffle_array() {
    local -n arr=$1
    local seed=${2:-$$}
    local n=${#arr[@]}
    for (( i=n-1; i>0; i-- )); do
        seed=$(( (seed * 1103515245 + 12345) & 0x7fffffff ))
        local j=$(( seed % (i + 1) ))
        local tmp="${arr[$i]}"
        arr[$i]="${arr[$j]}"
        arr[$j]="$tmp"
    done
}

# ── Part 1: Genuine match tests (FRR) ────────────────────────────────

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║        GENUINE MATCH TEST — Per-finger FRR                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

total_match=0
total_fail=0
total_verify=0
total_gated=0

for finger in "${FINGERS[@]}"; do
    mapfile -t pgms < <(ls "$CORPUS_DIR/$finger"/capture_*.pgm 2>/dev/null | sort)
    n=${#pgms[@]}
    if [[ $n -lt 4 ]]; then
        echo "  [$finger] SKIP — only $n PGMs (need at least 4)"
        continue
    fi

    n_enroll=$ENROLL_COUNT
    if [[ $n -le $n_enroll ]]; then
        n_enroll=$((n / 2))
    fi
    n_verify=$((n - n_enroll))

    if [[ $CV_ROUNDS -le 0 ]]; then
        # Single fixed split
        echo "── $finger ($n total: $n_enroll enroll, $n_verify verify) ──"

        output=$("$BATCH" \
            --enroll "${pgms[@]:0:$n_enroll}" \
            --verify "${pgms[@]:$n_enroll}" \
            --score-threshold="$THRESHOLD" 2>&1) || true

        echo "$output"

        m=$(echo "$output" | grep -oP 'Matches:\s+\K\d+' || echo 0)
        f=$(echo "$output" | grep -oP 'Rejections:\s+\K\d+' || echo 0)
        g=$(echo "$output" | grep -oP 'Quality-gated:\s+\K\d+' || echo 0)
        total_match=$((total_match + m))
        total_fail=$((total_fail + f))
        total_verify=$((total_verify + m + f))
        total_gated=$((total_gated + g))
    else
        # Cross-validation: shuffle and repeat
        echo "── $finger ($n total: $n_enroll enroll, $n_verify verify, $CV_ROUNDS CV rounds) ──"
        cv_match=0; cv_fail=0; cv_gated=0

        for (( r=1; r<=CV_ROUNDS; r++ )); do
            local_pgms=("${pgms[@]}")
            shuffle_array local_pgms "$((r * 31337 + ${#finger}))"

            result=$(run_one_split "$finger" \
                "${local_pgms[@]:0:$n_enroll}" -- "${local_pgms[@]:$n_enroll}")
            read -r rm rf rg <<< "$result"
            cv_match=$((cv_match + rm))
            cv_fail=$((cv_fail + rf))
            cv_gated=$((cv_gated + rg))
        done

        cv_total=$((cv_match + cv_fail))
        if [[ $cv_total -gt 0 ]]; then
            frr=$(awk "BEGIN { printf \"%.1f\", $cv_fail / $cv_total * 100 }")
        else
            frr="N/A"
        fi
        printf "  %d rounds: %d verified, %d match, %d fail, %d gated → FRR %s%%\n" \
            "$CV_ROUNDS" "$cv_total" "$cv_match" "$cv_fail" "$cv_gated" "$frr"

        total_match=$((total_match + cv_match))
        total_fail=$((total_fail + cv_fail))
        total_verify=$((total_verify + cv_total))
        total_gated=$((total_gated + cv_gated))
    fi
    echo ""
done

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  GENUINE SUMMARY                                             ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
printf "║  Total verified: %-5d  Matched: %-5d  Rejected: %-5d     ║\n" \
    "$total_verify" "$total_match" "$total_fail"
if [[ $total_gated -gt 0 ]]; then
    printf "║  Quality-gated:  %-5d  (skipped, not in FRR)              ║\n" "$total_gated"
fi
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

    n_enroll=$ENROLL_COUNT
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
