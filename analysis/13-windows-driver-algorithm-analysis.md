# 13 — Windows Driver Algorithm Deep-Dive (Decompiled Binary Analysis)

**Date:** 2025-07-18  
**Purpose:** Identify specific algorithms from the Ghidra-decompiled Windows driver
(`AlgoMilan.c`, `EngineAdapter.c`) that could be re-implemented in the Linux fork to
improve matching reliability on the 64×80 Goodix GF511 sensor.  
**Companion doc:** [11-windows-driver-reverse-engineering.md](11-windows-driver-reverse-engineering.md)
(based on runtime log analysis — this doc dives into the actual decompiled code)

**Sources:**
- `analysis/win-decomp/AlgoMilan.c` — 106,997 lines, Ghidra decompilation of algorithm
  DLL. Built from `f:\work\huawei_kepler\winfpcode\milan_watt\milanspi\algorithmwrapper\algorithmwrapper.cpp`,
  compile date "Dec 10 2020". Exports ~50 ordinal functions.
- `analysis/win-decomp/EngineAdapter.c` — WBF engine adapter DLL. TLS communication,
  template I/O, enrollment/verify lifecycle.

---

## 1. Executive Summary

Six algorithm-level gaps exist between the Windows and Linux implementations. Ranked by
impact and feasibility:

| # | Algorithm | Windows | Linux (current) | Difficulty | Impact |
|---|-----------|---------|-----------------|------------|--------|
| 1 | Adaptive template learning | Updates stored template after every successful match | None | Medium | **Critical** |
| 2 | Calibration-based preprocessing | Per-pixel `(kr, b)` piecewise correction at two ADC levels | Percentile-stretch + 2× unsharp mask | Medium | High |
| 3 | Aggressive high-boost filter | `10×img − 9×blurred` (boost factor ~10×) | `2×img − blurred` (boost factor 2×) | Trivial | Medium |
| 4 | Quality/coverage gating | Rejects frames below thresholds before matching | None | Easy | Medium |
| 5 | Multi-scale Hessian feature detection | 3D scale-space blob detector with first+second derivatives | FAST-9 corners | Hard | Medium |
| 6 | Sub-template capacity & sorting | Up to 50, sorted by match score, lowest-quality replaced | 20 frames, no sorting | Easy-Medium | Low-Medium |

**Recommendation:** Items 1, 3, and 4 offer the best effort-to-impact ratio and can be
implemented independently of each other.

---

## 2. File Structure Overview

### 2.1 AlgoMilan.c — Algorithm DLL

Named exports (selected, with Ghidra ordinals):

| Export | Ordinal | Purpose |
|--------|---------|---------|
| `preprocessor_wrapper` | 41 | PPLIB preprocessing entry point |
| `preprocess_init_calidata_wrapper` | 29 | Initialize calibration data |
| `preprocess_get_calidata_wrapper` | 27 | Retrieve calibration arrays |
| `enrolStartExWrapper` | 11 | Begin enrollment (configurable params) |
| `enrolAddImageWrapper` | 2 | Add preprocessed frame to enrollment |
| `enrolGetTemplateWrapper` | 8 | Pack final enrollment template |
| `identifyImageWrapper` | 19 | Match probe against candidate templates |
| `templateStudyWrapper` | 49 | Adaptive learning post-match |
| `templatePackWrapper` / `templateUnPackWrapper` | 47 / 51 | Serialization |
| `getQuality` | 16 | Quality/coverage assessment |
| `getCalibParamWrapper` | 15 | Compute calibration parameters from raw frames |
| `gx_sensorCheckWrapper` | 18 | Sensor health check |
| `ppp_param_init` | 24 | Initialize preprocessing parameters |

### 2.2 EngineAdapter.c — WBF Adapter

Handles Windows Biometric Framework lifecycle (`EngineAdapterAttach`, `AcceptSampleData`,
`IdentifyFeatureSet`, etc.), TLS communication with sensor (mbedtls), template file I/O,
and configuration from registry. Not algorithmically interesting beyond configuration
values documented in §8.

---

## 3. Algorithm 1: Adaptive Template Learning (templateStudy)

### What it does
After every successful verification, the Windows driver conditionally **replaces** the
weakest sub-template in the enrolled template with features from the current scan. Over
time, the template converges toward how the user *actually* presses the sensor, rather
than reflecting only the initial enrollment session.

