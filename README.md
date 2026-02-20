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
sudo ./host-tools/uninstall.sh
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

## 6. What's Next

See [ACTION_PLAN.md](ACTION_PLAN.md) for the full phase status and pre-MR checklist.

Remaining before upstream MR:
- Write MR description, credit original authors
- Ping `@hadess` on the MR
- Push branch to a public remote and update `packaging/aur/PKGBUILD` `url=`
- Investigate whether the PSK is per-device or shared across all 27c6:5110 units

---

## 7. Reference Documents

| Document | Contents |
|---|---|
| [packaging/README.md](packaging/README.md) | AUR PKGBUILD + Debian skeleton usage |
| [ACTION_PLAN.md](ACTION_PLAN.md) | Phase status, pre-MR checklist, changelog |
| [analysis/09-upstream-porting-plan.md](analysis/09-upstream-porting-plan.md) | Detailed MR spec |
| [analysis/03-architecture-and-technical-deep-dive.md](analysis/03-architecture-and-technical-deep-dive.md) | Driver stack internals |
| [analysis/08-session-findings-and-bug-fixes.md](analysis/08-session-findings-and-bug-fixes.md) | Three bugs found & fixed |
| [analysis/10-nbis-viability-test.md](analysis/10-nbis-viability-test.md) | Why NBIS can't work on this sensor |
| [analysis/12-packaging-aur-debian.md](analysis/12-packaging-aur-debian.md) | AUR PKGBUILD + Debian packaging analysis |
| [analysis/07-devcontainer-handoff.md](analysis/07-devcontainer-handoff.md) | Container setup & USB passthrough details |
