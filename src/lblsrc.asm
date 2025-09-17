;Laebl main routine
startLabel:
    lea rsp, endOfAlloc   ;Move RSP to our internal stack
;Now let us resize ourselves so as to take up as little memory as possible
    mov ebx, endOfAlloc
    mov eax, 4A00h
    int 21h ;If this fails, we still proceed as we are just being polite!
parseCmdLine:
;Now parse the command line
    lea rsi, qword [r8 + psp.progTail]
    xor eax, eax    ;Clear all upper bytes for fun
    call skipDelims ;Goto the first non-delimiter char
    cmp al, CR  ;If empty command line, deal with it later
    je processCmdline
    ;If the second char is not colon, assumed to be label for the curdrv
    cmp byte [rsi + 1], ":"
    jne .labelFnd
    ;Here we had a x:. Uppercase the char in al and proceed
    push rax
    mov eax, 1213h  ;Call on DOS to uppercase char in al.
    int 2fh
    sub al, "@" ;Convert into a 1 based drive number (so 0 means curdrv)
    mov byte [drvNum], al
    pop rax ;Renormalise the stack
    ;The first non-delim char immediately after the colon is the label
    add rsi, 2  ;Go past the colon
;Check the first char past the colon is not a CR. If it is, avoid setting
; the pointer to the CR. No need to move below .labelFnd as the check 
; in the case we jump is already made
    call skipDelims
    cmp al, CR
    je processCmdline
.labelFnd:
;If a volume label is passed on the command line, copy it into the inBuffer
; until a delimiter is hit
    mov byte [lblGvn], -1   ;Set the flag that a label in inBuffer + 2
    lea rdi, inBuffer + 2
.lblCpyLp:
    lodsb
    call isALDelim
    je processCmdline
    stosb
    inc byte [inBuffer + 1] ;Increment the count
    cmp al, CR  ;Did we just store a CR?
    jne .lblCpyLp   ;If not, keep going
    dec byte [inBuffer + 1] ;Remove the terminating CR from the count
processCmdline:
;Now we have a label pointer, a disk number etc. 
;Now ensure that a drive number of 0 is converted to the actual 1 based number
    mov al, byte [drvNum]
    test al, al
    jnz doDrvCheck
    mov eax, 1900h  ;Get the current 0 based drive number in al
    int 21h
    inc al
    mov byte [drvNum], al
doDrvCheck:
;Make sure the drive chosen is not SUBST/JOIN/NET.
    movzx ecx, al ;Save the 1 based drive number in ecx
    mov eax, 5200h
    int 21h
    cmp byte [rbx + sysVars.lastdrvNum], cl
    jnb .drvOk
.badDrvExit:
    lea rdx, badDrv
.badPrintExit:
    mov eax, 0900h
    int 21h
    mov eax, 4CFFh
    int 21h
.drvOk:
    dec cl  ;Turn into an offset into the CDS
    mov rdi, qword [rbx + sysVars.cdsHeadPtr]
    mov eax, cds_size
    mul ecx
    add rdi, rax
    test word [rdi + cds.wFlags], cdsValidDrive
    jz .badDrvExit  ;If it is not valid, error out!
    test word [rdi + cds.wFlags], cdsRedirDrive
    jz .drvNotNet
    lea rdx, netDrv
    jmp short .badPrintExit
.drvNotNet:
    test word [rdi + cds.wFlags], cdsSubstDrive | cdsJoinDrive
    jz setDTA
    lea rdx, jsaDrv
    jmp short .badPrintExit
setDTA:
;Now set the DTA to an internal DTA and do a find first
    lea rdx, searchDta
    mov eax, 1A00h  ;Set DTA to interneal data
    int 21h

    call getLabel
    movsx ebp, al   ;Save the ret code. If 0, label exists. If -1, no label

    call printLabel
    mov al, byte [lblGvn]   ;Check the command line lbl flag
    test al, al
    jnz parseLbl
getLbL:
    call printNewline
    lea rdx, vPrmptS
    call printStr
inLbL:
    lea rdx, inBuffer
    mov eax, 0A00h
    int 21h
    call printCRLF
    cmp word [inBuffer + 1], 0D00h   ;If only a CR was entered, then delete
    je delLbl
parseLbl:
    lea rsi, qword [inBuffer + 2]    ;Else get the pointer in rsi
    movzx ebx, byte [inBuffer + 1]   ;Get the chars typed in
    mov byte [rsi + rbx], SPC   ;Cover the CR with a space!

    lea rdx, volFcb
    mov al, byte [drvNum]
    mov byte [rdx + exFcb.driveNum], al ;Store the drive number here
    test ebp, ebp   ;epb acts as a flag for if a label already exists!!
    jz renLbl
