# MR: Add Goodix GF511 (27c6:5110) fingerprint sensor driver

**Branch:** `goodixtls-upstream-mr` (based on 1.94.9 / `dc8b05f`)
**Details:** [libfprint-27c6-5110](https://github.com/buxel/libfprint-27c6-5110) (analysis, benchmarks, tooling)

---

## Summary

Adds support for the Goodix GF511 capacitive fingerprint sensor
(USB `27c6:5110`, die GF3658), found in Lenovo ThinkBook / IdeaPad and
Huawei MateBook laptops. Standard `FpImageDevice` pattern with a
custom SIGFM matcher for the small sensor images. Only new runtime
dependency is GnuTLS (already an optional dep in the build system).

**No existing driver files or library API are modified**, aside from a
1-line `g_get_monotonic_time()` fix in `fpi-device.c` that affects all
drivers.

---

## Architecture

### Driver layers
- **goodixtls.c/.h** — GObject base class (`FpiDeviceGoodixTls`), USB
  bulk I/O, TLS session management (GnuTLS PSK-DHE in-memory transport).
- **goodix.c/.h** — Protocol codec: pack/unpack/checksum, command send
  with async callback dispatch, receive state machine.
- **goodix5xx.c/.h** — Scan state machine shared by 5xx-series USB
  sensors: FDT down/up, image capture, background subtraction,
  histogram stretch, unsharp-mask, and enroll/verify orchestration.
- **goodix511.c/.h** — GF511-specific constants (endpoints, config
  blob, image crop, firmware version).
- **goodix_proto.c/.h** — Low-level protocol struct definitions and
  encode/decode helpers.
- **sigfm.c/.h** — Pure-C feature matcher: FAST-9 corner detection +
  unsteered BRIEF-256 descriptors + RANSAC rigid-transform verification.
  Uses only `<glib.h>` and `<math.h>`.

### Why not NBIS?
The sensor's 64x80 px (3.2x4.0 mm) image contains ~6-8 ridge periods;
`mindtct` yields <=2 minutiae at any upscale factor with reliability <=0.19.
The SIGFM keypoint matcher is purpose-built for this resolution class.

---

## File summary (2 commits, +5,447/-3 net)

| Commit | Files | What |
|--------|-------|------|
| `811160f` fpi-device fix | 1 | `g_get_monotonic_time()` instead of `g_get_real_time() / 1000` |
| `bf25ee7` driver + test | 23 | 13 driver sources, meson integration, hwdb entry, umockdev pcap replay test, `getrandom-seed.c` TLS shim |

### New driver files (~4,400 lines)
```
libfprint/drivers/goodixtls/
  goodix.c        goodix.h          - protocol transport
  goodix511.c     goodix511.h       - GF511 device entry
  goodix5xx.c     goodix5xx.h       - 5xx scan state machine
  goodix_proto.c  goodix_proto.h    - protocol structs
  goodixtls.c     goodixtls.h       - USB + TLS base class
  sigfm.c         sigfm.h           - FAST-9/BRIEF-256 matcher
```

### Test files
```
tests/getrandom-seed.c              - LD_PRELOAD shim for deterministic gnutls_rnd()
tests/goodixtls511/custom.py        - umockdev replay test script
tests/goodixtls511/custom.pcapng    - captured USB traffic
tests/goodixtls511/device           - umockdev device description
tests/goodixtls511/README.md        - test recording instructions
```

---

## Performance

Benchmarked on a 150-frame corpus (5 fingers x 30 captures):

| Metric | Value |
|--------|-------|
| Per-attempt FRR | 27.6% |
| Effective FRR (5 retries) | 0.16% |
| FAR | 0.00% |
| Score threshold | 7 |
| Enrollment stages | 20 (validated: 15->+12 pp FRR, 10->+23 pp FRR, 30->no gain) |

Full benchmark methodology in `tools/benchmark/`.

> **Note:** The test corpus contains biometric data and is not included
> in the repository. Reviewers can reproduce results with their own
> sensor captures using `tools/benchmark/` and `tools/scripts/`.

---

## Build & test

```sh
meson setup build -Dgoodixtls=enabled
ninja -C build
meson test -C build goodixtls511   # pcap replay test
meson test -C build                # full suite - no regressions
```

Hardware-tested: 20-stage enroll, verify, identify, `fprintd`/PAM
integration (KDE login, sudo unlock).

---

## Checklist

- [x] `ninja -C build` - zero warnings
- [x] `meson test -C build` - no regressions
- [x] Driver replay test passes under `FP_DEVICE_EMULATION=1`
- [x] No existing driver files modified
- [x] C style matches upstream (GNU indent, `/* */` comments, GLib allocators)
- [x] Enroll + verify on physical hardware
- [x] LD_PRELOAD shim scoped to goodixtls511 test only
- [ ] CI green on freedesktop GitLab
