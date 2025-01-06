;--------------------------------------------------------------------
; loopplay_cia1_irq_16k.asm
;
; Plays 4-bit nibble data at ~16 kHz (double speed),
; hooking CIA #1 Timer A => IRQ on a Commodore 64.
;
; If first sample byte is zero => beep fallback => hang forever.
; If a sentinel "0" is read mid-play => reset pointer => infinite loop.
; Also sets up a DC offset for 8580 (works on 6581 too).
; Flickers the border color each IRQ => debug (so you see if it's firing).
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
    jsr init_sid_8580   ; ensures 8580 DC offset for volume-based digi (6581 is fine too)

    ;--------------------------------------------------
    ; Put pointer to sample data in zero-page
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1

    ; If first byte = 0 => beep fallback
    ldy #0
    lda (samplePtr),y
    beq noDataFallback

    ; nibbleIndex = $FF => force “load new byte” next time
    lda #$ff
    sta nibbleIndex

    ;--------------------------------------------------
    ; Setup CIA #1 => Timer A => ~16 kHz
    ;
    ;   For NTSC (≈1.0227 MHz):
    ;      1,022,727 / 16,000 ≈ 64 decimal => $40
    ;
    ;   For PAL (≈0.985 MHz):
    ;      985,248 / 16,000 ≈ 61.58 => say $3D or $3E
    ;
    ; We'll show the NTSC example with $40. 
    ; If you're on PAL, try $3D or so. 
    ;
    lda #$40
    sta $dc04     ; TimerA LSB
    lda #$00
    sta $dc05     ; TimerA MSB

    ; Clear any pending CIA #1 interrupts
    lda $dc0d
    lda #$7f
    sta $dc0d

    ; Enable Timer A interrupt => bit0=TimerA, bit7=1 => “enable”
    lda #$81
    sta $dc0d

    ; Timer Control:
    ;   bit6=1 => generate IRQ
    ;   bit0=1 => start
    ; => 0b01010001 => $51
    lda #$51
    sta $dc0e

    ;--------------------------------------------------
    ; Hook normal KERNAL IRQ vector at $0314/$0315
    ; We'll chain to the old KERNAL IRQ after our code.
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
; If first read is 0 => beep => hang
noDataFallback:
    lda #$0f
    sta $d418    ; beep once
    jsr shortDelay
    lda #0
    sta $d418
.hangForever:
    jmp .hangForever

;-----------------------------------------
; IRQ routine for CIA #1 Timer A
irqRoutine:
    ; Toggle border color => debug => see if interrupt is firing
    lda $d020
    eor #$04       ; flicker with color bit2
    sta $d020

    ; Acknowledge CIA #1 Timer A
    lda $dc0d
    sta $dc0d

    pha
    txa
    pha
    tya
    pha

    ; read nibble => $D418
    jsr playNibble

    ; restore regs
    pla
    tay
    pla
    tax
    pla

    ; chain to old KERNAL IRQ
    jmp oldIrq

;-----------------------------------------
; playNibble: read nibble from sample
; if nibbleIndex<0 => fetch new byte
; if new byte=0 => reset pointer => infinite loop
; else store nibble => $d418
playNibble:
    dec nibbleIndex
    bpl .doHighNibble

    ; nibbleIndex < 0 => load new sample byte
    ldy #0
    lda (samplePtr),y
    beq resetPointer   ; 0 => sentinel => reset to start

    sta currentByte

    ; inc pointer
    inc samplePtr
    bne .skipIncHigh
    inc samplePtr+1
.skipIncHigh:

    ; low nibble => $d418
    and #$0f
    sta $d418

    lda #1
    sta nibbleIndex
    rts

.doHighNibble:
    ; high nibble => shift down 4
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
    ; sentinel => reset pointer => infinite loop
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1
    rts

;-----------------------------------------
shortDelay:
    ; Only used for beep fallback
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
; init_sid_8580:
; Zero out SID => DC offset on voice3
init_sid_8580:
    ldx #$18
sidClr:
    lda #0
    sta $d400,x
    dex
    bpl sidClr

    ; enable test bit/pulse/gate on voice3 => sustain DC offset
    lda #$51
    sta $d40b

    ; Attack/Decay => e.g. $F0 => max Attack=15, Decay=0
    sta $d40c

    ; Sustain=15 => hold DC offset, Release=0
    lda #$f0
    sta $d40d
    rts

;-----------------------------------------
; zero-page & old IRQ
samplePtr   = $fa  ; 2 bytes => pointer
nibbleIndex = $fc
currentByte = $fd

oldIrqLo = $fe
oldIrqHi = $ff

;-----------------------------------------
; We'll place oldIrq vector code at end => jmp $ea31
        * = *
oldIrq:
    jmp $ea31    ; chain to standard KERNAL IRQ

;-----------------------------------------
; The appended 4-bit data plus trailing 0:
        * = *
sampleData:
; (Your .raw + 0 sentinel appended by “makeprg.py” or similar)
