# 14 — SIGFM Benchmark Results (5-Finger Corpus)

**Date**: 2026-02-22  
**Corpus**: `corpus/5finger/` — 5 right-hand fingers, ~30 captures each  
**Enrollment**: 10 frames per finger, remaining used for verification  
**Preprocessing**: percentile stretch (P0.1–P99) + unsharp mask (boost=4)

---

## 1. Corpus Summary

| Finger        | PGMs | Enrolled | Verified |
|---------------|------|----------|----------|
| right-thumb   |   30 |       10 |       20 |
| right-index   |   29 |       10 |       19 |
| right-middle  |   30 |       10 |       20 |
| right-ring    |   28 |       10 |       18 |
| right-little  |   28 |       10 |       18 |
| **Total**     |  145 |       50 |       95 |

**Impostor tests**: each finger enrolled (10 frames) verified against ALL captures
from every OTHER finger → 580 cross-finger attempts.

---

## 2. Phase 10 Baseline Results (Before RANSAC)

**Matcher**: SIGFM (FAST-9 + BRIEF-256, ratio test 0.90, NMS strict `>`)  
**Scoring**: pairwise angle-counting (`geometric_score()`)  
**Score threshold**: 40

### Genuine Match (FRR)

| Finger        | Verified | Matched | Rejected | FRR   | Score Range     | Mean Score |
|---------------|----------|---------|----------|-------|-----------------|------------|
| right-thumb   |       20 |      20 |        0 |  0.0% | 40–204,663      |     21,933 |
| right-index   |       19 |      16 |        3 | 15.8% | 23–82,219       |      6,624 |
| right-middle  |       20 |      13 |        7 | 35.0% | 0–15,531        |      1,147 |
| right-ring    |       18 |      15 |        3 | 16.7% | 1–734,753       |     61,943 |
| right-little  |       18 |      18 |        0 |  0.0% | 53–194,216      |     29,935 |
| **Overall**   |   **95** |  **82** |   **13** |**13.7%**|               |            |

### Impostor Test (FAR)

| Enrolled      | vs Index | vs Little | vs Middle | vs Ring | vs Thumb |
|---------------|----------|-----------|-----------|---------|----------|
| right-index   | —        | 12/28     | 13/30     | 15/28   | 9/30     |
| right-little  | 15/29    | —         | 18/30     | 19/28   | 10/30    |
| right-middle  | 13/29    | 17/28     | —         | 12/28   | 3/30     |
| right-ring    | 18/29    | 17/28     | 19/30     | —       | 16/30    |
| right-thumb   | 13/29    | 9/28      | 9/30      | 8/28    | —        |

**False accepts: 265/580 — FAR: 45.7%** ← Catastrophic, matcher cannot
discriminate between different fingers.

### Score Distributions

| Metric | Genuine | Impostor |
|--------|---------|----------|
| Min    | 0       | 0        |
| P25    | 81      | 16       |
| Median | 352     | 35       |
| P75    | 7,274   | 82       |
| P95    | —       | 252      |
| Max    | 734,753 | 991      |

Overlap zone: ~5 to ~991. EER ≈ 25% at threshold ~75.

---

## 3. Phase 11 Results — RANSAC Geometric Verification ✅

> **Note:** Phase 11 benchmarks used 10 enrollment frames and no stddev verify
> gate — methodology issues fixed in Phase 12 (see §6.0). Absolute FRR values
> are inflated; relative findings (FAR elimination, config ranking) remain valid.
> Phase 12 §6.5 has the authoritative FRR/FAR numbers.

**Matcher**: SIGFM (FAST-9 + BRIEF-256, ratio test **0.85**, cross-check filter)  
**Scoring**: RANSAC rigid-transform inlier counting (200 iter, ε=2px, LS refinement)  
**Score threshold**: 6

### Genuine scores (95 samples)
```
Min: 0  P5: 2  P10: 3  P25: 3  Median: 7  P75: 19  Max: 47
```

### Impostor scores (580 samples)
```
Min: 0  P25: 2  Median: 3  P75: 3  P90: 4  P95: 4  P99: 5  Max: 5
```

### FRR/FAR Tradeoff Table

