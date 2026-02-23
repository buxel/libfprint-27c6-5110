# 16 — Firmware & PSK Compatibility: Making Flashing Redundant

**Date:** 2026-02-23 (updated 2026-02-24)  
**Status:** Partial success — firmware/PSK checks relaxed, but TLS key reset blocked on fw 12118

---

## 1. Problem

The driver hardcodes firmware version `GF_ST411SEC_APP_12117` and rejects
anything else via `strcmp()` during activation. The device PSK is also
hardcoded (`ba1a86...`) and compared byte-for-byte against the device
response.

When Windows (or a BIOS update) upgrades the sensor firmware to `12118`
and/or writes a different PSK, the Linux driver refuses to activate:

```
Invalid device firmware: "GF_ST411SEC_APP_12118" (code: 35)
```

Previously, the workaround was to reflash firmware 12117 + the hardcoded
PSK via `goodix-fp-dump`/`run_5110.py`.

---

## 2. Firmware Version History

| Version | Key Capability | Status |
|---------|---------------|--------|
| **12109** | Exposed `0xF2` memory read (raw image dump) | Command patched out in 12117 |
| **12117** | Supports Preset PSK Write (`0xe0`) | Driver's hardcoded expected version |
| **12118** | PSK Write (`0xe0`) reportedly removed | Current version on test device |

---

## 3. Two Separate PSK Concepts

The driver has **two completely independent PSK layers**:

### Device Preset PSK (identity token)

- **Commands:** Write `0xe0` (`GOODIX_CMD_PRESET_PSK_WRITE`), Read `0xe4` (`GOODIX_CMD_PRESET_PSK_READ`)
- **Hardcoded value:** `ba1a86037c1d3c71c3af344955bd69a9a9861d9e911fa24985b677e8dbd72d43`
- **Hardcoded flags:** `0xbb020003`
- **Purpose:** Device identity verification during activation — proves the sensor was provisioned for this driver
- **NOT used for encryption** — purely a handshake/identity check
- **Storage:** Written to sensor flash by `goodix-fp-dump`; persists across reboots
- **Defined in:** `goodix511.h` (`goodix_511_psk_0[]`, `GOODIX_511_PSK_FLAGS`)
- **Checked in:** `goodix5xx.c` → `goodixtls5xx_check_preset_psk_read()` (flags, length, memcmp)
- **Class-level:** Stored in `FpiDeviceGoodixTls5xxClass` struct fields (`psk`, `psk_len`, `psk_flags`)

### TLS Session PSK (encryption key)

- **Value:** 32 zero bytes — `static const guint8 goodix_psk[32] = { 0 }`
- **Purpose:** Actual cryptographic key for the GnuTLS PSK-DHE TLS 1.2 session
- **Used in:** `goodixtls.c` → `tls_psk_server_cb()` → GnuTLS handshake
- **Both sides agree:** Driver (server) and sensor firmware (client) both use all-zeros
- **Completely independent** of the device preset PSK

---

## 4. Empirical Test (2026-02-23)

### Test: Relax firmware check, observe PSK read on firmware 12118

**Changes applied:**
1. Firmware check: prefix match (`GF_ST411SEC_APP_121*`) instead of exact `strcmp()`
2. Added `g_info()` diagnostic logging to PSK read callback

**Results:**

| Probe | Result |
|-------|--------|
| FW prefix match (12118) | **PASS** — accepted |
| PSK Read (`0xe4`) on 12118 | **PASS** — command works, returns valid data |
| PSK value matches hardcoded? | **NO** — device returned `beab233281ba4484d3f0b90d34f26d3bc17df1a2a74a4f2103c7f156407fcbc7` |

**Journal output:**
```
Goodix 511: accepted firmware "GF_ST411SEC_APP_12118" (expected "GF_ST411SEC_APP_12117", prefix match)
Invalid device PSK: 0xbeab233281ba4484d3f0b90d34f26d3bc17df1a2a74a4f2103c7f156407fcbc7
```

### Conclusions

1. **Firmware 12118 is protocol-compatible** — all activation commands work
2. **PSK Read (`0xe4`) works on 12118** — the command was not removed
3. **Windows wrote a different PSK** — the device has a valid PSK, just not ours
4. **Reflashing is NOT required** — the driver should accept any device PSK

