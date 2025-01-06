;--------------------------------------------------------------------
; loopplay_cia1_irq.asm
;
; Plays 4-bit nibble data at ~32kHz on a PAL system,
; hooking CIA #1 Timer A => IRQ.
; If first sample byte is zero => beep fallback => hang forever.
; If a sentinel 0 is read mid-play => resets pointer => infinite loop.
; Also sets up a DC offset for 8580 (works on 6581 too).
; Flickers border color each IRQ => debug indicator.
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
    jsr init_sid_8580   ; sets DC offset for 8580; harmless on 6581

    ;--------------------------------------------------
    ; zero-page pointer to sample
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1

    ; If first sample = 0 => beep fallback
    ldy #0
    lda (samplePtr),y
    beq noDataFallback

    ; nibbleIndex = $FF => force new sample byte next time
    lda #$ff
    sta nibbleIndex

    ;--------------------------------------------------
    ; Setup CIA #1 Timer A => ~32 kHz (PAL).
    ;   ~0.985 MHz / 32000 => ~31 => $1F
    lda #$1f
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

    ; Timer Control => bit6=1 => IRQ, bit0=1 => start => $51
    lda #$51
    sta $dc0e

    ;--------------------------------------------------
    ; Hook normal KERNAL IRQ ($0314/$0315)
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
    sta $d418
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
; Dec nibbleIndex: if negative => load new sample byte
; if loaded byte=0 => reset pointer => infinite loop
; else put nibble => $d418
playNibble:
    dec nibbleIndex
    bpl .hiN

    ; need a new sample byte
    ldy #0
    lda (samplePtr),y
    beq resetPointer

    sta currentByte

    ; inc pointer
    inc samplePtr
    bne +
    inc samplePtr+1
+
    ; low nibble
    and #$0f
    sta $d418

    lda #1
    sta nibbleIndex
    rts

.hiN:
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
.dX:
    ldy #$ff
.dY:
    dey
    bne .dY
    dex
    bne .dX
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
    sta $d40b

    ; Attack/Decay => $F0 => max attack(15), no decay(0)
    sta $d40c
    lda #$f0
    sta $d40d
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
; appended 4-bit data + sentinel

; ; // still too low pitched here ... 
; ;--------------------------------------------------------------------
; ; loopplay_cia1_irq.asm
; ;
; ; Plays 4-bit nibble data at ~16kHz (PAL),
; ; hooking CIA #1 Timer A => IRQ.
; ; If first sample byte is zero => beep fallback => hang.
; ; If a sentinel 0 is read mid-play => resets pointer => infinite loop.
; ; Also sets up a DC offset for 8580 (ok on 6581 too).
; ; Flickers the border color each IRQ => debug.
; ;--------------------------------------------------------------------

; !cpu 6510
; !to "loopplay.prg", cbm

;         * = $0801

; ; BASIC line 10 => SYS 2064
; !word $080c
; !word 10
; !byte $9e
; !text "2064",0
; !word 0

; ;--------------------------------------------------
; ; Start code at $0810
;         * = $0810

; start:
;     sei
;     jsr init_sid_8580   ; ensures 8580 DC offset (works fine on 6581 too)

;     ;--------------------------------------------------
;     ; Put pointer to sample data in zero-page
;     lda #<sampleData
;     sta samplePtr
;     lda #>sampleData
;     sta samplePtr+1

;     ; If first byte = 0 => beep fallback
;     ldy #0
;     lda (samplePtr),y
;     beq noDataFallback

;     ; nibbleIndex = $FF => force load new sample byte next IRQ
;     lda #$ff
;     sta nibbleIndex

;     ;--------------------------------------------------
;     ; Setup CIA #1 => Timer A => ~16 kHz (PAL)
;     ;
;     ; For PAL ~0.985 MHz => 985,248 / 16,000 ≈ 61 => $3D
;     ; If you want ~20 kHz, you'd use around 49 ($31), etc.
;     lda #$3d         ; ~16 kHz reload for PAL
;     sta $dc04        ; TimerA LSB
;     lda #$00
;     sta $dc05        ; TimerA MSB

;     ; Clear any pending CIA #1 interrupts
;     lda $dc0d
;     lda #$7f
;     sta $dc0d

;     ; Enable Timer A interrupt => bit0=TimerA, bit7=1 => enable
;     lda #$81
;     sta $dc0d

