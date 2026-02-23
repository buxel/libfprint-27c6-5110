#!/usr/bin/env python3
"""
SecWhiteEncrypt key derivation probe.

The disassembly shows mbedtls_md_setup(ctx, SHA256, hmac=1) but NO subsequent
mbedtls_md_hmac_starts() call before the first hmac_reset. This means the
ipad/opad buffers are whatever calloc initialized them to (zeros).

In mbedtls:
  hmac_reset: hash_starts → hash_update(ipad, 64)
  hmac_finish: inner = hash_finish → hash_starts → hash_update(opad, 64) → hash_update(inner, 32) → hash_finish

With uninitialized (zero) ipad/opad:
  "HMAC"(msg) = SHA256(zeros_64 || SHA256(zeros_64 || msg))

But ALSO consider: maybe the function at 0x364a0 is mbedtls_md_starts (plain
hash, not HMAC reset). Then the subsequent calls to 0x364f0 and 0x35c10 are
plain md_update and md_finish.

Let's also consider that "123GOODIX" might be used as the HMAC key via
hmac_starts at some point we missed, or that DAT_1800d33a0 contains the key.
"""

import hashlib
import hmac
import struct

EXPECTED_IDENTITY = bytes.fromhex("ba1a86037c1d3c71c3af344955bd69a9")
EXPECTED_FULL_32 = bytes.fromhex(
    "ba1a86037c1d3c71c3af344955bd69a9"
    "a9861d9e911fa24985b677e8dbd72d43"
)

def tweak_iv(iv_bytes: bytes, plaintext_len: int) -> bytes:
    """Apply the IV tweak from the disassembly."""
    iv = bytearray(iv_bytes[:16])
    orig = iv[15]
    iv[15] = ((orig ^ (plaintext_len & 0xFF)) & 0x0F) ^ orig
    return bytes(iv)


def try_method(label: str, hash_result: bytes):
    """Check if hash result matches expected identity."""
    iv = tweak_iv(hash_result, 32)
    match = "*** MATCH ***" if iv == EXPECTED_IDENTITY else ""
    print(f"  {label}:")
    print(f"    raw[0:16] = {hash_result[:16].hex()}")
    print(f"    tweaked   = {iv.hex()}")
    if match:
        print(f"    {match}")
    
    # Also check if full 32 bytes match the PSK Read output
    if hash_result[:16] == EXPECTED_FULL_32[:16]:
        # Check byte 15 (raw vs tweaked)
        pass
    
    return iv == EXPECTED_IDENTITY


print("Expected identity: " + EXPECTED_IDENTITY.hex())
print(f"Expected byte 15 raw (before tweak): ???")
print()

# The tweak for len=32 (0x20):
# new = ((old ^ 0x20) & 0x0F) ^ old
# Since 0x20 & 0x0F = 0, this simplifies to:
# new = (old & 0x0F) ^ old = old & 0xF0
# So tweaked[15] = raw[15] & 0xF0
# Expected tweaked[15] = 0xa9
# So raw[15] must satisfy: raw[15] & 0xF0 = 0xa0
# And raw[15] low nibble can be anything
# Wait: 0xa9 & 0xF0 = 0xa0, but expected is 0xa9
# Let me re-derive: new = ((old ^ 0x20) & 0x0F) ^ old
# For 0x20: old ^ 0x20 is old with bit 5 flipped
# (old ^ 0x20) & 0x0F = old & 0x0F (since bit 5 is above nibble)
# So new = (old & 0x0F) ^ old = old_high_nibble
# Hmm, that gives: new = old & 0xF0
# So expected_tweaked[15] = 0xa9 means 0xa9 = old & 0xF0 → impossible!
# 0xa9 & 0xF0 = 0xa0, but old & 0xF0 should equal 0xa9.
# 0xa9 isn't a multiple of 16...

# Wait, let me re-derive more carefully:
# new = ((old ^ 0x20) & 0x0F) ^ old
# Let old = 0xAB (example), len_byte = 0x20
# (0xAB ^ 0x20) = 0x8B
# 0x8B & 0x0F = 0x0B
# 0x0B ^ 0xAB = 0xA0
# So new = 0xA0 = old & 0xF0. Yes, low nibble is zeroed.

