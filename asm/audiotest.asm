!cpu 6510
!to "audiotest.prg", cbm

;--------------------------------------------------
; Program loads at $0801
* = $0801

; A minimal BASIC stub: SYS 2064
!word $080C
!word 202
!byte $9E
!text "2064",0
!word 0

;--------------------------------------------------
; Start code at $0810
* = $0810

start:
    sei
    jsr init_sid

    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1

loopTest:
    ; read next byte (which has low nibble, hi nibble)
    ldy #0
    lda (samplePtr),y
    beq done        ; if zero => done
    sta currentByte

    ; increment pointer
    inc samplePtr
    bne .skipLo
    inc samplePtr+1
.skipLo:

    ; low nibble
    and #$0f
    sta $d418

    ; read next byte to see if end or produce hi nibble
    ldy #0
    lda (samplePtr),y
    beq done
    sta currentByte

    inc samplePtr
    bne .skipHi
    inc samplePtr+1
.skipHi:

    ; high nibble
    lsr
    lsr
    lsr
    lsr
    and #$0f
    sta $d418

    jmp loopTest

done:
    lda #0
    sta $d418
stop:
    jmp stop

;--------------------------------------------------
; init_sid: zero out SID registers
init_sid:
    ldx #$18
.clearSID:
    lda #0
    sta $d400,x
    dex
    bpl .clearSID
    rts

;--------------------------------------------------
; Zero‐page pointers
samplePtr   = $fa
currentByte = $fc

;--------------------------------------------------
; Label for appended data
* = *           ; keep program counter aligned
sampleData:
; The .raw data is appended after assembly
