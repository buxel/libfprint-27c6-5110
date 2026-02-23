#!/usr/bin/env python3
"""
SecWhiteEncrypt / GoodixDataAesEncrypt — Python implementation

Reconstructed from gfspi.dll disassembly (fn_0x15b0, RVA 0x15b0–0x1c31)
and Ghidra decompilation of EngineAdapter.c (FUN_180003190, lines 2177–2654).

Source: f:\git\winfpsec\winfpsec\seclibs\sourceall\sourcecode\seccipher.c

Algorithm:
  1. Serialize plaintext length as LE32, zero-pad to 64 bytes → iv_buf
  2. HMAC-SHA256(key="123GOODIX", msg=iv_buf[:4]) → overwrite iv_buf with 32-byte hash
     (but iv_buf is 64 bytes; only first 32 are the hash, rest zero)
  3. Extract IV = iv_buf[0:16], copy to iv_save
  4. Tweak: iv_save[15] = (iv_save[15] ^ (plaintext_len & 0xFF)) & 0x0F ^ iv_save[15]
  5. Output[0:16] = iv_save  (this is the "identity hash" / PSK Read value)
  6. Second HMAC: hmac_reset, update(iv_buf[:64]), update(iv_save[:16]), finish → 32-byte AES key
  7. AES-256-CBC encrypt(key=aes_key, iv=iv_save, plaintext) with PKCS#7 padding
  8. HMAC-MAC: hmac over ciphertext (using same HMAC context) → 32-byte tag
     Actually: the HMAC processes the ciphertext blocks as they're produced,
     then finishes to produce a 32-byte MAC appended to output
  9. Output = [16B identity_hash | ciphertext_with_padding | 32B hmac_mac]
     For 32-byte plaintext: 16 + 48 + 32 = 96 bytes (final length stored as len+0x30=0x60)

Wait — re-reading the disassembly more carefully:

The length serialization at 0x17d0–0x180f is a loop that serializes `esi` (param_2 = plaintext_len)
into bytes at [rbp-0x20..rbp-0x1] (4 bytes), using shifts by 0,8,16,24 bits.
This is just a LE32 write of the length into a 64-byte zeroed buffer.

HMAC flow:
  - hmac_starts (0x364a0) — reset HMAC with key from DAT_1800d33a0 table
  - hmac_update (0x364f0, r8=4) — feed the 4-byte LE32 length
  - hmac_update (0x364f0, r8=9) — feed "123GOODIX" (9 bytes)
  - hmac_finish (0x35c10) → writes 32 bytes to iv_buf[0:32]

Wait, reading more carefully: the HMAC key is set up via pauVar6 = FUN_180007790()
which initializes a SHA-256 HMAC context with key from DAT_1800d33a0.

Actually no — FUN_180007790 returns an md_info_t for SHA-256. The "key" for
HMAC is set by the hmac_starts call. Let me re-examine...

The mbedtls flow in the decompiled code:
  - FUN_180007790() = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256) → returns md_info
  - FUN_180007760(ctx, data, len) = mbedtls_md_hmac_update
  - FUN_180007850(ctx) = mbedtls_md_hmac_reset (resets to use same key)
  - thunk_FUN_1800095c0(ctx, output) = mbedtls_md_hmac_finish
  - FUN_180005980(key_ptr, data, len) = mbedtls_md_hmac_starts (sets HMAC key)

But wait — the decompiled code shows:
  local_548 = (undefined (*) [16])&DAT_1800d33a0;
  ...
  FUN_180007850(pauVar6);           // hmac_reset
  FUN_180007760(pauVar6, &local_4c8, 4);    // hmac_update(len_le32, 4)
  FUN_180007760(pauVar6, "123GOODIX", 9);   // hmac_update("123GOODIX", 9)
  thunk_FUN_1800095c0(pauVar6, &local_4c8); // hmac_finish → hash

And before this, mbedtls_md_setup was called and the HMAC key was never
explicitly set via hmac_starts — so the reset implies a previous starts.

Actually, looking at the disassembly at 0x1757:
  call 0x36370 (mbedtls_md_get_size)  → gets hash size (32 for SHA-256)
Then at 0x1771:
  call 0x363c8 (mbedtls_md_hmac_starts) with rdx=pauVar6 (the md_info output),
  r8=r14 (the size from get_size=32? No wait, r14 is from [rsp+0x40] which was set to 1)

Hmm wait, let me look again at the asm:
  0x175c: mov r14d, dword ptr [rsp + 0x40]  → this was set to 1 at 0x16be
  0x1766: mov r8d, r14d      → r8 = 1
  0x1769: mov [rsp+0x58], rax  → save result of md_get_size
  0x176e: mov rdx, rax       → rdx = md_get_size result (a pointer to md_info)

Wait, that's FUN_180007790 = mbedtls_md_info_from_type(6) where 6=SHA256.
Then:
  0x1757: call 0x36370 → this returns the md_info_t pointer
  0x175c: r14d = [rsp+0x40] = 1 (the "local_5b0 = 1" padding mode flag)
  
Actually I'm overcomplicating this. Let me look at the decompiled more directly.

In the decompiled code:
```
local_548 = (undefined (*) [16])&DAT_1800d33a0;
```
And later:
```
FUN_180005980((longlong *)&local_548,(undefined (*) [16])&local_4c8,0x20);
```
This is mbedtls_md_hmac_starts(ctx, key=aes_derived_key, keylen=0x20).
But this happens AFTER the first HMAC pass, just before cipher_setkey.

OK let me just look at the decompiled Ghidra output line by line for the 
cryptographic operations in order:

1. Set up context, get cipher AES-128-CBC (wait, it says AES_128_CBC at 0x16d3!)
   "Cipher MBEDTLS_CIPHER_AES_128_CBC not found"
   
   But the analysis/16 doc says AES-256-CBC. Let me check...
   The string at 0x16d3 says "Cipher MBEDTLS_CIPHER_AES_128_CBC not found"
   but looking at the cipher_info lookup:
     0x16b9: mov ecx, 5  → MBEDTLS_CIPHER_AES_128_CBC = 5 in mbedtls
   
   Wait, but the key is set as 32 bytes... Let me check mbedtls cipher IDs:
   MBEDTLS_CIPHER_AES_128_CBC = 5
   MBEDTLS_CIPHER_AES_256_CBC = 11
   
   Hmm, the code says cipher type 5 = AES-128-CBC. So it IS AES-128-CBC,
   not AES-256-CBC! The analysis/16 doc was wrong about AES-256.
   
   But wait — the cipher setup may handle key size separately from the cipher
   type lookup. In mbedtls, MBEDTLS_CIPHER_AES_128_CBC uses
   mbedtls_cipher_setkey with the key bits parameter.

   At 0x18f9-0x1908:
     mov r8d, [rdi + 8]    → cipher key_bitlen from cipher_info
     lea rdx, [rbp-0x20]   → key data (32 bytes of derived key)  
     mov r9d, r14d          → operation (r14=1 = MBEDTLS_ENCRYPT)
     call 0x307e4           → mbedtls_cipher_setkey(ctx, key, bitlen, ENCRYPT)
   
   The key_bitlen comes from the cipher_info structure, which for
   MBEDTLS_CIPHER_AES_128_CBC would be 128. But the derived key is 32 bytes...
   
   Actually, in mbedtls, MBEDTLS_CIPHER_AES_128_CBC's key_bitlen is 128,
   so cipher_setkey would only use the first 16 bytes of the 32-byte buffer.
   
   So it's AES-128-CBC with a 16-byte key derived from the second HMAC!
   The disassembly label at the top of the file also says "AES-128-CBC".

OK so: the algorithm uses AES-128-CBC, not AES-256-CBC. The analysis/16 doc
was incorrect about this. Let me correct understanding:

Algorithm (corrected):
  1. LE32(plaintext_len) → buf[0:4], rest of 64-byte buf is zero
  2. HMAC-SHA256(key=???, msg=buf[0:4] || "123GOODIX") → 32-byte hash → buf[0:32]
  3. iv_out = buf[0:16], tweak iv_out[15]
  4. output[0:16] = iv_out (identity hash)
  5. HMAC-SHA256(key=???, msg=buf[0:64] || iv_out[0:16]) → 32-byte derived → buf[0:32]
  6. aes_key = buf[0:16] (first 16 bytes, since AES-128)
  7. AES-128-CBC(key=aes_key, iv=iv_out, plaintext) → ciphertext (with PKCS7)
  8. HMAC-MAC over ciphertext → 32-byte tag appended

But what's the HMAC key? Looking at the setup flow:

The decompiled code has:
```
  pauVar6 = FUN_180007790();  // mbedtls_md_info_from_type(SHA256)
  ...
  local_548 = (undefined (*) [16])&DAT_1800d33a0;  // whitebox lookup table
```

And later:
```
  FUN_180007850(pauVar6);  // hmac_reset — implies hmac_starts was already called
```

For hmac_reset to work, hmac_starts must have been called. Looking at the
setup code around the mbedtls_md_setup call:

```
  pauVar6 = FUN_180007790();   // md_info_from_type(SHA256)
  local_540 = pauVar6;
  local_5b8 = _calloc_base(2, 0x40);  // allocate 128 bytes for HMAC key storage
  local_538 = local_5b8;
  local_548 = &DAT_1800d33a0;   // the whitebox table pointer
```

Then looking further into the md setup:
```
  pauVar6 = FUN_180007790();  // md_info_from_type(6) = SHA256 info
```

The HMAC context (pauVar6 from the md functions) needs a key to be set via
hmac_starts. But I don't see an explicit hmac_starts call before the first
hmac_reset...

Wait — looking at the assembly more carefully at 0x1766-0x177a:
```
  0x175c: mov r14d, [rsp+0x40]   → r14 = 1 (padding mode)
  0x1761: lea rcx, [rsp+0x68]    → rcx = md context
  0x1766: mov r8d, r14d          → r8 = 1 (this is keylen for hmac_starts? No...)
  0x1769: mov [rsp+0x58], rax    → save md_info pointer
  0x176e: mov rdx, rax           → rdx = md_info (but this should be the key for hmac_starts)
  0x1771: call 0x363c8           → mbedtls_md_hmac_starts(ctx, md_info_ptr, 1)
```

Hmm, that doesn't make sense. Let me reconsider. Looking at the actual
mbedtls_md_hmac_starts signature:
  int mbedtls_md_hmac_starts(mbedtls_md_context_t *ctx, const unsigned char *key, size_t keylen)

So rdx = key pointer, r8 = keylen.

At 0x1766-0x1771:
  r8d = r14d = [rsp+0x40] = 1  → keylen = 1?? That's weird
  rdx = rax = return value of FUN_180007790 (or 0x36370?)

Wait, I need to re-read the asm. Let me look at the sequence:
  0x1752: mov ecx, 6              → arg for mbedtls_md_info_from_type
  0x1757: call 0x36370            → FUN_36370 = mbedtls_md_info_from_type
             Actually wait, 0x36370 might be mbedtls_md_get_size.
             And 0x363c8 might be mbedtls_md_hmac_starts.
             But what's at 0x363a8 (called at 0x16b4)?
             
Let me look at the sequence properly:

  0x16a6: lea rcx, [rbp-0x80]     → cipher context
  0x16aa: call 0x30638             → mbedtls_cipher_init(ctx)
  0x16af: lea rcx, [rsp+0x68]     → md HMAC context  
  0x16b4: call 0x363a8             → mbedtls_md_init(ctx)
  0x16b9: mov ecx, 5              → MBEDTLS_CIPHER_AES_128_CBC
  0x16be: mov [rsp+0x40], 1       → save padding/encrypt mode flag
  0x16c6: call 0x3056c             → mbedtls_cipher_info_from_type(5)
  ...
  0x1752: mov ecx, 6              → MBEDTLS_MD_SHA256 = 6
  0x1757: call 0x36370             → mbedtls_md_info_from_type(6)
  0x175c: mov r14d, [rsp+0x40]    → r14 = 1
  0x1761: lea rcx, [rsp+0x68]     → md context
  0x1766: mov r8d, r14d           → r8 = 1 (hmac flag, not key length!)
                                     mbedtls_md_setup(ctx, md_info, hmac=1)
  0x176e: mov rdx, rax            → rdx = md_info
  0x1771: call 0x363c8             → mbedtls_md_setup(ctx, md_info, hmac=1)

YES! 0x363c8 is mbedtls_md_setup, not hmac_starts! The third parameter 
r8=1 is the hmac flag (1 = allocate HMAC internals).

So now the key question: where is mbedtls_md_hmac_starts called to set the
HMAC key? Let me trace further...

After md_setup succeeds (0x1791), we see:
  0x1791: xor eax, eax              → zero
  0x1793: lea rdx, [rbp-0x1f]       → just past the first byte of the buffer
  0x1797: mov [rbp-0x20], rax       → zero the 64-byte buffer
  ... (zeroing continues)
  0x17d0–0x180f: LE32 serialization loop (writes plaintext_len to buffer)
  
  0x1811: lea rcx, [rsp+0x68]       → md context
  0x1816: call 0x364a0             → what is this?

Let me compare to the decompiled code:
```
  FUN_180007850(pauVar6);           // this is called with pauVar6 being local_540
```

But local_540 = FUN_180007790() which returns a pointer to md_info_from_type.
And pauVar6 is used as the HMAC context... 

Actually, I think there's some confusion. Let me look at the actual call sequence.

In the asm, the HMAC context is at [rsp+0x68]. The calls use rcx=[rsp+0x68]:
  0x1811: lea rcx, [rsp+0x68]
  0x1816: call 0x364a0          → this is likely mbedtls_md_hmac_reset or hmac_starts

But hmac_starts needs a key and keylen. Let me check what parameters are set:
  Only rcx is set before the call. No rdx, r8 setup. So it's a single-arg function.
  That means it's mbedtls_md_hmac_reset(ctx).

But you can't call hmac_reset before hmac_starts! hmac_starts must be called
first to set the key.

Unless... hmac_starts was called as part of md_setup? No, mbedtls doesn't work
that way.

Let me reconsider. Maybe FUN_180007850 and 0x364a0 are different functions.
Let me map the RVAs properly:

In the DLL's decompiled code, function addresses are 0x180000000 + RVA.
The asm uses raw RVAs. So:
  asm 0x364a0 → decompiled FUN_1800364a0 → what's this?
  asm 0x364f0 → decompiled FUN_1800364f0
  asm 0x35c10 → decompiled FUN_180035c10
  asm 0x363c8 → decompiled FUN_1800363c8

In the decompiled EngineAdapter.c code, the functions called are:
  FUN_180007790 → in asm: 0x7790 (but we see 0x36370 called at 0x1757)
  FUN_180007760 → hmac_update
  FUN_180007850 → hmac_reset
  FUN_1800095c0 → hmac_finish

But wait — these 0x77xx addresses are WRAPPERS in the EngineAdapter.dll,
while the 0x36xxx addresses are in gfspi.dll (different DLL!).

The 8 disassembled functions are from gfspi.dll, not EngineAdapter.dll. 
These are different DLLs with different function addresses.

In gfspi.dll:
  0x364a0 = probably mbedtls_md_hmac_reset (single arg)
  0x364f0 = probably mbedtls_md_hmac_update (3 args: ctx, data, len)
  0x35c10 = probably mbedtls_md_hmac_finish (2 args: ctx, output)
  0x363c8 = mbedtls_md_setup (3 args: ctx, md_info, hmac_flag)
  0x36370 = mbedtls_md_info_from_type (1 arg)
  0x36300 = probably some hmac util
  0x35d40 = probably hmac related

Now, for hmac_reset to work, the HMAC key must have been initialized.
Looking at the flow again:

After md_setup on the md context at [rsp+0x68]:
  0x1791–0x17be: zero the 64-byte buffer at [rbp-0x20]
  0x17d0–0x180f: serialize LE32(plaintext_len) into buffer[0:4]
  0x1811: call 0x364a0 (hmac_reset on [rsp+0x68])  ← BUT NO KEY SET YET!

Hmm, this is the puzzle. Let me think...

Oh wait — maybe the first call to 0x364a0 is not hmac_reset at all.
What if it's mbedtls_md_hmac_starts with the key embedded in the context?
Or maybe the HMAC was started using "123GOODIX" as the key via the md_setup?

Actually, let me reconsider. In mbedtls, after md_setup, to use HMAC you call:
  md_hmac_starts(ctx, key, keylen)  → sets the HMAC key
  md_hmac_update(ctx, input, ilen)  → processes data
  md_hmac_finish(ctx, output)       → produces HMAC
  md_hmac_reset(ctx)                → resets for reuse with same key

If 0x364a0 only takes 1 argument, it could be md_hmac_reset OR it could be 
a wrapper that calls md_hmac_starts with a hardcoded key.

AH WAIT — looking at FUN_180007850 in the decompiled EngineAdapter.c:
```
FUN_180007850((undefined8 *)pauVar6);
```
This is called with 1 argument, just like 0x364a0. And it's called BEFORE
any hmac_update. If it's hmac_reset, the key must be already set. But if it's
a WRAPPER that calls hmac_starts with a hardcoded key...

Actually, I realize there's another possibility. The md_setup at 0x363c8 might
be a customized version that also sets the key. Or there may be initialization
hidden in the DAT_1800d33a0 reference.

Let me look at this differently. The decompiled code shows:
```
local_548 = (undefined (*) [16])&DAT_1800d33a0;
```

And later when HMAC operations happen, local_548 is used as a vtable-like
structure. In the ciphertext MAC computation:
```
if ((pauVar20 != NULL) && (local_5b8 != NULL)) {
  (**(code **)pauVar20[2])(pauVar6, local_458, uVar21);
}
```

And after the cipher finishes:
```
if ((pauVar20 != NULL) && (puVar12 != NULL)) {
  iVar2 = *(int *)(pauVar20[1] + 4);
  (**(code **)(pauVar20[2] + 8))(pauVar6,local_478);
  (**(code **)(pauVar20[1] + 8))(pauVar6);
  (**(code **)pauVar20[2])(pauVar6,puVar12 + iVar2,...);
  (**(code **)pauVar20[2])(pauVar6,local_478,...);
  (**(code **)(pauVar20[2] + 8))(pauVar6,&local_4c8);
}
```

These are vtable calls through pauVar20 = local_548 = &DAT_1800d33a0.
DAT_1800d33a0 is NOT just a data table — it's a function pointer table!

So the "whitebox table" at 0xd33a0 contains function pointers that implement
the HMAC operations. This is likely a custom HMAC implementation using a
hardcoded key, hence "whitebox" — the key is embedded in the lookup table.

But for our purposes, the analysis/16 doc says the algorithm is:
- HMAC-SHA256 with message = LE32(len) || "123GOODIX"
And the resulting hash's first 16 bytes for an all-zeros 32-byte PSK should be
ba1a86037c1d3c71c3af344955bd69a9.

Let me just... verify this with Python. The simplest interpretation:

hmac_key is either from DAT_1800d33a0 or it could be that "123GOODIX" IS the key.

Actually, re-reading the asm:
```
  0x1816: call 0x364a0           → hmac_starts/reset (1 arg: ctx only → reset)
  0x181b: mov r8d, 4             → length
  0x1821: lea rdx, [rbp-0x20]   → LE32(plaintext_len) buffer  
  0x1825: lea rcx, [rsp+0x68]   → md context
  0x182a: call 0x364f0           → hmac_update(ctx, le32_buf, 4)
  0x182f: mov r8d, 9             → length
  0x1835: lea rdx, [rip+0x5311dc] → "123GOODIX"
  0x183c: lea rcx, [rsp+0x68]   → md context
  0x1841: call 0x364f0           → hmac_update(ctx, "123GOODIX", 9)
  0x1846: lea rdx, [rbp-0x20]   → output buffer
  0x184a: lea rcx, [rsp+0x68]   → md context
  0x184f: call 0x35c10           → hmac_finish(ctx, output)
```

So the HMAC computes: HMAC(key=???, LE32(32) || "123GOODIX").

The key must have been set earlier. Looking at the md_setup path:
  0x16af: lea rcx, [rsp+0x68]  → md context
  0x16b4: call 0x363a8          → mbedtls_md_init(ctx)

Then after cipher setup:
  0x1752: mov ecx, 6           → SHA256
  0x1757: call 0x36370          → md_info = md_info_from_type(SHA256)
  0x175c: r14d = 1
  0x1761: lea rcx, [rsp+0x68]  → md context
  0x1766: r8d = 1 (hmac=1)
  0x176e: rdx = md_info
  0x1771: call 0x363c8          → md_setup(ctx, md_info, 1)

After checking return:
  0x1791: ← continue here on success

Then zeroing buffer, LE32 serialization, and the HMAC calls.

There is NO hmac_starts call between md_setup and the first hmac_update!
The only function with 1 arg is 0x364a0 at line 0x1816.

If 0x364a0 is hmac_reset (which resets to use the same key from a prior starts),
then there was no prior starts and the key would be uninitialized (zeros? or garbage from the context).

OR: 0x364a0 is a WRAPPER function that calls hmac_starts with a hardcoded key.
In a "whitebox" crypto implementation, this makes sense — the key is embedded.

But what key? Looking at the only reference to DAT_1800d33a0:
In the decompiled code, it's assigned to local_548, which is then used as a
vtable/function-pointer-array for the MAC computations on the ciphertext.
It doesn't seem to be used as the HMAC key directly.

Let me try the simplest hypothesis first: maybe there's NO key (empty key / 
zero-length key). In mbedtls, if hmac_starts is called with keylen=0, the 
HMAC key is effectively empty. And if 0x364a0 is hmac_reset after an implicit
hmac_starts(ctx, NULL, 0)... or maybe md_setup with hmac=1 initializes with a 
zero-length key.

Actually, let me just TRY computing it both ways and see which produces the
known identity hash ba1a86037c1d3c71c3af344955bd69a9:

1. HMAC-SHA256(key=b"", msg=b"\x20\x00\x00\x00" + b"123GOODIX")
2. HMAC-SHA256(key=b"123GOODIX", msg=b"\x20\x00\x00\x00")
3. SHA256(b"\x20\x00\x00\x00" + b"123GOODIX") — plain hash, not HMAC

Then check first 16 bytes (after the IV tweak).

Actually wait — there's a complication. The tweak:
  iv[15] = (iv[15] ^ plaintext_len_byte) & 0x0F ^ iv[15]

For plaintext_len=32 (0x20), plaintext_len_byte = 0x20.
  iv[15] = (iv[15] ^ 0x20) & 0x0F ^ iv[15]

Since 0x20 & 0x0F = 0:
  = (iv[15] ^ 0x20) & 0x0F ^ iv[15]
  
Let's call original iv[15] = x:
  = ((x ^ 0x20) & 0x0F) ^ x
  = (x & 0x0F) ^ x       (since 0x20 only affects bit 5, ANDing with 0x0F removes it)
  = x & 0xF0              (XOR of low nibble cancels, high nibble remains)

Wait: (x ^ 0x20) & 0x0F = x & 0x0F (because 0x20 bit is above 0x0F mask)
Then: (x & 0x0F) ^ x = (x & 0xF0)

Hmm, that zeros out the low nibble. So iv[15] = iv[15] & 0xF0 when plaintext_len=0x20.

Let me just code it up and try all three HMAC key hypotheses.
"""

