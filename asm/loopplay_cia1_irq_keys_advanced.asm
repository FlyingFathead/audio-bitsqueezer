;--------------------------------------------------------------------
;  loopplay_cia1_irq_keys_advanced.asm
;  A re-implementation of nibble-based volume playback at ~8kHz,
;  toggled by Space, pitch changed by digits '0'..'9'.
;--------------------------------------------------------------------

!cpu 6510
!to "loopplay_cia1_irq_keys.prg", cbm

    * = $0801

; BASIC stub: SYS 2064
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
    jsr init_sid_8580

    ; Zero-page pointer to sample data
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1

    ; If first nibble=0 => beep => hang
    ldy #0
    lda (samplePtr),y
    beq noDataFallback

    ; nibbleIndex=-1 => next interrupt must load new byte
    lda #$ff
    sta nibbleIndex

    ; Default pitch index = 0
    lda #0
    sta pitchIndex

    ; Initialize playback toggled ON
    lda #1
    sta playbackOn

    ; Setup default Timer A rate => index=0 => ~8k
    jsr updateTimerA

    ; Clear & enable CIA #1 Timer A interrupt
    lda $dc0d    ; read to clear
    sta $dc0d
    lda #$81     ; bit0=timerA, bit7=enable
    sta $dc0d

    ; Timer Control => bit6=IRQ, bit0=start => $51
    lda #$51
    sta $dc0e

    ; Hook KERNAL IRQ vector
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
    jsr readKeyboard
    jmp mainLoop

;-----------------------------------------
noDataFallback:
    lda #$0f
    sta $d418   ; beep
    jsr shortDelay
    lda #0
    sta $d418
.hang:
    jmp .hang

;-----------------------------------------
; IRQ routine for CIA#1 Timer A
irqRoutine:
    ; Acknowledge CIA#1
    lda $dc0d
    sta $dc0d

    ; If playback is ON => do nibble
    lda playbackOn
    beq .skipPlay
    jsr playNibble
.skipPlay:

    jmp oldIrq  ; chain to old KERNAL IRQ or do jmp $ea31

;-----------------------------------------
; readNibble + sentinel
playNibble:
    dec nibbleIndex
    bpl .doHigh

    ; nibbleIndex < 0 => fetch next raw byte
    ldy #0
    lda (samplePtr),y
    beq resetPointer    ; 0 => sentinel => loop forever

    sta currentByte
    inc samplePtr
    bne .skipIncHigh
    inc samplePtr+1
.skipIncHigh:

    ; output low nibble => volume
    and #$0f
    sta $d418

    lda #1
    sta nibbleIndex
    rts

.doHigh:
    ; output high nibble => shift out low bits
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
; readKeyboard: checks for Space => toggles ON/OFF
; checks for '0'..'9' => changes pitch index
readKeyboard:
    jsr chkKey
    cmp #$00
    beq .noKey
    cmp #$20       ; ASCII for Space
    beq .toggle
    cmp #$30
    bcc .doneKey
    cmp #$39
    bcs .doneKey
    ; => it’s between '0'..'9'
    sec
    sbc #$30
    sta pitchIndex
    jsr updateTimerA
    jmp .doneKey

.toggle:
    lda playbackOn
    eor #$01
    sta playbackOn
.doneKey:
.noKey:
    rts

;-----------------------------------------
; KERNAL GETIN => returns ASCII in A or 0 if none
chkKey:
    lda #0
    sta $c6       ; #chars to read => 0 => no-block GETIN
    jsr $ffe4
    rts

;-----------------------------------------
; updateTimerA => sets Timer A reload from pitchTable
updateTimerA:
    lda pitchIndex
    cmp #10
    bcc .ok
    lda #9        ; clamp if index>9
.ok:
    tay
    lda pitchLoTable,y
    sta $dc04
    lda pitchHiTable,y
    sta $dc05
    rts

;-----------------------------------------
; shortDelay => for beep fallback, etc.
shortDelay:
    ldx #$20
.loopX:
    ldy #$ff
.loopY:
    dey
    bne .loopY
    dex
    bne .loopX
    rts

;-----------------------------------------
; init_sid_8580 => sets DC offset for volume register digis
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
; Pitch table: 0..9 => different Timer A LSB/MSB
; Adjust these for PAL/NTSC or other desired rates
pitchLoTable:
    !byte $7b,$6b,$5b,$50,$40,$30,$28,$20,$18,$0c
pitchHiTable:
    !byte 0,0,0,0,0,0,0,0,0,0

;-----------------------------------------
; Zero-page variables
samplePtr   = $fa   ; 2 bytes => pointer to nibble data
currentByte = $fc
nibbleIndex = $fd

playbackOn  = $f8
pitchIndex  = $f9

oldIrqLo    = $fe
oldIrqHi    = $ff

;-----------------------------------------
; Old vector => chain or skip
        * = *
oldIrq:
    jmp $ea31   ; or jmp $ea81 depending on your system

;-----------------------------------------
; The appended nibble data
        * = *
sampleData:
; your 4-bit data + trailing 0 appended by “makeprg.py”