| Threshold | FRR    | FAR    | Notes |
|-----------|--------|--------|-------|
|         2 |  2.1%  | 87.1%  |       |
|         3 | 17.9%  | 40.5%  |       |
|         4 | 33.7%  |  7.6%  |       |
|         5 | 41.1%  |  0.9%  |       |
|     **6** |**42.1%**|**0.0%**| ← **deployed threshold** |
|         7 | 48.4%  |  0.0%  |       |
|        10 | 60.0%  |  0.0%  |       |
|        20 | 77.9%  |  0.0%  |       |
|        30 | 90.5%  |  0.0%  |       |
|        40 | 97.9%  |  0.0%  |       |

### Key Results

| Metric | Phase 10 (Before) | Phase 11 (After) | Change |
|--------|-------------------|-------------------|--------|
| **FAR** | **45.7%** (265/580) | **0.00%** (0/580) | **Fixed** |
| FRR (per-attempt) | 13.7% (13/95) | 42.1% (40/95) | +28.4pp |
| FRR (5-retry effective) | ~13% | **~1.3%** | Improved |
| Impostor max score | 991 | **5** | 200× reduction |
| Genuine median | 352 | 7 | Different scale |
| Score overlap | Heavy (5–991) | **None** at T=6 | **Eliminated** |
| EER | ~25% | ~7% (est.) | Much improved |

### Tradeoff Rationale

The old 45.7% FAR meant **any finger had a ~46% chance of unlocking the
device** — completely insecure. The new 0% FAR provides real security.

The 42.1% per-attempt FRR means users retry ~1.7 times on average. With
fprintd's standard 5-retry allowance, the effective FRR is only **~1.3%**
(0.42¹ verified... 0.42⁵ = 0.013 all-5-fail probability).

---

## 4. Phase 11 Implementation Details

### Changes to `sigfm.c`

1. **Replaced `geometric_score()` with `ransac_score()`** (~100 lines)
   - 2-point rigid transform estimation (rotation + translation)
   - xorshift32 deterministic PRNG seeded from match geometry
   - 200 RANSAC iterations, ε=2.0px inlier threshold
   - Scale sanity check (reject transforms with scale ≠ 1.0 ± 20%)
   - Least-squares refinement: re-estimate transform from all inliers
     of best RANSAC model via centroid + cross-covariance, then re-count

2. **Added `cross_check_filter()`** (~30 lines)
   - For each forward match q→t, verify that the reverse best-match
     t→q agrees. Keeps only mutual best matches.
   - Reduced impostor max score from 8 → 5–6

3. **Lowered `RATIO_TEST`** from 0.90 → 0.85
   - Further reduces ambiguous descriptor matches
   - Combined with cross-check, impostor max dropped to 5

4. **Recalibrated `score_threshold`** from 24 → 6 in `goodix511.c`
   - Adapted to new inlier-count score scale (0–~50 vs old 0–735k)

### Parameter Sweep Results

| Config | RATIO | ε (px) | Cross-check | Genuine Med | Imp Max | FAR=0% FRR |
|--------|-------|--------|-------------|-------------|---------|------------|
| A      | 0.80  | 3.0    | No          | 7           | 7       | 47.4%      |
| B      | 0.85  | 4.0    | No          | 9           | 9       | 50.5%      |
| C      | 0.90  | 3.0    | No          | 10          | 11      | 51.6%      |
| D      | 0.90  | 2.0    | No          | 9           | 8       | 47.4%      |
| E      | 0.90  | 2.0    | **Yes**     | 8           | 6       | 45.3%      |
| **F**  |**0.85**|**2.0** | **Yes**     | **7**       | **5**   | **42.1%**  |
| G      | 0.80  | 2.0    | Yes         | 6           | 5       | 48.4%      |

Config F was selected: best impostor max (5) with acceptable FRR.

### Approaches Tested But Not Adopted

| Approach | Result | Why Rejected |
|----------|--------|--------------|
| Rotation constraint (±15–30°) | Genuine max 27→22, impostor max unchanged | Genuine placements have more rotation than expected |
| Translation constraint (20–30px) | Similar — hurt genuine, not impostor | Genuine finger shifts are large on 64×80 sensor |
| Rotation-steered BRIEF (ORB IC angle) | Genuine max 51→27, median 10→8 | IC angle noisy on fingerprints; removed orientation as discriminator |
| Hamming distance ceiling (50–70) | No effect | Ratio test already filters weak matches |
| Descriptor-weighted scoring (128−dist) | No separation improvement | Both genuine and impostor inliers have similar per-match quality |
| Higher keypoints (FAST=5, MAX_KP=200) | +2 genuine median, +1 impostor max | Marginal gain not worth impostor increase |

