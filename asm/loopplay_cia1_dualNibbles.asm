;--------------------------------------------------------------------
; loopplay_cia1_dualNibbles.asm
;
; Plays a 4-bit file (each byte = 2 nibbles) at ~8k final sample rate
; hooking CIA #1 Timer A => ~8k interrupts. In *each* IRQ:
;  - read 1 byte => has low nibble + high nibble
;  - output low nibble -> $d418
;  - short minimal wait (just a few cycles)
;  - output high nibble -> $d418
;
; If 1st byte=0 => beep fallback => hang. If sentinel=0 mid-play => reset pointer => infinite loop.
; Also sets DC offset for 8580 (fine on 6581). Flickers border color => debug each IRQ.
;--------------------------------------------------------------------

        !cpu 6510
        !to "loopplay_dualnibbles.prg", cbm

        * = $0801

; BASIC line 10 => SYS2064
!word $080c
!word 10
!byte $9e
!text "2064",0
!word 0

;--------------------------------------------------
; Start code at $0810
        * = $0810

start:
    sei
    jsr init_sid_8580     ; ensures 8580 offset, harmless on 6581

    ; Put pointer to 4-bit data in ZP
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1

    ; If the first byte == 0 => beep fallback => hang
    ldy #0
    lda (samplePtr),y
    beq noDataFallback

    ;-------------------------------------------
    ; Setup CIA #1 => Timer A => ~8 kHz (example)
    ; For PAL ~0.985 MHz => 985000 / 8000 ~ 123 => $7B
    ; For NTSC ~1.0227 => 1022700 / 8000 ~ 128 => $80
    ; Pick whichever is close. We'll do $7B for PAL as example:
    lda #$7b
    sta $dc04
    lda #0
    sta $dc05

    ; Clear pending
    lda $dc0d
    lda #$7f
    sta $dc0d

    ; Enable Timer A interrupt => bit0=TimerA, bit7=1 => enable
    lda #$81
    sta $dc0d

    ; Timer ctrl => bit6=1 => IRQ, bit0=1 => start => 0b01010001 => $51
    lda #$51
    sta $dc0e

    ;-------------------------------------------
    ; Hook KERNAL IRQ vector at $0314/$0315
    lda $0314
    sta oldIrqLo
    lda $0315
    sta oldIrqHi

    lda #<irqRoutine
    sta $0314
    lda #>irqRoutine
    sta $0315

    cli
mainLoop:
    jmp mainLoop

;-----------------------------------------
noDataFallback:
    lda #$0f
    sta $d418
    jsr shortDelay
    lda #0
    sta $d418
.hangForever:
    jmp .hangForever

;-----------------------------------------
irqRoutine:
    ; Flicker border color => debug
    lda $d020
    eor #$04
    sta $d020

    ; Acknowledge CIA#1 TimerA
    lda $dc0d
    sta $dc0d

    pha
    txa
    pha
    tya
    pha

    jsr playTwoNibbles   ; output 2 nibs => 2 sample steps in 1 IRQ

    pla
    tay
    pla
    tax
    pla

    jmp oldIrq

;-----------------------------------------
; In each IRQ, we read 1 byte => 2 4-bit samples
; If byte=0 => sentinel => reset pointer => infinite loop
; else => output low nibble -> $d418, short wait, then high nibble
playTwoNibbles:
    ldy #0
    lda (samplePtr),y
    beq resetPointer

    sta currentByte

    inc samplePtr
    bne .skipInc
    inc samplePtr+1
.skipInc:

    ;-----------------------------------------
    ; 1) Low nibble
    lda currentByte
    and #$0f
    sta $d418

    ; minimal wait => let the SID set that nibble => depends on how "spaced" you want them
    ; a few cycles is enough. Let's do 6 NOPs just for demonstration:
    nop
    nop
    nop
    nop
    nop
    nop

    ;-----------------------------------------
    ; 2) High nibble => shift right 4
    lda currentByte
    lsr
    lsr
    lsr
    lsr
    and #$0f
    sta $d418

    rts

;-----------------------------------------
resetPointer:
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1
    rts

;-----------------------------------------
shortDelay:
    ; Just used for beep fallback
    ldx #$20
.delX:
    ldy #$ff
.delY:
    dey
    bne .delY
    dex
    bne .delX
    rts

;-----------------------------------------
init_sid_8580:
    ldx #$18
.clearSid:
    lda #0
    sta $d400,x
    dex
    bpl .clearSid

    lda #$51
    sta $d40b   ; test=1, pulse=1, gate=1 => DC offset
    sta $d40c
    lda #$f0
    sta $d40d
    rts

;-----------------------------------------
samplePtr   = $fa
currentByte = $fc

oldIrqLo = $fd
oldIrqHi = $fe

        * = *
oldIrq:
    jmp $ea31

        * = *
sampleData:
; your 4-bit data (2 nibs/byte) + trailing 0 appended
