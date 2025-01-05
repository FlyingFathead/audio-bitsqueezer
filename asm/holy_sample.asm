!cpu 6510
!to "holy_sample.prg", cbm

* = $0801
!word $080c
!word 10
!byte $9e
!text "2064",0
!word 0

* = $0810

start:
    sei
    jsr init_sid

    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1

mainLoop:
    ; read a byte from appended data
    ldy #0
    lda (samplePtr),y
    beq done        ; if zero => end
    sta currentByte

    inc samplePtr
    bne .skipLow
    inc samplePtr+1
.skipLow:
    ; low nibble -> $d418
    and #$0f
    sta $d418

    ; next byte for high nibble
    ldy #0
    lda (samplePtr),y
    beq done
    sta currentByte

    inc samplePtr
    bne .skipHigh
    inc samplePtr+1
.skipHigh:
    ; high nibble
    lsr
    lsr
    lsr
    lsr
    and #$0f
    sta $d418

    jmp mainLoop

done:
    lda #0
    sta $d418
stop: jmp stop

init_sid:
    ldx #$18
.clearSid:
    lda #0
    sta $d400,x
    dex
    bpl .clearSid
    rts

samplePtr   = $fa
currentByte = $fc

* = *
sampleData:
; your .raw data appended, plus a trailing 00 if you want an end sentinel