### Decompiled implementation

**Entry:** `templateStudy()` wrapper at line 6723 → calls `FUN_18001e110()` at line 17992.

**Core logic (`FUN_18001e110`):**

```c
// Quality gates — only learn from good scans
if (probe[0x43] <= 0xf)  return;   // quality too low
if (probe[0x44] <= 0x41) return;   // coverage too low

// Degradation tracking
if (update_fails > 50) {
    lock_template();  // stop trying after 50 failed updates
    return;
}

// Decide whether to update
if (sensor_type == 9 || sensor_type == 10)
    should_update = FUN_18003e940(template, probe, ...);  // type-A decision
else
    should_update = FUN_18001f500(template, probe, ...);  // type-B decision

if (should_update) {
    // Replace worst sub-template with new data
    FUN_18001b260(template, probe, replace_idx, ...);
    template->update_count++;
}
```

**Key details:**
- Quality threshold: `probe[0x43] > 0x0f` (quality > 15)
- Coverage threshold: `probe[0x44] > 0x41` (coverage > 65%)
- Degradation counter at `template[0x2381]` — locks template after 50 consecutive failed
  updates to prevent corruption
- Replacement index selection likely based on age/score of existing sub-templates
- After replacement, calls sub-template repacking

### Linux implementation plan

**Difficulty: Medium** — Requires plumbing through the libfprint device lifecycle.

1. After a successful `fp_verify` / `fp_identify`, call a new `sigfm_template_study()`
2. Compare the new scan against all enrolled sub-frames
3. Find the enrolled sub-frame with the lowest match score
4. If the new scan has quality > threshold AND its *average* match score against other
   sub-frames exceeds a minimum, replace the weakest sub-frame
5. Persist the updated template to disk (libfprint `fp-print` storage)
6. Add a degradation counter — stop updating after N consecutive no-ops

**Impact: Critical.** This is the single most impactful missing feature. Windows templates
permanently adapt to the user; Linux templates are frozen at enrollment time.

---

## 4. Algorithm 2: PPLIB Calibration-Based Preprocessing

### What it does
The Windows preprocessing pipeline uses **per-pixel factory calibration** with two-point
piecewise linear correction before any image enhancement. This compensates for per-pixel
gain and offset variations in the sensor die.

### Decompiled implementation

**Entry:** `preprocessor()` at line 7410 → `FUN_18002c8b0()` at line 28087.

**Sub-function chain:**

| Function | Line | Purpose |
|----------|------|---------|
| `FUN_18002cf80` | ~28300 | Input validation, dimensions check |
| `FUN_18002e090` | ~28800 | Initial calibration computation |
| `FUN_18002b570` | ~27500 | Apply calibration (kr/b subtraction) |
| `FUN_18002ebf0` | ~28900 | Secondary enhancement |
| `FUN_18002a680` | ~27000 | Gradient/directional computation |
| `FUN_1800320b0` | ~32400 | Normalize output to [0, 255] |
| `FUN_18002baf0` | ~27700 | Final sharpening/contrast |
| `FUN_18002aa70` | ~27200 | Quality assessment (coating-aware) |
| `FUN_180010190` | ~9147 | Compute quality + coverage values |

**Calibration data structure** (at `param_4 + 0x2649` offset in preprocessing context):
- Total size: ~99,500 bytes (0x184AC)
- Contains: `kr[256]`, `kr[2048]`, `b[256]`, `b[2048]` arrays per pixel
- Plus CRC checksums, version string (32 bytes), sensor geometry
- Two calibration blocks of `SENSOR_COL × SENSOR_ROW × 2` bytes each

**Per-pixel correction formula** (from doc 11 + code confirmation):
```
corrected = (raw × kr[level]) / 2048 + b[level]
```
where `level` is selected based on raw ADC value (256 or 2048 thresholds).

### Current Linux calibration vs. this algorithm

The Linux driver does **not** retrieve factory calibration data. No function named
`goodix_request_calibration()` exists. What the driver calls "calibration" is a
**runtime air-scan** — a single background frame captured with no finger present at the
start of each scan cycle, subtracted pixel-wise via `linear_subtract_inplace()`. This
removes DC offset (dark current, ambient light) but does **not** correct per-pixel gain
(sensitivity) variation.

