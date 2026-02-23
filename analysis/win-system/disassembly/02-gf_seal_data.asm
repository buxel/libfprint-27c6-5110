; gfspi.dll - gf_seal_data function
; Source: d:\project\winfpcode\...\gf_win_crypt_helper.c
; Wraps CryptProtectData with CRYPTPROTECT_LOCAL_MACHINE flag (0x4)
; Signature: gf_seal_data(inbuf, inbuf_len, entropy, entropy_len, outbuf, outbuf_len)
; Logs: 'inbuf_len %d, entropy_len %d, len_out %d'
; 'This is the description string.' passed as szDataDescr
; Image base: 0x180000000
; String 'gf_seal_data' at RVA 0x31c860
; XREFs: ['0x2a19e', '0x2a229', '0x2a315', '0x2a361', '0x2a416']
; Function start: RVA 0x2a13c
; Function end: RVA 0x2a456

  0002a13c:  44894c2420                  mov      dword ptr [rsp + 0x20], r9d
  0002a141:  4c89442418                  mov      qword ptr [rsp + 0x18], r8  ; W"琀䠠벃쀤"
  0002a146:  89542410                    mov      dword ptr [rsp + 0x10], edx
  0002a14a:  48894c2408                  mov      qword ptr [rsp + 8], rcx
  0002a14f:  4881ec98000000              sub      rsp, 0x98
  0002a156:  4883bc24a000000000          cmp      qword ptr [rsp + 0xa0], 0
  0002a15f:  7420                        je       0x2a181
  0002a161:  4883bc24c000000000          cmp      qword ptr [rsp + 0xc0], 0
  0002a16a:  7415                        je       0x2a181
  0002a16c:  4883bc24c800000000          cmp      qword ptr [rsp + 0xc8], 0  ; W"උ�P㓨ﶾ䣿蒋ꀤ"
  0002a175:  740a                        je       0x2a181
  0002a177:  83bc24a800000000            cmp      dword ptr [rsp + 0xa8], 0
  0002a17f:  7746                        ja       0x2a1c7
  0002a181:  488d05c8f60400              lea      rax, [rip + 0x4f6c8]  ; W"wrong input"
  0002a188:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002a18d:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002a196:  c744242018000000            mov      dword ptr [rsp + 0x20], 0x18
  0002a19e:  4c8d0dbb262f00              lea      r9, [rip + 0x2f26bb]  ; W"gf_seal_data"
  0002a1a5:  4c8d05d4262f00              lea      r8, [rip + 0x2f26d4]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_win_cr"
  0002a1ac:  ba04000000                  mov      edx, 4
  0002a1b1:  488b0dd0de5000              mov      rcx, qword ptr [rip + 0x50ded0]
  0002a1b8:  e8bfbefdff                  call     0x607c  ; fn_0x607c
  0002a1bd:  b801000000                  mov      eax, 1
  0002a1c2:  e977020000                  jmp      0x2a43e
  0002a1c7:  83bc24b800000000            cmp      dword ptr [rsp + 0xb8], 0  ; W"褀⑄䡸벃뀤"
  0002a1cf:  7717                        ja       0x2a1e8
  0002a1d1:  48c78424b000000000000000    mov      qword ptr [rsp + 0xb0], 0
  0002a1dd:  c78424b800000000000000      mov      dword ptr [rsp + 0xb8], 0
  0002a1e8:  488b8424c8000000            mov      rax, qword ptr [rsp + 0xc8]
  0002a1f0:  8b00                        mov      eax, dword ptr [rax]
  0002a1f2:  89442448                    mov      dword ptr [rsp + 0x48], eax
  0002a1f6:  8b8424b8000000              mov      eax, dword ptr [rsp + 0xb8]
  0002a1fd:  89442440                    mov      dword ptr [rsp + 0x40], eax  ; W"P㓨ﶾ䣿蒋ꀤ"
  0002a201:  8b8424a8000000              mov      eax, dword ptr [rsp + 0xa8]
  0002a208:  89442438                    mov      dword ptr [rsp + 0x38], eax
  0002a20c:  488d051d272f00              lea      rax, [rip + 0x2f271d]  ; W"inbuf_len %d, entropy_len %d, len_out %d"
  0002a213:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002a218:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002a221:  c744242022000000            mov      dword ptr [rsp + 0x20], 0x22
  0002a229:  4c8d0d30262f00              lea      r9, [rip + 0x2f2630]  ; W"gf_seal_data"
  0002a230:  4c8d0549262f00              lea      r8, [rip + 0x2f2649]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_win_cr"
  0002a237:  ba07000000                  mov      edx, 7
  0002a23c:  488b0d45de5000              mov      rcx, qword ptr [rip + 0x50de45]
  0002a243:  e834befdff                  call     0x607c  ; fn_0x607c
  0002a248:  488b8424a0000000            mov      rax, qword ptr [rsp + 0xa0]  ; W"䒋栤䒉㠤赈턅⼦䠀䒉〤읈⑄("
  0002a250:  4889442470                  mov      qword ptr [rsp + 0x70], rax
  0002a255:  8b8424a8000000              mov      eax, dword ptr [rsp + 0xa8]
  0002a25c:  89442468                    mov      dword ptr [rsp + 0x68], eax
  0002a260:  c744245800000000            mov      dword ptr [rsp + 0x58], 0
  0002a268:  48c744246000000000          mov      qword ptr [rsp + 0x60], 0  ; W"먕⼦䠀䲍栤㋨̅蔀࿀ﮄ"
  0002a271:  488b8424b0000000            mov      rax, qword ptr [rsp + 0xb0]  ; W"උ�P䣨ﶽ䣿蒋젤"
  0002a279:  4889842480000000            mov      qword ptr [rsp + 0x80], rax  ; W"⑄䠰䓇⠤"
  0002a281:  8b8424b8000000              mov      eax, dword ptr [rsp + 0xb8]  ; W"࠹彳赈픅⼦䠀䒉〤읈⑄("
  0002a288:  89442478                    mov      dword ptr [rsp + 0x78], eax
  0002a28c:  4883bc24b000000000          cmp      qword ptr [rsp + 0xb0], 0  ; W"֍⛕/襈⑄䠰䓇⠤"
  0002a295:  750b                        jne      0x2a2a2
  0002a297:  48c744245000000000          mov      qword ptr [rsp + 0x50], 0  ; W"䒋栤䒉㠤赈턅⼦䠀䒉〤읈⑄("
  0002a2a0:  eb0a                        jmp      0x2a2ac
  0002a2a2:  488d442478                  lea      rax, [rsp + 0x78]
  0002a2a7:  4889442450                  mov      qword ptr [rsp + 0x50], rax  ; W"⼦䠀䒉〤읈⑄("
  0002a2ac:  488d442458                  lea      rax, [rsp + 0x58]
  0002a2b1:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002a2b6:  c744242804000000            mov      dword ptr [rsp + 0x28], 4
  0002a2be:  48c744242000000000          mov      qword ptr [rsp + 0x20], 0  ; W"謀⑄襘⑄譀⑄襨⑄䠸֍⛑/襈⑄䠰䓇⠤"
  0002a2c7:  4533c9                      xor      r9d, r9d
  0002a2ca:  4c8b442450                  mov      r8, qword ptr [rsp + 0x50]
  0002a2cf:  488d15ba262f00              lea      rdx, [rip + 0x2f26ba]  ; W"This is the description string."
  0002a2d6:  488d4c2468                  lea      rcx, [rsp + 0x68]  ; W"䡟֍⛕/襈⑄䠰䓇⠤"
  0002a2db:  e832050300                  call     0x5a812  ; fn_0x5a812
  0002a2e0:  85c0                        test     eax, eax
  0002a2e2:  0f84fb000000                je       0x2a3e3
  0002a2e8:  8b442458                    mov      eax, dword ptr [rsp + 0x58]  ; W"赈픅⼦䠀䒉〤읈⑄("
  0002a2ec:  89442440                    mov      dword ptr [rsp + 0x40], eax  ; W"뵈�譈⒄È"
  0002a2f0:  8b442468                    mov      eax, dword ptr [rsp + 0x68]
  0002a2f4:  89442438                    mov      dword ptr [rsp + 0x38], eax  ; W"뵈�譈⒄È"
  0002a2f8:  488d05d1262f00              lea      rax, [rip + 0x2f26d1]  ; W"The encryption phase worked, %d, %d"
  0002a2ff:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002a304:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002a30d:  c744242042000000            mov      dword ptr [rsp + 0x20], 0x42
  0002a315:  4c8d0d44252f00              lea      r9, [rip + 0x2f2544]  ; W"gf_seal_data"
  0002a31c:  4c8d055d252f00              lea      r8, [rip + 0x2f255d]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_win_cr"
  0002a323:  ba08000000                  mov      edx, 8
  0002a328:  488b0d59dd5000              mov      rcx, qword ptr [rip + 0x50dd59]
  0002a32f:  e848bdfdff                  call     0x607c  ; fn_0x607c
  0002a334:  488b8424c8000000            mov      rax, qword ptr [rsp + 0xc8]
  0002a33c:  8b4c2458                    mov      ecx, dword ptr [rsp + 0x58]
  0002a340:  3908                        cmp      dword ptr [rax], ecx
  0002a342:  735f                        jae      0x2a3a3
  0002a344:  488d05d5262f00              lea      rax, [rip + 0x2f26d5]  ; W"Buffer for encrypted data is not big enough"
  0002a34b:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002a350:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002a359:  c744242045000000            mov      dword ptr [rsp + 0x20], 0x45
  0002a361:  4c8d0df8242f00              lea      r9, [rip + 0x2f24f8]  ; W"gf_seal_data"
  0002a368:  4c8d0511252f00              lea      r8, [rip + 0x2f2511]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_win_cr"
  0002a36f:  ba04000000                  mov      edx, 4
  0002a374:  488b0d0ddd5000              mov      rcx, qword ptr [rip + 0x50dd0d]
  0002a37b:  e8fcbcfdff                  call     0x607c  ; fn_0x607c
  0002a380:  488b8424c8000000            mov      rax, qword ptr [rsp + 0xc8]
  0002a388:  8b4c2458                    mov      ecx, dword ptr [rsp + 0x58]
  0002a38c:  8908                        mov      dword ptr [rax], ecx
  0002a38e:  488b4c2460                  mov      rcx, qword ptr [rsp + 0x60]
  0002a393:  ff15cfed0400                call     qword ptr [rip + 0x4edcf]
  0002a399:  b802000000                  mov      eax, 2
  0002a39e:  e99b000000                  jmp      0x2a43e
  0002a3a3:  8b442458                    mov      eax, dword ptr [rsp + 0x58]  ; W"䠀䒉〤읈⑄("
  0002a3a7:  488b8c24c8000000            mov      rcx, qword ptr [rsp + 0xc8]
  0002a3af:  8b09                        mov      ecx, dword ptr [rcx]
  0002a3b1:  448bc8                      mov      r9d, eax
  0002a3b4:  4c8b442460                  mov      r8, qword ptr [rsp + 0x60]
  0002a3b9:  8bd1                        mov      edx, ecx
  0002a3bb:  488b8c24c0000000            mov      rcx, qword ptr [rsp + 0xc0]
  0002a3c3:  e898030000                  call     0x2a760  ; fn_0x2a760
  0002a3c8:  488b8424c8000000            mov      rax, qword ptr [rsp + 0xc8]
  0002a3d0:  8b4c2458                    mov      ecx, dword ptr [rsp + 0x58]
  0002a3d4:  8908                        mov      dword ptr [rax], ecx
  0002a3d6:  488b4c2460                  mov      rcx, qword ptr [rsp + 0x60]
  0002a3db:  ff1587ed0400                call     qword ptr [rip + 0x4ed87]
  0002a3e1:  eb59                        jmp      0x2a43c
  0002a3e3:  ff15a7ec0400                call     qword ptr [rip + 0x4eca7]
  0002a3e9:  89442440                    mov      dword ptr [rsp + 0x40], eax
  0002a3ed:  488d0584262f00              lea      rax, [rip + 0x2f2684]  ; W"CryptProtectData"
  0002a3f4:  4889442438                  mov      qword ptr [rsp + 0x38], rax
  0002a3f9:  488d05f0c20900              lea      rax, [rip + 0x9c2f0]  ; W"!!!!%s failed, error: 0x%x"
  0002a400:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002a405:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002a40e:  c744242050000000            mov      dword ptr [rsp + 0x20], 0x50
  0002a416:  4c8d0d43242f00              lea      r9, [rip + 0x2f2443]  ; W"gf_seal_data"
  0002a41d:  4c8d055c242f00              lea      r8, [rip + 0x2f245c]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_win_cr"
  0002a424:  ba04000000                  mov      edx, 4
  0002a429:  488b0d58dc5000              mov      rcx, qword ptr [rip + 0x50dc58]
  0002a430:  e847bcfdff                  call     0x607c  ; fn_0x607c
  0002a435:  b803000000                  mov      eax, 3
  0002a43a:  eb02                        jmp      0x2a43e
  0002a43c:  33c0                        xor      eax, eax
  0002a43e:  4881c498000000              add      rsp, 0x98
  0002a445:  c3                          ret      
  0002a446:  cc                          int3     

; --- function boundary ---

  0002a447:  cc                          int3     
  0002a448:  44894c2420                  mov      dword ptr [rsp + 0x20], r9d
  0002a44d:  4c89442418                  mov      qword ptr [rsp + 0x18], r8  ; W"琀䠠벃쀤"
  0002a452:  89542410                    mov      dword ptr [rsp + 0x10], edx