# But expected_tweaked[15] = 0xa9
# 0xa9 is NOT of the form X0 (low nibble = 9, not 0)
# This means either:
#   1. My understanding of the tweak is wrong
#   2. The expected identity hash I'm using is wrong (it's 32 bytes from PSK Read)
#   3. PSK Read returns something different from the identity hash

# Wait — the PSK Read returns 32 bytes: ba1a8603...a9861d9e...
# Maybe only the first 16 bytes are the identity hash, and those are:
# ba 1a 86 03 7c 1d 3c 71 c3 af 34 49 55 bd 69 a9
# byte 15 = 0xa9
# And before tweak: old[15] such that old & 0xF0 = 0xa9
# But 0xa9 is not a multiple of 0x10! So the tweak should produce X0 form...

# Unless I have the tweak formula wrong. Let me re-read the asm:
# 0x1874: shr rcx, 0x38     → get byte 15 (MSB of qword = byte at [rbp-0x12])
# 0x1878: xor cl, sil       → cl ^= plaintext_len_low_byte (0x20)
# 0x187b: shr rax, 0x38     → same byte (rax was set same as rcx earlier)
# 0x187f: and cl, 0xf       → cl &= 0x0F
# 0x1887: xor cl, al        → cl ^= original_byte_15
# 0x188e: mov [rbp+0x3f], cl → store

# So: cl = ((byte15 ^ sil) & 0x0F) ^ byte15
# With sil = 0x20:
# cl = ((byte15 ^ 0x20) & 0x0F) ^ byte15
# = (byte15 & 0x0F) ^ byte15  (since 0x20 bit is above 0x0F mask)
# = byte15 & 0xF0

# So indeed, the tweaked byte 15 MUST be of the form X0.
# But the expected first 16 bytes ba1a86037c1d3c71c3af344955bd69a9 has 
# byte 15 = 0xa9, which ends in 9, not 0.

# This means one of:
# a) The 32 bytes from PSK Read are NOT directly the SecWhiteEncrypt output header
# b) The expected hash I'm using takes a different form

# Hmm, looking at the PSK Read format: maybe it's the FULL first 32 bytes
# of the whitebox blob, and only a SUBSET is the tweaked IV.
# But the asm clearly copies xmm2 (16 bytes = tweaked IV) to r15 (output).
# And the PSK Read command returns what was written via PSK Write.

# Wait — maybe PSK Read returns the FULL whitebox blob (or 32 bytes of it),
# not just the 16-byte identity hash. In that case, the first 16 bytes might
# NOT be the result of the tweak.

# OR maybe the PSK Read output has nothing to do with SecWhiteEncrypt output.
# Maybe it's produced by a different function in the sensor firmware.

# Let me reconsider. The doc 16 says:
# "The first 16 bytes of the whitebox output serve as the identity token.
#  PSK Read returns this hash"
# But that's our analysis, not from Windows docs.

# Actually, the disassembly of production_check_psk_is_valid (07) compares
# a "host hash" against an "MCU hash" (32 bytes via memcmp). The MCU hash
# is obtained via fn_0x28f20 with tag 0xbb020003 (same as PSK Read flags).
# The host hash comes from production_get_host_psk_data.

# So: PSK Read (0xe4) with flags 0xbb020003 returns 32 bytes that are compared
# to a "host hash". That host hash is computed from the plaintext PSK (not
# from the whitebox blob). So the 32-byte PSK Read value might be a HASH of 
# the PSK, not the whitebox header!

# Let me try: SHA-256(all_zeros_32) and compare
plain_hash = hashlib.sha256(b'\x00' * 32).digest()
print("SHA-256(zeros_32) = " + plain_hash.hex())
print("Expected PSK Read = " + EXPECTED_FULL_32.hex())
print("Match: " + str(plain_hash == EXPECTED_FULL_32))
print()

# Try HMAC-SHA256("123GOODIX", zeros_32)
h = hmac.new(b"123GOODIX", b'\x00' * 32, hashlib.sha256)
print("HMAC-SHA256('123GOODIX', zeros_32) = " + h.digest().hex())
print("Match: " + str(h.digest() == EXPECTED_FULL_32))
print()

