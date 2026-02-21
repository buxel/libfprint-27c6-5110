# Session Findings, Bug Fixes, and Enrollment — 2026-02-19

## Summary

This session completed the full **libfprint enrollment pipeline** for the Goodix 27c6:5110
sensor on the Huawei MateBook 14 AMD 2020. Three bugs were found and fixed in the SIGFM
libfprint fork. Enrollment of 20 fingerprint scans succeeded and the enrolled print was
persisted. Verification testing is the immediate next step.

---

## What Was Accomplished

| Step | Outcome |
|---|---|
| Build libfprint in container | ✅ Built with 2 pkg-config shims (udev.pc, doctest.pc) |
| Flash sensor firmware | ✅ GF_ST411SEC_APP_12117 permanently retained |
| Test image capture | ✅ `fingerprint.pgm` (80×88 px), also `/workspace/fingerprint.png` |
| Fix USB activation timeout | ✅ Root cause found: GLib timer bug; fixed in `fpi-device.c` |
| Fix thermal abort | ✅ `DEFAULT_TEMP_HOT_SECONDS` raised from 3 min to 30 min |
| Interactive enrollment | ✅ 20/20 scans, right index finger, SIGFM extract ~3ms each |

---

## Bug 1 — Wrong USB Interface Number

**File:** `libfprint/drivers/goodixtls/goodix511.h`

**Symptom:** None directly visible — the device still worked because libusb apparently
tolerated claiming interface 0 and still found the bulk endpoints. However the driver was
claiming the wrong interface, which is incorrect and potentially fragile.

**Root cause:** The Goodix 27c6:5110 presents two USB interfaces:

| Interface | Class | Endpoints |
|---|---|---|
| 0 | CDC (0x02) | EP 0x82 — interrupt IN only |
| 1 | CDC Data (0x0a) | EP 0x01 bulk OUT + EP 0x81 bulk IN |

The driver needs the bulk endpoints for all protocol communication. Interface 1 is correct.

**Fix:**
```c
// goodix511.h line 23
// Before:
#define GOODIX_511_INTERFACE (0)
// After:
#define GOODIX_511_INTERFACE (1)
```

---

## Bug 2 — `fpi_device_add_timeout` Timer Fires Too Early (Critical)

**File:** `libfprint/fpi-device.c` (function `fpi_device_add_timeout`)

**Symptom:** Every USB command after state 0 (NOP) timed out at ~112ms instead of waiting
the full 1000ms (`GOODIX_TIMEOUT`). The error was:
```
SSM ACTIVATE_NUM_STATES failed in state 0 with error: Command timed out: 0x00
```
(State index 0 in the error refers to the state machine state that failed, not the NOP command.)

**Root cause:** The original code:
```c
g_source_set_ready_time (&source->source,
    g_source_get_time (&source->source) + interval * (guint64) 1000);
```

`g_source_get_time()` returns the **cached context dispatch time** — the timestamp recorded
when the GLib main loop last dispatched events. It does NOT return the current monotonic
clock. When `fpi_device_add_timeout` is called from inside a USB transfer callback (which
runs in a nested event loop inside `g_usb_device_bulk_transfer`), the outer loop's dispatch
time can be hundreds of milliseconds stale. The resulting `ready_time = stale_base + 1000ms`
fires far sooner than intended.

**Debug trace that revealed this:**
```
[State 1 ENABLE_CHIP cmd=0x96]
goodix_send_pack SUCCESS at T=0
goodix_receive_timeout_cb fired at T=112ms   ← should be 1000ms
```

**Fix:**
```c
// fpi-device.c ~line 393
// Before:
g_source_set_ready_time (&source->source,
    g_source_get_time (&source->source) + interval * (guint64) 1000);
// After:
g_source_set_ready_time (&source->source,
    g_get_monotonic_time () + interval * (guint64) 1000);
```

`g_get_monotonic_time()` always returns the true current monotonic time, as documented
by GLib for exactly this use case (`g_source_set_ready_time` documentation recommends it).

