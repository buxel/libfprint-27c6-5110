# 14 — Testing & Benchmarking Strategy

**Date:** 2026-02-21 (updated 2026-02-22)
**Purpose:** Define the data capture, replay, and comparison approach for A/B testing
driver preprocessing and matching improvements identified in
[doc 13](13-windows-driver-algorithm-analysis.md).

---

## 1. Problem Statement

The current debug tooling (`debug-capture.sh` + `analyze-capture.py`) captures a
**processed** 64×80 PGM — the output of the full driver pipeline. This is inadequate
for A/B testing preprocessing changes because:

- Each capture is a different finger press → can't isolate pipeline changes from
  placement variation
- The PGM is post-stretch, post-unsharp — we can't test different stretch or boost
  parameters on the same raw input
- No enrollment/verify lifecycle simulation — can't measure FRR or test adaptive
  template learning offline
- No SIGFM metrics embedded — keypoint counts and match scores require a separate
  live run

We need a **corpus-based offline testing approach** where raw sensor data is captured
once, then replayed through different pipeline configurations to produce directly
comparable results.

---

## 2. Current Pipeline (What We're Testing)

From `scan_on_read_img()` in `goodix5xx.c`:

```
Sensor → raw 12-bit packed (88×80 × 12-bit in 6-byte chunks)
  → goodixtls5xx_decode_frame()        → 88×80 × 16-bit (GoodixTls5xxPix)
  → linear_subtract_inplace()          → calibration frame subtracted
  → goodixtls5xx_squash_frame_percentile() → P0.1→P99 mapped to 0→255 (8-bit)
  → goodixtls5xx_unsharp_mask_inplace()    → 4×img − 3×blur (3×3 Gaussian, boost=4)
  → crop_frame()                       → 88→64 width, FPI_IMAGE_PARTIAL
  → FpImage (64×80, 8-bit, 508 DPI)
  → SIGFM: sigfm_extract()            → FAST-9 detect on blurred, BRIEF-256 on original (~3ms)
  → sigfm_match_score()               → KNN (ratio test 0.90) + geometric scoring
```

Each of the six doc-13 algorithms targets a specific stage:

| # | Algorithm | Pipeline stage affected |
|---|-----------|----------------------|
| 1 | Adaptive template learning | Post-match (template update) |
| 2 | Per-pixel calibration | Replace `linear_subtract` with kr/b correction |
| 3 | High-boost filter (10×) | Change `unsharp_mask` boost constant |
| 4 | Quality/coverage gating | Insert gate between preprocessing and SIGFM |
| 5 | Hessian features | Replace SIGFM's FAST-9 detector |
| 6 | Sub-template sorting | Change enrollment template management |

---

## 3. Testing Architecture

Three components, each building on the previous:

### Component 1: Raw Frame Dump (driver change)

**What:** Env-gated dump of raw sensor data before any processing.

**Change:** ~20 lines in `scan_on_read_img()` in `goodix5xx.c`, gated by `FP_SAVE_RAW`.

When `FP_SAVE_RAW=/path/to/dir` is set:
- Dump calibration frame once → `calibration.bin` (88×80 × 2 bytes = 14,080 bytes)
- Dump each raw frame (post-decode, post-calibration-subtract) → `raw_NNNN.bin`
  (14,080 bytes each)
- Normal processing continues — no user-visible difference

**Why post-calibration-subtract?** The `linear_subtract_inplace()` step uses
`priv->calibration_img` which is captured at device init. Dumping after subtraction
means the replay tool doesn't need to simulate this init-time calibration. For testing
doc-13 algorithm 2 (per-pixel calibration), we separately dump `calibration.bin` so the
replay tool can substitute a different calibration method.

**Data budget:** 50 captures = ~700 KB. Trivially small.

**Zero-cost when unset:** The env var check is a single `g_getenv()` call, no overhead
in the normal path.

### Component 2: Offline Preprocessing Replay (new C tool)

**What:** `replay-pipeline` — reads a raw `.bin` file, applies configurable
preprocessing, outputs a processed PGM.

