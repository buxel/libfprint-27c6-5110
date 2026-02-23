# 18 — Benchmark Summary

**Date**: 2026-02-23  
**Sensor**: Goodix GF511 (27c6:5110), 64×80 px, 508 DPI, 3.2×4.0 mm  
**Matcher**: SIGFM — FAST-9 + BRIEF-256, pure C (~665 lines)  
**Corpus**: 5 right-hand fingers × 30 frames × 2 sessions = 300 raw captures

---

## Final Operating Point

| Metric | Value |
|--------|-------|
| FRR (per-attempt) | **27.6%** |
| FRR (5-retry effective) | **0.16%** |
| FAR (cross-corpus) | **0.00%** |
| Score threshold | 7 |
| Impostor max score | 6 |
| Genuine MATCH min score | 8 |
| Score gap | 2 units (clean separation) |

---

## Evolution of Key Metrics

| Phase | Change | FRR | FAR | Source |
|-------|--------|-----|-----|--------|
| Phase 10 — Baseline | Angle-counting geometric score | 13.7% | **45.7%** | [doc 14 §2](14-sigfm-benchmark-results.md) |
| Phase 11 — RANSAC | 2-point rigid transform, ε=2px, 200 iter | 42.1% | **0.00%** | [doc 14 §3](14-sigfm-benchmark-results.md) |
| Phase 11 — + cross-check | Mutual best-match filter | 42.1% | 0.00% | [doc 14 §4](14-sigfm-benchmark-results.md) |
| Phase 12a — Quality gate | Stddev ≥ 25 pre-filter | — | — | [doc 15 §7.2](15-advancement-strategy.md) |
| Phase 12b — Boost sweep | Boost 4 optimal; >4 kills FAR | — | — | [doc 15 §7.2](15-advancement-strategy.md) |
| Phase 12 (6.5) — Corrected bench | 20 enrollment, corrected methodology | 24.0% | 0.34% | [doc 14 §6.5](14-sigfm-benchmark-results.md) |
| B2 — Multi-scale pyramid | 2-level Gaussian pyramid, ~100→128 kp/frame | 22.4%→28.6% | 2.89%→0.17% | [doc 15 §10](15-advancement-strategy.md) |
| C2 — Ratio test 0.80 | Tightened from 0.85 (more discriminating) | 28.6% | 0.17% | [doc 15 §10.6](15-advancement-strategy.md) |
| Threshold 6→7 | Score threshold raised | 28.6% | 0.17% | [doc 15 §10.8](15-advancement-strategy.md) |
| **Final** | Multi-scale + ratio=0.80 + threshold=7 | **27.6%** | **0.00%** | [ACTION_PLAN.md](../ACTION_PLAN.md) |

---

## What Was Tried and Rejected

### Preprocessing (A)

| ID | Idea | Result | Detail |
|----|------|--------|--------|
| A6 | 12-bit working space | ❌ No improvement | FRR 29.8%→29.8% (intra), 28.6%→29.3% (cross). FAST-9/BRIEF are binary/threshold operators. [doc 15 §7.3](15-advancement-strategy.md) |
| A2+ | Boost >4 (6, 8) | ❌ FAR catastrophe | Impostor max 5→23→33. Fixed-pattern noise without factory cal. [doc 15 §7.2](15-advancement-strategy.md) |
| A8 | Frame averaging | ❌ Rejected | Noise is not the bottleneck; sensor area is. [doc 15 §7.3](15-advancement-strategy.md) |

### Feature Detection (B)

| ID | Idea | Result | Detail |
|----|------|--------|--------|
| B2 | Multi-scale FAST-9 | ✅ Adopted | 2-level pyramid, ~100→128 kp/frame. [doc 15 §10](15-advancement-strategy.md) |
| B4 | Hessian det filter | ❌ Destroys FRR | +6 to +70pp FRR. Every keypoint matters on 64×80. [doc 15 §11.6](15-advancement-strategy.md) |

### Matching / Descriptors (C)

| ID | Idea | Result | Detail |
|----|------|--------|--------|
| C2 | Ratio test sweep | ✅ 0.80 adopted | Tested 0.70–0.90. 0.80 optimal with multi-scale. [doc 15 §10.6](15-advancement-strategy.md) |
| C3 | Oriented BRIEF (ORB) | ❌ Hurt FAR | IC angle noisy on ridges; removed orientation as discriminator. [doc 14 §4](14-sigfm-benchmark-results.md) |
| C5 | Hamming distance ceiling | ❌ No effect | Ratio test already filters. [doc 14 §4](14-sigfm-benchmark-results.md) |
| C6 | Descriptor-weighted scoring | ❌ No separation | Both genuine/impostor inliers have similar per-match quality. [doc 14 §4](14-sigfm-benchmark-results.md) |
| C7 | Higher keypoints (FAST=5) | ❌ Marginal | +2 genuine median, +1 impostor max — not worth it. [doc 14 §4](14-sigfm-benchmark-results.md) |

### Geometric Verification (D)

