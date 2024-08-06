; Label!

[map all ./lst/label.map]
[DEFAULT REL]

;
;Creates, changes and deletes volume labels! 
;Invoked by: 
; LABEL [volume:][label] <- Jumps to the prompt to change the label
; LABEL [volume:]        <- Prints current label for vol, go to line above.
; LABEL                  <- Assumes current drive. Goes to line above.

BITS 64
%include "./inc/dosMacro.mac"
%include "./inc/dosStruc.inc"
%include "./inc/dosError.inc"
%include "./inc/fcbStruc.inc"
%include "./src/lblsrc.asm"
%include "./dat/lbldat.asm"
;Use a 45 QWORD stack
Segment transient align=8 follows=.text nobits
    dq 45 dup (?)
endOfAlloc: