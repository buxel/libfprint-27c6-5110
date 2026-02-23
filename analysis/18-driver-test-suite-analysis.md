# 18 — Driver Test Suite Analysis

**Date:** 2026-02-23  
**Purpose:** Assess what upstream driver tests look like and plan goodixtls test creation.

---

## Upstream Test Framework

All libfprint driver tests use **umockdev** — a USB device mocking/replay framework.
Tests run recorded USB traffic against the driver in an isolated environment with
`FP_DEVICE_EMULATION=1`.

### Test directory structure

Every driver test lives in `tests/<driver-name>/` with 2–3 files:

| File | Purpose |
|------|---------|
| `device` | umockdev sysfs device description (VID/PID, bus topology, USB attributes) |
| `capture.ioctl` or `custom.pcapng` | Recorded USB traffic for replay |
| `capture.png` or `custom.py` | Reference output image, or Python test script |

### Two test patterns

1. **Capture tests** (image drivers: elan, vfs5011, aes2501, etc.)
   - Record one USB capture session → replay → compare output image pixel-for-pixel
     against a reference PNG.
   - Tests the image decode/processing pipeline only.
   - Files: `capture.ioctl` + `capture.png` + `device`

2. **Custom script tests** (MoC/storage drivers: synaptics, goodixmoc, fpcmoc, etc.)
   - Python script using GObject Introspection (`FPrint` GI API) exercises the
     full workflow: `open → enroll → verify → delete → close`.
   - Tests the complete protocol state machine.
   - Files: `custom.pcapng` + `custom.py` + `device`

### Drivers with tests (26 total)

All upstream drivers have umockdev tests. The `custom.py` pattern is used by
11 drivers (mostly MoC/match-on-chip). Image-only drivers use `capture.ioctl`.

### Test runner

`tests/umockdev-test.py` is the shared runner. It:
1. Reads the `device` file to set up mock sysfs
2. Starts `umockdev-run` with ioctl/pcapng replay
3. Runs either `capture.py` (image comparison) or `custom.py` (workflow)
4. Reports pass/fail

`tests/meson.build` registers each driver directory in `drivers_tests[]`.

---

## Requirements for goodixtls Test

### Challenges

1. **TLS-encrypted USB traffic** — All USB communication after the initial handshake
   is TLS-encrypted. A pcapng replay only works if TLS key derivation is deterministic
   during emulation. The driver must check `FP_DEVICE_EMULATION` and use fixed
   random values (e.g., fixed GnuTLS ECDHE private key), otherwise each replay
   produces different ciphertext.

2. **Capture-only vs full workflow** — As an image driver (not MoC), goodixtls
   could use either pattern:
   - **Capture test**: Simpler — just verify the image pipeline (decode → subtract →
     stretch → unsharp → output). Doesn't test SIGFM.
   - **Custom script test**: Full enroll+verify — tests the entire pipeline including
     SIGFM feature extraction, serialization, and matching.

3. **Recording the session** — Need to capture USB traffic with `umockdev-record`
   on a live device. Must be done with `FP_DEVICE_EMULATION=1` if using
   deterministic TLS.

### Implementation plan

1. **Add `FP_DEVICE_EMULATION` support to `goodixtls.c`**
   - When the env var is set, use a fixed TLS pre-master secret or fixed ECDH
     private key so that replayed sessions produce identical ciphertext.
   - Pattern: check `g_getenv("FP_DEVICE_EMULATION")` during TLS setup.

2. **Record a USB session**
   - Run `umockdev-record` on a live 27c6:5110 device with emulation mode
   - Capture a full enroll + verify cycle
   - Save as `tests/goodixtls511/custom.pcapng`

3. **Create test files**
   - `tests/goodixtls511/device` — sysfs description for 27c6:5110
   - `tests/goodixtls511/custom.pcapng` — recorded USB traffic
   - `tests/goodixtls511/custom.py` — Python script: open, enroll, verify, close

4. **Register in `tests/meson.build`**
   - Add `'goodixtls511'` to `drivers_tests[]`

### Effort estimate

- Emulation mode TLS support: ~2 hours (need to understand GnuTLS API for
  fixed key injection)
- Recording + test creation: ~1 hour
- Debugging replay issues: ~1–2 hours (TLS timing, state machine edge cases)
- **Total: ~4–5 hours**

### Priority

Medium. Not required for AUR publish or basic upstream merge, but would
significantly strengthen the upstream MR and prevent regressions. All other
upstream drivers have tests — lacking one makes the MR stand out negatively.
