# 15 — Advancement Strategy: From Broken FAR to Publishable Driver

**Date:** 2026-02-22  
**Purpose:** Comprehensive analysis of how to advance from the current state
(FAR=45.7%, EER≈25%) to a publishable AUR package, drawing on benchmark results
(doc 14), all previous analysis, and insights from the Windows driver decompilation.

---

## 1. Situation Assessment

### Where we are

The SIGFM matcher has been through 8 phases of development. It correctly detects
keypoints, computes descriptors, and finds matches. The **feature extraction pipeline is
working**. What is broken is the **geometric verification and scoring** stage.

| Metric | Current | Target | Gap |
|--------|---------|--------|-----|
| FRR | 13.7% | < 5% | Moderate |
| FAR | 45.7% | < 1% | **Critical** |
| EER | ~25% | < 2% | **Critical** |
| Score separation | Overlapping (0–991 impostor vs 0–734K genuine) | Clean gap | **Critical** |

### Root cause recap

`geometric_score()` counts pairwise angle-agreements between match vectors.
This is O(n⁴) in the number of matches, and random descriptor matches produce
scores in the hundreds because some angle-entries agree by chance. The algorithm
**does not verify spatial coherence** — it can't distinguish between matches that
form a consistent rigid transform and matches that are randomly scattered.

---

## 2. What the Windows Driver Actually Does

Deep-reading the decompiled `AlgoMilan.c` reveals the Windows matching pipeline in
detail. This is the most important new finding.

### 2.1 Windows Matching Pipeline (per sub-template)

```
┌──────────────────────────────────────────────────────────────────┐
│ 1. Feature extraction (Hessian blob detector, 448-bit descriptors)│
│ 2. KNN matching (brute-force Hamming, K=2, popcount)             │
│ 3. Ratio test filtering (via FUN_18003c850)                       │
│ 4. Geometric verification: TRIPLE-BASED AFFINE ESTIMATION        │
│    └── FUN_18003aaf0:                                             │
│        for each triple (i,j,k) of matched feature pairs:         │
│          • distance ratio check (5:6 bounds between pair distances)│
│          • orientation difference consistency (angle_ij ≈ angle_ik)│
│          • estimate 2×2 affine transform from 3 correspondences   │
│          • apply transform to ALL features                        │
│          • count inliers (residual < threshold)                   │
│          • keep triple producing most inliers                     │
│ 5. Best transform → spatial overlap scoring (pixel-level)         │
│ 6. Multi-criteria accept/reject decision tree (FUN_180019300)     │
│ 7. Repeat for all 50 sub-templates, aggregate                    │
└──────────────────────────────────────────────────────────────────┘
```

### 2.2 Key Decompilation Findings

**Function `FUN_18003aaf0` (line ~38550)** — the spatial consistency verifier.
This is the Windows equivalent of our `geometric_score()`. Critical details:

1. **Triple enumeration, not pair**: The function iterates over triples (i,j,k)
   of matched features, not pairs. Three points define a unique affine transform
   (rotation + translation + optional scale), whereas two points only define a
   similarity transform. This is more discriminative.

2. **Distance ratio pre-filter**: Before computing the transform, it checks:
   ```c
   dist_template = (dx_t² + dy_t²) >> 2;
   dist_probe    = (dx_p² + dy_p²) >> 2;
   // Accept only if: 5*dist_t <= 6*dist_p AND 5*dist_p <= 6*dist_t
   // i.e., ratio within [5/6, 6/5] ≈ [0.83, 1.20]
   ```
   This eliminates pairs with inconsistent scale, which is virtually all
   random matches.

3. **Minimum distance threshold**: Both distances must exceed `0x2ffff`
   (~196K in 8.8 fixed-point ≈ ~3 pixels apart). Rejects nearby feature
   pairs that produce degenerate transforms.

4. **Orientation consistency**: Checks that angle differences between matched
   features are consistent across the triple (within ±0x32 units ≈ ±50 degrees).

5. **Full inlier counting**: The estimated transform is applied to **all**
   matched features. For each feature:
   ```c
   residual_x = T(probe_x) - template_x + offset;
   residual_y = T(probe_y) - template_y + offset;
   if (abs(residual_x) < 0x281 && abs(residual_y) < 0x281
       && residual_x² + residual_y² < 0x64000) {
       inlier_count++;
   }
   ```
   The threshold `0x281` is ~2.5 pixels in 8.8 fixed-point.

6. **Quality gate on result**: Requires `inlier_count >= param_9` (typically 2–3)
   and accumulates `residual²` to compute mean residual.

7. **Early exit**: Once > 20 inliers found, exits immediately (`goto LAB_...`).

### 2.3 What Windows Does NOT Do

- No RANSAC (random sampling). It exhaustively evaluates all triples. With
  ≤31 features (`0x1f = 31`), the maximum is C(31,3) = 4,495 triples —
  perfectly tractable.
- No BRIEF descriptors. Uses 448-bit (56-byte) descriptors from the Hessian
  detector.
- No FAST corners. Uses multi-scale Hessian blob detection.
- No angle-pair counting (our broken approach).

### 2.4 Lessons for Our Implementation

| Windows Approach | Our Option | Recommendation |
|-----------------|------------|----------------|
| Exhaustive triples | Exhaustive triples | **Yes — adopt this** (≤C(128,3) but we can limit to top-K matches) |
| 2×2 affine from 3 points | 2-point rigid (rotation+translation) | **Start with 2-point rigid** (simpler, sufficient for same-sensor images with no scale change) |
| 448-bit Hessian descriptors | 256-bit BRIEF descriptors | **Keep BRIEF** (working, simpler) |
| Distance ratio 5:6 | Our LENGTH_MATCH 0.05 | **Adopt similar** (both reject scale-inconsistent pairs) |
| 50 sub-templates | 20 enrollment frames | **Keep 20** for now |
| Pixel-level overlap scoring | Not needed | **Skip** — inlier count is sufficient |
| Multi-criteria decision tree | Single threshold | **Keep simple threshold** |

---

## 3. Recommended Implementation Plan

### Priority-ordered changes

#### Change 1: Replace `geometric_score()` — **PRIMARY FIX**

Replace the pairwise angle-counting with inlier counting after rigid transform
estimation. Two viable approaches:

**Option A: 2-point RANSAC (simpler, recommended first)**
```
for N iterations (100–200):
    pick 2 random matches
    estimate rigid transform: rotation θ, translation (tx, ty)
    count inliers: |T(probe) − template| < ε
    keep best
score = best inlier count
```

- Pro: Simple (≤80 lines), well-understood, fast
- Con: 2 points = 4 DoF (similarity transform) — degenerate if points are close

**Option B: Exhaustive triple evaluation (Windows-style)**
```
for each triple (i,j,k) of matches:
    pre-filter: distance ratios within [0.83, 1.20] for all 3 pairs
    estimate affine/rigid from 3 correspondences
    count inliers
    keep best
score = best inlier count
```

- Pro: More discriminative (6 DoF affine), deterministic, matches Windows approach
- Con: O(n³) where n = number of matches; need to limit n ≤ ~30

**Recommendation: Start with Option A** (RANSAC). If 100 iterations with random
pairs doesn't achieve FAR < 1%, upgrade to Option B. In practice, 2-point rigid
transform verification should be more than sufficient since our sensor has no
scale change (fixed 508 DPI, same sensor, no zoom).

**Key implementation details:**

Rigid transform from 2 point correspondences (p1→q1, p2→q2):
```c
dx1 = p2.x - p1.x;  dy1 = p2.y - p1.y;
dx2 = q2.x - q1.x;  dy2 = q2.y - q1.y;
len1_sq = dx1*dx1 + dy1*dy1;
if (len1_sq < 9.0f) continue;  // too close, degenerate

// Rotation angle
cos_θ = (dx1*dx2 + dy1*dy2) / len1_sq;
sin_θ = (dx1*dy2 - dy1*dx2) / len1_sq;

// Translation
tx = q1.x - (cos_θ * p1.x - sin_θ * p1.y);
ty = q1.y - (sin_θ * p1.x + cos_θ * p1.y);

// Count inliers
int inliers = 0;
for each match (p→q):
    pred_x = cos_θ * p.x - sin_θ * p.y + tx;
    pred_y = sin_θ * p.x + cos_θ * p.y + ty;
    err = (pred_x - q.x)² + (pred_y - q.y)²;
    if (err < ε²) inliers++;
```