import hashlib
import hmac
import struct
from Crypto.Cipher import AES

def sec_white_encrypt(plaintext: bytes, hmac_key: bytes = b"") -> bytes:
    """
    SecWhiteEncrypt implementation.
    
    Args:
        plaintext: Data to encrypt (e.g., 32-byte PSK)
        hmac_key: Key for HMAC-SHA256. Default empty (zero-length key).
    
    Returns:
        Encrypted blob: [16B identity_hash | ciphertext | 32B mac]
    """
    plaintext_len = len(plaintext)
    
    # Step 1: Create 4-byte LE32 of plaintext length
    le32_len = struct.pack('<I', plaintext_len)
    
    # Step 2: First HMAC - derive IV
    # HMAC-SHA256(key, LE32(len) || "123GOODIX")
    h1 = hmac.new(hmac_key, digestmod=hashlib.sha256)
    h1.update(le32_len)
    h1.update(b"123GOODIX")
    hash1 = h1.digest()  # 32 bytes
    
    # The hash goes into a 64-byte buffer (rest zeros)
    iv_buf = bytearray(hash1 + b'\x00' * 32)
    
    # Step 3: Extract IV (first 16 bytes) and apply tweak
    iv = bytearray(iv_buf[0:16])
    
    # Tweak: iv[15] = (iv[15] ^ (byte)plaintext_len) & 0x0F ^ iv[15]
    original_byte = iv[15]
    iv[15] = ((original_byte ^ (plaintext_len & 0xFF)) & 0x0F) ^ original_byte
    
    # Step 4: Identity hash = tweaked IV (output[0:16])
    identity_hash = bytes(iv)
    
    # Also update the buffer with the tweaked IV for key derivation
    # The asm copies iv back to [rbp+0x30] then to [rbp-0x20] at 0x189e
    iv_buf[0:16] = iv
    
    # Wait — re-reading asm at 0x1854-0x189e:
    # 0x1854: movaps xmm0, [rbp-0x20]   → original hash first 16 bytes  
    # 0x185b: movups [rbp+0x30], xmm0   → copy to iv_save area
    # 0x185f: psrldq xmm0, 8            → shift right 8 bytes
    # 0x1864: movq rax, xmm0            → rax = bytes 8-15 of hash
    # 0x1869: movdqa [rbp], xmm1(=0)    → zero [rbp+0:16]
    # 0x186e: mov rcx, rax
    # 0x1874: shr rcx, 0x38             → get byte 15 (top byte of rax)
    # 0x1878: xor cl, sil               → cl ^= plaintext_len low byte
    # 0x187b: shr rax, 0x38             → same thing
    # 0x187f: and cl, 0x0f              → keep low nibble
    # 0x1882: movdqa [rbp-0x10], 0      → zero more buffer
    # 0x1887: xor cl, al                → cl ^= original byte 15
    # 0x1889: movdqa [rbp+0x10], 0      → zero
    # 0x188e: mov [rbp+0x3f], cl        → store tweaked byte at iv_save[15]
    # 
    # So iv_save at [rbp+0x30..0x3f] = hash[0:16] with byte 15 tweaked
    # [rbp-0x20..rbp+0x30] is zeroed for the new HMAC input
    # Wait no, [rbp] and [rbp-0x10] and [rbp+0x10] are zeroed.
    # [rbp+0x20..0x2f] was zeroed at 0x1791 (the hmac_key area I think)
    
    # 0x1891: lea rcx, [rsp+0x68]        → md context
    # 0x1896: movups xmm2, [rbp+0x30]    → load tweaked IV
    # 0x189a: movups [r15], xmm2          → write to output buffer (identity hash!)
    # 0x189e: movaps [rbp-0x20], xmm2     → copy tweaked IV to buf start
    #
    # So [rbp-0x20..0x10] is: tweaked_iv (16 bytes) at [-0x20..-0x10]
    #                         zeros everywhere else up through [rbp+0x18]
    # [rbp+0x20..0x2f] was zeroed earlier too
    # Total: [rbp-0x20] has the tweaked_iv[0:16] + 48 bytes of zeros = 64 bytes
    #
    # Then second HMAC:
    # 0x18a2: call 0x364a0               → hmac_reset
    # 0x18a7: mov r8d, 0x40              → 64 bytes
    # 0x18ad: lea rdx, [rbp-0x20]        → the 64-byte buffer (IV + zeros)
    # 0x18b1: lea rcx, [rsp+0x68]        → md context
    # 0x18b6: call 0x364f0               → hmac_update(ctx, buf, 64)
    # 0x18bb: mov r8d, 0x10              → 16 bytes
    # 0x18c1: lea rdx, [rbp+0x20]        → this area... what's here?
    
    # Hmm, [rbp+0x20..0x2f] was set at 0x18e8/0x18ec to zero.
    # But wait — that happens AFTER 0x18ca. Let me re-check the order.
    # 
    # Actually at 0x16a1:
    #   call 0x2c0d8  which zeroes [rbp+0x20..0x28] (the 16 bytes)
    # And [rbp+0x20] was set to 0 at 0x1699, +0x28 at 0x169d.
    # 
    # But wait, there's `local_488` in the decompiled code which maps to
    # [rbp+0x20..0x2f]. It was zeroed initially. The first HMAC finish
    # doesn't write there. So [rbp+0x20..0x2f] = all zeros.
    # 
    # Wait, I need to re-examine. The decompiled code says:
    # ```
    # FUN_180007760((uint *)pauVar6,(longlong)&local_488,0x10);
    # ```
    # local_488 is a separate variable that was zeroed. But what about
    # in the assembly? Let me look at the reference [rbp+0x20].
    
    # Actually, "local_488" in the Ghidra decompilation corresponds to
    # stack frame layout. The disassembly uses rbp-relative addressing.
    # Let me just look at what the decompiled code shows for the second HMAC:
    #
    # ```
    # FUN_180007850((undefined8 *)pauVar6);         // hmac_reset
    # FUN_180007760((uint *)pauVar6,(longlong)&local_4c8,0x40);  // update(buf64, 64)
    # FUN_180007760((uint *)pauVar6,(longlong)&local_488,0x10);  // update(zeros16, 16)
    # thunk_FUN_1800095c0((uint *)pauVar6,(undefined *)&local_4c8); // finish → buf
    # ```
    #
    # local_4c8 = the 64-byte buffer (hash + zeros)
    # local_488 = 16 bytes of zeros (never written to before this point)
    #
    # But wait — what about the identity hash? Looking at the decompiled code:
    # ```
    # local_560 = (undefined4)local_4c8;
    # uStack1372 = (undefined4)(local_4c8 >> 0x20);
    # uStack1368 = (undefined4)uStack1216;
    # uStack1364 = CONCAT13((uStack1216._7_1_ ^ (byte)param_2) & 0xf ^ uStack1216._7_1_,
    #                       (int3)(uStack1216 >> 0x20));
    # *(undefined4 *)param_3 = local_560;         → output[0:4]
    # *(undefined4 *)((longlong)param_3 + 4) = uStack1372;  → output[4:8]
    # ...
    # uStack1216 = uStack1216 & 0xffffffff | (ulonglong)uStack1364 << 0x20;
    # ```
    # 
    # And then:
    # ```
    # FUN_180007850(pauVar6);                        // hmac_reset
    # FUN_180007760(pauVar6, &local_4c8, 0x40);     // update(buf, 64)
    # FUN_180007760(pauVar6, &local_488, 0x10);     // update(zeros16?, 16)
    # thunk_FUN_1800095c0(pauVar6, &local_4c8);     // finish → buf
    # ```
    #
    # But local_488 was initialized: "local_488 = 0; local_480 = 0;"
    # These are 8+8 = 16 bytes of zeros.
    #
    # HOWEVER — the decompiled code then shows AFTER the tweaked IV is written:
    # ```
    # local_4b8 = 0;
    # uStack1200 = 0;
    # ```
    # And local_4c8 has been overwritten with the first HMAC hash output.
    #
    # After the tweak and output write:
    # ```
    # local_4a8 = 0;  # more zeroing
    # local_4a0 = 0;
    # local_498 = 0;
    # local_490 = 0;
    # ```
    #
    # So local_4c8 (the 64-byte buffer) now contains:
    # [0:16] = tweaked IV (from movaps [rbp-0x20], xmm2)
    # [16:32] = second half of original hash (unchanged from HMAC output)
    #     Wait no, at 0x1869 [rbp..rbp+16] is zeroed, 0x1882 [rbp-0x10..rbp] zeroed
    #     0x1889 [rbp+0x10..rbp+0x20] zeroed
    # 
    # So actually: [rbp-0x20..rbp+0x20] = 64 bytes:
    #   [rbp-0x20..-0x10] = tweaked IV (16 bytes) ← from 0x189e
    #   [rbp-0x10..rbp]   = 16 zeros ← from 0x1882
    #   [rbp..rbp+0x10]    = 16 zeros ← from 0x1869
    #   [rbp+0x10..rbp+0x20] = 16 zeros ← from 0x1889
    #
    # And [rbp+0x20..rbp+0x30] = "local_488" = 16 zeros
    #
    # Then second HMAC:
    #   hmac_update(&buf, 64) = hmac_update(tweaked_iv[16] + zeros[48])
    #   hmac_update(&local_488, 16) = hmac_update(zeros[16])
    #   hmac_finish → new 32-byte hash → stored at &buf = [rbp-0x20]  
    
    # Hmm wait, that means the second HMAC input is:
    #   tweaked_iv (16 bytes) + 48 zeros + 16 zeros = tweaked_iv + 64 zeros
    
    # That doesn't match what doc 16 says. Let me re-read the asm at 0x189e more carefully.
    
    # Actually, I need to look at this differently:
    # 0x189e: movaps [rbp-0x20], xmm2  → writes tweaked IV to [rbp-0x20..-0x10]
    # But the zeroing happened at:
    # 0x1869: movdqa [rbp], zeroes → [rbp..rbp+0x10] = 0  
    # 0x1882: movdqa [rbp-0x10], zeroes → [rbp-0x10..rbp] = 0
    # 0x1889: movdqa [rbp+0x10], zeroes → [rbp+0x10..rbp+0x20] = 0
    #
    # So the layout is:
    #   [rbp-0x20 .. rbp-0x10] = tweaked_iv (16B)  ← written at 0x189e
    #   [rbp-0x10 .. rbp]       = zeros (16B)       ← written at 0x1882
    #   [rbp     .. rbp+0x10]   = zeros (16B)       ← written at 0x1869
    #   [rbp+0x10.. rbp+0x20]   = zeros (16B)       ← written at 0x1889
    # = 64 bytes total: tweaked_IV (16) + zeros (48)
    #
    # And [rbp+0x20..rbp+0x30] = local_488 area = zeros (16B) from init
    #
    # Second HMAC:
    #   hmac_update(buf=&[rbp-0x20], len=0x40) → tweaked_IV (16) + zeros (48)
    #   hmac_update(&[rbp+0x20], len=0x10)     → zeros (16)
    #   hmac_finish → 32B hash → stored at [rbp-0x20]
    #
    # Total second HMAC message: tweaked_IV (16B) + 64 zeros = 80 bytes
    
    # Wait, that also seems wrong. Let me check the decompiled source AGAIN
    # and look SPECIFICALLY at what local_488 contains at the time of the 
    # second HMAC.
    
    # The decompiled shows:
    # local_488 = 0;  ← at initialization
    # local_480 = 0;
    # These correspond to [rbp+0x20..0x2f] = 16 bytes of zeros.
    
    # BUT THEN there's the first HMAC:
    # The first HMAC finish writes to &local_4c8 which is [rbp-0x20].
    # local_488 is at [rbp+0x20] so it's 0x40 bytes away. The HMAC output
    # is 32 bytes and would write to [rbp-0x20..rbp], not touching local_488.
    
    # OK let me stop going down rabbit holes and look at this from a different angle.
    # 
    # We KNOW the expected output: identity_hash starts with ba1a86037c1d3c71c3af344955bd69a9
    # for a 32-byte all-zeros PSK.
    # 
    # Let me just try different HMAC key candidates and see which one produces
    # that prefix.
    
    # Step 5: Second HMAC - derive AES key
    # iv_buf now = tweaked_iv (16B) + zeros (48B) = 64 bytes
    # plus an additional 16 bytes of zeros
    iv_buf_new = bytearray(64)  
    iv_buf_new[0:16] = iv
    # rest is zeros (already)
    
    extra_16 = b'\x00' * 16
    
    h2 = hmac.new(hmac_key, digestmod=hashlib.sha256)
    h2.update(bytes(iv_buf_new))  # 64 bytes
    h2.update(extra_16)           # 16 bytes  
    aes_key_full = h2.digest()    # 32 bytes
    
    # Step 6: AES-128-CBC encrypt with first 16 bytes as key
    aes_key = aes_key_full[0:16]  # AES-128 = 16 byte key
    
    # Apply PKCS#7 padding to plaintext
    block_size = 16
    pad_len = block_size - (plaintext_len % block_size)
    padded = plaintext + bytes([pad_len] * pad_len)
    
    cipher = AES.new(aes_key, AES.MODE_CBC, iv=bytes(iv))
    ciphertext = cipher.encrypt(padded)
    
    # Step 7: HMAC-MAC over ciphertext
    # Using the same HMAC context (same key), compute MAC over ciphertext
    h3 = hmac.new(hmac_key, digestmod=hashlib.sha256)
    h3.update(ciphertext)
    mac = h3.digest()  # 32 bytes
    
    # Step 8: Assemble output
    # [16B identity_hash | ciphertext | 32B mac]  
    result = identity_hash + ciphertext + mac
    
    return result


