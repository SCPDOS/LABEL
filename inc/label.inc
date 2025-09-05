;Misc structs here :)

struc idParamBlk
    .wCallLvl   dw ?    ;Should be zero
    .volId      dd ?    ;Volume Id
    .volLab     db 11 dup (?)   ;Volume label string
    .filSysType db 8 dup (?)    ;File system type string
endstruc