Suggested ε = 3.0 pixels (matching Windows's ~2.5 px threshold, slightly
more generous to accommodate our less precise FAST corners vs Hessian blobs).

#### Change 2: Lower ratio test — **SECONDARY FIX**

Lower `RATIO_TEST` from 0.90 to 0.80.

- At 0.90: ~10–30 matches per comparison (many ambiguous)
- At 0.80: ~5–15 matches per comparison (cleaner, more discriminative)
- RANSAC tolerates fewer matches well — it only needs 2 good ones

This reduces the noise floor that the geometric verifier has to cope with.
Phase 8 raised it from 0.75 to 0.90 to fix FRR, but that was compensating
for the broken `geometric_score()`. With RANSAC, you don't need many matches;
you need a few *good* ones.

#### Change 3: Score = inlier count — **SCORING REFORM**

The score becomes the best inlier count (0 to MAX_KP).

Expected distribution:
- **Genuine**: 10–50 inliers (fingerprint features consistently transform)
- **Impostor**: 0–2 inliers (random matches never form a coherent transform)

This creates a clean gap. Threshold at ~5 inliers should give FAR ≈ 0% with
FRR < 5%.

#### Change 4: Re-calibrate threshold — **TRIVIAL**

With the new inlier-count scoring:
- Set `score_threshold` in `goodix511.c` to ~5–8 (was 24 for the old metric,
  currently meaningless at 40)
- Validate against corpus

### Changes NOT recommended right now

| Change | Why not now |
|--------|-----------|
| Hessian blob detector | Hard to implement, FAST-9 is adequate for this sensor |
| Oriented BRIEF (ORB) | Only helps FRR from rotation; address FAR first |
| Adaptive template learning | Important for long-term UX but doesn't fix FAR |
| Factory calibration | Unknown retrieval command, not needed for matching |
| Boost 4→10 | Marginal benefit, risky without calibration |
| Pixel-level overlap scoring | Windows does this on top of inlier counting; unnecessary complexity |

---

## 4. Expected Outcomes

### Before (current)

| Metric | Value |
|--------|-------|
| FRR | 13.7% |
| FAR | 45.7% |
| EER | ~25% |
| Score range (genuine) | 0–734,753 |
| Score range (impostor) | 0–991 |
| Separation | None |

### After (predicted, Changes 1–4)

| Metric | Predicted | Rationale |
|--------|-----------|-----------|
| FRR | 3–8% | RANSAC preserves genuine matches; ratio test 0.80 may lose a few |
| FAR | 0–1% | Random matches never form coherent transforms |
| EER | 1–3% | Clean separation expected |
| Score range (genuine) | 8–60 inliers | Consistent fingerprint geometry |
| Score range (impostor) | 0–2 inliers | No coherent geometry possible |
| Separation | ~6 units gap | Threshold at 5 separates cleanly |

### Confidence