;     ; Timer Control:
;     ;  bit6=1 => IRQ
;     ;  bit0=1 => start
;     ; => 0b01010001 => $51
;     lda #$51
;     sta $dc0e

;     ;--------------------------------------------------
;     ; Hook normal KERNAL IRQ vector at $0314/$0315
;     ; We'll chain to old KERNAL IRQ after our code.
;     lda $0314
;     sta oldIrqLo
;     lda $0315
;     sta oldIrqHi

;     lda #<irqRoutine
;     sta $0314
;     lda #>irqRoutine
;     sta $0315

;     cli

; mainLoop:
;     jmp mainLoop

; ;-----------------------------------------
; ; If first read is 0 => beep => hang
; noDataFallback:
;     lda #$0f
;     sta $d418    ; beep once
;     jsr shortDelay
;     lda #0
;     sta $d418
; .hangForever:
;     jmp .hangForever

; ;-----------------------------------------
; ; IRQ routine for CIA #1 Timer A
; irqRoutine:
;     ; Toggle border color => debug => see if interrupt is firing
;     lda $d020
;     eor #$04       ; flicker with color bit2
;     sta $d020

;     ; Acknowledge CIA #1 Timer A
;     lda $dc0d
;     sta $dc0d

;     pha
;     txa
;     pha
;     tya
;     pha

;     ; read nibble => $D418
;     jsr playNibble

;     ; restore regs
;     pla
;     tay
;     pla
;     tax
;     pla

;     ; chain to old KERNAL IRQ
;     jmp oldIrq

; ;-----------------------------------------
; ; playNibble: read nibble from sample
; ; if nibbleIndex<0 => fetch new byte
; ; if new byte=0 => reset pointer => infinite loop
; ; else store nibble => $d418
; playNibble:
;     dec nibbleIndex
;     bpl .doHighNibble

;     ; nibbleIndex < 0 => load new sample byte
;     ldy #0
;     lda (samplePtr),y
;     beq resetPointer   ; 0 => sentinel => reset to start

;     sta currentByte

;     ; inc pointer
;     inc samplePtr
;     bne skipIncHigh
;     inc samplePtr+1
; skipIncHigh:

;     ; low nibble => $d418
;     and #$0f
;     sta $d418

;     lda #1
;     sta nibbleIndex
;     rts

; .doHighNibble:
;     ; high nibble => shift down 4
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

; ;-----------------------------------------
; resetPointer:
;     ; sentinel => reset pointer => infinite loop
;     lda #<sampleData
;     sta samplePtr
;     lda #>sampleData
;     sta samplePtr+1
;     rts

; ;-----------------------------------------
; shortDelay:
;     ; Only used for beep fallback
;     ldx #$20
; .delX:
;     ldy #$ff
; .delY:
;     dey
;     bne .delY
;     dex
;     bne .delX
;     rts

; ;-----------------------------------------
; ; init_sid_8580:
; ; Zero out SID => DC offset on voice3
; init_sid_8580:
;     ldx #$18
; sidClr:
;     lda #0
;     sta $d400,x
;     dex
;     bpl sidClr

;     ; enable test bit/pulse/gate on voice3 => sustain DC offset
;     lda #$51
;     sta $d40b

;     ; Attack/Decay => e.g. $F0 => max Attack=15, Decay=0
;     sta $d40c

;     ; Sustain=15 => hold DC offset, Release=0
;     lda #$f0
;     sta $d40d
;     rts

; ;-----------------------------------------
; ; zero-page & old IRQ
; samplePtr   = $fa  ; 2 bytes => pointer
; nibbleIndex = $fc
; currentByte = $fd

; oldIrqLo = $fe
; oldIrqHi = $ff

; ;-----------------------------------------
; ; We'll place oldIrq vector code at end => jmp $ea31
;         * = *
; oldIrq:
;     jmp $ea31    ; chain to standard KERNAL IRQ

; ;-----------------------------------------
; ; The appended 4-bit data plus trailing 0:
;         * = *
; sampleData:
; ; (Your .raw + 0 sentinel appended by “makeprg.py” or similar)


