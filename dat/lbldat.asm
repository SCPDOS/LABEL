
;Label data

lblGvn  db 0    ;If set, the label is in the inBuffer already
drvNum  db 0    ;1 based drive number we are modifying label for

;Strings
volStr  db "Volume in drive $"
volOkS  db " is $"
volNoS  db " has no label$"
vBadStr db "Invalid characters in volume label",CR,LF
vPrmptS db "Volume label (11 characters, ENTER for none)? $"

;Static Allocations
searchDta   db ffBlock_size dup (0)  ;This is where we get the label info
volFcb:
    istruc exFcb
    at exFcb.extSig,    db -1   ;Indicate extended FCB
    at exFcb.attribute, db volLabelFile
    at exFcb.driveNum,  db 0    ;Current drive
    at exFcb.filename,  db "????????"
    at exFcb.fileext,   db "???"
    at exFcb.curBlock,  dd 0
    iend 

inBuffer    db 12, 0, 12 dup (SPC)