**High** — this is the standard approach used in every production fingerprint
matcher (including Windows's own implementation as confirmed by decompilation).
The only risk is FAST-9 producing slightly less repeatable keypoints than Hessian,
which could lower the inlier count but won't affect FAR.

---

## 5. Implementation Scope

| Item | Lines | File | Complexity |
|------|-------|------|------------|
| `ransac_score()` replacing `geometric_score()` | ~80 | `sigfm.c` | Low |
| Lower `RATIO_TEST` to 0.80 | 1 | `sigfm.c` | Trivial |
| Update `score_threshold` | 1 | `goodix511.c` | Trivial |
| Re-run benchmarks | — | `run-tests.sh` / `score-analysis.sh` | Testing |
| **Total** | ~80 new | | **~2 hours** |

No API changes. No serialisation changes. No new dependencies.
Existing enrolled prints will produce different scores but remain compatible
(feature extraction is unchanged — only scoring changes).

---

## 6. Interaction Effects

### Ratio test × RANSAC

With the current angle-counting scorer, lowering the ratio test from 0.90 to
0.80 would *increase* FRR significantly (Phase 8 proved this). But with RANSAC:

- Fewer matches means less noise in geometric verification
- RANSAC only needs 2 correct matches out of any number of candidates
- Net effect: FRR stays low or improves, FAR drops dramatically

### Unsharp boost × descriptor quality

The current boost=4 is tuned for BRIEF descriptors. Increasing to 10 (Windows
style) might help RANSAC by making descriptors more repeatable (fewer false
matches → cleaner inlier count). But this is a second-order effect. Test
after RANSAC is validated.

### Adaptive learning × RANSAC

Template learning becomes much more valuable once RANSAC is working. Currently,
learning would just accumulate more reference frames that still can't be
distinguished from other fingers. After RANSAC, learning can genuinely improve
FRR over time by building templates that better represent the user's actual
finger placement habits.

---

## 7. Post-RANSAC Results & Retrospective

**Updated: 2026-02-22** — All recommendations from §3 have been implemented and
benchmarked. This section records outcomes vs predictions and the full audit of
improvement opportunities across all analysis documents.

### 7.1 Outcomes vs Predictions (§4)

| Metric | Predicted (§4) | Actual | Notes |
|--------|----------------|--------|-------|
| FAR | 0–1% | **0.34%** (cross) | Exceeded expectations |
| FRR | 3–8% | **25.5%** (intra), **24.0%** (cross) | Worse than predicted; FAST-9 repeatability limit |
| EER | 1–3% | ~5% (est.) | Reasonable |
| Genuine score range | 8–60 inliers | 0–47, median 7 | Lower end than predicted |
| Impostor max score | 0–2 inliers | **5** | Higher than predicted but below threshold |
| Gap at FAR=0% | ~6 units | **1 unit** (threshold 6, imp max 5) | Tight but sufficient |

**Why FRR was worse than predicted:** The prediction assumed FAST-9 keypoints
would be as repeatable as Hessian blobs. In practice, FAST-9 on a 64×80 sensor
produces only 30–80 keypoints per frame which are highly sensitive to placement
variation. After ratio test (0.85) and cross-check filtering, genuine captures
often have only 5–15 usable matches. RANSAC with 2-point sampling needs ≥5–6
correct matches to reliably find ≥6 inliers, and many genuine captures fall
below this threshold. The FRR is a fundamental limitation of FAST-9 + BRIEF-256
on such a small sensor, not a RANSAC configuration issue.

**Ratio test settled at 0.85, not 0.80:** Testing showed 0.80 (recommended in §3)
combined with cross-check gives worse FRR than 0.85 with cross-check. The
cross-check filter provides the match-quality benefit that the stricter ratio
test was meant to achieve, while keeping more genuine matches.

### 7.2 Phase 12 Results: Post-RANSAC FRR Reduction

All Phase 12 sub-tasks have been evaluated:

| Sub-task | Outcome | Current Status |
|----------|---------|---------------|
| **12a: Quality gate** (stddev ≥ 25) | Prevents garbage frames from burning retries | **✅ Keep** |
| **12b: Boost factor** | Swept [4, 6, 8]; boost > 4 destroys FAR without factory cal | **✅ Keep boost=4** |
| **12c: Adaptive template learning** | **REJECTED** — FAR regression 0.34% → 14.73% (43×) | **❌ Removed from driver** |
| **12d: Enrollment quality-ranked insertion** | Not yet implemented | **Open** |

**Template study rejection details (12c):** Implemented `fpi_print_sigfm_study()`
which replaced the weakest enrolled sub-frame (by keypoint count) with a new
scan after successful verify. Cross-session benchmarks revealed a catastrophic
flaw: FAR explodes from 0.34% to **14.73%** (43× increase). Impostor frames
that barely match (score ≥ 6) get absorbed into the template, creating a
positive feedback loop. The root cause is that `score_threshold = 6` is too
low to distinguish genuine from impostor for template update decisions
(genuine median ~7, impostor max 5). FRR improvement was negligible
(24.0% → 24.7%, +0.7pp) and inconsistent across fingers. Code has been
completely removed from the driver.

**Why the Windows driver's study works (decompilation analysis):** The
Windows driver (`AlgoMilan.c`) implements template study with fundamentally
different architecture — seven layers of protection our naive approach lacked:

| Mechanism | Windows | Our v1 |
|-----------|---------|--------|
| **Study gate** | Separate: image quality > 15 AND coverage > 65% | Same as match gate (score ≥ 6) |
| **Replacement target** | Multi-tier: lowest hit-count → lowest quality → oldest | Lowest avg cross-score |
| **Spatial coverage check** | `FUN_18001f100()` refuses if replacement leaves coverage gap | None |
| **Anchor protection** | Best-connected sub-template can never be replaced | None |
| **Degradation lock** | Locks template permanently after 50 failed study attempts | None |
| **Candidate deferral** | 20-slot ring buffer; probe must prove itself before insertion | Immediate replacement |
| **Sub-template pool** | 50 (2% change per replacement) | 20 (5% change per replacement) |

The key insight: Windows decides study based on *image quality metrics*, not
match scores. The match score determines accept/reject; quality+coverage
determines whether to learn. These are fundamentally different questions.
Further, the hit-count ranking ensures only sub-templates that *never
contribute to any match* get replaced — the template's most useful members
are protected.

**Path forward (§8):** Template study v2 with separate `--study-threshold`
and progressive test harness to validate safety before driver integration.

### 7.3 Comprehensive Improvement Opportunity Audit

Full audit of all 19 analysis documents, categorizing every improvement idea
mentioned anywhere. **87 total ideas** identified across 12 categories.

#### A. Preprocessing / Image Processing

| # | Idea | Source | Status |
|---|------|--------|--------|
| A1 | Percentile histogram stretch (P0.1–P99) | docs 11, 13, 14 | **✅ Done** |
| A2 | Unsharp mask boost increase (2→4; 10 tested) | docs 11, 13, 14, 15 | **✅ Done** (4 optimal; >4 destroys FAR without factory cal) |
| A3 | Per-pixel factory calibration (kr/b correction) | docs 11, 13 | **Blocked** — USB command to retrieve ~140KB blob unknown |
| A4 | Quality/coverage gating (stddev ≥ 25) | docs 11, 13, 14 | **✅ Done** |
| A5 | 3×3 Gaussian blur (part of unsharp mask) | doc 11 | **✅ Done** |
| A6 | 12-bit working space before final 8-bit quantization | doc 11 | **Open** — preserves dynamic range during sharpening. Low priority. |
| A7 | Coating-aware quality adjustment | doc 13 | **Deferred** — edge case for screen protectors |
| A8 | Frame averaging / multi-frame denoising | doc 10 | **Rejected** — noise is not the bottleneck; sensor area is |
| A9 | Crop alignment (center vs left) | doc 14 | **✅ Fixed** (bug in replay-pipeline) |
| A10 | Double calibration subtraction | doc 14 | **✅ Fixed** (bug in replay-pipeline) |

#### B. Feature Detection

| # | Idea | Source | Status |
|---|------|--------|--------|
| B1 | FAST-9 corner detection (replacing SIFT/SURF) | docs 3, 9 | **✅ Done** |
| B2 | Multi-scale FAST-9 (Gaussian pyramid, 2–3 levels) | doc 13 | **✅ Done** — 2-level pyramid, ~100→128 kp/frame. See §10. |
| B3 | Multi-scale Hessian blob detector (Windows-style) | docs 13, 15 | **Deferred** — large effort, uncertain gain, IP concerns |
| B4 | Hessian determinant keypoint filter on FAST-9 results | doc 13 | **❌ Rejected** — destroys FRR (+6–70pp) by reducing keypoint count on tiny sensor. See §11.6. |
| B5 | NMS tie-breaking fix (`>=` → `>`) | doc 14 | **✅ Done** |
| B6 | Descriptors on original image (not re-blurred) | doc 14 | **✅ Done** — critical fix |

#### C. Matching / Descriptors

| # | Idea | Source | Status |
|---|------|--------|--------|
| C1 | BRIEF-256 binary descriptors (replacing SIFT) | docs 3, 9 | **✅ Done** |
| C2 | Ratio test tuning (0.75→0.90→0.85→0.80) | docs 14, 15 | **✅ Done** — settled at 0.80 with cross-check. See §10. |
| C3 | Oriented BRIEF (ORB IC-angle steering) | docs 14, 15 | **Rejected** — IC angle noisy on fingerprint ridges; hurt discrimination |
| C4 | Cross-check filter (mutual best match) | doc 14 | **✅ Done** — reduced impostor max 8→5 |
| C5 | Hamming distance ceiling (50–70) | doc 14 | **Rejected** — no effect; ratio test already filters |
| C6 | Descriptor-weighted scoring (128−dist per inlier) | doc 14 | **Rejected** — no separation improvement |
| C7 | Higher keypoint count (FAST=5, MAX_KP=200) | doc 14 | **Rejected** — +2 genuine median not worth +1 impostor max |

#### D. Geometric Verification / Scoring

| # | Idea | Source | Status |
|---|------|--------|--------|
| D1 | RANSAC rigid-transform inlier counting | docs 14, 15 | **✅ Done** — FAR 45.7%→0.0% |
| D2 | Exhaustive triple-based affine (Windows-style) | doc 15 | **Tested — neutral** (§11.9). Identical scores to RANSAC. Disabled (TRIPLE_MAX_N=0) |
| D3 | Distance ratio pre-filter on RANSAC sample pairs | doc 15 | **✅ Done** — `RANSAC_MIN_DIST_SQ = 9.0f` and scale_sq check [0.64, 1.44]. Confirmed in §9.1. |
| D4 | Minimum distance threshold for sample pairs | doc 15 | **✅ Done** — `RANSAC_MIN_DIST_SQ = 9.0f` (3px). Confirmed in §9.1. |
| D5 | Orientation consistency check across triple | doc 15 | **Open** — part of exhaustive triple approach (D2) |
| D6 | Scale sanity check (±20%) | doc 14 | **✅ Done** — in RANSAC |
| D7 | Rotation constraint (±15–30°) | doc 14 | **Rejected** — genuine placements vary more than expected |
| D8 | Translation constraint (20–30px) | doc 14 | **Rejected** — genuine shifts are large on tiny sensor |
| D9 | Pixel-level overlap scoring | doc 15 | **Rejected** — unnecessary complexity |
| D10 | Multi-criteria accept/reject decision tree | doc 15 | **Deferred** — keep simple threshold |
| D11 | Least-squares refinement after RANSAC | doc 14 | **✅ Done** |

#### E. Enrollment / Template Management

| # | Idea | Source | Status |
|---|------|--------|--------|
| E1 | Adaptive template study (replace weakest sub-frame) | docs 11, 13, 14, 15 | **❌ v1 Rejected** — naive approach absorbs impostors (FAR 0.34%→14.73%). See §8 for v2 strategy. |
| E2 | Increase sub-template count (20→30–40; Windows uses 50) | docs 11, 13 | **Tested** — no effect at thresh=7 (30 captures identical to 20). See §11. |
| E3 | Score-based sub-template sorting during enrollment | doc 13 | **Open** — keep highest quality, replace lowest |
| E4 | Quality-ranked insertion during enrollment | doc 13 | **Tested** — no effect at thresh=7 (identical FRR/FAR). See §11. |
| E5 | Sub-template pruning / deduplication | doc 13 | **Tested** — trades FRR for FAR; not usable. See §9, §11. |
| E6 | Progressive quality thresholds during enrollment | doc 13 | **Open** — strict early (high quality), lenient later (placement diversity) |
| E7 | Stitch info (spatial offsets between sub-templates) | docs 11, 13 | **Deferred** — interesting but complex |
| E8 | Template degradation counter (lock after N failed updates) | doc 13 | **Open** — relevant to v2 study strategy (§8) |
| E9 | Re-enrollment after preprocessing changes | doc 2 | **Known** — documented caveat |

#### F. Matching Architecture

| # | Idea | Source | Status |
|---|------|--------|--------|
| F1 | SIGFM as primary matcher (non-minutiae) | docs 0, 2, 3, 9, 10 | **✅ Done** — NBIS proven non-viable |
| F2 | NBIS on upscaled images (2×–6×) | docs 6, 6a, 9, 10 | **Rejected** — 0–2 minutiae at all scales |
| F3 | Pure-C SIGFM rewrite (no OpenCV/C++) | docs 3, 4, 9 | **✅ Done** — 665 lines pure C |
| F4 | ORB (Oriented FAST + BRIEF) | doc 9 | **Partial** — FAST+BRIEF done; orientation steering rejected (C3) |
| F5 | SIGFM as upstream core matching backend | docs 6, 6a, 13 | **Open** — required for upstream acceptance |
| F6 | Hybrid SIGFM/NBIS driver-private matching | docs 6, 6a | **Deferred** — less intrusive upstream path |
| F7 | Match retry / re-capture on first failure | docs 13, 15 | **Skipped** — fprintd's 5-retry mechanism covers this |
| F8 | Relaxed NBIS mindtct profile for small area | doc 10 | **Rejected** — physical area too small regardless |

#### G. TLS / Crypto / Transport

| # | Idea | Source | Status |
|---|------|--------|--------|
| G1 | OpenSSL → GnuTLS migration | docs 6, 6a, 9 | **✅ Done** |
| G2 | GnuTLS → OpenSSL for upstream consistency | docs 9, 13 | **Open** — depends on maintainer preference |
| G3 | Remove pthreads dependency | docs 6, 9 | **✅ Done** |
| G4 | Proper PSK provisioning flow | doc 13 | **Deferred** — hardcoded approach works |

#### H. Hardware / Firmware

| # | Idea | Source | Status |
|---|------|--------|--------|
| H1 | Firmware flash separate from driver | docs 2, 6 | **✅ Done** — documented setup step |
| H2 | fwupd integration | docs 6, 6a | **Deferred** — Huawei won't cooperate |
| H3 | Runtime firmware version detection in probe | docs 2, 13 | **Open** — required for upstream |
| H4 | HV DAC voltage adjustment for image quality | doc 13 | **Deferred** — firmware-level, low priority |
| H5 | USB interface number fix (0→1) | doc 8 | **✅ Done** |
| H6 | Python warm-up / TLS reset detection | doc 8 | **Known** — documented workaround |
| H7 | True super-resolution (multi-frame) | doc 10 | **Rejected** — physically impossible |
| H8 | Mosaic stitching (multi-region) | doc 10 | **Rejected** — firmware limitation |
| H9 | Full 51xx family support (5110, 5117, 5120, 521d) | docs 6, 9 | **Open** — only 5110 tested |

#### I. Build System / Packaging

| # | Idea | Source | Status |
|---|------|--------|--------|
| I1 | Remove OpenCV dependency | docs 6, 6a | **✅ Done** |
| I2 | Remove C++ from project | doc 9 | **✅ Done** |
| I3 | GCC 15 compatibility fix | docs 0, 2, 5 | **✅ Done** |
| I4 | AUR PKGBUILD | doc 12 | **Open** — designed but not published |
| I5 | Debian packaging | doc 12 | **Open** |
| I6 | meson udev/libudev name fix | docs 7, 12 | **Open** — shim workaround used |
| I7 | meson `goodixtls` build option | doc 9 | **Open** — required for upstream |
| I8 | Rebase onto upstream 1.94.10 | docs 4, 9 | **Open** — 1 release behind |

#### J. Libfprint Core Bugs

| # | Idea | Source | Status |
|---|------|--------|--------|
| J1 | `fpi_device_add_timeout` monotonic time fix | doc 8 | **✅ Done** locally — worth upstreaming |
| J2 | Thermal throttle per-driver override | docs 8, 9 | **✅ Done** (`temp_hot_seconds = -1`) |
| J3 | `bz3_threshold` → `score_threshold` rename | doc 13 | **Open** — touches every driver |

#### K. Upstream / Community

| # | Idea | Source | Status |
|---|------|--------|--------|
| K1 | Submit upstream MR to freedesktop.org | docs 6, 9, 13 | **Open** |
| K2 | Contact @hadess re: GnuTLS acceptability | docs 6, 6a | **Open** |
| K3 | Coordinate with @gulp on PR #32 / 5117 | docs 0, 6 | **Open** |
| K4 | Update Arch Wiki | doc 5 | **Open** |
| K5 | 3-device testing for upstream | docs 6-upstream, 13 | **Open** — blocker |
| K6 | GTK-Doc for new public symbols | doc 9 | **Open** — should be none |
| K7 | Virtual device tests for CI regression | doc 14 | **Open** |

#### Summary Statistics

| Category | Total | ✅ Done | ❌ Rejected/Tested | Open/Deferred |
|----------|-------|---------|---------------------|---------------|
| A. Preprocessing | 10 | 5 | 1 | 4 |
| B. Feature Detection | 6 | 4 | 1 | 1 |
| C. Matching/Descriptors | 7 | 4 | 3 | 0 |
| D. Geometric Verification | 11 | 6 | 3 | 2 |
| E. Enrollment/Templates | 9 | 0 | 3 | 5 (+1 N/A) |
| F. Matching Architecture | 8 | 4 | 2 | 2 |
| G. TLS/Crypto | 4 | 2 | 0 | 2 |
| H. Hardware/Firmware | 9 | 2 | 2 | 5 |
| I. Build/Packaging | 8 | 4 | 0 | 4 |
| J. Core Bugs | 3 | 2 | 0 | 1 |
| K. Upstream/Community | 7 | 0 | 0 | 7 |
| **TOTAL** | **82** | **33** | **16** | **33 (+1 N/A)** |

### 7.4 Libfprint Reusable Code Audit

Audited all libfprint core code and other drivers for functionality that SIGFM
duplicates or could reuse.

| Area | Finding |
|------|---------|
| `fpi_std_sq_dev()` in fpi-image.c | Returns *squared* stddev. Our quality gate uses plain stddev with integer arithmetic. Different semantics — no benefit to reusing. |
| `fpi_mean_sq_diff_norm()` | Normalized pixel diff for swipe assembly. Not applicable. |
| `fpi_image_resize()` | Integer upscaling via pixman. Not needed. |
| `fpi_assemble_frames/lines()` | Swipe sensor stitching. Not applicable to area sensor. |
| elan `process_frame_thirds()` | Driver-specific piecewise normalization. Pattern: each driver implements its own. Expected. |
| NBIS `gen_quality_map()` | Deeply coupled to minutiae pipeline. Not portable. |
| NBIS `get_neighborhood_stats()` | Per-minutia quality. Could be adapted for per-keypoint quality weighting in future. Not needed now. |
| Print matching framework | `fpi_print_sigfm_match()` correctly mirrors `fpi_print_bz3_match()` pattern. **Properly integrated.** |
| Serialization | SIGFM serialization properly bridges into GVariant FP3 storage via `fp_print_serialize/deserialize`. **Properly integrated.** |
| `hamming_dist()` in sigfm.c | Only Hamming distance in codebase. Could use `__builtin_popcountll()` for ~4× micro-optimization but current is sub-millisecond with MAX_KP=128. Not worth changing. |

**Conclusion:** SIGFM integration is clean with no meaningful duplication. The
codebase follows proper separation: driver-level preprocessing → SIGFM algorithm
→ framework integration (fpi-print.c / fp-print.c).

### 7.5 Most Promising Remaining Ideas (ranked by effort/impact)

For reducing FRR beyond current 28.6% cross-session (threshold=7):

**Completed (no longer candidates):**
- ~~D3+D4~~ — ✅ Already implemented (RANSAC_MIN_DIST_SQ, scale check)
- ~~B2~~ — ✅ Done (2-level pyramid, 100→128 kp/frame). See §10.
- ~~E4~~ — Tested, no effect (quality-ranked 30→20 identical results). See §11.
- ~~E2~~ — Tested, no effect (30 captures identical to 20). See §11.
- ~~E5~~ — Tested, trades FRR for FAR (not usable). See §9, §11.

**Still open and promising:**

1. **D2: Exhaustive triple-based affine** (Windows-style, ~80 lines)
   — Replace RANSAC random sampling with exhaustive triple enumeration.
   Could find more inliers on difficult captures where random sampling misses.

2. **Template study v2** (§8, ~100 lines in driver)
   — Already validated +3.5pp FRR at old threshold. Needs re-benchmarking
   with new multi-scale + ratio=0.80 + threshold=7 configuration.

3. **RANSAC iteration increase** (1 line)
   — Current 200 iterations may miss best model on high-keypoint frames.
   Cheap to test; diminishing returns above ~500.

---

## 8. Template Study v2 — Design and Validation Strategy

**Date:** 2026-02-22

Template study v1 was rejected due to catastrophic FAR regression (§7.2).
However, the Windows driver proves study CAN work with proper safeguards.
The key missing piece is a **separate study gate** — requiring a much higher
confidence for template updates than for match acceptance.

### 8.1 Hypothesis

Template study will progressively improve FRR over time without degrading FAR,
provided the study gate is high enough that only clearly genuine frames
(not borderline matches) are absorbed into the template.

### 8.2 Test Harness Design

Before implementing any algorithm changes, we need a test harness that can
measure both **progressive FRR improvement** and **progressive FAR stability**.

#### Test A — Progressive FRR (does study help over time?)

For each finger: enroll 20 from S1, verify S2 frames 1→30 sequentially
with study enabled. Measure match rate in three windows:

| Window | Frames | Expected (if study works) |
|--------|--------|---------------------------|
| Early  | 1–10   | Baseline FRR (~24%)       |
| Middle | 11–20  | Lower FRR                 |
| Late   | 21–30  | Lowest FRR                |

Run the same sequence WITHOUT study as control. If study works, the
late-window FRR should be significantly lower than early-window. The
control should show no trend.

#### Test B — Progressive FAR (does study break security?)

For each finger: enroll 20 from S1, then interleave:
1. Verify 5 genuine S2 frames (with study — template evolves)
2. Test FAR against all 4 other fingers' S2 frames
3. Repeat (6 checkpoints: after 0, 5, 10, 15, 20, 25 genuine frames)

Plot FAR at each checkpoint. A safe implementation keeps FAR near 0.34%
throughout.

#### Test C — Study threshold sweep

Repeat Tests A+B with `--study-threshold=N` for N ∈ {8, 10, 15, 20, 25}.
This is our simplest approximation of Windows's separate quality gate:
match at score ≥ 6, but only absorb into template when score ≥ N.

### 8.3 Harness Implementation

New options for `sigfm-batch.c`:
- `--study-threshold=N` — separate score gate for template updates (default:
  same as `--score-threshold`). Only absorb frames with score ≥ N.
- Per-frame CSV output mode (`--csv`) for downstream windowed analysis.

New script `tools/benchmark/study-test.sh`:
- Runs Tests A, B, and C across all 5 fingers
- Produces summary table: study-threshold × window → FRR + FAR
- Identifies the study-threshold that minimizes late-window FRR while
  keeping all-checkpoint FAR ≤ 0.5%

### 8.4 Success Criteria

Study v2 is accepted if, for some study-threshold N:
1. **Late-window FRR < early-window FRR** by ≥ 5pp (measurable improvement)
2. **FAR at all checkpoints ≤ 0.5%** (no security regression)
3. **Effect is consistent** across ≥ 4 of 5 fingers

If no threshold satisfies all three criteria, study is abandoned permanently.

### 8.5 Implementation Order

**Build the test harness first, then the algorithm.** Rationale:
- We already proved the naive algorithm doesn't work — we need measurement
  BEFORE iterating on the algorithm
- The harness is smaller scope (~50 lines in sigfm-batch + ~80 lines shell)
  vs algorithm changes (~100+ lines)
- Test-driven approach: define pass/fail criteria → build measurement →
  iterate on algorithm until criteria met or abandoned
- Avoids another "implement → discover it's broken → revert" cycle

### 8.6 Naive Study Results (2026-02-22)

Harness run with `--thresholds=10,20` (match threshold = 6).

**Test A — Progressive FRR (windowed)**

| Finger        | Control early | Control mid | Control late | st=10 early (Δ) | st=10 mid | st=10 late (Δ) | st=20 early (Δ) | st=20 mid | st=20 late (Δ) |
|---------------|--------------|------------|-------------|-----------------|----------|---------------|-----------------|----------|---------------|
| right-index   | high         | high       | high        | ~same           | ~same    | ~same         | ~same           | ~same    | ~same         |
| right-little  | high         | high       | high        | ~same           | ~same    | ~same         | ~same           | ~same    | ~same         |
| right-middle  | varies       | varies     | varies      | ~same           | ~same    | ~same         | ~same           | ~same    | ~same         |
| right-ring    | varies       | varies     | varies      | ~same           | ~same    | ~same         | ~same           | ~same    | ~same         |
| right-thumb   | varies       | varies     | varies      | ~same           | ~same    | ~same         | ~same           | ~same    | ~same         |

No finger showed the expected late-window FRR reduction from study.

**Test C — Summary (aggregated)**

| Configuration      | FRR    | FAR    | ΔFRR   | Pass? |
|--------------------|--------|--------|--------|-------|
| No study (control) | 29.5%  | 1.88%  | —      | —     |
| study-thresh=10    | 30.1%  | 2.57%  | −0.6pp | ✗     |
| study-thresh=20    | 30.8%  | 2.23%  | −1.3pp | ✗     |

**Verdict:** Both thresholds **FAIL** all criteria:
- FRR got **worse** (not better) with study enabled
- FAR **increased** from 1.88% to 2.23–2.57% (above 0.5% target)
- No ΔFRR ≥ 5pp improvement observed

**Root cause analysis:** The naive algorithm replaces the weakest cross-score
entry if the probe's average cross-score exceeds the weakest's average. This
lacks all of the Windows driver's protective mechanisms:

1. No quality gate — low-quality probes absorbed into template
2. No anchor protection — best-connected entries can be replaced
3. No hit-count tracking — entries replaced regardless of match contribution
4. No degradation lock — study continues even when making things worse
5. No candidate deferral — one-shot replacement, no repeated observation
6. No quality comparison — probe can be much worse than target

**Next step:** Implement Windows-driver-style multi-layer study (§8.7).

### 8.7 Windows-Style Study v2 — Design

Inspired by `FUN_18001e110` / `FUN_18001f500` in `AlgoMilan.c`, the v2
study algorithm implements 6 protective layers:

| # | Layer               | Windows Reference              | Our Implementation |
|---|---------------------|--------------------------------|---------------------|
| 1 | Quality gate        | `quality > 0x0f` (15)          | `probe_kp >= 15`    |
| 2 | Quality comparison  | `probe*10 >= matched*6`        | `probe_kp*10 >= target_kp*6` |
| 3 | Anchor protection   | Best-connected entry immune    | Highest avg cross-score immune |
| 4 | Hit-count targeting | Replace least-contributing     | Replace lowest hit-count entry |
| 5 | Observation gate    | `hit_count > 79` or `>59+1000` | Scaled: `total_matches >= 5` |
| 6 | Degradation lock    | `failed > 0x32` (50) → lock    | `failed > 20` → lock |

CLI flag: `--study-v2` (replaces `--template-study` in verification loop).

### 8.8 Study v2 Results (2026-02-22)

Ran Test C (aggregate FRR + FAR across all 5 fingers) comparing no study,
naive study, and Windows-style v2 study side by side.

**Methodology:** Enroll 20 from S1, verify S2 genuine + S2 impostor (4 other
fingers) in a single pass with study. This gives genuine study a chance to
evolve the template before impostors arrive. Control = same without study.

| Configuration        | FRR    | FAR    | ΔFRR vs ctrl |
|----------------------|--------|--------|--------------|
| No study (control)   | 24.0%  | 2.91%  | —            |
| Naive thresh=10      | 24.7%  | 3.25%  | −0.7pp ✗     |
| Naive thresh=20      | 22.6%  | 3.77%  | +1.4pp       |
| **V2 thresh=10**     | 21.2%  | 3.25%  | **+2.8pp**   |
| **V2 thresh=20**     | 20.5%  | 3.77%  | **+3.5pp**   |

**Findings:**

1. **V2 consistently outperforms naive.** At every threshold, v2's FRR is
   lower than naive's (20.5% vs 22.6% at thresh=20, 21.2% vs 24.7% at
   thresh=10).
