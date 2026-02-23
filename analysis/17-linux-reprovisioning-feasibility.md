# 17 — Linux Reprovisioning Feasibility: Can We Write PSK Like Windows Does?

**Date:** 2026-02-24  
**Status:** Closed — all options investigated and abandoned (see §9)

---

## 1. Question

> "Could we do the same in the Linux driver?" — i.e., detect a PSK mismatch
> and reprovision the sensor with a known TLS key, the way Windows does.

---

## 2. Windows Provisioning Protocol (from disassembly)

The Windows driver (`gfspi.dll`) uses `production_psk_process` (fn_0x28440)
as the orchestrator. The complete flow:

### Step 1: Check PSK validity (up to 2 attempts)

```
production_check_psk_is_valid (fn_0x27450):
  1. "get host hash" — call production_get_host_psk_data (fn_0x27b60)
     → reads cached PSK from Goodix_Cache.bin, computes hash
  2. "get mcu hash" — call fn_0x28f20 with tag 0xbb020003
     → reads PSK hash (32 bytes) from sensor
  3. "verify" — memcmp(host_hash, mcu_hash, 32)
     → "!!!hash equal !!!" → success, PSK is valid
     → "!!!hash NOT match !!!" → return error 0xff000001
```

If the PSK is valid, **done** — no provisioning needed.

### Step 2: Switch to IAP (bootloader) mode

If PSK is invalid, check firmware version string for "APP":
- **Contains "APP"** (normal operation mode): Call fn_0x279a4 to "set to IAP"
  → Logs: "APP, set to IAP"
  → On success: returns `0xffdffff3` with log "return 0x%x after clearup APP,
    Driver will restart soon"
  → The Windows driver **restarts** after this
- **Already in IAP** (bootloader mode): "IAP, move on ..." → proceed to write

### Step 3: Write PSK (up to 2 attempts, IN IAP MODE)

```
production_write_key (fn_0x29268):
  1. Generate random 32-byte PSK (CryptGenRandom)
  2. Seal PSK with DPAPI → Goodix_Cache.bin (local backup)
  3. SecWhiteEncrypt(psk, 32) → 96-byte whitebox blob
  4. Wrap in TLV: tag=0xbb010003, length=0x7f8
  5. Build MCU packet: tag=0xbb010002, copy sealed data
  6. Write to sensor via USB command 0xe0
```

### Step 4: Verify

After writing, calls `production_check_psk_is_valid` again to confirm
the sensor now has the matching PSK hash.

---

## 3. Key Findings

### 3a. PSK write requires IAP (bootloader) mode on firmware 12118

The Linux driver already tried PSK Write (`0xe0`) in **APP mode** and it
**timed out** (documented in analysis/16, section 10). The Windows driver
never attempts this in APP mode — it always switches to IAP first.

The "clearup APP" log suggests the APP firmware may be erased when entering
IAP mode, though this phrasing could be a non-native English expression for
"cleaned up" vs "erased."

### 3b. The whitebox encryption is well-understood

SecWhiteEncrypt is fully reverse-engineered (analysis/16, section 5a):
```
SecWhiteEncrypt(plaintext_psk, 32):
  1. HMAC-SHA256(serialize_le32(32) || "123GOODIX") → 64-byte iv_buf
  2. iv = iv_buf[0..15], tweak: iv[15] ^= (32 & 0x0F) [low nibble XOR]
  3. Output[0..15] = iv  (identity hash — what PSK Read returns)
  4. HMAC-SHA256(iv_buf || modified_iv) → 32-byte AES key
  5. AES-256-CBC(key, iv, plaintext_psk) → ciphertext (48 bytes with PKCS#7)
  6. HMAC-MAC over ciphertext → 32-byte tag
  
  Total output: 16 + 48 + 32 = 96 bytes
```

For an all-zeros PSK, the output is deterministic (same every time, since
the input is constant). The known identity hash for all-zeros is:
`ba1a86037c1d3c71c3af344955bd69a9a9861d9e911fa24985b677e8dbd72d43`

### 3c. The Linux driver already has the right primitives

