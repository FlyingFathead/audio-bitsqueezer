;--------------------------------------------------------------------
; loopplay_cia1_irq_64k.asm
;
; Plays 4-bit nibble data on PAL at ~64 kHz interrupts => ~32 kHz final.
; hooking CIA #1 Timer A => IRQ. Each interrupt plays one nibble => $d418.
; If first sample byte=0 => beep fallback => hang. If sentinel=0 mid-play => reset pointer => infinite loop.
; Also sets DC offset for 8580 (ok on 6581). Flickers border color => debug.
;--------------------------------------------------------------------

        !cpu 6510
        !to "loopplay.prg", cbm

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
    jsr init_sid_8580   ; DC offset for 8580-based digi

    ;--------------------------------------------------
    ; Zero-page pointer => sample data
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1

    ; If first sample=0 => beep => hang
    ldy #0
    lda (samplePtr),y
    beq noDataFallback

    ; Force "load new byte" on next nibble
    lda #$ff
    sta nibbleIndex

    ;--------------------------------------------------
    ; CIA #1 Timer A => ~64 kHz interrupts on PAL
    ;   0.985 MHz / 64000 => ~15 => $0F
    lda #$0f       ; Timer A LSB=15 decimal
    sta $dc04
    lda #$00
    sta $dc05

    ; Clear any pending interrupts
    lda $dc0d
    lda #$7f
    sta $dc0d

    ; Enable Timer A interrupt => bit0=TimerA, bit7=1 => enable
    lda #$81
    sta $dc0d

    ; Timer Control => bit6=1=>IRQ, bit0=1=>start => $51
    lda #$51
    sta $dc0e

    ;--------------------------------------------------
    ; Hook normal KERNAL IRQ vector at $0314/$0315
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
    sta $d418     ; beep
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

    ; Acknowledge CIA#1
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

    jmp oldIrq

;-----------------------------------------
; Reads a nibble from sample:
;  - If nibbleIndex < 0 => load a new byte
;  - If that byte=0 => sentinel => reset pointer => loop
;  - Otherwise output nibble => $d418
playNibble:
    dec nibbleIndex
    bpl .doHigh

    ; nibbleIndex < 0 => load new byte
    ldy #0
    lda (samplePtr),y
    beq resetPointer   ; sentinel => restart pointer

    sta currentByte

    ; increment pointer
    inc samplePtr
    bne .skipIncHi
    inc samplePtr+1
.skipIncHi:

    ; low nibble => $d418
    and #$0f
    sta $d418

    lda #1
    sta nibbleIndex
    rts

.doHigh:
    ; high nibble
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
    ; if sentinel => reset pointer => infinite loop
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1
    rts

;-----------------------------------------
shortDelay:
    ; only used for beep fallback
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
clearSid:
    lda #0
    sta $d400,x
    dex
    bpl clearSid

    ; DC offset on voice3
    lda #$51
    sta $d40b
    sta $d40c
    lda #$f0
    sta $d40d
    rts

;-----------------------------------------
; zero-page + old vector
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
; appended 4-bit data + trailing 0