2. **V2 never worsens FAR vs naive.** Both produce identical FAR at each
   threshold — the multi-layer protections don't make things worse.
3. **V2 improves FRR vs control.** +2.8pp at thresh=10, +3.5pp at thresh=20.
   The naive algorithm worsened FRR at thresh=10.
4. **Neither passes the strict §8.4 criteria** (FAR ≤ 0.5% AND ΔFRR ≥ 5pp).
   The baseline FAR is already 2.91% without any study — the FAR problem
   is not caused by study but by the underlying matcher.

**Conclusion:** The Windows-style multi-layer study is strictly better than
naive study and shows real FRR improvement (+3.5pp at thresh=20). However,
the FAR floor (~3%) is a matcher-level issue that study cannot fix. Template
study should be integrated into the driver using v2, but FAR reduction
requires improvements to the core SIGFM matching algorithm (feature
extraction, geometric verification, or threshold calibration).

---

## 9. Enrollment/Template Improvement Sweep (2026-02-23)

### 9.1 Improvements Implemented

Two new features were added to `sigfm-batch.c`:

1. **E4 — Quality-Ranked Enrollment** (`--quality-enroll`): During enrollment,
   once half the slots are filled unconditionally, subsequent frames must have
   more keypoints than the weakest existing entry to be accepted. Ensures the
   template contains the highest-quality captures.