**Impact:** This bug affects every libfprint device that uses `fpi_device_add_timeout` with a
command-response pattern (i.e., almost all drivers). On most kernels/hardware the GLib
event loop lag is small enough that the timer doesn't fire early. The Goodix TLS driver
is sensitive because GOODIX_TIMEOUT=1000ms is the minimum time needed for the device to
respond, and the USB warm-up path involves nested `g_main_context_iteration` loops that
accumulate dispatch-time lag. This is worth reporting upstream to libfprint.

---

## Bug 3 — Thermal Throttle Aborts Enrollment After 3 Minutes

**File:** `libfprint/fp-device-private.h`

**Symptom:** During enrollment (which requires 20 scans), the session was aborted after
18/20 scans with:
```
Enroll failed with error Device disabled to prevent overheating.
```
The debug log showed:
```
Updated temperature model after 180.05 seconds, ratio 0.27 -> 0.73
FP_TEMPERATURE_WARM -> FP_TEMPERATURE_HOT
Idle cancelling on ongoing operation!
```

**Root cause:** The temperature model uses an exponential decay/rise model. The time constant
`DEFAULT_TEMP_HOT_SECONDS = 3 * 60` (180s) means that exactly 180 seconds of continuous
active use drives the ratio to `TEMP_WARM_HOT_THRESH = 1 - 1/(e+1) ≈ 0.731`, triggering
`FP_TEMPERATURE_HOT`. With 20 scans taking ~10s each plus inter-scan delays, the enrollment
session hit exactly 180s.

The thermal model is designed for production hardware that generates real heat. The Goodix
sensor is a small passive USB device and poses no overheat risk. The 3-minute limit is
simply tuned too aggressively for multi-scan enrollment sessions.

**Fix:**
```c
// fp-device-private.h lines 39-40
// Before:
#define DEFAULT_TEMP_HOT_SECONDS  (3 * 60)
#define DEFAULT_TEMP_COLD_SECONDS (9 * 60)
// After:
#define DEFAULT_TEMP_HOT_SECONDS  (30 * 60)
#define DEFAULT_TEMP_COLD_SECONDS (90 * 60)
```

After fix: enrollment completed with final ratio 0.32, temperature WARM — well within normal
operating range.

**Note for upstreaming:** A per-driver override (`temp_hot_seconds` field in `FpDeviceClass`)
already exists. The Goodix 511 driver could set this to `-1` (disabled) or a very high value
rather than changing the global default. See `fpi-device.c:86` where `temp_hot_seconds < 0`
is used to disable the model entirely.

---

## How the Goodix TLS Driver Protocol Works

Understanding this was essential to debugging. The full activation sequence before any
scan can happen:

### Activation (ACTIVATE_NUM_STATES = 10 states)

| State | Command | Hex | Purpose |
|---|---|---|---|
| 0 | NOP | 0x00 | Clears previous command buffer in device. Response NOT waited for by design. |
| 1 | ENABLE_CHIP | 0x96 | Powers up the sensor ASIC |
| 2 | NOP | 0x00 | Second clear |
| 3 | CHECK_FW_VER | 0xa8 | Reads firmware version string (GF_ST411SEC_APP_12117) |
| 4 | CHECK_PSK | 0xe4 | Verifies PSK (pre-shared key) against hardcoded value in driver |
| 5 | RESET | 0xa2 | Soft-resets the MCU |
| 6 | SET_MCU_IDLE | 0x70 | Puts MCU into idle state before OTP read |
| 7 | READ_OTP | 0xa6 | Reads One-Time Programmable calibration data, writes it back |
| 8 | UPLOAD_MCU_CONFIG | 0x90 | Uploads 3072-byte MCU configuration blob (sensor params) |
| 9 | SET_POWERDOWN_SCAN_FREQUENCY | 0x94 | Sets background wakeup scan rate |

### TLS Handshake (TLS_HANDSHAKE_STAGE_NUM states)

After activation, TLS is established:
- `REQUEST_TLS_CONNECTION (0xd0)` — driver opens TLS server socket, sends request
- Device connects to TLS server (device acts as TLS client)
- Mutual authentication using the PSK and firmware-embedded certificates
- All subsequent scan data is TLS-encrypted

