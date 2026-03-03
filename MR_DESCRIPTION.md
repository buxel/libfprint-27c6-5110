# MR: Add Goodix GF511 (27c6:5110) fingerprint sensor driver

**Branch:** `goodixtls-upstream-mr` (based on 1.94.9 / `dc8b05f`)

---

## Summary

Adds support for the Goodix GF511 capacitive fingerprint sensor
(USB `27c6:5110`, die GF3658), found in Huawei MateBook and Lenovo
ThinkBook / IdeaPad laptops.  The sensor encrypts all image data
over USB using TLS 1.2 (PSK-DHE); the GnuTLS dependency is
unavoidable for this device class.

The driver layers are designed for the broader Goodix 51xx MOH
(Match-on-Host) family — 5117, 5120, 521d share the same protocol
and only need a thin per-device shim similar to `goodix511.c`.
This MR adds the 5110 as the first supported device.

**Firmware prerequisite:** The sensor ships with Goodix factory
firmware that must be provisioned once via
[goodix-fp-dump](https://github.com/goodix-fp-linux-dev/goodix-fp-dump)
before the driver can communicate.  An unflashed sensor will fail
`probe` cleanly (no hang, no crash).  Firmware redistribution is
out of scope for libfprint — same situation as fwupd-dependent
devices, except the user runs a one-time script instead.

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
- **sigfm.c/.h** — Pure-C feature matcher (FAST-9 + BRIEF-256 +
  RANSAC rigid-transform).  Lives in `drivers/goodixtls/` because it
  is tightly coupled to this sensor's resolution class and image
  characteristics; if other low-res sensors appear it can be promoted
  to a shared module.  Uses only `<glib.h>` and `<math.h>`.

### Why not NBIS?
The sensor's 64×80 px image contains ~6–8 ridge periods; `mindtct`
yields ≤2 minutiae at any upscale factor (tested 1×–8×) with
reliability ≤0.19.  This matches @benzea's assessment in
[issue #376](https://gitlab.freedesktop.org/libfprint/libfprint/-/issues/376):
*"minutiae based matching just isn't going to cut it for that image
size"*.

---

## File summary (2 commits, +5,447/−3 net)

### Commit 1 — fpi-device fix (1 file)
`g_get_monotonic_time()` instead of `g_get_real_time() / 1000`

### Commit 2 — driver + test (23 files)

New driver files (~4,400 lines):
```
libfprint/drivers/goodixtls/
  goodix.c        goodix.h          - protocol transport
  goodix511.c     goodix511.h       - GF511 device entry
  goodix5xx.c     goodix5xx.h       - 5xx scan state machine
  goodix_proto.c  goodix_proto.h    - protocol structs
  goodixtls.c     goodixtls.h       - USB + TLS base class
  sigfm.c         sigfm.h           - FAST-9/BRIEF-256 matcher
```

Test files:
```
tests/getrandom-seed.c              - LD_PRELOAD shim for deterministic gnutls_rnd()
tests/goodixtls511/custom.py        - umockdev replay test script
tests/goodixtls511/custom.pcapng    - captured USB traffic
tests/goodixtls511/device           - umockdev device description
tests/goodixtls511/README.md        - test recording instructions
```

Plus: meson integration, hwdb entry.

---

## Performance

Benchmarked on a 150-frame corpus (5 fingers × 30 captures each):

| Metric | Value |
|--------|-------|
| Effective FRR (≤5 attempts) | **0.16%** |
| Per-attempt FRR | 27.6% (comparable to other small-area sensors) |
| FAR | 0.00% |
| Score threshold | 7 |
| Enrollment stages | 20 |

Hardware-tested: 20-stage enroll, verify, identify, `fprintd`/PAM
integration (KDE login, sudo unlock).

---

## Build & test

```sh
meson setup build -Dgoodixtls=enabled
ninja -C build
meson test -C build goodixtls511   # pcap replay test
meson test -C build                # full suite — no regressions
```

---

## Checklist

- [x] `ninja -C build` — zero warnings
- [x] `meson test -C build` — no regressions
- [x] Driver replay test passes under `FP_DEVICE_EMULATION=1`
- [x] No existing driver files modified (except 1-line fpi-device fix)
- [x] C style matches upstream (GNU indent, `/* */` comments, GLib allocators)
- [x] Enroll + verify on physical hardware
- [x] LD_PRELOAD shim scoped to goodixtls511 test only
- [ ] CI green on freedesktop GitLab

---

## Relationship to prior work

This driver is a from-scratch rewrite for upstream acceptance.  The
Goodix TLS protocol knowledge, image pipeline, and the idea of a
non-minutiae matcher originate in the community effort around
[issue #376](https://gitlab.freedesktop.org/libfprint/libfprint/-/issues/376)
(Apr 2021).  The existing community driver
([0x00002a/libfprint](https://github.com/0x00002a/libfprint), `0x2a/dev/goodixtls-sigfm` branch)
could not be submitted upstream as-is: it uses OpenSSL (GNOME ecosystem
prefers GnuTLS), blocking pthreads (libfprint requires GLib async I/O),
and OpenCV + C++17 (too heavy for a single driver).  @gulp's recent
[PR #32](https://github.com/goodix-fp-linux-dev/libfprint/pull/32) for
the 5117 sensor builds on the same stack and shares the same blockers.

Changes made here to reach upstream quality:

- **OpenSSL → GnuTLS** with in-memory custom-transport callbacks
  (no socket pair, no threads).
- **pthreads → GLib async I/O** — TLS handshake driven entirely by
  `FpiSsm` state machines.
- **C++17 / OpenCV SIGFM → pure-C SIGFM** (~665 lines, FAST-9 +
  BRIEF-256, depends only on `<glib.h>` + `<math.h>`).
- **Rebased onto 1.94.9.**

---

## Acknowledgements

Based on protocol reverse-engineering by the
[goodix-fp-linux-dev](https://github.com/goodix-fp-linux-dev) community.
Individual credits are in the driver source headers (`goodixtls.c`).