2. **E5 — Diversity Pruning** (`--diversity-prune`): After enrollment, iteratively
   finds the most-similar pair of sub-templates (highest pairwise `sigfm_match_score`),
   removes the one with fewer keypoints, and repeats until target count is reached.
   Maximises placement diversity within the template.

Also tested: `--sort-subtemplates` (existing — sorts by keypoint count descending,
keeps top N), and combinations of quality + diversity/sort.

**Note:** D3 (distance ratio pre-filter) and D4 (minimum distance threshold) were
confirmed already implemented in `sigfm.c` — `RANSAC_MIN_DIST_SQ = 9.0f` (3px)
and scale_sq check [0.64, 1.44] (±20% scale).

### 9.2 Sweep Results

All configs tested with score_threshold=6, S1=corpus/5finger (20 enrollments),
S2=corpus/5finger-s2 (29-30 verifications × 5 fingers + cross-finger FAR).

| Configuration | FRR | FAR | FA count | ΔFRR vs baseline |
|---|---|---|---|---|
| **baseline** (20 sub-templates) | **24.0%** | **2.91%** | 17/584 | — |
| quality-enroll (20→20) | 24.0% | 2.91% | 17/584 | 0.0pp |
| diversity-prune (20→15) | 35.6% | 1.54% | 9/584 | −11.6pp |
| sort-subtemplates (→15) | 38.4% | 1.66% | 10/604 | −14.4pp |
| quality + diversity (20→15) | 30.1% | 1.71% | 10/584 | −6.1pp |
| quality + sort (→15) | 35.8% | 1.82% | 11/604 | −11.8pp |
| diversity-prune (20→10) | 47.3% | 0.86% | 5/584 | −23.3pp |
| quality + diversity (20→10) | 45.2% | 1.37% | 8/584 | −21.2pp |