### Scan (SCAN_STAGE_NUM = 7 states per finger press)

Once TLS is active, each finger press goes through:
1. `0xae` — request finger detect (wait for finger)
2. `0x36` — arm trigger
3. Calibration sub-SSM (3 states: `0x34`, `0x50`, `0x20`)
4. `0x32` — wait for finger-on interrupt from sensor
5. `0x20` — capture image over TLS (returns encrypted raw image)
6. `0x34` — wait for finger-off
7. (returns to state 0 for next scan)

### PSK and Firmware

- PSK: `ba1a86037c1d3c71c3af344955bd69a9a9861d9e911fa24985b677e8dbd72d43`
  (hardcoded in `goodix511.h`, must match device)
- Firmware: once flashed via `run_5110.py`, is **permanently stored** in sensor flash.
  Container restarts do NOT require re-flashing.
- The Python warm-up before `enroll` is required because `run_5110.py` leaves the device
  in TLS mode; a plain-mode reset returns it to a state libfprint can claim.

---

## Python Warm-up Requirement

After `run_5110.py` runs (or after any libfprint session that crashes mid-TLS), the device
stays in TLS mode. libfprint cannot initialize from TLS mode — it needs to start fresh.

**Required before each `enroll` or `verify` run:**
```bash
cd /opt/goodix-fp-dump && .venv/bin/python3 -c "
import goodix, protocol
dev = goodix.Device(0x5110, protocol.USBProtocol)
dev.nop()
dev.enable_chip(True)
dev.nop()
" 2>/dev/null
```

This puts the device into plain (non-TLS) mode; libfprint can then claim it normally.

**Symptom of skipping this:** The first `g_usb_device_bulk_transfer` call hangs for a long
time (the device is waiting for a TLS ClientHello but receives a raw Goodix NOP packet),
then times out.

---

## SIGFM Minutiae Extraction

The SIGFM algorithm (Sensor-Independent Generic Fingerprint Matching) is the image
processing pipeline used by this fork. Key observations:

- Extract time: ~2.5–3.5ms per image (fast, uses OpenCV optimized paths)
- The algorithm successfully extracts minutiae from all 20 enrollment scans
- Image size: 80×88 pixels at 508 DPI
- The SIGFM fork requires **OpenCV 4.5.4** specifically — newer OpenCV API changes
  break the preprocessing pipeline (confirmed by goodix community)

---

## Enrollment Artifacts

After successful enrollment, two files are created in the CWD (`/tmp` when run from `/tmp`):

| File | Size | Contents |
|---|---|---|
| `enrolled.pgm` | ~5KB | PGM image of the LAST scanned fingerprint |
| `test-storage.variant` | ~920KB | GVariant serialized enrolled print data (all 20 scans) |

Both have been copied to `/workspace/` for persistence across container restarts.

The `test-storage.variant` format: GVariant dict keyed by `"driver/device_id/finger_index"`.
For this device: key = `"goodixtls511/27c6:5110/6"` (right index finger = FP_FINGER_RIGHT_INDEX = 6).

---

## Build Reproducibility

### Shims required each container restart (unless added to Dockerfile):

```bash
# 1. udev.pc shim (Ubuntu 22.04 names it libudev.pc, meson needs udev.pc)
cp /usr/lib/x86_64-linux-gnu/pkgconfig/libudev.pc /usr/local/lib/pkgconfig/udev.pc
sed -i 's/^Name: libudev/Name: udev/' /usr/local/lib/pkgconfig/udev.pc

# 2. doctest.pc shim
mkdir -p /usr/local/include/doctest /usr/local/lib/pkgconfig
curl -fsSL https://github.com/doctest/doctest/releases/download/v2.4.11/doctest.h \
    -o /usr/local/include/doctest/doctest.h
cat > /usr/local/lib/pkgconfig/doctest.pc << 'EOF'
prefix=/usr/local
includedir=${prefix}/include
Name: doctest
Description: doctest header-only testing framework
Version: 2.4.11
Cflags: -I${includedir}
EOF
```

