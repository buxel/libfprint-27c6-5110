# 14 — SIGFM Benchmark Results (5-Finger Corpus)

**Date**: 2026-02-22  
**Corpus**: `corpus/5finger/` — 5 right-hand fingers, ~30 captures each  
**Matcher**: SIGFM (FAST-9 + BRIEF-256, ratio test 0.90, unblurred, NMS strict `>`)  
**Preprocessing**: percentile stretch (P0.1–P99) + unsharp mask (boost=4)  
**Enrollment**: 10 frames per finger, remaining used for verification  
**Score threshold**: 40 (default)

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

---

## 2. Genuine Match Test (FRR) — Per Finger

| Finger        | Verified | Matched | Rejected | FRR   | Score Range     | Mean Score |
|---------------|----------|---------|----------|-------|-----------------|------------|
| right-thumb   |       20 |      20 |        0 |  0.0% | 40–204,663      |     21,933 |
| right-index   |       19 |      16 |        3 | 15.8% | 23–82,219       |      6,624 |
| right-middle  |       20 |      13 |        7 | 35.0% | 0–15,531        |      1,147 |
| right-ring    |       18 |      15 |        3 | 16.7% | 1–734,753       |     61,943 |
| right-little  |       18 |      18 |        0 |  0.0% | 53–194,216      |     29,935 |
| **Overall**   |   **95** |  **82** |   **13** |**13.7%**|               |            |

### Observations
- **Thumb & little finger**: 0% FRR — excellent
- **Index & ring**: ~16% FRR — moderate, some captures near threshold boundary
- **Middle finger**: 35% FRR — worst performer, likely partial placements or rotation

---

## 3. Impostor Test (FAR) — Cross-Finger

Every finger enrolled against itself (first 10 frames), then verified against ALL
captures from every OTHER finger. Any match = false accept.

| Enrolled      | vs Index | vs Little | vs Middle | vs Ring | vs Thumb |
|---------------|----------|-----------|-----------|---------|----------|
| right-index   | —        | 12/28     | 13/30     | 15/28   | 9/30     |
| right-little  | 15/29    | —         | 18/30     | 19/28   | 10/30    |
| right-middle  | 13/29    | 17/28     | —         | 12/28   | 3/30     |
| right-ring    | 18/29    | 17/28     | 19/30     | —       | 16/30    |
| right-thumb   | 13/29    | 9/28      | 9/30      | 8/28    | —        |

**Total impostor attempts: 580**  
**False accepts: 265**  
**FAR: 45.7%** at threshold=40

### This is unacceptable. The matcher cannot discriminate between different fingers of the same person at this threshold.

---

## 4. Score Distribution Analysis

### Genuine scores (95 samples)
```
Min: 0  P5: 5  P10: 25  P25: 81  Median: 352  P75: 7,274  Max: 734,753
```

### Impostor scores (580 samples)
```
Min: 0  P25: 16  Median: 35  P75: 82  P90: 173  P95: 252  P99: 568  Max: 991
```

### FRR/FAR Tradeoff Table

| Threshold | FRR    | FAR    |
|-----------|--------|--------|
|        10 |  5.3%  | 82.8%  |
|        20 |  6.3%  | 70.2%  |
|        30 | 10.5%  | 56.0%  |
|        40 | 13.7%  | 45.7%  |
|        50 | 15.8%  | 39.5%  |
|        75 | 22.1%  | 27.6%  |
|       100 | 28.4%  | 20.0%  |
|       150 | 33.7%  | 12.4%  |
|       200 | 36.8%  |  7.9%  |
|       300 | 45.3%  |  2.9%  |
|       400 | 51.6%  |  1.9%  |
|       500 | 53.7%  |  1.0%  |

### To achieve FAR=0%
- Threshold must be > 991 (max impostor score)
- FRR at that threshold: **58.9%**

### EER (Equal Error Rate)
- EER is approximately at threshold ~75, where FRR ≈ 22% and FAR ≈ 28%
- This is a very poor EER — typical fingerprint systems achieve EER < 1%

---

## 5. Diagnosis

The fundamental problem: **genuine and impostor score distributions overlap heavily**.

