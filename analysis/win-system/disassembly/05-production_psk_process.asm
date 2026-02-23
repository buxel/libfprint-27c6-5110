; gfspi.dll - production_psk_process function
; Main PSK orchestration: check validity, write if needed
; Image base: 0x180000000
; String 'production_psk_process' at RVA 0x31b100
; XREFs: ['0x28476', '0x284c4', '0x28515', '0x2857a', '0x285d3', '0x28611', '0x28669', '0x286c5', '0x2871e', '0x2876f']
; Function start: RVA 0x28440
; Function end: RVA 0x28a92

  00028440:  48894c2408                  mov      qword ptr [rsp + 8], rcx
  00028445:  4883ec58                    sub      rsp, 0x58
  00028449:  c7442440010000ff            mov      dword ptr [rsp + 0x40], 0xff000001  ; W"��荈⑼`卵譈⑄䡠䒉㠤赈舅⼬䠀䒉〤읈⑄("
  00028451:  c744244c00000000            mov      dword ptr [rsp + 0x4c], 0  ; W"㠤赈舅⼬䠀䒉〤읈⑄("
  00028459:  488d0570a31700              lea      rax, [rip + 0x17a370]  ; W"Entry"
  00028460:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"荈⑼`卵譈⑄䡠䒉㠤赈舅⼬䠀䒉〤읈⑄("
  00028465:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0  ; W"粃怤甀䡓䒋怤襈⑄䠸֍Ⲃ/襈⑄䠰䓇⠤"
  0002846e:  c7442420a2070000            mov      dword ptr [rsp + 0x20], 0x7a2  ; W"粃怤甀䡓䒋怤襈⑄䠸֍Ⲃ/襈⑄䠰䓇⠤"
  00028476:  4c8d0d832c2f00              lea      r9, [rip + 0x2f2c83]  ; W"production_psk_process"
  0002847d:  4c8d053cfa2e00              lea      r8, [rip + 0x2efa3c]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00028484:  ba08000000                  mov      edx, 8
  00028489:  488b0df8fb5000              mov      rcx, qword ptr [rip + 0x50fbf8]
  00028490:  e8e7dbfdff                  call     0x607c  ; fn_0x607c
  00028495:  48837c246000                cmp      qword ptr [rsp + 0x60], 0  ; W"ⲑ/襈⑄䠰䓇⠤"
  0002849b:  7553                        jne      0x284f0
  0002849d:  488b442460                  mov      rax, qword ptr [rsp + 0x60]  ; W"〤읈⑄("
  000284a2:  4889442438                  mov      qword ptr [rsp + 0x38], rax
  000284a7:  488d05822c2f00              lea      rax, [rip + 0x2f2c82]  ; W"Input invalide parameters p_version_now:0x%p."
  000284ae:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  000284b3:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000284bc:  c7442420a5070000            mov      dword ptr [rsp + 0x20], 0x7a5
  000284c4:  4c8d0d352c2f00              lea      r9, [rip + 0x2f2c35]  ; W"production_psk_process"
  000284cb:  4c8d05eef92e00              lea      r8, [rip + 0x2ef9ee]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000284d2:  ba04000000                  mov      edx, 4
  000284d7:  488b0daafb5000              mov      rcx, qword ptr [rip + 0x50fbaa]
  000284de:  e899dbfdff                  call     0x607c  ; fn_0x607c
  000284e3:  c7442440ffffefff            mov      dword ptr [rsp + 0x40], 0xffefffff
  000284eb:  e940050000                  jmp      0x28a30
  000284f0:  c744243802000000            mov      dword ptr [rsp + 0x38], 2  ; W"��䓇䐤"
  000284f8:  488d05912c2f00              lea      rax, [rip + 0x2f2c91]  ; W". check psk if valid (total times:%d)"
  000284ff:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00028504:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002850d:  c7442420ab070000            mov      dword ptr [rsp + 0x20], 0x7ab
  00028515:  4c8d0de42b2f00              lea      r9, [rip + 0x2f2be4]  ; W"production_psk_process"
  0002851c:  4c8d059df92e00              lea      r8, [rip + 0x2ef99d]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00028523:  ba08000000                  mov      edx, 8
  00028528:  488b0d59fb5000              mov      rcx, qword ptr [rip + 0x50fb59]
  0002852f:  e848dbfdff                  call     0x607c  ; fn_0x607c
  00028534:  c744244400000000            mov      dword ptr [rsp + 0x44], 0  ; W"䰀֍露.ࢺ"
  0002853c:  eb0a                        jmp      0x28548
  0002853e:  8b442444                    mov      eax, dword ptr [rsp + 0x44]
  00028542:  ffc0                        inc      eax
  00028544:  89442444                    mov      dword ptr [rsp + 0x44], eax
  00028548:  837c244402                  cmp      dword ptr [rsp + 0x44], 2
  0002854d:  0f8def000000                jge      0x28642
  00028553:  8b442444                    mov      eax, dword ptr [rsp + 0x44]  ; W"￮觿⑄荀⑼@䭴䲋䀤⛨Ќ褀⑄䠸֍ⱓ/襈⑄䠰䓇⠤"
  00028557:  ffc0                        inc      eax
  00028559:  89442438                    mov      dword ptr [rsp + 0x38], eax  ; W"��단￮觿⑄荀⑼@䭴䲋䀤⛨Ќ褀⑄䠸֍ⱓ/襈⑄䠰䓇⠤"
  0002855d:  488d057c2c2f00              lea      rax, [rip + 0x2f2c7c]  ; W"check psk times: %d"
  00028564:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"단￮觿⑄荀⑼@䭴䲋䀤⛨Ќ褀⑄䠸֍ⱓ/襈⑄䠰䓇⠤"
  00028569:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00028572:  c7442420ae070000            mov      dword ptr [rsp + 0x20], 0x7ae
  0002857a:  4c8d0d7f2b2f00              lea      r9, [rip + 0x2f2b7f]  ; W"production_psk_process"
  00028581:  4c8d0538f92e00              lea      r8, [rip + 0x2ef938]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00028588:  ba08000000                  mov      edx, 8
  0002858d:  488b0df4fa5000              mov      rcx, qword ptr [rip + 0x50faf4]
  00028594:  e8e3dafdff                  call     0x607c  ; fn_0x607c
  00028599:  e8b2eeffff                  call     0x27450  ; fn_0x27450
  0002859e:  89442440                    mov      dword ptr [rsp + 0x40], eax
  000285a2:  837c244000                  cmp      dword ptr [rsp + 0x40], 0
  000285a7:  744b                        je       0x285f4
  000285a9:  8b4c2440                    mov      ecx, dword ptr [rsp + 0x40]
  000285ad:  e8260c0400                  call     0x691d8  ; fn_0x691d8
  000285b2:  89442438                    mov      dword ptr [rsp + 0x38], eax  ; W"��䧫赈唅⼬䠀䒉〤읈⑄("
  000285b6:  488d05532c2f00              lea      rax, [rip + 0x2f2c53]  ; W"check psk failed with ret:0x%x."
  000285bd:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"䧫赈唅⼬䠀䒉〤읈⑄("
  000285c2:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0  ; W"䡉֍ⱕ/襈⑄䠰䓇⠤"
  000285cb:  c7442420b2070000            mov      dword ptr [rsp + 0x20], 0x7b2  ; W"䡉֍ⱕ/襈⑄䠰䓇⠤"
  000285d3:  4c8d0d262b2f00              lea      r9, [rip + 0x2f2b26]  ; W"production_psk_process"
  000285da:  4c8d05dff82e00              lea      r8, [rip + 0x2ef8df]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000285e1:  ba04000000                  mov      edx, 4
  000285e6:  488b0d9bfa5000              mov      rcx, qword ptr [rip + 0x50fa9b]
  000285ed:  e88adafdff                  call     0x607c  ; fn_0x607c
  000285f2:  eb49                        jmp      0x2863d
  000285f4:  488d05552c2f00              lea      rax, [rip + 0x2f2c55]  ; W"check psk: psk is valid!"
  000285fb:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00028600:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00028609:  c7442420b6070000            mov      dword ptr [rsp + 0x20], 0x7b6
  00028611:  4c8d0de82a2f00              lea      r9, [rip + 0x2f2ae8]  ; W"production_psk_process"
  00028618:  4c8d05a1f82e00              lea      r8, [rip + 0x2ef8a1]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  0002861f:  ba08000000                  mov      edx, 8
  00028624:  488b0d5dfa5000              mov      rcx, qword ptr [rip + 0x50fa5d]
  0002862b:  e84cdafdff                  call     0x607c  ; fn_0x607c
  00028630:  c744244000000000            mov      dword ptr [rsp + 0x40], 0
  00028638:  e9f3030000                  jmp      0x28a30
  0002863d:  e9fcfeffff                  jmp      0x2853e
  00028642:  488b442460                  mov      rax, qword ptr [rsp + 0x60]  ; W"䠀֍Ⱁ/襈⑄䠰䓇⠤"
  00028647:  4889442438                  mov      qword ptr [rsp + 0x38], rax  ; W"��赈ⴕ⼬䠀䲋怤뿨ʠ褀⑄荌⑼Ō萏í"
  0002864c:  488d05352c2f00              lea      rax, [rip + 0x2f2c35]  ; W"2. check IAP or APP: %S."
  00028653:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"赈ⴕ⼬䠀䲋怤뿨ʠ褀⑄荌⑼Ō萏í"
  00028658:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00028661:  c7442420c1070000            mov      dword ptr [rsp + 0x20], 0x7c1
  00028669:  4c8d0d902a2f00              lea      r9, [rip + 0x2f2a90]  ; W"production_psk_process"
  00028670:  4c8d0549f82e00              lea      r8, [rip + 0x2ef849]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00028677:  ba08000000                  mov      edx, 8
  0002867c:  488b0d05fa5000              mov      rcx, qword ptr [rip + 0x50fa05]
  00028683:  e8f4d9fdff                  call     0x607c  ; fn_0x607c
  00028688:  488d152d2c2f00              lea      rdx, [rip + 0x2f2c2d]  ; W"䅉PAPP, set to IAP"
  0002868f:  488b4c2460                  mov      rcx, qword ptr [rsp + 0x60]  ; W"䲋䀤�Њ褀⑄䠸֍⯘/襈⑄䠰䓇⠤"
  00028694:  e8bfa00200                  call     0x52758  ; fn_0x52758
  00028699:  8944244c                    mov      dword ptr [rsp + 0x4c], eax
  0002869d:  837c244c01                  cmp      dword ptr [rsp + 0x4c], 1  ; W"⑼@乴䲋䀤�Њ褀⑄䠸֍⯘/襈⑄䠰䓇⠤"
  000286a2:  0f84ed000000                je       0x28795
  000286a8:  488d05112c2f00              lea      rax, [rip + 0x2f2c11]  ; W"APP, set to IAP"
  000286af:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  000286b4:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000286bd:  c7442420c5070000            mov      dword ptr [rsp + 0x20], 0x7c5
  000286c5:  4c8d0d342a2f00              lea      r9, [rip + 0x2f2a34]  ; W"production_psk_process"
  000286cc:  4c8d05edf72e00              lea      r8, [rip + 0x2ef7ed]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000286d3:  ba08000000                  mov      edx, 8
  000286d8:  488b0da9f95000              mov      rcx, qword ptr [rip + 0x50f9a9]
  000286df:  e898d9fdff                  call     0x607c  ; fn_0x607c
  000286e4:  e8bbf2ffff                  call     0x279a4  ; fn_0x279a4
  000286e9:  89442440                    mov      dword ptr [rsp + 0x40], eax
  000286ed:  837c244000                  cmp      dword ptr [rsp + 0x40], 0
  000286f2:  744e                        je       0x28742
  000286f4:  8b4c2440                    mov      ecx, dword ptr [rsp + 0x40]
  000286f8:  e8db0a0400                  call     0x691d8  ; fn_0x691d8
  000286fd:  89442438                    mov      dword ptr [rsp + 0x38], eax
  00028701:  488d05d82b2f00              lea      rax, [rip + 0x2f2bd8]  ; W"set to IAP failed with 0x%x"
  00028708:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002870d:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00028716:  c7442420c9070000            mov      dword ptr [rsp + 0x20], 0x7c9
  0002871e:  4c8d0ddb292f00              lea      r9, [rip + 0x2f29db]  ; W"production_psk_process"
  00028725:  4c8d0594f72e00              lea      r8, [rip + 0x2ef794]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  0002872c:  ba04000000                  mov      edx, 4
  00028731:  488b0d50f95000              mov      rcx, qword ptr [rip + 0x50f950]
  00028738:  e83fd9fdff                  call     0x607c  ; fn_0x607c
  0002873d:  e9ee020000                  jmp      0x28a30
  00028742:  c7442440f3ffdfff            mov      dword ptr [rsp + 0x40], 0xffdffff3
  0002874a:  8b442440                    mov      eax, dword ptr [rsp + 0x40]
  0002874e:  89442438                    mov      dword ptr [rsp + 0x38], eax
  00028752:  488d05c72b2f00              lea      rax, [rip + 0x2f2bc7]  ; W"return 0x%x after clearup APP, Driver will restart soon"
  00028759:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002875e:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00028767:  c7442420cf070000            mov      dword ptr [rsp + 0x20], 0x7cf
  0002876f:  4c8d0d8a292f00              lea      r9, [rip + 0x2f298a]  ; W"production_psk_process"
  00028776:  4c8d0543f72e00              lea      r8, [rip + 0x2ef743]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  0002877d:  ba08000000                  mov      edx, 8
  00028782:  488b0dfff85000              mov      rcx, qword ptr [rip + 0x50f8ff]
  00028789:  e8eed8fdff                  call     0x607c  ; fn_0x607c
  0002878e:  e99d020000                  jmp      0x28a30
  00028793:  eb3c                        jmp      0x287d1
  00028795:  488d05f42b2f00              lea      rax, [rip + 0x2f2bf4]  ; W"IAP, move on ..."
  0002879c:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  000287a1:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000287aa:  c7442420d4070000            mov      dword ptr [rsp + 0x20], 0x7d4
  000287b2:  4c8d0d47292f00              lea      r9, [rip + 0x2f2947]  ; W"production_psk_process"
  000287b9:  4c8d0500f72e00              lea      r8, [rip + 0x2ef700]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000287c0:  ba05000000                  mov      edx, 5
  000287c5:  488b0dbcf85000              mov      rcx, qword ptr [rip + 0x50f8bc]
  000287cc:  e8abd8fdff                  call     0x607c  ; fn_0x607c
  000287d1:  c744243802000000            mov      dword ptr [rsp + 0x38], 2  ; W"��䓇䠤"
  000287d9:  488d05e02b2f00              lea      rax, [rip + 0x2f2be0]  ; W". write psk to mcu (total times:%d)"
  000287e0:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  000287e5:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000287ee:  c7442420d8070000            mov      dword ptr [rsp + 0x20], 0x7d8
  000287f6:  4c8d0d03292f00              lea      r9, [rip + 0x2f2903]  ; W"production_psk_process"
  000287fd:  4c8d05bcf62e00              lea      r8, [rip + 0x2ef6bc]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00028804:  ba08000000                  mov      edx, 8
  00028809:  488b0d78f85000              mov      rcx, qword ptr [rip + 0x50f878]
  00028810:  e867d8fdff                  call     0x607c  ; fn_0x607c
  00028815:  c744244800000000            mov      dword ptr [rsp + 0x48], 0
  0002881d:  eb0a                        jmp      0x28829
  0002881f:  8b442448                    mov      eax, dword ptr [rsp + 0x48]
  00028823:  ffc0                        inc      eax
  00028825:  89442448                    mov      dword ptr [rsp + 0x48], eax
  00028829:  837c244802                  cmp      dword ptr [rsp + 0x48], 2
  0002882e:  0f8dfc010000                jge      0x28a30
  00028834:  8b442448                    mov      eax, dword ptr [rsp + 0x48]
  00028838:  ffc0                        inc      eax
  0002883a:  89442438                    mov      dword ptr [rsp + 0x38], eax
  0002883e:  488d05c32b2f00              lea      rax, [rip + 0x2f2bc3]  ; W"write psk to mcu (times:%d)"
  00028845:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002884a:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00028853:  c7442420db070000            mov      dword ptr [rsp + 0x20], 0x7db
  0002885b:  4c8d0d9e282f00              lea      r9, [rip + 0x2f289e]  ; W"production_psk_process"
  00028862:  4c8d0557f62e00              lea      r8, [rip + 0x2ef657]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00028869:  ba08000000                  mov      edx, 8
  0002886e:  488b0d13f85000              mov      rcx, qword ptr [rip + 0x50f813]
  00028875:  e802d8fdff                  call     0x607c  ; fn_0x607c
  0002887a:  e8e9090000                  call     0x29268  ; fn_0x29268
  0002887f:  89442440                    mov      dword ptr [rsp + 0x40], eax
  00028883:  837c244000                  cmp      dword ptr [rsp + 0x40], 0
  00028888:  0f8487000000                je       0x28915
  0002888e:  8b4c2440                    mov      ecx, dword ptr [rsp + 0x40]
  00028892:  e841090400                  call     0x691d8  ; fn_0x691d8
  00028897:  89442438                    mov      dword ptr [rsp + 0x38], eax
  0002889b:  488d059e2b2f00              lea      rax, [rip + 0x2f2b9e]  ; W"update key failed with ret:0x%x."
  000288a2:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"赈ꨅ⼫䠀䒉〤䓇⠤ഉ"
  000288a7:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000288b0:  c7442420df070000            mov      dword ptr [rsp + 0x20], 0x7df
  000288b8:  4c8d0d41282f00              lea      r9, [rip + 0x2f2841]  ; W"production_psk_process"
  000288bf:  4c8d05faf52e00              lea      r8, [rip + 0x2ef5fa]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000288c6:  ba04000000                  mov      edx, 4
  000288cb:  488b0db6f75000              mov      rcx, qword ptr [rip + 0x50f7b6]
  000288d2:  e8a5d7fdff                  call     0x607c  ; fn_0x607c
  000288d7:  488d05aa2b2f00              lea      rax, [rip + 0x2f2baa]  ; W"update key failed"
  000288de:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  000288e3:  c7442428090d0000            mov      dword ptr [rsp + 0x28], 0xd09
  000288eb:  c7442420e0070000            mov      dword ptr [rsp + 0x20], 0x7e0
  000288f3:  4c8d0d06282f00              lea      r9, [rip + 0x2f2806]  ; W"production_psk_process"
  000288fa:  4c8d05bff52e00              lea      r8, [rip + 0x2ef5bf]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00028901:  ba04000000                  mov      edx, 4
  00028906:  b909000000                  mov      ecx, 9
  0002890b:  e83c06feff                  call     0x8f4c  ; fn_0x8f4c
  00028910:  e916010000                  jmp      0x28a2b
  00028915:  488d05942b2f00              lea      rax, [rip + 0x2f2b94]  ; W"update key success, check psk again"
  0002891c:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"赈ꀅ⼫䠀䒉〤䓇⠤Ⴭ"
  00028921:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002892a:  c7442420e4070000            mov      dword ptr [rsp + 0x20], 0x7e4
  00028932:  4c8d0dc7272f00              lea      r9, [rip + 0x2f27c7]  ; W"production_psk_process"
  00028939:  4c8d0580f52e00              lea      r8, [rip + 0x2ef580]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00028940:  ba08000000                  mov      edx, 8
  00028945:  488b0d3cf75000              mov      rcx, qword ptr [rip + 0x50f73c]
  0002894c:  e82bd7fdff                  call     0x607c  ; fn_0x607c
  00028951:  488d05a02b2f00              lea      rax, [rip + 0x2f2ba0]  ; W"update key success"
  00028958:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002895d:  c7442428cd100000            mov      dword ptr [rsp + 0x28], 0x10cd
  00028965:  c7442420e5070000            mov      dword ptr [rsp + 0x20], 0x7e5
  0002896d:  4c8d0d8c272f00              lea      r9, [rip + 0x2f278c]  ; W"production_psk_process"
  00028974:  4c8d0545f52e00              lea      r8, [rip + 0x2ef545]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  0002897b:  ba04000000                  mov      edx, 4
  00028980:  b909000000                  mov      ecx, 9
  00028985:  e8c205feff                  call     0x8f4c  ; fn_0x8f4c
  0002898a:  e8c1eaffff                  call     0x27450  ; fn_0x27450
  0002898f:  89442440                    mov      dword ptr [rsp + 0x40], eax
  00028993:  837c244000                  cmp      dword ptr [rsp + 0x40], 0
  00028998:  744b                        je       0x289e5
  0002899a:  8b4c2440                    mov      ecx, dword ptr [rsp + 0x40]
  0002899e:  e835080400                  call     0x691d8  ; fn_0x691d8
  000289a3:  89442438                    mov      dword ptr [rsp + 0x38], eax  ; W"횙�䛫赈搅⼨䠀䒉〤읈⑄("
  000289a7:  488d0562282f00              lea      rax, [rip + 0x2f2862]  ; W"check psk failed with ret:0x%x."
  000289ae:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"䛫赈搅⼨䠀䒉〤읈⑄("
  000289b3:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0  ; W"䡆֍⡤/襈⑄䠰䓇⠤"
  000289bc:  c7442420e9070000            mov      dword ptr [rsp + 0x20], 0x7e9  ; W"䡆֍⡤/襈⑄䠰䓇⠤"
  000289c4:  4c8d0d35272f00              lea      r9, [rip + 0x2f2735]  ; W"production_psk_process"
  000289cb:  4c8d05eef42e00              lea      r8, [rip + 0x2ef4ee]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000289d2:  ba04000000                  mov      edx, 4
  000289d7:  488b0daaf65000              mov      rcx, qword ptr [rip + 0x50f6aa]
  000289de:  e899d6fdff                  call     0x607c  ; fn_0x607c
  000289e3:  eb46                        jmp      0x28a2b
  000289e5:  488d0564282f00              lea      rax, [rip + 0x2f2864]  ; W"check psk: psk is valid!"
  000289ec:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  000289f1:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000289fa:  c7442420ed070000            mov      dword ptr [rsp + 0x20], 0x7ed
  00028a02:  4c8d0df7262f00              lea      r9, [rip + 0x2f26f7]  ; W"production_psk_process"
  00028a09:  4c8d05b0f42e00              lea      r8, [rip + 0x2ef4b0]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00028a10:  ba08000000                  mov      edx, 8
  00028a15:  488b0d6cf65000              mov      rcx, qword ptr [rip + 0x50f66c]
  00028a1c:  e85bd6fdff                  call     0x607c  ; fn_0x607c
  00028a21:  c744244000000000            mov      dword ptr [rsp + 0x40], 0
  00028a29:  eb05                        jmp      0x28a30
  00028a2b:  e9effdffff                  jmp      0x2881f
  00028a30:  8b4c2440                    mov      ecx, dword ptr [rsp + 0x40]
  00028a34:  e89f070400                  call     0x691d8  ; fn_0x691d8
  00028a39:  89442438                    mov      dword ptr [rsp + 0x38], eax
  00028a3d:  488d05dc2a2f00              lea      rax, [rip + 0x2f2adc]  ; W"Exit ret:0x%x"
  00028a44:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00028a49:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00028a52:  c7442420f4070000            mov      dword ptr [rsp + 0x20], 0x7f4
  00028a5a:  4c8d0d9f262f00              lea      r9, [rip + 0x2f269f]  ; W"production_psk_process"
  00028a61:  4c8d0558f42e00              lea      r8, [rip + 0x2ef458]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00028a68:  ba08000000                  mov      edx, 8
  00028a6d:  488b0d14f65000              mov      rcx, qword ptr [rip + 0x50f614]
  00028a74:  e803d6fdff                  call     0x607c  ; fn_0x607c
  00028a79:  8b442440                    mov      eax, dword ptr [rsp + 0x40]
  00028a7d:  4883c458                    add      rsp, 0x58
  00028a81:  c3                          ret      
  00028a82:  cc                          int3     

; --- function boundary ---

  00028a83:  cc                          int3     
  00028a84:  4c894c2420                  mov      qword ptr [rsp + 0x20], r9
  00028a89:  4c89442418                  mov      qword ptr [rsp + 0x18], r8
  00028a8e:  89542410                    mov      dword ptr [rsp + 0x10], edx