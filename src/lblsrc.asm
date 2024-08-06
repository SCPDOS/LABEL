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
    jnz setDTA
    mov eax, 1900h  ;Get the current 0 based drive number in al
    int 21h
    inc al
    mov byte [drvNum], al
setDTA:
;Set the DTA to an internal DTA and do a find first
    lea rdx, searchDta
    mov eax, 1A00h  ;Set DTA to interneal data
    int 21h
    call printNewline   ;New line
    lea rdx, volStr     ;Print Volume in drive string
    call printStr
    mov dl, byte [drvNum]
    add dl, "@" 
    call printChar

    lea rdx, volFcb
    mov al, byte [drvNum]   ;Get the 1 based drive number
    mov byte [rdx + exFcb.driveNum], al    ;Store in search FCB
    mov eax, 1100h  ;Find First FCB
    int 21h
    test al, al ;If al=0, we have a label!
    jz .lblFnd
    ;Here if no label found
    lea rdx, volNoS ;Print no label string
    call printStr
    xor ebp, ebp    ;Set no label present flag
    jmp short doLbl
.lblFnd:
    lea rdx, volOkS ;Print volume label
    call printStr
    lea rdx, searchDta + exFcb.filename ;Get the returned FCB data
    mov byte [rdx + 11],"$"             ;Terminate the string properly
    call printStr
    mov ebp, 1      ;Set label already present flag
doLbl:
    ;ebp = Label already present flag
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
    cmp word [rdx + 1], 0D00h   ;If only a CR was entered, then delete
    je delLbl
parseLbl:
    lea rsi, qword [inBuffer + 2]    ;Else get the pointer in rsi
    movzx ebx, byte [inBuffer + 1]   ;Get the chars typed in
    mov byte [rsi + rbx], SPC   ;Cover the CR with a space!

    lea rdx, volFcb
    mov al, byte [drvNum]
    mov byte [rdx + exFcb.driveNum], al ;Store the drive number here
    test ebp, ebp
    jnz renLbl
mkLbl:
    lea rdi, qword [rdx + exFcb.filename]
    movsq
    movsw
    movsb
    mov eax, 1600h  ;FCB Create
    int 21h
    test al, al
    jz exit
badLbL:
    mov byte [lblGvn], 0    ;No longer use the label given!
    call printNewline
    lea rdx, vBadStr
    call printStr
    lea rdi, inBuffer + 2
    mov byte [rdi - 1], 0
    inc rdi
    mov al, SPC
    mov cl, 12
    rep stosb
    jmp inLbL
delLbl:
    lea rdx, volFcb
    mov al, byte [drvNum]
    mov byte [rdx + exFcb.driveNum], al ;Store the drive number here
    lea rdi, qword [rdx + exFcb.filename]
    mov rax, "????????"
    stosq
    stosw
    stosb   
    mov eax, 1300h  ;FCB Delete
    int 21h
    jmp short exit
renLbl:
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
    test al, al
    jnz badLbL
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