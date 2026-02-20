# Research: Threads to Pull — Goodix 27c6:5110

> **Living task tracker:** See [`/workspace/ACTION_PLAN.md`](/workspace/ACTION_PLAN.md) for current phase status, pre-MR checklist, and changelog.

---

## Quick-Start Path (Try Existing AUR Package)

This is the fastest path to test if the fingerprint reader works on CachyOS.

### Prerequisites
1. CachyOS installed on the MateBook 14 AMD (2020)
2. Verify device presence: `lsusb | grep 27c6:5110`

### Step 1: Flash the Sensor Firmware

```bash
# Install Python 3.10+
sudo pacman -S python python-pip git

# Clone and run goodix-fp-dump
git clone --recurse-submodules https://github.com/goodix-fp-linux-dev/goodix-fp-dump.git
cd goodix-fp-dump
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Flash the 5110 sensor (use .venv path to avoid root breaking venv — tip from Discord)
sudo .venv/bin/python3 run_5110.py
```

### Step 2: Install the AUR Package

```bash
# Using yay or paru (CachyOS has paru by default)
paru -S libfprint-goodixtls-git

# Also ensure opencv is installed (runtime dependency)
sudo pacman -S opencv

# Install fprintd
sudo pacman -S fprintd
```

### Step 3: Enroll & Test

```bash
# Enroll a fingerprint
fprintd-enroll

# Test verification
fprintd-verify
```

### What to Watch For