mkLbl:
    lea rdi, qword [rdx + exFcb.filename]
    movsq
    movsw
    movsb
    breakpoint
    mov eax, 1600h  ;FCB Create
    int 21h
    test al, al
    jnz badLbL
    call getLabel   ;Ensure we read the set disk label from dir
    lea rsi, searchDta + exFcb.filename ;Set rsi for bsSync
    jmp exit

badLbL:
    xor eax, eax
    xchg al, byte [lblGvn]    ;No longer use the label given if one was given!
    push rax
    test eax, eax
    jz .l1
    call printLabel ;If the label was given, we need to print the label header
.l1:
    call printNewline
    lea rdx, vBadStr
    call printStr
    lea rdi, inBuffer + 2
    mov byte [rdi - 1], 0
    mov al, SPC
    mov cl, 12
    rep stosb
    pop rax ;Get the lblGvn status
    jmp inLbL

delLbl:
    test ebp, ebp   ;If there is no label, just exit 
    jnz exit
.lp:
    call printCRLF
    lea rdx, delStr
    call printStr
    lea rdx, inBuffer 
    mov dword [rdx], 2  ;Make space for a Y/N and CR
    mov eax, 0A00h
    int 21h
    call printCRLF
    cmp byte [inBuffer + 1], 1
    jne .lp
    mov dl, byte [inBuffer + 2]
    mov eax, 6523h  ;Check Yes/No (upper word zeroed)
    int 21h
    cmp eax, 1  ;Are we yes? Fallthrough if so
    ja .lp      ;eax = 2, neither
    jb exit   ;eax = 0, No, exit 
    lea rdx, volFcb ;Already setup drive and all ???? for deleting
    mov eax, 1300h  ;FCB Delete (if a bad dir with many labels, deletes all)
    int 21h
    lea rsi, defaultLbl    ;Sync the default label
    jmp short exit

renLbl:
;First compare the names. If they are the same, just exit oki.
;Always update BPB though.
    lea rdi, qword [rdx + exRenFcb.filename]
    mov rax, "????????"
    stosq
    stosw
    stosb
    lea rdi, qword [rdx + exRenFcb.newName]
    movsq
    movsw
    movsb
    mov eax, 1700h  ;FCB Rename
    int 21h
    call getLabel   ;Now check the label is as we set it
    lea rsi, searchDta + exFcb.filename
    lea rdi, inBuffer + 2
    mov byte [rsi + 11], 0  ;Turn into ASCIIZ strings
    mov byte [rdi + 11], 0
    mov eax, 121Eh  ;Preserves rsi
    int 2fh         ;Filename specific string comp
    jne badLbL
exit:
    call printCRLF
    mov eax, 4C00h
    int 21h


;Misc subroutines
printNewline:
    call printCRLF
    jmp short printLF
printCRLF:
    mov dl, CR
    call printChar
printLF:
    mov dl, LF
printChar:
    test byte [lblGvn], -1
    retnz
    mov eax, 0200h
    int 21h
    return

printStr:
;Input: rdx -> Dollar terminated string to print
    test byte [lblGvn], -1
    retnz
    mov eax, 0900h
    int 21h
    return

printLabel:
    call printCRLF   ;New line
    lea rdx, volStr     ;Print Volume in drive string
    call printStr
    mov dl, byte [drvNum]
    add dl, "@" 
    call printChar
    test ebp, ebp    ;If ebp=0, we have a label! If ebp=-1, no label
    jz .lblFnd
    ;Here if no label found
    lea rdx, volNoS ;Print no label string
    call printStr
    return
.lblFnd:
    lea rdx, volOkS ;Print volume label
    call printStr
    lea rdx, searchDta + exFcb.filename ;Get the returned FCB data
    mov byte [rdx + 11],"$"             ;Terminate the string properly
    call printStr
    return


skipDelims:
;Points rsi to the first non-delimiter char in a string, loads al with value
    lodsb
    call isALDelim
    jz skipDelims
;Else, point rsi back to that char :)
    dec rsi
    return

isALDelim:
    cmp al, SPC
    rete
    cmp al, TAB
    rete
    cmp al, "="
    rete
    cmp al, ","
    rete
    cmp al, ";"
    return

getLabel:
    lea rdx, volFcb
    mov al, byte [drvNum]   ;Get the 1 based drive number
    mov byte [rdx + exFcb.driveNum], al    ;Store in search FCB
    mov eax, 1100h  ;Find First FCB
    int 21h
    return