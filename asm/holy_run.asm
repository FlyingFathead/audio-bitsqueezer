!cpu 6510
!to "holy_run.prg", cbm

; We create a short BASIC program with line 10: SYS2064
; So that the user can do "RUN" from BASIC and it jumps to $0810.

* = $0801

; ---------------------------------------------------
; BASIC line 10: SYS 2064
; 
; Format of a BASIC line is:
;   [2-byte pointer to next line]
;   [2-byte line number]
;   [tokens and data]
;   [0-byte end of line]
;   ...
;   [0 0 => end of entire BASIC program]
;
; We'll make line 10 do "SYS 2064" plus a zero terminator, then end.
; We'll place the code at $0810 for the machine code part.

; Pointer to "next line" = $080C => the next line is at $080C
!word $080c       ; pointer to next line
!word 10          ; line number: 10
!byte $9e         ; token for SYS
!text "2064",0    ; "2064" + null terminator
!word 0           ; end of line

; Next line pointer = 0 => end of entire BASIC program
!word 0

; ---------------------------------------------------
; Machine code at $0810
* = $0810

start:
    sei

    ; Clear SID registers
    ldx #$18
clrSid:
    lda #0
    sta $d400,x
    dex
    bpl clrSid

mainLoop:
    ; Toggle border color each loop for visible effect
    lda $d020
    eor #$02
    sta $d020

    ; Toggle SID master volume between 0 and 15
    lda volumeFlag
    eor #1
    sta volumeFlag
    lda volumeFlag
    beq setZero

    lda #$0f
    sta $d418
    jsr delay
    jmp mainLoop

setZero:
    lda #0
    sta $d418
    jsr delay
    jmp mainLoop

; A simple software delay, just so you can see the border flicker
; and hear the on/off beep more distinctly
delay:
    ldx #$ff
delX:
    ldy #$ff
delY:
    dey
    bne delY
    dex
    bne delX
    rts

volumeFlag = $fa  ; a zero-page byte to store the on/off state

; End of code
