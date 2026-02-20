# 04 — Upstream libfprint & goodixtls Fork Research

**Date:** 2026-02-16  
**Purpose:** Inform implementation strategy by understanding the current state of upstream libfprint and the goodixtls community driver fork.

---

## URL Fetch Results Summary

| # | URL | Accessible? | Notes |
|---|-----|-------------|-------|
| 1 | gitlab.freedesktop.org/.../drivers | **NO** — blocked by Anubis bot protection | Used goodix-fp-linux-dev/libfprint GitHub fork (based on upstream ~1.94.5) instead |
| 2 | github.com/0x00002a/libfprint/.../goodixtls | **YES** | Full directory listing obtained |
| 3 | github.com/0x00002a/libfprint/.../goodixtls.h | **YES** | Full header content obtained |
| 4 | github.com/0x00002a/libfprint/.../meson.build (root) | **YES** | Version and build config obtained |
| 5 | gitlab.freedesktop.org/.../tags | **NO** — Anubis blocked | Used Repology.org instead — latest upstream: **1.94.10** |
| 6 | github.com/goodix-fp-linux-dev/.../goodixtls/meson.build | **404** — no separate meson.build for the driver dir | Driver sources are in `libfprint/meson.build` |
| 7 | raw.githubusercontent.com/0x00002a/.../goodixtls/meson.build | **404** — same reason | No per-driver meson.build exists |

---

## 1. Upstream libfprint Version

- **Latest upstream release: `1.94.10`** (Arch Linux, Debian Unstable, Fedora Rawhide, openSUSE Tumbleweed, Ubuntu 26.04)
- Source: Repology.org cross-distro package tracker
- GitLab (freedesktop.org) is protected by Anubis JavaScript challenge and cannot be fetched programmatically

## 2. Fork Base Version

### goodix-fp-linux-dev/libfprint (community org fork)
- **Version: `1.94.5`** (from root `meson.build`: `version: '1.94.5'`)
- Forked from `aryanshar/libfprint`
- Last activity: ~4 years ago
- **Does NOT include goodixtls driver on master branch** — the `libfprint/drivers/` directory has no `goodixtls` folder
- Default drivers list matches upstream 1.94.5 (no goodixtls)

### 0x00002a/libfprint (sigfm fork, branch `0x2a/dev/goodixtls-sigfm`)
- **Version: `1.94.5`** (same base)
- Forked from goodix-fp-linux-dev/libfprint
- **228 commits ahead, 23 commits behind** goodix-fp-linux-dev:master
- Last activity: ~3 years ago
- **This is the fork that actually has the goodixtls driver**
- Also adds `sigfm` (signal fingerprint matching) — a C++ component
- Adds `cpp_std=c++17` to build config and OpenSSL + threads dependencies

### Version Gap
- Fork is based on **1.94.5**, upstream is at **1.94.10**
- That's **5 point releases behind** — significant but not catastrophic
- The 1.94.x series appears to be the long-term stable line (no 2.x exists)

---

## 3. goodixtls Driver File Listing

The `goodixtls` driver consists of **10 files** in `libfprint/drivers/goodixtls/`:

| File | Lines | Size | Purpose |
|------|-------|------|---------|
| `goodix.c` | — | — | Core Goodix USB communication layer (packet send/receive, USB loop) |
| `goodix.h` | 570 lines | 20.1 KB | Main header — defines Goodix protocol API (send commands, TLS, image read) |
| `goodix511.c` | — | — | Device-specific driver for the 511 sensor (27c6:5110, 80x64 resolution) |
| `goodix511.h` | 65 lines | 3.18 KB | 511-specific header |
| `goodix5xx.c` | — | — | Common code for all 5xx-series USB devices |
| `goodix5xx.h` | 261 lines | 8.08 KB | 5xx API — abstraction layer over goodix.c for 5xx devices |
| `goodix_proto.c` | — | — | Protocol encoding/decoding (packet framing, checksums) |
| `goodix_proto.h` | 171 lines | 5.17 KB | Protocol structures and constants |
| `goodixtls.c` | — | — | TLS server implementation (OpenSSL-based, local socket pair) |
| `goodixtls.h` | 109 lines | 3.72 KB | TLS server structure and API |

