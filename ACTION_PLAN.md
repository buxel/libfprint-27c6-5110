# Action Plan — Goodix 27c6:5110 Upstream Driver

---

## Instructions for LLM Agents

This file is the **single source of truth** for what has been done and what is next.
Keep it up to date as work progresses.

**When to update this file:**
- A new document is added to `/workspace/analysis/` with findings that affect scope,
  phase ordering, implementation strategy, or known-unknowns.
- A phase is started, completed, or blocked.
- A technical decision is made that was previously listed as open.

**How to update:**
1. Read the relevant new `/workspace/analysis/` file(s) in full.
2. Reflect changed facts in the **Phase** entries below (status, notes, open questions).
3. Add a dated entry to the **Changelog** section at the bottom.
4. Do not remove completed phases — mark them ✅ and leave the summary.
5. Do not rewrite prose that is still accurate. Surgical edits only.

---

## Goal

Produce a working, distributable libfprint driver for the Goodix `27c6:5110` (GF511)
fingerprint sensor. Pure C, no OpenSSL/pthreads/OpenCV.

**Primary goal:** Publish AUR package for Arch-based distros.  
**Secondary goal:** Submit upstream MR to libfprint (optional, worth trying).

Working tree: `libfprint-fork/`  
Active branch: `goodixtls-on-1.94.9`  
GitHub: `github.com/buxel/libfprint.git`  
Upstream target: `https://gitlab.freedesktop.org/libfprint/libfprint`  
Detailed porting plan: `analysis/09-upstream-porting-plan.md`

---

## Current Status Snapshot

| Phase | Description | Status |
|-------|-------------|--------|
| 0 | Rebase fork to libfprint 1.94.9 | ✅ Done |
| 1 | NBIS viability test | ✅ Done |
| 2 | GnuTLS migration (`goodixtls.c/h`) | ✅ Done |
| 3 | SIGFM → pure-C replacement (ORB) | ✅ Done |
| 3.5 | Image preprocessing improvement | ✅ Done |
| 4 | Build system (`meson.build`) cleanup | ✅ Done |
| 5 | Thermal fix (1 line) | ✅ Done |
| 5.5 | Host fprintd integration | ✅ Done |
| 6 | AUR + Debian packaging | ✅ Done (not yet published) |
| 7 | Upstream submission | ⏳ Optional — deprioritised |
| 8 | SIGFM Phase 1 improvements | ✅ Done (FRR 90% → 0%) |
| 9 | AUR publish | ⬜ Next — primary distribution goal |
| 10 | Validation (larger corpus) | ⬜ Pending |

---

## Phase 1 — NBIS Viability Test ✅

**Verdict: NBIS is not viable. SIGFM stays as the matcher.**

The GF511 sensor produces 64×80 px images (3.2 mm × 4.0 mm physical area). At all upscale
factors (1×–6×) and all ppmm values, `mindtct` finds at most 2 minutiae (reliability ≤ 0.19).
Root cause: only ~6–8 ridge periods cross the short axis — not enough topology for any
NBIS-family detector. Bozorth3 scoring was also tested and confirmed non-functional.

Super-resolution is also not viable:
- Frame averaging: noise is not the bottleneck
- True SR: 50 µm electrode pitch is the hard spatial resolution limit
- Mosaic stitching: firmware always returns the same 64×80 area per press

**Consequence for plan:** Phase 3 is now "replace SIGFM with a pure-C keypoint matcher
(ORB)", not "drop SIGFM and use NBIS".

**Artifacts:** `nbis-test/` (test binaries + Makefile)  
**Full findings:** `analysis/10-nbis-viability-test.md`

---

## Phase 2 — GnuTLS Migration ✅ Done

**Files:** `libfprint/drivers/goodixtls/goodixtls.c` (201 lines), `goodixtls.h` (110 lines)  
**Detailed spec:** `analysis/09-upstream-porting-plan.md` §Phase 2

### What changes

| Item | Before | After |
|------|--------|-------|
| TLS library | OpenSSL (`SSL_CTX`, `BIO_s_mem`) | GnuTLS (`gnutls_session_t`) |
| Transport | Unix socket pair | Two `GByteArray` in-memory buffers |
| Threading | `pthread_t` + blocking `SSL_accept()` | No thread; `GNUTLS_E_AGAIN` loop |
| PSK callback | `SSL_CTX_set_psk_server_callback` | `gnutls_psk_set_server_credentials_function` |

