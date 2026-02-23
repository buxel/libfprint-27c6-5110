#!/usr/bin/env python3
r"""
Comprehensive disassembler for gfspi.dll key functions.
Finds function boundaries properly and captures full disassembly.

Driver: gfspi.dll v1.1.124.115 (Jul 2024)
Source path: d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\
"""

import pefile
import struct
import re
import os
from capstone import *

DLL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'driver-2024', 'gfspi.dll')
OUT_DIR = os.path.dirname(os.path.abspath(__file__))


def find_func_boundary(data, near_addr):
    """Find function start by scanning backward for ret/int3."""
    for addr in range(near_addr, max(0x1000, near_addr - 0x800), -1):
        b = data[addr]
        if b == 0xC3 or b == 0xCC:
            start = addr + 1
            while start < len(data) and data[start] == 0xCC:
                start += 1
            return start
    return near_addr


def find_func_end(data, start_addr, max_scan=0x1000):
    """Find end of function by looking for ret followed by int3/padding."""
    md = Cs(CS_ARCH_X86, CS_MODE_64)
    code = bytes(data[start_addr:start_addr + max_scan])
    last_ret = start_addr
    for inst in md.disasm(code, start_addr):
        if inst.mnemonic == 'ret':
            last_ret = inst.address + inst.size
        if inst.mnemonic == 'int3':
            return inst.address
    return last_ret


def find_xrefs(data, target_rva, text_start=0x1000, text_size=0x77834):
    """Find RIP-relative references to a target RVA in the text section."""
    text_data = data[text_start:text_start + text_size]
    xrefs = set()
    for i in range(len(text_data) - 4):
        disp = struct.unpack_from('<i', text_data, i)[0]
        next_inst = text_start + i + 4
        if next_inst + disp == target_rva:
            inst_addr = text_start + i - 3
            if inst_addr >= text_start:
                xrefs.add(inst_addr)
    return sorted(xrefs)


def disasm_region(data, start, end, wide_strings, ascii_strings):
    """Disassemble a region with string/call annotations."""
    md = Cs(CS_ARCH_X86, CS_MODE_64)
    md.detail = True

    code = bytes(data[start:end])
    lines = []

    for inst in md.disasm(code, start):
        ann = []

        for op in inst.operands:
            if op.type == 3 and op.mem.disp != 0:
                target = inst.address + inst.size + op.mem.disp
                found = False
                if target in wide_strings:
                    ann.append(f'W"{wide_strings[target][:70]}"')
                    found = True
                if not found and target in ascii_strings:
                    ann.append(f'"{ascii_strings[target][:70]}"')
                    found = True
                if not found:
                    try:
                        chunk = data[target:target + 120]
                        s16 = chunk.decode('utf-16-le', errors='replace').split('\x00')[0]
                        if len(s16) >= 4 and s16.isprintable():
                            ann.append(f'W"{s16[:70]}"')
                            found = True
                    except:
                        pass
                    if not found:
                        try:
                            sa = chunk.split(b'\x00')[0].decode('ascii', errors='replace')
                            ok = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_. ():%!-+*/\\:'
                            if len(sa) >= 4 and all(c in ok for c in sa):
                                ann.append(f'"{sa[:70]}"')
                        except:
                            pass

        if inst.mnemonic == 'call':
            for op in inst.operands:
                if op.type == 2:
                    ann.append(f'fn_{op.imm:#x}')

        hx = inst.bytes.hex()
        if len(hx) > 24:
            hx = hx[:24] + ".."

        line = f"  {inst.address:08x}:  {hx:<26s}  {inst.mnemonic:<8s} {inst.op_str}"
        if ann:
            line += "  ; " + " | ".join(ann)
        lines.append(line)

        if inst.mnemonic == 'int3':
            next_off = inst.address + inst.size - start
            if next_off < len(code) and code[next_off] == 0xCC:
                lines.append("")
                lines.append("; --- function boundary ---")
                lines.append("")

    return "\n".join(lines)