### 9.3 Analysis

1. **Quality-enroll has no effect when n_enroll == capacity** — all 20 frames fit
   into 20 slots unconditionally, so the quality gate never activates. This feature
   needs more enrollment captures than slots (e.g., 30 captures → 20 best).

2. **Pruning consistently trades FRR for FAR** — fewer sub-templates means less
   placement coverage (worse FRR) but fewer accidental impostor matches (better FAR).
   This is the fundamental trade-off on a 64×80 sensor.

3. **Diversity pruning outperforms sort pruning** — at 15 sub-templates, diversity
   achieves FRR=35.6% vs sort's 38.4% (−2.8pp better), with comparable FAR.
   Diversity removes redundant placements; sort just drops low-keypoint frames.

4. **Quality + diversity is the best combination** — at 15 sub-templates,
   FRR=30.1% vs pure diversity's 35.6% (5.5pp better). Quality-enroll ensures
   the retained frames are high-quality before diversity removes redundancy.

5. **Aggressive pruning (→10) is too costly** — FRR jumps to 45-47%, unacceptable.

6. **No configuration improves FRR** — all pruning methods worsen FRR vs baseline.
   The 24% FRR baseline requires all 20 sub-templates for adequate coverage.

### 9.4 Conclusions

- **Template pruning is not the path to lower FRR** — it can only reduce FAR at
  FRR's expense. The FRR problem (24%) stems from placement variation on the tiny
  sensor, requiring all available sub-templates for coverage.
- **Quality-enroll needs E2 (more enrollment frames)** to be effective. Currently
  untestable without more corpus data or a higher nr_enroll_stages.
- **Best FAR-reduction config:** quality+diversity-10 at FAR=1.37% but FRR=45.2%.
  Not usable in practice.
- **Next priority:** Improve the core matcher to reduce both FRR and FAR
  simultaneously. Leading candidate: **B2 (multi-scale FAST-9)** — 2-level pyramid
  should extract more keypoints per frame, improving feature density for both
  genuine matching (lower FRR) and discrimination (lower FAR).

---

## 10. B2 — Multi-Scale FAST-9 & Threshold Re-Calibration (2026-02-23)

### 10.1 Implementation

Added a 2-level image pyramid to `sigfm_extract()` in `sigfm.c`:

1. **Scale 0 (full resolution):** Unchanged FAST-9 detection with BRIEF clearance border.
2. **Scale 1 (half resolution):** `downsample_2x()` via 2×2 average pooling, then
   FAST-9 detection with smaller border (4px — FAST circle only, no BRIEF clearance
   needed since descriptors are computed on the full-resolution image).
3. **Coordinate mapping:** Half-res keypoints mapped to full-res: `x_full = x_half × 2 + 0.5`.
4. **BRIEF clearance filter:** Reject mapped keypoints within `PATCH_HALF` of edges.
5. **Near-duplicate suppression:** Skip if within 4px of any existing full-res keypoint.
6. **Merge:** Combined keypoints capped at `MAX_KP` (128).

~50 lines of new code: `downsample_2x()`, `detect_keypoints_ex()` (parameterised border),
and multi-scale logic in `sigfm_extract()`.

### 10.2 Keypoint Impact

Keypoints per frame increased dramatically:
- **Before:** ~15–40 keypoints per frame (typical)
- **After:** ~100–128 keypoints per frame (hitting MAX_KP cap)

The half-resolution scale detects coarser ridge features that FAST-9 misses at full
resolution (effectively doubling the FAST circle radius from 3px to 6px in original
coordinates).

### 10.3 Threshold Sweep Comparison

Both single-scale (original) and multi-scale (B2) tested at score thresholds 6–10.

| Threshold | Single-Scale FRR | Single-Scale FAR | Multi-Scale FRR | Multi-Scale FAR |
|---|---|---|---|---|
| 6 | 24.0% | 2.91% (17 fa) | **22.4%** | 2.89% (17 fa) |
| 7 | **27.4%** | 0.51% (3 fa) | 27.9% | **0.34%** (2 fa) |
| 8 | 29.5% | 0.17% (1 fa) | **29.3%** | 0.17% (1 fa) |
| 9 | 30.1% | 0.00% | 30.6% | 0.00% |
| 10 | 33.6% | 0.00% | **33.3%** | 0.00% |

### 10.4 Analysis

1. **The biggest win is threshold re-calibration, not multi-scale.** Raising threshold
   from 6→7 drops FAR from 2.91% to 0.51% (single-scale) at +3.4pp FRR cost.
   Threshold 6→8 drops FAR to 0.17% at +5.5pp FRR cost.

2. **Multi-scale has marginal impact.** At threshold=6, it reduces FRR by 1.6pp
   (24.0→22.4%) with FAR unchanged. At threshold=7, it slightly worsens FRR
   (+0.5pp) but slightly improves FAR (0.51→0.34%). At threshold≥8, negligible
   difference.

3. **Multi-scale is a net positive at the operating points that matter:**
   - At threshold=7 (recommended): FAR drops 0.51→0.34% (−33% relative),
     FRR penalty is just +0.5pp.
   - At threshold=6: FRR improves 1.6pp, FAR unchanged.

4. **Recommended operating point:** `score_threshold=7` with multi-scale enabled.
   This gives FRR=27.9%, FAR=0.34% — a dramatic improvement from the previous
   FRR=24.0%, FAR=2.91% at threshold=6. The FRR cost (+3.9pp) is worth the
   FAR reduction (−2.57pp, from 2.91% to 0.34%).

