# MR: Add Goodix GF511 (27c6:5110) fingerprint sensor driver

**Branch:** `goodixtls-on-1.94.9` → `main`  
**Gitlab:** open from your freedesktop fork once pushed  
**Ping:** `@hadess` (confirmed active on related MR !32)

---

## Summary

Adds support for the Goodix GF511 capacitive fingerprint sensor
(USB ID `27c6:5110`, die GF3658), found in several Lenovo ThinkBook and
IdeaPad laptops. The driver follows the standard `FpImageDevice` pattern
and introduces **no new non-optional dependencies** beyond GnuTLS, which
is already used by other drivers in the tree.

`ldd` on the built `.so` shows `libgnutls.so.30` as the only new runtime
dependency. No OpenSSL, no pthreads, no OpenCV, no C++.

---

## Background / prior art

The driver is a clean-room port of the community driver from
[goodix-fp-linux-dev](https://github.com/goodix-fp-linux-dev),
originally authored by Théo Robineau, Alexander Meiler, Matthieu Charette,
Natasha England-Elbro, and contributors. That driver depends on OpenSSL and
OpenCV and cannot be accepted upstream as-is; this port replaces both.

---

## Architecture

```
libfprint/drivers/goodixtls/
  goodix511.c       – FpImageDevice subclass; device class init
  goodix5xx.c       – scan pipeline: USB I/O, frame assembly,
                      preprocessing, SIGFM matching
  goodix.c          – low-level FpiSsm state machine, command builder
  goodix_proto.c/h  – USB protocol framing
  goodixtls.c/h     – GnuTLS in-memory TLS 1.2 transport

libfprint/sigfm/
  sigfm.c / sigfm.h – pure-C keypoint matcher (see below)
```

### TLS layer

The sensor requires a TLS 1.2 handshake before accepting scan commands,
using PSK-DHE with a 32-byte all-zero pre-shared key. The previous
community implementation used `BIO_s_mem`/OpenSSL and a `pthread_t`; this
port uses two `GByteArray` buffers as the GnuTLS push/pull transport,
driven inline by the `FpiSsm` state machine:

- `gnutls_handshake()` returns `GNUTLS_E_AGAIN` when it needs more data
- the SSM advances to the USB-receive state, collects the next packet,
  appends it to the read buffer, then retries the handshake
- no threads, no sockets, no file descriptors

Priority string: `"NORMAL:-VERS-ALL:+VERS-TLS1.2:-KX-ALL:+DHE-PSK:+PSK"`

### Fingerprint matcher (libsigfm)

NBIS (`mindtct`) was evaluated and is not viable for this sensor: the
64×80 px (3.2×4.0 mm) image area contains only ~6–8 ridge periods on the
short axis at any upscale factor, yielding ≤2 minutiae with reliability
≤0.19. A pure-C keypoint matcher was written as a replacement for the
OpenCV SIFT-based `sigfm.cpp`:

- **Detector:** FAST-9 corners with 3×3 NMS (up to 128 kp/frame)
- **Descriptor:** unsteered BRIEF-256 (32 bytes/kp, no orientation needed
  — press sensor always presents the finger in the same orientation)
- **Matching:** brute-force k-NN (k=2), Hamming distance, Lowe ratio 0.75
- **Scoring:** same geometric-consistency scorer as the original C++
  (relative length and angle thresholds of 5%)
- **Dependencies:** only `libm` (`sqrtf`, `atan2f`)

### Image preprocessing pipeline

1. Background-calibration frame subtraction (per-frame baseline removal)
2. Percentile histogram stretch (P0.1 → P99)
3. 3×3 Gaussian unsharp mask: `out = CLAMP(2·in − blur(in), 0, 255)`

### Core libfprint changes

| File(s) | Change |
|---------|--------|
| `fp-image.c`, `fpi-image.h` | `fpi_image_get_sigfm_info()` / `fpi_image_extract_sigfm_info_finish()` — SIGFM extraction path alongside existing NBIS path |
| `fp-print.c`, `fpi-print.c` | SIGFM serialisation field (binary v2), following exactly the same pattern as the NBIS minutiae field |
| `fpi-image-device.c`, `.h` | `fpi_image_device_sigfm_extracted()` callback so the driver can report extraction results without a full dequeue cycle |
| `fpi-device.c` | `g_get_monotonic_time()` in `fpi_device_add_timeout()` (fixes non-monotonic clock on suspend/resume) |
| `meson.build` (root) | `dependency('udev', 'libudev')` fallback at three call sites for Debian/Ubuntu compatibility |
| `meson_options.txt` | `goodixtls` feature option (default: `auto`) |
| `libfprint/meson.build` | driver registration, udev hwdb entry |
| all drivers | `bz3_threshold` → `score_threshold` rename (the field was never bozorth3-specific) |

---

## Build

```sh
meson setup build \
    -Ddoc=false \
    -Dgtk-examples=false \
    -Dintrospection=false \
    -Dgoodixtls=enabled \
    -Dc_args="-Wno-error=incompatible-pointer-types"   # GCC 14+ only
ninja -C build
ninja -C build test   # 3/3 pass; ~27 device-level tests skipped (need hw)
```

`-Wno-error=incompatible-pointer-types` is needed on GCC 14+ due to
pointer-signedness warnings in upstream libfprint code (not new code in
this MR). It can be dropped when the upstream codebase is cleaned up.

---

## Testing

Tested on a Huawei MateBook 14 AMD 2020 (CachyOS, kernel 6.x):

- 20-stage enrollment completes reliably
- Verify returns MATCH; scores in the range 47–499 against threshold 24
- Finger detection (on/off) works correctly during the scan sequence
- `fprintd` integration tested: KDE fingerprint login, PAM sudo unlock
- All 3 libfprint unit tests pass

---

## Open questions / known limitations

1. **PSK is assumed shared** — the 32-byte all-zero key is hardcoded in
   the community driver and has worked across multiple units. If devices
   use per-unit keys, a provisioning step would be required (none observed
   so far).

2. **score_threshold = 24** — provisionally carried over from SIFT tuning.
   BRIEF-256 with FAST-9 may warrant a different value; empirical
   calibration across more devices would be valuable.

3. **64×80 px image size** — the sensor always returns the same frame
   area. Super-resolution and mosaic stitching were both investigated and
   found non-viable (50 µm electrode pitch is the hard spatial limit).

4. **Serialisation version 2** — incompatible with the OpenCV Mat v1
   format used by the community driver. Previously enrolled prints must
   be deleted and re-enrolled.

---

## Checklist

- [x] `ninja -C build` passes clean
- [x] `ninja -C build test` — 3/3 unit tests pass
- [x] `ldd`: `libgnutls.so.30` only — no OpenSSL, OpenCV, or pthreads
- [x] Enroll + verify tested on physical hardware
- [x] `clang-format --style=file` applied to all new/modified C files
- [x] Commit history is clean (one logical commit per component)
- [x] Copyright headers credit original authors in all new files
- [ ] CI green on freedesktop GitLab
