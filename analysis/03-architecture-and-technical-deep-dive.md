# Architecture & Technical Deep Dive

## How the Goodix 5110 Driver Stack Works

```
┌──────────────────────────────────────────────────┐
│                User Applications                  │
│          (GNOME Settings, login screen)           │
├──────────────────────────────────────────────────┤
│                   fprintd                         │
│          D-Bus daemon for fingerprint mgmt        │
├──────────────────────────────────────────────────┤
│                  libfprint                         │
│    ┌──────────────────────────────────────┐       │
│    │   goodixtls driver (community fork)    │       │
│    │   - TLS handshake with sensor MCU      │       │
│    │     (GnuTLS custom transport)           │       │
│    │   - Image capture (80×64 raw)            │       │
│    │   - Image processing (pure C)            │       │
│    │   - SIGFM matching (FAST-9+BRIEF-256)   │       │
│    └──────────────────────────────────────┘       │
├──────────────────────────────────────────────────┤
│              USB Interface (libgusb)              │
├──────────────────────────────────────────────────┤
│           Goodix 27c6:5110 Hardware               │
│       (requires firmware flash via goodix-fp-dump)│
└──────────────────────────────────────────────────┘
```

## Key Technical Components

### 1. Goodix TLS Protocol

The Goodix fingerprint sensors communicate over USB using a **TLS-encrypted channel**. This is unusual for fingerprint readers and is why standard libfprint can't support them — the protocol must be reverse-engineered.

**Key aspects:**
- Sensor has its own MCU (microcontroller unit)
- Communication is wrapped in TLS 1.2
  - **Current working tree:** GnuTLS with custom in-memory transport callbacks (no threads)
  - **0x00002a fork (original):** OpenSSL BIO pair + pthread
  - **Upstream libfprint:** Now uses OpenSSL by default (confirmed by @3v1n0, Mar 2025)
- Firmware must be extracted from a Windows driver and flashed to the sensor before Linux can communicate
- The `goodix-fp-dump` project handles the protocol RE and firmware management
- TLS cipher: `TLS_PSK_WITH_AES_128_CBC_SHA256` (PSK-based, no certificates)

### 2. Firmware Flashing (`goodix-fp-dump`)

The sensor ships configured for Windows. To use it on Linux:

