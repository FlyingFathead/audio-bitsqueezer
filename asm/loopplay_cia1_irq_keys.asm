;--------------------------------------------------------------------
; loopplay_cia1_irq_keys.asm
; (Thanks to nmp for additional quirks & code tips)
;
; Volume-digi player at ~8kHz or so, toggled by Space bar,
; pitch changed by keys '0'..'9' => different Timer A reload values.
;--------------------------------------------------------------------

        !cpu 6510
        !to "loopplay_cia1_irq_keys.prg", cbm

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
    jsr init_sid_8580

    ; Set pointer to 4-bit nibble data in zero-page
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1

    ; If first byte = 0 => beep fallback => hang
    ldy #0
    lda (samplePtr),y
    beq noDataFallback

    ; nibbleIndex = -1 => means next interrupt loads a new byte
    lda #$ff
    sta nibbleIndex

    ; Default pitch index = 0 => see pitchTable
    lda #0
    sta currentPitch

    ; Setup CIA #1 => Timer A => ~8kHz
    jsr updateTimerA

    ; Clear any pending interrupt
    lda $dc0d
    sta $dc0d

    ; Enable Timer A interrupt => bit0=TimerA, bit7=1 => enable
    lda #$81
    sta $dc0d

    ; Timer ctrl => bit6=1 => IRQ, bit0=1 => start => $51
    lda #$51
    sta $dc0e

    ; Hook KERNAL IRQ vector @ $0314/$0315
    lda $0314
    sta oldIrqLo
    lda $0315
    sta oldIrqHi

    lda #<irqRoutine
    sta $0314
    lda #>irqRoutine
    sta $0315

    ; Playback enabled => 1
    lda #1
    sta playbackEnabled

    cli

mainLoop:
    jsr readKeyboard
    jmp mainLoop

;-----------------------------------------
noDataFallback:
    lda #$0f
    sta $d418
    jsr shortDelay
    lda #0
    sta $d418
hangForever:
    jmp hangForever

;-----------------------------------------
irqRoutine:
    lda $dc0d
    sta $dc0d

    lda playbackEnabled
    beq skipPlay

    jsr playNibble

skipPlay:
    jmp oldIrq

;-----------------------------------------
playNibble:
    dec nibbleIndex
    bpl doHigh

    ; nibbleIndex < 0 => load new byte
    ldy #0
    lda (samplePtr),y
    beq resetPointer

    sta currentByte
    inc samplePtr
    bne noCarry
    inc samplePtr+1

noCarry:
    and #$0f
    sta $d418

    lda #1
    sta nibbleIndex
    rts

doHigh:
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

resetPointer:
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1
    rts

;-----------------------------------------
readKeyboard:
    jsr chkKey
    cmp #$20       ; space key?
    bne notSpace
    ; toggle playback
    lda playbackEnabled
    eor #$01
    sta playbackEnabled
    rts

notSpace:
    cmp #$30
    bcc done
    cmp #$39
    bcs done
    ; => '0'..'9'
    sec
    sbc #$30
    sta currentPitch
    jsr updateTimerA
done:
    rts

;-----------------------------------------
chkKey:
    ; KERNAL's GETIN => $FFE4
    ; If no key => A=0
    lda #0
    sta $c6
    jsr $ffe4
    rts

;-----------------------------------------
updateTimerA:
    lda currentPitch
    tay
    lda pitchTableLo,y
    sta $dc04
    lda pitchTableHi,y
    sta $dc05
    rts

;-----------------------------------------
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
init_sid_8580:
    ldx #$18
clearSid:
    lda #0
    sta $d400,x
    dex
    bpl clearSid

    lda #$51
    sta $d40b
    sta $d40c
    lda #$f0
    sta $d40d
    rts

;-----------------------------------------
; Data tables (no blank lines, no trailing spaces)
pitchTableLo:
    !byte $7B,$6B,$5B,$50,$40,$30,$28,$20,$18,$0C
pitchTableHi:
    !byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00

;-----------------------------------------
; Zero-page vars
samplePtr       = $fa
nibbleIndex     = $fc
currentByte     = $fd
playbackEnabled = $f9
currentPitch    = $f8
oldIrqLo        = $fe
oldIrqHi        = $ff

;-----------------------------------------
oldIrq:
    jmp $ea31

sampleData:
; (makeprg.py merges your .raw + trailing 0)
