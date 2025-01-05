; File: loopplay.asm
; Loops over 4-bit data in pairs (low nibble, high nibble),
; writing to $D418. If it sees a 0 sentinel, it resets pointer => infinite loop.

!cpu 6510
!to "loopplay.prg", cbm

        * = $0801

; BASIC line 10: SYS 2064
!word $080c
!word 10
!byte $9e
!text "2064",0
!word 0

;-----------------------------------------
; Start code at $0810
        * = $0810

start:
    sei
    jsr init_sid_8580   ; <--- changed to do test bit setup

    ; Set pointer to sample start
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1

loopForever:
    ; 1) read one byte => low nibble
    ldy #0
    lda (samplePtr),y
    beq resetPointer
    sta currentByte

    inc samplePtr
    bne skipLo
    inc samplePtr+1
skipLo:

    and #$0f
    sta $d418

    jsr shortDelay

    ; 2) read next byte => high nibble
    ldy #0
    lda (samplePtr),y
    beq resetPointer
    sta currentByte

    inc samplePtr
    bne skipHi
    inc samplePtr+1
skipHi:

    lsr
    lsr
    lsr
    lsr
    and #$0f
    sta $d418

    jsr shortDelay

    jmp loopForever

resetPointer:
    ; Saw 0 => sentinel => go back to start of data => infinite loop
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1
    jmp loopForever

;-----------------------------------------
; shortDelay: software loop to slow playback speed
shortDelay:
    ldx #$20
delX:
    ldy #$ff
delY:
    dey
    bne delY
    dex
    bne delX
    rts

;-----------------------------------------
done:
    lda #0
    sta $d418
stop:
    jmp stop

;-----------------------------------------
; init_sid_8580: zero out SID + set up voice 3 for “test bit”
; so volume digis are audible on 8580. (Works on 6581 too.)
init_sid_8580:
    ldx #$18
clearSid:
    lda #0
    sta $d400,x
    dex
    bpl clearSid

    ; Now do “test bit” setup on voice 3
    ; Control reg @ $d40b => 0101_0001 => bit0=gate=1,
    ;    bit4=pulse wave=1, bit6=test=1 => DC offset
    lda #$51
    sta $d40b

    ; Attack/Decay => $F0 => max attack, no decay
    sta $d40c
    ; Sustain/Release => $F0 => sustain=15 => keep DC offset
    lda #$f0
    sta $d40d

    rts

;-----------------------------------------
; Zero-page pointers
samplePtr   = $fa
currentByte = $fc

;-----------------------------------------
; The appended 4-bit data goes here plus a trailing zero
        * = *
sampleData:
; (The “makeprg.py” merges the .raw + sentinel 0)
