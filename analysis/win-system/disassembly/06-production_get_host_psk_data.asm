; gfspi.dll - production_get_host_psk_data function
; Reads Goodix_Cache.bin, unseals (DPAPI), extracts PSK
; Also performs whitebox (wb) decryption and hash verification
; Image base: 0x180000000
; String 'production_get_host_psk_data' at RVA 0x31c010
; XREFs: ['0x27baa', '0x27c8d', '0x27ceb', '0x27d68', '0x27df8', '0x27ea7', '0x27ef5', '0x27f37', '0x27fcc', '0x2800f']
; Function start: RVA 0x27b60
; Function end: RVA 0x28360

  00027b60:  44894c2420                  mov      dword ptr [rsp + 0x20], r9d
  00027b65:  4c89442418                  mov      qword ptr [rsp + 0x18], r8
  00027b6a:  89542410                    mov      dword ptr [rsp + 0x10], edx
  00027b6e:  48894c2408                  mov      qword ptr [rsp + 8], rcx
  00027b73:  57                          push     rdi
  00027b74:  4881ec100b0000              sub      rsp, 0xb10
  00027b7b:  488b05c61d5100              mov      rax, qword ptr [rip + 0x511dc6]
  00027b82:  4833c4                      xor      rax, rsp
  00027b85:  48898424000b0000            mov      qword ptr [rsp + 0xb00], rax
  00027b8d:  488d055ce70900              lea      rax, [rip + 0x9e75c]  ; W"entry"
  00027b94:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00027b99:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00027ba2:  c7442420e80a0000            mov      dword ptr [rsp + 0x20], 0xae8
  00027baa:  4c8d0d5f442f00              lea      r9, [rip + 0x2f445f]  ; W"production_get_host_psk_data"
  00027bb1:  4c8d0508032f00              lea      r8, [rip + 0x2f0308]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027bb8:  ba08000000                  mov      edx, 8
  00027bbd:  488b0dc4045100              mov      rcx, qword ptr [rip + 0x5104c4]
  00027bc4:  e8b3e4fdff                  call     0x607c  ; fn_0x607c
  00027bc9:  c7442450010000ff            mov      dword ptr [rsp + 0x50], 0xff000001
  00027bd1:  48c744246000000000          mov      qword ptr [rsp + 0x60], 0
  00027bda:  c744245400000000            mov      dword ptr [rsp + 0x54], 0
  00027be2:  48c744246800000000          mov      qword ptr [rsp + 0x68], 0
  00027beb:  488d842480020000            lea      rax, [rsp + 0x280]
  00027bf3:  488bf8                      mov      rdi, rax
  00027bf6:  33c0                        xor      eax, eax
  00027bf8:  b980000000                  mov      ecx, 0x80
  00027bfd:  f3aa                        rep stosb byte ptr [rdi], al
  00027bff:  c744245800000000            mov      dword ptr [rsp + 0x58], 0
  00027c07:  488d842400030000            lea      rax, [rsp + 0x300]  ; W"︐诿⑄襐⑄䠸֍䉏/襈⑄䠰䓇⠤"
  00027c0f:  488bf8                      mov      rdi, rax
  00027c12:  33c0                        xor      eax, eax
  00027c14:  b900080000                  mov      ecx, 0x800
  00027c19:  f3aa                        rep stosb byte ptr [rdi], al
  00027c1b:  c744245c00080000            mov      dword ptr [rsp + 0x5c], 0x800
  00027c23:  4883bc24300b000000          cmp      qword ptr [rsp + 0xb30], 0  ; W"〤읈⑄("
  00027c2c:  7442                        je       0x27c70
  00027c2e:  4883bc24400b000000          cmp      qword ptr [rsp + 0xb40], 0
  00027c37:  7437                        je       0x27c70
  00027c39:  4883bc24480b000000          cmp      qword ptr [rsp + 0xb48], 0
  00027c42:  742c                        je       0x27c70
  00027c44:  4883bc24500b000000          cmp      qword ptr [rsp + 0xb50], 0  ; W"䒉〤읈⑄("
  00027c4d:  7421                        je       0x27c70
  00027c4f:  83bc24280b000020            cmp      dword ptr [rsp + 0xb28], 0x20
  00027c57:  7517                        jne      0x27c70
  00027c59:  83bc24380b000020            cmp      dword ptr [rsp + 0xb38], 0x20  ; W"⼫䠀䒉〤읈⑄("
  00027c61:  750d                        jne      0x27c70
  00027c63:  488b8424480b0000            mov      rax, qword ptr [rsp + 0xb48]
  00027c6b:  833820                      cmp      dword ptr [rax], 0x20
  00027c6e:  7345                        jae      0x27cb5
  00027c70:  488d05d9432f00              lea      rax, [rip + 0x2f43d9]  ; W"input ERROR"
  00027c77:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00027c7c:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00027c85:  c7442420fa0a0000            mov      dword ptr [rsp + 0x20], 0xafa
  00027c8d:  4c8d0d7c432f00              lea      r9, [rip + 0x2f437c]  ; W"production_get_host_psk_data"
  00027c94:  4c8d0525022f00              lea      r8, [rip + 0x2f0225]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027c9b:  ba04000000                  mov      edx, 4
  00027ca0:  488b0de1035100              mov      rcx, qword ptr [rip + 0x5103e1]
  00027ca7:  e8d0e3fdff                  call     0x607c  ; fn_0x607c
  00027cac:  8b442450                    mov      eax, dword ptr [rsp + 0x50]
  00027cb0:  e972070000                  jmp      0x28427
  00027cb5:  488b8424500b0000            mov      rax, qword ptr [rsp + 0xb50]
  00027cbd:  c60000                      mov      byte ptr [rax], 0
  00027cc0:  488b8424480b0000            mov      rax, qword ptr [rsp + 0xb48]
  00027cc8:  8b00                        mov      eax, dword ptr [rax]
  00027cca:  89442454                    mov      dword ptr [rsp + 0x54], eax  ; W"섍◓䐀䒋吤譈⒔ୀ"
  00027cce:  488d0593432f00              lea      rax, [rip + 0x2f4393]  ; W".get seal data"
  00027cd5:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00027cda:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0  ; W"֍㴯/Һ"
  00027ce3:  c7442420020b0000            mov      dword ptr [rsp + 0x20], 0xb02  ; W"֍㴯/Һ"
  00027ceb:  4c8d0d1e432f00              lea      r9, [rip + 0x2f431e]  ; W"production_get_host_psk_data"
  00027cf2:  4c8d05c7012f00              lea      r8, [rip + 0x2f01c7]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027cf9:  ba08000000                  mov      edx, 8
  00027cfe:  488b0d83035100              mov      rcx, qword ptr [rip + 0x510383]
  00027d05:  e872e3fdff                  call     0x607c  ; fn_0x607c
  00027d0a:  4c8d052f3d2f00              lea      r8, [rip + 0x2f3d2f]  ; W"Goodix_Cache.bin"
  00027d11:  ba04000000                  mov      edx, 4
  00027d16:  488d4c2470                  lea      rcx, [rsp + 0x70]
  00027d1b:  e8d8d8fdff                  call     0x55f8  ; fn_0x55f8
  00027d20:  4c8d0dc1d32500              lea      r9, [rip + 0x25d3c1]
  00027d27:  448b442454                  mov      r8d, dword ptr [rsp + 0x54]
  00027d2c:  488b9424400b0000            mov      rdx, qword ptr [rsp + 0xb40]
  00027d34:  488bc8                      mov      rcx, rax
  00027d37:  e8a0abfdff                  call     0x28dc  ; fn_0x28dc
  00027d3c:  4889442460                  mov      qword ptr [rsp + 0x60], rax
  00027d41:  488b442460                  mov      rax, qword ptr [rsp + 0x60]  ; W"怤赈ࡄ䇸ࢹ"
  00027d46:  4889442438                  mov      qword ptr [rsp + 0x38], rax
  00027d4b:  488d0536432f00              lea      rax, [rip + 0x2f4336]  ; W"read %d bytes"
  00027d52:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"荈⑼`蘏ǣ"
  00027d57:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00027d60:  c7442420070b0000            mov      dword ptr [rsp + 0x20], 0xb07
  00027d68:  4c8d0da1422f00              lea      r9, [rip + 0x2f42a1]  ; W"production_get_host_psk_data"
  00027d6f:  4c8d054a012f00              lea      r8, [rip + 0x2f014a]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027d76:  ba08000000                  mov      edx, 8
  00027d7b:  488b0d06035100              mov      rcx, qword ptr [rip + 0x510306]
  00027d82:  e8f5e2fdff                  call     0x607c  ; fn_0x607c
  00027d87:  48837c246000                cmp      qword ptr [rsp + 0x60], 0
  00027d8d:  0f86e3010000                jbe      0x27f76
  00027d93:  c744245880000000            mov      dword ptr [rsp + 0x58], 0x80
  00027d9b:  488b8424400b0000            mov      rax, qword ptr [rsp + 0xb40]
  00027da3:  488b4c2460                  mov      rcx, qword ptr [rsp + 0x60]
  00027da8:  488d4408f8                  lea      rax, [rax + rcx - 8]
  00027dad:  41b908000000                mov      r9d, 8
  00027db3:  4c8bc0                      mov      r8, rax
  00027db6:  488d542458                  lea      rdx, [rsp + 0x58]
  00027dbb:  488d8c2480020000            lea      rcx, [rsp + 0x280]
  00027dc3:  e818f2ffff                  call     0x26fe0  ; fn_0x26fe0
  00027dc8:  89442450                    mov      dword ptr [rsp + 0x50], eax
  00027dcc:  837c245000                  cmp      dword ptr [rsp + 0x50], 0
  00027dd1:  7449                        je       0x27e1c
  00027dd3:  8b442450                    mov      eax, dword ptr [rsp + 0x50]
  00027dd7:  89442438                    mov      dword ptr [rsp + 0x38], eax
  00027ddb:  488d05ce422f00              lea      rax, [rip + 0x2f42ce]  ; W"generate entropy failed with 0x%x"
  00027de2:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00027de7:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00027df0:  c7442420150b0000            mov      dword ptr [rsp + 0x20], 0xb15
  00027df8:  4c8d0d11422f00              lea      r9, [rip + 0x2f4211]  ; W"production_get_host_psk_data"
  00027dff:  4c8d05ba002f00              lea      r8, [rip + 0x2f00ba]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027e06:  ba04000000                  mov      edx, 4
  00027e0b:  488b0d76025100              mov      rcx, qword ptr [rip + 0x510276]
  00027e12:  e865e2fdff                  call     0x607c  ; fn_0x607c
  00027e17:  e9be050000                  jmp      0x283da
  00027e1c:  488d842480020000            lea      rax, [rsp + 0x280]
  00027e24:  4889442468                  mov      qword ptr [rsp + 0x68], rax  ; W"襈⑄䠰䓇⠤"
  00027e29:  488b442460                  mov      rax, qword ptr [rsp + 0x60]  ; W"⽂䠀䒉〤읈⑄("
  00027e2e:  4883e808                    sub      rax, 8
  00027e32:  89442454                    mov      dword ptr [rsp + 0x54], eax  ; W"赈漅⽂䠀䒉〤읈⑄("
  00027e36:  488d8424280b0000            lea      rax, [rsp + 0xb28]
  00027e3e:  4889442428                  mov      qword ptr [rsp + 0x28], rax
  00027e43:  488b8424200b0000            mov      rax, qword ptr [rsp + 0xb20]
  00027e4b:  4889442420                  mov      qword ptr [rsp + 0x20], rax
  00027e50:  448b4c2458                  mov      r9d, dword ptr [rsp + 0x58]
  00027e55:  4c8b442468                  mov      r8, qword ptr [rsp + 0x68]
  00027e5a:  8b542454                    mov      edx, dword ptr [rsp + 0x54]
  00027e5e:  488b8c24400b0000            mov      rcx, qword ptr [rsp + 0xb40]  ; W"䠸֍⡢/襈⑄䠰䓇⠤"
  00027e66:  e8dd250000                  call     0x2a448  ; fn_0x2a448
  00027e6b:  89442450                    mov      dword ptr [rsp + 0x50], eax
  00027e6f:  8b8424280b0000              mov      eax, dword ptr [rsp + 0xb28]  ; W"㗨Ј褀⑄䠸֍⡢/襈⑄䠰䓇⠤"
  00027e76:  89442448                    mov      dword ptr [rsp + 0x48], eax
  00027e7a:  8b442454                    mov      eax, dword ptr [rsp + 0x54]
  00027e7e:  89442440                    mov      dword ptr [rsp + 0x40], eax
  00027e82:  8b442450                    mov      eax, dword ptr [rsp + 0x50]
  00027e86:  89442438                    mov      dword ptr [rsp + 0x38], eax
  00027e8a:  488d056f422f00              lea      rax, [rip + 0x2f426f]  ; W"unseal return 0x%x length before %d, length after:%d"
  00027e91:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"粃値ༀ螄"
  00027e96:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00027e9f:  c7442420210b0000            mov      dword ptr [rsp + 0x20], 0xb21
  00027ea7:  4c8d0d62412f00              lea      r9, [rip + 0x2f4162]  ; W"production_get_host_psk_data"
  00027eae:  4c8d050b002f00              lea      r8, [rip + 0x2f000b]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027eb5:  ba08000000                  mov      edx, 8
  00027eba:  488b0dc7015100              mov      rcx, qword ptr [rip + 0x5101c7]
  00027ec1:  e8b6e1fdff                  call     0x607c  ; fn_0x607c
  00027ec6:  837c245000                  cmp      dword ptr [rsp + 0x50], 0  ; W"֍䉏/襈⑄䠰䓇⠤"
  00027ecb:  0f8487000000                je       0x27f58
  00027ed1:  8b442450                    mov      eax, dword ptr [rsp + 0x50]
  00027ed5:  89442438                    mov      dword ptr [rsp + 0x38], eax  ; W"诿⑄襐⑄䠸֍䉏/襈⑄䠰䓇⠤"
  00027ed9:  488d0590422f00              lea      rax, [rip + 0x2f4290]  ; W"fail to unseal file data %d"
  00027ee0:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"襐⑄䠸֍䉏/襈⑄䠰䓇⠤"
  00027ee5:  c7442428090d0000            mov      dword ptr [rsp + 0x28], 0xd09  ; W"襐⑄䠸֍䉏/襈⑄䠰䓇⠤"
  00027eed:  c7442420240b0000            mov      dword ptr [rsp + 0x20], 0xb24  ; W"襐⑄䠸֍䉏/襈⑄䠰䓇⠤"
  00027ef5:  4c8d0d14412f00              lea      r9, [rip + 0x2f4114]  ; W"production_get_host_psk_data"
  00027efc:  4c8d05bdff2e00              lea      r8, [rip + 0x2effbd]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027f03:  ba03000000                  mov      edx, 3
  00027f08:  b909000000                  mov      ecx, 9
  00027f0d:  e83a10feff                  call     0x8f4c  ; fn_0x8f4c
  00027f12:  8b442450                    mov      eax, dword ptr [rsp + 0x50]
  00027f16:  89442438                    mov      dword ptr [rsp + 0x38], eax
  00027f1a:  488d054f422f00              lea      rax, [rip + 0x2f424f]  ; W"fail to unseal file data %d"
  00027f21:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00027f26:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00027f2f:  c7442420250b0000            mov      dword ptr [rsp + 0x20], 0xb25
  00027f37:  4c8d0dd2402f00              lea      r9, [rip + 0x2f40d2]  ; W"production_get_host_psk_data"
  00027f3e:  4c8d057bff2e00              lea      r8, [rip + 0x2eff7b]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027f45:  ba04000000                  mov      edx, 4
  00027f4a:  488b0d37015100              mov      rcx, qword ptr [rip + 0x510137]
  00027f51:  e826e1fdff                  call     0x607c  ; fn_0x607c
  00027f56:  eb1e                        jmp      0x27f76
  00027f58:  488b8424500b0000            mov      rax, qword ptr [rsp + 0xb50]
  00027f60:  c60001                      mov      byte ptr [rax], 1
  00027f63:  488b8424480b0000            mov      rax, qword ptr [rsp + 0xb48]  ; W"䒉〤읈⑄("
  00027f6b:  8b4c2460                    mov      ecx, dword ptr [rsp + 0x60]
  00027f6f:  8908                        mov      dword ptr [rax], ecx
  00027f71:  e94b020000                  jmp      0x281c1
  00027f76:  488b8424480b0000            mov      rax, qword ptr [rsp + 0xb48]
  00027f7e:  8b00                        mov      eax, dword ptr [rax]
  00027f80:  89442454                    mov      dword ptr [rsp + 0x54], eax
  00027f84:  4c8d442454                  lea      r8, [rsp + 0x54]
  00027f89:  488b9424400b0000            mov      rdx, qword ptr [rsp + 0xb40]
  00027f91:  b9020001bb                  mov      ecx, 0xbb010002
  00027f96:  e8850f0000                  call     0x28f20  ; fn_0x28f20
  00027f9b:  89442450                    mov      dword ptr [rsp + 0x50], eax  ; W"琀䡁֍䇿/襈⑄䠰䓇⠤"
  00027f9f:  8b442454                    mov      eax, dword ptr [rsp + 0x54]  ; W"/襈⑄䠰䓇⠤"
  00027fa3:  89442440                    mov      dword ptr [rsp + 0x40], eax
  00027fa7:  8b442450                    mov      eax, dword ptr [rsp + 0x50]  ; W"⑄䠰䓇⠤"
  00027fab:  89442438                    mov      dword ptr [rsp + 0x38], eax
  00027faf:  488d05fa412f00              lea      rax, [rip + 0x2f41fa]  ; W"get from mcu, return 0x%x, len %d"
  00027fb6:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"粃値琀䡁֍䇿/襈⑄䠰䓇⠤"
  00027fbb:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0  ; W"⑼P䅴赈％⽁䠀䒉〤읈⑄("
  00027fc4:  c7442420330b0000            mov      dword ptr [rsp + 0x20], 0xb33  ; W"⑼P䅴赈％⽁䠀䒉〤읈⑄("
  00027fcc:  4c8d0d3d402f00              lea      r9, [rip + 0x2f403d]  ; W"production_get_host_psk_data"
  00027fd3:  4c8d05e6fe2e00              lea      r8, [rip + 0x2efee6]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027fda:  ba08000000                  mov      edx, 8
  00027fdf:  488b0da2005100              mov      rcx, qword ptr [rip + 0x5100a2]
  00027fe6:  e891e0fdff                  call     0x607c  ; fn_0x607c
  00027feb:  837c245000                  cmp      dword ptr [rsp + 0x50], 0
  00027ff0:  7441                        je       0x28033
  00027ff2:  488d05ff412f00              lea      rax, [rip + 0x2f41ff]  ; W"get from mcu ERROR"
  00027ff9:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00027ffe:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00028007:  c7442420360b0000            mov      dword ptr [rsp + 0x20], 0xb36
  0002800f:  4c8d0dfa3f2f00              lea      r9, [rip + 0x2f3ffa]  ; W"production_get_host_psk_data"
  00028016:  4c8d05a3fe2e00              lea      r8, [rip + 0x2efea3]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  0002801d:  ba04000000                  mov      edx, 4
  00028022:  488b0d5f005100              mov      rcx, qword ptr [rip + 0x51005f]
  00028029:  e84ee0fdff                  call     0x607c  ; fn_0x607c
  0002802e:  e9a7030000                  jmp      0x283da
  00028033:  488b8424480b0000            mov      rax, qword ptr [rsp + 0xb48]
  0002803b:  8b4c2454                    mov      ecx, dword ptr [rsp + 0x54]
  0002803f:  8908                        mov      dword ptr [rax], ecx
  00028041:  c744245880000000            mov      dword ptr [rsp + 0x58], 0x80
  00028049:  8b442454                    mov      eax, dword ptr [rsp + 0x54]
  0002804d:  488b8c24400b0000            mov      rcx, qword ptr [rsp + 0xb40]
  00028055:  488d4401f8                  lea      rax, [rcx + rax - 8]
  0002805a:  41b908000000                mov      r9d, 8
  00028060:  4c8bc0                      mov      r8, rax
  00028063:  488d542458                  lea      rdx, [rsp + 0x58]
  00028068:  488d8c2480020000            lea      rcx, [rsp + 0x280]
  00028070:  e86befffff                  call     0x26fe0  ; fn_0x26fe0
  00028075:  89442450                    mov      dword ptr [rsp + 0x50], eax
  00028079:  837c245000                  cmp      dword ptr [rsp + 0x50], 0
  0002807e:  7449                        je       0x280c9
  00028080:  8b442450                    mov      eax, dword ptr [rsp + 0x50]
  00028084:  89442438                    mov      dword ptr [rsp + 0x38], eax
  00028088:  488d0521402f00              lea      rax, [rip + 0x2f4021]  ; W"generate entropy failed with 0x%x"
  0002808f:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00028094:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002809d:  c7442420460b0000            mov      dword ptr [rsp + 0x20], 0xb46
  000280a5:  4c8d0d643f2f00              lea      r9, [rip + 0x2f3f64]  ; W"production_get_host_psk_data"
  000280ac:  4c8d050dfe2e00              lea      r8, [rip + 0x2efe0d]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000280b3:  ba04000000                  mov      edx, 4
  000280b8:  488b0dc9ff5000              mov      rcx, qword ptr [rip + 0x50ffc9]
  000280bf:  e8b8dffdff                  call     0x607c  ; fn_0x607c
  000280c4:  e911030000                  jmp      0x283da
  000280c9:  488d842480020000            lea      rax, [rsp + 0x280]
  000280d1:  4889442468                  mov      qword ptr [rsp + 0x68], rax  ; W"⑄䠰䓇⠤"
  000280d6:  8b442454                    mov      eax, dword ptr [rsp + 0x54]  ; W"⑄襐⑄䠸֍㿄/襈⑄䠰䓇⠤"
  000280da:  83e808                      sub      eax, 8
  000280dd:  89442454                    mov      dword ptr [rsp + 0x54], eax  ; W"赈쐅⼿䠀䒉〤읈⑄("
  000280e1:  488d8424280b0000            lea      rax, [rsp + 0xb28]
  000280e9:  4889442428                  mov      qword ptr [rsp + 0x28], rax
  000280ee:  488b8424200b0000            mov      rax, qword ptr [rsp + 0xb20]
  000280f6:  4889442420                  mov      qword ptr [rsp + 0x20], rax
  000280fb:  448b4c2458                  mov      r9d, dword ptr [rsp + 0x58]  ; W"䰀֍ﵠ.ࢺ"
  00028100:  4c8b442468                  mov      r8, qword ptr [rsp + 0x68]  ; W"��粃値琀證⑄襐⑄䠸֍䂙/襈⑄䠰䓇⠤"
  00028105:  8b542454                    mov      edx, dword ptr [rsp + 0x54]
  00028109:  488b8c24400b0000            mov      rcx, qword ptr [rsp + 0xb40]
  00028111:  e832230000                  call     0x2a448  ; fn_0x2a448
  00028116:  89442450                    mov      dword ptr [rsp + 0x50], eax
  0002811a:  8b8424280b0000              mov      eax, dword ptr [rsp + 0xb28]  ; W"䒉〤읈⑄("
  00028121:  89442448                    mov      dword ptr [rsp + 0x48], eax  ; W"��粃値琀證⑄襐⑄䠸֍䂙/襈⑄䠰䓇⠤"
  00028125:  8b442454                    mov      eax, dword ptr [rsp + 0x54]  ; W"⑄䠸֍䂙/襈⑄䠰䓇⠤"
  00028129:  89442440                    mov      dword ptr [rsp + 0x40], eax  ; W"��粃値琀證⑄襐⑄䠸֍䂙/襈⑄䠰䓇⠤"
  0002812d:  8b442450                    mov      eax, dword ptr [rsp + 0x50]  ; W"֍䂙/襈⑄䠰䓇⠤"
  00028131:  89442438                    mov      dword ptr [rsp + 0x38], eax  ; W"��粃値琀證⑄襐⑄䠸֍䂙/襈⑄䠰䓇⠤"
  00028135:  488d05c43f2f00              lea      rax, [rip + 0x2f3fc4]  ; W"unseal return 0x%x length before %d, length after:%d"
  0002813c:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"粃値琀證⑄襐⑄䠸֍䂙/襈⑄䠰䓇⠤"
  00028141:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0  ; W"⑼P䥴䒋値䒉㠤赈餅⽀䠀䒉〤읈⑄("
  0002814a:  c7442420530b0000            mov      dword ptr [rsp + 0x20], 0xb53  ; W"⑼P䥴䒋値䒉㠤赈餅⽀䠀䒉〤읈⑄("
  00028152:  4c8d0db73e2f00              lea      r9, [rip + 0x2f3eb7]  ; W"production_get_host_psk_data"
  00028159:  4c8d0560fd2e00              lea      r8, [rip + 0x2efd60]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00028160:  ba08000000                  mov      edx, 8
  00028165:  488b0d1cff5000              mov      rcx, qword ptr [rip + 0x50ff1c]
  0002816c:  e80bdffdff                  call     0x607c  ; fn_0x607c
  00028171:  837c245000                  cmp      dword ptr [rsp + 0x50], 0  ; W"/襈⑄䠰䓇⠤"
  00028176:  7449                        je       0x281c1
  00028178:  8b442450                    mov      eax, dword ptr [rsp + 0x50]
  0002817c:  89442438                    mov      dword ptr [rsp + 0x38], eax
  00028180:  488d0599402f00              lea      rax, [rip + 0x2f4099]  ; W"unseal return 0x%x"
  00028187:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002818c:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00028195:  c7442420570b0000            mov      dword ptr [rsp + 0x20], 0xb57
  0002819d:  4c8d0d6c3e2f00              lea      r9, [rip + 0x2f3e6c]  ; W"production_get_host_psk_data"
  000281a4:  4c8d0515fd2e00              lea      r8, [rip + 0x2efd15]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000281ab:  ba04000000                  mov      edx, 4
  000281b0:  488b0dd1fe5000              mov      rcx, qword ptr [rip + 0x50fed1]
  000281b7:  e8c0defdff                  call     0x607c  ; fn_0x607c
  000281bc:  e919020000                  jmp      0x283da
  000281c1:  488d0580402f00              lea      rax, [rip + 0x2f4080]  ; W".wb data "
  000281c8:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  000281cd:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0  ; W"䲍尤赌⒄̀"
  000281d6:  c7442420610b0000            mov      dword ptr [rsp + 0x20], 0xb61  ; W"䲍尤赌⒄̀"
  000281de:  4c8d0d2b3e2f00              lea      r9, [rip + 0x2f3e2b]  ; W"production_get_host_psk_data"
  000281e5:  4c8d05d4fc2e00              lea      r8, [rip + 0x2efcd4]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000281ec:  ba08000000                  mov      edx, 8
  000281f1:  488b0d90fe5000              mov      rcx, qword ptr [rip + 0x50fe90]
  000281f8:  e87fdefdff                  call     0x607c  ; fn_0x607c
  000281fd:  4c8d4c245c                  lea      r9, [rsp + 0x5c]  ; W"⼽䰀֍ﱘ.ࢺ"
  00028202:  4c8d842400030000            lea      r8, [rsp + 0x300]
  0002820a:  8b9424280b0000              mov      edx, dword ptr [rsp + 0xb28]
  00028211:  488b8c24200b0000            mov      rcx, qword ptr [rsp + 0xb20]
  00028219:  e89293fdff                  call     0x15b0  ; fn_0x15b0
  0002821e:  89442450                    mov      dword ptr [rsp + 0x50], eax
  00028222:  8b44245c                    mov      eax, dword ptr [rsp + 0x5c]  ; W"値俨Џ褀⑄䠸֍䀴/襈⑄䠰䓇⠤"
  00028226:  89442448                    mov      dword ptr [rsp + 0x48], eax
  0002822a:  8b8424280b0000              mov      eax, dword ptr [rsp + 0xb28]  ; W"䐹吤ݷ粃吤省䡟蒋蠤"
  00028231:  89442440                    mov      dword ptr [rsp + 0x40], eax
  00028235:  8b442450                    mov      eax, dword ptr [rsp + 0x50]  ; W"䒉㠤赈㐅⽀䠀䒉〤읈⑄("
  00028239:  89442438                    mov      dword ptr [rsp + 0x38], eax
  0002823d:  488d051c402f00              lea      rax, [rip + 0x2f401c]  ; W"wb return 0x%x length before %d, length after:%d "
  00028244:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00028249:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0  ; W"⑼P乴䲋値俨Џ褀⑄䠸֍䀴/襈⑄䠰䓇⠤"
  00028252:  c7442420630b0000            mov      dword ptr [rsp + 0x20], 0xb63  ; W"⑼P乴䲋値俨Џ褀⑄䠸֍䀴/襈⑄䠰䓇⠤"
  0002825a:  4c8d0daf3d2f00              lea      r9, [rip + 0x2f3daf]  ; W"production_get_host_psk_data"
  00028261:  4c8d0558fc2e00              lea      r8, [rip + 0x2efc58]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00028268:  ba08000000                  mov      edx, 8
  0002826d:  488b0d14fe5000              mov      rcx, qword ptr [rip + 0x50fe14]
  00028274:  e803defdff                  call     0x607c  ; fn_0x607c
  00028279:  837c245000                  cmp      dword ptr [rsp + 0x50], 0  ; W"赈⌅⽀䠀䒉〤읈⑄("
  0002827e:  744e                        je       0x282ce
  00028280:  8b4c2450                    mov      ecx, dword ptr [rsp + 0x50]  ; W"䠀䒉〤읈⑄("
  00028284:  e84f0f0400                  call     0x691d8  ; fn_0x691d8
  00028289:  89442438                    mov      dword ptr [rsp + 0x38], eax
  0002828d:  488d0534402f00              lea      rax, [rip + 0x2f4034]  ; W"wb failed with 0x%x."
  00028294:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00028299:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000282a2:  c7442420670b0000            mov      dword ptr [rsp + 0x20], 0xb67
  000282aa:  4c8d0d5f3d2f00              lea      r9, [rip + 0x2f3d5f]  ; W"production_get_host_psk_data"
  000282b1:  4c8d0508fc2e00              lea      r8, [rip + 0x2efc08]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000282b8:  ba04000000                  mov      edx, 4
  000282bd:  488b0dc4fd5000              mov      rcx, qword ptr [rip + 0x50fdc4]
  000282c4:  e8b3ddfdff                  call     0x607c  ; fn_0x607c
  000282c9:  e90c010000                  jmp      0x283da
  000282ce:  488d0523402f00              lea      rax, [rip + 0x2f4023]  ; W".hash"
  000282d5:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"䒋尤譌⒄ର"
  000282da:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000282e3:  c74424206c0b0000            mov      dword ptr [rsp + 0x20], 0xb6c
  000282eb:  4c8d0d1e3d2f00              lea      r9, [rip + 0x2f3d1e]  ; W"production_get_host_psk_data"
  000282f2:  4c8d05c7fb2e00              lea      r8, [rip + 0x2efbc7]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000282f9:  ba08000000                  mov      edx, 8
  000282fe:  488b0d83fd5000              mov      rcx, qword ptr [rip + 0x50fd83]
  00028305:  e872ddfdff                  call     0x607c  ; fn_0x607c
  0002830a:  8b44245c                    mov      eax, dword ptr [rsp + 0x5c]
  0002830e:  4c8b8424300b0000            mov      r8, qword ptr [rsp + 0xb30]  ; W"吤䒉㠤赈�⼮䠀䒉〤읈⑄("
  00028316:  8bd0                        mov      edx, eax
  00028318:  488d8c2400030000            lea      rcx, [rsp + 0x300]
  00028320:  e80b99fdff                  call     0x1c30  ; fn_0x1c30
  00028325:  89442450                    mov      dword ptr [rsp + 0x50], eax
  00028329:  8b8424380b0000              mov      eax, dword ptr [rsp + 0xb38]
  00028330:  89442448                    mov      dword ptr [rsp + 0x48], eax
  00028334:  8b44245c                    mov      eax, dword ptr [rsp + 0x5c]  ; W"赈�⼿䠀䒉〤읈⑄("
  00028338:  89442440                    mov      dword ptr [rsp + 0x40], eax
  0002833c:  8b442450                    mov      eax, dword ptr [rsp + 0x50]  ; W"䒉㠤赈�⼿䠀䒉〤읈⑄("
  00028340:  89442438                    mov      dword ptr [rsp + 0x38], eax
  00028344:  488d05c53f2f00              lea      rax, [rip + 0x2f3fc5]  ; W"hash return 0x%x length before %d, length after:%d"
  0002834b:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00028350:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0  ; W"⑼P䭴䲋値䣨Ў褀⑄䠸֍㿝/襈⑄䠰䓇⠤"