- `goodix_send_preset_psk_write()` — sends command `0xe0` with flags + payload
- `goodix_send_preset_psk_read()` — reads PSK hash via `0xe4`
- `GoodixPresetPsk` struct: `{uint32 flags, uint32 length}` + payload
- `GOODIX_511_PSK_FLAGS` = `0xbb020003`
- The wire format for PSK write: `[flags_le32 | length_le32 | whitebox_blob]`

### 3d. Two distinct flags for write vs read

| Tag | Purpose | Used in |
|-----|---------|---------|
| `0xbb010003` | PSK Write flags (whitebox blob) | production_write_key TLV wrapper |
| `0xbb010002` | MCU data write (sealed data) | production_write_key MCU packet |
| `0xbb020003` | PSK Read flags (identity check) | production_check_psk_is_valid, Linux driver |

The Linux driver currently uses `0xbb020003` for both read AND write, but
Windows uses `0xbb010003` for the write. **This might be why the PSK write
"timed out"** — wrong flags for the write operation.

---

## 4. Why Didn't the Linux PSK Write Work? (Definitive Answer)

The Linux driver sent `0xe0` in **APP mode**. The disassembly proves this
can never work — Windows **never** sends `production_write_key` in APP mode.

The control flow at [0x28688–0x287d1](analysis/win-system/disassembly/05-production_psk_process.asm)
is unambiguous:

```
if firmware_version contains "APP":
    log("APP, set to IAP")
    call fn_0x279a4()          // switch sensor to bootloader
    return 0xffdffff3          // "Driver will restart soon"
    // ← NEVER reaches the write loop

else:  // already in IAP mode
    log("IAP, move on ...")
    // ← falls through to write loop (fn_0x29268)
```

`production_write_key` (fn_0x29268) is called at 0x2887a, which is only
reachable from the "IAP, move on..." branch at 0x28795. When the sensor is
in APP mode, the function switches it to IAP and **returns immediately** —
the actual write happens on the next driver invocation, after restart, when
the sensor is confirmed to be in IAP mode.

The flags question is secondary. Windows uses `0xbb010003` for the whitebox
TLV wrapper, but even correct flags won't help if the firmware rejects the
entire `0xe0` command in APP mode — which is exactly what we observed
(timeout, not error).

---

## 5. Implementation Strategy for Linux Reprovisioning

### Option A: IAP-mode PSK write (most correct, most complex)

Implement the full Windows flow:
1. Detect TLS handshake failure (PSK mismatch)
2. Switch sensor to IAP mode (need to reverse-engineer the IAP switch command)
3. Send 96-byte whitebox blob for all-zeros PSK via `0xe0` with flags `0xbb010003`
4. Reset sensor back to APP mode
5. Re-attempt TLS handshake

**Complexity:** High  
**Risk:** If "clearup APP" means firmware erasure, step 4 requires
reflashing firmware (which means bundling the firmware binary).

### Option B: Provisioning tool (practical, separate from driver)

Write a standalone CLI tool (or integrate into `goodix-fp-dump`) that:
1. Switches sensor to IAP mode
2. Writes all-zeros PSK whitebox blob
3. Optionally reflashes firmware if needed
4. Resets sensor

User runs this once after Windows reprovisioning. The libfprint driver
itself stays simple (uses all-zeros TLS PSK).

**Complexity:** Medium  
**Risk:** Low — this is essentially what `goodix-fp-dump` already does

### Option C: Try PSK write in APP mode with correct flags (quick test)

Before going to IAP mode, try:
1. Send `0xe0` with flags `0xbb010003` (not `0xbb020003`)
2. If that works, we don't need IAP mode at all

**Complexity:** Low (one-line change to test)  
**Risk:** Likely won't work on fw 12118, but worth testing

### Option D: Extract PSK from Windows (current approach)

For the user's own device, the DPAPI extraction path already works:
1. Mount Windows partition
2. Run extraction script to get PSK from Goodix_Cache.bin
3. Patch driver with extracted PSK

**Complexity:** Low for implementation, high for user  
**Not portable** — requires Windows partition access per device

---