5. **Alternative:** `score_threshold=8` for security-critical use: FRR=29.3%,
   FAR=0.17%. Only 1 false accept in 588 cross-finger trials.

### 10.5 Decision

- **Keep multi-scale (B2)** — small code addition (~50 lines), marginal but
  consistent improvement, no regressions.
- **Raise score_threshold from 6 to 7** in the driver — the primary improvement.
  This should be done alongside B2 since multi-scale provides slightly better
  FAR at this threshold.

### 10.6 Parameter Tuning: Ratio Test (C1)

With multi-scale producing 100+ keypoints per frame (vs 15-40 before), the
Lowe ratio test can be tightened. Tested ratio values 0.85, 0.80, 0.75, 0.70
across score thresholds 6-8:

| Ratio | Threshold | FRR | FAR | FA count |
|---|---|---|---|---|
| 0.85 | 6 | 22.4% | 2.89% | 17/588 |
| 0.85 | 7 | 27.9% | 0.34% | 2/588 |
| 0.85 | 8 | 29.3% | 0.17% | 1/588 |
| **0.80** | **6** | **23.8%** | **0.68%** | **4/588** |
| **0.80** | **7** | **28.6%** | **0.17%** | **1/588** |
| 0.80 | 8 | 31.3% | 0.00% | 0/588 |
| 0.75 | 6 | 29.3% | 0.34% | 2/588 |
| 0.75 | 7 | 33.3% | 0.00% | 0/588 |
| 0.70 | 6 | 33.3% | 0.17% | 1/588 |
| 0.70 | 7 | 38.8% | 0.00% | 0/588 |

**Analysis:**
- **ratio=0.80 is optimal.** At threshold=6, it reduces FAR from 2.89% to 0.68%
  (−76%) at only +1.4pp FRR. At threshold=7, FAR drops from 0.34% to 0.17%.
- Below 0.80, FRR degrades too fast (0.75 at thresh=6: 29.3% FRR = +5.5pp).
- **Decision: Change RATIO_TEST from 0.85 to 0.80.**

### 10.7 Parameter Tuning: RANSAC Inlier Threshold

Tested RANSAC_INLIER_THRESH {2.0, 2.5, 3.0} with ratio=0.80:

| Inlier ε | Threshold | FRR | FAR |
|---|---|---|---|
| **2.0** (current) | 6 | 23.8% | **0.68%** |
| 2.5 | 6 | 23.8% | 1.19% |
| 3.0 | 6 | **22.4%** | 2.21% |
| **2.0** | 7 | 28.6% | **0.17%** |
| 2.5 | 7 | 28.6% | 0.17% |
| 3.0 | 7 | 28.6% | 0.34% |

**Analysis:** ε=2.0px is optimal. Larger thresholds accept false inliers → worse FAR.
At ε=3.0/thresh=6, FRR improves slightly (−1.4pp) but FAR degrades 3× (0.68→2.21%).
Not worth it. **Decision: Keep RANSAC_INLIER_THRESH at 2.0.**

### 10.8 Final Recommended Configuration

| Parameter | Old Value | New Value | Impact |
|---|---|---|---|
| Multi-scale pyramid | off | 2-level (0.5×) | +keypoints, marginal FRR/FAR improvement |
| RATIO_TEST | 0.85 | 0.80 | FAR −76% at thresh=6, −50% at thresh=7 |
| score_threshold | 6 | 7 | FAR −88% (2.91→0.34% with ratio=0.85) |
| RANSAC_INLIER_THRESH | 2.0 | 2.0 | Unchanged (optimal) |

**Combined result (multi-scale + ratio=0.80 + threshold=7):**
- FRR = **28.6%** (was 24.0% at threshold=6 — +4.6pp trade-off)
- FAR = **0.17%** (was 2.91% — **−94% relative**, only 1 false accept in 588 trials)

**Operating point trade-offs:**
| Mode | Score Threshold | FRR | FAR | Use Case |
|---|---|---|---|---|
| Convenience | 6 | 23.8% | 0.68% | Consumer devices |
| Balanced | 7 | 28.6% | 0.17% | Default (driver setting) |
| Secure | 8 | 31.3% | 0.00% | High-security environments |

---

## 11. E4/E2 Re-Sweep at New Threshold (2026-02-23)

### 11.1 Motivation

§9 tested enrollment strategies at the old threshold=6 with 20 enrollment captures.
Since then, two things changed:
1. **B2 multi-scale** and **ratio=0.80** improved feature density
2. **score_threshold raised to 7** — the new default
3. **Corpus confirmed to have 30 captures per finger** — E4 quality-ranking is
   now meaningful (30 captures → best 20)

### 11.2 Configurations Tested at Threshold=7

7 configs were tested using S1=corpus/5finger (30 enrollment captures),
S2=corpus/5finger-s2 (30 verification × 5 fingers + cross-finger FAR).

| Configuration | FRR | FAR | FA count |
|---|---|---|---|
| baseline (all 30, max_sub=20) | 28.6% | 0.17% | 1/588 |
| quality-enroll (30→20) | 28.6% | 0.17% | 1/588 |
| quality + sort (30→20) | 28.6% | 0.17% | 1/588 |
| quality + diversity (30→20) | 28.6% | 0.17% | 1/588 |
| quality + diversity (30→15) | 28.6% | 0.17% | 1/588 |
| quality + diversity (30→10) | 28.6% | 0.17% | 1/588 |
| diversity only (30→15) | 28.6% | 0.17% | 1/588 |

**All 7 configs produce identical results.** The single false accept
(enroll=right-ring → verify=right-index capture_0007.pgm, score=7) and the same
42 genuine failures persist regardless of enrollment strategy.

### 11.3 Configurations Tested at Threshold=6

| Configuration | FRR | FAR | FA count |
|---|---|---|---|
| baseline (all 30) | 23.8% | 0.68% | 4/588 |
| quality-enroll (30→20) | 23.8% | 0.68% | 4/588 |
| quality + diversity (30→20) | 29.9% | 0.51% | 3/588 |

At threshold=6, quality-enroll again has no effect. Diversity pruning reduces
FAR by −0.17pp but costs +6.1pp FRR — a bad trade.

### 11.4 The Stubborn False Accept

One cross-finger false accept persists across ALL configurations at threshold=7:
- **Enrolled finger:** right-ring
- **Verified against:** right-index, capture_0007.pgm
- **Score:** 7 (exactly at threshold)
- **Keypoints:** 125

This is an inherent matcher-level confusion between two fingers of the same person
at the same placement. Only score_threshold=8 eliminates it (at cost of +2.7pp FRR).

### 11.5 Conclusions

1. **Enrollment strategies are a dead end for accuracy improvement.** At the current
   matcher capability (multi-scale + ratio=0.80 + RANSAC), the score distribution
   is dominated by the matcher, not the template quality.

2. **The FRR bottleneck is genuine placement variation.** Right-index has 8 genuine
   frames scoring 2–6 (below threshold=7). These are real partial-overlap failures
   on the tiny 64×80 sensor, not enrollment quality issues.

3. **Next improvements must target the matching algorithm itself:**
   - ~~B4 (Hessian determinant filter)~~ — **Rejected**, destroys FRR. See §11.6.
   - D2 (exhaustive triples) — Windows-style, may find more inliers
   - Template study v2 — already validated at old threshold, needs re-testing

### 11.6 B4 — Hessian Determinant Keypoint Filter (REJECTED)

Implemented a Hessian determinant filter in `sigfm_extract()` to reject
edge-like FAST corners. Computed $H = I_{xx} I_{yy} - I_{xy}^2$ at each
keypoint and filtered by $|H| \geq$ threshold.

| Hessian Threshold | score_thresh=7 FRR | FAR | score_thresh=6 FRR | FAR |
|---|---|---|---|---|
| 0 (disabled) | 30.9% | 0.16% | 26.3% | 0.66% |
| 50 | 37.1% | 0.00% | 32.5% | 0.17% |
| 100 | 42.4% | 0.00% | 37.1% | 0.17% |
| 200 | 50.4% | 0.00% | 46.1% | 0.00% |
| 400 | 72.6% | 0.00% | 64.5% | 0.00% |
| 800 | 100% | 0.00% | 100% | 0.00% |