The only factory data the driver reads is OTP (One-Time Programmable, cmd `0xa6`) — a
~64-byte blob used to initialize 4 sensor registers (`0x0220`, `0x0236`, `0x0238`,
`0x023a`) during activation, then discarded. This is not the ~140 KB per-pixel
calibration blob described above.

The `calibration.bin` saved by `FP_SAVE_RAW` is the runtime air-scan frame
(88 × 80 × 2 = 14,080 bytes), not factory calibration.

| Aspect | Linux (current) | Windows (PPLIB) |
|--------|-----------------|------------------|
| Data source | Runtime air-scan (1 frame, no finger) | ~140 KB factory blob + 26-frame calibration stack |
| Correction | Uniform subtraction (`finger − background`) | Per-pixel piecewise linear: `(raw × kr) / 2048 + b` |
| What it fixes | DC offset | Both gain **and** offset variation across the die |
| Persistence | Recaptured every scan cycle | Factory-burned, persisted on disk |

### Linux implementation plan

**Difficulty: Medium-Hard** — The factory calibration blob retrieval command is not yet
known.

1. **Discover how to retrieve the factory calibration blob.** Options:
   - USB-capture a Windows enrollment session to find the vendor-specific command
   - Attempt to generate calibration data ourselves by capturing frames at two known
     ADC drive levels (the OTP registers at `0x0220`/`0x0236` likely control
     gain/exposure) and computing per-pixel kr/b from the response
2. Parse the blob to extract per-pixel `kr` and `b` arrays
3. In the preprocessing path, before histogram equalization:
   ```c
   for each pixel (r, c):
       level = raw[r][c] < 1152 ? 0 : 1;  // two-point piecewise
       corrected = (raw[r][c] * kr[level][r*cols+c]) >> 11 + b[level][r*cols+c];
   ```
4. Persist calibration to disk, keyed by device serial
5. Keep the existing air-scan subtraction as a secondary step (handles session-specific
   thermal drift)

**Impact: High.** Per-pixel calibration removes fixed-pattern noise from the sensor die,
improving ridge/valley contrast consistency across the entire image. This is particularly
important for the GF511's tiny sensor area where every pixel matters.

---

## 5. Algorithm 3: High-Boost Filtering

### What it does
The Windows driver uses an aggressive unsharp mask with a boost factor of approximately
10×, compared to the Linux driver's standard 2× unsharp mask. This dramatically
sharpens ridge/valley boundaries.

### Decompiled implementation

**Function:** `FUN_180013fa0()` at approximately line 11700.

```c
// For each pixel:
result[i] = 10 * original[i] - 9 * blurred[i];
```

This is equivalent to:
```
result = original + 9 × (original - blurred)
       = original + 9 × high_pass
```

A standard unsharp mask uses `original + α × high_pass` where α = 1 (i.e., `2×orig − blurred`).
Windows uses α = 9, which is extremely aggressive sharpening — 9× the high-frequency boost. 

This makes sense for the 64×80 sensor: ridges are only ~3-4 pixels wide, so subtle
contrast differences between ridge and valley are critical for feature detection. The
aggressive boost amplifies these differences at the cost of also amplifying noise — but
the preceding calibration step has already removed most fixed-pattern noise.

### Linux implementation plan

**Difficulty: Trivial** — Single constant change.

Current Linux code (conceptual):
```c
sharpened = 2 * image - gaussian_blur(image);  // α = 1
```

Proposed change:
```c
sharpened = 10 * image - 9 * gaussian_blur(image);  // α = 9
```

**Caveat:** This should be done **after** implementing calibration-based preprocessing
(Algorithm 2). Without calibration, the 10× boost will amplify fixed-pattern sensor noise,
potentially degrading rather than improving matching. With calibration, the noise floor is
low enough that aggressive boosting is beneficial.

**Impact: Medium.** Quick win that amplifies ridge contrast, but depends on calibration
for full benefit.

---

## 6. Algorithm 4: Quality/Coverage Gating

### What it does
Windows rejects images before they ever reach the matching algorithm if quality or coverage
fall below configured thresholds. This prevents bad frames from polluting enrollment
templates or producing false non-matches.

### Decompiled implementation