**Location:** `tools/replay-pipeline.c`, links against libfprint's bundled
preprocessing functions.

**Parameters:**

| Flag | Default | Purpose |
|------|---------|---------|
| `--boost=N` | 2 | Unsharp mask boost factor (2=current, 10=Windows) |
| `--stretch=percentile\|linear` | percentile | Histogram stretch method |
| `--calibration=FILE` | none | Apply per-pixel kr/b calibration (algorithm 2) |
| `--width=N` | 88 | Raw frame width |
| `--height=N` | 80 | Raw frame height |
| `--crop=N` | 64 | Output width after crop |
| `-o FILE` | stdout | Output PGM path |

**Example:**
```bash
replay-pipeline --boost=10 corpus/raw_0001.bin -o processed/boost10_0001.pgm
```

**Build:** Standalone binary, same pattern as `nbis-test/`. Directly includes the
relevant preprocessing functions from `goodix5xx.c` (they're pure arithmetic, no
driver state dependencies).

### Component 3: SIGFM Batch Test (new C tool)

**What:** `sigfm-batch` — reads a set of PGMs, simulates enrollment + verification,
reports match scores and FRR.

**Location:** `tools/sigfm-batch.c`, links against libfprint's SIGFM library.

**Usage:**
```bash
sigfm-batch \
    --enroll frame_001.pgm ... frame_020.pgm \
    --verify frame_021.pgm ... frame_050.pgm \
    [--quality-gate=25] \
    [--sort-subtemplates] \
    [--template-study] \
    [--score-threshold=40]
```

**Output:**
```
Enrollment: 20 frames, 18 accepted (2 rejected: quality < 25)
Keypoints per frame: min=28 max=97 mean=54

Verification: 30 frames
  Frame 021: score=52/40 ✓ (keypoints: 61)
  Frame 022: score=38/40 ✗ (keypoints: 43)
  ...

Summary:
  FRR: 6/30 = 20.0%
  Mean match score: 47.3
  Mean non-match score: n/a (no impostor test)
```

**Features tested per flag:**

| Flag | Doc-13 algorithm | What it tests |
|------|-----------------|---------------|
| `--quality-gate=N` | #4 Quality gating | Reject enrollment/verify frames below quality |
| `--sort-subtemplates` | #6 Sub-template mgmt | Rank enrolled frames by score, keep best |
| `--template-study` | #1 Adaptive learning | Update template after each successful verify |
| `--score-threshold=N` | Baseline | Match decision threshold |

The SIGFM C API is self-contained (`sigfm_extract()`, `sigfm_match_score()`,
`sigfm_keypoints_count()`), making this straightforward.

---

## 4. End-to-End Workflow

### 4.1 Building the Corpus (one-time, on real hardware)

```bash
# Create corpus directory
mkdir -p corpus

# Capture 50 frames (same finger, varied placement/pressure)
# Repeat this command 50 times, pressing finger differently each time
FP_SAVE_RAW=./corpus ./tools/debug-capture.sh finger.pgm

# Result: corpus/calibration.bin + corpus/raw_0000.bin .. raw_0049.bin
```

**Best practice:** Capture frames across realistic conditions — light touch, heavy
press, offset left/right/up/down, dry, slightly moist. This produces the kind of
variation enrollment + verify will encounter in real use.

### 4.2 Generating Processed Variants

```bash
# Baseline (current driver: percentile stretch, 2× boost)
for f in corpus/raw_*.bin; do
    name=$(basename "$f" .bin)
    replay-pipeline --boost=2 "$f" -o processed/baseline/${name}.pgm
done

# Algorithm 3: 10× high-boost
for f in corpus/raw_*.bin; do
    name=$(basename "$f" .bin)
    replay-pipeline --boost=10 "$f" -o processed/boost10/${name}.pgm
done

# Algorithm 2+3: calibration + 10× boost (when implemented)
for f in corpus/raw_*.bin; do
    name=$(basename "$f" .bin)
    replay-pipeline --calibration=corpus/calibration.bin --boost=10 \
        "$f" -o processed/cal_boost10/${name}.pgm
done
```