1. **Extract firmware** from Windows driver (pre-packaged in [firmware submodule](https://github.com/goodix-fp-linux-dev/goodix-fp-dump/tree/master/firmware))
2. **Run the flash script** (`run_5110.py`) which:
   - Establishes USB communication
   - Performs TLS handshake
   - Uploads firmware configuration
   - Configures the sensor for Linux operation

**File of interest:** `driver_51x0.py` — the core driver for the 5110/5117 family.

### 3. Image Processing Pipeline

The 80×64 raw image from the sensor goes through several processing stages:

```
Raw capture (88×80 × 16-bit)
    │
    ▼
Calibration subtract (linear_subtract_inplace)
    │  - subtract per-pixel calibration frame in 16-bit space
    ▼
Normalise (squash_frame_linear)
    │  - per-frame min→max linear stretch → 8-bit
    ▼
Crop (crop_frame)
    │  - discard 24 guard columns (88→64 px wide)
    ▼
FpImage (64×80, 8-bit, 508 DPI)
    │
    ▼
SIGFM feature extraction (FAST-9 + BRIEF-256)
    │  - pure C, ~3ms per frame
    │  - no OpenCV dependency
    ▼
Template matching (enrollment / verification)
```

**NBIS/bozorth3 minutiae detection is non-viable** at this resolution — mindtct yields 0–2 minutiae per frame regardless of upscaling (see [10-nbis-viability-test.md](10-nbis-viability-test.md)). The **SIGFM** (Signal Feature Matching) algorithm was developed specifically to solve this. The current working tree uses a pure-C implementation (FAST-9 keypoint detector + BRIEF-256 binary descriptor); the original 0x00002a fork used C++/OpenCV SIFT.

### 4. SIGFM — Signal Feature Matching

SIGFM is a **non-minutiae fingerprint matching algorithm** designed for very low resolution sensors where NBIS cannot extract enough structural features.

**Current working tree (`goodixtls-on-1.94.9`):**
- Pure C implementation: FAST-9 keypoint detection + BRIEF-256 binary descriptors
- ~665 lines (`sigfm/sigfm.c` + `sigfm/sigfm.h`)
- No external dependencies (no OpenCV, no C++)
- License: LGPL-2.1-or-later
- Feature extraction: ~3ms per frame
- 20 frames enrolled per finger

**0x00002a/libfprint fork (original):**
- C++ implementation using OpenCV SIFT
- Required `cpp_std=c++17`, OpenCV runtime dependency
- This is the branch the AUR package (`libfprint-goodixtls-git`) still builds from

**Upstream validation:** @benzea (upstream libfprint owner, Sep 2021): *"What we really need is someone implementing an algorithm that really works well with a single frame. Minutiae based matching just isn't going to cut it for that image size."*

### 5. Build System

The project uses **Meson** as its build system (inherited from upstream libfprint).

Key build dependencies:

**Current working tree (`goodixtls-on-1.94.9`):**
- `libgudev`, `libgusb` — USB device interaction
- `gnutls` — TLS communication with sensor
- `meson` — build system

**0x00002a fork (AUR package source):**
- `libgudev`, `libgusb` — USB device interaction
- `nss` + `openssl` — TLS communication with sensor
- `pixman` — pixel manipulation
- `opencv` — image processing (**runtime dependency**)
- `cmake`, `doctest`, `meson` — build tools
- `gobject-introspection`, `gtk-doc` — documentation/introspection

### 6. Integration with fprintd

Once libfprint-goodixtls is installed (replacing system libfprint), it integrates with the standard `fprintd` D-Bus daemon:

```bash
# Enroll a finger
fprintd-enroll

# Verify
fprintd-verify

# List enrolled prints
fprintd-list $USER
```

PAM integration is available via `pam-fprint-grosshack` (AUR) for login/sudo authentication.

## Fork Lineage

```
upstream libfprint (gitlab.freedesktop.org)
    │
    ├── aryanshar/libfprint (GitHub mirror)
    │       │
    │       └── goodix-fp-linux-dev/libfprint  ← Primary community fork
    │               │
    │               ├── rootd/libfprint  ← Referenced in Arch Wiki (⚠️ STALE: 12 behind, 4yr old)
    │               │
    │               ├── 0x00002a/libfprint  ← sigfm branch, AUR source
    │               │       branch: 0x2a/dev/goodixtls-sigfm
    │               │       228 commits ahead, 23 behind
    │               │
    │               ├── gulp/libfprint-1  ← PR #32 author (active Jan 2026)
    │               │
    │               └── d-k-bo/libfprint  ← Fedora COPR (abandoned)
    │                       branch: copr (spec file)
    │                       branch: 55b4-experimental
    │
    ├── Infinytum/libfprint  ← Intermediate fork by @nilathedragon
    │       │
    │       ├── kase1111-hash/libfprint-goodix-521d-gcc15  ← GCC 15 fix (last month)
    │       └── bertin0/libfprint-sigfm  ← Stale SIGFM fork (5yr old)
    │
    └── goodix-fp-linux-dev/goodix-fp-dump  ← Companion firmware tool
            Last meaningful commit: May 2023
            5110 flash fix (PR #29): Nov 2022 — stable
```

## TOD vs goodixtls Architecture

Two fundamentally different architectures exist for Goodix sensors on Linux:

```
TOD (Touch Other Device) — Proprietary Path
──────────────────────────────────────────
┌──────────────────────────────────────────┐
│             fprintd / libfprint-tod            │
│     (modified libfprint with plugin support)    │
├──────────────────────────────────────────┤
│   Vendor binary blob (.so plugin)               │
│   e.g. Dell blob from dell.archive.canonical.com│
└──────────────────────────────────────────┘
↑ Used by: 27c6:533c (Dell XPS), 27c6:550a (Lenovo)
✗ NOT available for 27c6:5110 (no Huawei blob exists)


goodixtls — Open-Source Path
──────────────────────────────────────────
┌──────────────────────────────────────────┐
│             fprintd / libfprint (fork)           │
│     (community fork with goodixtls driver)       │
├──────────────────────────────────────────┤
│   Reverse-engineered TLS protocol + SIGFM        │
│   Pure-C FAST-9+BRIEF-256, GnuTLS transport     │
└──────────────────────────────────────────┘
↑ Used by: 27c6:5110, 5117, 5120, 521d (MOH sensors)
✓ The ONLY option for 5110
```

## Sources

- [goodix-fp-dump repository structure](https://github.com/goodix-fp-linux-dev/goodix-fp-dump)
- [0x00002a/libfprint sigfm branch](https://github.com/0x00002a/libfprint/tree/0x2a/dev/goodixtls-sigfm)
- [AUR PKGBUILD dependencies](https://aur.archlinux.org/packages/libfprint-goodixtls-git)
- [d-k-bo RPM spec file](https://github.com/d-k-bo/libfprint/blob/copr/libfprint.spec)
