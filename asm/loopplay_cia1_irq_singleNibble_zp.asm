;--------------------------------------------------------------------
; loopplay_cia1_irq_singleNibble_zp.asm
; 
; Example: Single-nibble playback at ~8kHz, zero-page forced.
;--------------------------------------------------------------------

        !cpu 6510
        !to "loopplay_singleNibble_zp.prg", cbm

        * = $0801
!word $080c
!word 10
!byte $9e
!text "2064",0
!word 0

        * = $0810

start:
    sei
    jsr init_sid_8580

    ; Load pointer to sample data in zero-page
    lda #<sampleData
    sta <samplePtr
    lda #>sampleData
    sta <samplePtr+1

    ; Check if first byte=0 => fallback beep
    ldy #0
    lda (<samplePtr),y
    beq noDataFallback

    ; nibbleIndex = $FF => next IRQ => load new byte
    lda #$ff
    sta <nibbleIndex

    ;--------------------------------------------------
    ; Setup CIA #1 => Timer A => ~8kHz (PAL => $7B).
    lda #$7b
    sta $dc04
    lda #0
    sta $dc05

    ; Clear pending by reading $dc0d once
    lda $dc0d

    ; Enable TimerA interrupt => bit0=TimerA, bit7=1 => enable
    lda #$81
    sta $dc0d

    ; Start timer, bit6=1 => IRQ, bit0=1 => start => $51
    lda #$51
    sta $dc0e

    ; Hook KERNAL IRQ
    lda $0314
    sta <oldIrqLo
    lda $0315
    sta <oldIrqHi

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
    jmp forever
forever:
    jmp forever

;-----------------------------------------
irqRoutine:
    ; Debug: flicker border
    lda $d020
    eor #$04
    sta $d020

    ; Acknowledge CIA #1
    lda $dc0d
    sta $dc0d

    ; *** We skip pushing A,X,Y here,
    ; *** because KERNAL’s IRQ chain does it anyway if we do jmp $ea31
    jsr playOneNibble

    ; If you want to chain to the standard KERNAL handler:
    jmp $ea31

;-----------------------------------------
playOneNibble:
    ; dec nibbleIndex => if >=0 => do high nibble
    dec <nibbleIndex
    bpl .doHigh

    ; nibbleIndex < 0 => load new byte => output low nibble
    ldy #0
    lda (<samplePtr),y
    beq resetPointer

    sta <currentByte

    inc <samplePtr
    bne .skipInc
    inc <samplePtr+1
.skipInc:

    and #$0f
    sta $d418

    lda #0
    sta <nibbleIndex
    rts

.doHigh:
    lda <currentByte
    lsr
    lsr
    lsr
    lsr
    and #$0f
    sta $d418

    lda #$ff
    sta <nibbleIndex
    rts

;-----------------------------------------
resetPointer:
    lda #<sampleData
    sta <samplePtr
    lda #>sampleData
    sta <samplePtr+1
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
.clrSid:
    lda #0
    sta $d400,x
    dex
    bpl .clrSid

    lda #$51
    sta $d40b
    sta $d40c
    lda #$f0
    sta $d40d
    rts

;-----------------------------------------
; ZP variables => force usage as zero-page
samplePtr   = $fa   ; 2 bytes => $fa,$fb
nibbleIndex = $fc
currentByte = $fd
oldIrqLo    = $fe
oldIrqHi    = $ff

        * = *
oldIrq:
    jmp $ea31   ; chain to KERNAL

        * = *
sampleData:
    ; (Will be appended + 0 sentinel)