**Total: 10 files (5 .c + 5 .h)**

---

## 4. Driver Architecture (Layered)

The driver has a clean **layered architecture**:

```
┌─────────────────────────────────┐
│         goodix511.c             │ ← Device-specific (sensor config, image processing)
│  FpiDeviceGoodixTls511          │   Implements FpImageDeviceClass
├─────────────────────────────────┤
│         goodix5xx.c/.h          │ ← 5xx-family common layer
│  FpiDeviceGoodixTls5xx          │   Scan management, frame decode, TLS init
│  (GObject subclass)             │   Provides hooks: get_mcu_cfg, process_frame
├─────────────────────────────────┤
│         goodix.c/.h             │ ← Core Goodix protocol layer
│  FpiDeviceGoodixTls             │   USB communication, packet send/receive
│  (GObject subclass)             │   Commands: firmware query, MCU state, FDT, etc.
├─────────────────────────────────┤
│     goodix_proto.c/.h           │ ← Protocol layer (packet framing)
├─────────────────────────────────┤
│     goodixtls.c/.h              │ ← TLS layer (OpenSSL socket pair)
│     GoodixTlsServer             │   Decrypts sensor data
└─────────────────────────────────┘
```

### Inheritance Chain (GObject)
```
FpDevice → FpImageDevice → FpiDeviceGoodixTls → FpiDeviceGoodixTls5xx → FpiDeviceGoodixTls511
```

---

## 5. Build System Integration

### How the driver is registered in the build
There is **no separate `meson.build` per driver**. Instead, everything is in `libfprint/meson.build`:

```meson
# Driver-specific source (just the device-specific file)
driver_sources = {
    ...
    'goodixtls511' : [ 'drivers/goodixtls/goodix511.c' ],
    ...
}

# Helper/shared sources (the bulk of the driver)
helper_sources = {
    ...
    'goodixtls' : [
        'drivers/goodixtls/goodix_proto.c',
        'drivers/goodixtls/goodix.c',
        'drivers/goodixtls/goodixtls.c',
        'drivers/goodixtls/goodix5xx.c'
    ],
    ...
}
```

The driver is split into:
- **`driver_sources['goodixtls511']`** — just `goodix511.c` (device-specific)
- **`helper_sources['goodixtls']`** — 4 shared files (protocol, USB, TLS, 5xx common)

### Root meson.build driver list (0x00002a fork)
```meson
default_drivers = [
    ... (standard upstream drivers) ...
    'goodixmoc',
    'goodixtls511',   # ← ADDED by the fork
    'nb1010',
    'fpcmoc',
    'elanspi',
]
```

### External Dependencies Added
```meson
# In root meson.build, for the 'goodixtls' helper:
openssl_dep = dependency('openssl', required: false)
threads_dep = dependency('threads', required: false)
```

---

## 6. Upstream Driver Structure (for comparison)

From the goodix-fp-linux-dev/libfprint fork (mirrors upstream ~1.94.5), the `drivers/` directory contains:

### Subdirectory-based drivers (like goodixtls):
| Driver | Structure |
|--------|-----------|
| `elanmoc/` | Directory with own files |
| `fpcmoc/` | Directory with own files |
| `goodixmoc/` | Directory: `goodix.c`, `goodix_proto.c` |
| `synaptics/` | Directory: `synaptics.c`, `bmkt_message.c` |

### Single-file drivers (majority):
`aes1610.c`, `aes1660.c/.h`, `aes2501.c/.h`, `aes2550.c/.h`, `aes2660.c/.h`, `aes3500.c`, `aes4000.c`, `egis0570.c/.h`, `elan.c/.h`, `elanspi.c/.h`, `etes603.c`, `nb1010.c`, `upekts.c`, `upeksonly.c/.h`, `upektc.c/.h`, `upektc_img.c/.h`, `uru4000.c`, `vcom5s.c`, `vfs0050.c/.h`, `vfs101.c`, `vfs301.c/.h`, `vfs5011.c`, `vfs7552.c`, `virtual-*.c`