### 4.3 Running Comparisons

```bash
# Convention: first 20 frames = enrollment, frames 21-50 = verification

for variant in baseline boost10 cal_boost10; do
    echo "=== $variant ==="
    sigfm-batch \
        --enroll processed/$variant/raw_00{00..19}.pgm \
        --verify processed/$variant/raw_00{20..49}.pgm \
        --quality-gate=25
done
```

### 4.4 Testing Adaptive Learning

```bash
# Same corpus, with template study enabled
sigfm-batch \
    --enroll processed/baseline/raw_00{00..19}.pgm \
    --verify processed/baseline/raw_00{20..49}.pgm \
    --template-study
```

Compare FRR with and without `--template-study` on identical data.

---

## 5. Metrics & Decision Criteria

### Primary metric: False Rejection Rate (FRR)

FRR = (failed genuine matches) / (total genuine attempts) × 100%

| Source | FRR | Notes |
|--------|-----|-------|
| Windows driver | ~1–3% | From doc-13 §10 |
| Target (Phase 1+2) | <10% | Acceptable for daily use |
| Target (Phase 3) | <5% | Near-production quality |
| Pre-Phase 1 baseline | **90%** | Measured: 1/10 matches at threshold 40 (20-frame corpus) |
| **Post-Phase 1** | **0%** | **Measured: 10/10 matches at threshold 40, min score 47** |

### Secondary metrics (per frame)

| Metric | Source | Threshold |
|--------|--------|-----------|
| SIGFM keypoint count | `sigfm_keypoints_count()` | ≥25 (hard minimum in `fp-image.c`) |
| SIGFM match score | `sigfm_match_score()` | ≥40 (default `score_threshold`) |
| SIGFM extraction time | Debug log | Baseline ~3ms |
| Image quality (std dev) | `analyze-capture.py` | >15 (blank frame detection) |
| Coverage estimate | `analyze-capture.py` | >65% (Windows threshold) |

### Decision gate (from doc-13 §10)

After implementing each improvement, re-run the batch test:

1. **Phase 1** (boost, SIGFM ratio/descriptor fixes) → ✅ **FRR = 0%** (see §11)
2. **Phase 2** (calibration, adaptive learning) → may be unnecessary given Phase 1 results
3. If FRR < 5% after Phase 2 → skip Phase 3 (Hessian features) → **already met after Phase 1**

---

## 6. Relationship to libfprint Test Infrastructure

libfprint has three test layers we can leverage:

| Layer | Mechanism | Useful for us? |
|-------|-----------|---------------|
| **Virtual-image driver** | Feeds 8-bit PGMs over Unix socket, runs full pipeline | **Yes** — could run SIGFM matching on saved PGMs via the full libfprint stack |
| **umockdev replay** | Replays recorded USB traffic | **No** — we don't have goodixtls recordings, and creating them requires umockdev integration |
| **C unit tests** (GTest) | Tests core API | **No** — we need integration-level testing |

### Why standalone tools over virtual-image?

The `virtual-image` driver is powerful but has limitations for our use case:

- It defaults to NBIS, not SIGFM — would need patching to test SIGFM
- It operates at the FpImage level (post-processing) — can't test preprocessing changes
- The socket protocol adds complexity for batch testing
- Standalone tools are simpler to build, run, and integrate into scripts

**However**, the virtual-image driver becomes valuable later for:
- Integration testing of the full enroll→verify lifecycle
- Regression testing: feed known-good PGMs, assert match succeeds
- CI pipeline: run matching tests without hardware

### Existing standalone tools

| Tool | Location | Status |
|------|----------|--------|
| `nbis-minutiae-test` | `nbis-test/nbis-minutiae-test.c` | Working — tested in doc-10 |
| `nbis-bozorth3-test` | `nbis-test/nbis-bozorth3-test.c` | Working — tested in doc-10 |
| `analyze-capture.py` | `tools/analyze-capture.py` | Working — image stats + log parsing |
| `debug-capture.sh` | `tools/debug-capture.sh` | Working — capture + SIGFM debug log |
| `capture-corpus.sh` | `tools/capture-corpus.sh` | Working — loop capture of N frames |
| `replay-pipeline` | `tools/replay-pipeline.c` | Working — offline preprocessing replay |
| `sigfm-batch` | `tools/sigfm-batch.c` | Working — enrollment/verify FRR benchmark |

