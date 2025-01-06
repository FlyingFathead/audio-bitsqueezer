;--------------------------------------------------------------------
; loopplay_cia1_irq_32k.asm
;
; Plays 4-bit nibble data on a PAL C64 at ~32 kHz interrupts => ~16 kHz final rate
; hooking CIA #1 Timer A => IRQ. 
;
; Each interrupt reads one nibble. If first sample byte=0 => beep fallback => hang.
; If a sentinel 0 is read mid-play => pointer resets => infinite loop.
; Also sets DC offset for 8580 (fine on 6581).
; Toggles border color each IRQ => debug (so you can see it's firing).
;--------------------------------------------------------------------

        !cpu 6510
        !to "loopplay_32k.prg", cbm

        * = $0801

; BASIC line 10 => SYS 2064
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
    jsr init_sid_8580   ; sets DC offset for 8580 digis; works on 6581 too

    ;--------------------------------------------------
    ; zero-page pointer => sample data
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1

    ; check if first sample byte=0 => beep => hang
    ldy #0
    lda (samplePtr),y
    beq noDataFallback

    ; nibbleIndex=-1 => force "load new byte" next time
    lda #$ff
    sta nibbleIndex

    ;--------------------------------------------------
    ; CIA #1 Timer A => ~32 kHz interrupts on PAL
    ;   0.985 MHz / 32000 => ~30.8 => pick $1E or $1F
    lda #$1e        ; try 30 decimal
    sta $dc04
    lda #$00
    sta $dc05

    ; clear pending
    lda $dc0d
    lda #$7f
    sta $dc0d

    ; enable Timer A interrupt => bit0=TimerA, bit7=1 => enable
    lda #$81
    sta $dc0d

    ; Timer Control => bit6=1 => IRQ, bit0=1 => start => $51
    lda #$51
    sta $dc0e

    ;--------------------------------------------------
    ; Hook normal KERNAL IRQ vector at $0314/$0315 => chain later
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
    sta $d418      ; beep once
    jsr shortDelay
    lda #0
    sta $d418
.hangForever:
    jmp .hangForever

;-----------------------------------------
irqRoutine:
    ; flicker border color => debug
    lda $d020
    eor #$04
    sta $d020

    ; Acknowledge CIA #1
    lda $dc0d
    sta $dc0d

    pha
    txa
    pha
    tya
    pha

    jsr playNibble

    pla
    tay
    pla
    tax
    pla

    ; chain to old KERNAL IRQ
    jmp oldIrq

;-----------------------------------------
; playNibble
; 
; nibbleIndex < 0 => load new sample byte
; if loaded=0 => reset pointer => infinite loop
; else output nibble => $d418
playNibble:
    dec nibbleIndex
    bpl .highNibble

    ; nibbleIndex <0 => load new byte
    ldy #0
    lda (samplePtr),y
    beq resetPointer

    sta currentByte

    ; inc pointer
    inc samplePtr
    bne .skipIncHi
    inc samplePtr+1
.skipIncHi:

    ; low nibble
    and #$0f
    sta $d418

    lda #1
    sta nibbleIndex
    rts

.highNibble:
    lda currentByte
    lsr
    lsr
    lsr
    lsr
    and #$0f
    sta $d418

    lda #$ff
    sta nibbleIndex
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
    sta $d40c   ; Attack=5,Decay=1 is not super relevant
    lda #$f0
    sta $d40d   ; sustain=15 => hold DC offset
    rts

;-----------------------------------------
samplePtr   = $fa
nibbleIndex = $fc
currentByte = $fd

oldIrqLo = $fe
oldIrqHi = $ff

        * = *
oldIrq:
    jmp $ea31

        * = *
sampleData:
; your appended raw data + trailing 0