### Key implementation notes

- Priority string: `"NORMAL:-VERS-ALL:+VERS-TLS1.2:-KX-ALL:+DHE-PSK:+PSK"`
- PSK key: 32-byte all-zeros (unchanged from current driver)
- Transport push/pull/pull_timeout callbacks write into / read from the byte arrays
- `gnutls_handshake()` called inline in the FpiSsm state machine; returns `GNUTLS_E_AGAIN`
  when more sensor data is needed → advance SSM state, receive next USB packet, retry
- `libgnutls28-dev` is already installed in the devcontainer
- Remove `#include <pthread.h>` from `goodix.c` after migration

### Open questions

- Confirm GnuTLS PSK-DHE cipher suite negotiation succeeds against the GF511 firmware
  (the firmware's TLS implementation is minimal; may accept only specific curves/groups)

---

## Phase 3 — SIGFM → Pure-C Keypoint Matcher ✅ Done

**Commit:** `1f27f60`  
**Deleted:** `sigfm.cpp`, `tests.cpp`, `img-info.hpp`, `binary.hpp`, `tests-embedded.hpp`  
**Added:** `sigfm.c` (656 lines, pure C, no dependencies beyond libm)

Algorithm: FAST-9 corner detection + 3×3 NMS (up to 128 kp/frame), unsteered BRIEF-256
descriptors (32 bytes), brute-force Hamming KNN with Lowe ratio test (0.75), same
geometric-consistency scorer as the C++ version (length_match=0.05, angle_match=0.05).

`ldd` confirms: `libgnutls.so.30` only — no libopencv, libssl, libcrypto, or pthread.

**Serialisation version 2** (incompatible with v1/OpenCV Mat format). Previously enrolled
prints must be deleted and re-enrolled. See Open Questions #3.

**Score threshold** may need calibration — see Open Questions #2.

---

## Phase 3.5 — Image Preprocessing Improvement ✅ Done

**Commit:** `f45853f`  
**File:** `libfprint/drivers/goodixtls/goodix5xx.c`

Replaced `goodixtls5xx_squash_frame_linear` in the scan pipeline with:

1. `goodixtls5xx_squash_frame_percentile` — P0.1→P99 histogram stretch, clipping
   outliers that caused the linear stretch to collapse dynamic range.
2. `goodixtls5xx_unsharp_mask_inplace` — 3×3 Gaussian unsharp mask
   (`out = clip(2×in − blur(in))`), sharpening ridge/valley contrast.

Calibration frame subtraction (`linear_subtract_inplace`) was already
implemented and is unchanged. The quality gate (coverage < 65%) is deferred
to hardware testing—the existing “< 25 keypoints” check in `fp-image.c`
already handles quality-based retry.

---

## Phase 4 — Build System Cleanup ✅ Done

All meaningful changes were applied across Phases 0, 2, and 3:

| Item | Status | Where |
|------|--------|-------|
| Replace `openssl`+`threads` with `gnutls >= 3.6.0` | ✅ | Phase 2 (`meson.build`) |
| `meson_options.txt` goodixtls feature option | ✅ | Phase 0 |
| Remove `opencv4` and `doctest` from `sigfm/meson.build` | ✅ | Phase 3 |
| Remove `cpp_std=c++17` | N/A | 1.94.9 never had it |
| Remove `'cpp'` from `project()` languages | N/A | `examples/cpp-test.cpp` still needs it |
| `subdir('sigfm')` + `link_with: libsigfm` | Kept | Mirrors the libnbis pattern; correct for upstream |

---

## Phase 5 — Thermal Fix ✅ Done

**File:** `libfprint/drivers/goodixtls/goodix511.c`  
**Commit:** `705b146`

Added `dev_class->temp_hot_seconds = -1;` in `fpi_device_goodixtls511_class_init()`,
following the same pattern as `goodixmoc`. Skipped the original fork's global
`DEFAULT_TEMP_HOT_SECONDS` hack.

---

## Phase 6 — AUR + Debian Packaging ✅ Done

**Files:** `packaging/aur/PKGBUILD`, `packaging/debian/debian/`  
**Full analysis:** `analysis/12-packaging-aur-debian.md`

### What was done

| Item | Details |
|------|--------|
| `meson.build` udev fix | `dependency('udev', 'libudev')` fallback at all 3 call sites — commit `7f6c089` |
| AUR PKGBUILD | `packaging/aur/PKGBUILD` — `provides`/`conflicts`/`replaces` set; 3 runtime deps only; correct `meson setup` invocation |
| Debian skeleton | `packaging/debian/debian/{control,rules,changelog,copyright,source/format}` — `debhelper-compat 13`, `Conflicts`/`Replaces`/`Provides: libfprint-2-2` |
| No Debian patch needed | udev fix already applied in-tree; `debian/patches/` not required |

### AUR (`libfprint-goodixtls511-git`)

- `provides=('libfprint' 'libfprint-2.so=2-64')` + `conflicts=('libfprint' 'libfprint-goodixtls-git')`
- `depends`: `libgusb gnutls libgudev` — 3 packages only (no opencv, openssl, doctest, nss, pixman)
- `build()`: `meson setup --prefix=/usr -Dgoodixtls=enabled -Dc_args="-Wno-error=incompatible-pointer-types"` then `ninja`
- **TODO before AUR publish:** push branch to a public remote; update `url=` in PKGBUILD; run `makepkg --printsrcinfo > .SRCINFO`

### Debian/Ubuntu

- `Build-Depends`: `libglib2.0-dev libgusb-dev libgnutls28-dev libgudev-1.0-dev libudev-dev meson ninja-build`
- `Conflicts`/`Replaces`/`Provides: libfprint-2-2` so `apt` swaps the official package cleanly
- The `udev`→`libudev` fix is in `meson.build` directly; no `debian/patches/` needed
- Build with: `dpkg-buildpackage -us -uc -b` from the source root

---

## Phase 7 — Upstream Submission ⏳ Optional

**Depends on:** All phases above complete and passing CI  
**Detailed spec:** `analysis/09-upstream-porting-plan.md` §Phase 6  
**Priority:** Secondary — AUR package (Phase 9) is the primary distribution goal.
Upstream submission is worth trying but not blocking.

### Pre-MR checklist

- [x] `meson build && ninja -C build` passes in the devcontainer
- [x] `ninja -C build test` — all existing libfprint tests pass
- [x] Enrollment + verify works on physical device (20-press enroll, verify passes)
- [x] No OpenSSL, pthreads, or OpenCV in build graph (`ldd`, `grep` deps)
- [x] `clang-format --style=file` applied to all modified C files
- [x] Commit history is clean (one logical commit per phase or squashed per component)
- [x] MR description links to goodix-fp-linux-dev repo and credits original authors
- [ ] Ask @hadess: GnuTLS dependency acceptable? (upstream now uses OpenSSL by default)
- [ ] CI green on freedesktop GitLab
- [ ] Test on 3+ standalone devices (upstream requirement — only 5110 tested so far)
- [ ] Fix `-Wno-error=incompatible-pointer-types` (pointer-signedness casts in upstream code)
- [ ] Submit `fpi-device.c` monotonic timer fix as separate upstream bug report/MR

---

## Phase 8 — SIGFM Phase 1 Improvements ✅ Done

**Fork commit:** `a0b2589`  
**Parent commit:** `1086271`  
**Full analysis:** `analysis/14-testing-and-benchmarking-strategy.md` §11

Root cause analysis identified four issues in the SIGFM matching pipeline.
All fixed, reducing FRR from 90% to 0% on a 20-frame corpus.

| Change | File | Detail |
|--------|------|--------|
| Ratio test 0.75 → 0.90 | `sigfm.c` | Fingerprints are self-similar; strict ratio kills genuine matches |
| Descriptors on original image | `sigfm.c` | Detect on blurred (stable), describe on original (discriminative) |
| NMS `>=` → `>` | `sigfm.c` | Strict local maximum, no directional bias |
| Unsharp boost 2 → 4 | `goodix5xx.c` | Generalized formula: `boost×img − (boost−1)×blur` |

**Benchmark (threshold 40, 10 enroll + 10 verify):**

| Configuration | Matches | FRR | Min Score | Mean Score |
|--------------|---------|-----|-----------|------------|
| Pre-Phase 8 | 1/10 | 90% | 0 | — |
| Post-Phase 8 | 10/10 | 0% | 47 | 473 |

**A/B testing tools built:** `tools/replay-pipeline`, `tools/sigfm-batch`,
`tools/capture-corpus.sh`. Design doc: `analysis/14-testing-and-benchmarking-strategy.md`.

---

## Phase 9 — AUR Publish ⬜ Next

**Primary distribution goal.**

### Checklist

- [x] PKGBUILD created (`packaging/aur/PKGBUILD`)
- [x] Branch pushed to public GitHub remote
- [ ] Update `url=` in PKGBUILD to point to GitHub repo
- [ ] Run `makepkg --printsrcinfo > .SRCINFO`
- [ ] Test `makepkg -si` on clean CachyOS install
- [ ] Publish to AUR as `libfprint-goodixtls511-git`
- [ ] Add post-install message: re-enrollment required (SIGFM v2 serialisation)

---

## Phase 10 — Validation ⬜ Pending

Phase 8 achieved 0% FRR on a 20-frame single-session corpus. This is promising
but insufficient to declare the driver production-quality.

### Required

- [ ] Capture 50+ frame corpus across varied conditions (pressure, placement, moisture)
- [ ] Cross-session test: re-enroll, capture verify corpus on a different day
- [ ] Re-run `sigfm-batch` on larger corpus to confirm FRR holds

### Optional

- [ ] Impostor test (second finger corpus) for FAR measurement
- [ ] Test on other 51xx VID/PID variants (5117, 5120, 521d) if hardware available

---

## Key Technical Facts (Quick Reference)

| Property | Value |
|----------|-------|
| Sensor | Goodix GF511 (die: GF3658), USB `27c6:5110` |
| Image size | 64×80 px, 508 DPI, 3.2×4.0 mm |
| Raw pixel depth | 16-bit (`guint16`), per-frame |
| Scan width (raw) | 88 columns (24 are reference electrodes, discarded) |
| Enrollment frames | 20 presses (`nr_enroll_stages = 20`) |
| Matcher | SIGFM: FAST-9 + BRIEF-256, ratio test 0.90, `score_threshold = 24` |
| Preprocessing | Percentile stretch (P0.1→P99) + unsharp mask (boost=4) |
| TLS | GnuTLS 1.2, PSK-DHE, 32-byte zero key, in-memory transport |
| Firmware string | `GF_ST411SEC_APP_12117_GF3658_ST` (same on Windows) |
| Windows algorithm | "Milan v3.02.00.15", up to 50 sub-templates, adaptive learning |
| Working tree | `libfprint-fork/` |
| GitHub | `github.com/buxel/libfprint.git` branch `goodixtls-on-1.94.9` |

---

## Open Questions

1. ~~**GnuTLS PSK-DHE compatibility**~~ — ✅ Resolved. The driver works end-to-end
   (enroll + verify on CachyOS host), confirming GnuTLS PSK-DHE negotiation succeeds
   against the GF511 firmware.
2. **Score threshold calibration** — `score_threshold = 24` works (Phase 8 min score
   was 47 at threshold 40), but hasn't been formally calibrated across diverse captures.
   Deferred until Phase 10 validation with a larger corpus.
3. **Serialisation version bump** — enrolled prints from the C++ SIFT implementation
   (v1) are incompatible with the pure-C BRIEF implementation (v2). Users must delete
   `/var/lib/fprint/` prints and re-enroll. Needs user-facing documentation in the AUR
   post-install message (Phase 9).
4. **Calibration blob format** — the Windows driver loads a 140KB per-pixel factory
   calibration blob from sensor flash. The Linux driver uses a simple background-frame
   subtraction. Need to investigate whether `goodix_read_otp()` can retrieve the factory
   blob. Deferred — current preprocessing achieves 0% FRR without it.
5. **PSK per-device vs shared** — the PSK `ba1a86...` is hardcoded. Unknown whether
   it's per-device or shared across all 27c6:5110 units. Only one device tested.
   See `analysis/08-session-findings-and-bug-fixes.md`.
6. **PSK flashing requirement** — `run_5110.py` must be run once to flash the PSK to
   the sensor. After flashing, the PSK persists in sensor flash. If a libfprint session
   crashes mid-TLS, the device stays in TLS mode and needs a plain-mode reset before
   libfprint can re-claim it. See `analysis/08-session-findings-and-bug-fixes.md` §PSK
   and Firmware, §Python Warm-up Requirement.

---

## Deferred Improvements (from doc 13 — Windows Driver Analysis)

Phase 8 achieved 0% FRR. The following improvements from `analysis/13-windows-driver-algorithm-analysis.md`
are kept in the plan until Phase 10 validation confirms the current implementation is
sufficient with a larger, cross-session corpus.

| # | Algorithm | Status | Notes |
|---|-----------|--------|-------|
| 1 | Adaptive template learning | Deferred | Most impactful remaining feature. Requires driver lifecycle plumbing. |
| 2 | Per-pixel factory calibration | Deferred (optional) | **Blocking unknown:** no command to retrieve factory kr/b blob (~140 KB) is known. Current runtime air-scan subtraction corrects offset only, not per-pixel gain. Options: USB-capture Windows session to find the command, or generate calibration from controlled ADC captures. See doc 13 §4 for corrected analysis. |
| 3 | Boost factor 4 → 10 | Deferred | Current boost=4 achieves 0% FRR. 10× may help after calibration is added. |
| 4 | Quality/coverage gating | Deferred | Only `< 25 keypoints` check exists. Easy to add if needed. |
| 5 | Hessian feature detection | Deferred | Decision gate: only if FRR > 5% after validation. Currently 0%. |
| 6 | Sub-template sorting | Deferred | Easy but low impact given current results. |
| — | Match retry | Deferred | Re-capture on first fail. Easy to add if needed. |

---

## Postponed Items

Community engagement tasks from early research. Will revisit when driver quality is
confirmed with more data.

- Join Goodix Fingerprint Linux Development Discord
- Contact @gulp about PR #32 resubmission status
- Contact @egormanga about project status
- Update Arch Wiki: fix stale `rootd/libfprint` link → `goodix-fp-linux-dev/libfprint`

---

## Known Limitations

1. **System libfprint overwritten by `pacman -Syu`** — CachyOS upgrades install the
   stock `libfprint 1.94.10` to `/usr/lib/`, overwriting the library. Current workaround:
   our `.so` is in `/usr/local/lib/` with ldconfig priority (`/etc/ld.so.conf.d/local.conf`).
   Resolved permanently by AUR package (Phase 9) or upstream merge (Phase 7).
2. **`-Wno-error=incompatible-pointer-types`** — required due to pointer-signedness
   warnings in upstream libfprint code (not in our code). Not a functional issue.
3. **Single device tested** — only one Huawei MateBook 14 AMD 2020 (27c6:5110).
   VID/PID table includes 5117, 5120, 521d but none are verified.

---

## Changelog

| Date | Change |
|------|--------|
| 2026-02-19 | Initial plan created. Phase 1 complete (NBIS not viable). Phase 3.5 added from Windows RE findings (`analysis/11`). |
| 2026-02-19 | Rebased fork from 1.94.5 (grafted) to clean 1.94.9 via transplant approach. New branch `goodixtls-on-1.94.9`. Commits: `16ea092` (transplant), `8c403f9` (monotonic time fix), `705b146` (thermal fix). Build confirmed: 109/109 targets, warnings only. Phase 5 complete. |
| 2026-02-19 | Phase 2 complete (`0d93c2a`): TLS migrated from OpenSSL+pthread to GnuTLS in-memory transport. No sockets, no threads. `ldd`: `libgnutls.so.30` only. |
| 2026-02-19 | Phase 3 complete (`1f27f60`): sigfm.cpp (OpenCV SIFT) replaced with sigfm.c (pure-C FAST-9 + BRIEF-256). opencv4/doctest deps removed. 107/107 targets. Phase 4 simultaneously complete (all build system items resolved). Score threshold calibration note added to Open Questions. |
| 2026-02-19 | Phase 3.5 complete (`f45853f`): goodix5xx.c scan pipeline now uses percentile histogram stretch (P0.1→P99) + 3×3 Gaussian unsharp mask. Calibration subtraction was already in place. Quality gate deferred to hardware testing. |
| 2026-02-19 | clang-format pass complete (`9a9f7df`): `.clang-format` added (GNU-based, 2-space, 90-col). All 12 goodixtls driver + sigfm files formatted in-place. Build clean: 68/68 targets. Phase 6 pre-MR checklist: clang-format item now complete. |
| 2026-02-19 | Test suite: 3/3 unit tests pass, 28 skipped (device-level tests need hardware). Fixed `udev-hwdb` SIGTRAP: `27c6:5110` removed from known-unsupported list in `fprint-list-udev-hwdb.c` (`a3bb0ed`). |
| 2026-02-19 | History squashed to 4 semantic commits: `811160f` (fpi-device monotonic fix), `cf77a87` (sigfm pure-C library), `7059d20` (goodixtls511 full driver), `aeb57a6` (hwdb + .clang-format). Tests still pass (0 failures). |
| 2026-02-19 | Hardware testing complete. Two bugs found and fixed (`d4df106`): (1) `fp_image_detect_minutiae_finish` SIGTRAP on SIGFM path — added `fp_image_extract_sigfm_info_finish` + dedicated `fpi_image_device_sigfm_extracted` callback; (2) double-free of `SigfmImgInfo` in `fpi_print_add_from_image` — fixed by using `sigfm_copy_info`. End-to-end: 20-stage enrollment completes, verify returns MATCH. |
| 2026-02-19 | History squashed: fix commit folded into driver commit. Final 4 commits: `811160f` (fpi-device), `cf77a87` (sigfm), `8fea0a5` (goodixtls511 driver + hw fixes), `9992fc1` (hwdb + .clang-format + autosuspend.hwdb). Tests: 3/3 pass. |
| 2026-02-19 | Two additional commits: `9399dce` (meson: libudev fallback — Phase 6), `e369029` (rename bz3_threshold→score_threshold across all drivers). `834f5f9` (autosuspend.hwdb regeneration) squashed into `9992fc1`. Final 6 commits above v1.94.9. |
| 2026-02-19 | Host fprintd integration complete: `install.sh` deployed to CachyOS host, finger enrolled via KDE fingerprint settings, used to unlock screen. End-to-end pipeline confirmed on host with fprintd 1.94.5 + our libfprint `.so`. Note: `pacman -Syu` upgrades to `libfprint 1.94.10` overwrite our `.so`; re-run `install.sh` after each upgrade until MR is merged. |
| 2026-02-19 | Phase 6 complete: AUR PKGBUILD (`packaging/aur/PKGBUILD`) and Debian skeleton (`packaging/debian/debian/`) created. meson.build patched with `dependency('udev', 'libudev')` fallback at 3 sites (commit `7f6c089`); no debian/patches needed. |
| 2026-02-21 | A/B testing infrastructure built: raw frame dump in driver (`FP_SAVE_RAW`), `tools/replay-pipeline`, `tools/sigfm-batch`, `tools/capture-corpus.sh`. 20-frame corpus captured. Design doc: `analysis/14-testing-and-benchmarking-strategy.md`. |
| 2026-02-22 | Phase 8 complete: SIGFM Phase 1 improvements. Three fixes in `sigfm.c` (ratio test, descriptor source, NMS) + unsharp boost 2→4 in `goodix5xx.c`. FRR: 90% → 0%. Fork commit `a0b2589`, parent commit `1086271`. |
| 2026-02-22 | Live sensor test passed: fprintd installed, ldconfig configured for `/usr/local/lib` priority, enroll + verify works end-to-end with Phase 8 improvements. |
| 2026-02-22 | Full action plan review. All 17 analysis docs audited for open items. Goal refocused: AUR publish is primary, upstream MR is secondary. Open Question #1 (GnuTLS PSK-DHE) resolved. Added Phases 9 (AUR publish) and 10 (validation). Community engagement items postponed. Windows algorithm improvements deferred pending Phase 10 validation. PSK flashing requirement documented (OQ #6). |