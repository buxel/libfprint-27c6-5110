# libfprint GF511 driver — Goodix 27c6:5110

Adds Goodix GF511 fingerprint sensor support to libfprint. Hardware tested on the
Huawei MateBook 14 AMD 2020 running CachyOS. Full enroll → verify pipeline works,
including KDE fingerprint login via fprintd.

Branch: `goodixtls-on-1.94.9` — 4 commits above `v1.94.9`, ready for upstream MR.

---

> **Disclaimer**
>
> This project consolidates prior community work (see credits in
> [MR_DESCRIPTION.md](MR_DESCRIPTION.md)) into a single, rebased, and cleaned-up
> branch with potential to be submitted upstream to libfprint. **AI assistance was
> used throughout the porting, refactoring, and documentation process.**
>
> The AUR package (`libfprint-goodixtls511-git`) is provided for **personal use
> only**. It has not been published to the AUR and comes with no warranty.
> Use it at your own risk.

---

## 1. Open in Dev Container

The workspace includes a `.devcontainer/` configuration. Open it in VS Code and
**Reopen in Container** (or `devcontainer open .`). The container is Ubuntu 22.04
with all build dependencies pre-installed.

**USB passthrough** — the physical sensor must be passed through to the container.
Confirm it is visible inside:

```bash
lsusb | grep 27c6:5110
# Bus 001 Device 009: ID 27c6:5110 Shenzhen Goodix Technology Co.,Ltd.
```

---

## 2. Build

Build:

```bash
cd /workspace/libfprint-fork
rm -rf build    # use rm -rf, not meson --wipe (buggy on this version)
meson setup build \
    -Ddoc=false \
    -Dgtk-examples=false \
    -Dintrospection=false \
    -Dc_args="-Wno-error=incompatible-pointer-types"
ninja -C build
```

Run tests:

```bash
ninja -C build test
# Expected: 3 pass, ~27 skip (hardware tests require device)
```

---

## 3. Enroll & Verify (inside container)

```bash
cd /workspace/libfprint-fork
G_MESSAGES_DEBUG=libfprint-goodixtls5xx ./build/examples/enroll
# Choose finger 6 (right index). Place finger 20 times.
```

```bash
G_MESSAGES_DEBUG=libfprint-goodixtls5xx ./build/examples/verify
# Run from the directory containing test-storage.variant
```

Reference enrollment artifacts are in `test-data/` (`enrolled.pgm`,
`test-storage.variant`). Scores of 47–499 against threshold 24 are normal.

---

## 4. Install on Host (CachyOS / Arch)

```bash
cd packaging/aur
makepkg -si
```

Or with an AUR helper once the package is published:

```bash
yay -S libfprint-goodixtls511-git
```

Then enroll:

```bash
fprintd-enroll -f right-index-finger $USER
```

Or via KDE: **System Settings → Users → Fingerprint Authentication**.

To revert to the stock libfprint:

```bash
sudo ./tools/uninstall.sh
```

---

## 5. Key Facts

| Property | Value |
|----------|-------|
| Sensor | Goodix GF511 (die: GF3658), USB `27c6:5110` |
| Image size | 64×80 px, 508 DPI |
| Enrollment stages | 20 presses |
| Matcher | Pure-C FAST-9 + BRIEF-256 (no OpenCV) |
| TLS | GnuTLS 1.2, PSK-DHE, in-memory (no pthreads) |
| PSK | `ba1a86037c1d3c71c3af344955bd69a9a9861d9e911fa24985b677e8dbd72d43` |

---

## 6. A/B Testing Pipeline

The GF511 sensor produces low-resolution 64×80 images. Small changes to the
preprocessing pipeline (sharpening boost, contrast stretch, crop margins) can
dramatically affect match rates. The repo includes an offline A/B testing setup
that captures raw sensor frames once and replays them through different
preprocessing configurations — removing finger placement variation from the
comparison.

### Architecture

```
  Sensor                    Offline (no sensor needed)
  ──────                    ──────────────────────────
  capture-corpus.sh    →    replay-pipeline    →    sigfm-batch
  (raw .bin + PGM)          (raw → PGM)             (PGM → scores + FRR)
```

