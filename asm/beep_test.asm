!cpu 6510
!to "beep_test.prg", cbm

* = $0801

; Minimal BASIC stub: SYS 2064
!word $080c
!word 202
!byte $9e
!text "2064",0
!word 0

* = $0810

start:
    sei
    jsr init_sid

    ; Save old IRQ vector
    lda $0314
    sta oldIrqLo
    lda $0315
    sta oldIrqHi

    ; Hook our new IRQ vector
    lda #<irqRoutine
    sta $0314
    lda #>irqRoutine
    sta $0315

    ; Setup CIA #1 Timer A => ~100 Hz beep
    ; 1.02MHz / 100 => ~10200 => decimal ~ $27 0x9f
    ; We'll do a simpler ~200 Hz beep => ~5100 => decimal ~ $13 0xec
    ; Let's pick 0x1388 (~5000 decimal) for a ~200 Hz beep
    lda #$88
    sta $dc04
    lda #$13
    sta $dc05

    ; Clear pending
    lda $dc0d
    lda #$7f
    sta $dc0d

    ; Enable Timer A interrupt => bit0=TimerA, bit7=1 => enable
    lda #$81
    sta $dc0d

    ; Timer control: bit0=1 => start, bit6=1 => IRQ
    lda #$12
    sta $dc0e

    cli

mainLoop:
    jmp mainLoop

;-----------------------------------------
; Our IRQ routine (CIA #1 TimerA)
irqRoutine:
    ; Flicker char at $0400 for debug
    lda $0400
    eor #$80
    sta $0400

    ; Acknowledge CIA #1
    lda $dc0d
    sta $dc0d

    pha
    txa
    pha
    tya
    pha

    ; Toggle beep
    jsr beepToggle

    pla
    tay
    pla
    tax
    pla
    jmp oldIrq

;-----------------------------------------
; beepToggle: Toggles master volume 0 <-> 15
beepToggle:
    lda beepFlag
    eor #1
    sta beepFlag

    lda beepFlag
    beq .set0
    lda #$0f      ; volume=15
    sta $d418
    rts
.set0:
    lda #0
    sta $d418
    rts

;-----------------------------------------
; Stop playback (not used in this test)
stopPlayback:
    ; disable Timer
    lda #0
    sta $dc0e
    lda $dc0d
    lda #$7f
    sta $dc0d

    lda #0
    sta $d418

    ; restore old vector
    lda oldIrqHi
    sta $0315
    lda oldIrqLo
    sta $0314
    rts

init_sid:
    ldx #$18
.clearSid:
    lda #0
    sta $d400,x
    dex
    bpl .clearSid
    rts

; Zero-page
beepFlag  = $fa
oldIrqLo  = $fc
oldIrqHi  = $fd

* = *
oldIrq:
    jmp $ea7e  ; standard KERNAL IRQ
