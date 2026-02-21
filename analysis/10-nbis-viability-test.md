# 10 — Phase 1: NBIS Viability Test & Super-Resolution Analysis

**Date:** 2026-02-19  
**Goal:** Determine whether NBIS/bozorth3 can replace SIGFM as the matcher for the
goodixtls511 sensor, and whether combining multiple captured frames could yield enough
image quality for NBIS to work.

---

## 1. Sensor Signal Path (What We're Working With)

```
USB frame (encrypted TLS)
  └─ goodixtls5xx_decode_frame()
       └─ 88 × 80 × guint16  (16-bit capacitance readings)
            ├─ linear_subtract_inplace()   — subtract calibration frame (in 16-bit space)
            ├─ squash_frame_linear()       — per-frame min→max normalise → 8-bit
            └─ crop_frame()               — take columns 0-63 of 88 → 64 × 80 × u8
                  └─ FpImage (64×80, 8-bit, 508 DPI)
```

Key facts from the source:

| Property | Value | Source |
|---|---|---|
| Raw pixel type | `guint16` (16-bit) | `goodix5xx.h:46` |
| Raw scan dimensions | 88 × 80 px | `goodix511.c:49` `GOODIX511_SCAN_WIDTH 88` |
| Output image dimensions | 64 × 80 px | `goodix511.c:47-48` |
| Physical area at 508 DPI | 3.2 mm × 4.0 mm = **12.8 mm²** | calculated |
| Enrollment frames | **20 independent presses** | `goodix511.c:322` `nr_enroll_stages = 20` |
| Matching algorithm (current) | SIGFM | `goodix511.c:330` `FPI_DEVICE_ALGO_SIGFM` |

The extra 24 columns (88−64) are discarded in `crop_frame()`; they are guard/reference
electrodes, not additional sensing area for SR.

---

## 2. NBIS Minutiae Test Results

A standalone test program ([`/workspace/nbis-test/nbis-minutiae-test.c`](../nbis-test/nbis-minutiae-test.c))
was built directly against the bundled NBIS C sources (`libfprint/nbis/mindtct/` ×26 files +
`bozorth3/` ×6 files) to call `get_minutiae()` with the same `g_lfsparms_V2` parameters
libfprint uses internally.

Test images:
- `/workspace/enrolled.pgm` — 64×80 8-bit PGM, saved from a real enrollment scan
- `/tmp/verify.pgm` — 64×80 8-bit PGM, saved from a real verify scan

### Results: minutiae count vs scale and ppmm

| Scale | Dimensions | ppmm arg | Enrolled | Verify |
|---|---|---|---|---|
| 1× (native) | 64×80 | 20.0 | **2** | 0 |
| 2× bilinear | 128×160 | 40.0 | 2 | 2 |
| 2× bilinear | 128×160 | 20.0 | 2 | 2 |
| 4× bilinear | 256×320 | 80.0 | 0 | — |
| 4× bilinear | 256×320 | 20.0 | 0 | — |
| 6× bilinear | 384×480 | 120.0 | 0 | — |

**Finding:** Minutiae count is 0–2 across all tested scales and ppmm values. Bozorth3
requires a minimum of ~8 reliable minutiae in each print to produce a meaningful score.

### Bozorth3 match test

Test binary: [`/workspace/nbis-test/nbis-bozorth3-test.c`](../nbis-test/nbis-bozorth3-test.c)

```
=== NBIS bozorth3 match test ===
  ppmm=20.0  scale=2x
  /workspace/enrolled.pgm (2x): 2 minutiae
  /tmp/verify.pgm (2x): 2 minutiae
RESULT: Skipping bozorth3 — too few minutiae (2 / 2)
VERDICT: NBIS not viable for this sensor.
```

The bozorth3 score was not computed — there are simply too few minutiae to attempt a match.

---

## 3. Why NBIS Fails: Root Cause

NBIS/mindtct's ridge-tracing algorithm needs to observe a complete local ridge structure:
ridges entering and leaving a patch, bifurcations, and endings. The rule of thumb is that
a patch must contain at least 5-10 full ridge periods to produce reliable minutiae.

| Quantity | Value |
|---|---|
| Sensor pixel pitch | 508 DPI → **50 μm/pixel** |
| Average fingerprint ridge period | **400–500 μm** |
| Ridges visible in 64 px (3.2 mm) | ~6–8 ridges across the short axis |
| Ridges visible in 80 px (4.0 mm) | ~8–10 ridges along the long axis |
| Total ridge segments visible | far too few for reliable structural features |

A typical 500 DPI sensor for NBIS uses a **0.5" × 0.65"** platen (12.7 mm × 16.5 mm),
giving ~200 mm². The goodixtls511 covers **12.8 mm²** — roughly **1/16th** of the standard
area. Even with perfect noise elimination, there simply is not enough ridge topology for
mindtct to locate reliable structural features.

The 2 minutiae that *are* detected have reliability ≤ 0.19 (libfprint quality score;
bozorth3 considers a good minutia as > 0.5), indicating they are noise artefacts, not true
ridge endpoints or bifurcations.

---

## 4. Can Multiple Scans Be Combined to Produce a Higher-Quality Image?

### 4a. Frame averaging (denoising)

**Is it feasible?** Yes, in principle.

The 20-frame enrollment pipeline captures 20 independent presses.  The raw pixels are
`guint16` before the `squash_frame_linear()` call normalises each frame to 8-bit
independently.  If instead we:

1. Keep each frame in 16-bit space after calibration subtraction
2. Spatial-align the N frames (whole-pixel registration via normalised cross-correlation)
3. Average the aligned 16-bit frames
4. Apply `squash_frame_linear()` once on the averaged result

