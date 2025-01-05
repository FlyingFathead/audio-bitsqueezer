;------------------------------------------
; A CIA #1 Timer + IRQ hooking example
;------------------------------------------

!to "player.bin", cbm
!cpu 6510

* = $0801
!word $080c
!word 202
!byte $9e
!text "2064",0
!word 0

* = $0810
start:
    sei
    jsr init_sid

    ; Save old IRQ vector so we can chain it
    lda $0314
    sta oldIrqLo
    lda $0315
    sta oldIrqHi

    ; Put our new vector in $0314/$0315
    lda #<irqRoutine
    sta $0314
    lda #>irqRoutine
    sta $0315

    ; Set up CIA #1 Timer A for ~8kHz (NTSC):
    ;  ~1.02 MHz / 8000 => ~128 => $80
    lda #$80
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

    ; Timer Control: bit0=1 => start, bit6=1 => generate IRQ
    ; (some docs say bit5=1 for one‐shot vs. continuous, etc.)
    lda #$11
    sta $dc0e

    cli

mainLoop:
    jmp mainLoop


;------------------------------------------
; Our IRQ routine
;------------------------------------------
irqRoutine:
    ; For debugging: flicker top-left char at $0400
    lda $0400
    eor #$80
    sta $0400

    ; Acknowledge CIA #1 IRQ
    lda $dc0d
    sta $dc0d

    pha
    txa
    pha
    tya
    pha

    jsr playSample4bit

    pla
    tay
    pla
    tax
    pla

    ; Now chain to old KERNAL handler
    jmp oldIrq

;------------------------------------------
; Our sample routine (unchanged)
;------------------------------------------
playSample4bit:
    dec nibbleIndex
    bpl .gotHigh
    ; load new byte, etc...
    ; (like your existing logic)

    rts
.gotHigh:
    ; ...
    rts

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
.clear:
    lda #0
    sta $d400,x
    dex
    bpl .clear
    rts

; Zero‐page for pointer, etc.
samplePtr   = $fa
nibbleIndex = $fc
currentByte = $fd

; store old KERNAL vector here
oldIrqLo = $fe
oldIrqHi = $ff

* = *
sampleData:
; appended data
oldIrq:
    jmp $ea7e   ; standard KERNAL IRQ entry, or $ea31 + bit trick

; !cpu 6510
; !to "player.bin", cbm

; * = $0801

; ; BASIC stub: SYS 2064
; !word $080C
; !word 202
; !byte $9E
; !text "2064",0
; !word 0

; * = $0810

; start:
;     sei
;     jsr init_sid

;     ; Store sample pointer in zero-page ($fa/$fb)
;     lda #<sampleData
;     sta samplePtr
;     lda #>sampleData
;     sta samplePtr+1

;     ; nibbleIndex = -1 => force new byte
;     lda #$ff
;     sta nibbleIndex

;     ; Setup CIA #1 Timer A => ~8 kHz
;     ; CIA #1 is at $DC00
;     ; For NTSC ~1.02 MHz => 1022730/8k => ~128, so:
;     lda #$80
;     sta $dc04  ; Timer A LSB
;     lda #0
;     sta $dc05  ; Timer A MSB

;     ; Clear pending interrupts
;     lda $dc0d
;     lda #$7f
;     sta $dc0d

;     ; Enable Timer A interrupt => bit0=TimerA; bit7=1 => enable
;     lda #$81
;     sta $dc0d

;     ; Timer Control: bit0=1 => start timer, bit6=1 => send IRQ
;     ; (bit6=1 means IRQ, not NMI on CIA #1)
;     lda #$12  ; bit4=0 => One-shot=0? Actually we want "continuous"...
;     ; bit7=0 => run at system clock
;     ; bit6=1 => irq
;     ; bit0=1 => start
;     sta $dc0e

;     ; Install our IRQ vector at $0314
;     lda #<irqRoutine
;     sta $0314
;     lda #>irqRoutine
;     sta $0315

;     ; Clear the normal CIA #1 IRQ from the KERNAL so it doesn’t run
;     ; or we can just do a custom routine that JSR oldVector if needed
;     ; For minimal example: we won't chain old vector
;     cli

; mainLoop:
;     jmp mainLoop

; ;---------------------------
; ; CIA #1 Timer A -> normal IRQ => jump here
; irqRoutine:
;     ; Toggle screen char at $0400 for debug
;     lda $0400
;     eor #$80
;     sta $0400

;     ; Acknowledge CIA #1 interrupt
;     lda $dc0d
;     sta $dc0d  ; any write to $dc0d acknowledges

;     pha
;     txa
;     pha
;     tya
;     pha

;     jsr playSample4bit

;     pla
;     tay
;     pla
;     tax
;     pla

;     jmp $ea81   ; KERNAL RTI, or do "rti" if you've disabled the KERNAL's normal IRQ
;     ; Typically you'd do "bit $ea31 : rti" or "jmp $ea81" for handshake with KERNAL.
;     ; If you want to fully override KERNAL, just do rti.

; ;---------------------------
; ; read 2 nibbles from sample
; playSample4bit:
;     dec nibbleIndex
;     bpl gotHigh

;     ldy #0
;     lda (samplePtr),y
;     beq stopPlayback

;     sta currentByte
;     inc samplePtr
;     bne +
;     inc samplePtr+1
; +
;     lda #1
;     sta nibbleIndex
;     and #$0f
;     sta $d418
;     rts

; gotHigh:
;     lda currentByte
;     lsr
;     lsr
;     lsr
;     lsr
;     and #$0f
;     sta $d418

;     lda #$ff
;     sta nibbleIndex
;     rts

; stopPlayback:
;     ; disable Timer
;     lda #0
;     sta $dc0e
;     lda $dc0d
;     lda #$7f
;     sta $dc0d

;     ; volume=0
;     lda #0
;     sta $d418

;     ; restore normal KERNAL IRQ vector or do nothing
;     lda #<OldIrq
;     sta $0314
;     lda #>OldIrq
;     sta $0315

;     rts

; init_sid:
;     ldx #$18
; clrSid:
;     lda #0
;     sta $d400,x
;     dex
;     bpl clrSid
;     rts

; ; Zero-page pointers
; !zone 0
; samplePtr  = $fa
; nibbleIndex= $fc
; currentByte= $fd

; * = *
; sampleData:
; ; appended data
; OldIrq:
;     rti