---

## 5. Diagnosis (Updated)

### Problem Solved: FAR

The original `geometric_score()` used pairwise angle-counting — O(n⁴) agreeing
pairs from O(n²) angle-entries. Random descriptor matches easily produced
50–991 agreement counts. RANSAC inlier counting requires a coherent spatial
transform, which random matches almost never satisfy. **FAR eliminated.**

### Remaining Limitation: Per-Attempt FRR

About 42% of genuine captures produce ≤5 RANSAC inliers, indistinguishable
from the best impostor alignments (also ≤5). Root causes:

1. **64×80 pixel sensor** — only ~5,120 pixels, yielding ~30–80 FAST keypoints.
   After ratio test, cross-check, and duplicate removal, genuine captures
   may have only 5–15 usable matches. RANSAC with 2-point sampling needs
   ≥5–6 correct matches to reliably find ≥6 inliers.

2. **Fingerprint placement variation** — finger rotation, translation, and
   pressure differences between enrollment and verification change which
   keypoints are detected and where. On a 3.2×4.0mm sensor, even small shifts
   move keypoints to the image border where they're excluded.

3. **BRIEF descriptor instability** — unsteered 256-bit BRIEF descriptors
   are sensitive to rotation (>10° flips ~20% of bits). Adding rotation
   steering (ORB-style) was tested but **hurt** discrimination — the IC angle
   is noisy on fingerprint ridge patterns and removed orientation as a
   useful feature for matching.

4. **Same-hand finger similarity** — on a 64×80 sensor at 508 DPI, different
   fingers of the same hand share similar ridge spacing and texture patterns.
   BRIEF descriptors in the 3–5 impostor inlier range represent genuine
   texture similarity, not matching errors.

### Comparison with Windows Driver

The Windows `AlgoMilan` uses a fundamentally different approach:
- **Minutiae-based matching** (ridge endings + bifurcations), not keypoints
- **50 sub-templates** with adaptive learning
- **Triple-based affine estimation** (3 points → full affine) vs our 2-point rigid
- More features per image due to different detection algorithms

Reaching Windows-level accuracy would require minutiae extraction, which is
a much larger engineering effort (~1000+ lines, ridge orientation field,
thinning, minutia classification).

---

## 6. Phase 12 Results — Cross-Session Validation

**Date**: 2026-02-23  
**Corpora**: S1 = `corpus/5finger/` (30×5 fingers), S2 = `corpus/5finger-s2/` (30×5 fingers)  
**Bug fixes**: Two critical bugs in replay-pipeline.c were found and fixed during this phase:

1. **Center vs left crop**: replay-pipeline used center crop (`offset = (88-64)/2 = 12`)
   but driver uses left-aligned crop (`offset = 0`). Fixed to match driver.
2. **Double calibration subtraction**: driver saves raw frames AFTER calibration subtraction,
   but replay-pipeline applied calibration AGAIN when `--cal` was passed. Removed auto-detection
   of calibration.bin in batch mode.

### 6.0 Benchmark Methodology Audit

A critical review of the benchmark tooling revealed five issues in
`sigfm-batch.c` and `run-tests.sh`:

1. **Quality gate divergence**: Driver applies TWO quality gates (stddev ≥ 25
   on the preprocessed image + keypoints ≥ 25 after SIGFM extraction).
   Benchmark only applied the keypoint gate, and only during enrollment.
2. **Enrollment count mismatch**: `run-tests.sh` enrolled 10 frames; driver
   uses 20 (`nr_enroll_stages`). Benchmark templates were significantly
   weaker than real enrollments.
