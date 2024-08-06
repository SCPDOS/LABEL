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
    cmp byte [rsi], CR
    je processCmdline
.labelFnd:
    mov qword [lblPtr], rsi 
processCmdline:
;Now we have a label pointer, a disk number etc. 
;Set the DTA to an internal DTA and do a find first
    lea rdx, searchDta
    mov eax, 1A00h  ;Set DTA to interneal data
    int 21h
    call printNewline    ;New line
    lea rdx, volStr     ;Print Volume in drive string
    call printStr

    lea rdx, volFcb
    mov al, byte [drvNum]   ;Get the 1 based drive number
    mov byte [rdx + volFcb + exFcb.driveNum], al    
    mov eax, 1100h  ;Find First FCB
    int 21h
    mov dl, byte [rdx + volFcb + exFcb.driveNum]    ;Get 0 based number
    add dl, "A"
    mov eax, 0200h  ;Print the drive letter
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
    mov rsi, qword [lblPtr]
    test rsi, rsi
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
    lea rsi, qword [rdx + 2]    ;Else get the pointer in rsi
parseLbl:
;rsi -> First char of the volume label provided.
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
    call printNewline
    lea rdx, vBadStr
    call printStr
    lea rdi, inBuffer + 1
    xor eax, eax
    ;Clean thirteen chars, set to 0
    stosq
    stosd
    stosb
    jmp short inLbL
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
    mov eax, 4C00h
    int 21h
;Misc subroutines
printNewline:
    call printCRLF
    jmp short printLF
printCRLF:
    mov dl, CR
    call printLF.goChar
printLF:
    mov dl, LF
.goChar:
    mov eax, 0200h
    int 21h
    return

printStr:
;Input: rdx -> Dollar terminated string to print
    mov eax, 0900h
    int 21h
    return

skipDelims:
;Points rsi to the first non-delimiter char in a string, loads al with value
    lodsb
;If the char in AL is any of the chars listed below, goto next char
    cmp al, SPC
    je skipDelims
    cmp al, TAB
    je skipDelims
    cmp al, "="
    je skipDelims
    cmp al, ","
    je skipDelims
    cmp al, ";"
    je skipDelims
;Else, point rsi back to that char :)
    dec rsi
    return