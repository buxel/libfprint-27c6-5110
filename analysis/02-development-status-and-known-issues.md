# Development Status & Known Issues

## Overall Assessment

**The Goodix `27c6:5110` Linux driver is functional but experimental.** While the core repos had no commits for ~3 years, **development resumed in January 2026** with [PR #32](https://github.com/goodix-fp-linux-dev/libfprint/pull/32) adding `27c6:5117` support (same sensor family). Notably, **@hadess (Bastien Nocera), the upstream libfprint maintainer, is a participant** on that PR — a positive signal for potential upstream acceptance. The community effort has not reached upstream quality yet but is showing signs of renewed activity.

## Timeline of Development

| Date | Event |
|---|---|
| ~2020–2021 | Reverse engineering of Goodix TLS protocol begins (goodix-fp-dump) |
| 2021-06-04 | [PR #1](https://github.com/goodix-fp-linux-dev/libfprint/pull/1): @rootd renames goodix5110 to goodixtls, implements OpenSSL linking |
| 2021-06-15 | [PR #2](https://github.com/goodix-fp-linux-dev/libfprint/pull/2): @mpi3d adds goodixmoc PID 6A94 |
| ~2021 | Protocol drivers for various Goodix sensors created (5110, 5117, 5120, 521d, 532d, etc.) |
| **2022-06-13** | **[PR #10](https://github.com/goodix-fp-linux-dev/libfprint/pull/10): @0x00002a implements full 5110 image capture** — merged (37 commits, +1245/-367 lines). This is the foundational PR that made 5110 fingerprint reading actually work in libfprint: TLS handshake, image decoding, noise reduction, fprintd integration. |
| 2022-11-06 | AUR package [`libfprint-goodixtls-git`](https://aur.archlinux.org/packages/libfprint-goodixtls-git) submitted by voidstar |
| 2022-11-07 | Fedora [COPR repo created](https://discussion.fedoraproject.org/t/d-k-bo-libfprint-goodixtls/43849/1) by d-k-bo |
| 2022-11-09 | [PR #13](https://github.com/goodix-fp-linux-dev/libfprint/pull/13) + [PR #14](https://github.com/goodix-fp-linux-dev/libfprint/pull/14): @0x00002a misc fixes for goodix511 + finger-up detection |
| 2022-11-11 | [PR #15](https://github.com/goodix-fp-linux-dev/libfprint/pull/15): @0x00002a implements general goodix5xx API — merged Dec 28. @mpi3d notes *"we are far from a merge with libfprint. There are still a lot of things to implement."* |
| 2022-11-27 | User [aleemont confirms](https://aur.archlinux.org/packages/libfprint-goodixtls-git) working on Huawei MateBook 14 2020 with Goodix 5110 |
| 2022-12-29 | [Issue #22](https://github.com/goodix-fp-linux-dev/libfprint/issues/22): Rebase onto upstream libfprint — completed via [PR #26](https://github.com/goodix-fp-linux-dev/libfprint/pull/26) + [PR #27](https://github.com/goodix-fp-linux-dev/libfprint/pull/27) |
| 2023-01-20 | voidstar commits change to image processing, requires re-enrollment |
| 2023-03-15 | d-k-bo discusses build issues with loveisfoss on Fedora Discussion |
| 2024-01-07 | User [on-fedelity reports](https://discussion.fedoraproject.org/t/d-k-bo-libfprint-goodixtls/43849/19) **"Failed to detect minutiae"** errors on Fedora 39 — potential OpenCV breakage |
| 2024-10-22 | **d-k-bo officially abandons** the Fedora COPR repo: *"I don't really use this fingerprint sensor anymore and I'm not interested in working on this anymore"* ([source](https://discussion.fedoraproject.org/t/d-k-bo-libfprint-goodixtls/43849/22)) |
| 2024-12-14 | AUR comment: opencv should be in `depends` not `makedepends` (runtime dependency) |
| 2025-02 | Issue [#33](https://github.com/goodix-fp-linux-dev/libfprint/issues/33) opened requesting support for `27c6:5130` (similar Huawei MateBook sensor) |
| 2025-07 | Issue [#54](https://github.com/goodix-fp-linux-dev/goodix-fp-dump/issues/54) on goodix-fp-dump asks for updates |
| 2025-10-28 | [Issue #31](https://github.com/goodix-fp-linux-dev/libfprint/issues/31): User tries 5117 on Ubuntu, uses wrong repo (official libfprint). @egormanga clarifies: **5xxx chips are "MOH" (not MOC), `goodixmoc` driver does NOT work for them.** Closed as not planned. |
| **2026-01-09** | **[PR #32](https://github.com/goodix-fp-linux-dev/libfprint/pull/32): @gulp submits 27c6:5117 support** (MateBook 13 2021). Confirms SIGFM is required. Reviewed by @egormanga. @hadess (upstream maintainer) is a participant. Closed by author to fix accidental 5110 removal — likely to be resubmitted. |

## Known Issues & Caveats

### 1. "Failed to detect minutiae" Error ⚠️ HIGH PRIORITY

**Symptoms:** `fprintd-enroll` captures images but fails with `"Failed to detect minutiae: No minutiae found"`.

**Reported:** [Fedora Discussion, Jan 2024](https://discussion.fedoraproject.org/t/d-k-bo-libfprint-goodixtls/43849/19) by on-fedelity on Fedora 39.

**Probable Cause:** Standard NBIS minutiae detection simply does not work at this resolution. The SIGFM algorithm was designed specifically to solve this, but users may be running builds without SIGFM enabled, or OpenCV API changes broke the image enhancement pipeline.

**Evidence:**
- `goodix-fp-dump` can still capture valid images independently
- The error occurs in the libfprint minutiae detection stage
- The sensor resolution (80×64) is very low, making minutiae extraction fragile
- An OpenCV version change coincides with reports of failure
- **[PR #32](https://github.com/goodix-fp-linux-dev/libfprint/pull/32) (Jan 2026) explicitly confirms:** *"Without SIGFM, the NBIS minutiae detector fails with 'No minutiae found' due to the low resolution"* — tested on the similar 5117 sensor (80×88)

**Impact:** This may be the **primary blocker** for using the AUR package on a modern CachyOS install.

### 2. Device Firmware Flashing Requirement

Before the driver works, the device must be "flashed" using [goodix-fp-dump](https://github.com/goodix-fp-linux-dev/goodix-fp-dump):

```bash
python --version  # Must be Python 3.10 or newer
git clone --recurse-submodules https://github.com/goodix-fp-linux-dev/goodix-fp-dump.git
cd goodix-fp-dump
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
sudo python3 run_5110.py
```

**Warning from upstream:** *"We do not recommend using this for now. This is very unstable."*

**Risk:** Flashing could potentially brick the sensor if something goes wrong. However, users have reported success on the exact target device (MateBook 14 2020).

### 3. Very Low Sensor Resolution

The Goodix `27c6:5110` captures at **80×64 pixels** — extremely low for fingerprint matching. This means:
- Minutiae extraction is inherently unreliable
- The 0x00002a/libfprint fork added `sigfm` (signal feature matching) as an alternative to standard minutiae-based matching
- Image preprocessing (OpenCV-dependent) is critical to get usable data

### 4. Package Dependency Issue

The [AUR package](https://aur.archlinux.org/packages/libfprint-goodixtls-git) lists `opencv` as a **makedepend** but it is actually a **runtime dependency** ([comment from ujhhgtg, Dec 2024](https://aur.archlinux.org/packages/libfprint-goodixtls-git)). OpenCV must be installed for the driver to function.

### 5. Conflicts with System libfprint

The AUR package:
- **Conflicts with:** `libfprint` (the official package)
- **Provides:** `libfprint`, `libfprint-2.so`

This means installing it **replaces** the system libfprint. Any official updates to libfprint will be blocked until this package is removed.

### 6. Re-enrollment After Updates

voidstar [noted (Jan 2023)](https://aur.archlinux.org/packages/libfprint-goodixtls-git) that image processing changes require re-enrollment of fingerprints.

### 7. Upstream Path — New Signal

There is no formal merge request on [gitlab.freedesktop.org](https://gitlab.freedesktop.org/libfprint/libfprint) yet, **but @hadess (Bastien Nocera), the upstream libfprint maintainer, appeared as a participant on [PR #32](https://github.com/goodix-fp-linux-dev/libfprint/pull/32) (Jan 2026)**. This is a potentially significant signal that upstream may be open to reviewing Goodix TLS support if the code is brought up to standard.

### 8. GCC 15 Compilation Failure ⚠️ CachyOS-SPECIFIC

**Symptoms:** Build fails with "incompatible pointer type errors" in `libfprint/drivers/goodixtls/` when compiling with GCC 15.

**Evidence:** [kase1111-hash/libfprint-goodix-521d-gcc15](https://github.com/kase1111-hash/libfprint-goodix-521d-gcc15) (created last month) fixes this for the 521d driver. The fix targets the `goodix_tls_read_image` function and address-of operator usage in the shared goodixtls code.

**CachyOS relevance:** CachyOS tracks bleeding-edge compiler versions. If GCC 15 is the default (or becomes default), the AUR package `libfprint-goodixtls-git` will likely fail to build. The 5110 and 521d drivers share substantial code in the `goodixtls` driver family.

**Mitigation:** Cherry-pick the fix from `kase1111-hash`'s fork, or compile with `-Wno-error=incompatible-pointer-types` as a temporary workaround.

**See also:** [05-internet-research-findings.md](05-internet-research-findings.md#key-finding-2-gcc-15-compatibility-issue-%EF%B8%8F)

## Repository Health Summary

| Repository | Last Meaningful Commit | Open Issues | Activity Level |
|---|---|---|---|
| goodix-fp-linux-dev/libfprint | **Jan 2026** ([PR #32](https://github.com/goodix-fp-linux-dev/libfprint/pull/32)) | 2 | 🟡 Reviving |
| goodix-fp-linux-dev/goodix-fp-dump | **May 30, 2023** (firmware submodule update by @mpi3d) | 5 | 🔴 Dormant — 5110 flash code stable since Nov 2022 (PR #29) |
| 0x00002a/libfprint | ~3 years ago | N/A | 🔴 Dormant |
| AUR package | 2022-11-16 (last update) | N/A | 🟡 Maintained (minimally) |

## Sources

- [Fedora Discussion: on-fedelity's bug report](https://discussion.fedoraproject.org/t/d-k-bo-libfprint-goodixtls/43849/19)
- [Fedora Discussion: d-k-bo's abandonment notice](https://discussion.fedoraproject.org/t/d-k-bo-libfprint-goodixtls/43849/22)
- [AUR: libfprint-goodixtls-git comments](https://aur.archlinux.org/packages/libfprint-goodixtls-git)
- [goodix-fp-dump README warnings](https://github.com/goodix-fp-linux-dev/goodix-fp-dump#how-to-use-it)
- [0x00002a/libfprint README](https://github.com/0x00002a/libfprint/tree/0x2a/dev/goodixtls-sigfm)
- [goodix-fp-linux-dev/libfprint issues](https://github.com/goodix-fp-linux-dev/libfprint/issues)
