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
│    │   goodixtls driver (community fork)  │       │
│    │   - TLS handshake with sensor MCU    │       │
│    │   - Image capture (80×64 raw)        │       │
│    │   - Image processing (OpenCV)        │       │
│    │   - Minutiae detection (NBIS/sigfm)  │       │
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
- Communication is wrapped in TLS 1.2 (using OpenSSL/NSS)
- Firmware must be extracted from a Windows driver and flashed to the sensor before Linux can communicate
- The `goodix-fp-dump` project handles the protocol RE and firmware management

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
Raw capture (80×64)
    │
    ▼
Preprocessing (preprocessor.py / OpenCV in libfprint)
    │  - Cropping
    │  - Thresholding
    │  - Mean filtering
    ▼
Minutiae extraction (NBIS bozorth3 / sigfm)
    │
    ▼
Template matching (enrollment / verification)
```

**The OpenCV dependency is critical** — it handles image enhancement that makes the low-resolution captures usable. The `sigfm` (signal feature matching) approach in 0x00002a's fork was developed specifically because standard minutiae extraction (NBIS/bozorth3) struggles with 80×64 images.

### 4. The `sigfm` Branch (0x00002a)

The `0x2a/dev/goodixtls-sigfm` branch (228 commits ahead of the main community fork) represents the most advanced development:

- **Signal Feature Matching:** Alternative to minutiae-based matching that works better at very low resolutions
- **OpenCV integration:** Uses OpenCV for image processing at the C level within libfprint
- **This is the branch the AUR package builds from**

### 5. Build System

The project uses **Meson** as its build system (inherited from upstream libfprint).

Key build dependencies (from AUR PKGBUILD):
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
│     (community fork with goodixtls driver)      │
├──────────────────────────────────────────┤
│   Reverse-engineered TLS protocol + SIGFM        │
│   OpenCV image processing + custom matching      │
└──────────────────────────────────────────┘
↑ Used by: 27c6:5110, 5117, 5120, 521d (MOH sensors)
✓ The ONLY option for 5110
```

## Sources

- [goodix-fp-dump repository structure](https://github.com/goodix-fp-linux-dev/goodix-fp-dump)
- [0x00002a/libfprint sigfm branch](https://github.com/0x00002a/libfprint/tree/0x2a/dev/goodixtls-sigfm)
- [AUR PKGBUILD dependencies](https://aur.archlinux.org/packages/libfprint-goodixtls-git)
- [d-k-bo RPM spec file](https://github.com/d-k-bo/libfprint/blob/copr/libfprint.spec)
