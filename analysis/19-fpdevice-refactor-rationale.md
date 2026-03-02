# 19 — FpDevice Refactor Rationale

## Decision

Refactor the goodixtls driver from `FpImageDevice` to `FpDevice` (Strategy B).

## Why FpImageDevice Was Originally Chosen

1. The GF511 (27c6:5110) is a **Match-on-Host image sensor** — it sends raw
   64×80 pixel fingerprint images to the host for all processing. `FpImageDevice`
   appeared to be the correct base class since it provides an image-capture
   pipeline with built-in NBIS/bozorth3 minutiae extraction and matching.

2. The original 0x00002a fork inherited this architecture decision.

3. After porting to the current codebase, **NBIS was tested and found non-viable**
   (see `10-nbis-viability-test.md`). The 64×80 images at 508 DPI yield only
   0–2 minutiae — far below the minimum needed for bozorth3 matching.

4. SIGFM (FAST-9 + BRIEF-256) was developed as a replacement matching algorithm,
   purpose-built for small-area sensor images.

5. Rather than switching the base class, **three custom vfuncs** (`extract`,
   `build_print`, `compare`) were grafted onto `FpImageDeviceClass` to hook
   SIGFM into FpImageDevice's extraction pipeline.

## Why This Doesn't Work for Upstream

The vfunc additions required **~283 lines of changes across 6 core framework
files**:

- `libfprint/fpi-image-device.c` (+165 lines)
- `libfprint/fpi-image-device.h` (+50 lines)
- `libfprint/fp-image-device.c`
- `libfprint/fpi-print.c` / `fpi-print.h` (`FPI_PRINT_SIGFM`, new APIs)
- `libfprint/fp-print.c` (SIGFM serialization)

These changes affect **all** image device drivers, not just goodixtls. Every
other upstream driver with custom matching (goodixmoc, synaptics, elanmoc)
extends `FpDevice` directly and handles its own enroll/verify/identify
orchestration. A maintainer would immediately ask: *"why does this driver need
special treatment?"*

## Why FpDevice Is the Correct Base Class

- **Upstream precedent**: goodixmoc (same vendor, Goodix) uses `FpDevice`
  directly with `open`/`close`/`enroll`/`verify`/`identify`/`cancel` vfuncs.
- **Self-containment**: All driver logic stays under `libfprint/drivers/goodixtls/`
  with zero core framework modifications.
- **Matching algorithm flexibility**: `FpDevice` imposes no matching pipeline —
  the driver is free to use SIGFM, NBIS, or any algorithm internally.

The upstream maintainer @benzea explicitly supports non-NBIS matching:
> *"What we really need is someone implementing an algorithm that really works
> well with a single frame. Minutiae based matching just isn't going to cut it
> for that image size."*

## Impact

| Metric                | Before (FpImageDevice) | After (FpDevice) |
|-----------------------|------------------------|------------------|
| Core files modified   | 6                      | 0                |
| Core lines changed    | ~283                   | 0                |
| New upstream APIs     | 5                      | 0                |
| Self-containment      | 5/10                   | ~9/10            |

## Execution

See `plan-fpDeviceRefactor.prompt.md` for the detailed step-by-step plan.
Steps 0–9 (the code refactor) and Step 10 (test validation) are complete.

---

## Completion Status

**Date:** 2025-07-18
**Result:** `meson test -C build goodixtls511 -v` → **OK** (1/1 pass, 0 fail)

The refactored driver correctly performs 20-stage enrollment and single-scan
verify against the umockdev pcap replay, with `G_DEBUG=fatal-warnings` active
(upstream default). Zero modifications to shared test infrastructure.

### Uncommitted Changes (working tree vs base `8fea0a5~1`)

```
 libfprint/drivers/goodixtls/goodix.c    |  31 +-   (TLS emulation fixes, shared)
 libfprint/drivers/goodixtls/goodix.h    |  15 +-   (header updates)
 libfprint/drivers/goodixtls/goodix511.c |  37 +-   (activation SSM cleanup)
 libfprint/drivers/goodixtls/goodix5xx.c | 679 +++++  (the entire FpDevice refactor)
 libfprint/drivers/goodixtls/goodix5xx.h |  36 +-   (header updates)
 libfprint/fp-print.c                    |  52 ---   (REVERT: remove sigfm from core)
 libfprint/fpi-image-device.c            | 172 +---    (REVERT: remove sigfm hooks)
 libfprint/fpi-image-device.h            |  50 +--   (REVERT: remove sigfm hooks)
 libfprint/fpi-print.c                   |  75 +--    (REVERT: remove FPI_PRINT_SIGFM)
 libfprint/fpi-print.h                   |   7 -     (REVERT: remove FPI_PRINT_SIGFM)
 libfprint/meson.build                   |   4 +-   (sigfm lib linkage)
 tests/goodixtls511/custom.py            |   5 +-   (upstream-aligned close pattern)
```