; ; still too low in PAL systems, but could be utilized
; ; for some really creepy sounds ...
; ;--------------------------------------------------------------------
; ; loopplay_cia1_irq.asm
; ;
; ; Plays 4-bit nibble data at ~16kHz (double speed/pitch),
; ; hooking CIA #1 Timer A => IRQ.
; ; If first sample byte is zero => beep fallback => hang.
; ; If a sentinel 0 is read mid-play => resets pointer => infinite loop.
; ; Also sets up a DC offset for 8580 (ok on 6581 too).
; ; Flickers the border color each IRQ => debug.
; ;--------------------------------------------------------------------

; !cpu 6510
; !to "loopplay.prg", cbm

;         * = $0801

; ; BASIC line 10 => SYS 2064
; !word $080c
; !word 10
; !byte $9e
; !text "2064",0
; !word 0

; ;--------------------------------------------------
; ; Start code at $0810
;         * = $0810

; start:
;     sei
;     jsr init_sid_8580   ; ensures 8580 DC offset for volume-based digi

;     ;--------------------------------------------------
;     ; Put pointer to sample data in zero-page
;     lda #<sampleData
;     sta samplePtr
;     lda #>sampleData
;     sta samplePtr+1

;     ; If first byte = 0 => beep fallback
;     ldy #0
;     lda (samplePtr),y
;     beq noDataFallback

;     ; nibbleIndex = $FF => force load new sample byte next time
;     lda #$ff
;     sta nibbleIndex

;     ;--------------------------------------------------
;     ; Setup CIA #1 => Timer A => ~16 kHz (NTSC)
;     ; ~1.0227 MHz / 16000 => ~64 => $40
;     ; If that’s too high, pick e.g. $50 => ~12.8 kHz, etc.
;     lda #$40
;     sta $dc04     ; TimerA LSB
;     lda #$00
;     sta $dc05     ; TimerA MSB

;     ; Clear any pending CIA #1 interrupts
;     lda $dc0d
;     lda #$7f
;     sta $dc0d

;     ; Enable Timer A interrupt => bit0=TimerA, bit7=1 => enable
;     lda #$81
;     sta $dc0d

;     ; Timer Control: 
;     ;  bit6=1 => IRQ
;     ;  bit0=1 => start
;     ; => 0b01010001 => $51
;     lda #$51
;     sta $dc0e

;     ;--------------------------------------------------
;     ; Hook normal KERNAL IRQ vector at $0314/$0315
;     ; We'll chain to the old KERNAL IRQ after our code.
;     lda $0314
;     sta oldIrqLo
;     lda $0315
;     sta oldIrqHi

;     lda #<irqRoutine
;     sta $0314
;     lda #>irqRoutine
;     sta $0315

;     cli

; mainLoop:
;     jmp mainLoop

; ;-----------------------------------------
; ; If first read is 0 => beep => hang
; noDataFallback:
;     lda #$0f
;     sta $d418    ; beep once
;     jsr shortDelay
;     lda #0
;     sta $d418
; .hangForever:
;     jmp .hangForever

; ;-----------------------------------------
; ; IRQ routine for CIA #1 Timer A
; irqRoutine:
;     ; Toggle border color => debug => see if interrupt is firing
;     lda $d020
;     eor #$04       ; flicker with color bit2
;     sta $d020

;     ; Acknowledge CIA #1 Timer A
;     lda $dc0d
;     sta $dc0d

;     pha
;     txa
;     pha
;     tya
;     pha

;     ; read nibble => $D418
;     jsr playNibble

;     ; restore regs
;     pla
;     tay
;     pla
;     tax
;     pla

;     ; chain to old KERNAL IRQ
;     jmp oldIrq

; ;-----------------------------------------
; ; playNibble: read nibble from sample
; ; if nibbleIndex<0 => fetch new byte
; ; if new byte=0 => reset pointer => infinite loop
; ; else store nibble => $d418
; playNibble:
;     dec nibbleIndex
;     bpl .doHighNibble

;     ; nibbleIndex < 0 => load new sample byte
;     ldy #0
;     lda (samplePtr),y
;     beq resetPointer   ; 0 => sentinel => reset to start

;     sta currentByte

;     ; inc pointer
;     inc samplePtr
;     bne skipIncHigh
;     inc samplePtr+1
; skipIncHigh:

;     ; low nibble => $d418
;     and #$0f
;     sta $d418

;     lda #1
;     sta nibbleIndex
;     rts

; .doHighNibble:
;     ; high nibble => shift down 4
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

