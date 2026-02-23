# MR: Add Goodix GF511 (27c6:5110) fingerprint sensor driver

**Branch:** `goodixtls-on-1.94.9` (based on 1.94.9 / `dc8b05f`)  
**Details:** [libfprint-27c6-5110](https://github.com/buxel/libfprint-27c6-5110) (analysis, benchmarks, tooling)  
**Ping:** `@hadess`

---

## Summary

Adds support for the Goodix GF511 capacitive fingerprint sensor
(USB `27c6:5110`, die GF3658), found in Lenovo ThinkBook / IdeaPad and
Huawei MateBook laptops. Standard `FpImageDevice` pattern. Only new
runtime dependency is GnuTLS (already required by other drivers).

The driver introduces **3 optional vfuncs** on `FpImageDeviceClass`
(`extract`, `build_print`, `compare`) that let a driver supply its own
feature-extraction and matching pipeline while reusing the entire
enroll/verify/identify state machine unchanged. Existing drivers are
unaffected — all vfuncs default to the NBIS minutiae path when NULL.

---

## Why not NBIS?

The sensor's 64×80 px (3.2×4.0 mm) image contains ~6–8 ridge periods;
`mindtct` yields ≤2 minutiae at any upscale factor with reliability ≤0.19.
A pure-C keypoint matcher (FAST-9 + BRIEF-256) replaces it for this sensor
class; see `libfprint/sigfm/` and the [analysis notes](https://github.com/buxel/libfprint-27c6-5110/tree/main/analysis).

---

## Core changes (6 files, +285/−76 net +209)

| File | +/− | What |
|------|-----|------|
| `fpi-image-device.h` | +32/−11 | 3 optional vfuncs + `fpi_image_device_extract_complete()` |
| `fpi-image-device.c` | +108/−43 | Unified `extract_complete` handler; vfunc dispatch in `image_captured` |
| `fpi-print.h/.c` | +95/−18 | `FPI_PRINT_SIGFM` type, lifecycle, `fpi_print_sigfm_match()`, `fpi_print_add_sigfm_data()` |
| `fp-print.c` | +49/−0 | SIGFM serialize/deserialize (parallel to NBIS) |
| `fp-image-device.c` | +1/−4 | Remove hardcoded NBIS type-forcing on enroll start |

Plus: 1-line `g_get_monotonic_time()` fix in `fpi-device.c`, meson/hwdb
registration, and whitespace-only alignment in 3 headers.

**Zero existing driver files modified.** The old `bz3_threshold` name is
kept; no `score_threshold` rename.

---

## New files (driver + library, ~4,300 lines)

```
libfprint/drivers/goodixtls/   – 8 files (511 + 5xx + goodix + proto + tls)
libfprint/sigfm/sigfm.c/.h    – pure-C FAST-9 + BRIEF-256 matcher (libm only)
```

TLS: GnuTLS PSK-DHE in-memory transport, no threads/sockets.
Image pipeline: background subtraction → histogram stretch → unsharp mask.

---

## Performance

Benchmarked on a 150-frame corpus (5 fingers × 30 captures):

| Metric | Value |
|--------|-------|
| Per-attempt FRR | 27.6% |
| Effective FRR (5 retries) | 0.16% |
| FAR | 0.00% |
| Score threshold | 7 |

Full benchmark methodology and tooling in the
[companion repo](https://github.com/buxel/libfprint-27c6-5110/tree/main/tools/benchmark).

> **Note:** The test corpus is **not** included in the repository as it
> contains sensitive biometric data. Reviewers are encouraged to
> reproduce results using the benchmark tooling with their own sensor
> captures (see `tools/benchmark/` and `tools/scripts/`). The original
> corpus can be shared with individual reviewers on request for
> independent verification.

---

## Build & test

```sh
meson setup build -Dgoodixtls=enabled
ninja -C build
ninja -C build test   # 3/3 pass
```

Hardware-tested: 20-stage enroll, verify, identify, `fprintd`/PAM
integration (KDE login, sudo unlock).

---

## Checklist

- [x] `ninja -C build` — zero warnings
- [x] Unit tests pass
- [x] `clang-format --style=file` on all new/modified files
- [x] No existing driver files modified
- [x] `FpImage` zero diff vs upstream
- [x] Enroll + verify on physical hardware
- [ ] CI green on freedesktop GitLab
