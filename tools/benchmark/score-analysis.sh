#!/usr/bin/env bash
#
# score-analysis.sh — Collect all genuine/impostor scores and compute stats
#
set -uo pipefail

CORPUS_DIR="${1:?Usage: $0 <corpus_dir>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BATCH="$SCRIPT_DIR/sigfm-batch"

FINGERS=()
for d in "$CORPUS_DIR"/*/; do
    [[ -d "$d" ]] && FINGERS+=("$(basename "$d")")
done

GENUINE_FILE=$(mktemp)
IMPOSTOR_FILE=$(mktemp)
trap "rm -f $GENUINE_FILE $IMPOSTOR_FILE" EXIT

# ── Collect genuine scores ──────────────────────────────────────
echo "Collecting genuine scores..."
for finger in "${FINGERS[@]}"; do
    mapfile -t pgms < <(ls "$CORPUS_DIR/$finger"/capture_*.pgm 2>/dev/null | sort)
    n=${#pgms[@]}
    [[ $n -lt 4 ]] && continue
    n_enroll=10
    [[ $n -le $n_enroll ]] && n_enroll=$((n / 2))
    enroll=("${pgms[@]:0:$n_enroll}")
    verify=("${pgms[@]:$n_enroll}")
    "$BATCH" --enroll "${enroll[@]}" --verify "${verify[@]}" --score-threshold=0 2>&1 \
        | grep -oP 'score=\K\d+' >> "$GENUINE_FILE"
done

# ── Collect impostor scores ─────────────────────────────────────
echo "Collecting impostor scores..."
for ef in "${FINGERS[@]}"; do
    mapfile -t epgms < <(ls "$CORPUS_DIR/$ef"/capture_*.pgm 2>/dev/null | sort)
    n_e=${#epgms[@]}
    [[ $n_e -lt 4 ]] && continue
    n_enroll=10
    [[ $n_e -le $n_enroll ]] && n_enroll=$((n_e / 2))
    enroll=("${epgms[@]:0:$n_enroll}")

    for vf in "${FINGERS[@]}"; do
        [[ "$vf" == "$ef" ]] && continue
        mapfile -t vpgms < <(ls "$CORPUS_DIR/$vf"/capture_*.pgm 2>/dev/null | sort)
        [[ ${#vpgms[@]} -eq 0 ]] && continue
        "$BATCH" --enroll "${enroll[@]}" --verify "${vpgms[@]}" --score-threshold=0 2>&1 \
            | grep -oP 'score=\K\d+' >> "$IMPOSTOR_FILE"
    done
done

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              SCORE DISTRIBUTION ANALYSIS                     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

echo "── Genuine scores ──"
sort -n "$GENUINE_FILE" | awk '
BEGIN { n=0 }
{ scores[n++] = $1 }
END {
    printf "  Count: %d\n", n
    printf "  Min: %d  P5: %d  P10: %d  P25: %d  Median: %d  P75: %d  Max: %d\n",
        scores[0], scores[int(n*0.05)], scores[int(n*0.1)], scores[int(n*0.25)],
        scores[int(n*0.5)], scores[int(n*0.75)], scores[n-1]
    printf "  All: "
    for (i=0; i<n; i++) printf "%d ", scores[i]
    printf "\n"
}'

echo ""
echo "── Impostor scores ──"
sort -n "$IMPOSTOR_FILE" | awk '
BEGIN { n=0 }
{ scores[n++] = $1 }
END {
    printf "  Count: %d\n", n
    printf "  Min: %d  P25: %d  Median: %d  P75: %d  P90: %d  P95: %d  P99: %d  Max: %d\n",
        scores[0], scores[int(n*0.25)], scores[int(n*0.5)], scores[int(n*0.75)],
        scores[int(n*0.9)], scores[int(n*0.95)], scores[int(n*0.99)], scores[n-1]
}'

echo ""
echo "── FRR/FAR at various thresholds ──"
echo "  Threshold | FRR%     | FAR%     | Comment"
echo "  ----------|----------|----------|--------"

for thresh in 10 20 30 40 50 75 100 150 200 300 400 500; do
    n_gen=$(wc -l < "$GENUINE_FILE")
    n_imp=$(wc -l < "$IMPOSTOR_FILE")
    gen_reject=$(awk -v t="$thresh" '$1 < t' "$GENUINE_FILE" | wc -l)
    imp_accept=$(awk -v t="$thresh" '$1 >= t' "$IMPOSTOR_FILE" | wc -l)
    frr=$(awk "BEGIN { printf \"%.1f\", $gen_reject / $n_gen * 100 }")
    far=$(awk "BEGIN { printf \"%.1f\", $imp_accept / $n_imp * 100 }")
    echo "  $thresh|$frr|$far" | awk -F'|' '{ printf "  %-10s| %-9s| %-9s|\n", $1, $2, $3 }'
done

echo ""
echo "── Threshold for FAR=0% ──"
max_imp=$(sort -n "$IMPOSTOR_FILE" | tail -1)
echo "  Max impostor score: $max_imp"
echo "  To achieve FAR=0%, threshold must be > $max_imp"
n_gen=$(wc -l < "$GENUINE_FILE")
gen_below=$(awk -v t="$max_imp" '$1 <= t' "$GENUINE_FILE" | wc -l)
frr_at_zero_far=$(awk "BEGIN { printf \"%.1f\", $gen_below / $n_gen * 100 }")
echo "  FRR at that threshold: $frr_at_zero_far%"