- **"Failed to detect minutiae"** — This is the [known OpenCV issue](#thread-1). See Thread 1 below.
- **USB claim errors** — Check `journalctl -xe` for USB interface issues.
- **Sensor not detected** — May need firmware re-flash or reboot.

---

## Threads to Pull

### Thread 1: OpenCV / SIGFM Minutiae Detection Failure � MEDIUM RISK

**The Problem:** Users reported `fprintd-enroll` fails with `"Failed to detect minutiae: No minutiae found"`. [PR #32](https://github.com/goodix-fp-linux-dev/libfprint/pull/32) (Jan 2026) confirmed the root cause: **NBIS minutiae detection fundamentally cannot work at 80×64 resolution. The SIGFM algorithm is required.**

**CachyOS-specific risk is lower than initially thought:** The Fedora COPR build (d-k-bo) may have been using a branch without SIGFM enabled, which would explain the failure. The AUR package builds from the `0x2a/dev/goodixtls-sigfm` branch which **does include SIGFM**. The 5110 image capture pipeline was implemented in [PR #10](https://github.com/goodix-fp-linux-dev/libfprint/pull/10) (Jun 2022) by @0x00002a, and SIGFM was layered on top of that work. So the AUR build should have the correct matching algorithm.

**Remaining risk:** OpenCV API changes could still break the image *preprocessing* that feeds SIGFM, even if SIGFM itself is enabled.

**Reported:** [Fedora Discussion, Jan 2024](https://discussion.fedoraproject.org/t/d-k-bo-libfprint-goodixtls/43849/19) by on-fedelity on Fedora 39.

**Investigation Steps:**
1. Install the AUR package and test — does the error reproduce?
2. If yes, check the OpenCV version on CachyOS: `pacman -Q opencv`
3. Compare with the version known to work (OpenCV 4.6.x timeframe — late 2022)
4. Examine the `sigfm` code in [0x00002a/libfprint](https://github.com/0x00002a/libfprint/tree/0x2a/dev/goodixtls-sigfm) for OpenCV API calls
5. Search for deprecated/changed OpenCV functions (likely in `libfprint/drivers/goodixtls/` directory)

**Potential Fix:** Track down the specific OpenCV API break and patch the driver. This is likely a small, targeted fix (e.g. function signature change, removed function, changed return type).

**Difficulty:** Medium — requires C knowledge and understanding of OpenCV's C API changes.

---

### Thread 2: Rebase onto Modern libfprint 🟡 IMPORTANT

**The Problem:** The community fork is based on libfprint from ~4 years ago. Upstream libfprint has continued development with new device support, bug fixes, and API improvements.

**History:** A rebase was already performed once in Dec 2022 ([Issue #22](https://github.com/goodix-fp-linux-dev/libfprint/issues/22), resolved via [PR #26](https://github.com/goodix-fp-linux-dev/libfprint/pull/26) + [PR #27](https://github.com/goodix-fp-linux-dev/libfprint/pull/27)). At that time, @mpi3d noted: *"we are far from a merge with libfprint. There are still a lot of things to implement."* Another 3+ years have passed since.

**Important terminology:** @egormanga clarified in [Issue #31](https://github.com/goodix-fp-linux-dev/libfprint/issues/31) that 5xxx sensors are **MOH** (Match-on-Host), not MOC (Match-on-Chip). The upstream `goodixmoc` driver only handles 6xxx series. This means the goodixtls driver is fundamentally different code, which may make rebasing less conflict-prone (it's largely self-contained).

**Investigation Steps:**
1. Identify the upstream libfprint version the fork diverged from
2. Compare with current upstream (likely 1.94.x → now likely 1.96+)
3. Assess merge conflicts — the goodixtls driver is largely self-contained in `libfprint/drivers/goodixtls/`
4. Consider whether the driver can be structured as a standalone plugin

**Difficulty:** Hard — requires understanding of libfprint internals and careful conflict resolution.

---

### Thread 3: Discord Community 🟢 QUICK WIN

**Action:** Join the [Goodix Fingerprint Linux Development Discord](https://discord.com/invite/6xZ6k34Vqg) to:
- Check if there's any unpublished progress
- Ask about the OpenCV issue
- Gauge interest in continued development
- Connect with [@mpi3d](https://github.com/mpi3d), [@0x00002a](https://github.com/0x00002a), and other contributors

---

### Thread 4: PR #32 — Active 5117 Development 🟢 HIGH PRIORITY

[PR #32](https://github.com/goodix-fp-linux-dev/libfprint/pull/32) (opened Jan 9, 2026 by [@gulp](https://github.com/gulp)) is the most significant recent activity:

- **Adds 27c6:5117 support** (Huawei MateBook 13 2021, 80×88 sensor) — same 51x0 family as your 5110
- **Confirms SIGFM is mandatory** for low-res sensors
- **Reviewed by @egormanga** (project member)
- **@hadess (Bastien Nocera, upstream libfprint maintainer) is a participant** — huge signal
- Closed by author to fix accidental 5110 removal; likely to be resubmitted
- Tested on Arch Linux (Omarchy)

**Actions:**
1. Watch the PR for a resubmission
2. Contact @gulp — they are actively working on the same sensor family right now
3. Offer to test on the 5110 when the corrected PR lands
4. @hadess's involvement suggests an upstream path may be viable

---

### Thread 5: Alternative Approach — goodix-fp-dump Standalone 🟡 FALLBACK

If the libfprint integration is too broken, `goodix-fp-dump` itself can capture valid fingerprint images. A fallback approach would be:

1. Use `goodix-fp-dump` to verify the sensor works at all
2. Capture test images to understand quality
3. Consider writing a simpler matching solution or updating the libfprint driver

**Command:** `sudo python3 run_5110.py` produces fingerprint images directly.

---

### Thread 6: Upstream Contribution Path � NOW MORE VIABLE

To get Goodix support into upstream libfprint officially:

1. Study [HACKING.md](https://github.com/0x00002a/libfprint/blob/0x2a/dev/goodixtls-sigfm/HACKING.md) for contribution guidelines
2. Review the [libfprint GitLab](https://gitlab.freedesktop.org/libfprint/libfprint) merge request process
3. The driver would need:
   - Clean rebase on current upstream
   - Proper test coverage
   - Code review by libfprint maintainers
   - Compliance with libfprint coding standards (uncrustify)
4. The TLS/encryption dependency may be a blocker for upstream acceptance (complexity & security considerations)

**New signal (Jan 2026):** @hadess (Bastien Nocera), the upstream libfprint maintainer, appeared as a participant on [PR #32](https://github.com/goodix-fp-linux-dev/libfprint/pull/32). This is the first indication of upstream interest and suggests a contribution may be welcome if the code quality is right.

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| **GCC 15 breaks AUR build** | **High (CachyOS-specific)** | **High** | Cherry-pick fix from [kase1111-hash fork](https://github.com/kase1111-hash/libfprint-goodix-521d-gcc15) or use `-Wno-error=incompatible-pointer-types` |
| OpenCV API breakage blocks enrollment | High | High | Downgrade OpenCV or patch driver |
| Sensor firmware flash fails | Low | High | Flash from Windows first, keep Windows partition |
| Driver conflicts with CachyOS updates | Medium | Medium | Pin libfprint package version |
| Complete project abandonment | Partially happened, but reviving | Medium | Fork and maintain locally; engage with @gulp who is active now |
| Sensor hardware damage from flashing | Very Low | Very High | Use known-good firmware from submodule (stable since Nov 2022) |

## Recommended Order of Operations

1. **Check GCC version** — `gcc --version` on CachyOS. If GCC 15+, expect AUR build failure and prepare the [GCC 15 fix](https://github.com/kase1111-hash/libfprint-goodix-521d-gcc15)
2. **Watch PR #32** — Most important: track @gulp's resubmission and offer to test on 5110
3. **Join the Discord** — Quick community check, but note it's low-activity
4. **Install CachyOS** — Keep a Windows partition for fallback
5. **Test goodix-fp-dump** — Verify sensor can capture images
6. **Install AUR package** — Test fprintd enrollment (ensure SIGFM branch is used)
7. **Debug if needed** — Focus on GCC 15 and SIGFM/OpenCV issues
8. **Engage with @gulp and @hadess** — Coordinate on upstream contribution
9. **Update Arch Wiki** — Fix the stale `rootd/libfprint` link to point to `goodix-fp-linux-dev/libfprint` (community contribution)

## Sources

- All sources cited in companion documents:
  - [01-device-and-ecosystem-overview.md](01-device-and-ecosystem-overview.md)
  - [02-development-status-and-known-issues.md](02-development-status-and-known-issues.md)
  - [03-architecture-and-technical-deep-dive.md](03-architecture-and-technical-deep-dive.md)
  - [05-internet-research-findings.md](05-internet-research-findings.md)