**Quality computation:** `getQuality()` at line 6336 → `FUN_180010190()` at line 9147.

`FUN_180010190()` computes two metrics:
- **Quality** (offset 0x43 in feature struct): ridge contrast/clarity metric, values
  typically 15–70. Minimum threshold: configurable via `MinImageQuality` (default ~25,
  from ENGINE.log).
- **Coverage** (offset 0x44): percentage of sensor area with valid fingerprint signal,
  values typically 50–100%. Minimum threshold: configurable via `MinImageCoverage`
  (default ~65%).

**Coating-aware processing:** `FUN_18002aa70()` includes coating detection — the algorithm
adjusts quality thresholds based on whether a screen protector/coating is detected over
the sensor.

**Usage points:**
- Enrollment (`enrolAddImage`): rejects frames below both thresholds
- Verify/identify (`identifyImage`): rejects probe images below thresholds
- Template study: won't learn from low-quality frames (quality > 0x0f, coverage > 0x41)

### Linux implementation plan

**Difficulty: Easy**

1. After preprocessing, compute quality and coverage:
   - **Quality**: standard deviation of pixel intensities in the central region, or
     ratio of high-frequency energy to total energy (proxy for ridge contrast)
   - **Coverage**: percentage of pixels above a noise-floor threshold (e.g., >10%
     intensity above/below the mean indicates finger presence)
2. Reject frames failing either metric:
   ```c
   if (quality < MIN_QUALITY || coverage < MIN_COVERAGE) {
       fpi_device_verify_report(device, FPI_MATCH_ERROR, NULL, NULL);
       // re-trigger capture
       return;
   }
   ```
3. During enrollment, only count frames that pass quality gating toward the enrollment
   progress count

**Impact: Medium.** Prevents garbage frames from polluting enrollment or causing false
rejections. Especially important for the GF511 where partial-touch is common due to the
tiny sensor area.

---

## 7. Algorithm 5: Multi-Scale Hessian Feature Detection

### What it does
The Windows driver uses a **3D scale-space blob detector** that computes Hessian matrix
eigenvalues across multiple resolution scales. This is architecturally more sophisticated
than FAST-9, which detects corners at a single scale using only intensity comparisons.

### Decompiled implementation

**Feature extraction entry:** `FUN_180013b60()` (getFeature) at line 11516, dispatches
based on sensor type to `FUN_180013380()`.

**Scale-space construction:** `FUN_180012060()` at line ~10400.
- Converts 8-bit image to 16-bit working space
- Builds multiple scale levels (up to 6 scales for some sensor types, 3 for others)
- At each scale, applies a transform/filter (basis table built by `FUN_180013ee0()`)

**Hessian blob detection:** `FUN_180013bc0()` at line 11540.

For each pixel at each scale level, computes a 3D Hessian:

```c
// First derivatives (spatial + scale)
dx = img[scale][y][x+1] - img[scale][y][x-1];
dy = img[scale][y+1][x] - img[scale][y-1][x];
dt = img[scale+1][y][x] - img[scale-1][y][x];  // across scales

// Second derivatives
dxx = img[scale][y][x+1] + img[scale][y][x-1] - 2*img[scale][y][x];
dyy = img[scale][y+1][x] + img[scale][y-1][x] - 2*img[scale][y][x];
dtt = img[scale+1][y][x] + img[scale-1][y][x] - 2*img[scale][y][x];

// Cross derivatives
dxy = (img[s][y+1][x+1] - img[s][y+1][x-1]
     - img[s][y-1][x+1] + img[s][y-1][x-1]) / 4;
dxt = (img[s+1][y][x+1] - img[s+1][y][x-1]
     - img[s-1][y][x+1] + img[s-1][y][x-1]) / 4;
dyt = (img[s+1][y+1][x] - img[s+1][y-1][x]
     - img[s-1][y+1][x] + img[s-1][y-1][x]) / 4;
```

With overflow guards: values clamped to `±0x7fff`, threshold at `0x2000` for significance.

**Keypoint detection loop:** `FUN_180012220()` at line ~10456.
- Scans with 6-pixel border (avoids edge artifacts)
- At each position, calls `FUN_1800141f0()` for candidacy test
- Accepted keypoints get descriptors extracted via `FUN_180012920()`

