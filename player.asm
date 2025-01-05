!cpu 6510
!to "player.bin", cbm         ; ACME directive: produce "player.bin" in CBM/PRG format

;--------------------------------------------------
; 1) Program loads at $0801 for Commodore 64
* = $0801

; --- BASIC stub to jump to code at $0810
!word $080C              ; Next BASIC line pointer
!word 202                ; BASIC line number
!byte $9E                ; SYS token
!text "2064",0           ; "SYS 2064" + null terminator
!word 0                  ; End of BASIC program

;--------------------------------------------------
; 2) Actual machine code starts at $0810
* = $0810

start:
    sei
    jsr init_sid

    ;--------------------------------------------------
    ; Initialize pointer to sampleData in zero-page
    ; We'll store <sampleData into $FA, and >sampleData into $FB
    ; so (samplePtr),y -> ( $FA ),y is valid addressing
    lda #<sampleData
    sta samplePtr       ; low byte -> $FA
    lda #>sampleData
    sta samplePtr+1     ; high byte -> $FB

    ; nibbleIndex = -1 => forces load of a new byte
    lda #$ff
    sta nibbleIndex     ; ( $FC )

    ;--------------------------------------------------
    ; Setup CIA #2 Timer => ~8 kHz
    ; For NTSC ~1.02MHz => 1022727 / 8000 ~ 128 => $80
    lda #$80
    sta $dd04     ; Timer A LSB
    lda #0
    sta $dd05     ; Timer A MSB

    ; turn off pending interrupts on CIA2
    lda #$7F
    sta $dd0d
    lda $dd0d

    ; enable Timer A interrupt (bit0=TimerA, bit7=1 => enable)
    lda #$81
    sta $dd0d

    ; Timer control: bit0=1 => start timer, bit5=1 => NMI
    lda #$11
    sta $dd0e

    cli
mainLoop:
    rts    ; returns to BASIC prompt if no loop

;--------------------------------------------------
; NMI routine (fires ~8k times/s). We'll push regs, do the sample routine
nmiRoutine:
    pha
    txa
    pha
    tya
    pha

    lda $dd0d               ; Acknowledge CIA2 interrupt
    jsr playSample4bit

    pla
    tay
    pla
    tax
    pla
    rti

;--------------------------------------------------
; playSample4bit: read nibble from sample. 
;  - We store pointer in $FA/$FB (samplePtr).
;  - nibbleIndex ($FC) tracks lo nibble (0) vs. hi nibble(1).
;  - 'currentByte' is at $FD.
;  - If the loaded byte is 0 => sentinel => stop playback.
playSample4bit:
    dec nibbleIndex
    bpl gotHighNybble    ; if nibbleIndex >= 0 => do hi nibble

    ; nibbleIndex < 0 => need a new byte
    ldy #0
    lda (samplePtr),y    ; load next sample byte using zero-page indirect
    beq stopPlayback

    sta currentByte

    ; advance pointer
    inc samplePtr
    bne skipIncHigh
    inc samplePtr+1
skipIncHigh:

    ; next time, do high nibble
    lda #1
    sta nibbleIndex

    and #$0F             ; low nibble
    sta $D418            ; set SID master volume
    rts

gotHighNybble:
    lda currentByte
    lsr
    lsr
    lsr
    lsr
    and #$0F             ; high nibble
    sta $D418

    ; reset nibbleIndex to -1
    lda #$ff
    sta nibbleIndex
    rts

stopPlayback:
    ; disable timer
    lda #$7F
    sta $dd0d
    lda #0
    sta $dd0e
    lda $dd0d

    ; volume=0
    lda #0
    sta $D418

    ; restore NMI vector if you want
    lda #$47
    sta $0318
    lda #$fe
    sta $0319

    rts

;--------------------------------------------------
; init_sid: zero out SID registers, optional "digiboost" for 8580, etc.
init_sid:
    ldx #$18
clrSid:
    lda #0
    sta $d400,x
    dex
    bpl clrSid
    rts

;--------------------------------------------------
; 3) Zero-page definitions
; We'll pick these addresses manually:
; samplePtr = $FA,$FB is our pointer
; nibbleIndex = $FC
; currentByte = $FD

!zone 0       ; or you can just do direct eqm

samplePtr  = $fa      ; 2 bytes => $fa, $fb
nibbleIndex= $fc      ; 1 byte => $fc
currentByte= $fd      ; 1 byte => $fd

;--------------------------------------------------
; 4) Label for appended data
* = *          ; keep program counter the same
sampleData:
; raw 4-bit data appended externally
