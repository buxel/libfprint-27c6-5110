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

## 7. Post-RANSAC Prioritisation

After RANSAC achieves acceptable FAR/FRR, the priority order for remaining
improvements is:

1. **AUR publish** (Phase 9) — the primary goal; everything below is optional
2. **Adaptive template learning** (doc 13 §3) — most impactful for long-term UX
3. **Quality/coverage gating** (doc 13 §6) — easy, improves rejection of bad captures
4. **Oriented BRIEF** — reduces FRR from rotated placements
5. **Boost factor increase** — minor, only with calibration
6. **Factory calibration** — blocked on unknown retrieval command; nice-to-have
7. **Hessian detector** — hard, only if FAST-9 proves insufficient

---

## 8. Decompilation Reference (New Functions Identified)

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

## 9. Summary

| Question | Answer |
|----------|--------|
| Is RANSAC the right approach? | **Yes** — Windows uses the same principle (inlier counting after transform estimation), just with exhaustive triples instead of random sampling |
| Does the Windows decompilation change anything? | **Confirms and strengthens** the RANSAC plan. The Windows driver's geometric verification is functionally equivalent to RANSAC but uses exhaustive triples. Both approaches count inliers after estimating a spatial transform. |
| What order should changes be made? | 1. Replace `geometric_score()` → RANSAC, 2. Lower ratio test 0.90→0.80, 3. Re-calibrate threshold, 4. Validate |
| Any Windows features we should adopt? | Distance ratio pre-filter (5:6 bounds) and minimum distance threshold — both are cheap sanity checks |
| Expected outcome? | FAR from 45.7% to <1%, EER from 25% to <3% |
| Scope? | ~80 lines of C, ~2 hours work |
| What comes after? | AUR publish, then adaptive template learning |
