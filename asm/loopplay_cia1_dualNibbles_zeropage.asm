;--------------------------------------------------------------------
; loopplay_cia1_dualNibbles_zeropage.asm
;
; Plays a 4-bit file (1 byte = 2 nibbles) at ~8kHz CIA #1 interrupts.
; Each IRQ: read 1 byte -> output low nibble -> short wait -> output high nibble.
; Resets pointer if sentinel=0 read, beep fallback if sample=0 at start, etc.
; DC offset for 8580. Flicker border color => debug.
;--------------------------------------------------------------------

        !cpu 6510
        !to "loopplay_dualnibbles_zeropage.prg", cbm

        * = $0801

; BASIC line => SYS 2064
!word $080c
!word 10
!byte $9e
!text "2064",0
!word 0

        * = $0810

start:
    sei
    jsr init_sid_8580

    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1

    ldy #0
    lda (<samplePtr),y
    beq noDataFallback

    ; Setup CIA #1 for ~8kHz (PAL => $7B, NTSC => $80)
    lda #$7b
    sta $dc04
    lda #0
    sta $dc05

    ; Clear + enable Timer A IRQ
    lda $dc0d
    lda #$7f
    sta $dc0d
    lda #$81
    sta $dc0d

    ; Timer ctrl => bit6=1 => IRQ, bit0=1 => start => $51
    lda #$51
    sta $dc0e

    ; Hook IRQ
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

noDataFallback:
    lda #$0f
    sta $d418
    jsr shortDelay
    lda #0
    sta $d418
.hangForever:
    jmp .hangForever

irqRoutine:
    lda $d020
    eor #$04
    sta $d020

    lda $dc0d
    sta $dc0d

    pha
    txa
    pha
    tya
    pha

    jsr playTwoNibbles

    pla
    tay
    pla
    tax
    pla
    jmp oldIrq

playTwoNibbles:
    ldy #0
    lda (<samplePtr),y
    beq resetPointer

    sta currentByte

    inc samplePtr
    bne .skipInc
    inc samplePtr+1
.skipInc:

    ; Low nibble
    lda currentByte
    and #$0f
    sta $d418

    nop
    nop
    nop
    nop
    nop
    nop

    ; High nibble
    lda currentByte
    lsr
    lsr
    lsr
    lsr
    and #$0f
    sta $d418

    rts

resetPointer:
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1
    rts

shortDelay:
    ldx #$20
.delX:
    ldy #$ff
.delY:
    dey
    bne .delY
    dex
    bne .delX
    rts

init_sid_8580:
    ldx #$18
.clearSid:
    lda #0
    sta $d400,x
    dex
    bpl .clearSid

    lda #$51
    sta $d40b
    sta $d40c
    lda #$f0
    sta $d40d
    rts

;-----------------------------------------
; Zero-page definitions

samplePtr   = $fa
currentByte = $fc
oldIrqLo    = $fd
oldIrqHi    = $fe

        * = *
oldIrq:
    jmp $ea31

        * = *
sampleData:
; appended 4-bit data + trailing 0