; ;-----------------------------------------
; resetPointer:
;     ; sentinel => reset pointer => infinite loop
;     lda #<sampleData
;     sta samplePtr
;     lda #>sampleData
;     sta samplePtr+1
;     rts

; ;-----------------------------------------
; shortDelay:
;     ; Only used for beep fallback
;     ldx #$20
; .delX:
;     ldy #$ff
; .delY:
;     dey
;     bne .delY
;     dex
;     bne .delX
;     rts

; ;-----------------------------------------
; ; init_sid_8580:
; ; Zero out SID => DC offset on voice3
; init_sid_8580:
;     ldx #$18
; sidClr:
;     lda #0
;     sta $d400,x
;     dex
;     bpl sidClr

;     ; enable test bit/pulse/gate on voice3 => sustain DC offset
;     lda #$51
;     sta $d40b

;     ; Attack/Decay => e.g. $F0 => max Attack=15, Decay=0
;     sta $d40c

;     ; Sustain=15 => hold DC offset, Release=0
;     lda #$f0
;     sta $d40d
;     rts

; ;-----------------------------------------
; ; zero-page & old IRQ
; samplePtr   = $fa  ; 2 bytes => pointer
; nibbleIndex = $fc
; currentByte = $fd

; oldIrqLo = $fe
; oldIrqHi = $ff

; ;-----------------------------------------
; ; We'll place oldIrq vector code at end => jmp $ea31
;         * = *
; oldIrq:
;     jmp $ea31    ; chain to standard KERNAL IRQ

; ;-----------------------------------------
; ; The appended 4-bit data plus trailing 0:
;         * = *
; sampleData:
; ; (Your .raw + 0 sentinel appended by “makeprg.py” or similar)

; ; ;--------------------------------------------------------------------
; ; ; loopplay_cia1_irq.asm
; ; ;
; ; ; Plays 4-bit nibble data at ~8kHz, hooking CIA #1 Timer A => IRQ.
; ; ; If the first sample byte is zero => beep fallback.
; ; ; If a sentinel 0 is read mid-play => resets pointer => infinite loop.
; ; ; Also sets up a DC offset for 8580 (works on 6581 too).
; ; ; Debug: toggles border color each IRQ => see if it's firing.
; ; ;--------------------------------------------------------------------

; ; !cpu 6510
; ; !to "loopplay.prg", cbm

; ;         * = $0801

; ; ; BASIC line 10 => SYS 2064
; ; !word $080c
; ; !word 10
; ; !byte $9e
; ; !text "2064",0
; ; !word 0

; ; ;--------------------------------------------------
; ; ; Start code at $0810
; ;         * = $0810

; ; start:
; ;     sei
; ;     jsr init_sid_8580   ; ensure 8580 has DC offset for volume-based digi (6581 works too)

; ;     ;--------------------------------------------------
; ;     ; Put pointer to sample data in zero-page
; ;     lda #<sampleData
; ;     sta samplePtr
; ;     lda #>sampleData
; ;     sta samplePtr+1

; ;     ; If first sample byte is 0 => beep fallback
; ;     ldy #0
; ;     lda (samplePtr),y
; ;     beq noDataFallback

; ;     ; nibbleIndex = $FF => force load new sample byte next time
; ;     lda #$ff
; ;     sta nibbleIndex

; ;     ;--------------------------------------------------
; ;     ; Setup CIA #1 => Timer A => ~8kHz (NTSC)
; ;     ;
; ;     ; ~1.0227 MHz / 8000 => ~128 => $80
; ;     ; for PAL ~0.985 => maybe $7B
; ;     ;
; ;     lda #$80
; ;     sta $dc04     ; Timer A LSB
; ;     lda #$00
; ;     sta $dc05     ; Timer A MSB

; ;     ; Clear any pending CIA #1 interrupts
; ;     lda $dc0d
; ;     lda #$7f
; ;     sta $dc0d

; ;     ; Enable Timer A interrupt => bit0=TimerA, bit7=1 => enable
; ;     lda #$81
; ;     sta $dc0d

; ;     ; Timer Control:
; ;     ;  bit6=1 => generate IRQ
; ;     ;  bit0=1 => start
; ;     ; => 0b01010001 => $51
; ;     lda #$51
; ;     sta $dc0e

; ;     ;--------------------------------------------------
; ;     ; Hook the normal IRQ vector at $0314/$0315
; ;     ; We'll chain to the old KERNAL IRQ.
; ;     lda $0314
; ;     sta oldIrqLo
; ;     lda $0315
; ;     sta oldIrqHi

