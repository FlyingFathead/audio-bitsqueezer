; --- ACME-compatible version of "player.asm"

        * = $0801      ; Start assembling at $0801

; --- BASIC stub to jump to code at $0810 or so
        !word $080c    ; Next line pointer
        !word 201      ; BASIC line number
        !byte $9e      ; SYS token
        !text "2064",0 ; "2064", i.e. SYS 2064, then a zero terminator
        !word 0        ; End of BASIC program

        * = $0810      ; Now place the following code at $0810

start:
        sei
        jsr init_sid       ; Initialize SID for 4-bit volume trick
        lda #<sampleData   ; Low byte of sampleData
        sta samplePtr
        lda #>sampleData   ; High byte of sampleData
        sta samplePtr+1
        jsr init_timer     ; Setup CIA#2 Timer => NMI at ~8kHz

        cli
mainLoop:
        rts               ; Could also do: jmp mainLoop if you want to idle

; ---------------------------
; NMI ROUTINE (CIA #2 Timer)
nmiRoutine:
        lda $dd0d          ; Acknowledge the interrupt immediately
        jsr samplePlayerRoutine  ; E.g. read nibble / poke $D418
        rti

; ---------------------------------------------------------
; If you have init_sid, init_timer, samplePlayerRoutine, define them too:

init_sid:
        rts

init_timer:
        rts

samplePlayerRoutine:
        rts

; ---------------------------------------------------------
; Storage for sample pointer, etc.
samplePtr:
        !byte 0,0

; ---------------------------------------------------------
; The sample data will be appended externally or left here
sampleData:

; ACME ends this file here