# Try HMAC-SHA256(zeros_32, "123GOODIX")
h = hmac.new(b'\x00' * 32, b"123GOODIX", hashlib.sha256)
print("HMAC-SHA256(zeros_32, '123GOODIX') = " + h.digest().hex())
print("Match: " + str(h.digest() == EXPECTED_FULL_32))
print()

# What about: the wihitebox output[0:16] IS the tweaked IV which SHOULD have
# byte 15 as X0. But the PSK Read value is 32 bytes, not 16. Maybe the PSK
# Read value is something ELSE entirely — like what the sensor firmware computes
# independently (not the whitebox header).

# In production_check_psk_is_valid (fn_0x27450):
#   Step 1: production_get_host_psk_data → obtains PSK bytes + "host hash" (32B)
#   Step 2: read from MCU with tag 0xbb020003 → "MCU hash" (32B) 
#   Step 3: memcmp(host_hash, mcu_hash, 32)
#
# The "host hash" is derived from the plaintext PSK on the host side.
# The "MCU hash" is stored on the sensor (computed by sensor firmware after
# it decrypts the whitebox blob and extracts the PSK).
# Both sides compute the SAME hash from the SAME plaintext PSK.
#
# So PSK Read returns a HASH computed by the sensor firmware from the plaintext PSK.
# This hash is NOT the whitebox blob header!

# The question is: what hash function does the sensor firmware use?
# And what hash function does production_get_host_psk_data use?
# We need to disassemble production_get_host_psk_data (fn_0x27b60) to find this.

# But first, let me try some obvious candidates:
print("=== Trying to match PSK Read value (32B hash of zeros_32 PSK) ===")
print(f"Target: {EXPECTED_FULL_32.hex()}")
print()

candidates = [
    ("SHA256(psk)", hashlib.sha256(b'\x00' * 32).digest()),
    ("SHA256('123GOODIX' || psk)", hashlib.sha256(b"123GOODIX" + b'\x00' * 32).digest()),
    ("SHA256(psk || '123GOODIX')", hashlib.sha256(b'\x00' * 32 + b"123GOODIX").digest()),
    ("HMAC(key='123GOODIX', msg=psk)", hmac.new(b"123GOODIX", b'\x00' * 32, hashlib.sha256).digest()),
    ("HMAC(key=psk, msg='123GOODIX')", hmac.new(b'\x00' * 32, b"123GOODIX", hashlib.sha256).digest()),
    ("HMAC(key=b'', msg=psk)", hmac.new(b"", b'\x00' * 32, hashlib.sha256).digest()),
    ("SHA256(LE32(32) || '123GOODIX' || psk)", hashlib.sha256(struct.pack('<I', 32) + b"123GOODIX" + b'\x00' * 32).digest()),
    ("double SHA256(psk)", hashlib.sha256(hashlib.sha256(b'\x00' * 32).digest()).digest()),
]

for label, result in candidates:
    match = "MATCH!" if result == EXPECTED_FULL_32 else ""
    print(f"  {label}: {result.hex()} {match}")

print()

# The identity hash from production_check_psk_is_valid is 32 bytes read from MCU.
# It's compared against 32 bytes from the host.
# These are NOT the SecWhiteEncrypt output — they're a VERIFICATION hash.
#
# We need to look at production_get_host_psk_data (fn_0x27b60) to find how
# the host computes its hash. That function is at 06-production_get_host_psk_data.asm.

# Meanwhile, our goal of computing SecWhiteEncrypt for the whitebox blob
# is SEPARATE from understanding the verification hash.
#
# For SecWhiteEncrypt, we still need to figure out:
# 1. What HMAC key is used (possibly a key from DAT_1800d33a0)
# 2. The correct algorithm
#
# But we CAN'T verify SecWhiteEncrypt's output against the PSK Read value,
# because they're different things!
#
# What we CAN do: use the existing `goodix-fp-dump` tool as ground truth.
# The run_5110.py script writes a 96-byte whitebox blob for all-zeros PSK.
# If we can find that blob in the source, we have our answer.

print("=== Need to check goodix-fp-dump for the hardcoded whitebox blob ===")
print("The run_5110.py script writes a pre-computed 96-byte blob.")
print("That blob IS the SecWhiteEncrypt(zeros_32) output we need.")
