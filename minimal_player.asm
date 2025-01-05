!to "player.bin", cbm    ; Tells ACME to write a CBM/P00 style binary

* = $0801                 ; Start of BASIC area
!word $080c               ; Next line pointer
!word 201                 ; BASIC line number
!byte $9e                 ; SYS token
!text "2064",0            ; "SYS 2064" + null terminator
!word 0                   ; end of BASIC program

* = $0810                 ; code starts at $0810

start:
    sei
    jsr init_sid
    lda #<sampleData
    sta samplePtr
    lda #>sampleData
    sta samplePtr+1

    jsr init_timer

    cli
mainLoop:
    rts

; --- NMI handler
nmiRoutine:
    lda $dd0d
    jsr samplePlayerRoutine
    rti

; dummy placeholders
init_sid:
    rts

init_timer:
    rts

samplePlayerRoutine:
    rts

; pointer storage
samplePtr:
    !byte 0,0

; label where sample data goes
sampleData:
; do not put anything else here; the merging script appends data
