# 16 — Firmware & PSK Compatibility: Making Flashing Redundant

**Date:** 2026-02-23 (updated 2026-02-24)  
**Status:** Closed — firmware/PSK checks relaxed; in-driver reprovisioning abandoned (see §11–§13)

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

### 5a. Windows Driver Reverse Engineering — PSK & TLS Internals

A detailed decompilation analysis of the Windows user-mode WBDI engine
adapter DLLs (`EngineAdapter.c` / `AlgoMilan.c`) reveals the following
PSK provisioning architecture. Note: the **kernel driver** (`GoodixFingerPrint.sys`)
actually sends USB commands to the sensor; the user-mode DLLs handle
the cipher/HMAC math and hand the results to the kernel via IOCTLs.

#### Registry Configuration Flags

These are read from `HKLM\Software\Goodix\FP\*` during `init_config()`:

| Flag | Global | File | Line | Purpose |
|------|--------|------|------|---------|
| `FirmwareUpdateSwitch` | `DAT_1800e42f4` (EA) / `DAT_1800ab994` (AM) | Both | EA:8182–8188 / AM:2562–2568 | Controls whether firmware flashing is enabled (1=yes) |
| `PSKSimulationSwitch` | `DAT_1800e42f5` (EA) / `DAT_1800ab995` (AM) | Both | EA:8193–8199 / AM:2573–2579 | When set, uses a fixed/debug PSK instead of generating random |
| `PSKCacheSwitch` | `DAT_1800e42f6` (EA) / `DAT_1800ab996` (AM) | Both | EA:8203–8209 / AM:2583–2589 | Controls whether PSK is cached to registry across sessions |

These flags are stored as single bytes and passed to the kernel driver
via IOCTL. They are **read-only** in the user-mode DLLs — the kernel
driver consumes them to decide the provisioning strategy.

#### `SecWhiteEncrypt` / `GoodixDataAesEncrypt` — The Whitebox Blob Generator

**Function:** `FUN_180003190` (EngineAdapter.c, lines 2177–2654)  
**Source path:** `f:\git\winfpsec\winfpsec\seclibs\sourceall\sourcecode\seccipher.c`  
**Called as:** `SecWhiteEncrypt` / `GoodixDataAesEncrypt`

This is the core cryptographic function that creates the 96-byte
"whitebox" PSK blob written to the device via command `0xe0`. It also
encrypts data dumps (the same function serves double duty for data-at-rest
encryption in dump files).

**Pseudocode:**
```
SecWhiteEncrypt(plaintext, plaintext_len, ciphertext_out, ciphertext_len_out):
    // 1. Set up AES-256-CBC cipher (mbedtls)
    cipher_info = lookup(AES-256-CBC)
    cipher_setup(ctx, cipher_info)
    
    // 2. Set up HMAC-SHA256 context for key derivation
    md_ctx = md_setup(SHA256)
    hmac_key_buf = calloc(2, 0x40)  // 128 bytes for derived keys
    
    // 3. DERIVE THE AES KEY via HMAC
    //    Reference table: DAT_1800d33a0 (the static whitebox table)
    
    // 3a. First HMAC: derive 16-byte IV
    iv_buf = zeroes(64)
    iv_buf[0..3] = serialize_le32(plaintext_len)  // 4 bytes of length
    hmac_reset(md_ctx)
    hmac_update(md_ctx, iv_buf, 4)
    hmac_update(md_ctx, "123GOODIX", 9)          // ← HARDCODED HMAC SALT
    hmac_finish(md_ctx, iv_buf)
    
    // 3b. Derive first 16 bytes → used as IV
    iv = iv_buf[0..15]
    // XOR last byte of first hash with low nibble of plaintext_len:
    iv[15] = (iv[15] ^ (byte)plaintext_len) & 0x0F ^ iv[15]
    // Copy first 16 bytes to output as header (PSK identity hash)
    ciphertext_out[0..15] = iv
    
    // 3c. Second HMAC: derive 32-byte AES key
    hmac_reset(md_ctx)
    hmac_update(md_ctx, iv_buf, 0x40)   // full 64-byte buffer
    hmac_update(md_ctx, prev_hash, 0x10) // the modified IV area
    hmac_finish(md_ctx, iv_buf)          // → 32-byte key in iv_buf[0..31]
    
    // 4. Set AES-256-CBC key from derived bytes
    cipher_setkey(ctx, iv_buf[0..31], 256, ENCRYPT)
    cipher_set_iv(ctx, derived_iv, 16)
    
    // 5. Encrypt plaintext with PKCS#7 padding
    cipher_update(ctx, plaintext, ciphertext_out+16)
    cipher_finish(ctx, remaining)
    
    // 6. Append MAC tag
    //    HMAC over ciphertext, appended as 32-byte trailer
    hmac_finish(md_ctx, mac_tag)
    ciphertext_out[16 + encrypted_len .. +32] = mac_tag
    
    // Total output: 16 (IV/hash) + encrypted_len + 32 (MAC) = 96 for 32-byte PSK
    *ciphertext_len_out = 16 + encrypted_len + 0x30
```