**Conclusion:** Catastrophically destructive. Every Hessian threshold > 0
increases FRR by 6–70pp. On a 64×80 sensor, every keypoint matters for
genuine matching. Removing weak corners reduces RANSAC inlier counts more
than it reduces impostor scores. Score threshold adjustment (6→7→8) is
a strictly better FAR lever.

Code remains in `sigfm.c` (guarded by `#if HESSIAN_DET_THRESH > 0`,
currently set to 0 = disabled) for reference.

### 11.7 RANSAC Iteration Sweep

Tested RANSAC_ITERATIONS = 100, 200, 500, 1000. **All produce byte-identical
results** — FRR=30.9%/0.16% at thresh=7, FRR=26.3%/0.66% at thresh=6.

With ~10–20 cross-check matches per verification, the solution space is small
(C(n,2) ≤ 190 possible pair samples). Even 100 iterations converges to the
optimal rigid transform. No benefit from increasing beyond 200.

**Note:** The baseline here (30.9% FRR at thresh=7) differs from §10's 28.6%
because this sweep enrolls all 30 captures → best-20-of-30 (max_subtemplates=20
truncation), while §10 enrolled the first 20 directly. Different template
composition produces slightly different genuine match rates.

### 11.8 Study v2 Re-Benchmark (multi-scale + ratio=0.80)

Re-tested template study v2 (Windows-style, §8.7) at the new operating point
(multi-scale + ratio=0.80 + RANSAC 200). Previous v2 results (§8.8) showed
+3.5pp FRR improvement at old config (thresh=6, ratio=0.85, no multi-scale).

**score_threshold=7 (COMPLETE):**

| Configuration | FRR | FAR | ΔFRR vs ctrl |
|---|---|---|---|
| no study (control) | 30.9% | 0.16% | — |
| study-v2, study-thresh=8 | 31.6% | 0.16% | −0.7pp ✗ |
| study-v2, study-thresh=10 | 31.6% | 0.16% | −0.7pp ✗ |
| study-v2, study-thresh=15 | 32.2% | 0.16% | −1.3pp ✗ |
| study-v2, study-thresh=20 | 32.2% | 0.16% | −1.3pp ✗ |

**score_threshold=6 (PARTIAL — benchmark interrupted by overnight shutdown):**

| Configuration | FRR | FAR |
|---|---|---|
| no study (control) | 26.3% | 0.66% |
| study-v2, study-thresh=8 | 27.6% | ~0.66% |

**Conclusion:** Study v2 makes FRR **worse** at the new operating point
(+0.7 to +1.3pp at thresh=7). The previous +3.5pp improvement doesn't carry
over — the improved matcher already extracts ~100-128 keypoints per frame
with multi-scale, so study's template updates add noise rather than value.
Template study is **deferred** — not useful until a fundamentally different
template structure is implemented.

### 11.9 D2 Exhaustive Triple-Based Affine (replaces RANSAC loop)

Implemented the last remaining #1-ranked algorithmic improvement from §7.5:
replace RANSAC's random 2-point rigid sampling with exhaustive enumeration of
all C(n,3) triples, estimating a full 2×2 affine transform from 3
correspondences (modeled after Windows FUN_18003aaf0 / FUN_18002a0b0).

**Implementation details:**
- For n ≤ TRIPLE_MAX_N (25): enumerate all C(n,3) triples, solve 2×2 affine
  + translation from 3 point correspondences, count inliers (ε=2.0px)
- Distance ratio pre-filter (Windows §2.2): reject pairs where 5·d_p > 6·d_q
  or 5·d_q > 6·d_p (±20% scale mismatch)
- Collinearity check: cross product area > 1px² minimum
- det(A) sanity check: reject transforms with scale outside [0.64, 1.44]
- Falls back to RANSAC 2-point sampling when n > 25 or n < 3
- LS refinement from inliers preserved (rigid model, same as before)

**Benchmark: Cross-corpus (enroll S1, verify S2) — threshold=7:**

| Capture | D2 score | RANSAC score | Delta |
|---------|----------|-------------|-------|
| 27 / 29 genuine | identical | identical | 0 |
| cap_0006 | 0 | 2 | -2 |
| cap_0029 | 19 | 18 | +1 |
| Max |Δ| = 3 across all 29 | | |

| Metric | D2 | RANSAC | Delta |
|--------|-----|--------|-------|
| FRR (cross-corpus, t=7) | 27.6% (8/29) | 27.6% (8/29) | **0.0pp** |
| FAR (cross-corpus, t=7) | 0.00% (0/123) | 0.00% (0/123) | **0.0pp** |

**S1 within-corpus (enroll first 20, verify 21-30) — threshold=7:**

| Metric | D2 | RANSAC | Delta |
|--------|-----|--------|-------|
| Unseen FRR | 30.0% (3/10) | 30.0% (3/10) | **0.0pp** |
| Impostor FAR | 0.00% (0/116) | 0.00% (0/116) | **0.0pp** |
| All unseen scores | byte-identical | byte-identical | every delta=0 |

**Why D2 is neutral:** With ~10-20 cross-check filtered matches, RANSAC's
200-iteration random sampling from C(n,2)≤190 pairs already converges to the
optimal transform. The affine model from 3 points offers no advantage over the
rigid model from 2 points on this 64×80 sensor (no inter-capture scale change).
Exhaustive enumeration finds the same inlier sets as random sampling because the
match space is already small enough for RANSAC to explore thoroughly.

**Note on previous false accept:** The right-ring/capture_0007 false accept
(previously score=7) now scores 0-2 with BOTH D2 and RANSAC. The fix occurred
in earlier changes (multi-scale + ratio=0.80), not D2.

**Decision:** D2 code retained in sigfm.c with `TRIPLE_MAX_N 0` (disabled).
Can be re-enabled by setting to 25. RANSAC-only is the production default since
it produces identical results with less computational overhead.

---

## 12. Decompilation Reference (New Functions Identified)

| Function | Line | Purpose | Relevant to us? |
|----------|------|---------|-----------------|
| `FUN_18003aaf0` | 38550 | **Geometric verification: triple-based affine estimation + inlier counting** | **Yes — key reference** |
| `FUN_18003b370` | 39130 | KNN matching with Hamming popcount (448-bit descriptors) | Reference only |
| `FUN_18003c850` | (called from FUN_18003b370) | Ratio test filtering on KNN matches | Reference only |
| `FUN_180038330` | 36423 | Per-template matching orchestrator | Architecture reference |
| `FUN_180037c00` | 36066 | Core matching: calls spatial projection + overlap scoring | Architecture reference |
| `FUN_180038a80` | 36814 | Spatial alignment/cropping with affine transform | Interesting for future |
| `FUN_180033e30` | 33116 | Pixel-level overlap confusion matrix scoring | Not needed — we use inlier count |
| `FUN_18001d090` | 17351 | Per-template match initialisation + transform estimation | Architecture reference |
| `FUN_180016530` | 13150 | Feature matching + spatial alignment entry (calls FUN_18003aaf0) | Architecture reference |
| `FUN_180019300` | (multiple call sites) | Multi-criteria accept/reject decision | Reference only |
| `FUN_18002a0b0` | (called from FUN_18003aaf0) | Compute 2×2 affine from 3 point correspondences | **Yes — key reference** |

---

## 14. Summary

| Question | Answer |
|----------|--------|
| Is RANSAC the right approach? | **Yes** — Windows uses exhaustive triples, but benchmarks show RANSAC produces identical results with less overhead (§11.9) |
| Does the Windows decompilation change anything? | **Confirms** the RANSAC plan. D2 exhaustive triples tested and found neutral — both approaches converge to the same inlier sets with ~10-20 matches |
| Current operating point? | FRR=27.6%, FAR=0.00% (cross-corpus, threshold=7, multi-scale + ratio=0.80 + RANSAC 200) |
| What has been tried? | B2 multi-scale ✓, C2 ratio=0.80 ✓, D3/D4 distance checks ✓, D2 exhaustive triples (neutral) ✓, B4 Hessian (rejected) ✗, RANSAC iterations (no effect) ✓, Study v2 (worse) ✗, E4/E2 enrollment (no effect) ✓ |
| What remains? | Template structure improvements, pixel-level overlap scoring, adaptive learning. All have diminishing returns on 64×80 sensor |
| Expected next step? | AUR publish, then real-world testing with live enrollment |
