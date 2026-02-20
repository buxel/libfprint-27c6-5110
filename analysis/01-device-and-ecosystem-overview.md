# Device & Ecosystem Overview

## Target Device

| Property | Value |
|---|---|
| **Laptop** | Huawei MateBook 14 AMD (2020) |
| **Fingerprint Sensor** | Goodix |
| **USB ID** | `27c6:5110` |
| **Sensor Resolution** | 80×64 pixels |
| **Official libfprint Support** | ❌ No — **not** on the [supported devices list](https://fprint.freedesktop.org/supported-devices.html). See [clarification below](#goodix-moc-vs-tls-confusion). |
| **Target OS** | CachyOS (Arch-based) |

### Goodix MOC vs TLS Confusion

> **Common misconception:** The official libfprint supported devices list includes many Goodix sensors with vendor ID `27c6`, but these are all **MOC (Match-on-Chip)** sensors starting at `27c6:5840` and above. The `27c6:5110` is a **MOH** (Match-on-Host) chip using a completely different **TLS-encrypted protocol** and is **not supported** by the upstream `goodixmoc` driver.
>
> As clarified by @egormanga ([Issue #31](https://github.com/goodix-fp-linux-dev/libfprint/issues/31), Oct 2025): *"MOC series chips are only 6xxx, while yours is 5xxx series, thus being MOH."*
>
> This confusion was observed in the [Discord](#discord-status-feb-2026) (Feb 2026) where a user claimed the 5110 had a ✅ on the supported list. This is incorrect — they likely saw other `27c6:xxxx` Goodix MOC entries and assumed coverage.

## Ecosystem Map

The Goodix fingerprint Linux support effort is a community-driven project spanning several repositories, packages, and individuals. Below is the full landscape as of February 2026.

### Upstream (Official)

- **libfprint** (official): [gitlab.freedesktop.org/libfprint/libfprint](https://gitlab.freedesktop.org/libfprint/libfprint)
  - The canonical fingerprint reader library for Linux.
  - `27c6:5110` is **not** in the supported device list.
  - No active MR or development effort visible upstream for Goodix TLS devices.

### Community Development Repositories

| Repository | Role | Status | Last Activity |
|---|---|---|---|
| [goodix-fp-linux-dev/libfprint](https://github.com/goodix-fp-linux-dev/libfprint) | **Primary community fork** of libfprint for Goodix devices | Experimental, 103 stars, 16 forks | [PR #32](https://github.com/goodix-fp-linux-dev/libfprint/pull/32) (5117 support) — **Jan 2026** |
| [goodix-fp-linux-dev/goodix-fp-dump](https://github.com/goodix-fp-linux-dev/goodix-fp-dump) | Firmware dump/flash tool for Goodix sensors | 331 stars, 29 forks, 5 open issues | ~3 years ago (last commit) |
| [0x00002a/libfprint](https://github.com/0x00002a/libfprint) (`0x2a/dev/goodixtls-sigfm` branch) | Fork with improved signal/feature matching (sigfm) | 8 stars, 228 commits ahead of goodix-fp-linux-dev | ~3 years ago |
| [rootd/libfprint](https://github.com/rootd/libfprint) | Earlier fork referenced in Arch Wiki — **stale** (12 commits behind, 1 ahead) | 3 stars | ~4 years ago |
| [d-k-bo/libfprint](https://github.com/d-k-bo/libfprint) (`copr` branch) | Fedora COPR packaging fork | **Abandoned** (Oct 2024 statement) | RPM spec only |
| [kase1111-hash/libfprint-goodix-521d-gcc15](https://github.com/kase1111-hash/libfprint-goodix-521d-gcc15) | **GCC 15 compatibility fix** for Goodix 521d driver — relevant to 5110 | Fork of Infinytum/libfprint | Last month |

### Packages

| Package | Distribution | Source |
|---|---|---|
| [libfprint-goodixtls-git (AUR)](https://aur.archlinux.org/packages/libfprint-goodixtls-git) | Arch Linux / CachyOS | Builds from [0x00002a/libfprint](https://github.com/0x00002a/libfprint) `0x2a/dev/goodixtls-sigfm` branch |
| [libfprint-goodix-53xc (AUR)](https://aur.archlinux.org/packages/libfprint-goodix-53xc) | Arch Linux | **NOT for 5110** — proprietary Dell TOD driver for 27c6:533c (XPS 15 9500). Uses binary blob from `dell.archive.canonical.com`. Depends on `libfprint-tod` AUR. |
| d-k-bo/libfprint-goodixtls (COPR) | Fedora | **Abandoned** — maintainer [stated Oct 2024](https://discussion.fedoraproject.org/t/d-k-bo-libfprint-goodixtls/43849/22) they no longer use the sensor |

### Two Approaches to Goodix on Linux

> **Important distinction:** There are two fundamentally different approaches for Goodix fingerprint sensors on Linux. Only one applies to the 5110.
>
> 1. **TOD / Proprietary:** Uses `libfprint-tod` to load vendor binary blobs (from Dell, Lenovo via Canonical). Works for sensors like 27c6:533c (Dell XPS) and 27c6:550a (Lenovo ThinkPad). **Not available for 5110** because Huawei has never published a Linux fingerprint driver.
> 2. **goodixtls / Open-Source:** Community reverse-engineered driver for MOH (51xx) sensors. This is the **only viable path** for the 5110.
>
> See [05-internet-research-findings.md](05-internet-research-findings.md) for full analysis.

### Community Communication

| Channel | Link |
|---|---|
| Discord | [Goodix Fingerprint Linux Development](https://discord.com/invite/6xZ6k34Vqg) |
| Fedora Discussion | [d-k-bo/libfprint-goodixtls thread](https://discussion.fedoraproject.org/t/d-k-bo-libfprint-goodixtls/43849) |
| Arch Wiki | [Huawei MateBook 14 AMD (2020)](https://wiki.archlinux.org/title/Huawei_MateBook_14_AMD_(2020)) — **⚠️ fingerprint section outdated**: links to stale `rootd/libfprint` fork instead of `goodix-fp-linux-dev/libfprint` |
| CachyOS Forum | [discuss.cachyos.org](https://discuss.cachyos.org/search?q=fingerprint) — 37 results for "fingerprint", none specific to Goodix 5110 or goodixtls |

### Discord Status (Feb 2026)

The Discord channel is **low-activity**. Last notable messages (Aug 2025 – Feb 2026):

| Date | User | Summary |
|---|---|---|
| 2025-08-14 | sikora | Tip: use `sudo .venv/bin/python3 run_5110.py` (root breaks venv path) |
| 2025-08-20 | oski146 | Afraid of bricking sensor, will wait for stability |
| 2025-09-26 | zyr0n | Asking where the code/solution is, offered USB capture help |
| 2026-01-10 | oski146 | Asking if a stable driver is available (no answer) |
| 2026-02-07 | Elouan | Claims 5110 has ✅ on supported list — **this is incorrect** (see [clarification above](#goodix-moc-vs-tls-confusion)) |

**Takeaway:** No active development is happening via the Discord. Users are still asking for a stable driver; nobody is providing one.

### Key Contributors

| Person | GitHub Handle | Role |
|---|---|---|
| Matthieu Charette | [@mpi3d](https://github.com/mpi3d) | Lead of goodix-fp-dump, core protocol reverse-engineering |
| voidstar / 0x00002a | [@0x00002a](https://github.com/0x00002a) | AUR package maintainer, sigfm branch developer |
| rootd | [@rootd](https://github.com/rootd) | Earlier libfprint fork maintainer |
| d-k-bo | [@d-k-bo](https://github.com/d-k-bo) | Fedora COPR packager (now inactive) |
| EliaGeretto | [@EliaGeretto](https://github.com/EliaGeretto) | Contributor to goodix-fp-dump |
| gulp | [@gulp](https://github.com/gulp) | Active contributor (Jan 2026) — adding 5117 support via [PR #32](https://github.com/goodix-fp-linux-dev/libfprint/pull/32) |
| egormanga | [@egormanga](https://github.com/egormanga) | Project member, code reviewer on PR #32 |
| Bastien Nocera (hadess) | [@hadess](https://github.com/hadess) | **Upstream libfprint maintainer** — participant on PR #32 |

## Sources

- [Arch Wiki: Huawei MateBook 14 AMD (2020)](https://wiki.archlinux.org/title/Huawei_MateBook_14_AMD_(2020)) — last edited 29 August 2025
- [AUR: libfprint-goodixtls-git](https://aur.archlinux.org/packages/libfprint-goodixtls-git) — submitted 2022-11-06, last updated 2022-11-16
- [AUR: libfprint-goodix-53xc](https://aur.archlinux.org/packages/libfprint-goodix-53xc) — TOD driver for 533c (NOT for 5110)
- [goodix-fp-linux-dev/libfprint](https://github.com/goodix-fp-linux-dev/libfprint) — 103 stars
- [goodix-fp-linux-dev/goodix-fp-dump](https://github.com/goodix-fp-linux-dev/goodix-fp-dump) — 331 stars, last commit May 2023
- [Fedora Discussion Thread](https://discussion.fedoraproject.org/t/d-k-bo-libfprint-goodixtls/43849)
- [Internet Research Findings](05-internet-research-findings.md) — comprehensive search results