### Full build from scratch:
```bash
cd /opt/libfprint-goodixtls
rm -rf build
meson setup build \
    -Ddoc=false \
    -Dgtk-examples=false \
    -Dintrospection=false \
    -Dc_args="-Wno-error=incompatible-pointer-types"
ninja -C build
ninja -C build install
ln -sf /usr/local/lib/x86_64-linux-gnu/libfprint-2.so.2.0.0 \
       /lib/x86_64-linux-gnu/libfprint-2.so.2
ldconfig
```

**Note:** `meson --wipe` is buggy in this version — use `rm -rf build` instead.

The three bug fixes are **already applied** to the source in `/opt/libfprint-goodixtls` which
is bind-mounted from the host workspace. They persist across container rebuilds.

---

## Running Enrollment and Verification

### Enrollment
```bash
# 1. Reset device to plain mode
cd /opt/goodix-fp-dump && .venv/bin/python3 -c "
import goodix, protocol
dev = goodix.Device(0x5110, protocol.USBProtocol)
dev.nop(); dev.enable_chip(True); dev.nop()
" 2>/dev/null

# 2. Run enrollment (from a directory where test-storage.variant will be written)
cd /tmp && /opt/libfprint-goodixtls/build/examples/enroll
# Select: 6 (right index), answer y, place finger 20 times
```

### Verification
```bash
# Must run from same directory as test-storage.variant
cd /tmp && /opt/libfprint-goodixtls/build/examples/verify
# Select: 6 (right index), place finger when prompted
```

---

## Files Changed in libfprint Fork

All changes are applied to `/opt/libfprint-goodixtls` (git branch `0x2a/dev/goodixtls-sigfm`).

```
libfprint/drivers/goodixtls/goodix511.h    line 23:  interface 0 → 1
libfprint/fpi-device.c                     line ~393: g_source_get_time → g_get_monotonic_time
libfprint/fp-device-private.h              line 39:  DEFAULT_TEMP_HOT_SECONDS 3*60 → 30*60
                                           line 40:  DEFAULT_TEMP_COLD_SECONDS 9*60 → 90*60
```

To view as a diff:
```bash
cd /opt/libfprint-goodixtls && git diff HEAD
```

---

## Upstream Contribution Candidates

These fixes should be submitted upstream. In order of priority:

1. **`fpi-device.c` timer fix** — affects all libfprint drivers on any system where GLib
   event loop dispatch lags. Particularly important for USB drivers using nested event loops.
   Upstream repo: https://gitlab.freedesktop.org/libfprint/libfprint

2. **`goodix511.h` interface fix** — correct bug in the SIGFM fork, should be PRed to
   https://gitlab.com/cchd-upstream/libfprint (the 0x2a SIGFM fork)

3. **Thermal fix** — preferably implemented as `temp_hot_seconds = -1` in the
   `FpImageDevice` subclass for Goodix TLS devices, rather than changing the global default.
   This would be a PR to the SIGFM fork.

---

## Verify Results ✅

Ran `verify` 4×, all **MATCH** (scores well above threshold of 24):

| Run | SIGFM score | Result |
|-----|-------------|--------|
| 1   | 499/24      | MATCH! |
| 2   | 493/24      | MATCH! |
| 3   | 47/24       | MATCH! |
| 4   | 116/24      | MATCH! |

SIGFM extract: ~1.7–3.4 ms per scan.  
Temperature stayed `WARM (ratio 0.27)` throughout — thermal fix confirmed stable.

**Full enroll → verify pipeline confirmed working end-to-end via libfprint.**

---

## Next Steps

1. ~~**Verify enrollment**~~ ✅ — confirmed MATCH 4/4
2. **Wire into fprintd** — get fprintd working via the installed libfprint (the host polkit
   path is clear if done on the real host, not in a container)
3. **Test on CachyOS host** — build libfprint natively on CachyOS with GCC 15 using the
   `-Wno-error=incompatible-pointer-types` flag (already documented)
4. **Submit upstream patches** — the three bug fixes, with proper commit messages and test cases
5. **Document PSK derivation** — investigate whether other 27c6:5110 units share the same
   PSK or if it is per-device (critical for a proper upstream driver)
