; gfspi.dll - gf_seal_data and gf_unseal_data (detailed view)
; Source: d:\project\winfpcode\...\gf_win_crypt_helper.c
; gf_seal_data wraps CryptProtectData
; gf_unseal_data wraps CryptUnprotectData
; CRITICAL: Does the code pass pOptionalEntropy to CryptProtectData?
; CryptProtectData(pDataIn, szDataDescr, pOptionalEntropy, pvReserved,
;                  pPromptStruct, dwFlags, pDataOut)
; RVA range: 0x2a100 - 0x2a900