**Key insight:** The function name `SecWhiteEncrypt` is misleading — it's
not traditional whitebox crypto. It's HMAC-SHA256 key derivation using the
constant `"123GOODIX"` as a salt, followed by AES-256-CBC encryption. The
"whitebox table" at `DAT_1800d33a0` appears to be a static lookup table
used for the HMAC context initialization.

#### `SecAes256CbcPKCS7padDecrypt` — The Decryption Side

**Function:** `FUN_1800022eb` (EngineAdapter.c, lines ~2100–2170)  
**Source path:** `f:\git\winfpsec\winfpsec\seclibs\sourceall\sourcecode\seccipher.c`

Standard AES-256-CBC decryption with PKCS#7 unpadding. Used by the driver
to decrypt data it previously encrypted, and by the sensor firmware to
decrypt the whitebox blob received via `0xe0`.

#### GTLS Error Codes — The TLS Layer

**Function:** `FUN_180005e80` (EngineAdapter.c, lines 3140–3200+)  
Error code to string mapper for the Goodix TLS (GTLS) layer:

| Error Code | Hex | String |
|-----------|-----|--------|
| `0xff8fffff` | -0x700001 | `[GTLS] Wrong role (neither server or client)` |
| `0xff8ffffc` | -0x700004 | `[GTLS] Handshaking is not over, in progressing` |
| `0xff8ffffd` | -0x700003 | `[GTLS] HMAC Identity check error` |
| `0xff8ffffe` | -0x700002 | `[GTLS] Handshake state wrong` |
| `0xffbffbff` | -0x400401 | `[GTLS] Not error, Driver now is still in handshaking progress` |
| `0xffbffbfd` | -0x400403 | `Verify peer's identity or certification failed` |
| `0xffbffefa` | -0x400106 | `AES decryption HMAC check failed.` |
| `0xffbffefe` | -0x400102 | `AES decryption failed.` |
| `0xffbffeff` | -0x400101 | `AES encryption failed.` |

The `HMAC Identity check error` (-0x700003) occurs when the TLS PSK
identity (not the device preset PSK) doesn't match during TLS handshake.
This is the mbedTLS PSK-DHE handshake failing at the identity verification
step.

#### `_ForTestControlUnitGeneralControl` — Test/Provisioning Entry Points

**Function:** (EngineAdapter.c, lines 15640–16060)

A test harness function that dispatches provisioning operations via
DeviceIoControl to the kernel driver. Control codes include:

| Control Code (char) | Line | String | Purpose |
|---------------------|------|--------|---------|
| `0x27` (`'`) | 16004 | `"from driver for test original psk"` | Read/test the original (factory) PSK |
| `0x28` (`(`) | 16013 | `"from driver clear APP"` | Erase the firmware application |
| `0x29` (`)`) | 16021 | `"from driver update APP"` | Flash new firmware application |
| `0x20` (` `) | 15962 | `"from driver get data_dump settings"` | Read dump configuration |
| `0x21` (`!`) | 15979 | `"from driver get log info"` | Read log configuration |
| `0x22` (`"`) | 15988 | `"from driver get version info"` | Read version info |
| `0x26` (`&`) | 15996 | `"from driver get WBDI test info"` | WBDI HLK test data |

The `clear APP` (0x28) and `update APP` (0x29) operations correspond to
firmware erase and firmware flash respectively. They are dispatched via
`IOCTL_BIOMETRIC_FOR_GENERAL_CONTROL2` to the kernel driver.