; ;     lda #<irqRoutine
; ;     sta $0314
; ;     lda #>irqRoutine
; ;     sta $0315

; ;     cli

; ; mainLoop:
; ;     jmp mainLoop

; ; ;-----------------------------------------
; ; ; If the first read is 0 => beep => hang
; ; noDataFallback:
; ;     lda #$0f
; ;     sta $d418     ; beep once
; ;     jsr shortDelay
; ;     lda #0
; ;     sta $d418
; ; .hangForever:
; ;     jmp .hangForever

; ; ;-----------------------------------------
; ; ; IRQ routine for CIA #1 Timer A
; ; irqRoutine:
; ;     ; Toggle border color => debug => see if interrupt is firing
; ;     lda $d020
; ;     eor #$04       ; flicker with color bit2
; ;     sta $d020

; ;     ; Acknowledge CIA #1 Timer A
; ;     lda $dc0d
; ;     sta $dc0d

; ;     pha
; ;     txa
; ;     pha
; ;     tya
; ;     pha

; ;     ; read nibble => $D418
; ;     jsr playNibble

; ;     ; restore regs
; ;     pla
; ;     tay
; ;     pla
; ;     tax
; ;     pla

; ;     ; chain to old KERNAL IRQ
; ;     jmp oldIrq

; ; ;-----------------------------------------
; ; ; playNibble: read nibble from sample
; ; ; if nibbleIndex<0 => fetch new byte
; ; ; if new byte=0 => reset pointer => infinite loop
; ; ; else store nibble => $d418
; ; playNibble:
; ;     dec nibbleIndex
; ;     bpl .doHighNibble

; ;     ; nibbleIndex < 0 => load new sample byte
; ;     ldy #0
; ;     lda (samplePtr),y
; ;     beq resetPointer   ; 0 => sentinel => reset

; ;     sta currentByte

; ;     ; inc pointer
; ;     inc samplePtr
; ;     bne skipIncHigh
; ;     inc samplePtr+1
; ; skipIncHigh:

; ;     ; low nibble => $d418
; ;     and #$0f
; ;     sta $d418

; ;     lda #1
; ;     sta nibbleIndex
; ;     rts

; ; .doHighNibble:
; ;     ; high nibble => shift down 4
; ;     lda currentByte
; ;     lsr
; ;     lsr
; ;     lsr
; ;     lsr
; ;     and #$0f
; ;     sta $d418

; ;     lda #$ff
; ;     sta nibbleIndex
; ;     rts


; ; ;-----------------------------------------
; ; resetPointer:
; ;     ; if sentinel read => reset pointer => infinite loop
; ;     lda #<sampleData
; ;     sta samplePtr
; ;     lda #>sampleData
; ;     sta samplePtr+1
; ;     rts


; ; ;-----------------------------------------
; ; shortDelay:
; ;     ldx #$20
; ; .delX:
; ;     ldy #$ff
; ; .delY:
; ;     dey
; ;     bne .delY
; ;     dex
; ;     bne .delX
; ;     rts

; ; ;-----------------------------------------
; ; ; init_sid_8580:
; ; ; Zero out SID => DC offset on voice3
; ; init_sid_8580:
; ;     ldx #$18
; ; sidClr:
; ;     lda #0
; ;     sta $d400,x
; ;     dex
; ;     bpl sidClr

; ;     ; enable test bit/pulse/gate on voice3 => sustain DC offset
; ;     lda #$51
; ;     sta $d40b

; ;     ; Attack/Decay => e.g. $F0 => max Attack=15, Decay=0
; ;     sta $d40c

; ;     ; Sustain=15 => hold DC offset, Release=0
; ;     lda #$f0
; ;     sta $d40d
; ;     rts

; ; ;-----------------------------------------
; ; ; zero-page & old IRQ
; ; samplePtr   = $fa  ; 2 bytes => pointer
; ; nibbleIndex = $fc
; ; currentByte = $fd

; ; oldIrqLo = $fe
; ; oldIrqHi = $ff

; ; ;-----------------------------------------
; ; ; We'll place oldIrq vector code at end => jmp $ea31
; ; ; or $ea81, depends on your KERNAL. Usually $ea31 is standard.
; ;         * = *
; ; oldIrq:
; ;     jmp $ea31    ; chain to standard KERNAL IRQ