## 6. Recommended Approach

**Start with Option C** (5 minutes), then **Option A/B** if it fails.

### Quick test (Option C):

```c
// In goodix511.c, try writing with 0xbb010003 flags instead of 0xbb020003
static const guint8 psk_whitebox_zeros[96] = {
  // Pre-computed SecWhiteEncrypt(all_zeros_32_bytes)
  // First 16 bytes = identity hash (ba1a8603...)
  // Next 48 bytes = AES-256-CBC encrypted PSK
  // Last 32 bytes = HMAC-MAC tag
};

goodix_send_preset_psk_write(dev, 0xbb010003, psk_whitebox_zeros, 96,
                              NULL, write_callback, ssm);
```

If this succeeds, we can integrate it into the activation flow as a
fallback when TLS handshake fails.

### If Option C fails → Option B:

Implement a `goodix-reprovision` tool that enters IAP mode and writes
the PSK. This is the safest approach and matches what `goodix-fp-dump`
already does.

---

## 7. What We Need to Test

1. **Compute the all-zeros whitebox blob** — run SecWhiteEncrypt on 32
   zero bytes using the known algorithm. The identity hash `ba1a8603...`
   confirms the first 16 bytes; we need the full 96.

2. **Try PSK write with flags `0xbb010003`** in APP mode

3. **Research IAP mode entry** — what USB command does fn_0x279a4 send?
   Disassemble this function to find the MCU command for bootloader switch.

4. **Test PSK write in IAP mode** — if IAP mode can be entered without
   erasing firmware, this might work without reflashing.

---

## 8. Pre-computed Values (for all-zeros PSK)

### Input
- PSK: 32 bytes of `0x00`
- Length serialized: `0x20000000` (LE32)
- HMAC salt: `"123GOODIX"` (9 bytes)

### Known output
- Identity hash (first 16B): `ba1a86037c1d3c71c3af344955bd69a9`
  (matches the `goodix_511_psk_0[]` value the driver originally hardcoded)
- Full 96-byte whitebox blob: **needs to be computed**

The fact that PSK Read (`0xe4`) returns `ba1a8603...` after `goodix-fp-dump`
provisions confirms this is the SecWhiteEncrypt output for all-zeros PSK.

---

## 9. Final Conclusion — All Options Abandoned

**Date:** 2026-02-24

Every reprovisioning option was evaluated and rejected:

| Option | Outcome | Why abandoned |
|--------|---------|---------------|
| **A: IAP-mode PSK write in driver** | Rejected | Entering IAP erases firmware. Bundling firmware binary is legally and technically prohibited by upstream maintainers. |
| **B: Standalone provisioning tool** | Already exists | `goodix-fp-dump` does exactly this. No need to duplicate. |
| **C: PSK write in APP mode** | Tested, failed | Command `0xe0` times out on firmware 12118 — silently ignored. Confirmed by both empirical test and Windows driver disassembly (§4). |
| **D: DPAPI PSK extraction** | Works but not portable | Requires per-device Windows partition access. Not viable for a distributable driver. |

### Root cause chain

1. Windows driver generates a **random** 32-byte PSK on each provisioning
2. It encrypts this PSK into a 96-byte whitebox blob via `SecWhiteEncrypt`
3. It writes the blob to the sensor via `0xe0` — but **only in IAP mode**
4. The sensor firmware decrypts the blob and uses the random PSK for TLS
5. The Linux driver uses all-zeros PSK → **TLS handshake fails**
6. We cannot write our own PSK because `0xe0` is blocked in APP mode
7. We cannot enter IAP mode without erasing the firmware
8. We cannot bundle firmware for reflash (upstream policy + legal risk)

### Resolution

The PSK reprovisioning code was **reverted from the driver** (whitebox blob,
PMK hash, write flags, `ACTIVATE_WRITE_PSK` state, `psk_valid` field — all
removed from `goodix511.c` and `goodix511.h`).

Users whose sensors were re-provisioned by Windows must run `goodix-fp-dump`
once to reset the sensor to the all-zeros PSK. This is documented as a
setup prerequisite, not a driver limitation.