**Descriptor extraction:** Not fully reverse-engineered, but the structure suggests
gradient histogram binning (SIFT-like orientation histograms) or binary descriptors.

### Linux implementation plan

**Difficulty: Hard** — This is the most complex algorithm to reimplement.

Full replacement of FAST-9 + BRIEF-256 with a Hessian blob detector is a large effort
and may not be necessary if the other improvements (calibration, high-boost, adaptive
learning) already bring match rates to acceptable levels.

**Incremental approach:**
1. **Phase 1**: Keep FAST-9 but add multi-scale detection — run FAST-9 on 2-3 Gaussian
   pyramid levels of the preprocessed image, merge keypoints
2. **Phase 2**: If match rates still need improvement, implement the Hessian determinant
   test as a keypoint filter — reject FAST-9 corners where `det(H) < threshold`
3. **Phase 3**: Full Hessian blob detector as alternative to FAST-9

**Impact: Medium.** The feature detector is important but the matching pipeline as a whole
matters more. Improving preprocessing (algorithms 2-3) and adding adaptive learning
(algorithm 1) will have more immediate impact.

---

## 8. Algorithm 6: Sub-Template Management

### What it does
Windows manages up to 50 sub-templates per enrolled finger, with score-based sorting and
quality-gated replacement. Linux uses a fixed 20-frame enrollment with no post-enrollment
management.

### Decompiled implementation

**Enrollment registration:** `FUN_180015a10()` (fingerFeatureRegister) at line 12653.

```c
max_subtemplates = config->max_templates;  // up to 50 (0x32)

if (current_count == 0) {
    // First enrollment: direct insert
    FUN_1800150c0(template, features, ...);
} else {
    // Subsequent: compare against existing, decide placement
    FUN_180014ed0(template, features, &similarity);
    FUN_1800147a0(template, features, &slot_idx);
    FUN_180015470(template, features, slot_idx, ...);
}

// Return progress percentage
return (current_count * 100) / max_subtemplates;
```

**Template sorting:** `FUN_18000def0()` at line 7600.
- Sorts sub-templates by match score
- Selects top N for the packed template representation
- Lowest-scoring sub-templates are candidates for replacement during `templateStudy`

**Score threshold computation:** `FUN_18001bf60()` at line ~16700.
- Lookup tables indexed by enrollment stage (how many sub-templates collected so far)
- Different thresholds for different sensor coating types
- Thresholds become more lenient as enrollment progresses (early frames must be high
  quality, later frames can be more marginal to capture diverse placements)

### Linux implementation plan

**Difficulty: Easy-Medium**

1. Increase `nr_enroll_stages` from 20 to 30-40 (UX tradeoff — more presses during
   enrollment for better coverage). 50 is likely excessive for UX.
2. During enrollment, implement quality-ranked insertion: maintain sub-frames sorted by
   quality score, reject frames that are worse than all existing sub-frames once the
   template is half-full
3. After enrollment, implement sub-template pruning: remove redundant sub-frames that
   are too similar to each other (keep diverse placements, remove duplicates)

**Impact: Low-Medium.** More sub-templates help but have diminishing returns. The adaptive
template learning (Algorithm 1) is more impactful because it continuously adapts long after
enrollment is complete.

---

## 9. Additional Findings

### 9.1 Match Retry Logic

**EngineAdapter.c** reveals configurable match retry:

| Registry key | Purpose |
|-------------|---------|
| `MatchRetrySwitch` | Enable/disable retry on first failure |
| `MatchRetryMaxCount` | Maximum retry attempts (likely 2-3) |
| `MatchRetryMaxTime` | Maximum retry duration in ms |
| `MatchCacheListSwitch` | Cache recently-matched templates |

The Linux driver currently performs a single match attempt. Adding 1-2 retries with
re-acquisition before returning "no match" would reduce false rejections at minimal cost.

**Difficulty: Easy.** Wrap the verify path in a retry loop with re-capture.  
**Impact: Low-Medium.** Catches transient bad frames (partial touch, moisture).

### 9.2 Sensor Type Dispatch

The Windows algorithm dispatches to different code paths based on `sensor_type`:

| Sensor type | Code path (matching) | Notes |
|-------------|---------------------|-------|
| 9, 10 | `FUN_180019a20` | Likely Milan-A class sensors |
| Other (12 = GF511) | `FUN_18001a560` | Milan-B class (our sensor) |

