;--------------------------------------------------------------------
; loopplay_cia1_irq_singleNibble_zeropage.asm
;
; Plays 4-bit nibble data at ~8kHz interrupts on PAL:
;   - Each interrupt reads exactly ONE nibble (low or high).
;   - nibbleIndex toggles between -1 and 0 => “new byte” vs. “use high nibble”.
;
; If first sample byte=0 => beep fallback => hang forever.
; If a sentinel 0 is read mid-play => reset pointer => infinite loop.
; Also sets DC offset for 8580 (fine on 6581 too).
; Flickers border color each IRQ => debug.
;--------------------------------------------------------------------

        !cpu 6510
        !to "loopplay_singleNibble_zeropage.prg", cbm

        * = $0801

; BASIC line 10 => SYS 2064
!word $080c
!word 10
!byte $9e
!text "2064",0
!word 0

;--------------------------------------------------
; Code starts at $0810
        * = $0810

start:
    sei
    jsr init_sid_8580   ; ensures 8580 offset, harmless on 6581

    ;--------------------------------------------------
    ; Put pointer to sample data in ZP
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1

    ; If first byte == 0 => beep fallback => hang
    ldy #0
    lda (<samplePtr),y    ; < forces zero-page indirect addressing
    beq noDataFallback

    ; nibbleIndex = $FF => means “on next IRQ, load a new byte”
    lda #$ff
    sta nibbleIndex

    ;--------------------------------------------------
    ; Setup CIA #1 => Timer A => ~8 kHz (PAL example).
    ;   ~0.985 MHz / 8000 => ~123 => $7B
    ; For NTSC ~1.0227 => ~128 => $80
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

    ; Timer ctrl => bit6=1 => IRQ, bit0=1 => start => $51
    lda #$51
    sta $dc0e

    ;--------------------------------------------------
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
; noDataFallback => beep once if sample=0 => hang
noDataFallback:
    lda #$0f
    sta $d418
    jsr shortDelay
    lda #0
    sta $d418
.hangForever:
    jmp .hangForever

;-----------------------------------------
; CIA #1 Timer A -> IRQ => we do 1 nibble
irqRoutine:
    ; Flicker border color => debug
    lda $d020
    eor #$04
    sta $d020

    ; Acknowledge CIA #1 TimerA
    lda $dc0d
    sta $dc0d

    pha
    txa
    pha
    tya
    pha

    jsr playOneNibble

    pla
    tay
    pla
    tax
    pla

    jmp oldIrq

;-----------------------------------------
; playOneNibble: If nibbleIndex<0 => read a new byte => output low nibble
; else => output high nibble => set nibbleIndex back to -1
playOneNibble:
    dec nibbleIndex
    bpl .doHigh    ; if nibbleIndex >= 0 => do high nibble

    ; nibbleIndex < 0 => load a new sample byte
    ldy #0
    lda (<samplePtr),y    ; again using <samplePtr for zero-page indirect
    beq resetPointer      ; saw sentinel => reset => loop forever

    sta currentByte

    inc samplePtr
    bne .skipInc
    inc samplePtr+1
.skipInc:

    ; Output the LOW nibble
    and #$0f
    sta $d418

    lda #0
    sta nibbleIndex
    rts

.doHigh:
    ; Output the HIGH nibble
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
    ; If 0 => sentinel => reset pointer => infinite loop
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1
    rts

;-----------------------------------------
shortDelay:
    ; used only for beep fallback
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
; Now define them in the “zeropage” area:

samplePtr   = $fa
nibbleIndex = $fc
currentByte = $fd
oldIrqLo    = $fe
oldIrqHi    = $ff

        * = *
oldIrq:
    jmp $ea31

        * = *
sampleData:
; your 4-bit data (2 nibs/byte) + trailing 0 appended