| ID | Idea | Result | Detail |
|----|------|--------|--------|
| D1 | RANSAC inlier counting | ✅ Adopted | FAR 45.7%→0.0%. [doc 14 §3](14-sigfm-benchmark-results.md) |
| D2 | Exhaustive triples | ❌ Neutral | Byte-identical scores to RANSAC — solution space too small. [doc 15 §11.9](15-advancement-strategy.md) |
| D7 | Rotation constraint ±15–30° | ❌ Hurts genuine | Genuine placements vary more than expected. [doc 14 §4](14-sigfm-benchmark-results.md) |
| D8 | Translation constraint 20–30px | ❌ Hurts genuine | Genuine shifts are large on tiny sensor. [doc 14 §4](14-sigfm-benchmark-results.md) |
| D10 | Multi-criteria accept | ❌ Unnecessary | Clean score gap (FAIL max=5, MATCH min=8). No borderline cases. [ACTION_PLAN.md](../ACTION_PLAN.md) |
| D11 | Least-squares refinement | ✅ Adopted | Re-estimate transform from inliers. [doc 14 §4](14-sigfm-benchmark-results.md) |

### Enrollment / Templates (E)

| ID | Idea | Result | Detail |
|----|------|--------|--------|
| E1 | Template study v1 (naive) | ❌ FAR 43× worse | 0.34%→14.73%. Impostors absorbed into template. [doc 14 §6.4](14-sigfm-benchmark-results.md) |
| E1v2 | Template study v2 (Windows-style) | ❌ FRR worse | +0.7 to +1.3pp at thresh=7. Improved matcher makes study noise. [doc 15 §11.8](15-advancement-strategy.md) |
| E2 | More sub-templates (20→30) | ❌ No effect | 30 captures identical to 20 at thresh=7. [doc 15 §11](15-advancement-strategy.md) |
| E3 | Score-based sorting | ❌ FRR +8–21pp | Loses placement diversity. 28.6%→36.8%/43.4%/49.3%. [ACTION_PLAN.md](../ACTION_PLAN.md) |
| E4 | Quality-ranked insertion | ❌ No effect | All configs identical at thresh=7. [doc 15 §11](15-advancement-strategy.md) |
| E5 | Diversity pruning | ❌ Trades FRR for FAR | 24%→35.6% FRR, FAR improves but not worth it. [doc 15 §9](15-advancement-strategy.md) |
| E6 | Progressive enrollment | ❌ No-op or worse | 28.6%→32.0% when strict=120. Reordering hurts. [ACTION_PLAN.md](../ACTION_PLAN.md) |

### RANSAC Parameter Sweeps

| Parameter | Values Tested | Optimal | Detail |
|-----------|--------------|---------|--------|
| Iterations | 100, 200, 500, 1000 | 200 | All produce identical results — space too small. [doc 15 §11.7](15-advancement-strategy.md) |
| Inlier ε | 2.0, 2.5, 3.0 px | 2.0 | Larger ε accepts false inliers → worse FAR. [doc 15 §10.7](15-advancement-strategy.md) |
| Score threshold | 2–40 | 7 | Full tradeoff table in [doc 14 §3](14-sigfm-benchmark-results.md) and [doc 15 §10](15-advancement-strategy.md) |
| Ratio test | 0.70, 0.75, 0.80, 0.85, 0.90 | 0.80 | Below 0.80 FRR degrades too fast. [doc 15 §10.6](15-advancement-strategy.md) |

---

## Score Distribution at Final Config

```
Genuine matches:   score 8–47, median ~12
Genuine failures:  score 0–6
Impostor max:      6 (at threshold=7, FAR=0.00%)
                   5 (at threshold=6, FAR=0.17%)
```

The 42 genuine failures (27.6% FRR) are all placement mismatches — the finger
was placed differently enough that only 0–6 RANSAC inliers survive. This is a
physical constraint of the 3.2×4.0 mm sensor, not recoverable by algorithm.

---

## Fundamental Constraints

1. **64×80 px / 3.2×4.0 mm sensor area** — ~30–128 FAST keypoints per frame.
   Small shifts move keypoints to edges where they're lost.
2. **BRIEF-256 rotation sensitivity** — unsteered descriptors flip ~20% of bits
   at >10° rotation. Adding steering (ORB) was tested and hurt discrimination.
3. **Same-hand finger similarity** — at 508 DPI on 64×80, different fingers share
   ridge spacing/texture. BRIEF in the 3–5 inlier range is genuine ridge similarity.
4. **No factory calibration** — boost >4 amplifies fixed-pattern noise without
   per-pixel kr/b correction (A3 blocked — USB calibration command unknown).

---

## What Could Still Help (blocked or high-effort)

| ID | Idea | Blocker |
|----|------|---------|
| A3 | Per-pixel factory calibration | USB command to read ~140KB cal blob unknown |
| — | Alternative feature detectors (ORB, AKAZE) | Significant rewrite |
| — | Minutiae-based matching (Windows approach) | ~1000+ lines, ridge orientation, thinning |