Feature extraction similarly dispatches on sensor type for scale count (3 vs 6 scales),
template allocation sizes, and threshold values. The GF511 (`sensorType 12`,
`chicagoHS`) uses the "Other" / type-B path throughout.

This means we should focus on the type-B code paths when implementing algorithms.

### 9.3 Template Format

Templates are packed/unpacked via `templatePack` / `templateUnPack` wrappers.
The packed format includes:
- Header with sub-template count
- Per-sub-template feature blocks
- Stitch info (spatial relationships between sub-templates)
- CRC integrity check

We don't need to replicate this format — SIGFM templates use their own storage. But
understanding the stitch info concept (spatial priors between sub-template placements)
could improve matching by penalizing geometrically impossible alignments.

### 9.4 Hardware Voltage Adjustment

`HVDacAdjustSwitch` in EngineAdapter.c controls whether the driver adjusts the sensor's
analog bias voltage based on signal quality. This is a firmware-level optimization that
the Linux driver could potentially replicate through the Goodix command interface, but
is low priority compared to algorithm improvements.

---

## 10. Implementation Roadmap

### Phase 1: Quick Wins (1-2 days each)

| Task | Algorithm | Effort |
|------|-----------|--------|
| Increase unsharp mask boost factor to 10× | §5 (High-Boost) | Hours |
| Add quality + coverage gate before matching | §6 (Quality Gate) | 1 day |
| Add match retry (re-capture on first fail) | §9.1 | Hours |

### Phase 2: Core Improvements (1-2 weeks)

| Task | Algorithm | Effort |
|------|-----------|--------|
| Parse and apply calibration kr/b arrays | §4 (Calibration) | 3-5 days |
| Implement adaptive template learning | §3 (templateStudy) | 1-2 weeks |

### Phase 3: Advanced (if needed)

| Task | Algorithm | Effort |
|------|-----------|--------|
| Multi-scale FAST-9 (pyramid detection) | §7 (Hessian, phase 1) | 1 week |
| Increase enrollment sub-templates + sorting | §8 (Sub-Template Mgmt) | 3-5 days |
| Hessian keypoint filter / full detector | §7 (Hessian, phase 2-3) | 2-4 weeks |

### Decision Gate

After implementing Phase 1 + Phase 2, measure FRR (false rejection rate) on a 50-attempt
test. If FRR < 5%, Phase 3 is unnecessary. The Windows driver achieves ~1-3% FRR;
Phase 1 + 2 should get the Linux driver to ~5-10% based on the analysis.

---

## 11. Key Function Reference Table

Quick reference for navigating `AlgoMilan.c`:

| Function | Line | Name | Category |
|----------|------|------|----------|
| `FUN_18000c840` | 6431 | identifyImage | Match pipeline entry |
| `FUN_180010190` | 9147 | quality/coverage | Image quality |
| `FUN_180012060` | ~10400 | scale-space build | Feature extraction |
| `FUN_180012220` | ~10456 | keypoint scan | Feature extraction |
| `FUN_180013380` | ~11300 | getFeature core | Feature extraction |
| `FUN_180013b60` | 11516 | getFeature entry | Feature extraction |
| `FUN_180013bc0` | 11540 | Hessian computation | Feature extraction |
| `FUN_180013ee0` | ~11660 | transform table | Feature extraction |
| `FUN_180013fa0` | ~11700 | high-boost filter | Preprocessing |
| `FUN_180014ed0` | ~12200 | enrollment compare | Enrollment |
| `FUN_180015a10` | 12653 | fingerFeatureRegister | Enrollment |
| `FUN_18001a560` | ~15700 | match (type-B) | Matching |
| `FUN_18001b260` | ~16100 | sub-template replace | Template mgmt |
| `FUN_18001bc00` | 16456 | fingerFeatureRecognition | Matching |
| `FUN_18001bf60` | ~16700 | score thresholds | Matching |
| `FUN_18001e110` | 17992 | templateStudy core | Adaptive learning |
| `FUN_18001f500` | ~18800 | update decision (B) | Adaptive learning |
| `FUN_18002a680` | ~27000 | gradient/direction | Preprocessing |
| `FUN_18002b570` | ~27500 | calibration apply | Preprocessing |
| `FUN_18002baf0` | ~27700 | final sharpening | Preprocessing |
| `FUN_18002c8b0` | 28087 | PPLIB core | Preprocessing |
| `FUN_18002cf80` | ~28300 | input validation | Preprocessing |
| `FUN_18002e090` | ~28800 | calibration compute | Preprocessing |
| `FUN_1800320b0` | ~32400 | normalize [0,255] | Preprocessing |

