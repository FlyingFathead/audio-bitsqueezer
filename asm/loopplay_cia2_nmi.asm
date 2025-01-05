;---------------------------------------------
; loopplay_cia2_nmi.asm
; 
; 4-bit sample playing via $D418 volume changes, at ~8kHz, 
; using CIA #2 Timer => NMI interrupts. 
; 
; If the first sample byte is zero => beep fallback.
; If sentinel (0) is read in the middle => reset pointer => loop forever.
; 
; We also do the "init_sid_8580" to get DC offset for 8580 SIDs.
;---------------------------------------------

!cpu 6510
!to "loopplay.prg", cbm

        * = $0801

; BASIC line: 10 SYS 2064
!word $080c
!word 10
!byte $9e
!text "2064",0
!word 0

;-----------------------------------------
; Start code at $0810
        * = $0810

start:
    sei
    jsr init_sid_8580

    ; Put pointer to sample data in zero-page
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1

    ; Check if first byte is zero => beep fallback
    ldy #0
    lda (samplePtr),y
    beq noDataFallback

    ; Initialize nibbleIndex to $FF => forces load of new byte for next nibble
    lda #$ff
    sta nibbleIndex

    ;-----------------------------------------
    ; Setup CIA #2 Timer => NMI at ~8kHz
    ; (NTSC => ~1.02 MHz => 1,022,727 / 8000 ~ 128 => $80)
    lda #$80          ; Timer LSB
    sta $dd04
    lda #0            ; Timer MSB
    sta $dd05

    ; Clear any pending interrupts
    lda #$7f
    sta $dd0d
    lda $dd0d        ; read to fully ack

    ; Enable Timer A interrupt => bit0=TimerA, bit7=1 => enable
    lda #$81
    sta $dd0d

    ; Timer control (CIA#2):
    ;  bit7=0 => system clock
    ;  bit6=1 => NMI
    ;  bit0=1 => start
    ; => 0b01010001 => $51
    lda #$51
    sta $dd0e

    ;-----------------------------------------
    ; Hook NMI vector => we store at $fffa,$fffb
    lda #<nmiRoutine
    sta $fffa
    lda #>nmiRoutine
    sta $fffb

    cli

    ; Just idle here forever while NMI does the playback
mainLoop:
    jmp mainLoop

;-----------------------------------------
; If the first read is zero => beep then hang
noDataFallback:
    lda #$0f
    sta $d418     ; beep
    jsr shortDelay
    lda #0
    sta $d418
.hangForever:
    jmp .hangForever


;-----------------------------------------
; NMI routine (CIA #2 Timer). 
; We read nibble from sample data, store to $D418. 
nmiRoutine:
    ; Acknowledge CIA #2
    lda $dd0d
    sta $dd0d

    ; push regs
    pha
    txa
    pha
    tya
    pha

    ;--- Debug? Toggle a screen char, or store nibble-ASCII
    ; lda $0400
    ; eor #$80
    ; sta $0400

    jsr playNibble

    ; pop regs
    pla
    tay
    pla
    tax
    pla

    rti


;-----------------------------------------
; playNibble: 
;  - if nibbleIndex<0 => load new byte from sample
;  - if loaded byte=0 => sentinel => reset pointer => infinite loop
;  - else output nibble (low or hi)
playNibble:
    dec nibbleIndex
    bpl .gotHigh  ; if nibbleIndex >= 0 => do high nibble

    ; nibbleIndex < 0 => load new byte
    ldy #0
    lda (samplePtr),y
    beq resetPointer    ; if we read 0 => sentinel => reset pointer => loop forever

    sta currentByte

    ; increment pointer
    inc samplePtr
    bne .noIncHi
    inc samplePtr+1
.noIncHi:

    ; next nibble is the "low" nibble (bits0..3)
    and #$0f
    sta $d418

    ;--- (optional) store nibble ASCII to $0400
    ;  lda $d418
    ;  and #$0f
    ;  ora #$30
    ;  sta $0400

    ; set nibbleIndex=1 => next time do high nibble
    lda #1
    sta nibbleIndex
    rts

.gotHigh:
    lda currentByte
    lsr
    lsr
    lsr
    lsr
    and #$0f
    sta $d418

    ;--- (optional) store nibble ASCII to $0401
    ;  lda $d418
    ;  and #$0f
    ;  ora #$30
    ;  sta $0401

    ; set nibbleIndex=-1 => next time do new byte
    lda #$ff
    sta nibbleIndex
    rts


;-----------------------------------------
resetPointer:
    ; If we read sentinel => set pointer back to sampleData => infinite loop
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1
    rts


;-----------------------------------------
; shortDelay: just used in beep fallback
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
; init_sid_8580: clear SID + set voice3 test bit => DC offset
init_sid_8580:
    ldx #$18
.clrLoop:
    lda #0
    sta $d400,x
    dex
    bpl .clrLoop

    lda #$51
    sta $d40b       ; bit6=test=1, bit4=pulse=1, bit0=gate=1
    sta $d40c       ; Attack/Decay = $51 => not too crucial
    lda #$f0
    sta $d40d       ; Sustain/Release => $F0 => sustain=15
    rts


;-----------------------------------------
; Zero-page
samplePtr   = $fa  ; 2 bytes => pointer to our nibble data
nibbleIndex = $fc  ; 1 byte => -1 => read new, 1 => do hi nibble
currentByte = $fd  ; 1 byte => store loaded sample byte

;-----------------------------------------
; The appended 4-bit data goes here plus trailing 0
        * = *
sampleData:
; (Merged via “makeprg.py” or your approach)