#### `_ForTestControlUnitTLS` — TLS Test Operations

**Function:** (EngineAdapter.c, lines 17091–17400)

Handles TLS-related test operations: capture image over TLS channel,
verify templates, and communicate results back. Uses DeviceIoControl
with the same IOCTL pattern. This function captures fingerprint images
through the encrypted TLS channel and runs matching algorithms, all
within the WBDI test framework.

#### Data Dump Encryption with WhiteBox

The `dump_data` function (EngineAdapter.c, lines ~7180–7800) encrypts
fingerprint data dumps using `FUN_180003190` (SecWhiteEncrypt). This is
the same whitebox encryption function used for PSK blob generation. When
encryption fails, it logs `"[FAILED] WhiteBox encryption failed"`.

This confirms that `SecWhiteEncrypt` is a general-purpose encryption
function — used for both PSK blob creation and data-at-rest protection.

#### mbedTLS Integration

The EngineAdapter DLL bundles a complete mbedTLS implementation including:
- CTR-DRBG random number generator (line 4818+)
- HMAC-DRBG (line 4862+)
- Entropy source (line 4837+)
- AES cipher suite (lines 2200–2654)
- SSL/TLS error strings including PSK identity errors (line 4569)

The SSL error string `"SSL - Unknown identity received (eg, PSK identity)"`
at line 4569 confirms TLS-PSK is the handshake mode.

#### `EngineAdapterAttach` — The Attach/Init Flow

**Function:** (EngineAdapter.c, lines 11540–11660)

The WBDI engine adapter attach sequence:
1. Allocate engine context (0x390 bytes)
2. Call `FUN_180019770` → `_GetSensorInfo`: sends IOCTL `0x442008` to get
   sensor dimensions, chip ID, sensor type
3. Call `FUN_1800134c0`: load sensor type configuration
4. Call `FUN_180033080`: validate sensor type
5. Call `FUN_180017840` → `_InitAlgorithmEngine`: initialize the matching
   algorithm (called via function pointers in `_DAT_180100d68` table)

The TLS handshake and PSK provisioning happen in the **kernel driver**
during the IOCTL calls, not in this user-mode code. The user-mode DLL
only provides the crypto primitives and configuration flags.

### 5b. Complete PSK Provisioning Flow (Reconstructed)

Based on the decompiled code, the PSK provisioning flow works as follows:

```
┌─────────────────────────────────────────────────────────────┐
│                    WINDOWS BOOT / DRIVER INIT               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Kernel driver (GoodixFingerPrint.sys) loads             │
│                                                             │
│  2. User-mode DLL (EngineAdapter) calls init_config():      │
│     • Reads FirmwareUpdateSwitch from registry → flag byte  │
│     • Reads PSKSimulationSwitch from registry → flag byte   │
│     • Reads PSKCacheSwitch from registry → flag byte        │
│                                                             │
│  3. If FirmwareUpdateSwitch=1:                              │
│     a. Kernel driver sends "clear APP" (erase firmware)     │
│     b. Kernel driver sends "update APP" (flash new fw)      │
│     c. Device reboots with new firmware                     │
│                                                             │
│  4. PSK Provisioning (in kernel driver):                    │
│     a. If PSKSimulationSwitch=1:                            │
│        → Use fixed/debug PSK (for factory testing)          │
│     b. If PSKSimulationSwitch=0 (production):               │
│        → Generate random 32-byte PSK via CTR-DRBG           │
│                                                             │
│     c. Call SecWhiteEncrypt(random_psk, 32, blob, &len):    │
│        i.   HMAC-SHA256(len_le32 || "123GOODIX") → IV       │
│        ii.  XOR-tweak last IV byte with len low nibble       │
│        iii. First 16 bytes → Identity hash (PSK Read output) │
│        iv.  HMAC-SHA256(full_buf || IV) → 32-byte AES key   │
│        v.   AES-256-CBC encrypt PSK → ciphertext            │
│        vi.  HMAC-MAC over ciphertext → 32-byte tag          │
│        vii. Output: [16B hash | ciphertext | 32B MAC] = 96B │
│                                                             │
│     d. Send 96-byte blob via USB command 0xe0               │
│        (GOODIX_CMD_PRESET_PSK_WRITE)                        │
│                                                             │
│     e. If PSKCacheSwitch=1:                                 │
│        → Cache PSK to registry for session resume           │
│                                                             │
│  5. TLS Handshake:                                          │
│     a. Sensor firmware decrypts the whitebox blob            │
│        (it knows the "123GOODIX" HMAC key)                  │
│     b. Both sides now share the 32-byte random PSK          │
│     c. mbedTLS PSK-DHE handshake using that shared PSK      │
│     d. If identity mismatch → 0xff8ffffd HMAC Identity err  │
│     e. If handshake succeeds → encrypted channel ready      │
│                                                             │
│  6. Device returns PSK identity hash via command 0xe4:      │
│     The first 16 bytes of the whitebox output serve as      │
│     the identity token. PSK Read returns this hash so the   │
│     driver can verify the provisioning state.               │
│                                                             │
│  7. Encrypted image capture proceeds over TLS channel       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 5c. Relationship Between PSK Generation, WhiteBox, and TLS

| Component | What it is | Who generates it | Where stored |
|-----------|-----------|------------------|-------------|
| **Raw PSK** | 32-byte random key | Kernel driver (CTR-DRBG) | Driver memory + optionally registry (PSKCacheSwitch) |
| **WhiteBox blob** | 96-byte encrypted container holding the PSK | `SecWhiteEncrypt()` in user-mode DLL | Sent to device via cmd `0xe0`, stored in sensor flash |
| **PSK Identity hash** | First 16 bytes of whitebox output | `SecWhiteEncrypt()` HMAC derivation step | Readable via cmd `0xe4`, used for handshake identity check |
| **TLS Session PSK** | The same 32-byte random key after sensor decrypts the blob | Sensor firmware extracts from blob | Used by both sides in mbedTLS PSK-DHE handshake |

**Critical insight:** The raw PSK and the TLS session PSK are the **same key**.
The whitebox blob is merely the encrypted transport envelope. Once the sensor
firmware decrypts it (using its built-in knowledge of the "123GOODIX" HMAC
derivation), both sides have the identical 32-byte key for TLS.

This means our Linux driver's all-zeros TLS PSK only works when the sensor
was provisioned with an all-zeros key (which is what `goodix-fp-dump` does).
After Windows re-provisions with a random key, the all-zeros key no longer
matches — hence the TLS handshake failure.

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

---

## 13. Final Conclusion — Why In-Driver Reprovisioning Was Abandoned

Three independent blockers make it impossible to reprovision PSK from
within the libfprint driver:

1. **PSK Write (`0xe0`) only works in IAP/bootloader mode.** Tested
   empirically: the command times out silently in APP mode on firmware
   12118. The Windows driver disassembly confirms it never attempts a
   write in APP mode — it switches to IAP first (§4 in doc 17).

2. **Entering IAP mode erases the firmware.** The Windows driver log
   says `"return 0x%x after clearup APP, Driver will restart soon"`
   after the IAP switch. The only known way back to APP mode is a full
   firmware reflash, which requires bundling a proprietary firmware
   binary — a legal and technical non-starter for a Linux driver.

3. **Upstream maintainers prohibit firmware flashing in the driver.**
   Benjamin Berg (libfprint maintainer): *"it is extremely unlikely that
   a firmware blob can be included in libfprint"*. Alexander Meiler
   (original 5110 author): *"Our specific 5110 sensor requires a full
   reflash of the firmware every time the PSK is written."* Firmware
   operations must remain in a separate tool (`goodix-fp-dump`).

### What the driver keeps

- **Firmware prefix match** — accepts `12117`, `12118`, and future versions
- **Dynamic PSK Read** — accepts any device PSK hash, no hardcoded value
- **All-zeros TLS PSK** — works when sensor has matching provisioning

### User-facing impact

| Scenario | Works? | Action needed |
|----------|--------|---------------|
| Fresh sensor (never provisioned by Windows) | ✅ Yes | None |
| Sensor provisioned by `goodix-fp-dump` | ✅ Yes | None |
| Sensor re-provisioned by Windows driver | ❌ No | Run `goodix-fp-dump` once to reset PSK |
| Sensor on firmware 12118 (never Windows-provisioned) | ✅ Yes | None |