; ; ;-----------------------------------------
; ; ; The appended 4-bit data plus trailing 0:
; ;         * = *
; ; sampleData:
; ; ; (Will be appended via merge tool, e.g. "makeprg.py" merges .raw + a 0 byte.)

; ; ; // old tryouts with incorrect timings;
; ; ; ;--------------------------------------------------------------------
; ; ; ; loopplay_cia1_irq.asm
; ; ; ;
; ; ; ; Plays 4-bit nibble data at ~8kHz, hooking CIA #1 Timer A => IRQ.
; ; ; ; If the first sample byte is zero => beep fallback.
; ; ; ; If a sentinel 0 is read in the middle => resets pointer => infinite loop.
; ; ; ; Also sets up a DC offset for 8580 (works on 6581 too).
; ; ; ; Debug: toggles border color each IRQ => see if it's firing.
; ; ; ;--------------------------------------------------------------------

; ; ; !cpu 6510
; ; ; !to "loopplay.prg", cbm

; ; ;         * = $0801

; ; ; ; BASIC line 10: SYS2064
; ; ; !word $080c
; ; ; !word 10
; ; ; !byte $9e
; ; ; !text "2064",0
; ; ; !word 0

; ; ; ;--------------------------------------------------
; ; ; ; Start code at $0810
; ; ;         * = $0810

; ; ; start:
; ; ;     sei
; ; ;     jsr init_sid_8580  ; ensures 8580 has DC offset for volume-based digi

; ; ;     ;--------------------------------------------------
; ; ;     ; Put pointer to sample data in zero-page
; ; ;     lda #<sampleData
; ; ;     sta samplePtr
; ; ;     lda #>sampleData
; ; ;     sta samplePtr+1

; ; ;     ; If first sample byte is 0 => beep fallback
; ; ;     ldy #0
; ; ;     lda (samplePtr),y
; ; ;     beq noDataFallback

; ; ;     ; nibbleIndex = $FF => force load new sample byte next time
; ; ;     lda #$ff
; ; ;     sta nibbleIndex

; ; ;     ;--------------------------------------------------
; ; ;     ; Setup CIA #1 => Timer A => ~8kHz
; ; ;     ; For NTSC ~1.0227 MHz => 1,022,727 / 8000 ~ 128 => $80
; ; ;     ; For PAL (~0.985 MHz) you might want $7B or so. We'll pick $80 for NTSC example.
; ; ;     lda #$80
; ; ;     sta $dc04   ; TimerA LSB
; ; ;     lda #0
; ; ;     sta $dc05   ; TimerA MSB

; ; ;     ; Clear any pending CIA #1 interrupts
; ; ;     lda $dc0d
; ; ;     lda #$7f
; ; ;     sta $dc0d

; ; ;     ; Enable Timer A interrupt => bit0=TimerA, bit7=1 => enable
; ; ;     lda #$81
; ; ;     sta $dc0d

; ; ;     ; Timer Control: 
; ; ;     ;  bit6=1 => generate IRQ
; ; ;     ;  bit0=1 => start timer
; ; ;     ; => 0b01010001 => $51
; ; ;     lda #$51
; ; ;     sta $dc0e

