; gfspi.dll - gf_unseal_data function
; Source: gf_win_crypt_helper.c
; Wraps CryptUnprotectData
; Image base: 0x180000000
; String 'gf_unseal_data' at RVA 0x31caa0
; XREFs: ['0x2a4aa', '0x2a535', '0x2a62e', '0x2a67a', '0x2a72f']
; Function start: RVA 0x2a448
; Function end: RVA 0x2a76f

  0002a448:  44894c2420                  mov      dword ptr [rsp + 0x20], r9d
  0002a44d:  4c89442418                  mov      qword ptr [rsp + 0x18], r8  ; W"琀䠠벃쀤"
  0002a452:  89542410                    mov      dword ptr [rsp + 0x10], edx
  0002a456:  48894c2408                  mov      qword ptr [rsp + 8], rcx
  0002a45b:  4881ec98000000              sub      rsp, 0x98
  0002a462:  4883bc24a000000000          cmp      qword ptr [rsp + 0xa0], 0
  0002a46b:  7420                        je       0x2a48d
  0002a46d:  4883bc24c000000000          cmp      qword ptr [rsp + 0xc0], 0
  0002a476:  7415                        je       0x2a48d
  0002a478:  4883bc24c800000000          cmp      qword ptr [rsp + 0xc8], 0  ; W"උ�P⣨ﶻ䣿蒋ꀤ"
  0002a481:  740a                        je       0x2a48d
  0002a483:  83bc24a800000000            cmp      dword ptr [rsp + 0xa8], 0
  0002a48b:  7746                        ja       0x2a4d3
  0002a48d:  488d05bcf30400              lea      rax, [rip + 0x4f3bc]  ; W"wrong input"
  0002a494:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002a499:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002a4a2:  c74424205c000000            mov      dword ptr [rsp + 0x20], 0x5c
  0002a4aa:  4c8d0def252f00              lea      r9, [rip + 0x2f25ef]  ; W"gf_unseal_data"
  0002a4b1:  4c8d05c8232f00              lea      r8, [rip + 0x2f23c8]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_win_cr"
  0002a4b8:  ba04000000                  mov      edx, 4
  0002a4bd:  488b0dc4db5000              mov      rcx, qword ptr [rip + 0x50dbc4]
  0002a4c4:  e8b3bbfdff                  call     0x607c  ; fn_0x607c
  0002a4c9:  b801000000                  mov      eax, 1
  0002a4ce:  e984020000                  jmp      0x2a757
  0002a4d3:  83bc24b800000000            cmp      dword ptr [rsp + 0xb8], 0
  0002a4db:  7717                        ja       0x2a4f4
  0002a4dd:  48c78424b000000000000000    mov      qword ptr [rsp + 0xb0], 0
  0002a4e9:  c78424b800000000000000      mov      dword ptr [rsp + 0xb8], 0  ; W"甀䠋䓇値"
  0002a4f4:  488b8424c8000000            mov      rax, qword ptr [rsp + 0xc8]  ; W"⑄䡐䒍怤襈⑄윰⑄("
  0002a4fc:  8b00                        mov      eax, dword ptr [rax]
  0002a4fe:  89442448                    mov      dword ptr [rsp + 0x48], eax
  0002a502:  8b8424b8000000              mov      eax, dword ptr [rsp + 0xb8]  ; W"䠀䒉値赈⑄䡠䒉〤䓇⠤"
  0002a509:  89442440                    mov      dword ptr [rsp + 0x40], eax  ; W"P⣨ﶻ䣿蒋ꀤ"
  0002a50d:  8b8424a8000000              mov      eax, dword ptr [rsp + 0xa8]
  0002a514:  89442438                    mov      dword ptr [rsp + 0x38], eax
  0002a518:  488d0511242f00              lea      rax, [rip + 0x2f2411]  ; W"inbuf_len %d, entropy_len %d, len_out %d"
  0002a51f:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002a524:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002a52d:  c744242066000000            mov      dword ptr [rsp + 0x20], 0x66
  0002a535:  4c8d0d64252f00              lea      r9, [rip + 0x2f2564]  ; W"gf_unseal_data"
  0002a53c:  4c8d053d232f00              lea      r8, [rip + 0x2f233d]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_win_cr"
  0002a543:  ba07000000                  mov      edx, 7
  0002a548:  488b0d39db5000              mov      rcx, qword ptr [rip + 0x50db39]
  0002a54f:  e828bbfdff                  call     0x607c  ; fn_0x607c
  0002a554:  488b8424a0000000            mov      rax, qword ptr [rsp + 0xa0]
  0002a55c:  4889442478                  mov      qword ptr [rsp + 0x78], rax
  0002a561:  8b8424a8000000              mov      eax, dword ptr [rsp + 0xa8]  ; W"䠸֍⒨/襈⑄䠰䓇⠤"
  0002a568:  89442470                    mov      dword ptr [rsp + 0x70], eax
  0002a56c:  48c744246800000000          mov      qword ptr [rsp + 0x68], 0
  0002a575:  c744246000000000            mov      dword ptr [rsp + 0x60], 0
  0002a57d:  488b8424b0000000            mov      rax, qword ptr [rsp + 0xb0]
  0002a585:  4889842488000000            mov      qword ptr [rsp + 0x88], rax  ; W"⼤䠀䒉〤읈⑄("
  0002a58d:  8b8424b8000000              mov      eax, dword ptr [rsp + 0xb8]
  0002a594:  89842480000000              mov      dword ptr [rsp + 0x80], eax  ; W"〤읈⑄("
  0002a59b:  48c744245800000000          mov      qword ptr [rsp + 0x58], 0
  0002a5a4:  4883bc24b000000000          cmp      qword ptr [rsp + 0xb0], 0  ; W"赈갅⼤䠀䒉〤읈⑄("
  0002a5ad:  750b                        jne      0x2a5ba
  0002a5af:  48c744245000000000          mov      qword ptr [rsp + 0x50], 0  ; W"譀⑄襰⑄䠸֍⒨/襈⑄䠰䓇⠤"
  0002a5b8:  eb0d                        jmp      0x2a5c7
  0002a5ba:  488d842480000000            lea      rax, [rsp + 0x80]
  0002a5c2:  4889442450                  mov      qword ptr [rsp + 0x50], rax  ; W"䠀䒉〤읈⑄("
  0002a5c7:  488d442460                  lea      rax, [rsp + 0x60]
  0002a5cc:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"䒋怤䒉䀤䒋瀤䒉㠤赈ꠅ⼤䠀䒉〤읈⑄("
  0002a5d1:  c744242800000000            mov      dword ptr [rsp + 0x28], 0  ; W"䒋怤䒉䀤䒋瀤䒉㠤赈ꠅ⼤䠀䒉〤읈⑄("
  0002a5d9:  48c744242000000000          mov      qword ptr [rsp + 0x20], 0  ; W"⑄襠⑄譀⑄襰⑄䠸֍⒨/襈⑄䠰䓇⠤"
  0002a5e2:  4533c9                      xor      r9d, r9d
  0002a5e5:  4c8b442450                  mov      r8, qword ptr [rsp + 0x50]
  0002a5ea:  488d542458                  lea      rdx, [rsp + 0x58]
  0002a5ef:  488d4c2470                  lea      rcx, [rsp + 0x70]  ; W"襈⑄䠰䓇⠤"
  0002a5f4:  e81f020300                  call     0x5a818  ; fn_0x5a818
  0002a5f9:  85c0                        test     eax, eax
  0002a5fb:  0f84fb000000                je       0x2a6fc
  0002a601:  8b442460                    mov      eax, dword ptr [rsp + 0x60]  ; W"䒉〤읈⑄("
  0002a605:  89442440                    mov      dword ptr [rsp + 0x40], eax  ; W"먯�譈⒄È"
  0002a609:  8b442470                    mov      eax, dword ptr [rsp + 0x70]
  0002a60d:  89442438                    mov      dword ptr [rsp + 0x38], eax  ; W"먯�譈⒄È"
  0002a611:  488d05a8242f00              lea      rax, [rip + 0x2f24a8]  ; W"The decryption phase worked, %d, %d"
  0002a618:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002a61d:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002a626:  c744242081000000            mov      dword ptr [rsp + 0x20], 0x81
  0002a62e:  4c8d0d6b242f00              lea      r9, [rip + 0x2f246b]  ; W"gf_unseal_data"
  0002a635:  4c8d0544222f00              lea      r8, [rip + 0x2f2244]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_win_cr"
  0002a63c:  ba08000000                  mov      edx, 8
  0002a641:  488b0d40da5000              mov      rcx, qword ptr [rip + 0x50da40]
  0002a648:  e82fbafdff                  call     0x607c  ; fn_0x607c
  0002a64d:  488b8424c8000000            mov      rax, qword ptr [rsp + 0xc8]
  0002a655:  8b4c2460                    mov      ecx, dword ptr [rsp + 0x60]
  0002a659:  3908                        cmp      dword ptr [rax], ecx
  0002a65b:  735f                        jae      0x2a6bc
  0002a65d:  488d05ac242f00              lea      rax, [rip + 0x2f24ac]  ; W"Buffer for decrypted data is not big enough"
  0002a664:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002a669:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002a672:  c744242085000000            mov      dword ptr [rsp + 0x20], 0x85
  0002a67a:  4c8d0d1f242f00              lea      r9, [rip + 0x2f241f]  ; W"gf_unseal_data"
  0002a681:  4c8d05f8212f00              lea      r8, [rip + 0x2f21f8]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_win_cr"
  0002a688:  ba04000000                  mov      edx, 4
  0002a68d:  488b0df4d95000              mov      rcx, qword ptr [rip + 0x50d9f4]
  0002a694:  e8e3b9fdff                  call     0x607c  ; fn_0x607c
  0002a699:  488b8424c8000000            mov      rax, qword ptr [rsp + 0xc8]
  0002a6a1:  8b4c2460                    mov      ecx, dword ptr [rsp + 0x60]
  0002a6a5:  8908                        mov      dword ptr [rax], ecx
  0002a6a7:  488b4c2468                  mov      rcx, qword ptr [rsp + 0x68]  ; W"휅ি䠀䒉〤읈⑄("
  0002a6ac:  ff15b6ea0400                call     qword ptr [rip + 0x4eab6]
  0002a6b2:  b802000000                  mov      eax, 2
  0002a6b7:  e99b000000                  jmp      0x2a757
  0002a6bc:  8b442460                    mov      eax, dword ptr [rsp + 0x60]
  0002a6c0:  488b8c24c8000000            mov      rcx, qword ptr [rsp + 0xc8]
  0002a6c8:  8b09                        mov      ecx, dword ptr [rcx]
  0002a6ca:  448bc8                      mov      r9d, eax
  0002a6cd:  4c8b442468                  mov      r8, qword ptr [rsp + 0x68]
  0002a6d2:  8bd1                        mov      edx, ecx
  0002a6d4:  488b8c24c0000000            mov      rcx, qword ptr [rsp + 0xc0]
  0002a6dc:  e87f000000                  call     0x2a760  ; fn_0x2a760
  0002a6e1:  488b8424c8000000            mov      rax, qword ptr [rsp + 0xc8]
  0002a6e9:  8b4c2460                    mov      ecx, dword ptr [rsp + 0x60]
  0002a6ed:  8908                        mov      dword ptr [rax], ecx
  0002a6ef:  488b4c2468                  mov      rcx, qword ptr [rsp + 0x68]
  0002a6f4:  ff156eea0400                call     qword ptr [rip + 0x4ea6e]
  0002a6fa:  eb59                        jmp      0x2a755
  0002a6fc:  ff158ee90400                call     qword ptr [rip + 0x4e98e]
  0002a702:  89442440                    mov      dword ptr [rsp + 0x40], eax
  0002a706:  488d055b242f00              lea      rax, [rip + 0x2f245b]  ; W"CryptUnprotectData"
  0002a70d:  4889442438                  mov      qword ptr [rsp + 0x38], rax
  0002a712:  488d05d7bf0900              lea      rax, [rip + 0x9bfd7]  ; W"!!!!%s failed, error: 0x%x"
  0002a719:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002a71e:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002a727:  c744242090000000            mov      dword ptr [rsp + 0x20], 0x90
  0002a72f:  4c8d0d6a232f00              lea      r9, [rip + 0x2f236a]  ; W"gf_unseal_data"
  0002a736:  4c8d0543212f00              lea      r8, [rip + 0x2f2143]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_win_cr"
  0002a73d:  ba04000000                  mov      edx, 4
  0002a742:  488b0d3fd95000              mov      rcx, qword ptr [rip + 0x50d93f]
  0002a749:  e82eb9fdff                  call     0x607c  ; fn_0x607c
  0002a74e:  b803000000                  mov      eax, 3
  0002a753:  eb02                        jmp      0x2a757
  0002a755:  33c0                        xor      eax, eax
  0002a757:  4881c498000000              add      rsp, 0x98
  0002a75e:  c3                          ret      
  0002a75f:  cc                          int3     
  0002a760:  4c894c2420                  mov      qword ptr [rsp + 0x20], r9
  0002a765:  4c89442418                  mov      qword ptr [rsp + 0x18], r8
  0002a76a:  4889542410                  mov      qword ptr [rsp + 0x10], rdx