**Component A — Capture** (`tools/capture-corpus.sh`):
Runs `img-capture` in a loop, saving both the driver-processed PGM and the raw
pre-processed frame (via `FP_SAVE_RAW`). Each raw frame is a 14,080-byte
uint16 LE array (88×80 pixels, post-calibration-subtract, pre-squash/sharpen/crop).

**Component B — Replay** (`tools/replay-pipeline`):
Reads raw `.bin` frames and `calibration.bin`, then applies the same preprocessing
steps as `goodix5xx.c` with configurable parameters. This lets you compare
e.g. `--boost=2` (current) vs `--boost=10` (Windows-style) on identical sensor data.

**Component C — Benchmark** (`tools/sigfm-batch`):
Takes PGM files, splits them into enrollment and verification sets, runs the full
SIGFM matching pipeline (FAST-9 + BRIEF-256), and reports per-frame scores and FRR.

### Quick Start

```bash
# 1. Build tools
make -C tools

# 2. Capture 20 frames (press finger once per capture)
./tools/capture-corpus.sh ./corpus/baseline 20

# 3. Benchmark driver-produced PGMs directly
./tools/sigfm-batch \
    --enroll  corpus/baseline/capture_000{1..9}.pgm corpus/baseline/capture_0010.pgm \
    --verify  corpus/baseline/capture_001{1..9}.pgm corpus/baseline/capture_0020.pgm \
    --score-threshold=40

# 4. Replay raw frames with a different boost factor
./tools/replay-pipeline --batch corpus/baseline --boost=10 -o corpus/boost10

# 5. Benchmark replayed frames
./tools/sigfm-batch \
    --enroll  corpus/boost10/0001.pgm corpus/boost10/0002.pgm ... \
    --verify  corpus/boost10/0011.pgm corpus/boost10/0012.pgm ... \
    --score-threshold=40
```

### Interpreting Results

- **Keypoints**: FAST-9 corners detected. Healthy range: 60–128 (capped at 128).
  Below 25 → frame rejected as too few features.
- **Score**: Count of geometrically consistent angle-pairs from matched BRIEF
  descriptors. Scale is O(n²) of matched features, so values range from 0 to
  thousands. Score of 0 means fewer than 5 KNN descriptor matches were found.
- **FRR**: False Rejection Rate — percentage of genuine verification attempts
  that failed to match. The target is <10%.

---

## 7. What's Next

See [ACTION_PLAN.md](ACTION_PLAN.md) for the full phase status and pre-MR checklist.

Remaining before upstream MR:
- Reduce FRR from current baseline (~60–90%) to <10% via preprocessing tuning
- Write MR description, credit original authors
- Ping `@hadess` on the MR
- Push branch to a public remote and update `packaging/aur/PKGBUILD` `url=`
- Investigate whether the PSK is per-device or shared across all 27c6:5110 units

---

## 8. Reference Documents

| Document | Contents |
|---|---|
| [packaging/README.md](packaging/README.md) | AUR PKGBUILD + Debian skeleton usage |
| [ACTION_PLAN.md](ACTION_PLAN.md) | Phase status, pre-MR checklist, changelog |
| [analysis/09-upstream-porting-plan.md](analysis/09-upstream-porting-plan.md) | Detailed MR spec |
| [analysis/03-architecture-and-technical-deep-dive.md](analysis/03-architecture-and-technical-deep-dive.md) | Driver stack internals |
| [analysis/08-session-findings-and-bug-fixes.md](analysis/08-session-findings-and-bug-fixes.md) | Three bugs found & fixed |
| [analysis/10-nbis-viability-test.md](analysis/10-nbis-viability-test.md) | Why NBIS can't work on this sensor |
| [analysis/12-packaging-aur-debian.md](analysis/12-packaging-aur-debian.md) | AUR PKGBUILD + Debian packaging analysis |
| [analysis/14-testing-and-benchmarking-strategy.md](analysis/14-testing-and-benchmarking-strategy.md) | Full A/B testing design rationale |
| [analysis/07-devcontainer-handoff.md](analysis/07-devcontainer-handoff.md) | Container setup & USB passthrough details |
