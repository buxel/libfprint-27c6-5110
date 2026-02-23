; gfspi.dll - generate_entropy2 function
; Generates entropy (rootkey) used as DPAPI optional entropy parameter
; Contains XOR loops that derive a 16-byte value from static data tables
; Then hashes (SHA-256) the result to produce final entropy
; Called before gf_seal_data and gf_unseal_data
; Image base: 0x180000000
; String 'generate_entropy2' at RVA 0x31b5d0
; XREFs: ['0x270c6', '0x2712c', '0x2718f', '0x271d0', '0x27321', '0x273bc']
; Function start: RVA 0x26fe0
; Function end: RVA 0x2745e

  00026fe0:  44894c2420                  mov      dword ptr [rsp + 0x20], r9d
  00026fe5:  4c89442418                  mov      qword ptr [rsp + 0x18], r8  ; W"䠀쐳襈⒄È"
  00026fea:  4889542410                  mov      qword ptr [rsp + 0x10], rdx  ; W"⥅Q㍈䣄蒉젤"
  00026fef:  48894c2408                  mov      qword ptr [rsp + 8], rcx  ; W"譈䔅儩䠀쐳襈⒄È"
  00026ff4:  57                          push     rdi
  00026ff5:  4881ecd0000000              sub      rsp, 0xd0
  00026ffc:  488b0545295100              mov      rax, qword ptr [rip + 0x512945]
  00027003:  4833c4                      xor      rax, rsp
  00027006:  48898424c8000000            mov      qword ptr [rsp + 0xc8], rax
  0002700e:  c744244000000000            mov      dword ptr [rsp + 0x40], 0
  00027016:  488d442450                  lea      rax, [rsp + 0x50]
  0002701b:  488bf8                      mov      rdi, rax
  0002701e:  33c0                        xor      eax, eax
  00027020:  b910000000                  mov      ecx, 0x10
  00027025:  f3aa                        rep stosb byte ptr [rdi], al
  00027027:  488d842488000000            lea      rax, [rsp + 0x88]
  0002702f:  488bf8                      mov      rdi, rax
  00027032:  33c0                        xor      eax, eax
  00027034:  b920000000                  mov      ecx, 0x20
  00027039:  f3aa                        rep stosb byte ptr [rdi], al
  0002703b:  488d442460                  lea      rax, [rsp + 0x60]
  00027040:  488bf8                      mov      rdi, rax
  00027043:  33c0                        xor      eax, eax
  00027045:  b908000000                  mov      ecx, 8
  0002704a:  f3aa                        rep stosb byte ptr [rdi], al
  0002704c:  488d442468                  lea      rax, [rsp + 0x68]
  00027051:  488bf8                      mov      rdi, rax
  00027054:  33c0                        xor      eax, eax
  00027056:  b920000000                  mov      ecx, 0x20
  0002705b:  f3aa                        rep stosb byte ptr [rdi], al
  0002705d:  488d8424a8000000            lea      rax, [rsp + 0xa8]
  00027065:  488bf8                      mov      rdi, rax
  00027068:  33c0                        xor      eax, eax
  0002706a:  b920000000                  mov      ecx, 0x20
  0002706f:  f3aa                        rep stosb byte ptr [rdi], al
  00027071:  4883bc24e000000000          cmp      qword ptr [rsp + 0xe0], 0
  0002707a:  742d                        je       0x270a9
  0002707c:  4883bc24e800000000          cmp      qword ptr [rsp + 0xe8], 0  ; W"襀⑄䠸֍䓧/襈⑄䠰䓇⠤"
  00027085:  7422                        je       0x270a9
  00027087:  488b8424e8000000            mov      rax, qword ptr [rsp + 0xe8]  ; W"/襈⑄䠰䓇⠤"
  0002708f:  833830                      cmp      dword ptr [rax], 0x30
  00027092:  7215                        jb       0x270a9
  00027094:  4883bc24f000000000          cmp      qword ptr [rsp + 0xf0], 0
  0002709d:  740a                        je       0x270a9
  0002709f:  83bc24f800000008            cmp      dword ptr [rsp + 0xf8], 8
  000270a7:  7446                        je       0x270ef
  000270a9:  488d05a0270500              lea      rax, [rip + 0x527a0]  ; W"wrong input"
  000270b0:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  000270b5:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000270be:  c744242038080000            mov      dword ptr [rsp + 0x20], 0x838
  000270c6:  4c8d0d03452f00              lea      r9, [rip + 0x2f4503]  ; W"generate_entropy2"
  000270cd:  4c8d05ec0d2f00              lea      r8, [rip + 0x2f0dec]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000270d4:  ba04000000                  mov      edx, 4
  000270d9:  488b0da80f5100              mov      rcx, qword ptr [rip + 0x510fa8]
  000270e0:  e897effdff                  call     0x607c  ; fn_0x607c
  000270e5:  b8feffefff                  mov      eax, 0xffeffffe
  000270ea:  e946030000                  jmp      0x27435
  000270ef:  41b808000000                mov      r8d, 8
  000270f5:  488b9424f0000000            mov      rdx, qword ptr [rsp + 0xf0]
  000270fd:  488d4c2460                  lea      rcx, [rsp + 0x60]
  00027102:  e8694d0300                  call     0x5be70  ; fn_0x5be70
  00027107:  85c0                        test     eax, eax
  00027109:  0f85a4000000                jne      0x271b3
  0002710f:  488d05ea442f00              lea      rax, [rip + 0x2f44ea]  ; W"random not exist or invalid, generate new data"
  00027116:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002711b:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00027124:  c74424203d080000            mov      dword ptr [rsp + 0x20], 0x83d
  0002712c:  4c8d0d9d442f00              lea      r9, [rip + 0x2f449d]  ; W"generate_entropy2"
  00027133:  4c8d05860d2f00              lea      r8, [rip + 0x2f0d86]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  0002713a:  ba07000000                  mov      edx, 7
  0002713f:  488b0d420f5100              mov      rcx, qword ptr [rip + 0x510f42]
  00027146:  e831effdff                  call     0x607c  ; fn_0x607c
  0002714b:  8b9424f8000000              mov      edx, dword ptr [rsp + 0xf8]
  00027152:  488b8c24f0000000            mov      rcx, qword ptr [rsp + 0xf0]
  0002715a:  e87d2c0000                  call     0x29ddc  ; fn_0x29ddc
  0002715f:  89442440                    mov      dword ptr [rsp + 0x40], eax
  00027163:  837c244000                  cmp      dword ptr [rsp + 0x40], 0
  00027168:  7449                        je       0x271b3
  0002716a:  8b442440                    mov      eax, dword ptr [rsp + 0x40]
  0002716e:  89442438                    mov      dword ptr [rsp + 0x38], eax
  00027172:  488d05e7442f00              lea      rax, [rip + 0x2f44e7]  ; W"generate rand failed with 0x%x"
  00027179:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  0002717e:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00027187:  c744242041080000            mov      dword ptr [rsp + 0x20], 0x841
  0002718f:  4c8d0d3a442f00              lea      r9, [rip + 0x2f443a]  ; W"generate_entropy2"
  00027196:  4c8d05230d2f00              lea      r8, [rip + 0x2f0d23]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  0002719d:  ba04000000                  mov      edx, 4
  000271a2:  488b0ddf0e5100              mov      rcx, qword ptr [rip + 0x510edf]
  000271a9:  e8ceeefdff                  call     0x607c  ; fn_0x607c
  000271ae:  e980020000                  jmp      0x27433
  000271b3:  488d05e6442f00              lea      rax, [rip + 0x2f44e6]  ; W"generate rootkey"
  000271ba:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  000271bf:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000271c8:  c744242049080000            mov      dword ptr [rsp + 0x20], 0x849
  000271d0:  4c8d0df9432f00              lea      r9, [rip + 0x2f43f9]  ; W"generate_entropy2"
  000271d7:  4c8d05e20c2f00              lea      r8, [rip + 0x2f0ce2]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000271de:  ba07000000                  mov      edx, 7
  000271e3:  488b0d9e0e5100              mov      rcx, qword ptr [rip + 0x510e9e]
  000271ea:  e88deefdff                  call     0x607c  ; fn_0x607c
  000271ef:  c744244400000000            mov      dword ptr [rsp + 0x44], 0
  000271f7:  eb0a                        jmp      0x27203
  000271f9:  8b442444                    mov      eax, dword ptr [rsp + 0x44]
  000271fd:  ffc0                        inc      eax
  000271ff:  89442444                    mov      dword ptr [rsp + 0x44], eax
  00027203:  837c244408                  cmp      dword ptr [rsp + 0x44], 8
  00027208:  7d57                        jge      0x27261
  0002720a:  4863442444                  movsxd   rax, dword ptr [rsp + 0x44]
  0002720f:  488d0d2a265100              lea      rcx, [rip + 0x51262a]
  00027216:  0fb60401                    movzx    eax, byte ptr [rcx + rax]
  0002721a:  48634c2444                  movsxd   rcx, dword ptr [rsp + 0x44]
  0002721f:  488d152a265100              lea      rdx, [rip + 0x51262a]
  00027226:  0fb60c0a                    movzx    ecx, byte ptr [rdx + rcx]
  0002722a:  33c1                        xor      eax, ecx
  0002722c:  48634c2444                  movsxd   rcx, dword ptr [rsp + 0x44]
  00027231:  88440c50                    mov      byte ptr [rsp + rcx + 0x50], al
  00027235:  4863442444                  movsxd   rax, dword ptr [rsp + 0x44]
  0002723a:  0fb6440450                  movzx    eax, byte ptr [rsp + rax + 0x50]
  0002723f:  8b4c2444                    mov      ecx, dword ptr [rsp + 0x44]
  00027243:  83c108                      add      ecx, 8
  00027246:  4863c9                      movsxd   rcx, ecx
  00027249:  488d15f0255100              lea      rdx, [rip + 0x5125f0]
  00027250:  0fb60c0a                    movzx    ecx, byte ptr [rdx + rcx]
  00027254:  33c1                        xor      eax, ecx
  00027256:  48634c2444                  movsxd   rcx, dword ptr [rsp + 0x44]
  0002725b:  88440c50                    mov      byte ptr [rsp + rcx + 0x50], al
  0002725f:  eb98                        jmp      0x271f9
  00027261:  c744244808000000            mov      dword ptr [rsp + 0x48], 8
  00027269:  eb0a                        jmp      0x27275
  0002726b:  8b442448                    mov      eax, dword ptr [rsp + 0x48]
  0002726f:  ffc0                        inc      eax
  00027271:  89442448                    mov      dword ptr [rsp + 0x48], eax
  00027275:  837c244810                  cmp      dword ptr [rsp + 0x48], 0x10
  0002727a:  7d57                        jge      0x272d3
  0002727c:  4863442448                  movsxd   rax, dword ptr [rsp + 0x48]
  00027281:  488d0dc8255100              lea      rcx, [rip + 0x5125c8]
  00027288:  0fb60401                    movzx    eax, byte ptr [rcx + rax]
  0002728c:  48634c2448                  movsxd   rcx, dword ptr [rsp + 0x48]
  00027291:  488d15c8255100              lea      rdx, [rip + 0x5125c8]
  00027298:  0fb60c0a                    movzx    ecx, byte ptr [rdx + rcx]
  0002729c:  33c1                        xor      eax, ecx
  0002729e:  48634c2448                  movsxd   rcx, dword ptr [rsp + 0x48]
  000272a3:  88440c50                    mov      byte ptr [rsp + rcx + 0x50], al  ; W"䀤琀證⑄襀⑄䠸֍䎽/襈⑄䠰䓇⠤"
  000272a7:  4863442448                  movsxd   rax, dword ptr [rsp + 0x48]  ; W"荀⑼@䥴䒋䀤䒉㠤赈봅⽃䠀䒉〤읈⑄("
  000272ac:  0fb6440450                  movzx    eax, byte ptr [rsp + rax + 0x50]  ; W"⑄䠸֍䎽/襈⑄䠰䓇⠤"
  000272b1:  8b4c2448                    mov      ecx, dword ptr [rsp + 0x48]  ; W"⑄襀⑄䠸֍䎽/襈⑄䠰䓇⠤"
  000272b5:  83e908                      sub      ecx, 8
  000272b8:  4863c9                      movsxd   rcx, ecx
  000272bb:  488d159e255100              lea      rdx, [rip + 0x51259e]
  000272c2:  0fb60c0a                    movzx    ecx, byte ptr [rdx + rcx]
  000272c6:  33c1                        xor      eax, ecx
  000272c8:  48634c2448                  movsxd   rcx, dword ptr [rsp + 0x48]
  000272cd:  88440c50                    mov      byte ptr [rsp + rcx + 0x50], al
  000272d1:  eb98                        jmp      0x2726b
  000272d3:  8b8424f8000000              mov      eax, dword ptr [rsp + 0xf8]
  000272da:  4c8d842488000000            lea      r8, [rsp + 0x88]
  000272e2:  8bd0                        mov      edx, eax
  000272e4:  488b8c24f0000000            mov      rcx, qword ptr [rsp + 0xf0]
  000272ec:  e83fa9fdff                  call     0x1c30  ; fn_0x1c30
  000272f1:  89442440                    mov      dword ptr [rsp + 0x40], eax
  000272f5:  837c244000                  cmp      dword ptr [rsp + 0x40], 0
  000272fa:  7449                        je       0x27345
  000272fc:  8b442440                    mov      eax, dword ptr [rsp + 0x40]
  00027300:  89442438                    mov      dword ptr [rsp + 0x38], eax
  00027304:  488d05bd432f00              lea      rax, [rip + 0x2f43bd]  ; W"hash failed with 0x%x"
  0002730b:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  00027310:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  00027319:  c74424205a080000            mov      dword ptr [rsp + 0x20], 0x85a
  00027321:  4c8d0da8422f00              lea      r9, [rip + 0x2f42a8]  ; W"generate_entropy2"
  00027328:  4c8d05910b2f00              lea      r8, [rip + 0x2f0b91]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  0002732f:  ba04000000                  mov      edx, 4
  00027334:  488b0d4d0d5100              mov      rcx, qword ptr [rip + 0x510d4d]
  0002733b:  e83cedfdff                  call     0x607c  ; fn_0x607c
  00027340:  e9ee000000                  jmp      0x27433
  00027345:  41b810000000                mov      r8d, 0x10
  0002734b:  488d942488000000            lea      rdx, [rsp + 0x88]
  00027353:  488d4c2468                  lea      rcx, [rsp + 0x68]
  00027358:  e873440300                  call     0x5b7d0  ; fn_0x5b7d0
  0002735d:  488d442478                  lea      rax, [rsp + 0x78]
  00027362:  41b810000000                mov      r8d, 0x10
  00027368:  488d542450                  lea      rdx, [rsp + 0x50]
  0002736d:  488bc8                      mov      rcx, rax
  00027370:  e85b440300                  call     0x5b7d0  ; fn_0x5b7d0
  00027375:  4c8d8424a8000000            lea      r8, [rsp + 0xa8]
  0002737d:  ba20000000                  mov      edx, 0x20
  00027382:  488d4c2468                  lea      rcx, [rsp + 0x68]
  00027387:  e8a4a8fdff                  call     0x1c30  ; fn_0x1c30
  0002738c:  89442440                    mov      dword ptr [rsp + 0x40], eax
  00027390:  837c244000                  cmp      dword ptr [rsp + 0x40], 0
  00027395:  7446                        je       0x273dd
  00027397:  8b442440                    mov      eax, dword ptr [rsp + 0x40]
  0002739b:  89442438                    mov      dword ptr [rsp + 0x38], eax
  0002739f:  488d0522432f00              lea      rax, [rip + 0x2f4322]  ; W"hash failed with 0x%x"
  000273a6:  4889442430                  mov      qword ptr [rsp + 0x30], rax
  000273ab:  48c744242800000000          mov      qword ptr [rsp + 0x28], 0
  000273b4:  c744242065080000            mov      dword ptr [rsp + 0x20], 0x865
  000273bc:  4c8d0d0d422f00              lea      r9, [rip + 0x2f420d]  ; W"generate_entropy2"
  000273c3:  4c8d05f60a2f00              lea      r8, [rip + 0x2f0af6]  ; W"d:\project\winfpcode\winfpcode\milan_watt\milanspi\milanfusb\gf_produc"
  000273ca:  ba04000000                  mov      edx, 4
  000273cf:  488b0db20c5100              mov      rcx, qword ptr [rip + 0x510cb2]
  000273d6:  e8a1ecfdff                  call     0x607c  ; fn_0x607c
  000273db:  eb56                        jmp      0x27433
  000273dd:  488d842498000000            lea      rax, [rsp + 0x98]
  000273e5:  41b810000000                mov      r8d, 0x10
  000273eb:  488bd0                      mov      rdx, rax
  000273ee:  488b8c24e0000000            mov      rcx, qword ptr [rsp + 0xe0]
  000273f6:  e8d5430300                  call     0x5b7d0  ; fn_0x5b7d0
  000273fb:  488b8424e0000000            mov      rax, qword ptr [rsp + 0xe0]
  00027403:  4883c010                    add      rax, 0x10
  00027407:  41b820000000                mov      r8d, 0x20
  0002740d:  488d9424a8000000            lea      rdx, [rsp + 0xa8]
  00027415:  488bc8                      mov      rcx, rax
  00027418:  e8b3430300                  call     0x5b7d0  ; fn_0x5b7d0
  0002741d:  488b8424e8000000            mov      rax, qword ptr [rsp + 0xe8]
  00027425:  c70030000000                mov      dword ptr [rax], 0x30
  0002742b:  c744244000000000            mov      dword ptr [rsp + 0x40], 0  ; W"䒉〤읈⑄("
  00027433:  33c0                        xor      eax, eax
  00027435:  488b8c24c8000000            mov      rcx, qword ptr [rsp + 0xc8]
  0002743d:  4833cc                      xor      rcx, rsp
  00027440:  e82b370300                  call     0x5ab70  ; fn_0x5ab70
  00027445:  4881c4d0000000              add      rsp, 0xd0
  0002744c:  5f                          pop      rdi
  0002744d:  c3                          ret      
  0002744e:  cc                          int3     

; --- function boundary ---

  0002744f:  cc                          int3     
  00027450:  4057                        push     rdi
  00027452:  4881ec000b0000              sub      rsp, 0xb00