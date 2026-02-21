````markdown
# Implementation Strategy for Goodix 27c6:5110 Support

**Primary goal:** Upstream the driver into libfprint.  
**Fallback:** Maintain a clean patch-based package if upstream rejects it.

This strategy plans for GnuTLS and GLib async I/O from the start, rather than building on OpenSSL/pthreads and retrofitting later.

---

## Starting Point: What Exists

### The Community Driver (0x00002a/libfprint SIGFM Branch)

| Property | Value |
|---|---|
| Fork base | libfprint **1.94.5** |
| Upstream current | libfprint **1.94.10** (5 point releases behind, same major) |
| Driver files | 10 files (5 `.c` + 5 `.h`) in `libfprint/drivers/goodixtls/` |
| Architecture | Layered: `goodix_proto` → `goodixtls` (TLS) → `goodix` (USB) → `goodix5xx` (common) → `goodix511` (device-specific) |
| External deps | OpenSSL (TLS), pthreads, OpenCV (image processing) |
| Self-containment | HIGH — uses standard `FpImageDevice` / `FpiSsm` / `FpiUsbTransfer` APIs. Driver is largely isolated in its own directory |
| libfprint API surface | Subclasses `FpImageDevice` (appropriate for MOH/image sensors) |
| Matching algorithm | SIGFM (Signal Feature Matching) — replaces NBIS minutiae extraction for low-res sensors |
| Last commit | ~3 years ago |

This code **cannot go upstream as-is**. It uses OpenSSL (wrong ecosystem), pthreads (wrong async model), OpenCV (too heavy), and doesn't follow upstream coding standards. But the protocol knowledge, image pipeline, and SIGFM algorithm are all correct and field-tested — they represent ~4 years of reverse engineering that must not be thrown away.

### Why OpenSSL Was Used (and Why It Needs to Change)

The community driver used OpenSSL because it was the *pragmatic* choice at the time, not a deliberate architectural decision:

1. **Consistency with goodix-fp-dump:** The Python reference implementation uses Python's `ssl` module, which wraps OpenSSL. The C driver mirrored the same library to make protocol debugging easier — when both sides speak the same TLS implementation, Wireshark traces match byte-for-byte.

2. **BIO pair API is convenient for USB-over-TLS:** The Goodix sensor requires TLS 1.2, but over USB, not TCP. OpenSSL's `BIO_new_bio_pair()` makes this straightforward: you create an in-memory BIO pair, feed raw USB bytes into one end, and get decrypted application data out the other. This is well-documented and widely used for custom transports.

3. **Developer familiarity:** @mpi3d and @0x00002a were focused on making it work, not on upstreamability. OpenSSL is the most commonly documented TLS library in the C ecosystem.

4. **Upstream acceptance was never the goal** during the 2020–2022 development phase. Nobody expected @hadess to appear on PR #32 in January 2026.