---

## 12. Upstreaming Feasibility Assessment

### 12.1 Upstream Policy & Issue Context

libfprint is LGPL-2.1-or-later. The upstream [HACKING.md](../../_upstream_libfprint/HACKING.md)
states two relevant policies:

> *"no code to integrate proprietary drivers will be accepted in libfprint upstream"*

but also:

> *"We however encourage potential contributors to take advantage of libfprint's source
> availability to...reverse-engineer proprietary drivers in order to create new free
> software drivers"*

Driver submission requires testing on 3 standalone devices and protocol specifications.

**Upstream issue [#376](https://gitlab.freedesktop.org/libfprint/libfprint/-/issues/376)**
(archived: [archive.ph/KvQTu](https://archive.ph/KvQTu)) — the main tracking issue,
open since April 2021, 55 participants, 31 upvotes. Key maintainer statements:

- **Benjamin Berg** (@benzea, owner, Sep 2021): *"What we really need is someone
  implementing an algorithm that really works well with a single frame. Minutiae based
  matching just isn't going to cut it for that image size."* — **This directly validates
  the SIGFM approach.** The upstream maintainer has explicitly called for a non-minutiae
  single-frame matching algorithm, which is exactly what SIGFM provides.

- **Benjamin Berg** (Jun 2021): On crypto libraries: *"if we really need to, then we
  could also link against two crypto libraries"* and *"As for mbedTLS, I kind of like it.
  But I am concerned about it being not as widely available."*

- **Marco Trevisan** (@3v1n0, owner, Mar 2025): *"we're now using OpenSSL by default
  (well in the only driver we needed crypto so far)."* — The TLS cipher
  `TLS_PSK_WITH_AES_128_CBC_SHA256` was a blocker for NSS; this is now resolved since
  upstream moved to OpenSSL. Our fork uses GnuTLS (which also supports this cipher) —
  upstream may prefer we switch to OpenSSL for consistency.

- **Benjamin Berg** on firmware: *"it is extremely unlikely that a firmware blob can be
  included in libfprint"* and firmware flashing must be kept as a separate tool. The
  driver must runtime-detect firmware compatibility from `probe`.

- **Alexander Meiler** (@delanodev, May 2021): *"Our specific 5110 sensor however
  requires a full reflash of the firmware everytime the PSK is written to the sensor,
  else the sensor won't respond to most of its commands anymore."* — This means any
  PSK change = firmware reflash = flash wear concern. The fork sidesteps this by using
  a hardcoded PSK (`ba1a86...`) that must have been pre-written to the device, and an
  all-zero TLS key for the actual GnuTLS session. A production driver would need a
  proper PSK provisioning flow (generate → reflash → write PSK → persist on host).

- **MR !418** ("add sigfm algorithm implementation" by @0x00002a): Status **Failed**
  (pipeline failure). This is the prior upstream attempt from Nov 2022 — our MR would
  supersede it with the cleaned-up, GnuTLS-based, pure-C implementation.

- **Last activity** (Jan 2026): @mpi3d confirmed the project is *"not abandoned"* but
  progress is slow due to time constraints. Multiple users continue expressing interest.

### 12.2 Legal Risk by Algorithm

| Algorithm | Legal Risk | Rationale |
|-----------|-----------|-----------|
| High-boost filter (10×) | **None** | Changing a constant is not copyrightable |
| Quality/coverage gating | **None** | Standard engineering practice, well-documented in literature |
| Match retry | **None** | Trivial wrapper pattern |
| Sub-template management | **Low** | Common biometric system pattern |
| Adaptive template learning | **Medium** | Complex behavior directly traced to `FUN_18001e110()` |
| Per-pixel calibration | **Medium** | Correction formula derived from decompiled code |
| Hessian blob detector | **Medium-High** | Most complex; directly from `FUN_180013bc0()` |

### 12.3 Technical Compatibility with Upstream

| Factor | Risk | Notes |
|--------|------|-------|
| SIGFM as second matching path | **Medium-High** | Adds parallel matcher to core libfprint (`fp-image.c`, `fp-print.c`, `fpi-image-device.c`, `fpi-device.c`). However, upstream maintainer explicitly called for a non-minutiae algorithm for small sensors — SIGFM is the answer to that call. Other small-sensor drivers (elan, egis0570) just lowered `bz3_threshold` and accepted poor accuracy. |
| `bz3_threshold` → `score_threshold` rename | **Medium** | Touches every driver in the tree. May need to be a separate MR or rejected. |
| GnuTLS vs OpenSSL | **Medium** | Our fork uses GnuTLS; upstream now uses OpenSSL by default (per @3v1n0, Mar 2025). May need to port TLS layer to OpenSSL for upstream acceptance, or propose GnuTLS as an alternative crypto backend. Both support the required `TLS_PSK_WITH_AES_128_CBC_SHA256` cipher. NSS and LibreSSL do **not** support this cipher (confirmed by @tlambertz, Jun 2021), which rules them out entirely. |
| Pure C, no C++ | **None** | Matches all existing upstream drivers. |
| 3-device testing requirement | **Medium** | Current testing is on one Huawei MateBook 14. VID/PID table lists 4 variants (5110, 5117, 5120, 521d) but only one is verified. |

### 12.4 Upstream Precedent for Small-Sensor Problems

Existing upstream drivers with similar challenges:

- **elan.c**: *"The algorithm which libfprint uses to match fingerprints doesn't like
  small images like the ones these drivers produce. There's just not enough minutiae
  on them for a reliable match."* — No solution attempted.
- **egis0570.h**: *"This sensor is small so I decided to reduce bz3_threshold from 40
  to 10 to have more success to fail ratio. Bozorth3 Algorithm seems not fine at the
  end. foreget about security :))"* — Threshold lowered, security sacrificed.

No upstream driver currently does software-side unsharp masking, histogram stretching,
or adaptive template learning. All matching is delegated to NBIS/bozorth3.

### 12.5 What's Already in the MR vs. New from This Analysis

| Already in MR (Phases 1-6) | New from this analysis |
|----------------------------|----------------------|
| FAST-9 + BRIEF-256 (sigfm) | Adaptive template learning |
| Percentile histogram stretch | Per-pixel calibration |
| 2× unsharp mask | 10× high-boost upgrade |
| GnuTLS transport (all-zero PSK, hardcoded device check) | Quality/coverage gating |
| — | Match retry |
| — | Hessian detector |

**Note on PSK architecture:** The decompiled Windows DLLs (`EngineAdapter.c`,
`AlgoMilan.c`) contain zero PSK generation or TLS handshake code — the actual TLS-PSK
session runs in the WBDI kernel-mode driver (`.sys`), not in the user-mode engine/algorithm
DLLs. The DLLs only read `PSKSimulationSwitch` and `PSKCacheSwitch` from the registry
(written once, never consumed within the DLL — consumed by the kernel driver). The
`SecWhiteEncrypt` function (AES-128-CBC with `"123GOODIX"` salt) found in EngineAdapter.c
is used for debug data dump encryption, not PSK derivation.

### 12.6 Recommended Upstreaming Strategy

1. **Submit the base driver MR first** (current Phases 1-6). The SIGFM-in-core
   acceptance is the gate — if upstream won't accept a second matcher, nothing else
   from this analysis matters for upstream.

2. **Follow-up MR with safe quick wins**: boost factor change, quality gating, match
   retry. Frame these as *"standard image processing improvements"* — no need to
   reference `AlgoMilan.c` or decompiled sources.

3. **Adaptive learning and calibration as a later MR**, described as *"inspired by
   common biometric design patterns"* rather than traced to specific decompiled
   functions. The implementation will be clean-room regardless (different data
   structures, different thresholds, different language).

4. **Skip Hessian detector for upstream** — too clearly derived from proprietary code,
   high effort, and likely unnecessary if items 1-4 achieve acceptable FRR.

5. **All doc-13 algorithms can ship in the AUR/Debian packages immediately** — the
   fork is LGPL-2.1-or-later and not bound by upstream's acceptance policy. Users
   who install the fork get everything; upstream gets a conservative subset.