### Helper/shared modules:
`aeslib.c/.h`, `aesx660.c/.h`, `aes3k.c/.h`, `upek_proto.c/.h`, `virtual-device-listener.c`, `virtual-device-private.h`

**Pattern**: The `driver_sources` / `helper_sources` split is the standard upstream pattern. Goodixtls follows this pattern correctly.

---

## 7. Key Interface Dependencies on libfprint Internals

The goodixtls driver uses these libfprint APIs:

| API | Header | Coupling Level |
|-----|--------|---------------|
| `FpImageDevice` / `FpImageDeviceClass` | `fpi-image-device.h` | **Standard** — same as all image drivers |
| `FpDevice` | `fpi-device.h` | **Standard** |
| `FpiSsm` (state machine) | `fpi-ssm.h` | **Standard** — used by most drivers |
| `FpiUsbTransfer` | `fpi-usb-transfer.h` | **Standard** — used by all USB drivers |
| `fpi_image_device_*` functions | `fpi-image-device.h` | **Standard** |
| `FpImage` | `fpi-image.h` | **Standard** — for image submission |
| GLib/GObject | System | External |
| OpenSSL | System | **External** — unique to this driver |
| pthreads | System | **External** — for TLS socket pair |

### Assessment: The driver is **NOT** deeply entangled with libfprint internals. 
It uses only the standard driver API (`FpImageDevice`, `FpiSsm`, `FpiUsbTransfer`). The TLS and protocol layers are entirely self-contained.

---

## 8. The sigfm Addition (0x00002a fork only)

The `0x2a/dev/goodixtls-sigfm` branch adds a **`sigfm`** (Signal Fingerprint Matching) subsystem:

| File | Purpose |
|------|---------|
| `sigfm/sigfm.h` | C API header |
| `sigfm/sigfm.cpp` | C++ implementation |
| `sigfm/binary.hpp` | Binary serialization |
| `sigfm/img-info.hpp` | Image metadata |
| `sigfm/tests.cpp` | Embedded tests |
| `sigfm/tests-embedded.hpp` | Test helpers |
| `sigfm/meson.build` | Build integration |

This is a **separate concern** from the goodixtls driver itself — it's an alternative fingerprint matching approach. It's written in C++ (requiring `cpp_std=c++17`) and is linked as `libsigfm`.

**For porting the goodixtls driver, sigfm is NOT required.** It's an optional enhancement specific to the 0x00002a fork.

---

## 9. Conclusions for Implementation Strategy

### Driver Self-Containment: **HIGH**
- 10 files, all in `drivers/goodixtls/`
- Clean layered architecture with well-defined boundaries
- Uses only standard libfprint driver APIs
- External deps: OpenSSL + pthreads (both widely available)
- No sigfm dependency for basic operation

### Portability to Current Upstream: **FEASIBLE but requires work**
- Fork is 5 releases behind (1.94.5 → 1.94.10)
- The driver API surface used is stable (`FpImageDevice`, `FpiSsm`, etc.)
- Meson build integration follows upstream patterns exactly
- Main risk: subtle API changes in `fpi-*.h` private headers between versions

### Options for Integration:
1. **Rebase onto upstream 1.94.10** — Port the 10 driver files + add to `libfprint/meson.build` and root `meson.build`
2. **Use as-is with the fork** — Ship the fork's libfprint 1.94.5 (older but known-working)
3. **Standalone out-of-tree driver** — Would require significant refactoring since the GObject type registration is done at build time via `fpi-drivers.c` generation

### Critical Missing Piece:
The goodix-fp-linux-dev/libfprint **master branch does NOT contain the goodixtls driver**. The driver only exists in the 0x00002a fork's `0x2a/dev/goodixtls-sigfm` branch. This means the "community" driver never made it back to the main community org.