Files marked "REVERT" are removing previously-committed core framework changes
(FPI_PRINT_SIGFM, image-device sigfm hooks) — the whole point of the refactor.

---

## Bugs Fixed During Refactor

### 1. FDT_UP Deadlock on Last Enroll Scan

The 20th enroll scan sent `FDT_UP` and waited for ACK+NOTIF, but the pcap shows
the original driver called `goodix_reset_state()` + `ENABLE_CHIP` before the
device responded. ACK/NOTIF never arrives → infinite hang.

**Fix:** Added `gboolean last_scan` to private state. On the last enroll scan,
FDT_UP is sent fire-and-forget (NULL callback), followed by immediate
`goodix_reset_state()` + `fpi_ssm_next_state()`.

### 2. SEGFAULT in `enroll_ssm_done`

`deactivate_device()` called `goodixtls5xx_cleanup()` which freed
`priv->enroll_data`, but the SSM done callback still needed it to build the
final print → use-after-free.

**Fix:** Moved `goodixtls5xx_cleanup()` into SSM done callbacks and `dev_close`
instead of `deactivate_device()`.

### 3. `last_scan` Not Reset for Verify

`last_scan` was set TRUE during final enroll but never cleared before verify.
The verify scan's FDT_UP was incorrectly treated as fire-and-forget.

**Fix:** Added `priv->last_scan = FALSE` to `dev_verify_identify()`.

### 4. `probe_print` Use-After-Free in Verify/Identify (Root Cause of Test Failure)

In the `VERIFY_COMPARE` state handler, `probe_print` was declared as
`g_autoptr(FpPrint)`. When passed to `fpi_device_verify_report()`, the framework
calls `g_object_ref_sink()` internally and stores a reference. But when the block
scope ended, `g_autoptr` called `g_object_unref()` on the same pointer, dropping
the ref count to 0. Later, `fp_device_verify_finish()` tried
`g_object_ref(data->print)` on the freed object → SIGSEGV (exit 139).

This was misdiagnosed for months as an umockdev cleanup WARNING / `G_DEBUG`
infrastructure problem. The umockdev `WARNING` ("Connection reset by peer") was
actually a **consequence** of the child segfaulting (broken pipe), not a separate
issue.

**Fix:** Changed both `fpi_device_verify_report` and `fpi_device_identify_report`
calls to use `g_steal_pointer(&probe_print)` instead of `probe_print`, properly
transferring ownership so the autoptr sees NULL on scope exit.

---

## Test Infrastructure

### Running the test

```bash
meson test -C build goodixtls511 -v
```

### Key details

- Tests use `FP_DEVICE_EMULATION=1` with deterministic TLS for pcap replay
- Test data: `tests/goodixtls511/device` + `tests/goodixtls511/custom.pcapng`
- `custom.py` follows standard upstream pattern: `d.close_sync()` / `del d` / `del c`
- `tests/umockdev-test.py` matches upstream exactly (zero diff) — no workarounds needed
- The pcap does NOT contain close-sequence traffic; `goodix_dev_deinit()` does
  only in-memory cleanup + kernel ioctl, so `close_sync()` works without it

### Pcap structure reference

| Block Range | Phase | Notes |
|-------------|-------|-------|
| 2–50 | Initial activation | NOP → ENABLE_CHIP → FW_VER → PSK → RESET → IDLE → ODP → MCU_CONFIG×4 → ODP2 → SCAN_FREQ |
| 51–95 | TLS handshake | TLS_INIT → 3× TLS read/write → HANDSHAKE DONE |
| 96–1053 | 20 enroll scans | Each: QUERY_MCU → FDT_DOWN → CALIBRATE → FDT_MODE → GET_IMG → FDT_UP(+ACK+NOTIF) |
| 1054–1056 | Last scan's FDT_UP | Fire-and-forget: S-WR FDT_UP, C-WR, S-RD (pending) |
| 1057–1155 | Re-activation + TLS | Full activation sequence + TLS handshake for verify |
| 1156–1195 | Verify scan | Same scan pattern, FDT_UP has proper ACK+NOTIF |
| 1196–1197 | Trailing | S-RD (pending) + C-RD 0B (empty) |