- Genuine median: 352
- Impostor P75: 82, P95: 252, max: 991

The overlap zone spans from ~5 to ~991. There is no threshold that achieves
both low FRR and low FAR.

### Root Causes (code-level)

The matcher (`sigfm.c`) has three stages: (1) KNN match with ratio test,
(2) pairwise angle/length consistency, (3) count agreeing angle-pairs.
All three contribute to the FAR problem.

1. **Ratio test at 0.90 is too permissive** (`RATIO_TEST 0.90f`, line ~260).
   Phase 8 raised this from 0.75 to fix FRR. But at 0.90, most descriptor
   matches pass — including ambiguous ones that correlate with any finger.
   With 128 keypoints per image, even random images produce 10–30 matches
   after ratio test, which then feed into the geometric scorer.

2. **`geometric_score()` uses pairwise angle-counting, not RANSAC** (line ~321).
   It counts how many *pairs of angle-entries* agree within `ANGLE_MATCH=0.05`
   (5%) tolerance. Angle-entries are O(n²) in the number of matches, and
   agreeing pairs are O(n⁴). Even with 10 random matches, O(100) angle-entries
   are formed, and some fraction agree by chance — producing scores of 50–991
   for impostors. This is *not* a genuine geometric transform check.

3. **No rigid transform estimation**. A true RANSAC approach would estimate
   a translation+rotation from match pairs and count inliers — matches whose
   transformed positions agree within a pixel tolerance. Random matches
   almost never form a coherent rigid transform, which would cleanly separate
   genuine from impostor.

4. **Small sensor area (64×80 px)** exacerbates the problem. Same person's
   fingers share similar skin texture & ridge spacing. But proper geometric
   verification would still discriminate — ridge patterns differ in spatial
   layout even between adjacent fingers.

### Why the deferred ACTION_PLAN items don't help

None of the deferred improvements from doc 13 (Windows driver analysis)
address the FAR problem. They all target FRR or image quality:

| # | Deferred Item              | Helps FAR? | Why not |
|---|----------------------------|-----------|--------------------------------------------|
| 1 | Adaptive template learning | No        | Improves FRR. Doesn't change scoring algo. |
| 2 | Factory calibration        | Marginal  | Better images, but keypoints already fine.  |
| 3 | Boost factor 4→10          | No        | More contrast ≠ better discrimination.      |
| 4 | Quality/coverage gating    | No        | Rejects bad captures. Impostors have plenty of keypoints. |
| 5 | Hessian feature detection   | No        | Different detector, same broken scorer.     |
| 6 | Sub-template sorting       | No        | Organizational only.                       |
| — | Match retry                | No        | FRR only.                                  |

### Required improvements (new work — see ACTION_PLAN Phase 11)

1. **Replace `geometric_score()` with RANSAC-based inlier counting**.
   Estimate rigid transform (translation + rotation) from 2-point samples.
   Count inliers — matches whose transformed position agrees within
   2–3 px. Score = inlier count. This is the single most impactful change.

2. **Lower ratio test** from 0.90 back toward 0.80. RANSAC inlier counting
   tolerates fewer but cleaner matches far better than the current approach.

3. **Score = inlier count, not pairwise angle agreements**. This produces
   compact, interpretable scores (0–128) where genuine typically gets 15–50
   inliers and impostor gets 0–2.

4. Optional: **oriented BRIEF (ORB-style)** to add rotation invariance,
   reducing FRR from finger placement variation without hurting FAR.

Estimated scope: ~150 lines of C replacing `geometric_score()` + constant
tuning. No API changes, no serialisation changes.

---

## Test Commands

```bash
# Genuine match (FRR) + Impostor (FAR) full test:
./tools/benchmark/run-tests.sh corpus/5finger 40

# Score distribution analysis:
./tools/benchmark/score-analysis.sh corpus/5finger

# Single finger test:
./tools/benchmark/sigfm-batch \
    --enroll corpus/5finger/right-thumb/capture_000{1..9}.pgm \
               corpus/5finger/right-thumb/capture_0010.pgm \
    --verify corpus/5finger/right-thumb/capture_00{11..30}.pgm \
    --score-threshold=40
```
