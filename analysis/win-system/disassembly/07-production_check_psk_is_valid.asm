; gfspi.dll - production_check_psk_is_valid function
; Compares host PSK hash vs MCU PSK hash
; Image base: 0x180000000
; String 'production_check_psk_is_valid' at RVA 0x31c3c8
; XREFs: ['0x27488', '0x2754a', '0x275f2', '0x27642', '0x27683', '0x276f2', '0x27735', '0x27776', '0x277dd', '0x27818']
; Function start: RVA 0x27450
; Function end: RVA 0x279b1

  00027450:  4057                        push     rdi
  00027452:  4881ec000b0000              sub      rsp, 0xb00
  00027459:  488b05e8245100              mov      rax, qword ptr [rip + 0x5124e8]
  00027460:  4833c4                      xor      rax, rsp
  00027463:  48898424f00a0000            mov      qword ptr [rsp + 0xaf0], rax
  0002746b:  488d057eee0900              lea      rax, [rip + 0x9ee7e]  ; W"entry"
  00027472:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00027477:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00027480:  c7442420800b0000            mov      dword ptr [rsp + 0x20], 0xb80
  00027488:  4c8d0d394f2f00              lea      r9, [rip + 0x2f4f39]  ; W"production_check_psk_is_valid"
  0002748f:  4c8d052a0a2f00              lea      r8, [rip + 0x2f0a2a]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027496:  ba08000000                  mov      edx, 8
  0002749b:  488b0de60b5100              mov      rcx, qword ptr [rip + 0x510be6]
  000274a2:  e8d5ebfdff                  call     0x607c  ; fn_0x607c
  000274a7:  c7442464010000ff            mov      dword ptr [rsp + 0x64], 0xff000001
  000274af:  c644246000                  mov      byte ptr [rsp + 0x60], 0
  000274b4:  48c744247800000000          mov      qword ptr [rsp + 0x78], 0  ; W"䒉〤읈⑄("
  000274bd:  488d8424c8020000            lea      rax, [rsp + 0x2c8]
  000274c5:  488bf8                      mov      rdi, rax
  000274c8:  33c0                        xor      eax, eax
  000274ca:  b920000000                  mov      ecx, 0x20
  000274cf:  f3aa                        rep stosb byte ptr [rdi], al
  000274d1:  c744247020000000            mov      dword ptr [rsp + 0x70], 0x20
  000274d9:  488d8424f0020000            lea      rax, [rsp + 0x2f0]
  000274e1:  488bf8                      mov      rdi, rax
  000274e4:  33c0                        xor      eax, eax
  000274e6:  b900080000                  mov      ecx, 0x800
  000274eb:  f3aa                        rep stosb byte ptr [rdi], al
  000274ed:  c744246c00080000            mov      dword ptr [rsp + 0x6c], 0x800
  000274f5:  488d8424a8020000            lea      rax, [rsp + 0x2a8]
  000274fd:  488bf8                      mov      rdi, rax
  00027500:  33c0                        xor      eax, eax
  00027502:  b920000000                  mov      ecx, 0x20
  00027507:  f3aa                        rep stosb byte ptr [rdi], al
  00027509:  c744247420000000            mov      dword ptr [rsp + 0x74], 0x20  ; W"襈⑄䐠䲋琤赌⒄ʨ"
  00027511:  488d842488020000            lea      rax, [rsp + 0x288]
  00027519:  488bf8                      mov      rdi, rax
  0002751c:  33c0                        xor      eax, eax
  0002751e:  b920000000                  mov      ecx, 0x20
  00027523:  f3aa                        rep stosb byte ptr [rdi], al
  00027525:  c744246820000000            mov      dword ptr [rsp + 0x68], 0x20
  0002752d:  488d05d44e2f00              lea      rax, [rip + 0x2f4ed4]  ; W"1.get host hash"
  00027534:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"赈⑄䡠䒉〤赈⑄䡬䒉⠤赈⒄˰"
  00027539:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00027542:  c7442420930b0000            mov      dword ptr [rsp + 0x20], 0xb93
  0002754a:  4c8d0d774e2f00              lea      r9, [rip + 0x2f4e77]  ; W"production_check_psk_is_valid"
  00027551:  4c8d0568092f00              lea      r8, [rip + 0x2f0968]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027558:  ba08000000                  mov      edx, 8
  0002755d:  488b0d240b5100              mov      rcx, qword ptr [rip + 0x510b24]
  00027564:  e813ebfdff                  call     0x607c  ; fn_0x607c
  00027569:  488d442460                  lea      rax, [rsp + 0x60]  ; W"⑄襤⑄䠸֍乔/襈⑄䠰䓇⠤"
  0002756e:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00027573:  488d44246c                  lea      rax, [rsp + 0x6c]
  00027578:  4889442428                  mov      qword ptr [rsp + 0x28], rax
  0002757d:  488d8424f0020000            lea      rax, [rsp + 0x2f0]
  00027585:  4889442420                  mov      qword ptr [rsp + 0x20], rax  ; W"搤똏⑄襠⑄識⑄襬⑄譐⑄襴⑄譈⑄襰⑄譀⑄襤⑄䠸֍乔/襈⑄䠰䓇⠤"
  0002758a:  448b4c2474                  mov      r9d, dword ptr [rsp + 0x74]
  0002758f:  4c8d8424a8020000            lea      r8, [rsp + 0x2a8]
  00027597:  8b542470                    mov      edx, dword ptr [rsp + 0x70]
  0002759b:  488d8c24c8020000            lea      rcx, [rsp + 0x2c8]
  000275a3:  e8b8050000                  call     0x27b60  ; fn_0x27b60
  000275a8:  89442464                    mov      dword ptr [rsp + 0x64], eax  ; W"菿⑼d乴䲋搤럨Л褀⑄䠸֍五/襈⑄䠰䓇⠤"
  000275ac:  0fb6442460                  movzx    eax, byte ptr [rsp + 0x60]
  000275b1:  89442458                    mov      dword ptr [rsp + 0x58], eax
  000275b5:  8b44246c                    mov      eax, dword ptr [rsp + 0x6c]  ; W"赈鐅⽎䠀䒉〤읈⑄("
  000275b9:  89442450                    mov      dword ptr [rsp + 0x50], eax
  000275bd:  8b442474                    mov      eax, dword ptr [rsp + 0x74]
  000275c1:  89442448                    mov      dword ptr [rsp + 0x48], eax
  000275c5:  8b442470                    mov      eax, dword ptr [rsp + 0x70]
  000275c9:  89442440                    mov      dword ptr [rsp + 0x40], eax
  000275cd:  8b442464                    mov      eax, dword ptr [rsp + 0x64]
  000275d1:  89442438                    mov      dword ptr [rsp + 0x38], eax
  000275d5:  488d05544e2f00              lea      rax, [rip + 0x2f4e54]  ; W"ret 0x%x, psk len %d, hash len %d, seal len %d, data from file flag %d"
  000275dc:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  000275e1:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0  ; W"⑼d乴䲋搤럨Л褀⑄䠸֍五/襈⑄䠰䓇⠤"
  000275ea:  c7442420950b0000            mov      dword ptr [rsp + 0x20], 0xb95  ; W"⑼d乴䲋搤럨Л褀⑄䠸֍五/襈⑄䠰䓇⠤"
  000275f2:  4c8d0dcf4d2f00              lea      r9, [rip + 0x2f4dcf]  ; W"production_check_psk_is_valid"
  000275f9:  4c8d05c0082f00              lea      r8, [rip + 0x2f08c0]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027600:  ba08000000                  mov      edx, 8
  00027605:  488b0d7c0a5100              mov      rcx, qword ptr [rip + 0x510a7c]
  0002760c:  e86beafdff                  call     0x607c  ; fn_0x607c
  00027611:  837c246400                  cmp      dword ptr [rsp + 0x64], 0
  00027616:  744e                        je       0x27666
  00027618:  8b4c2464                    mov      ecx, dword ptr [rsp + 0x64]
  0002761c:  e8b71b0400                  call     0x691d8  ; fn_0x691d8
  00027621:  89442438                    mov      dword ptr [rsp + 0x38], eax
  00027625:  488d05944e2f00              lea      rax, [rip + 0x2f4e94]  ; W"get host hash failed with 0x%x."
  0002762c:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00027631:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002763a:  c7442420980b0000            mov      dword ptr [rsp + 0x20], 0xb98
  00027642:  4c8d0d7f4d2f00              lea      r9, [rip + 0x2f4d7f]  ; W"production_check_psk_is_valid"
  00027649:  4c8d0570082f00              lea      r8, [rip + 0x2f0870]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027650:  ba04000000                  mov      edx, 4
  00027655:  488b0d2c0a5100              mov      rcx, qword ptr [rip + 0x510a2c]
  0002765c:  e81beafdff                  call     0x607c  ; fn_0x607c
  00027661:  e9d5020000                  jmp      0x2793b
  00027666:  488d05934e2f00              lea      rax, [rip + 0x2f4e93]  ; W"2.get mcu hash"
  0002766d:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00027672:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002767b:  c74424209d0b0000            mov      dword ptr [rsp + 0x20], 0xb9d
  00027683:  4c8d0d3e4d2f00              lea      r9, [rip + 0x2f4d3e]  ; W"production_check_psk_is_valid"
  0002768a:  4c8d052f082f00              lea      r8, [rip + 0x2f082f]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027691:  ba08000000                  mov      edx, 8
  00027696:  488b0deb095100              mov      rcx, qword ptr [rip + 0x5109eb]
  0002769d:  e8dae9fdff                  call     0x607c  ; fn_0x607c
  000276a2:  c744246820000000            mov      dword ptr [rsp + 0x68], 0x20  ; W"⑼d䅴赈䄅⽎䠀䒉〤읈⑄("
  000276aa:  4c8d442468                  lea      r8, [rsp + 0x68]  ; W"䡁֍乁/襈⑄䠰䓇⠤"
  000276af:  488d942488020000            lea      rdx, [rsp + 0x288]  ; W"铨И褀⑄䠸֍䩙/襈⑄䠰䓇⠤"
  000276b7:  b9030002bb                  mov      ecx, 0xbb020003
  000276bc:  e85f180000                  call     0x28f20  ; fn_0x28f20
  000276c1:  89442464                    mov      dword ptr [rsp + 0x64], eax
  000276c5:  8b442468                    mov      eax, dword ptr [rsp + 0x68]
  000276c9:  89442440                    mov      dword ptr [rsp + 0x40], eax
  000276cd:  8b442464                    mov      eax, dword ptr [rsp + 0x64]  ; W"赌谍⽌䰀֍ݽ/Һ"
  000276d1:  89442438                    mov      dword ptr [rsp + 0x38], eax
  000276d5:  488d05444e2f00              lea      rax, [rip + 0x2f4e44]  ; W"get mcu hash, ret 0x%x, len %d"
  000276dc:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"粃搤琀䡁֍乁/襈⑄䠰䓇⠤"
  000276e1:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0  ; W"⑼d䅴赈䄅⽎䠀䒉〤읈⑄("
  000276ea:  c7442420a00b0000            mov      dword ptr [rsp + 0x20], 0xba0  ; W"⑼d䅴赈䄅⽎䠀䒉〤읈⑄("
  000276f2:  4c8d0dcf4c2f00              lea      r9, [rip + 0x2f4ccf]  ; W"production_check_psk_is_valid"
  000276f9:  4c8d05c0072f00              lea      r8, [rip + 0x2f07c0]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027700:  ba08000000                  mov      edx, 8
  00027705:  488b0d7c095100              mov      rcx, qword ptr [rip + 0x51097c]
  0002770c:  e86be9fdff                  call     0x607c  ; fn_0x607c
  00027711:  837c246400                  cmp      dword ptr [rsp + 0x64], 0  ; W"⽌䰀֍ܼ/ࢺ"
  00027716:  7441                        je       0x27759
  00027718:  488d05414e2f00              lea      rax, [rip + 0x2f4e41]  ; W"get mcu hash ERROR"
  0002771f:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00027724:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002772d:  c7442420a30b0000            mov      dword ptr [rsp + 0x20], 0xba3
  00027735:  4c8d0d8c4c2f00              lea      r9, [rip + 0x2f4c8c]  ; W"production_check_psk_is_valid"
  0002773c:  4c8d057d072f00              lea      r8, [rip + 0x2f077d]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027743:  ba04000000                  mov      edx, 4
  00027748:  488b0d39095100              mov      rcx, qword ptr [rip + 0x510939]
  0002774f:  e828e9fdff                  call     0x607c  ; fn_0x607c
  00027754:  e9e2010000                  jmp      0x2793b
  00027759:  488d05284e2f00              lea      rax, [rip + 0x2f4e28]  ; W"3.verify"
  00027760:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00027765:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0  ; W"⑄䑨삋赈⒔ʈ"
  0002776e:  c7442420a90b0000            mov      dword ptr [rsp + 0x20], 0xba9  ; W"⑄䑨삋赈⒔ʈ"
  00027776:  4c8d0d4b4c2f00              lea      r9, [rip + 0x2f4c4b]  ; W"production_check_psk_is_valid"
  0002777d:  4c8d053c072f00              lea      r8, [rip + 0x2f073c]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027784:  ba08000000                  mov      edx, 8
  00027789:  488b0df8085100              mov      rcx, qword ptr [rip + 0x5108f8]
  00027790:  e8e7e8fdff                  call     0x607c  ; fn_0x607c
  00027795:  8b442468                    mov      eax, dword ptr [rsp + 0x68]
  00027799:  448bc0                      mov      r8d, eax
  0002779c:  488d942488020000            lea      rdx, [rsp + 0x288]
  000277a4:  488d8c24a8020000            lea      rcx, [rsp + 0x2a8]
  000277ac:  e8bf460300                  call     0x5be70  ; fn_0x5be70
  000277b1:  89442464                    mov      dword ptr [rsp + 0x64], eax
  000277b5:  837c246400                  cmp      dword ptr [rsp + 0x64], 0  ; W"䰀֍ښ/κ"
  000277ba:  0f8482000000                je       0x27842
  000277c0:  488d05d94d2f00              lea      rax, [rip + 0x2f4dd9]  ; W"!!!hash NOT match !!! "
  000277c7:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"赈촅⽍䠀䒉〤䓇⠤ഉ"
  000277cc:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000277d5:  c7442420b00b0000            mov      dword ptr [rsp + 0x20], 0xbb0
  000277dd:  4c8d0de44b2f00              lea      r9, [rip + 0x2f4be4]  ; W"production_check_psk_is_valid"
  000277e4:  4c8d05d5062f00              lea      r8, [rip + 0x2f06d5]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000277eb:  ba04000000                  mov      edx, 4
  000277f0:  488b0d91085100              mov      rcx, qword ptr [rip + 0x510891]
  000277f7:  e880e8fdff                  call     0x607c  ; fn_0x607c
  000277fc:  488d05cd4d2f00              lea      rax, [rip + 0x2f4dcd]  ; W"hash NOT match"
  00027803:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00027808:  c7442428090d0000            mov      dword ptr [rsp + 0x28], 0xd09
  00027810:  c7442420b10b0000            mov      dword ptr [rsp + 0x20], 0xbb1
  00027818:  4c8d0da94b2f00              lea      r9, [rip + 0x2f4ba9]  ; W"production_check_psk_is_valid"
  0002781f:  4c8d059a062f00              lea      r8, [rip + 0x2f069a]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027826:  ba03000000                  mov      edx, 3
  0002782b:  b909000000                  mov      ecx, 9
  00027830:  e81717feff                  call     0x8f4c  ; fn_0x8f4c
  00027835:  c7442464010000ff            mov      dword ptr [rsp + 0x64], 0xff000001
  0002783d:  e9f9000000                  jmp      0x2793b
  00027842:  488d05a74d2f00              lea      rax, [rip + 0x2f4da7]  ; W"!!!hash equal !!! "
  00027849:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002784e:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0  ; W"⑄襰⠅儠謀∅儠䐀삋赈⒔ˈ"
  00027857:  c7442420b50b0000            mov      dword ptr [rsp + 0x20], 0xbb5  ; W"⑄襰⠅儠謀∅儠䐀삋赈⒔ˈ"
  0002785f:  4c8d0d624b2f00              lea      r9, [rip + 0x2f4b62]  ; W"production_check_psk_is_valid"
  00027866:  4c8d0553062f00              lea      r8, [rip + 0x2f0653]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  0002786d:  ba07000000                  mov      edx, 7
  00027872:  488b0d0f085100              mov      rcx, qword ptr [rip + 0x51080f]
  00027879:  e8fee7fdff                  call     0x607c  ; fn_0x607c
  0002787e:  8b442470                    mov      eax, dword ptr [rsp + 0x70]  ; W"襬⑄䠸֍䅪/襈⑄䠰䓇⠤"
  00027882:  890528205100                mov      dword ptr [rip + 0x512028], eax
  00027888:  8b0522205100                mov      eax, dword ptr [rip + 0x512022]
  0002788e:  448bc0                      mov      r8d, eax
  00027891:  488d9424c8020000            lea      rdx, [rsp + 0x2c8]
  00027899:  488d0df01f5100              lea      rcx, [rip + 0x511ff0]
  000278a0:  e82b3f0300                  call     0x5b7d0  ; fn_0x5b7d0
  000278a5:  0fb6442460                  movzx    eax, byte ptr [rsp + 0x60]
  000278aa:  85c0                        test     eax, eax
  000278ac:  0f8581000000                jne      0x27933
  000278b2:  4c8d0587412f00              lea      r8, [rip + 0x2f4187]  ; W"Goodix_Cache.bin"
  000278b9:  ba04000000                  mov      edx, 4
  000278be:  488d8c2480000000            lea      rcx, [rsp + 0x80]  ; W"㠤赈夅⽊䠀䒉〤읈⑄("
  000278c6:  e82dddfdff                  call     0x55f8  ; fn_0x55f8
  000278cb:  448b44246c                  mov      r8d, dword ptr [rsp + 0x6c]
  000278d0:  488d9424f0020000            lea      rdx, [rsp + 0x2f0]
  000278d8:  488bc8                      mov      rcx, rax
  000278db:  e838b1fdff                  call     0x2a18  ; fn_0x2a18
  000278e0:  4889442478                  mov      qword ptr [rsp + 0x78], rax
  000278e5:  488b442478                  mov      rax, qword ptr [rsp + 0x78]
  000278ea:  4889442440                  mov      qword ptr [rsp + 0x40], rax
  000278ef:  8b44246c                    mov      eax, dword ptr [rsp + 0x6c]
  000278f3:  89442438                    mov      dword ptr [rsp + 0x38], eax
  000278f7:  488d056a412f00              lea      rax, [rip + 0x2f416a]  ; W"written %d:%d bytes to file"
  000278fe:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00027903:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002790c:  c7442420bd0b0000            mov      dword ptr [rsp + 0x20], 0xbbd
  00027914:  4c8d0dad4a2f00              lea      r9, [rip + 0x2f4aad]  ; W"production_check_psk_is_valid"
  0002791b:  4c8d059e052f00              lea      r8, [rip + 0x2f059e]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027922:  ba08000000                  mov      edx, 8
  00027927:  488b0d5a075100              mov      rcx, qword ptr [rip + 0x51075a]
  0002792e:  e849e7fdff                  call     0x607c  ; fn_0x607c
  00027933:  c744246400000000            mov      dword ptr [rsp + 0x64], 0
  0002793b:  8b4c2464                    mov      ecx, dword ptr [rsp + 0x64]
  0002793f:  e894180400                  call     0x691d8  ; fn_0x691d8
  00027944:  89442438                    mov      dword ptr [rsp + 0x38], eax
  00027948:  488d05594a2f00              lea      rax, [rip + 0x2f4a59]  ; W"exit with 0x%x"
  0002794f:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"䒋搤譈⒌૰"
  00027954:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002795d:  c7442420c20b0000            mov      dword ptr [rsp + 0x20], 0xbc2
  00027965:  4c8d0d5c4a2f00              lea      r9, [rip + 0x2f4a5c]  ; W"production_check_psk_is_valid"
  0002796c:  4c8d054d052f00              lea      r8, [rip + 0x2f054d]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00027973:  ba08000000                  mov      edx, 8
  00027978:  488b0d09075100              mov      rcx, qword ptr [rip + 0x510709]
  0002797f:  e8f8e6fdff                  call     0x607c  ; fn_0x607c
  00027984:  8b442464                    mov      eax, dword ptr [rsp + 0x64]
  00027988:  488b8c24f00a0000            mov      rcx, qword ptr [rsp + 0xaf0]
  00027990:  4833cc                      xor      rcx, rsp
  00027993:  e8d8310300                  call     0x5ab70  ; fn_0x5ab70
  00027998:  4881c4000b0000              add      rsp, 0xb00
  0002799f:  5f                          pop      rdi
  000279a0:  c3                          ret      
  000279a1:  cc                          int3     

; --- function boundary ---

  000279a2:  cc                          int3     

; --- function boundary ---

  000279a3:  cc                          int3     
  000279a4:  4883ec78                    sub      rsp, 0x78
  000279a8:  c744245800000000            mov      dword ptr [rsp + 0x58], 0