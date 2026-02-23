; gfspi.dll - SecWhiteEncrypt / 123GOODIX functions
; Whitebox encryption using HMAC-SHA256('123GOODIX') + AES-128-CBC
; '123GOODIX' (ASCII) at RVA 0x532a18
; 'SecWhiteEncrypt' (ASCII) at RVA 0x532918
; Image base: 0x180000000
; String 'SecWhiteEncrypt' at RVA 0x532918
; XREFs: ['0x1610', '0x1661', '0x1730', '0x1b43', '0x1b6d']
; Function start: RVA 0x15b0
; Function end: RVA 0x1c31

  000015b0:  4c8bdc                      mov      r11, rsp
  000015b3:  55                          push     rbp
  000015b4:  53                          push     rbx
  000015b5:  498dab68fbffff              lea      rbp, [r11 - 0x498]
  000015bc:  4881ec88050000              sub      rsp, 0x588
  000015c3:  488b057e835300              mov      rax, qword ptr [rip + 0x53837e]
  000015ca:  4833c4                      xor      rax, rsp
  000015cd:  48898540040000              mov      qword ptr [rbp + 0x440], rax
  000015d4:  498973e8                    mov      qword ptr [r11 - 0x18], rsi
  000015d8:  488d05e1125300              lea      rax, [rip + 0x5312e1]  ; "=> GoodixDataAesEncrypt pData:0x%p, pDataEncrypted:0x%p, pDataEncrypte"
  000015df:  49897be0                    mov      qword ptr [r11 - 0x20], rdi
  000015e3:  488bd9                      mov      rbx, rcx
  000015e6:  4d8963d8                    mov      qword ptr [r11 - 0x28], r12
  000015ea:  4d8be1                      mov      r12, r9
  000015ed:  4c894c2438                  mov      qword ptr [rsp + 0x38], r9
  000015f2:  4c89442430                  mov      qword ptr [rsp + 0x30], r8
  000015f7:  4d896bd0                    mov      qword ptr [r11 - 0x30], r13
  000015fb:  48894c2428                  mov      qword ptr [rsp + 0x28], rcx
  00001600:  4d8973c8                    mov      qword ptr [r11 - 0x38], r14
  00001604:  4d897bc0                    mov      qword ptr [r11 - 0x40], r15  ; W"S㍈䣄薉р"
  00001608:  4d8bf8                      mov      r15, r8
  0000160b:  4c894c2450                  mov      qword ptr [rsp + 0x50], r9
  00001610:  4c8d0501135300              lea      r8, [rip + 0x531301]  ; "SecWhiteEncrypt"
  00001617:  8bf2                        mov      esi, edx
  00001619:  41b9ef010000                mov      r9d, 0x1ef
  0000161f:  48894c2448                  mov      qword ptr [rsp + 0x48], rcx
  00001624:  488d1545125300              lea      rdx, [rip + 0x531245]  ; "f:\git\winfpsec\winfpsec\seclibs\sourceall\sourcecode\seccipher.c"
  0000162b:  b904000000                  mov      ecx, 4
  00001630:  c744244000000000            mov      dword ptr [rsp + 0x40], 0  ; W"S璉⠤륁Ǹ"
  00001638:  4889442420                  mov      qword ptr [rsp + 0x20], rax
  0000163d:  e88e070000                  call     0x1dd0  ; fn_0x1dd0
  00001642:  4d85ff                      test     r15, r15
  00001645:  0f84e6040000                je       0x1b31
  0000164b:  4885db                      test     rbx, rbx
  0000164e:  0f84dd040000                je       0x1b31
  00001654:  4d85e4                      test     r12, r12
  00001657:  0f84d4040000                je       0x1b31
  0000165d:  418b0424                    mov      eax, dword ptr [r12]
  00001661:  4c8d05b0125300              lea      r8, [rip + 0x5312b0]  ; "SecWhiteEncrypt"
  00001668:  89442430                    mov      dword ptr [rsp + 0x30], eax
  0000166c:  488d15fd115300              lea      rdx, [rip + 0x5311fd]  ; "f:\git\winfpsec\winfpsec\seclibs\sourceall\sourcecode\seccipher.c"
  00001673:  488d05c6125300              lea      rax, [rip + 0x5312c6]  ; "Input data length:%d. Output buffer length:%d."
  0000167a:  89742428                    mov      dword ptr [rsp + 0x28], esi
  0000167e:  41b9f8010000                mov      r9d, 0x1f8
  00001684:  4889442420                  mov      qword ptr [rsp + 0x20], rax
  00001689:  b904000000                  mov      ecx, 4
  0000168e:  e83d070000                  call     0x1dd0  ; fn_0x1dd0
  00001693:  33c0                        xor      eax, eax
  00001695:  488d4d20                    lea      rcx, [rbp + 0x20]
  00001699:  48894520                    mov      qword ptr [rbp + 0x20], rax
  0000169d:  48894528                    mov      qword ptr [rbp + 0x28], rax
  000016a1:  e832aa0200                  call     0x2c0d8  ; fn_0x2c0d8
  000016a6:  488d4d80                    lea      rcx, [rbp - 0x80]
  000016aa:  e889ef0200                  call     0x30638  ; fn_0x30638
  000016af:  488d4c2468                  lea      rcx, [rsp + 0x68]
  000016b4:  e8ef4c0300                  call     0x363a8  ; fn_0x363a8
  000016b9:  b905000000                  mov      ecx, 5
  000016be:  c744244001000000            mov      dword ptr [rsp + 0x40], 1
  000016c6:  e8a1ee0200                  call     0x3056c  ; fn_0x3056c
  000016cb:  488bf8                      mov      rdi, rax
  000016ce:  4885c0                      test     rax, rax
  000016d1:  7512                        jne      0x16e5
  000016d3:  488d0596125300              lea      rax, [rip + 0x531296]  ; "Cipher MBEDTLS_CIPHER_AES_128_CBC not found"
  000016da:  41b909020000                mov      r9d, 0x209
  000016e0:  e959040000                  jmp      0x1b3e
  000016e5:  488bd7                      mov      rdx, rdi
  000016e8:  488d4d80                    lea      rcx, [rbp - 0x80]
  000016ec:  e82bf20200                  call     0x3091c  ; fn_0x3091c
  000016f1:  8bd8                        mov      ebx, eax
  000016f3:  85c0                        test     eax, eax
  000016f5:  7412                        je       0x1709
  000016f7:  488d05a2125300              lea      rax, [rip + 0x5312a2]  ; "mbedtls_cipher_setup failed"
  000016fe:  41b90e020000                mov      r9d, 0x20e
  00001704:  e93a040000                  jmp      0x1b43
  00001709:  33d2                        xor      edx, edx
  0000170b:  488d4d80                    lea      rcx, [rbp - 0x80]
  0000170f:  e838f00200                  call     0x3074c  ; fn_0x3074c
  00001714:  8bd8                        mov      ebx, eax
  00001716:  85c0                        test     eax, eax
  00001718:  7438                        je       0x1752
  0000171a:  99                          cdq      
  0000171b:  41b919020000                mov      r9d, 0x219
  00001721:  33c2                        xor      eax, edx
  00001723:  2bc2                        sub      eax, edx
  00001725:  89442428                    mov      dword ptr [rsp + 0x28], eax
  00001729:  488d0590125300              lea      rax, [rip + 0x531290]  ; "mbedtls_cipher_set_padding_mode failed:0x%x. "
  00001730:  4c8d05e1115300              lea      r8, [rip + 0x5311e1]  ; "SecWhiteEncrypt"
  00001737:  4889442420                  mov      qword ptr [rsp + 0x20], rax
  0000173c:  488d152d115300              lea      rdx, [rip + 0x53112d]  ; "f:\git\winfpsec\winfpsec\seclibs\sourceall\sourcecode\seccipher.c"
  00001743:  b904000000                  mov      ecx, 4
  00001748:  e883060000                  call     0x1dd0  ; fn_0x1dd0
  0000174d:  e90e040000                  jmp      0x1b60
  00001752:  b906000000                  mov      ecx, 6
  00001757:  e8144c0300                  call     0x36370  ; fn_0x36370
  0000175c:  448b742440                  mov      r14d, dword ptr [rsp + 0x40]  ; W"䣨䖉䓰䂍䠐䖉䣸䖉䠀䖉䠈䖉䠐䖉䠘䖉䠰䖉昸ས萟"
  00001761:  488d4c2468                  lea      rcx, [rsp + 0x68]
  00001766:  458bc6                      mov      r8d, r14d
  00001769:  4889442458                  mov      qword ptr [rsp + 0x58], rax
  0000176e:  488bd0                      mov      rdx, rax
  00001771:  e8524c0300                  call     0x363c8  ; fn_0x363c8
  00001776:  8bd8                        mov      ebx, eax
  00001778:  85c0                        test     eax, eax
  0000177a:  7415                        je       0x1791
  0000177c:  f7d8                        neg      eax
  0000177e:  41b921020000                mov      r9d, 0x221
  00001784:  89442428                    mov      dword ptr [rsp + 0x28], eax
  00001788:  488d0561125300              lea      rax, [rip + 0x531261]  ; "mbedtls_md_setup() returned -0x%04x"
  0000178f:  eb9f                        jmp      0x1730
  00001791:  33c0                        xor      eax, eax
  00001793:  488d55e1                    lea      rdx, [rbp - 0x1f]  ; W"삅ᕴ�륁ȡ"
  00001797:  488945e0                    mov      qword ptr [rbp - 0x20], rax
  0000179b:  4533c9                      xor      r9d, r9d
  0000179e:  488945e8                    mov      qword ptr [rbp - 0x18], rax
  000017a2:  488945f0                    mov      qword ptr [rbp - 0x10], rax
  000017a6:  448d4010                    lea      r8d, [rax + 0x10]
  000017aa:  488945f8                    mov      qword ptr [rbp - 8], rax
  000017ae:  48894500                    mov      qword ptr [rbp], rax
  000017b2:  48894508                    mov      qword ptr [rbp + 8], rax
  000017b6:  48894510                    mov      qword ptr [rbp + 0x10], rax
  000017ba:  48894518                    mov      qword ptr [rbp + 0x18], rax
  000017be:  48894530                    mov      qword ptr [rbp + 0x30], rax
  000017c2:  48894538                    mov      qword ptr [rbp + 0x38], rax
  000017c6:  66660f1f840000000000        nop      word ptr [rax + rax]
  000017d0:  428d0ccd00000000            lea      ecx, [r9*8]
  000017d8:  8bc6                        mov      eax, esi
  000017da:  d3e8                        shr      eax, cl
  000017dc:  418d48f8                    lea      ecx, [r8 - 8]
  000017e0:  8842ff                      mov      byte ptr [rdx - 1], al
  000017e3:  488d5204                    lea      rdx, [rdx + 4]
  000017e7:  8bc6                        mov      eax, esi
  000017e9:  4183c104                    add      r9d, 4
  000017ed:  d3e8                        shr      eax, cl
  000017ef:  418bc8                      mov      ecx, r8d
  000017f2:  8842fc                      mov      byte ptr [rdx - 4], al
  000017f5:  8bc6                        mov      eax, esi
  000017f7:  d3e8                        shr      eax, cl
  000017f9:  418d4808                    lea      ecx, [r8 + 8]
  000017fd:  8842fd                      mov      byte ptr [rdx - 3], al
  00001800:  4183c020                    add      r8d, 0x20
  00001804:  8bc6                        mov      eax, esi
  00001806:  d3e8                        shr      eax, cl
  00001808:  8842fe                      mov      byte ptr [rdx - 2], al
  0000180b:  4183f904                    cmp      r9d, 4
  0000180f:  72bf                        jb       0x17d0
  00001811:  488d4c2468                  lea      rcx, [rsp + 0x68]
  00001816:  e8854c0300                  call     0x364a0  ; fn_0x364a0
  0000181b:  41b804000000                mov      r8d, 4
  00001821:  488d55e0                    lea      rdx, [rbp - 0x20]
  00001825:  488d4c2468                  lea      rcx, [rsp + 0x68]
  0000182a:  e8c14c0300                  call     0x364f0  ; fn_0x364f0
  0000182f:  41b809000000                mov      r8d, 9
  00001835:  488d15dc115300              lea      rdx, [rip + 0x5311dc]  ; "123GOODIX"
  0000183c:  488d4c2468                  lea      rcx, [rsp + 0x68]
  00001841:  e8aa4c0300                  call     0x364f0  ; fn_0x364f0
  00001846:  488d55e0                    lea      rdx, [rbp - 0x20]  ; W"쇨͌䄀স"
  0000184a:  488d4c2468                  lea      rcx, [rsp + 0x68]
  0000184f:  e8bc430300                  call     0x35c10  ; fn_0x35c10
  00001854:  0f2845e0                    movaps   xmm0, xmmword ptr [rbp - 0x20]
  00001858:  0f57c9                      xorps    xmm1, xmm1
  0000185b:  0f114530                    movups   xmmword ptr [rbp + 0x30], xmm0
  0000185f:  660f73d808                  psrldq   xmm0, 8
  00001864:  66480f7ec0                  movq     rax, xmm0
  00001869:  660f7f4d00                  movdqa   xmmword ptr [rbp], xmm1
  0000186e:  488bc8                      mov      rcx, rax
  00001871:  0f57c0                      xorps    xmm0, xmm0
  00001874:  48c1e938                    shr      rcx, 0x38
  00001878:  4032ce                      xor      cl, sil
  0000187b:  48c1e838                    shr      rax, 0x38
  0000187f:  80e10f                      and      cl, 0xf
  00001882:  660f7f45f0                  movdqa   xmmword ptr [rbp - 0x10], xmm0
  00001887:  32c8                        xor      cl, al
  00001889:  660f7f4510                  movdqa   xmmword ptr [rbp + 0x10], xmm0
  0000188e:  884d3f                      mov      byte ptr [rbp + 0x3f], cl
  00001891:  488d4c2468                  lea      rcx, [rsp + 0x68]  ; W"喍䗠캋赈聍ퟨˮ謀藘瓀䠒֍ᄎS륁ɍ"
  00001896:  0f105530                    movups   xmm2, xmmword ptr [rbp + 0x30]
  0000189a:  410f1117                    movups   xmmword ptr [r15], xmm2
  0000189e:  0f2955e0                    movaps   xmmword ptr [rbp - 0x20], xmm2
  000018a2:  e8f94b0300                  call     0x364a0  ; fn_0x364a0
  000018a7:  41b840000000                mov      r8d, 0x40
  000018ad:  488d55e0                    lea      rdx, [rbp - 0x20]
  000018b1:  488d4c2468                  lea      rcx, [rsp + 0x68]
  000018b6:  e8354c0300                  call     0x364f0  ; fn_0x364f0
  000018bb:  41b810000000                mov      r8d, 0x10
  000018c1:  488d5520                    lea      rdx, [rbp + 0x20]
  000018c5:  488d4c2468                  lea      rcx, [rsp + 0x68]
  000018ca:  e8214c0300                  call     0x364f0  ; fn_0x364f0
  000018cf:  488d55e0                    lea      rdx, [rbp - 0x20]
  000018d3:  488d4c2468                  lea      rcx, [rsp + 0x68]
  000018d8:  e833430300                  call     0x35c10  ; fn_0x35c10
  000018dd:  33c0                        xor      eax, eax
  000018df:  488d55e0                    lea      rdx, [rbp - 0x20]
  000018e3:  488d4c2468                  lea      rcx, [rsp + 0x68]  ; W"赈聍ߨ˭謀藘瓀䠒֍ᄒS륁ɘ"
  000018e8:  48894520                    mov      qword ptr [rbp + 0x20], rax  ; W"謀藘瓀䠒֍ᄎS륁ɍ"
  000018ec:  48894528                    mov      qword ptr [rbp + 0x28], rax
  000018f0:  448d4020                    lea      r8d, [rax + 0x20]  ; W"֍ᄎS륁ɍ"
  000018f4:  e8e3460300                  call     0x35fdc  ; fn_0x35fdc
  000018f9:  448b4708                    mov      r8d, dword ptr [rdi + 8]
  000018fd:  488d55e0                    lea      rdx, [rbp - 0x20]
  00001901:  458bce                      mov      r9d, r14d
  00001904:  488d4d80                    lea      rcx, [rbp - 0x80]
  00001908:  e8d7ee0200                  call     0x307e4  ; fn_0x307e4
  0000190d:  8bd8                        mov      ebx, eax
  0000190f:  85c0                        test     eax, eax
  00001911:  7412                        je       0x1925
  00001913:  488d050e115300              lea      rax, [rip + 0x53110e]  ; "mbedtls_cipher_setkey() returned error"
  0000191a:  41b94d020000                mov      r9d, 0x24d
  00001920:  e91e020000                  jmp      0x1b43
  00001925:  41b810000000                mov      r8d, 0x10
  0000192b:  488d5530                    lea      rdx, [rbp + 0x30]
  0000192f:  488d4d80                    lea      rcx, [rbp - 0x80]
  00001933:  e858ed0200                  call     0x30690  ; fn_0x30690
  00001938:  8bd8                        mov      ebx, eax
  0000193a:  85c0                        test     eax, eax
  0000193c:  7412                        je       0x1950
  0000193e:  488d050b115300              lea      rax, [rip + 0x53110b]  ; "mbedtls_cipher_set_iv() returned error"
  00001945:  41b953020000                mov      r9d, 0x253
  0000194b:  e9f3010000                  jmp      0x1b43
  00001950:  488d4d80                    lea      rcx, [rbp - 0x80]
  00001954:  e807ed0200                  call     0x30660  ; fn_0x30660
  00001959:  8bd8                        mov      ebx, eax
  0000195b:  85c0                        test     eax, eax
  0000195d:  7412                        je       0x1971
  0000195f:  488d0512115300              lea      rax, [rip + 0x531112]  ; "mbedtls_cipher_reset() returned error"
  00001966:  41b958020000                mov      r9d, 0x258
  0000196c:  e9d2010000                  jmp      0x1b43
  00001971:  33ff                        xor      edi, edi
  00001973:  48c744246000000000          mov      qword ptr [rsp + 0x60], 0
  0000197c:  4533f6                      xor      r14d, r14d
  0000197f:  4983c710                    add      r15, 0x10
  00001983:  85f6                        test     esi, esi
  00001985:  0f84a7000000                je       0x1a32
  0000198b:  0f1f440000                  nop      dword ptr [rax + rax]
  00001990:  488b5580                    mov      rdx, qword ptr [rbp - 0x80]  ; W"֍ᄎS륁ɍ"
  00001994:  4885d2                      test     rdx, rdx
  00001997:  7405                        je       0x199e
  00001999:  8b4220                      mov      eax, dword ptr [rdx + 0x20]
  0000199c:  eb02                        jmp      0x19a0
  0000199e:  33c0                        xor      eax, eax
  000019a0:  488bce                      mov      rcx, rsi
  000019a3:  482bcf                      sub      rcx, rdi
  000019a6:  483bc8                      cmp      rcx, rax
  000019a9:  760e                        jbe      0x19b9
  000019ab:  4885d2                      test     rdx, rdx
  000019ae:  7405                        je       0x19b5
  000019b0:  8b4220                      mov      eax, dword ptr [rdx + 0x20]  ; W"휃譍䣄䒉․컨˯謀藘࿀螅"
  000019b3:  eb08                        jmp      0x19bd
  000019b5:  33c0                        xor      eax, eax
  000019b7:  eb04                        jmp      0x19bd
  000019b9:  8bc6                        mov      eax, esi
  000019bb:  2bc7                        sub      eax, edi
  000019bd:  488b542448                  mov      rdx, qword ptr [rsp + 0x48]
  000019c2:  4c8d4d40                    lea      r9, [rbp + 0x40]
  000019c6:  4c63e0                      movsxd   r12, eax
  000019c9:  488d4d80                    lea      rcx, [rbp - 0x80]
  000019cd:  488d442460                  lea      rax, [rsp + 0x60]
  000019d2:  4803d7                      add      rdx, rdi
  000019d5:  4d8bc4                      mov      r8, r12
  000019d8:  4889442420                  mov      qword ptr [rsp + 0x20], rax
  000019dd:  e8ceef0200                  call     0x309b0  ; fn_0x309b0
  000019e2:  8bd8                        mov      ebx, eax
  000019e4:  85c0                        test     eax, eax
  000019e6:  0f8587000000                jne      0x1a73
  000019ec:  4c8b442460                  mov      r8, qword ptr [rsp + 0x60]
  000019f1:  488d5540                    lea      rdx, [rbp + 0x40]  ; W"怤赈䁕赈聍哨˧謀藘瓀䠻֍ႯS륁ʁ"
  000019f5:  488d4c2468                  lea      rcx, [rsp + 0x68]  ; W"֍ၠS륁ɶ"
  000019fa:  e801490300                  call     0x36300  ; fn_0x36300
  000019ff:  4c8b442460                  mov      r8, qword ptr [rsp + 0x60]  ; W"ၠS륁ɶ"
  00001a04:  4903fc                      add      rdi, r12
  00001a07:  4c8b642450                  mov      r12, qword ptr [rsp + 0x50]
  00001a0c:  4d03f0                      add      r14, r8
  00001a0f:  418b0424                    mov      eax, dword ptr [r12]
  00001a13:  4c3bf0                      cmp      r14, rax
  00001a16:  7744                        ja       0x1a5c
  00001a18:  488d5540                    lea      rdx, [rbp + 0x40]
  00001a1c:  498bcf                      mov      rcx, r15
  00001a1f:  e8ac9d0500                  call     0x5b7d0  ; fn_0x5b7d0
  00001a24:  4c037c2460                  add      r15, qword ptr [rsp + 0x60]
  00001a29:  483bfe                      cmp      rdi, rsi
  00001a2c:  0f825effffff                jb       0x1990
  00001a32:  4c8d442460                  lea      r8, [rsp + 0x60]
  00001a37:  488d5540                    lea      rdx, [rbp + 0x40]
  00001a3b:  488d4d80                    lea      rcx, [rbp - 0x80]
  00001a3f:  e854e70200                  call     0x30198  ; fn_0x30198
  00001a44:  8bd8                        mov      ebx, eax
  00001a46:  85c0                        test     eax, eax
  00001a48:  743b                        je       0x1a85
  00001a4a:  488d05af105300              lea      rax, [rip + 0x5310af]  ; "mbedtls_cipher_finish() returned error"
  00001a51:  41b981020000                mov      r9d, 0x281
  00001a57:  e9e7000000                  jmp      0x1b43
  00001a5c:  bbfaffefff                  mov      ebx, 0xffeffffa
  00001a61:  488d0560105300              lea      rax, [rip + 0x531060]  ; "pDataEncryptedLength too small, no enough out memory."
  00001a68:  41b976020000                mov      r9d, 0x276
  00001a6e:  e9d0000000                  jmp      0x1b43
  00001a73:  488d0526105300              lea      rax, [rip + 0x531026]  ; "mbedtls_cipher_update() returned error"
  00001a7a:  41b96b020000                mov      r9d, 0x26b
  00001a80:  e9be000000                  jmp      0x1b43
  00001a85:  4c8b442460                  mov      r8, qword ptr [rsp + 0x60]
  00001a8a:  488d5540                    lea      rdx, [rbp + 0x40]
  00001a8e:  488d4c2468                  lea      rcx, [rsp + 0x68]
  00001a93:  e868480300                  call     0x36300  ; fn_0x36300
  00001a98:  4c8b442460                  mov      r8, qword ptr [rsp + 0x60]
  00001a9d:  418b0424                    mov      eax, dword ptr [r12]
  00001aa1:  4d03f0                      add      r14, r8
  00001aa4:  4c3bf0                      cmp      r14, rax
  00001aa7:  7617                        jbe      0x1ac0
  00001aa9:  bbfaffefff                  mov      ebx, 0xffeffffa
  00001aae:  488d0513105300              lea      rax, [rip + 0x531013]  ; "pDataEncryptedLength too small, no enough out memory."
  00001ab5:  41b98a020000                mov      r9d, 0x28a
  00001abb:  e983000000                  jmp      0x1b43
  00001ac0:  488d5540                    lea      rdx, [rbp + 0x40]
  00001ac4:  498bcf                      mov      rcx, r15
  00001ac7:  e8049d0500                  call     0x5b7d0  ; fn_0x5b7d0
  00001acc:  4c037c2460                  add      r15, qword ptr [rsp + 0x60]
  00001ad1:  488d55e0                    lea      rdx, [rbp - 0x20]
  00001ad5:  488d4c2468                  lea      rcx, [rsp + 0x68]
  00001ada:  e861420300                  call     0x35d40  ; fn_0x35d40
  00001adf:  488b7c2458                  mov      rdi, qword ptr [rsp + 0x58]
  00001ae4:  488bcf                      mov      rcx, rdi
  00001ae7:  e81c420300                  call     0x35d08  ; fn_0x35d08
  00001aec:  0fb6c0                      movzx    eax, al
  00001aef:  4c03f0                      add      r14, rax
  00001af2:  418b0424                    mov      eax, dword ptr [r12]
  00001af6:  4c3bf0                      cmp      r14, rax
  00001af9:  7614                        jbe      0x1b0f
  00001afb:  bbfaffefff                  mov      ebx, 0xffeffffa
  00001b00:  488d05c10f5300              lea      rax, [rip + 0x530fc1]  ; "pDataEncryptedLength too small, no enough out memory."
  00001b07:  41b996020000                mov      r9d, 0x296
  00001b0d:  eb34                        jmp      0x1b43
  00001b0f:  488bcf                      mov      rcx, rdi
  00001b12:  e8f1410300                  call     0x35d08  ; fn_0x35d08
  00001b17:  440fb6c0                    movzx    r8d, al
  00001b1b:  488d55e0                    lea      rdx, [rbp - 0x20]  ; W"䣿֍࿁S륁ʖ"
  00001b1f:  498bcf                      mov      rcx, r15
  00001b22:  e8a99c0500                  call     0x5b7d0  ; fn_0x5b7d0
  00001b27:  418d4610                    lea      eax, [r14 + 0x10]
  00001b2b:  41890424                    mov      dword ptr [r12], eax
  00001b2f:  eb2f                        jmp      0x1b60
  00001b31:  488d05f00d5300              lea      rax, [rip + 0x530df0]  ; "Invalid parameters"
  00001b38:  41b9f4010000                mov      r9d, 0x1f4
  00001b3e:  bbffffefff                  mov      ebx, 0xffefffff
  00001b43:  4c8d05ce0d5300              lea      r8, [rip + 0x530dce]  ; "SecWhiteEncrypt"
  00001b4a:  4889442420                  mov      qword ptr [rsp + 0x20], rax
  00001b4f:  488d151a0d5300              lea      rdx, [rip + 0x530d1a]  ; "f:\git\winfpsec\winfpsec\seclibs\sourceall\sourcecode\seccipher.c"
  00001b56:  b904000000                  mov      ecx, 4
  00001b5b:  e870020000                  call     0x1dd0  ; fn_0x1dd0
  00001b60:  488d05c10f5300              lea      rax, [rip + 0x530fc1]  ; "<= GoodixDataAesEncrypt"
  00001b67:  41b9a1020000                mov      r9d, 0x2a1
  00001b6d:  4c8d05a40d5300              lea      r8, [rip + 0x530da4]  ; "SecWhiteEncrypt"
  00001b74:  4889442420                  mov      qword ptr [rsp + 0x20], rax
  00001b79:  488d15f00c5300              lea      rdx, [rip + 0x530cf0]  ; "f:\git\winfpsec\winfpsec\seclibs\sourceall\sourcecode\seccipher.c"
  00001b80:  b904000000                  mov      ecx, 4
  00001b85:  e846020000                  call     0x1dd0  ; fn_0x1dd0
  00001b8a:  33d2                        xor      edx, edx
  00001b8c:  488d4d40                    lea      rcx, [rbp + 0x40]
  00001b90:  41b800040000                mov      r8d, 0x400
  00001b96:  e8e5a00500                  call     0x5bc80  ; fn_0x5bc80
  00001b9b:  4c8bbc2458050000            mov      r15, qword ptr [rsp + 0x558]
  00001ba3:  33c0                        xor      eax, eax
  00001ba5:  4c8bb42460050000            mov      r14, qword ptr [rsp + 0x560]
  00001bad:  4c8bac2468050000            mov      r13, qword ptr [rsp + 0x568]
  00001bb5:  4c8ba42470050000            mov      r12, qword ptr [rsp + 0x570]
  00001bbd:  488bbc2478050000            mov      rdi, qword ptr [rsp + 0x578]
  00001bc5:  488bb42480050000            mov      rsi, qword ptr [rsp + 0x580]
  00001bcd:  488945e0                    mov      qword ptr [rbp - 0x20], rax
  00001bd1:  488945e8                    mov      qword ptr [rbp - 0x18], rax
  00001bd5:  488945f0                    mov      qword ptr [rbp - 0x10], rax
  00001bd9:  488945f8                    mov      qword ptr [rbp - 8], rax
  00001bdd:  48894500                    mov      qword ptr [rbp], rax
  00001be1:  48894508                    mov      qword ptr [rbp + 8], rax  ; W"䐹䀤፴赈聍냨˨䠀䲍栤拨̀謀䣃趋р"
  00001be5:  48894510                    mov      qword ptr [rbp + 0x10], rax  ; W"˨䠀䲍栤拨̀謀䣃趋р"
  00001be9:  48894518                    mov      qword ptr [rbp + 0x18], rax  ; W"謀䣃趋р"
  00001bed:  39442440                    cmp      dword ptr [rsp + 0x40], eax
  00001bf1:  7413                        je       0x1c06
  00001bf3:  488d4d80                    lea      rcx, [rbp - 0x80]
  00001bf7:  e8b0e80200                  call     0x304ac  ; fn_0x304ac
  00001bfc:  488d4c2468                  lea      rcx, [rsp + 0x68]
  00001c01:  e862400300                  call     0x35c68  ; fn_0x35c68
  00001c06:  8bc3                        mov      eax, ebx
  00001c08:  488b8d40040000              mov      rcx, qword ptr [rbp + 0x440]
  00001c0f:  4833cc                      xor      rcx, rsp
  00001c12:  e8598f0500                  call     0x5ab70  ; fn_0x5ab70
  00001c17:  4881c488050000              add      rsp, 0x588
  00001c1e:  5b                          pop      rbx
  00001c1f:  5d                          pop      rbp
  00001c20:  c3                          ret      
  00001c21:  cc                          int3     

; --- function boundary ---

  00001c22:  cc                          int3     

; --- function boundary ---

  00001c23:  cc                          int3     

; --- function boundary ---

  00001c24:  cc                          int3     

; --- function boundary ---

  00001c25:  cc                          int3     

; --- function boundary ---

  00001c26:  cc                          int3     

; --- function boundary ---

  00001c27:  cc                          int3     

; --- function boundary ---

  00001c28:  cc                          int3     

; --- function boundary ---

  00001c29:  cc                          int3     

; --- function boundary ---

  00001c2a:  cc                          int3     

; --- function boundary ---

  00001c2b:  cc                          int3     

; --- function boundary ---

  00001c2c:  cc                          int3     

; --- function boundary ---

  00001c2d:  cc                          int3     

; --- function boundary ---

  00001c2e:  cc                          int3     

; --- function boundary ---

  00001c2f:  cc                          int3     