---

## 5. Root Cause: Why PSK Differs

The Windows kernel-mode WBDI driver (`.sys`) provisions its own PSK during
its activation flow. The decompiled user-mode DLLs (`EngineAdapter.c`,
`AlgoMilan.c`) contain:

- `PSKSimulationSwitch` — registry flag suggesting debug/fixed PSK mode
- `PSKCacheSwitch` — registry flag for PSK caching across sessions
- `[GTLS] HMAC Identity check error` — error string for PSK mismatch

The actual PSK provisioning runs in the kernel driver (not decompiled),
which writes its own PSK, overwriting the one `goodix-fp-dump` wrote.

The `ba1a86...` value was the PSK written by `run_5110.py` during the
initial firmware flash. Windows replaced it with `beab23...`. Both are
valid — the specific value doesn't matter as long as the TLS session PSK
(all-zeros) is unchanged.

---

## 6. Fix: Dynamic PSK Read

**Approach:** Accept whatever PSK the device returns instead of comparing
against a hardcoded value. The preset PSK was never a security boundary
(the all-zeros TLS key is the real auth); it was a provisioning sanity
check.

### Changes required

| File | Change |
|------|--------|
| `goodix5xx.c` `check_preset_psk_read()` | Remove 3-way validation (flags, length, memcmp). Accept any successful read with sane length. Log PSK at `fp_dbg()` level. |
| `goodix5xx.c` `check_firmware_version()` | Keep prefix match (already applied). Remove test `g_info()` scaffolding. |
| `goodix5xx.h` class struct | Remove `psk`, `psk_len`, `psk_flags` fields (no longer needed) |
| `goodix511.h` | Remove `GOODIX_511_PSK_FLAGS`, `goodix_511_psk_0[]` |
| `goodix511.c` `class_init` | Remove `xx_cls->psk*` assignments |
| `goodix511.c` `ACTIVATE_CHECK_PSK` | Change `goodix_send_preset_psk_read()` flags arg from `GOODIX_511_PSK_FLAGS` to `0` (or keep if device requires specific flags in request — test empirically) |
| `goodixtls.c` | **No changes** — TLS session PSK is independent |

### What stays the same

- TLS session PSK (all-zeros in `goodixtls.c`) — unchanged
- All other activation states — unchanged
- Protocol commands — unchanged
- Image capture and matching — unchanged

---

## 7. Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Device with no PSK at all | `success` check still catches this — read failure = activation failure |
| Corrupt PSK data | Length sanity check (0 < len ≤ 64) catches garbage |
| PSK flags value matters for read request | Test with flags=0; if device doesn't respond, keep `0xbb020003` for the request but skip response validation |
| TLS handshake fails after PSK change | TLS PSK (all-zeros) is independent; should not be affected. If it fails, the sensor firmware's TLS implementation may have changed — separate issue |

---

## 8. TLS Handshake Failure After Dynamic PSK Read

After implementing the firmware prefix match and dynamic PSK read (accepting
any device PSK), the TLS handshake **still fails**:

```
gnutls_handshake error: Decryption has failed.
```

The TLS handshake fails at stage 3 (server processes client's finished
message). This means the sensor firmware's TLS PSK no longer matches the
driver's all-zeros key.

**Root cause:** When Windows re-provisions the sensor, it changes:
1. The device preset PSK (identity token) — observed: `ba1a86...` → `beab23...`
2. The TLS session PSK — the actual encryption key used in TLS handshake

These are independent: having the correct device preset PSK does NOT help
establish the TLS session. The TLS key is a separate secret.

---

## 9. TLS PSK Experiment: Wiring Device PSK into TLS

**Hypothesis:** Maybe the device preset PSK hash IS the TLS session key
(i.e., Windows uses `SHA256(white_box)` as both identity and TLS key).

**Test:** Modified `goodixtls.c` TLS PSK callback to use the device-read
PSK (`beab23...`) instead of all-zeros.

**Result:** Still fails at the same point:
```
TLS PSK callback: using device-read PSK (len=32)
gnutls_handshake error: Decryption has failed.
```