def try_hmac_key(key: bytes, label: str) -> bytes:
    """Try a given HMAC key and return the identity hash."""
    plaintext = b'\x00' * 32
    le32_len = struct.pack('<I', 32)
    
    h = hmac.new(key, digestmod=hashlib.sha256)
    h.update(le32_len)
    h.update(b"123GOODIX")
    hash_result = h.digest()
    
    # Apply tweak to byte 15
    iv = bytearray(hash_result[0:16])
    original = iv[15]
    # plaintext_len=32=0x20, (0x20 & 0xFF)=0x20
    # (original ^ 0x20) & 0x0F ^ original  
    iv[15] = ((original ^ 0x20) & 0x0F) ^ original
    
    identity = bytes(iv)
    print(f"Key={label}: hash[0:16]={hash_result[0:16].hex()}, "
          f"tweaked={identity.hex()}")
    return identity


def try_plain_hash(label: str) -> bytes:
    """Try plain SHA-256 (not HMAC)."""
    plaintext_len = 32
    le32_len = struct.pack('<I', plaintext_len)
    
    h = hashlib.sha256()
    h.update(le32_len)
    h.update(b"123GOODIX")
    hash_result = h.digest()
    
    iv = bytearray(hash_result[0:16])
    original = iv[15]
    iv[15] = ((original ^ 0x20) & 0x0F) ^ original
    
    identity = bytes(iv)
    print(f"Key={label}: hash[0:16]={hash_result[0:16].hex()}, "
          f"tweaked={identity.hex()}")
    return identity