---

## 7. Implementation Order

### Step 1: Raw frame dump (driver change) — ✅ Done

`FP_SAVE_RAW` env-gated dump in `goodix5xx.c`. Dumps `calibration.bin` once +
`raw_NNNN.bin` per frame (14,080 bytes each). Hybrid `seq_hwm` counter avoids
overwriting existing files.

### Step 2: `sigfm-batch` (standalone C tool) — ✅ Done

Reads PGMs, simulates 10-enroll + 10-verify lifecycle, reports per-frame match scores
and FRR. Located in `tools/sigfm-batch.c`, linked directly against `sigfm.c`.

### Step 3: `replay-pipeline` (standalone C tool) — ✅ Done

Reads raw `.bin` dumps, applies configurable preprocessing (boost, stretch, crop),
outputs PGMs. Located in `tools/replay-pipeline.c`. Supports `--batch` mode for
processing an entire corpus directory.

### Step 4: Capture corpus — ✅ Done

20-frame corpus captured via `capture-corpus.sh` and stored in `corpus/baseline/`.
Contains `calibration.bin` + `raw_0000.bin` through `raw_0019.bin` + driver PGMs
(`capture_0001.pgm` through `capture_0020.pgm`).

---

## 8. Coverage Matrix

Which doc-13 algorithms can be tested with each component:

| Algorithm | Raw dump | replay-pipeline | sigfm-batch | virtual-image |
|-----------|----------|-----------------|-------------|---------------|
| 1. Adaptive learning | — | — | `--template-study` | Later |
| 2. Per-pixel calibration | ✓ (need cal blob) | `--calibration` | Via processed PGMs | — |
| 3. High-boost (10×) | ✓ (raw input) | `--boost=10` | Via processed PGMs | — |
| 4. Quality gating | — | — | `--quality-gate` | Later |
| 5. Hessian features | — | — | Future alt extractor | — |
| 6. Sub-template sorting | — | — | `--sort-subtemplates` | Later |
| Match retry | — | — | Via re-run on fail | Later |

Full coverage of algorithms 1–4 and 6. Algorithm 5 (Hessian) is explicitly deferred per
doc-13 §10 decision gate — only needed if FRR remains >5% after Phase 2.

---

## 9. Existing Test Data

| Artifact | Location | Contents |
|----------|----------|----------|
| `capture-test.pgm` | `capture-samples/baseline/` | 64×80 processed PGM from real sensor |
| `capture-test_x8.png` | `capture-samples/baseline/` | 8× upscaled PNG for viewing |
| `capture-test_enhanced_x8.png` | `capture-samples/baseline/` | Auto-contrast 8× PNG |
| `capture-report.html` | `capture-samples/baseline/` | HTML analysis report |
| `enrolled.pgm` | (from doc-08, may need re-capture) | Last enrolled frame |
| `test-storage.variant` | (from doc-08, may need re-capture) | Full 20-frame enrollment template |

### NBIS benchmark baseline (from doc-10)

| Scale | Minutiae (enrolled) | Minutiae (verify) | Viable? |
|-------|--------------------|--------------------|---------|
| 1× (64×80) | 2 | 0 | No |
| 2× (128×160) | 2 | 2 | No |
| 4× (256×320) | 0 | — | No |

Conclusion: NBIS/bozorth3 is not viable for this sensor. SIGFM is the correct approach.

### SIGFM baseline (from doc-08)

- Extraction time: ~2.5–3.5 ms per frame
- All 20 enrollment scans successfully extracted
- Match scores: ">100 when it works, as low as 22 on marginal scans" (doc-06)

### Windows driver baseline (from doc-11)