**Conclusion:** The device preset PSK hash is NOT the TLS session key.
They are completely independent cryptographic values. The TLS key is
established during the Windows kernel driver's provisioning flow and is
NOT derivable from the preset PSK.

This experiment was reverted — all-zeros TLS PSK restored with improved
documentation.

---

## 10. PSK Write Probe: Re-provisioning on Firmware 12118

**Hypothesis:** Writing the 96-byte white-box blob via PSK Write (`0xe0`)
might still work on firmware 12118, and might reset both the device preset
PSK and the TLS session PSK.

**Background:** The `goodix-fp-dump` provisioning tool (`run_5110.py`)
writes this blob after firmware flashing. Reports suggest that PSK Write
was removed in firmware 12118 (which is why `goodix-fp-dump` requires a
preceding firmware downgrade).

**Implementation:** Added `ACTIVATE_WRITE_PSK` state to activation flow,
with the 96-byte white-box blob and flags `0xbb010003`. Made non-fatal
so activation continues even if write fails.

**Result:**
```
PSK write returned error: Command timed out: 0xe0 — continuing anyway
```

The PSK Write (`0xe0`) command **times out** on firmware 12118. The sensor
firmware silently ignores the command — no error response, no ACK, just
nothing. This confirms that firmware 12118 has removed support for PSK
Write.

**Activation continues** past the failed write (non-fatal), but TLS still
fails since the provisioning was not completed.

---

## 11. Dead End: Windows-Provisioned Sensors on Firmware 12118

The situation for firmware 12118 devices that were re-provisioned by Windows:

| Operation | Firmware 12118 |
|-----------|---------------|
| PSK Read (`0xe4`) | **Works** — returns Windows-written PSK hash |
| PSK Write (`0xe0`) | **Times out** — command removed |
| TLS with all-zeros key | **Fails** — Windows changed the TLS key |
| TLS with device PSK hash | **Fails** — device PSK ≠ TLS key |

**The only known path to recovery is firmware reflash** (downgrade to 12117
via `goodix-fp-dump`, which re-enables PSK Write and resets the TLS key).

### Potential future approaches

1. **Reverse-engineer Windows TLS PSK derivation** — the Windows kernel
   driver (`GoodixFingerPrint.sys`) establishes the TLS PSK during
   provisioning. If we could determine the derivation algorithm, we could
   compute the correct TLS key.

2. **Firmware 12118 downgrade via USB** — `goodix-fp-dump` already supports
   this flow (flash 12117, write PSK, flash back to 12118 if desired).

3. **Intercept Windows provisioning** — capture the TLS key during Windows
   boot/driver initialization (e.g., via kernel debugger or USB sniffer).

---

## 12. Summary of Changes Implemented

The following changes improve driver robustness and are worth keeping
regardless of the TLS key issue:

### Firmware version check (prefix match)
- **Before:** `strcmp(firmware, "GF_ST411SEC_APP_12117")` — exact match only
- **After:** Prefix match up to last underscore — accepts `12117`, `12118`,
  and any future firmware in the same family
- **Benefit:** Driver doesn't reject newer firmware; activation proceeds to
  the point where TLS would succeed (if the key matches)

### Dynamic PSK read (accept any)
- **Before:** 3-way validation (flags, length, memcmp against hardcoded hash)
- **After:** Accept any PSK with sane length (1–64 bytes), log value
- **Benefit:** Works with any provisioning state; no need to reflash just to
  pass the PSK identity check
- **Removed:** Hardcoded PSK array from `goodix511.h`, PSK class fields from
  `goodix5xx.h`, PSK assignments from `goodix511.c`

### TLS PSK documentation
- **Added:** Extensive comment in `goodixtls.c` explaining that the TLS
  session PSK (all-zeros) is completely independent of the device preset PSK
- **Renamed:** `goodix_psk` → `goodix_tls_psk` for clarity

### PSK Write probe (removed after testing)
- Tested empirically: PSK Write (`0xe0`) times out on firmware 12118
- Probe code removed after confirming the command is not supported
- White-box blob and write flags removed from `goodix511.h`

### What does NOT work yet
- Enrollment on sensors where Windows changed the TLS key
- Any sensor on firmware 12118 that was provisioned by the Windows driver
- These sensors require firmware reflash via `goodix-fp-dump` as a workaround