if __name__ == "__main__":
    expected_identity = bytes.fromhex("ba1a86037c1d3c71c3af344955bd69a9")
    expected_full = bytes.fromhex(
        "ba1a86037c1d3c71c3af344955bd69a9"
        "a9861d9e911fa24985b677e8dbd72d43"
    )
    # Note: expected_full is 32 bytes = what PSK Read (0xe4) returns
    # First 16 bytes = identity hash, second 16 bytes might be more of the 
    # first HMAC hash output (before tweaking)
    
    print("=== Searching for correct HMAC key ===")
    print(f"Expected identity hash (first 16B): {expected_identity.hex()}")
    print(f"Expected full PSK Read value (32B):  {expected_full.hex()}")
    print()
    
    # Try different keys
    candidates = [
        (b"", "empty"),
        (b"123GOODIX", "123GOODIX"),
        (b"\x00" * 32, "32_zeros"),
        (b"\x00" * 16, "16_zeros"),
    ]
    
    for key, label in candidates:
        identity = try_hmac_key(key, label)
        if identity == expected_identity:
            print(f"  *** MATCH on first 16 bytes! ***")
            print()
            
            # Now compute the full whitebox blob
            print(f"Computing full whitebox blob with key={label}...")
            blob = sec_white_encrypt(b'\x00' * 32, hmac_key=key)
            print(f"Full blob ({len(blob)} bytes): {blob.hex()}")
            print()
            print("// C array for driver:")
            print("static const guint8 psk_whitebox_zeros[] = {")
            for i in range(0, len(blob), 16):
                chunk = blob[i:i+16]
                hex_vals = ", ".join(f"0x{b:02x}" for b in chunk)
                print(f"  {hex_vals},")
            print("};")
            break
    else:
        print()
        print("No HMAC key matched. Trying plain SHA-256...")
        identity = try_plain_hash("SHA256_no_HMAC")
        if identity == expected_identity:
            print("  *** MATCH with plain SHA-256! ***")
    
    print()
    
    # Also try: maybe "123GOODIX" is the message, and LE32(len) is the key?
    # i.e., HMAC(key=LE32(32), msg="123GOODIX")
    print("=== Alternative: LE32 as key, 123GOODIX as message ===")
    le32 = struct.pack('<I', 32)
    h = hmac.new(le32, b"123GOODIX", hashlib.sha256)
    hash_r = h.digest()
    iv = bytearray(hash_r[0:16])
    orig = iv[15]
    iv[15] = ((orig ^ 0x20) & 0x0F) ^ orig
    print(f"  tweaked={bytes(iv).hex()}")
    if bytes(iv) == expected_identity:
        print("  *** MATCH! ***")