def main():
    print(f"Loading {DLL_PATH}...")
    pe = pefile.PE(DLL_PATH)
    data = pe.get_memory_mapped_image()
    imagebase = pe.OPTIONAL_HEADER.ImageBase

    print("Building string tables...")
    wide_strings = {}
    for m in re.finditer(b'(?:[\x20-\x7e]\x00){4,}', data):
        try:
            s = m.group().decode('utf-16-le')
            if s.isprintable() and len(s) >= 4:
                wide_strings[m.start()] = s
        except:
            pass

    ascii_strings = {}
    for m in re.finditer(b'[\x20-\x7e]{6,}', data):
        try:
            s = m.group().decode('ascii')
            if s.isprintable():
                ascii_strings[m.start()] = s
        except:
            pass
    print(f"  {len(wide_strings)} wide, {len(ascii_strings)} ASCII strings")

    # Find key string RVAs
    string_targets = {}
    search_strings = [
        ('generate_entropy2', 'utf-16-le'),
        ('gf_seal_data', 'utf-16-le'),
        ('gf_unseal_data', 'utf-16-le'),
        ('production_write_key', 'utf-16-le'),
        ('production_psk_process', 'utf-16-le'),
        ('production_get_host_psk_data', 'utf-16-le'),
        ('production_check_psk_is_valid', 'utf-16-le'),
        ('generate rootkey', 'utf-16-le'),
        ('CryptProtectData', 'utf-16-le'),
        ('CryptUnprotectData', 'utf-16-le'),
        ('CryptGenRandom', 'utf-16-le'),
        ('Goodix_Cache.bin', 'utf-16-le'),
        ('123GOODIX', 'ascii'),
        ('SecWhiteEncrypt', 'ascii'),
    ]

    for name, enc in search_strings:
        needle = name.encode(enc)
        off = data.find(needle)
        if off >= 0:
            string_targets[name] = off
            print(f"  '{name}' ({enc}) at RVA {off:#x}")

    # ================================================================
    # Define functions to disassemble
    # ================================================================
    functions = [
        {
            'name': 'generate_entropy2',
            'file': '01-generate_entropy2.asm',
            'string_key': 'generate_entropy2',
            'header': [
                "; gfspi.dll - generate_entropy2 function",
                "; Generates entropy (rootkey) used as DPAPI optional entropy parameter",
                "; Contains XOR loops that derive a 16-byte value from static data tables",
                "; Then hashes (SHA-256) the result to produce final entropy",
                "; Called before gf_seal_data and gf_unseal_data",
            ],
            'extra_range': 0x600,
        },
        {
            'name': 'gf_seal_data',
            'file': '02-gf_seal_data.asm',
            'string_key': 'gf_seal_data',
            'header': [
                "; gfspi.dll - gf_seal_data function",
                r"; Source: d:\project\winfpcode\...\gf_win_crypt_helper.c",
                "; Wraps CryptProtectData with CRYPTPROTECT_LOCAL_MACHINE flag (0x4)",
                "; Signature: gf_seal_data(inbuf, inbuf_len, entropy, entropy_len, outbuf, outbuf_len)",
                "; Logs: 'inbuf_len %d, entropy_len %d, len_out %d'",
                "; 'This is the description string.' passed as szDataDescr",
            ],
            'extra_range': 0x400,
        },
        {
            'name': 'gf_unseal_data',
            'file': '03-gf_unseal_data.asm',
            'string_key': 'gf_unseal_data',
            'header': [
                "; gfspi.dll - gf_unseal_data function",
                "; Source: gf_win_crypt_helper.c",
                "; Wraps CryptUnprotectData",
            ],
            'extra_range': 0x400,
        },
        {
            'name': 'production_write_key',
            'file': '04-production_write_key.asm',
            'string_key': 'production_write_key',
            'header': [
                "; gfspi.dll - production_write_key function",
                "; Generates random PSK, seals with DPAPI, writes to MCU, caches to file",
                "; Flow: 0.generate random psk -> 1.seal psk -> 2.process encrypted psk",
                ";       -> 3.write to mcu -> write Goodix_Cache.bin",
            ],
            'extra_range': 0x600,
        },
        {
            'name': 'production_psk_process',
            'file': '05-production_psk_process.asm',
            'string_key': 'production_psk_process',
            'header': [
                "; gfspi.dll - production_psk_process function",
                "; Main PSK orchestration: check validity, write if needed",
            ],
            'extra_range': 0x800,
        },
        {
            'name': 'production_get_host_psk_data',
            'file': '06-production_get_host_psk_data.asm',
            'string_key': 'production_get_host_psk_data',
            'header': [
                "; gfspi.dll - production_get_host_psk_data function",
                "; Reads Goodix_Cache.bin, unseals (DPAPI), extracts PSK",
                "; Also performs whitebox (wb) decryption and hash verification",
            ],
            'extra_range': 0x800,
        },
        {
            'name': 'production_check_psk_is_valid',
            'file': '07-production_check_psk_is_valid.asm',
            'string_key': 'production_check_psk_is_valid',
            'header': [
                "; gfspi.dll - production_check_psk_is_valid function",
                "; Compares host PSK hash vs MCU PSK hash",
            ],
            'extra_range': 0x600,
        },
        {
            'name': 'SecWhiteEncrypt',
            'file': '08-SecWhiteEncrypt.asm',
            'string_key': 'SecWhiteEncrypt',
            'header': [
                "; gfspi.dll - SecWhiteEncrypt / 123GOODIX functions",
                "; Whitebox encryption using HMAC-SHA256('123GOODIX') + AES-128-CBC",
                f"; '123GOODIX' (ASCII) at RVA {string_targets.get('123GOODIX', 0):#x}",
                f"; 'SecWhiteEncrypt' (ASCII) at RVA {string_targets.get('SecWhiteEncrypt', 0):#x}",
            ],
            'extra_range': 0x800,
        },
    ]

    for func in functions:
        key = func['string_key']
        if key not in string_targets:
            print(f"\n  SKIP {func['name']}: string not found")
            continue

        xrefs = find_xrefs(data, string_targets[key])
        if not xrefs:
            print(f"\n  SKIP {func['name']}: no XREFs found")
            continue

        func_start = find_func_boundary(data, xrefs[0])
        func_end = func_start + func['extra_range']

        actual_end = find_func_end(data, func_start, func['extra_range'])
        if actual_end > func_start:
            func_end = actual_end + 16

        print(f"\n  {func['name']}: {func_start:#x} - {func_end:#x} (XREFs: {[f'{x:#x}' for x in xrefs[:5]]})")

        output = disasm_region(data, func_start, func_end, wide_strings, ascii_strings)

        outpath = os.path.join(OUT_DIR, func['file'])
        with open(outpath, 'w') as f:
            for h in func['header']:
                f.write(h + "\n")
            f.write(f"; Image base: {imagebase:#x}\n")
            f.write(f"; String '{key}' at RVA {string_targets[key]:#x}\n")
            f.write(f"; XREFs: {[f'{x:#x}' for x in xrefs[:10]]}\n")
            f.write(f"; Function start: RVA {func_start:#x}\n")
            f.write(f"; Function end: RVA {func_end:#x}\n\n")
            f.write(output)

        line_count = output.count('\n') + 1
        print(f"    -> {outpath} ({line_count} lines)")

    # ================================================================
    # Extract data tables referenced by generate_entropy2
    # ================================================================
    print("\n=== Extracting data tables ===")
    md = Cs(CS_ARCH_X86, CS_MODE_64)
    md.detail = True

    if 'generate_entropy2' in string_targets:
        gen_xrefs = find_xrefs(data, string_targets['generate_entropy2'])
        if gen_xrefs:
            gen_start = find_func_boundary(data, gen_xrefs[0])
            code = bytes(data[gen_start:gen_start + 0x600])

            data_refs = set()
            for inst in md.disasm(code, gen_start):
                if inst.mnemonic in ('lea', 'mov', 'movzx'):
                    for op in inst.operands:
                        if op.type == 3 and op.mem.disp != 0:
                            target = inst.address + inst.size + op.mem.disp
                            if 0x537000 <= target < 0x5a0000:
                                data_refs.add(target)

            outpath = os.path.join(OUT_DIR, '09-data_tables.txt')
            with open(outpath, 'w') as f:
                f.write("; Data tables referenced by generate_entropy2\n")
                f.write("; These are in the .data section and used in XOR loops\n\n")

                for ref in sorted(data_refs):
                    chunk = data[ref:ref + 48]
                    f.write(f"  RVA {ref:#08x}: {chunk[:16].hex()} {chunk[16:32].hex()} {chunk[32:48].hex()}\n")
                    ascii_try = chunk[:32].decode('ascii', errors='replace')
                    f.write(f"               ASCII: {ascii_try}\n\n")

            print(f"    -> {outpath} ({len(data_refs)} data references)")

    # ================================================================
    # Import table
    # ================================================================
    print("\n=== Extracting imports ===")
    outpath = os.path.join(OUT_DIR, '10-imports.txt')
    with open(outpath, 'w') as f:
        f.write("; gfspi.dll import table\n\n")

        f.write("; === Crypto/DPAPI related ===\n\n")
        for entry in pe.DIRECTORY_ENTRY_IMPORT:
            dll_name = entry.dll.decode('utf-8', errors='replace')
            crypto_imports = []
            for imp in entry.imports:
                name = imp.name.decode('utf-8', errors='replace') if imp.name else f"ord_{imp.ordinal}"
                if any(kw in name.lower() for kw in ['crypt', 'dpapi', 'protect', 'random', 'hash',
                                                       'key', 'cert', 'sign', 'verify', 'encrypt',
                                                       'decrypt', 'bcrypt', 'ncrypt']):
                    crypto_imports.append((imp.address - imagebase, name))
            if crypto_imports:
                f.write(f"[{dll_name}]\n")
                for addr, name in crypto_imports:
                    f.write(f"  IAT RVA {addr:#x}: {name}\n")
                f.write("\n")

        f.write("\n; === ALL IMPORTS ===\n\n")
        for entry in pe.DIRECTORY_ENTRY_IMPORT:
            dll_name = entry.dll.decode('utf-8', errors='replace')
            f.write(f"[{dll_name}]\n")
            for imp in entry.imports:
                name = imp.name.decode('utf-8', errors='replace') if imp.name else f"ord_{imp.ordinal}"
                f.write(f"  {name}\n")
            f.write("\n")
    print(f"  -> {outpath}")

    print("\n=== All done ===")


if __name__ == '__main__':
    main()