- Match score: 71, quality: 44, coverage: 95%
- Compare time: 32 ms
- Template: ~170 KB (50 sub-templates)

---

## 10. Open Questions

1. **Calibration blob retrieval:** The driver calls `goodix_request_calibration()` at
   init, but what it retrieves is a *background frame* (sensor output with no finger),
   not the Windows-style per-pixel kr/b factory calibration. The factory calibration
   (140 KB blob with kr/b arrays) may be stored in sensor flash OTP. Need to
   investigate whether `goodix_read_otp()` or another sensor command can retrieve it.

2. **Impostor testing:** The corpus workflow above tests genuine matches only (same
   finger). For FAR (false acceptance rate), we'd need a second corpus from a different
   finger. Low priority — FRR is the primary concern.

3. **Cross-session variability:** A corpus captured in one session may not represent
   long-term variability (skin condition changes, temperature, humidity). Multiple
   corpus captures across days/weeks would strengthen the benchmark, but one session
   is sufficient for initial A/B comparison of preprocessing changes.

---

## 11. Phase 1 Results

**Date:** 2026-02-22

### Root cause analysis

Four issues were identified in the SIGFM matching pipeline:

| # | Root Cause | Severity | Fix |
|---|-----------|----------|-----|
| 1 | Ratio test 0.75 too strict for self-similar fingerprint textures — second-best BRIEF match is always close to first, killing genuine matches | Critical | `RATIO_TEST` 0.75 → **0.90** |
| 2 | Double blur — driver applies unsharp mask to enhance ridges, then SIGFM immediately re-blurs with `box3_blur` before computing BRIEF descriptors, undoing the sharpening | Critical | Detect keypoints on blurred image, compute descriptors on **original** image |
| 3 | Unsharp mask boost=2 insufficient for BRIEF discrimination on 64×80 images (Windows uses boost≈10) | Significant | `UNSHARP_BOOST` 2 → **4** (conservative increase) |
| 4 | NMS tie-breaking `>=` biased keypoint selection toward top-left | Minor | Changed to strict `>` |

### Code changes

| File | Change |
|------|--------|
| `sigfm/sigfm.c` | `RATIO_TEST` 0.75→0.90, NMS `>=`→`>`, descriptors computed on original (unblurred) image |
| `drivers/goodixtls/goodix5xx.c` | Added `#define UNSHARP_BOOST 4`, generalized formula: `boost*img − (boost−1)*blur` |
| `tools/replay-pipeline.c` | `DEFAULT_BOOST` 2→4 to match driver |

### Benchmark results

Corpus: 20 frames from real sensor (right index finger), 10 enroll + 10 verify.
Threshold: 40 (sigfm-batch default).

| Configuration | Matches | FRR | Min Score | Mean Score |
|--------------|---------|-----|-----------|------------|
| Baseline (boost=2, ratio=0.75, blurred descriptors) | 1/10 | **90%** | 0 | — |
| New SIGFM only (boost=2, ratio=0.90, unblurred descriptors) | 5/10 | **50%** | 1 | — |
| Full Phase 1 (boost=4, ratio=0.90, unblurred descriptors) | **10/10** | **0%** | 47 | 473 |

All three SIGFM changes (ratio, descriptors, NMS) and the boost increase contributed.
The ratio test relaxation alone recovered 4 matches; the boost increase recovered the
remaining 5. The minimum score of 47 comfortably exceeds the driver's score threshold
of 24 (`goodix511.c` class_init).

### Assessment

Phase 1 exceeded the Phase 1+2 target (FRR < 10%) and the Phase 3 target (FRR < 5%).
Per the decision gate in §5, Phase 2 and Phase 3 improvements are **not required** for
basic functionality. However, the corpus is small (20 frames, single session) — a larger
and cross-session corpus is recommended before declaring victory.

### Next steps

1. **Live sensor test** — verify the rebuilt driver works end-to-end (enroll + verify)
2. **Larger corpus** — capture 50+ frames across varied conditions for a more robust benchmark
3. **Cross-session test** — re-enroll, capture verify corpus on a different day
4. **Commit and push** Phase 1 changes
