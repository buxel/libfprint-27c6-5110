b````markdown
# Internet Research Findings

> Compiled from systematic search across GitHub, Reddit, Arch forums, CachyOS forums, Arch Wiki, and fork network analysis (Jul 2025).

## Executive Summary

No previously unknown development paths or breakthroughs were found for the Goodix `27c6:5110` on Linux. The goodixtls open-source community driver remains the **only viable approach** — no vendor (Huawei) driver exists, and the proprietary TOD (Touch Other Device) path used by Dell/Lenovo for their Goodix sensors is not available for the 5110. Two new risks were identified: a **GCC 15 compatibility issue** affecting Goodix drivers (relevant for CachyOS's bleeding-edge toolchain) and an **outdated Arch Wiki** page that links to a stale fork.

---

## Key Finding 1: Two Approaches to Goodix Linux Support

The Linux Goodix fingerprint ecosystem has bifurcated into two fundamentally different approaches. Understanding this distinction is critical for assessing what is and isn't applicable to the 5110.

### Path A: TOD / Proprietary Binary Blob

| Property | Detail |
|---|---|
| **Architecture** | `libfprint-tod` (Touch Other Device) — a plugin system for proprietary vendor drivers |
| **How it works** | Vendor (Dell, Lenovo) publishes a binary blob via Canonical's archive; `libfprint-tod` loads it as a plugin |
| **Applicable sensors** | 27c6:533c (Dell XPS 15 9500), 27c6:550a (Lenovo ThinkPad), possibly others |
| **AUR package** | [`libfprint-goodix-53xc`](https://aur.archlinux.org/packages/libfprint-goodix-53xc) (by pusi77, Jul 2025) — downloads Dell blob from `dell.archive.canonical.com` |
| **Depends on** | [`libfprint-tod`](https://aur.archlinux.org/packages/libfprint-tod) AUR package |
| **Status** | Working for sensors that have vendor blobs; confirmed operational on Arch by multiple users on r/archlinux |

### Path B: goodixtls / Open-Source Reverse-Engineered

| Property | Detail |
|---|---|
| **Architecture** | Community-built driver integrated into a libfprint fork |
| **How it works** | Reverse-engineered TLS protocol, image capture, and SIGFM matching |
| **Applicable sensors** | 27c6:5110, 27c6:5117, 27c6:5120, 27c6:521d, and other 51xx MOH sensors |
| **AUR package** | [`libfprint-goodixtls-git`](https://aur.archlinux.org/packages/libfprint-goodixtls-git) (by voidstar, Nov 2022) |
| **Status** | Experimental, no vendor involvement |

### Why Only Path B Works for the 5110

**Huawei has never published a Linux fingerprint driver for any of their laptops.** There is no proprietary blob available on Canonical's archive, Dell's archive, or anywhere else. The 5110 is an MOH (Match-on-Host) sensor requiring full image processing on the host — the host must understand the Goodix TLS protocol to retrieve images. Without a vendor blob, the TOD approach is impossible. The open-source reverse-engineered goodixtls driver is the **sole path**.

**Sources:**
- [r/archlinux: XPS fingerprint working](https://www.reddit.com/r/archlinux/comments/1lzmuki/) — TOD approach for 533c
- [r/debian: 550a guide](https://www.reddit.com/r/debian/comments/1jtrgtn/) — TOD approach for Lenovo
- [AUR: libfprint-goodix-53xc](https://aur.archlinux.org/packages/libfprint-goodix-53xc)
- [Arch Wiki: Huawei MateBook 14 AMD (2020)](https://wiki.archlinux.org/title/Huawei_MateBook_14_AMD_(2020)) — no LVFS updates from Huawei

---

## Key Finding 2: GCC 15 Compatibility Issue ⚠️

A fork created **last month** (`kase1111-hash/libfprint-goodix-521d-gcc15`) fixes "incompatible pointer type errors" in the Goodix 521d driver when compiled with GCC 15.

| Property | Detail |
|---|---|
| **Repository** | [kase1111-hash/libfprint-goodix-521d-gcc15](https://github.com/kase1111-hash/libfprint-goodix-521d-gcc15) |
| **What it fixes** | `fix GCC 15 incompatible pointer type errors for Goodix 521d driver` |
| **Affected code** | `libfprint/drivers/goodixtls/` — the `goodix_tls_read_image` function and related address-of operator usage |
| **Relevance for 5110** | The 5110 and 521d drivers share substantial code in the `goodixtls` driver family. **If the same pointer patterns exist in the 5110 code path, GCC 15 will fail to compile it.** |
| **CachyOS impact** | **HIGH** — CachyOS tracks bleeding-edge compiler versions. If CachyOS has moved to GCC 15 (or will do so), the AUR package `libfprint-goodixtls-git` may fail to build. |

**Action items:**
1. Check CachyOS's current GCC version: `gcc --version`
2. If GCC 15+, expect build failures with the current AUR package
3. The fix from `kase1111-hash` can be cherry-picked or applied to the SIGFM branch

**Source:** [github.com/kase1111-hash/libfprint-goodix-521d-gcc15](https://github.com/kase1111-hash/libfprint-goodix-521d-gcc15)

---

## Key Finding 3: Arch Wiki Is Outdated

The [Arch Wiki page for Huawei MateBook 14 AMD (2020)](https://wiki.archlinux.org/title/Huawei_MateBook_14_AMD_(2020)) is the canonical reference for this device but its fingerprint section has issues:

### Current Content (as of Aug 29, 2025)
- Fingerprint reader listed as **"No"** in the hardware compatibility table
- Links to [rootd/libfprint](https://github.com/rootd/libfprint) as "a fork" — **this is a stale fork** (1 commit ahead, 12 behind `goodix-fp-linux-dev/libfprint`, last activity 4 years ago)
- Links to [libfprint-goodixtls-git](https://aur.archlinux.org/packages/libfprint-goodixtls-git) AUR package — this is correct

### Wiki Edit History (fingerprint-related)
| Date | Editor | Change |
|---|---|---|
| 2021-09-02 | (void*) | Added fingerprint reader section (reverted partially by NetSysFire for Discord link policy) |
| 2022-06-24 | Erus Iluvatar | Updated to "more recent fork" |
| 2022-11-10 | (void*) | "Added information about the new progress of the fingerprint driver" — added rootd/libfprint link and AUR package |

**Note:** The wiki editor `(void*)` is very likely @0x00002a (their C-style handle "void pointer" → `0x00002a` "null pointer address"). They last edited the fingerprint section in Nov 2022, which was exactly when the AUR package was created.

### Recommended Wiki Update
The fingerprint section should:
1. Replace `rootd/libfprint` link with `goodix-fp-linux-dev/libfprint`
2. Mention that the AUR package builds from the `0x2a/dev/goodixtls-sigfm` branch
3. Add a note about PR #32 activity (Jan 2026)
4. Clarify the MOH vs MOC distinction

---

## Key Finding 4: CachyOS Forum — No 5110-Specific Threads

Searched [discuss.cachyos.org](https://discuss.cachyos.org/search?q=fingerprint) for "fingerprint" — **37 results**, none about Goodix 5110 or goodixtls.

### Relevant threads found:
| Thread | Date | Relevance |
|---|---|---|
| "UE5 games not working in CachyOS" | Jun 2025 | User mentions "not being able to use my fingerprint reader (no drivers for any distro of linux)" — confirms awareness of the issue |
| "Will my ASUS Laptop do well in CachyOS?" | Dec 2025 | User reports fingerprint reader working on CachyOS after failing on Mint — but this is an ASUS laptop, likely a supported sensor |
| "GUI Installer doesn't show up" | Sep 2024 | Mentions "basically only the Goodix fingerprint is incompatible" referencing linux-hardware.org |
| "Addtiniol settings" | Jul 2024 | Notes that CachyOS doesn't ship fprintd by default; it's a manual install |

### Key takeaway
CachyOS treats fingerprint readers as a manual configuration item — `fprintd` is not pre-installed. There is no CachyOS-specific integration or blocklisting of Goodix sensors. The AUR package approach should work if the underlying driver compiles.

---

## Key Finding 5: Fork Network Analysis

Analysis of the full [fork network](https://github.com/goodix-fp-linux-dev/libfprint/network/members) (~100+ forks) reveals:

### Notable forks
| Fork | Owner | Significance |
|---|---|---|
| [gulp/libfprint-1](https://github.com/gulp/libfprint-1) | @gulp | PR #32 author's fork — active Jan 2026. Note: GitHub username is `gulp` (not `gulp21` as previously suspected) |
| [kase1111-hash/libfprint-goodix-521d-gcc15](https://github.com/kase1111-hash/libfprint-goodix-521d-gcc15) | @kase1111-hash | GCC 15 fix, last month — see Finding 2 |
| [bertin0/libfprint-sigfm](https://github.com/bertin0/libfprint-sigfm) | @bertin0 | SIGFM-named fork of Infinytum/libfprint — 5 years old, no additional work |
| [oscar-schwarz/libfprint-goodix-55b4](https://github.com/oscar-schwarz/libfprint-goodix-55b4) | @oscar-schwarz | Fork for 55b4 sensor |
| [jooooscha/libfprint-goodix](https://github.com/jooooscha/libfprint-goodix) | @jooooscha | Generic Goodix fork |

### Upstream heritage
The fork chain is: `aryanshar/libfprint` (GitHub mirror of upstream) → `goodix-fp-linux-dev/libfprint` (community fork) → all individual forks. Some forks derive from `Infinytum/libfprint` (an intermediate fork by @nilathedragon), which explains why certain forks appear in a separate tree.

---

## Key Finding 6: goodix-fp-dump Commit History

Detailed examination of [goodix-fp-dump commits](https://github.com/goodix-fp-linux-dev/goodix-fp-dump/commits/master):

| Date | Committer | Change | Relevance |
|---|---|---|---|
| 2023-05-30 | @mpi3d | Firmware submodule update | Last commit |
| 2023-05-14 | @coredoesdev | PR #37: 5503 driver | Different sensor |
| 2023-03-14 | @anarsoul | Preprocessor improvements | Image quality |
| **2022-11-07** | **@0x00002a** | **PR #29: Fix flashing 5110 failing** | **Directly relevant — 5110 flash fix** |
| 2022-11-06 | @EliaGeretto | 53x5 firmware RE | Different sensor |

**The 5110 flash code (PR #29) has been stable since Nov 2022** — nearly 3 years without reported issues. This reduces the firmware flashing risk.

---

## Key Finding 7: Contributor Activity Profiles

| Contributor | Recent GitHub Activity | Assessment |
|---|---|---|
| @gulp | Active on GitHub (profile shows LanguageTool + geography projects). 0 fingerprint history before PR #32 | **One-off contribution** to goodixtls; motivated by own 5117 hardware need |
| @0x00002a (voidstar) | Unknown recent activity; AUR package last updated Nov 2022 | **Likely dormant** on this project |
| @mpi3d (Matthieu Charette) | Last goodix-fp-dump commit May 2023 | **Dormant** on fingerprint work |
| @hadess (Bastien Nocera) | Active upstream libfprint maintainer | **Observer/advisor** — appeared on PR #32 but no commits |
| @egormanga | Active code reviewer on PR #32 | **Probably the most active project member** currently |

---

## Key Finding 8: Broader Context — Reddit Community Perspectives

### r/linux: "Situation in finger print scanner support" (Jan 2025)
- Fingerprint scanners compared to "old WinModems" — vendor trade secrets, reverse-engineering required
- One commenter has Goodix 27c6:631c (6xxx = MOC, upstream-supported) working on Arch
- Confirms `fprint.freedesktop.org/supported-devices.html` as the authoritative reference
- General consensus: if your sensor isn't on the supported list, it probably won't work without community drivers

### r/linux: "Fingerprint integration in Linux" (Dec 2025)
- PAM configuration works for sudo fingerprint authentication
- Desktop integration (login screens) is poor and error-prone
- @gulp tested PR #32 on Omarchy (Arch-based) — another commenter confirms fingerprint sudo works on Omarchy

### r/archlinux: Huawei MateBook 15 (2021) with 27c6:5125 (Dec 2021)
- Same Goodix family as 5110 — fingerprint "doesn't work on any distro"
- Comments confirm: "Goodix is not supported on any Linux distro"
- Links to the Arch Wiki for MateBook 14 AMD (2020) — same device page we analyzed

### r/linuxhardware: "Are Huawei Notebooks underdogs in Linux support?" (Jan 2025)
- Mixed reception; newer Huawei laptops may run HarmonyOS (not Linux-based)
- Consensus: ThinkPads and Dell XPS are the go-to for Linux; Huawei is not recommended for Linux users
- No specific fingerprint driver mentions

---

## Search Coverage Summary

| Source | Query / Method | Results for 5110 |
|---|---|---|
| GitHub (code search) | `goodixtls`, `goodix 5110`, `27c6:5110` | No new repos beyond known ecosystem |
| Reddit (r/archlinux) | `goodix`, `fingerprint`, `5110`, `libfprint` | 3 relevant threads found (see Finding 8) |
| Reddit (r/linuxhardware) | `huawei fingerprint` | 1 general thread (see Finding 8) |
| Reddit (r/linux) | `fingerprint linux support` | 2 general discussions (see Finding 8) |
| Reddit (r/debian) | `goodix fingerprint` | 1 TOD guide for 550a (not applicable) |
| AskUbuntu | `goodix 5110 fingerprint` | 0 results |
| Arch Linux forums (bbs) | `goodix`, `5110`, `goodixtls` | 0 direct results; 3 tangential threads |
| CachyOS forums | `fingerprint` | 37 results, 0 specific to 5110/goodixtls |
| Arch Wiki | Huawei MateBook 14 AMD (2020) page | Confirmed "No" status, outdated fork link |
| freedesktop.org GitLab | Unsupported Devices wiki | Blocked by Anubis bot protection |
| GitHub fork network | goodix-fp-linux-dev/libfprint members | ~100+ forks; 3 notable (see Finding 5) |
| AUR | `libfprint-goodix*` | 2 packages: goodixtls-git (our target), goodix-53xc (TOD, unrelated) |

---

## Conclusion

The research confirms that:

1. **No hidden development** exists for the 5110 — the goodixtls community fork is the sole effort
2. **Two approaches exist** for Goodix on Linux, but only the open-source path applies to 5110
3. **GCC 15 is a newly identified risk** for CachyOS builds — patches exist for related drivers
4. **The Arch Wiki is outdated** and should be updated as a community contribution
5. **@egormanga appears to be the most active project member** — valuable contact
6. **The firmware flash code for 5110 is mature** (stable since Nov 2022)
7. **No CachyOS-specific gotchas** were found — standard fprintd + AUR approach applies

---

## Sources

All URLs verified during research:
- https://wiki.archlinux.org/title/Huawei_MateBook_14_AMD_(2020)
- https://discuss.cachyos.org/search?q=fingerprint
- https://github.com/rootd/libfprint
- https://github.com/kase1111-hash/libfprint-goodix-521d-gcc15
- https://github.com/bertin0/libfprint-sigfm
- https://github.com/goodix-fp-linux-dev/libfprint/network/members
- https://aur.archlinux.org/packages/libfprint-goodix-53xc
- https://www.reddit.com/r/archlinux/comments/1lzmuki/
- https://www.reddit.com/r/archlinux/comments/16jdx2x/
- https://www.reddit.com/r/archlinux/comments/rj7gb4/
- https://www.reddit.com/r/linux/comments/1ibf2pz/
- https://www.reddit.com/r/linux/comments/1pocdw3/
- https://www.reddit.com/r/debian/comments/1jtrgtn/
- https://www.reddit.com/r/linuxhardware/comments/1n0jju8/

````