; ; ;     ;--------------------------------------------------
; ; ;     ; Hook the normal IRQ vector at $0314/$0315
; ; ;     ; (We can chain the old vector or we can just
; ; ;     ;  do a minimal "rti" after the digi code. 
; ; ;     ;  We'll do a "chain to old KERNAL" approach.)
; ; ;     lda $0314
; ; ;     sta oldIrqLo
; ; ;     lda $0315
; ; ;     sta oldIrqHi

; ; ;     lda #<irqRoutine
; ; ;     sta $0314
; ; ;     lda #>irqRoutine
; ; ;     sta $0315

; ; ;     cli

; ; ; mainLoop:
; ; ;     jmp mainLoop


; ; ; ;-----------------------------------------
; ; ; ; If the first read is 0 => beep => hang
; ; ; noDataFallback:
; ; ;     lda #$0f
; ; ;     sta $d418     ; beep
; ; ;     jsr shortDelay
; ; ;     lda #0
; ; ;     sta $d418
; ; ; .hangForever:
; ; ;     jmp .hangForever


; ; ; ;-----------------------------------------
; ; ; ; IRQ routine for CIA #1 Timer A
; ; ; irqRoutine:
; ; ;     ; Toggle border color => debug => see if interrupt is firing
; ; ;     lda $d020
; ; ;     eor #$04       ; flicker with color bit2
; ; ;     sta $d020

; ; ;     ; Acknowledge CIA #1 Timer A
; ; ;     lda $dc0d
; ; ;     sta $dc0d

; ; ;     pha
; ; ;     txa
; ; ;     pha
; ; ;     tya
; ; ;     pha

; ; ;     ; read nibble => $D418
; ; ;     jsr playNibble

; ; ;     ; restore regs
; ; ;     pla
; ; ;     tay
; ; ;     pla
; ; ;     tax
; ; ;     pla

; ; ;     ; chain to old KERNAL IRQ if desired
; ; ;     jmp oldIrq

; ; ; ;-----------------------------------------
; ; ; ; read nibble from sample
; ; ; ; if nibbleIndex<0 => fetch new byte
; ; ; ; if new byte=0 => reset pointer => loop
; ; ; ; else store nibble => $d418
; ; ; playNibble:
; ; ;     dec nibbleIndex
; ; ;     bpl .doHigh

; ; ;     ; nibbleIndex < 0 => load new sample byte
; ; ;     ldy #0
; ; ;     lda (samplePtr),y
; ; ;     beq resetPointer   ; 0 => sentinel => reset

; ; ;     sta currentByte

; ; ;     ; inc pointer
; ; ;     inc samplePtr
; ; ;     bne +
; ; ;     inc samplePtr+1
; ; ; +
; ; ;     ; low nibble
; ; ;     and #$0f
; ; ;     sta $d418

; ; ;     lda #1
; ; ;     sta nibbleIndex
; ; ;     rts

; ; ; .doHigh:
; ; ;     ; high nibble
; ; ;     lda currentByte
; ; ;     lsr
; ; ;     lsr
; ; ;     lsr
; ; ;     lsr
; ; ;     and #$0f
; ; ;     sta $d418

; ; ;     lda #$ff
; ; ;     sta nibbleIndex
; ; ;     rts


; ; ; ;-----------------------------------------
; ; ; resetPointer:
; ; ;     ; if sentinel read => reset pointer => infinite loop
; ; ;     lda #<sampleData
; ; ;     sta samplePtr
; ; ;     lda #>sampleData
; ; ;     sta samplePtr+1
; ; ;     rts


; ; ; ;-----------------------------------------
; ; ; shortDelay:
; ; ;     ldx #$20
; ; ; .delX:
; ; ;     ldy #$ff
; ; ; .delY:
; ; ;     dey
; ; ;     bne .delY
; ; ;     dex
; ; ;     bne .delX
; ; ;     rts


; ; ; ;-----------------------------------------
; ; ; ; init_sid_8580:
; ; ; ; Zero out SID => DC offset on voice3
; ; ; init_sid_8580:
; ; ;     ldx #$18
; ; ; sidClr:
; ; ;     lda #0
; ; ;     sta $d400,x
; ; ;     dex
; ; ;     bpl sidClr

; ; ;     lda #$51
; ; ;     sta $d40b     ; test=1, pulse=1, gate=1
; ; ;     sta $d40c     ; Attack=5, Decay=1 => not crucial
; ; ;     lda #$f0
; ; ;     sta $d40d     ; Sustain=15 => hold DC offset
; ; ;     rts

; ; ; ;-----------------------------------------
; ; ; ; zero-page & old IRQ
; ; ; samplePtr   = $fa  ; 2 bytes => pointer
; ; ; nibbleIndex = $fc
; ; ; currentByte = $fd

; ; ; oldIrqLo = $fe
; ; ; oldIrqHi = $ff

; ; ; ;-----------------------------------------
; ; ; ; We'll place oldIrq vector code at end => jmp $ea31 or $ea81
; ; ; ; Usually KERNAL's main IRQ is at $ea31 (JSR $ea7e, etc).
; ; ;         * = *
; ; ; oldIrq:
; ; ;     jmp $ea31    ; chain to standard KERNAL

; ; ; ;-----------------------------------------
; ; ; ; The appended 4-bit data plus trailing 0:
; ; ;         * = *
; ; ; sampleData:
; ; ; ; "makeprg.py" or similar merges your .raw + 0 sentinel