**Why GnuTLS for upstream:** libfprint is a GNOME/freedesktop project. GnuTLS is the standard TLS library in the GNOME ecosystem (used by GLib-Networking, GNOME Online Accounts, Evolution, etc.). OpenSSL had historical license incompatibilities with the GPL (largely resolved with OpenSSL 3.0's Apache 2.0 license, but the ecosystem preference remains). GnuTLS offers equivalent custom-transport support via `gnutls_transport_set_push_function()` / `gnutls_transport_set_pull_function()` — functionally the same as OpenSSL BIO pairs, just a different API.

---

## What Needs to Change for Upstream

```
Existing Community Driver              Upstream-Quality Driver
─────────────────────────              ───────────────────────
FpImageDevice subclass  ────────→  FpImageDevice subclass (keep)
OpenSSL TLS (BIO pairs) ────────→  GnuTLS (custom transport callbacks)
pthreads (blocking TLS) ────────→  GLib async I/O + FpiSsm state machines
OpenCV image processing ────────→  In-tree processing (pixman / custom)
SIGFM matching          ────────→  Upstream into libfprint core, or
                                   make NBIS work via upscaling (research needed)
Custom meson integration ───────→  Standard driver registration in meson.build
No tests                ────────→  Unit tests + virtual device tests
```

### Technical Challenges (Ranked by Risk)

**1. TLS Dependency — HIGH RISK**
Upstream libfprint has **zero TLS dependencies today**. Adding one is the single biggest architectural ask. This is the most likely reason for upstream rejection.

*Mitigation:* Use GnuTLS, which is already a transitive dependency of many GNOME desktop installations. Frame it as an optional dependency (`-Dgoodixtls=enabled/disabled`). The `goodixmoc` driver already added non-trivial device-side crypto — the precedent exists for security-adjacent code in drivers. Ask @hadess early (before writing code) whether a TLS dependency is acceptable.

**GnuTLS migration plan:**

| OpenSSL Concept | GnuTLS Equivalent | Notes |
|---|---|---|
| `SSL_CTX_new()` | `gnutls_init()` | Session initialization |
| `BIO_new_bio_pair()` | `gnutls_transport_set_push/pull_function()` | Custom transport — GnuTLS uses callbacks instead of BIO objects. Provide push/pull functions that read from / write to a GLib `GBytes` buffer fed by USB transfers. |
| `SSL_read()` / `SSL_write()` | `gnutls_record_recv()` / `gnutls_record_send()` | Same semantics |
| `SSL_do_handshake()` | `gnutls_handshake()` | Both return "want read/write" for non-blocking use |
| Blocking handshake loop | `FpiSsm` state machine | The key async conversion (see below) |
| `SSL_CTX_set_cipher_list()` | `gnutls_priority_set_direct()` | Cipher suite configuration |
| Certificate loading | `gnutls_certificate_set_x509_key_mem()` | Sensor certificate handling |

**GLib async conversion plan:**

The existing driver uses a blocking `while (SSL_do_handshake() != 1)` loop inside a pthread. Upstream requires GLib async I/O. The conversion:

```
Current flow (blocking):                  Target flow (async):
─────────────────────────                 ─────────────────────
pthread_create()                          fpi_ssm_new(TLS_HANDSHAKE_STATES)
  ├── SSL_do_handshake()                    ├── STATE_SEND_CLIENT_HELLO
  │   ├── BIO_read() → usb_send()           │   └── gnutls_handshake() → EAGAIN
  │   ├── usb_recv() → BIO_write()          │   └── fpi_usb_transfer_submit()
  │   └── loop until CONNECTED               │   └── on_transfer_complete → next state
  ├── SSL_read(sensor_data)                 ├── STATE_RECV_SERVER_HELLO
  └── return                                │   └── feed data → gnutls_handshake()
                                            ├── ... (more states)
                                            ├── STATE_HANDSHAKE_DONE
                                            └── STATE_READ_DATA
                                                └── gnutls_record_recv()
```

Each TLS round-trip becomes an `FpiSsm` state that submits a USB transfer and advances on completion. The existing driver already uses `FpiSsm` for the *non-TLS* parts of the protocol — the pattern just needs to be extended to cover the TLS handshake and data transfer.

**2. SIGFM vs NBIS Matching — MEDIUM-HIGH RISK**
Upstream uses NBIS/bozorth3 for all image-based matching. At 80×64 pixels, NBIS fundamentally cannot extract minutiae. Options:

| Option | Feasibility | Acceptance Risk |
|---|---|---|
| **Upstream SIGFM into libfprint core** | Doable — SIGFM is self-contained | Medium — adds complexity to matching pipeline. But benefits all low-res sensors. |
| **Upscale 80×64 → 160×128 (or higher) before NBIS** | Needs experimentation | Low if it works — no core changes needed. But may not produce usable minutiae. |
| **Hybrid: use SIGFM as a driver-private matching fallback** | Technically possible — driver can override match logic | Medium — non-standard but less intrusive |

*Recommendation:* Experiment with upscaling first (cheapest to try). If NBIS can't work even with 4x upscaled images, propose SIGFM as a secondary matching backend with a clear justification.

**3. OpenCV Removal — MEDIUM RISK**
OpenCV is used for image preprocessing (noise reduction, contrast, finger detection). Upstream won't accept an OpenCV dependency for a single driver.

*Replacement path:*
- Noise reduction → libfprint already has `fpi_image_detect_finger()` and basic image ops
- Contrast/histogram → custom implementation (~100 lines of C, well-understood algorithms)
- Finger detection → already exists in libfprint's `FpImageDevice` base class
- The heavy OpenCV work is in SIGFM's feature extraction — if SIGFM is upstreamed, this becomes part of the core library

**4. Firmware Flash — LOW RISK**
Keep it separate. Upstream libfprint does not handle firmware. Users run `goodix-fp-dump` once as a setup step. Proper Linux approach would be `fwupd`, but that requires vendor cooperation (Huawei won't do this). Document the flash requirement clearly.

---

## Rejected Alternatives

### PAM Module with goodix-fp-dump Directly
❌ No desktop integration (GNOME Settings, login screen). Python in PAM stack is a security concern. Not portable.

### D-Bus Service Wrapping goodix-fp-dump
❌ Reimplementing fprintd's D-Bus API is far more work than fixing the libfprint driver.

### Virtualization / Windows Driver Passthrough
❌ Absurdly heavyweight and fragile for a fingerprint reader.

### Standalone libfprint Driver Package (No Fork)
❌ Not feasible — libfprint has no plugin/runtime loading mechanism. All drivers are compiled in at build time via Meson-generated `fpi-drivers.c` GType registration.

---

## Phased Strategy

### Phase 1: Foundations (Week 1–2)
**Goal:** Validate hardware, establish a working baseline for development, and engage the community.

This phase is a *prerequisite* for upstream work — you need a working sensor to develop and test against.

#### Development Environment: VM vs Bare Metal

A CachyOS VM on the current Windows machine is viable for most development work, but has caveats for USB hardware access.

**Hyper-V** has no native USB device passthrough for arbitrary devices. Use [`usbipd-win`](https://github.com/dorssel/usbipd-win) (Microsoft-supported) to forward the Goodix sensor over USB/IP:

```powershell
# On Windows host:
winget install usbipd
usbipd list                          # find 27c6:5110, note BUSID
usbipd attach --busid <BUSID>       # attach to Hyper-V VM
```

The CachyOS guest needs the `usbip` client package (`linux-tools-generic` or equivalent) to receive the forwarded device.

**VirtualBox** or **VMware Workstation** have native USB passthrough and are simpler to set up — VirtualBox with Extension Pack is free and has the lowest friction.

| Hypervisor | USB Passthrough | Setup Effort | Cost |
|---|---|---|---|
| **Hyper-V + usbipd-win** | USB/IP (adds latency) | Medium | Free |
| **VirtualBox + ExtPack** | Native USB 2.0/3.0 | Low | Free (personal) |
| **VMware Workstation** | Native USB, best quality | Low | Paid |

**Timing and reliability considerations:**

- **VirtualBox / VMware (native USB passthrough):** The device is detached from the Windows host and attached directly to the VM's virtual USB controller — no network stack involved. Latency is near bare-metal. Firmware flashing, TLS handshakes, and interrupt transfers (finger detection) should all work without timing issues.
- **Hyper-V + usbipd-win (USB/IP):** USB is tunneled over the network stack, adding latency. This *may* cause firmware flash timeouts, TLS handshake failures, or unreliable interrupt endpoint forwarding. Use only if VirtualBox/VMware are not an option.

**Recommended approach:**
1. The VirtualBox VM **"CachyOS-Fingerprint-Dev"** has been created and configured:
   - 4 GB RAM, 4 CPUs, EFI boot, VMSVGA graphics, 50 GB dynamic disk
   - USB 3.0 (xHCI) enabled with auto-attach filter for Goodix 27c6:5110
   - NAT networking with SSH port forwarding (host:2222 → guest:22)
   - CachyOS ISO (`cachyos-desktop-linux-260124.iso`) mounted as DVD
2. To install: open VirtualBox → start "CachyOS-Fingerprint-Dev" → follow the CachyOS installer
3. After install: remove the ISO from SATA port 1 (or it'll boot the installer again)
4. Enable SSH in the guest: `sudo systemctl enable --now sshd`
5. Connect from Windows: `ssh -p 2222 localhost`

```
1. Community Engagement (do this FIRST — before writing any code)
   ├── Join Goodix FP Discord
   ├── Contact @gulp — is PR #32 resubmission planned?
   ├── Contact @egormanga — status of the project?
   ├── Ask @hadess (via GitLab or PR #32): "Would a goodixtls driver
   │   be welcome as an MR? Key concern: it needs a GnuTLS dependency
   │   for sensor communication. Is that acceptable?"
   │   └── This single question determines whether upstream is viable
   │       BEFORE you invest months of work
   └── Fork 0x00002a/libfprint to your own GitHub (preservation)

2. Hardware Validation
   ├── Install CachyOS (dual-boot, keep Windows)
   ├── lsusb | grep 27c6:5110
   ├── Flash firmware: goodix-fp-dump → sudo .venv/bin/python3 run_5110.py
   ├── Verify image capture works (goodix-fp-dump outputs images directly)
   └── Install existing AUR package to confirm baseline functionality
       ├── paru -S libfprint-goodixtls-git
       ├── Fix GCC 15 if needed (cherry-pick from kase1111-hash fork)
       └── fprintd-enroll / fprintd-verify

3. Study Upstream Patterns
   ├── Read 2–3 existing upstream drivers end-to-end
   │   ├── goodixmoc (same vendor, MOC variant — closest reference)
   │   ├── elanmoc or egismoc (recently accepted — shows current standards)
   │   └── A FpImageDevice driver (since goodixtls uses FpImageDevice)
   ├── Read HACKING.md contribution guidelines
   ├── Study FpiSsm state machine pattern (used by all drivers)
   └── Study how GnuTLS custom transport works
       └── gnutls_transport_set_push/pull_function() documentation
```

**Exit criteria:**
- Hardware confirmed working (images captured)
- @hadess has responded to the TLS dependency question
- You understand upstream driver patterns well enough to start coding

### Phase 2: Upstream-Quality Driver Development (Weeks 3–8)
**Goal:** Build the driver correctly from the start — GnuTLS, GLib async, upstream coding standards.

The approach: take the *protocol logic* from the community driver (what bytes to send, what responses to expect, how to decode images) but rewrite the *integration layer* (how TLS is handled, how async I/O works, how the driver registers with libfprint).

```
Layer 1: TLS Transport (Week 3–4)
├── Implement GnuTLS session with custom transport callbacks
│   ├── Push function: queues data into FpiUsbTransfer
│   ├── Pull function: reads from received USB data buffer
│   └── Handshake driven by FpiSsm state machine
├── Test: can you complete a TLS handshake with the sensor?
│   └── Compare byte traces with goodix-fp-dump for validation
└── This is the hardest part — get it right before moving on

Layer 2: Goodix Protocol (Week 4–5)
├── Port goodix_proto.c packet framing (keep as-is — it's protocol logic)
├── Port goodix.c USB command/response handling
│   └── Convert any blocking calls to FpiSsm states
├── Port sensor initialization sequence
└── Test: can you send commands and get responses?

Layer 3: Image Capture (Week 5–6)
├── Port goodix5xx.c image capture pipeline
├── Replace OpenCV preprocessing with lightweight alternatives
│   ├── Noise reduction: simple box/median filter (~50 lines of C)
│   ├── Contrast: histogram equalization (~30 lines)
│   └── Finger detection: use libfprint's fpi_image_detect_finger()
├── Port goodix511.c device-specific parameters (5110 resolution, etc.)
└── Test: can you capture a fingerprint image via libfprint?

Layer 4: Matching (Week 6–7)
├── Experiment: upscale 80×64 → 320×256 with bilinear interpolation
│   └── Feed to NBIS/bozorth3 — does it find minutiae?
│       ├── If YES → no SIGFM needed! Simplest upstream path.
│       └── If NO → port SIGFM
│           ├── Extract SIGFM into a clean, self-contained module
│           ├── Propose as a libfprint core matching alternative
│           └── Justify: "low-res MOH sensors cannot use NBIS"
└── Test: fprintd-enroll + fprintd-verify with the new driver

Layer 5: Polish (Week 7–8)
├── Meson build integration (standard driver registration)
├── Coding standards compliance (upstream style, GTK-Doc, -Werror clean)
├── Write tests (virtual device tests if possible)
├── Support full 51xx family: 5110, 5117, 5120, 521d
│   └── Collaborate with @gulp for 5117-specific validation
└── Documentation: README, supported devices list entry
```

**Critical design decisions to make early:**

| Decision | When to Decide | How |
|---|---|---|
| GnuTLS vs OpenSSL | Before writing any TLS code | Ask @hadess in Phase 1. Default: GnuTLS. |
| SIGFM vs NBIS+upscale | After Layer 3 (need captured images to test) | Experiment with NBIS on upscaled images. Data-driven. |
| OpenCV replacement | During Layer 3 | Replace function by function. Most are <50 lines of C. |
| Single driver or per-device | During Layer 2 | Follow goodixmoc pattern (single driver, device table). |

### Phase 3: Upstream Submission (Week 8+)
**Goal:** Submit merge request to gitlab.freedesktop.org and iterate through review.

```
1. Pre-submission checklist
   ├── Builds cleanly with -Werror on GCC 15 and Clang
   ├── All tests pass
   ├── meson.build integration follows existing patterns
   ├── GTK-Doc for any public API additions
   ├── No OpenSSL, no OpenCV, no pthreads
   ├── GnuTLS as optional dependency (configurable in meson)
   └── Tested on real hardware (5110 at minimum)

2. Submit MR to gitlab.freedesktop.org/libfprint/libfprint
   ├── Title: "Add Goodix TLS (51xx MOH) sensor support"
   ├── Description: explain the TLS requirement, reference hardware
   ├── CC: @hadess, @benzea (if active)
   └── Link to community fork for provenance

3. Review cycles
   ├── Expect 2–8 weeks of review
   ├── Be prepared for:
   │   ├── "Why does this need TLS?" — have a clear technical explanation
   │   ├── "Can you reduce the GnuTLS surface?" — minimize to just what's needed
   │   ├── "The image quality is poor" — explain 80×64 is a hardware limitation
   │   └── Architectural refactoring requests
   └── Iterate and resubmit
```

### Fallback: Self-Maintained Patch Package
**If upstream rejects the MR** (most likely reason: TLS dependency deemed too complex), the upstream-quality code is *still valuable*. It's already been modernized to GnuTLS + GLib async, so it's better than the original community driver.

```
Fallback plan:
├── Your driver code is already clean and working
├── Create a patch series against upstream libfprint:
│   ├── Patch 1: Add libfprint/drivers/goodixtls/ directory
│   ├── Patch 2: Register driver in meson.build
│   ├── Patch 3: Add GnuTLS dependency to meson.build
│   └── Patch 4: (Optional) SIGFM matching module
├── Package as AUR: libfprint-goodix5110
│   └── Source: upstream tarball + patches
│   └── Replaces system libfprint (unavoidable without plugin mechanism)
│   └── But patches are small and easy to maintain across releases
├── Publish patches on GitHub for other distros
└── Update Arch Wiki with correct instructions
```

**Key advantage of building upstream-first:** Even if rejected, you end up with a *better* self-maintained driver than if you'd started with the old OpenSSL/pthreads code. The GnuTLS/GLib async work isn't wasted — it makes the code more maintainable either way.

---

## Coordination with @gulp and PR #32

@gulp's PR #32 adds 5117 support — same 51xx sensor family. This is a natural collaboration:

| Action | Timing |
|---|---|
| Watch PR #32 for resubmission | Now (Phase 1) |
| Offer 5110 hardware testing | Phase 1, when contacting @gulp |
| Share GnuTLS migration work | Phase 2 — @gulp may benefit from it too |
| Co-submit or chain MRs | Phase 3 — ideally a single MR covering 5110+5117 |

@gulp's biggest value isn't just the code — it's the @hadess connection. If @gulp resubmits and @hadess engages, that's the upstream entry point for the entire 51xx family.

---

## Decision Tree

```
START
  │
  ▼
Ask @hadess: "Is a GnuTLS dependency acceptable for a new driver?"
  │
  ├── YES (or encouraging)
  │   └── Full upstream path viable → Phase 1 → 2 → 3
  │
  ├── NO
  │   └── Upstream path blocked → Phase 1 → 2 → Fallback
  │       (still build with GnuTLS/GLib — better code either way)
  │
  └── NO RESPONSE (likely, maintainers are busy)
      └── Proceed with upstream path anyway → Phase 1 → 2 → 3
          └── Worst case: MR rejected at Phase 3, you have Fallback
```

---

## Effort Summary

| Phase | Effort | Outcome |
|---|---|---|
| **Phase 1** | 1–2 weeks | Hardware working, community engaged, upstream patterns understood |
| **Phase 2** | 4–6 weeks | Clean GnuTLS/GLib driver, tested on real hardware |
| **Phase 3** | 2–8 weeks (calendar) | Upstream MR submitted and iterated |
| **Fallback** | 1–2 days | Patch-based AUR package from Phase 2 code |
| **Total** | ~2–4 months | Either upstream merge or clean self-maintained package |

---

## Why NOT Start Over From Scratch

The existing code represents ~4 years of specialized reverse engineering:
1. The Goodix TLS protocol (packet framing, command set, handshake sequence)
2. The SIGFM algorithm's necessity for 80×64 sensors
3. The image capture pipeline (noise reduction, finger detection, orientation)

**None of this protocol knowledge changes when switching from OpenSSL to GnuTLS.** What bytes the sensor expects, what responses it sends, how to decode the image — that's all the same. The rewrite (Phase 2) replaces the *integration layer* (~30% of the code) while keeping the *protocol layer* (~70%) intact. This is modernization, not reinvention.

---

## First Actions (Do Before Installing CachyOS)

1. **On GitHub:**
   - Fork `0x00002a/libfprint` to your own account (preservation — most important)
   - Star and watch `goodix-fp-linux-dev/libfprint` for notifications
   - Watch PR #32 for resubmission

2. **Community outreach:**
   - Join the [Goodix FP Discord](https://discord.com/invite/6xZ6k34Vqg)
   - DM or @ @egormanga about PR #32 status and project direction
   - Contact @gulp — are they planning to resubmit?
   - **Critical question for @hadess:** Would a goodixtls driver MR be welcome? The driver needs GnuTLS for sensor communication — is that an acceptable dependency?

3. **Study material (can do now, on Windows):**
   - Read upstream libfprint driver source: `goodixmoc`, `elanmoc`, `egismoc`
   - Read GnuTLS custom transport documentation
   - Read GLib `FpiSsm` state machine pattern in existing drivers

4. **On the hardware (Windows):**
   - Note the current firmware version (Device Manager → Goodix device → Details)
   - Download the Goodix Windows driver installer (backup for future firmware needs)

## Sources

- All analysis documents in this project:
  - [00-action-plan-and-threads-to-pull.md](00-action-plan-and-threads-to-pull.md)
  - [01-device-and-ecosystem-overview.md](01-device-and-ecosystem-overview.md)
  - [02-development-status-and-known-issues.md](02-development-status-and-known-issues.md)
  - [03-architecture-and-technical-deep-dive.md](03-architecture-and-technical-deep-dive.md)
  - [05-internet-research-findings.md](05-internet-research-findings.md)
- Upstream libfprint: [gitlab.freedesktop.org/libfprint/libfprint](https://gitlab.freedesktop.org/libfprint/libfprint)
- Version gap: fork at 1.94.5, upstream at 1.94.10
- Driver structure: 10 files, self-contained, uses standard FpImageDevice API
- No plugin mechanism in libfprint (drivers are compile-time only)
- GnuTLS custom transport: [gnutls.org/manual — Custom Transport](https://www.gnutls.org/manual/html_node/Setting-up-the-transport-layer.html)

````
