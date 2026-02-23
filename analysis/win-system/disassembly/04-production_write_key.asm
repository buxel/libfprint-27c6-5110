; gfspi.dll - production_write_key function
; Generates random PSK, seals with DPAPI, writes to MCU, caches to file
; Flow: 0.generate random psk -> 1.seal psk -> 2.process encrypted psk
;       -> 3.write to mcu -> write Goodix_Cache.bin
; Image base: 0x180000000
; String 'production_write_key' at RVA 0x31b760
; XREFs: ['0x29376', '0x293c7', '0x2942f', '0x29470', '0x294c8', '0x29561', '0x295ac', '0x295ed', '0x29645', '0x296f0']
; Function start: RVA 0x29268
; Function end: RVA 0x29868

  00029268:  4057                        push     rdi
  0002926a:  4881ec60030000              sub      rsp, 0x360
  00029271:  488b05d0065100              mov      rax, qword ptr [rip + 0x5106d0]
  00029278:  4833c4                      xor      rax, rsp
  0002927b:  4889842450030000            mov      qword ptr [rsp + 0x350], rax  ; W"⍉/襈⑄䠰䓇⠤"
  00029283:  48c784248000000000000000    mov      qword ptr [rsp + 0x80], 0
  0002928f:  c744247000000000            mov      dword ptr [rsp + 0x70], 0
  00029297:  488d8424d0020000            lea      rax, [rsp + 0x2d0]
  0002929f:  488bf8                      mov      rdi, rax
  000292a2:  33c0                        xor      eax, eax
  000292a4:  b980000000                  mov      ecx, 0x80
  000292a9:  f3aa                        rep stosb byte ptr [rdi], al
  000292ab:  48c744246800000000          mov      qword ptr [rsp + 0x68], 0
  000292b4:  c744245400080000            mov      dword ptr [rsp + 0x54], 0x800
  000292bc:  c7442450010000ff            mov      dword ptr [rsp + 0x50], 0xff000001
  000292c4:  c68424a802000000            mov      byte ptr [rsp + 0x2a8], 0
  000292cc:  c68424a902000000            mov      byte ptr [rsp + 0x2a9], 0
  000292d4:  488d8424aa020000            lea      rax, [rsp + 0x2aa]  ; W"證⑄襐⑄䠸֍⌺/襈⑄䠰䓇⠤"
  000292dc:  488bf8                      mov      rdi, rax
  000292df:  33c0                        xor      eax, eax
  000292e1:  b91e000000                  mov      ecx, 0x1e
  000292e6:  f3aa                        rep stosb byte ptr [rdi], al
  000292e8:  488d8424a0020000            lea      rax, [rsp + 0x2a0]  ; W"֍⌺/襈⑄䠰䓇⠤"
  000292f0:  488bf8                      mov      rdi, rax
  000292f3:  33c0                        xor      eax, eax
  000292f5:  b908000000                  mov      ecx, 8
  000292fa:  f3aa                        rep stosb byte ptr [rdi], al
  000292fc:  48c744245800000000          mov      qword ptr [rsp + 0x58], 0  ; W"⼣䠀䒉〤읈⑄("
  00029305:  48c744246000000000          mov      qword ptr [rsp + 0x60], 0
  0002930e:  c744247400000000            mov      dword ptr [rsp + 0x74], 0
  00029316:  c744247800000000            mov      dword ptr [rsp + 0x78], 0
  0002931e:  c744247080000000            mov      dword ptr [rsp + 0x70], 0x80
  00029326:  41b908000000                mov      r9d, 8
  0002932c:  4c8d8424a0020000            lea      r8, [rsp + 0x2a0]  ; W"⼣䠀䒉〤읈⑄("
  00029334:  488d542470                  lea      rdx, [rsp + 0x70]  ; W"䠀֍⏟/襈⑄䠰䓇⠤"
  00029339:  488d8c24d0020000            lea      rcx, [rsp + 0x2d0]
  00029341:  e89adcffff                  call     0x26fe0  ; fn_0x26fe0
  00029346:  89442450                    mov      dword ptr [rsp + 0x50], eax
  0002934a:  837c245000                  cmp      dword ptr [rsp + 0x50], 0
  0002934f:  7449                        je       0x2939a
  00029351:  8b442450                    mov      eax, dword ptr [rsp + 0x50]
  00029355:  89442438                    mov      dword ptr [rsp + 0x38], eax
  00029359:  488d05a0232f00              lea      rax, [rip + 0x2f23a0]  ; W"generate entropy failed with error code 0x%x"
  00029360:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00029365:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002936e:  c7442420df080000            mov      dword ptr [rsp + 0x20], 0x8df
  00029376:  4c8d0de3232f00              lea      r9, [rip + 0x2f23e3]  ; W"production_write_key"
  0002937d:  4c8d053ceb2e00              lea      r8, [rip + 0x2eeb3c]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00029384:  ba04000000                  mov      edx, 4
  00029389:  488b0df8ec5000              mov      rcx, qword ptr [rip + 0x50ecf8]
  00029390:  e8e7ccfdff                  call     0x607c  ; fn_0x607c
  00029395:  e934060000                  jmp      0x299ce
  0002939a:  488d8424d0020000            lea      rax, [rsp + 0x2d0]
  000293a2:  4889842480000000            mov      qword ptr [rsp + 0x80], rax
  000293aa:  488d05df232f00              lea      rax, [rip + 0x2f23df]  ; W"0.generate random psk"
  000293b1:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  000293b6:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000293bf:  c7442420e6080000            mov      dword ptr [rsp + 0x20], 0x8e6
  000293c7:  4c8d0d92232f00              lea      r9, [rip + 0x2f2392]  ; W"production_write_key"
  000293ce:  4c8d05ebea2e00              lea      r8, [rip + 0x2eeaeb]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000293d5:  ba08000000                  mov      edx, 8
  000293da:  488b0da7ec5000              mov      rcx, qword ptr [rip + 0x50eca7]
  000293e1:  e896ccfdff                  call     0x607c  ; fn_0x607c
  000293e6:  c744247820000000            mov      dword ptr [rsp + 0x78], 0x20
  000293ee:  8b542478                    mov      edx, dword ptr [rsp + 0x78]
  000293f2:  488d8c24a8020000            lea      rcx, [rsp + 0x2a8]
  000293fa:  e8dd090000                  call     0x29ddc  ; fn_0x29ddc
  000293ff:  89442450                    mov      dword ptr [rsp + 0x50], eax  ; W"赈븅⼣䠀䒉〤읈⑄("
  00029403:  837c245000                  cmp      dword ptr [rsp + 0x50], 0  ; W"/襈⑄䠰䓇⠤"
  00029408:  7449                        je       0x29453
  0002940a:  8b442450                    mov      eax, dword ptr [rsp + 0x50]
  0002940e:  89442438                    mov      dword ptr [rsp + 0x38], eax
  00029412:  488d05a7232f00              lea      rax, [rip + 0x2f23a7]  ; W"generate_rand failed with error code 0x%x"
  00029419:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002941e:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00029427:  c7442420eb080000            mov      dword ptr [rsp + 0x20], 0x8eb
  0002942f:  4c8d0d2a232f00              lea      r9, [rip + 0x2f232a]  ; W"production_write_key"
  00029436:  4c8d0583ea2e00              lea      r8, [rip + 0x2eea83]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  0002943d:  ba04000000                  mov      edx, 4
  00029442:  488b0d3fec5000              mov      rcx, qword ptr [rip + 0x50ec3f]
  00029449:  e82eccfdff                  call     0x607c  ; fn_0x607c
  0002944e:  e97b050000                  jmp      0x299ce
  00029453:  488d05be232f00              lea      rax, [rip + 0x2f23be]  ; W"1.seal psk "
  0002945a:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002945f:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00029468:  c7442420f0080000            mov      dword ptr [rsp + 0x20], 0x8f0
  00029470:  4c8d0de9222f00              lea      r9, [rip + 0x2f22e9]  ; W"production_write_key"
  00029477:  4c8d0542ea2e00              lea      r8, [rip + 0x2eea42]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  0002947e:  ba08000000                  mov      edx, 8
  00029483:  488b0dfeeb5000              mov      rcx, qword ptr [rip + 0x50ebfe]
  0002948a:  e8edcbfdff                  call     0x607c  ; fn_0x607c
  0002948f:  ba00080000                  mov      edx, 0x800
  00029494:  b901000000                  mov      ecx, 1
  00029499:  e87ef50300                  call     0x68a1c  ; fn_0x68a1c
  0002949e:  4889442468                  mov      qword ptr [rsp + 0x68], rax
  000294a3:  48837c246800                cmp      qword ptr [rsp + 0x68], 0
  000294a9:  7549                        jne      0x294f4
  000294ab:  488d057e232f00              lea      rax, [rip + 0x2f237e]  ; W"malloc memory failed"
  000294b2:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  000294b7:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000294c0:  c7442420f4080000            mov      dword ptr [rsp + 0x20], 0x8f4
  000294c8:  4c8d0d91222f00              lea      r9, [rip + 0x2f2291]  ; W"production_write_key"
  000294cf:  4c8d05eae92e00              lea      r8, [rip + 0x2ee9ea]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000294d6:  ba04000000                  mov      edx, 4
  000294db:  488b0da6eb5000              mov      rcx, qword ptr [rip + 0x50eba6]
  000294e2:  e895cbfdff                  call     0x607c  ; fn_0x607c
  000294e7:  c7442450fbffefff            mov      dword ptr [rsp + 0x50], 0xffeffffb  ; W"襐⑄䠸֍⌕/襈⑄䠰䓇⠤"
  000294ef:  e9da040000                  jmp      0x299ce
  000294f4:  488d442454                  lea      rax, [rsp + 0x54]  ; W"⑄䠰䓇⠤"
  000294f9:  4889442428                  mov      qword ptr [rsp + 0x28], rax  ; W"褀⑄譐⑄襔⑄䡈䓇䀤 "
  000294fe:  488b442468                  mov      rax, qword ptr [rsp + 0x68]
  00029503:  4889442420                  mov      qword ptr [rsp + 0x20], rax  ; W"⑄譐⑄襔⑄䡈䓇䀤 "
  00029508:  448b4c2470                  mov      r9d, dword ptr [rsp + 0x70]
  0002950d:  4c8b842480000000            mov      r8, qword ptr [rsp + 0x80]  ; W"䠀䒉〤읈⑄("
  00029515:  ba20000000                  mov      edx, 0x20
  0002951a:  488d8c24a8020000            lea      rcx, [rsp + 0x2a8]  ; W"荈⑼`䥵赈켅⼡䠀䒉〤읈⑄("
  00029522:  e8150c0000                  call     0x2a13c  ; fn_0x2a13c
  00029527:  89442450                    mov      dword ptr [rsp + 0x50], eax
  0002952b:  8b442454                    mov      eax, dword ptr [rsp + 0x54]  ; W"P䥴䒋値䒉㠤赈㨅⼣䠀䒉〤읈⑄("
  0002952f:  89442448                    mov      dword ptr [rsp + 0x48], eax
  00029533:  48c744244020000000          mov      qword ptr [rsp + 0x40], 0x20  ; W"쫼�粃値琀證⑄襐⑄䠸֍⌺/襈⑄䠰䓇⠤"
  0002953c:  8b442450                    mov      eax, dword ptr [rsp + 0x50]  ; W"֍⌺/襈⑄䠰䓇⠤"
  00029540:  89442438                    mov      dword ptr [rsp + 0x38], eax  ; W"쫼�粃値琀證⑄襐⑄䠸֍⌺/襈⑄䠰䓇⠤"
  00029544:  488d0515232f00              lea      rax, [rip + 0x2f2315]  ; W"seal psk, ret 0x%x length before %d, length after:%d"
  0002954b:  4889442430                  mov      qword ptr [rsp + 0x30], rax  ; W"粃値琀證⑄襐⑄䠸֍⌺/襈⑄䠰䓇⠤"
  00029550:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0  ; W"⑼P䥴䒋値䒉㠤赈㨅⼣䠀䒉〤읈⑄("
  00029559:  c7442420fa080000            mov      dword ptr [rsp + 0x20], 0x8fa  ; W"⑼P䥴䒋値䒉㠤赈㨅⼣䠀䒉〤읈⑄("
  00029561:  4c8d0df8212f00              lea      r9, [rip + 0x2f21f8]  ; W"production_write_key"
  00029568:  4c8d0551e92e00              lea      r8, [rip + 0x2ee951]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  0002956f:  ba08000000                  mov      edx, 8
  00029574:  488b0d0deb5000              mov      rcx, qword ptr [rip + 0x50eb0d]
  0002957b:  e8fccafdff                  call     0x607c  ; fn_0x607c
  00029580:  837c245000                  cmp      dword ptr [rsp + 0x50], 0  ; W"/襈⑄䠰䓇⠤"
  00029585:  7449                        je       0x295d0
  00029587:  8b442450                    mov      eax, dword ptr [rsp + 0x50]
  0002958b:  89442438                    mov      dword ptr [rsp + 0x38], eax
  0002958f:  488d053a232f00              lea      rax, [rip + 0x2f233a]  ; W"gf_sgx_seal_data failed with error 0x%x"
  00029596:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002959b:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000295a4:  c7442420fd080000            mov      dword ptr [rsp + 0x20], 0x8fd
  000295ac:  4c8d0dad212f00              lea      r9, [rip + 0x2f21ad]  ; W"production_write_key"
  000295b3:  4c8d0506e92e00              lea      r8, [rip + 0x2ee906]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000295ba:  ba04000000                  mov      edx, 4
  000295bf:  488b0dc2ea5000              mov      rcx, qword ptr [rip + 0x50eac2]
  000295c6:  e8b1cafdff                  call     0x607c  ; fn_0x607c
  000295cb:  e9fe030000                  jmp      0x299ce
  000295d0:  488d0549232f00              lea      rax, [rip + 0x2f2349]  ; W"2.process encrypted psk"
  000295d7:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  000295dc:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000295e5:  c744242002090000            mov      dword ptr [rsp + 0x20], 0x902
  000295ed:  4c8d0d6c212f00              lea      r9, [rip + 0x2f216c]  ; W"production_write_key"
  000295f4:  4c8d05c5e82e00              lea      r8, [rip + 0x2ee8c5]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000295fb:  ba08000000                  mov      edx, 8
  00029600:  488b0d81ea5000              mov      rcx, qword ptr [rip + 0x50ea81]
  00029607:  e870cafdff                  call     0x607c  ; fn_0x607c
  0002960c:  ba00080000                  mov      edx, 0x800
  00029611:  b901000000                  mov      ecx, 1
  00029616:  e801f40300                  call     0x68a1c  ; fn_0x68a1c
  0002961b:  4889442458                  mov      qword ptr [rsp + 0x58], rax
  00029620:  48837c245800                cmp      qword ptr [rsp + 0x58], 0  ; W"⑄의р߸"
  00029626:  7549                        jne      0x29671
  00029628:  488d0521232f00              lea      rax, [rip + 0x2f2321]  ; W"p_tlv_psk_wb malloc failed!"
  0002962f:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00029634:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  0002963d:  c744242006090000            mov      dword ptr [rsp + 0x20], 0x906
  00029645:  4c8d0d14212f00              lea      r9, [rip + 0x2f2114]  ; W"production_write_key"
  0002964c:  4c8d056de82e00              lea      r8, [rip + 0x2ee86d]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  00029653:  ba04000000                  mov      edx, 4
  00029658:  488b0d29ea5000              mov      rcx, qword ptr [rip + 0x50ea29]
  0002965f:  e818cafdff                  call     0x607c  ; fn_0x607c
  00029664:  c7442450fbffefff            mov      dword ptr [rsp + 0x50], 0xffeffffb  ; W"р䒉䠤읈⑄⁀"
  0002966c:  e95d030000                  jmp      0x299ce
  00029671:  488b442458                  mov      rax, qword ptr [rsp + 0x58]
  00029676:  c700030001bb                mov      dword ptr [rax], 0xbb010003
  0002967c:  488b442458                  mov      rax, qword ptr [rsp + 0x58]  ; W"䠀䒉〤읈⑄("
  00029681:  c74004f8070000              mov      dword ptr [rax + 4], 0x7f8  ; W"䡘삃䠄䲋堤荈ࣁ譌䳈솋₺"
  00029688:  488b442458                  mov      rax, qword ptr [rsp + 0x58]
  0002968d:  4883c004                    add      rax, 4
  00029691:  488b4c2458                  mov      rcx, qword ptr [rsp + 0x58]
  00029696:  4883c108                    add      rcx, 8
  0002969a:  4c8bc8                      mov      r9, rax
  0002969d:  4c8bc1                      mov      r8, rcx
  000296a0:  ba20000000                  mov      edx, 0x20
  000296a5:  488d8c24a8020000            lea      rcx, [rsp + 0x2a8]
  000296ad:  e8fe7efdff                  call     0x15b0  ; fn_0x15b0
  000296b2:  89442450                    mov      dword ptr [rsp + 0x50], eax
  000296b6:  488b442458                  mov      rax, qword ptr [rsp + 0x58]
  000296bb:  8b4004                      mov      eax, dword ptr [rax + 4]
  000296be:  89442448                    mov      dword ptr [rsp + 0x48], eax
  000296c2:  48c744244020000000          mov      qword ptr [rsp + 0x40], 0x20
  000296cb:  8b442450                    mov      eax, dword ptr [rsp + 0x50]  ; W"䒉㠤赈똅ԁ䠀䒉〤읈⑄("
  000296cf:  89442438                    mov      dword ptr [rsp + 0x38], eax
  000296d3:  488d0596010500              lea      rax, [rip + 0x50196]  ; W"process ret 0x%x length before %d, length after:%d"
  000296da:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  000296df:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000296e8:  c74424200d090000            mov      dword ptr [rsp + 0x20], 0x90d
  000296f0:  4c8d0d69202f00              lea      r9, [rip + 0x2f2069]  ; W"production_write_key"
  000296f7:  4c8d05c2e72e00              lea      r8, [rip + 0x2ee7c2]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000296fe:  ba08000000                  mov      edx, 8
  00029703:  488b0d7ee95000              mov      rcx, qword ptr [rip + 0x50e97e]
  0002970a:  e86dc9fdff                  call     0x607c  ; fn_0x607c
  0002970f:  837c245000                  cmp      dword ptr [rsp + 0x50], 0  ; W"赈ᴅ⼢䠀䒉〤읈⑄("
  00029714:  744e                        je       0x29764
  00029716:  8b4c2450                    mov      ecx, dword ptr [rsp + 0x50]  ; W"䠀䒉〤읈⑄("
  0002971a:  e8b9fa0300                  call     0x691d8  ; fn_0x691d8
  0002971f:  89442438                    mov      dword ptr [rsp + 0x38], eax
  00029723:  488d05b6010500              lea      rax, [rip + 0x501b6]  ; W"[FAILED] WhiteBox encryption failed with 0x%x."
  0002972a:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002972f:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00029738:  c744242011090000            mov      dword ptr [rsp + 0x20], 0x911
  00029740:  4c8d0d19202f00              lea      r9, [rip + 0x2f2019]  ; W"production_write_key"
  00029747:  4c8d0572e72e00              lea      r8, [rip + 0x2ee772]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  0002974e:  ba04000000                  mov      edx, 4
  00029753:  488b0d2ee95000              mov      rcx, qword ptr [rip + 0x50e92e]
  0002975a:  e81dc9fdff                  call     0x607c  ; fn_0x607c
  0002975f:  e96a020000                  jmp      0x299ce
  00029764:  488d051d222f00              lea      rax, [rip + 0x2f221d]  ; W"3.write to mcu"
  0002976b:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00029770:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0  ; W"⑄䡔䲋堤䦋䠄䒍᠈䒉琤䒋琤킋ƹ"
  00029779:  c744242016090000            mov      dword ptr [rsp + 0x20], 0x916  ; W"⑄䡔䲋堤䦋䠄䒍᠈䒉琤䒋琤킋ƹ"
  00029781:  4c8d0dd81f2f00              lea      r9, [rip + 0x2f1fd8]  ; W"production_write_key"
  00029788:  4c8d0531e72e00              lea      r8, [rip + 0x2ee731]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  0002978f:  ba08000000                  mov      edx, 8
  00029794:  488b0dede85000              mov      rcx, qword ptr [rip + 0x50e8ed]
  0002979b:  e8dcc8fdff                  call     0x607c  ; fn_0x607c
  000297a0:  8b442454                    mov      eax, dword ptr [rsp + 0x54]
  000297a4:  488b4c2458                  mov      rcx, qword ptr [rsp + 0x58]
  000297a9:  8b4904                      mov      ecx, dword ptr [rcx + 4]
  000297ac:  488d440818                  lea      rax, [rax + rcx + 0x18]  ; W"䡠粃怤甀䡉֍⇏/襈⑄䠰䓇⠤"
  000297b1:  89442474                    mov      dword ptr [rsp + 0x74], eax  ; W"䡔삃䠈䲋怤䆉謄⑄䡔䲋怤荈ࣁ譄䣀咋栤胨̟謀⑄䡔䲋怤赈ń䄈ࢸ"
  000297b5:  8b442474                    mov      eax, dword ptr [rsp + 0x74]  ; W"䠈䲋怤䆉謄⑄䡔䲋怤荈ࣁ譄䣀咋栤胨̟謀⑄䡔䲋怤赈ń䄈ࢸ"
  000297b9:  8bd0                        mov      edx, eax
  000297bb:  b901000000                  mov      ecx, 1
  000297c0:  e857f20300                  call     0x68a1c  ; fn_0x68a1c
  000297c5:  4889442460                  mov      qword ptr [rsp + 0x60], rax
  000297ca:  48837c246000                cmp      qword ptr [rsp + 0x60], 0
  000297d0:  7549                        jne      0x2981b
  000297d2:  488d05cf212f00              lea      rax, [rip + 0x2f21cf]  ; W"p_data_to_mcu malloc failed"
  000297d9:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  000297de:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000297e7:  c74424202f090000            mov      dword ptr [rsp + 0x20], 0x92f
  000297ef:  4c8d0d6a1f2f00              lea      r9, [rip + 0x2f1f6a]  ; W"production_write_key"
  000297f6:  4c8d05c3e62e00              lea      r8, [rip + 0x2ee6c3]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000297fd:  ba04000000                  mov      edx, 4
  00029802:  488b0d7fe85000              mov      rcx, qword ptr [rip + 0x50e87f]
  00029809:  e86ec8fdff                  call     0x607c  ; fn_0x607c
  0002980e:  c7442450fbffefff            mov      dword ptr [rsp + 0x50], 0xffeffffb
  00029816:  e9b3010000                  jmp      0x299ce
  0002981b:  488b442460                  mov      rax, qword ptr [rsp + 0x60]
  00029820:  c700020001bb                mov      dword ptr [rax], 0xbb010002
  00029826:  8b442454                    mov      eax, dword ptr [rsp + 0x54]
  0002982a:  4883c008                    add      rax, 8
  0002982e:  488b4c2460                  mov      rcx, qword ptr [rsp + 0x60]
  00029833:  894104                      mov      dword ptr [rcx + 4], eax
  00029836:  8b442454                    mov      eax, dword ptr [rsp + 0x54]
  0002983a:  488b4c2460                  mov      rcx, qword ptr [rsp + 0x60]
  0002983f:  4883c108                    add      rcx, 8
  00029843:  448bc0                      mov      r8d, eax
  00029846:  488b542468                  mov      rdx, qword ptr [rsp + 0x68]
  0002984b:  e8801f0300                  call     0x5b7d0  ; fn_0x5b7d0
  00029850:  8b442454                    mov      eax, dword ptr [rsp + 0x54]  ; W"褀⑄荐⑼P乴䲋値ᯨϹ褀⑄䠸֍℘/襈⑄䠰䓇⠤"
  00029854:  488b4c2460                  mov      rcx, qword ptr [rsp + 0x60]
  00029859:  488d440108                  lea      rax, [rcx + rax + 8]
  0002985e:  41b808000000                mov      r8d, 8