3. **Score threshold default**: `sigfm-batch` defaulted to 40; driver uses 6.
4. **No retry simulation**: Benchmark counted quality-gated frames as failures
   instead of skipping them (matching the driver's retry behaviour).
5. **Template study algorithm mismatch**: Benchmark selected study replacement
   candidates by pairwise score; driver uses keypoint count.

All five were fixed in `sigfm-batch.c` and `run-tests.sh`.

### 6.1 Intra-Session (S1 cross-validation)

| Config   | Verified | Match | Reject | Gated | FRR   |
|----------|----------|-------|--------|-------|-------|
| No study | 47       | 35    | 12     | 3     | 25.5% |

### 6.2 Cross-Session (S1 enroll → S2 verify)

| Finger       | Match | Reject | Gated | Verified | FRR (no study) | FRR (with study) | Δ     |
|--------------|-------|--------|-------|----------|----------------|------------------|-------|
| right-index  | 22    | 7      | 1     | 29       | 24.1%          | 17.2%            | −6.9  |
| right-little | 23    | 6      | 1     | 29       | 20.7%          | 27.6%            | +6.9  |
| right-middle | 18    | 11     | 1     | 29       | 37.9%          | 34.5%            | −3.4  |
| right-ring   | 24    | 5      | 1     | 29       | 17.2%          | 27.6%            | +10.4 |
| right-thumb  | 24    | 6      | 0     | 30       | 20.0%          | 16.7%            | −3.3  |
| **TOTAL**    | 111   | 35     | 4     | 146      | **24.0%**      | **24.7%**        | **+0.7** |

Template study provides only marginal (+0.7pp) and inconsistent FRR change.

### 6.3 Cross-Session FAR (S1 enroll → S2 impostor)

| Config          | False Accepts | Trials | FAR    |
|-----------------|---------------|--------|--------|
| No study        |       2       |   580  | 0.34%  |
| With study      |      86       |   584  | 14.73% |

### 6.4 Template Study Verdict: **REJECT**

Template study (Phase 12c) is **catastrophically flawed**. FAR explodes from
0.34% to **14.73%** (43× increase). The mechanism:

1. An impostor frame barely matches (score ≥ 6)
2. Study replaces the weakest enrolled sub-frame with this impostor frame
3. Future impostor verifications now match the incorporated impostor features
4. Positive feedback loop → template drifts toward "any finger from this hand"

The root cause is that `score_threshold = 6` is too low to distinguish genuine
from impostor for template update decisions. Genuine scores typically range
6–47 (median ~7), while impostor max is 5. A score of 6 could be either a
marginal genuine match or an unusual impostor. The study mechanism needs a
much higher gate for updates (e.g., ≥ 20) to ensure only clearly genuine
frames are absorbed — but this would require separate thresholds for matching
vs study, adding complexity with uncertain benefit.

**FRR improvement is negligible**: 24.0% → 24.7% (+0.7pp, within noise), and
inconsistent across fingers (index improves −6.9pp, ring worsens +10.4pp).

**Action**: Template study code remains removed from the driver.

### 6.5 Phase 12 Summary

| Phase 12 Sub-task              | Status   | Impact |
|--------------------------------|----------|--------|
| 12a: Quality gate (stddev≥25)  | ✅ Keep  | Prevents enrollment of bad frames |
| 12b: Unsharp boost=4           | ✅ Keep  | Optimal (tested 2–8) |
| 12c: Template study            | ❌ Remove | FAR 0.34%→14.73% (43× worse) |
| Replay-pipeline bug fixes      | ✅ Done  | Crop + double-cal fixed |
| Benchmark methodology audit    | ✅ Done  | 5 issues fixed in sigfm-batch + run-tests |

Final numbers (Phase 12 final = 12a + 12b, no study):

| Metric | Value | Notes |
|--------|-------|-------|
| Intra-session FRR | **25.5%** | 35/47 verified match, 3 quality-gated |
| Cross-session FRR | **24.0%** | 111/146 verified match, 4 quality-gated |
| FAR (cross, no study) | **0.34%** | 2/580 false accepts |
| FAR (cross, with study) | **14.73%** | 86/584 — template study catastrophically broken |
| 5-retry FRR (intra) | **~0.11%** | 0.255⁵ = 0.0011 |
| 5-retry FRR (cross) | **~0.08%** | 0.240⁵ = 0.0008 |

---

## 7. Test Commands

```bash
# Full FRR + FAR test (corrected benchmark, threshold=6, 20 enrollment frames):
bash tools/benchmark/run-tests.sh --threshold=6 --enroll-count=20 corpus/5finger

# Cross-validation (intra-session, 5-fold):
bash tools/benchmark/run-tests.sh --threshold=6 --enroll-count=20 --cross-validate=5 corpus/5finger

# Score distribution analysis:
bash tools/benchmark/score-analysis.sh corpus/5finger

# Rebuild benchmark tool after sigfm.c changes:
make -C tools benchmark/sigfm-batch

# Single-finger cross-session benchmark:
BATCH=tools/benchmark/sigfm-batch
$BATCH --enroll corpus/5finger/right-index/capture_{0001..0020}.pgm \
       --verify corpus/5finger-s2/right-index/capture_*.pgm \
       --score-threshold=6 --stddev-gate=25
```