…we would reduce zero-mean additive noise by a factor of $1/\sqrt{N}$.  With $N = 20$
frames the theoretical SNR improvement is $\times 4.47$ (~13 dB).

**Would it help NBIS?**  Unlikely to be sufficient.  The problem is not noise — the
enrolled and verify PGM files already show clear ridge structure visible to the human eye
(the ridges and valleys are visible in the image).  The issue is that the sensor area is
too small for mindtct to find *transitions* (endings/bifurcations), which require following
a ridge until it ends or splits.  A cleaner version of the same 64×80 area would still
contain the same number of ridges and the same dearth of transitions within the frame.

### 4b. True super-resolution

**Is it feasible?** No, for fundamental physical reasons.

Multi-frame super-resolution (MFSR) works by recovering spatial frequencies above the
pixel Nyquist limit when *known sub-pixel shifts* exist between frames. It requires:

1. Sub-pixel inter-frame shifts
2. Accurate sub-pixel shift estimation
3. An optical/physical aperture smaller than a pixel so aliased high-frequency content
   is present in each frame to be deconvolved

None of these conditions hold here:

| Requirement | Reality |
|---|---|
| Sub-pixel shifts between presses | Finger repositions by several pixels between presses — useful for coverage, not for SR |
| Shift estimation accuracy | Ridge autocorrelation gives pixel-level alignment at best; sub-pixel accuracy requires sub-pixel features that don't exist yet |
| PSF narrower than one pixel | Each capacitive electrode physically integrates over its 50 μm cell — it has no high-frequency content to deconvolve |

The electrode cell size (50 μm × 50 μm) is the physical limit.  The sensor cannot
capture spatial frequencies above $1/(2 × 50\,\mu\text{m}) = 10\,\text{cycles/mm}$
regardless of how many frames are taken.

### 4c. Mosaic stitching (coverage super-resolution)

**Is it feasible?** Potentially, but requires firmware co-operation.

If multiple presses are intentionally *shifted* (e.g. the sensor reads top-half, then
bottom-half of the finger), the frames can be stitched into a larger composite.  The
goodixtls511 firmware does not support multi-region capture; each press returns the same
64×80 sensing area.  This is a firmware / protocol limitation, not a software limitation.

Some goodix sensors (e.g. the 7395 swipe sensor) do capture a strip and composite it into
a wider image in firmware.  The 511 is not a swipe sensor.

### 4d. Summary table

| Technique | Feasible? | Benefit to NBIS? | Complexity |
|---|---|---|---|
| Frame averaging (denoising) | Yes — 20 frames available, 16-bit data in driver | Marginally cleaner image but same resolution | Medium (needs alignment + pre-squash average) |
| True super-resolution | No — physical electrode limit | — | — |
| Mosaic stitching | No — firmware delivers same 64px area every press | — | — |

---

## 5. Phase 1 Verdict

**NBIS is not viable for the goodixtls511 sensor.**

The sensor's 64×80-pixel / 12.8 mm² imaging area is fundamentally too small for
NBIS/bozorth3, regardless of upscaling, denoising, or multi-frame combination.
No software technique can add spatial information that the physical sensor never
captured.

The SIGFM / SIFT-based matcher continues to be the only viable approach for this
sensor class until/unless the upstream team either:
- Adds a sensor-specific small-area mindtct profile with relaxed minimum minutiae
  requirements (a significant change to libfprint's core NBIS integration), or
- Accepts that small-platen sensors require a matcher other than bozorth3.

---

## 6. Impact on the Upstream Porting Plan

Per [09-upstream-porting-plan.md](09-upstream-porting-plan.md):

- **Phase 1 outcome → Phase 3 decision: keep SIGFM** (the NBIS-only path is closed).
- **SIGFM/OpenCV dependency remains.** The OpenCV/SIGFM code cannot be dropped.
- **Phase 2 (GnuTLS)** is still fully independent and remains the priority.
- **The upstream pitch** changes: this driver requires a SIFT-based matcher, and the
  upstream story should either be "bundled pure-C SIFT" or "propose SIGFM as an upstream
  matching backend for small-platen sensors".

### Revised phase ordering

| Phase | Task | Status |
|---|---|---|
| 1 | NBIS viability test | ✅ Complete — NBIS not viable |
| 2 | GnuTLS rewrite of `goodixtls.c/h` | ⬜ Next priority |
| 3 | SIGFM decision | ✅ Resolved — SIGFM stays; needs pure-C or bundled C++ port |
| 4 | Build system cleanup (C-only project, remove pthreads/OpenSSL) | ⬜ After Phase 2 |
| 5 | Thermal fix (`temp_hot_seconds = -1` in class_init) | ⬜ |
| 6 | Upstream MR | ⬜ |

---

## 7. Test Artifacts

```
/workspace/nbis-test/
  Makefile               — builds against bundled libfprint NBIS sources, no extra deps
  nbis-minutiae-test.c   — calls get_minutiae() on a PGM at any scale/ppmm
  nbis-bozorth3-test.c   — runs full enroll→verify bozorth3 pipeline on two PGMs
```

Build:
```bash
cd /workspace/nbis-test && make
```

Reproduce results:
```bash
# Minutiae counts at all scales
./nbis-minutiae-test /workspace/enrolled.pgm 20.0 1
./nbis-minutiae-test /workspace/enrolled.pgm 40.0 2
./nbis-minutiae-test /workspace/enrolled.pgm 80.0 4

# Bozorth3 match test
./nbis-bozorth3-test /workspace/enrolled.pgm /tmp/verify.pgm 20.0 2
```
