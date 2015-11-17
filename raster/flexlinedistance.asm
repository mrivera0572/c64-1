; -- FLD (Flexable line distance) Example --
;
; Code: Jesder / 0xc64 / Hokuto Force
; Platform: C64
; Compiler: win2c64 (http://www.aartbik.com)
; About: Simple FLD effect to bounce a bitmap logo
;

                        ; common register definitions

REG_INTSERVICE_LOW      .equ $0314              ; interrupt service routine low byte
REG_INTSERVICE_HIGH     .equ $0315              ; interrupt service routine high byte
REG_SCREENCTL_1         .equ $d011              ; screen control register #1
REG_RASTERLINE          .equ $d012              ; raster line position 
REG_SCREENCTL_2         .equ $d016              ; screen control register #2
REG_MEMSETUP            .equ $d018              ; memory setup register
REG_INTFLAG             .equ $d019              ; interrupt flag register
REG_INTCONTROL          .equ $d01a              ; interrupt control register
REG_BORCOLOUR           .equ $d020              ; border colour register
REG_BGCOLOUR            .equ $d021              ; background colour register
REG_INTSTATUS_1         .equ $dc0d              ; interrupt control and status register #1
REG_INTSTATUS_2         .equ $dd0d              ; interrupt control and status register #2


                        ; constants

C_SCREEN_RAM            .equ $0400              ; screen RAM
C_COLOUR_RAM            .equ $d800              ; colour ram


                        ; program start

                        .org $0801              ; begin (2049)

                        .byte $0b, $08, $01, $00, $9e, $32, $30, $36
                        .byte $31, $00, $00, $00 ;= SYS 2061


                        ; create initial interrupt

                        sei                     ; set up interrupt
                        lda #$7f
                        sta REG_INTSTATUS_1     ; turn off the CIA interrupts
                        sta REG_INTSTATUS_2
                        and REG_SCREENCTL_1     ; clear high bit of raster line
                        sta REG_SCREENCTL_1

                        ldy #000
                        sty REG_RASTERLINE

                        lda #<sync_intro        ; load interrupt address
                        ldx #>sync_intro
                        sta REG_INTSERVICE_LOW
                        stx REG_INTSERVICE_HIGH

                        lda #$01                ; enable raster interrupts
                        sta REG_INTCONTROL
                        cli


                        ; forever loop

forever                 jmp forever


                        ; helper routines -------------------------------------------------------------------------------------------------]
                        ; -----------------------------------------------------------------------------------------------------------------]

apply_interrupt         sta REG_RASTERLINE              ; apply next interrupt
                        stx REG_INTSERVICE_LOW
                        sty REG_INTSERVICE_HIGH
                        jmp $ea81


                        ; intro sync ------------------------------------------------------------------------------------------------------]
                        ; -----------------------------------------------------------------------------------------------------------------]

sync_intro              inc REG_INTFLAG                 ; acknowledge interrupt

                        ldx #000                        ; relocate bitmap colour/screen data
setup_bitmap_data       lda bitmap_screen_data, x
                        sta $0428, x
                        lda bitmap_screen_data + $40, x
                        sta $0468, x

                        lda bitmap_colour_ram, x
                        sta $d828, x
                        lda bitmap_colour_ram + $40, x
                        sta $d868, x                        
                        inx
                        bne setup_bitmap_data
                        
                        lda #255                        ; init video garbage
                        sta $3fff                       ; fill to highlight fld for debugging

                        lda #001                        ; test characters 
                        sta $400                        ; used to verify character positions before / after fld
                        sta $770

                        jmp hook_init_frame_fld


                        ; init frame fld state --------------------------------------------------------------------------------------------]
                        ; -----------------------------------------------------------------------------------------------------------------]

hook_init_frame_fld     lda #015
                        ldx #<init_frame_fld
                        ldy #>init_frame_fld
                        jmp apply_interrupt


init_frame_fld          inc REG_INTFLAG

                        lda #$1b                        ; restore register to default
                        sta REG_SCREENCTL_1

                        jmp hook_bitmap_start


                        ; begin rendering bitmap ------------------------------------------------------------------------------------------]
                        ; -----------------------------------------------------------------------------------------------------------------]

hook_bitmap_start       lda #057
                        ldx #<render_bitmap_start
                        ldy #>render_bitmap_start
                        jmp apply_interrupt


render_bitmap_start     ldx #000                        ; apply fld effect to top of logo
                        beq bitmap_top_fld_done         ; no fld? then skip past this

wait_bitmap_top_fld     lda REG_RASTERLINE
                        cmp REG_RASTERLINE
                        beq wait_bitmap_top_fld + 3
                        lda REG_SCREENCTL_1
                        adc #001                        ; delay next bad scan line 
                        and #007
                        ora #$18
                        sta REG_SCREENCTL_1
                        dex
                        bne wait_bitmap_top_fld

bitmap_top_fld_done     ldx #012                        ; wait for raster to get into position for bitmap
                        dex
                        bne bitmap_top_fld_done + 2

                        inc REG_INTFLAG                 ; acknowledge interrupt
                
                        clc
                        lda REG_SCREENCTL_1             ; switch bitmap mode on
                        and #007
                        adc #056        
                        sta REG_SCREENCTL_1
                        lda #029                        ; set bitmap & screen memory pointer
                        sta REG_MEMSETUP
                        lda #216                        ; switch multi colour mode on
                        sta REG_SCREENCTL_2

                        jmp hook_bitmap_end


                        ; complete rendering bitmap ---------------------------------------------------------------------------------------]
                        ; -----------------------------------------------------------------------------------------------------------------]

hook_bitmap_end         lda #121
                        ldx #<render_bitmap_end
                        ldy #>render_bitmap_end
                        jmp apply_interrupt


render_bitmap_end       ldx #015
wait_bitmap_bot_fld     lda REG_RASTERLINE
                        cmp REG_RASTERLINE
                        beq wait_bitmap_bot_fld + 3
                        lda REG_SCREENCTL_1
                        adc #001
                        and #007
                        ora #056
                        sta REG_SCREENCTL_1
                        dex
                        bpl wait_bitmap_bot_fld 

                        ldx #008
latch_final_bitmap_line dex
                        bne latch_final_bitmap_line

                        inc REG_INTFLAG                 ; acknowledge interrupt

                        clc
                        lda REG_SCREENCTL_1             ; bitmap off
                        and #007                        ; maintain current vertical scroll bits
                        adc #024
                        sta REG_SCREENCTL_1
                        lda #021
                        sta REG_MEMSETUP
                        lda #200                        ; multi colour mode off
                        sta REG_SCREENCTL_2

                        jmp hook_update_logo_fld


                        ; update fld effect -----------------------------------------------------------------------------------------------]
                        ; -----------------------------------------------------------------------------------------------------------------]

hook_update_logo_fld    lda #250
                        ldx #<update_logo_fld
                        ldy #>update_logo_fld
                        jmp apply_interrupt


update_logo_fld         inc REG_INTFLAG

                        dec logo_bounce_delay                   ; smooth logo bounce effect
                        bne update_logo_fld_done
                        lda #002
                        sta logo_bounce_delay

                        ldx logo_bounce_index                   ; advance bounce height index
                        inx
                        txa
                        and #015                                ; loop bounce index to start
                        sta logo_bounce_index 

                        clc
                        tax
                        lda logo_bounce_heights, x              ; grab next height
                        tay
                        adc #121                                ; adjust bitmap ending interrupt
                        sta hook_bitmap_end + 1
                        sty render_bitmap_start + 1             ; set number of fld lines before the bitmap
                        clc
                        lda #016                                ; set number of fld lines after the bitmap
                        sbc render_bitmap_start + 1             
                        sta render_bitmap_end + 1

update_logo_fld_done    jmp hook_init_frame_fld


                        ; variables -----------------------------------------------------------------------------------------------------]
                        ; -----------------------------------------------------------------------------------------------------------------]

logo_bounce_heights     .byte 000, 000, 001, 001, 003, 005, 008, 013, 015, 012, 009, 006, 003, 001, 001, 000
logo_bounce_index       .byte 000
logo_bounce_delay       .byte 002


                        ; bitmap colour data ----------------------------------------------------------------------------------------------]
                        ; -----------------------------------------------------------------------------------------------------------------]

bitmap_screen_data      .byte $3e, $1a, $fa, $fa, $60, $e6, $6e, $6e, $e3, $23, $30, $6e, $3e, $30, $30, $3e
                        .byte $e6, $60, $60, $60, $00, $00, $00, $60, $60, $e6, $e0, $3e, $30, $00, $00, $60
                        .byte $63, $36, $3e, $30, $fa, $fa, $ca, $3e, $fa, $fa, $fa, $fa, $fa, $fa, $c6, $c6
                        .byte $16, $cf, $3c, $c3, $cf, $c3, $10, $c6, $e6, $b5, $b9, $b9, $19, $cb, $c0, $9c
                        .byte $9b, $cb, $9b, $c6, $5b, $9b, $f1, $00, $63, $60, $fa, $fa, $fa, $f7, $7f, $fa
                        .byte $f2, $f2, $92, $2c, $f2, $f2, $ca, $c6, $cf, $c4, $cf, $e3, $ce, $cf, $cf, $ce
                        .byte $e6, $5b, $98, $b5, $51, $cb, $c0, $9b, $9b, $9b, $9b, $e6, $65, $98, $fb, $9b
                        .byte $91, $a2, $af, $fa, $a2, $2a, $2a, $fa, $c2, $29, $92, $c9, $9a, $92, $ca, $ca
                        .byte $cf, $ca, $cf, $c6, $c6, $cf, $c6, $c6, $c6, $b8, $ba, $5b, $3e, $63, $c6, $89
                        .byte $8f, $fb, $00, $c6, $8d, $89, $fb, $9b, $9b, $a2, $a2, $29, $92, $a9, $a9, $2a
                        .byte $2a, $29, $b9, $b9, $9b, $2c, $c7, $37, $cf, $c7, $c7, $c6, $c4, $c4, $c4, $c4
                        .byte $c4, $b1, $d1, $5b, $00, $6e, $d3, $db, $db, $9b, $9c, $db, $d3, $d3, $d3, $d3
                        .byte $13, $db, $2a, $19, $13, $b9, $92, $12, $20, $92, $ac, $30, $c6, $c0, $73, $37
                        .byte $cf, $ec, $c3, $c7, $c3, $c7, $c4, $c4, $c5, $d3, $53, $50, $b1, $5b, $3b, $3d
                        .byte $5d, $1b, $31, $5b, $5b, $35, $5b, $53, $5c, $3b, $e3, $13, $92, $9a, $2a, $20
                        .byte $28, $20, $9a, $2b, $9b, $c3, $3e, $e3, $cf, $c3, $ce, $37, $3e, $37, $c7, $e3
                        .byte $b5, $53, $3e, $b5, $b3, $b5, $3b, $c5, $b3, $3b, $35, $db, $fe, $7f, $7f, $3b
                        .byte $f1, $60, $93, $29, $2a, $92, $92, $29, $28, $28, $28, $20, $92, $c2, $ce, $ce
                        .byte $cf, $ce, $cf, $f1, $f1, $ce, $c3, $cf, $5b, $5b, $5b, $b5, $b5, $5b, $cb, $5b
                        .byte $d5, $5b, $5b, $5b, $3e, $63, $c6, $5b, $5c, $29, $28, $28, $28, $28, $a2, $2a

bitmap_colour_ram       .byte $01, $03, $0e, $02, $00, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01
                        .byte $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
                        .byte $01, $01, $06, $01, $01, $00, $01, $01, $00, $07, $07, $07, $07, $06, $0a, $0f
                        .byte $0f, $06, $01, $01, $01, $01, $0f, $01, $00, $09, $08, $0f, $0b, $01, $01, $0f
                        .byte $0c, $01, $0c, $01, $00, $0c, $00, $01, $01, $01, $06, $07, $07, $0a, $0a, $0e
                        .byte $0a, $0a, $0a, $0a, $0a, $0a, $04, $04, $01, $06, $01, $01, $0f, $0e, $01, $0f
                        .byte $00, $09, $0b, $01, $09, $01, $01, $0f, $0f, $08, $08, $00, $0d, $00, $01, $0f
                        .byte $0f, $01, $02, $02, $09, $09, $0f, $02, $0a, $0a, $0a, $0a, $02, $0a, $01, $01
                        .byte $00, $01, $06, $01, $01, $06, $0f, $0f, $01, $01, $01, $00, $01, $00, $01, $0b
                        .byte $09, $01, $01, $01, $01, $01, $0c, $08, $08, $01, $09, $0a, $0a, $02, $02, $09
                        .byte $01, $0a, $01, $01, $06, $09, $01, $01, $01, $01, $03, $01, $03, $06, $06, $01
                        .byte $0b, $0d, $03, $01, $01, $00, $01, $01, $01, $08, $08, $00, $01, $01, $01, $01
                        .byte $0d, $01, $09, $03, $09, $01, $0a, $0a, $01, $0a, $09, $01, $01, $01, $0e, $0e
                        .byte $01, $03, $0e, $01, $01, $01, $01, $01, $0b, $05, $0d, $01, $0d, $00, $0d, $05
                        .byte $03, $03, $05, $0d, $03, $0b, $03, $0d, $03, $0c, $00, $06, $0a, $00, $09, $01
                        .byte $01, $01, $02, $09, $00, $01, $01, $00, $01, $0e, $03, $0f, $01, $0c, $01, $01
                        .byte $0c, $00, $05, $00, $05, $0d, $05, $01, $05, $05, $00, $05, $01, $01, $01, $05
                        .byte $05, $01, $0e, $06, $09, $0a, $00, $08, $0a, $0a, $01, $01, $00, $09, $01, $0f
                        .byte $01, $0f, $00, $0e, $0e, $07, $0e, $0e, $0c, $00, $00, $01, $00, $00, $05, $00
                        .byte $0b, $0d, $00, $00, $01, $01, $01, $00, $0f, $01, $09, $0a, $01, $01, $08, $08

bitmap_padding_to_2000  .align 1024
                        nop
                        .align 1024
                        nop
                        .align 1024
                        nop
                        .align 1024
                        nop
                        .align 1024
                        nop
                        .align 1024


                        ; bitmap image ----------------------------------------------------------------------------------------------------]
                        ; -----------------------------------------------------------------------------------------------------------------]
;$2000
bitmap_memory_start     .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

;$2140
bitmap_data             .byte $00, $00, $00, $04, $0c, $7f, $0c, $04, $40, $00, $30, $00, $00, $c0, $00, $02
                        .byte $c0, $00, $00, $00, $00, $00, $aa, $95, $00, $00, $00, $00, $00, $00, $a8, $5a
                        .byte $00, $00, $00, $01, $00, $00, $00, $00, $00, $08, $00, $00, $04, $00, $00, $00
                        .byte $00, $04, $00, $81, $10, $00, $00, $00, $00, $08, $00, $00, $00, $10, $00, $00
                        .byte $00, $04, $10, $00, $40, $04, $00, $00, $00, $00, $02, $00, $20, $00, $00, $00
                        .byte $00, $0c, $00, $00, $00, $00, $01, $00, $08, $00, $00, $00, $0c, $00, $00, $10
                        .byte $c3, $00, $00, $21, $00, $00, $00, $00, $00, $10, $30, $fd, $30, $10, $00, $00
                        .byte $00, $00, $01, $00, $00, $0c, $00, $00, $00, $00, $08, $00, $10, $00, $00, $00
                        .byte $00, $04, $00, $00, $42, $00, $00, $00, $00, $00, $01, $00, $00, $10, $00, $00
                        .byte $00, $00, $00, $10, $00, $00, $00, $00, $00, $40, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $01, $00, $00, $00
                        .byte $00, $00, $10, $00, $01, $00, $00, $00, $40, $00, $81, $00, $00, $00, $00, $00
                        .byte $04, $00, $00, $00, $00, $04, $00, $00, $00, $00, $01, $03, $1f, $03, $01, $80
                        .byte $00, $00, $0c, $00, $d0, $00, $00, $00, $0c, $00, $00, $c0, $00, $00, $00, $00
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $10, $00, $00, $00, $00, $00
                        .byte $00, $00, $01, $00, $40, $02, $03, $2f, $00, $04, $00, $00, $08, $00, $00, $d0
                        .byte $80, $00, $04, $00, $00, $03, $00, $c0, $04, $00, $00, $00, $30, $00, $00, $00
                        .byte $00, $00, $30, $00, $00, $00, $2a, $a5, $00, $00, $00, $00, $00, $00, $aa, $56
                        .byte $00, $00, $00, $0c, $00, $00, $00, $80, $0c, $00, $04, $00, $80, $00, $02, $00
                        .byte $00, $00, $00, $00, $02, $0a, $09, $29, $0a, $29, $a7, $9f, $7d, $75, $56, $59
                        .byte $7f, $ff, $dd, $55, $56, $69, $9a, $aa, $f5, $fd, $df, $57, $65, $99, $aa, $aa
                        .byte $80, $60, $58, $d6, $d5, $75, $5d, $95, $03, $00, $00, $00, $00, $80, $60, $60
                        .byte $02, $09, $06, $06, $06, $06, $06, $06, $57, $aa, $aa, $a0, $aa, $aa, $80, $aa
                        .byte $f5, $80, $a8, $00, $0f, $30, $30, $30, $a7, $01, $00, $00, $00, $40, $70, $7c
                        .byte $00, $00, $81, $80, $80, $80, $80, $87, $00, $00, $00, $00, $00, $80, $c0, $f8
                        .byte $55, $40, $48, $80, $40, $80, $8b, $c0, $55, $01, $01, $01, $81, $c1, $f9, $c1
                        .byte $0f, $0c, $0c, $0c, $0c, $04, $0c, $04, $54, $04, $84, $24, $84, $24, $04, $04
                        .byte $00, $21, $00, $00, $04, $00, $00, $00, $00, $01, $04, $04, $04, $07, $0b, $07
                        .byte $55, $00, $08, $20, $82, $8a, $2b, $af, $ff, $00, $2a, $2a, $15, $10, $10, $10
                        .byte $54, $09, $02, $a0, $c0, $c8, $e8, $e8, $00, $00, $c0, $c0, $40, $40, $40, $40
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $0a, $24, $90, $90, $80, $c0, $80, $c1
                        .byte $ba, $00, $00, $00, $02, $12, $12, $02, $5f, $00, $00, $00, $a8, $08, $08, $08
                        .byte $c0, $30, $0c, $0c, $0c, $4c, $48, $0c, $00, $00, $00, $0c, $00, $00, $00, $08
                        .byte $0a, $08, $08, $08, $08, $08, $04, $08, $ef, $00, $00, $00, $40, $40, $04, $00
                        .byte $50, $10, $10, $20, $10, $20, $20, $20, $00, $00, $00, $00, $00, $00, $00, $00
                        .byte $03, $02, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $10, $00, $00, $00
                        .byte $00, $00, $00, $c0, $00, $02, $09, $09, $02, $09, $25, $97, $57, $5d, $75, $56
                        .byte $5f, $7f, $f7, $d5, $59, $66, $aa, $aa, $a9, $aa, $66, $55, $d5, $7d, $f7, $ff
                        .byte $f0, $bc, $6f, $5b, $96, $a6, $ea, $ba, $00, $03, $00, $00, $80, $a0, $60, $68
                        .byte $35, $35, $f5, $d7, $df, $7f, $de, $7f, $7f, $7f, $fe, $fb, $ee, $ba, $ea, $aa
                        .byte $ee, $bb, $ea, $aa, $aa, $aa, $9b, $6e, $dd, $77, $55, $55, $55, $55, $75, $dd
                        .byte $f5, $bd, $ef, $bb, $ae, $ab, $aa, $ea, $5c, $5c, $d7, $f5, $fd, $bf, $ef, $bb
                        .byte $07, $07, $07, $07, $87, $87, $87, $85, $aa, $aa, $aa, $fe, $aa, $fe, $ff, $7f
                        .byte $30, $30, $20, $20, $10, $20, $10, $20, $6c, $6c, $7c, $7c, $68, $68, $68, $68
                        .byte $80, $80, $c0, $80, $c0, $c0, $80, $c0, $c0, $80, $00, $10, $00, $40, $00, $04
                        .byte $c0, $c0, $c0, $43, $c0, $48, $40, $40, $81, $02, $01, $32, $02, $32, $02, $02
                        .byte $0c, $0c, $0c, $08, $0c, $08, $08, $08, $cc, $04, $8c, $0c, $0c, $8c, $0c, $0c
                        .byte $00, $08, $00, $00, $10, $00, $00, $00, $07, $07, $07, $07, $07, $07, $0b, $07
                        .byte $6a, $a6, $96, $5a, $6a, $ab, $af, $bf, $10, $20, $20, $20, $30, $30, $20, $20
                        .byte $7c, $7c, $70, $70, $4c, $bc, $bc, $a5, $80, $80, $40, $80, $80, $83, $80, $80
                        .byte $00, $00, $30, $00, $00, $00, $00, $00, $c1, $c0, $c4, $c5, $c1, $d0, $94, $d5
                        .byte $42, $52, $12, $12, $52, $52, $13, $12, $09, $09, $08, $09, $09, $0b, $0b, $0a
                        .byte $48, $48, $48, $48, $48, $48, $c8, $a8, $00, $80, $00, $08, $00, $00, $00, $04
                        .byte $08, $48, $08, $08, $0c, $08, $0c, $0c, $10, $11, $00, $14, $54, $40, $55, $55
                        .byte $30, $30, $30, $30, $30, $10, $30, $10, $ab, $80, $80, $80, $81, $90, $85, $95
                        .byte $fa, $02, $42, $03, $43, $03, $43, $03, $00, $00, $00, $00, $02, $02, $09, $05
                        .byte $1a, $da, $e9, $e5, $55, $57, $5d, $77, $5a, $6b, $ae, $bb, $ef, $bf, $ff, $fe
                        .byte $99, $66, $aa, $aa, $aa, $aa, $a6, $99, $66, $99, $56, $55, $55, $55, $9d, $67
                        .byte $ab, $ab, $6a, $9a, $66, $59, $56, $55, $58, $58, $5a, $96, $a6, $a9, $e6, $a9
                        .byte $fa, $fe, $fa, $ee, $fa, $ea, $aa, $ea, $5a, $65, $5b, $69, $97, $6f, $67, $af
                        .byte $bf, $ff, $ff, $ff, $f9, $e5, $d4, $91, $ff, $ff, $ff, $ff, $aa, $aa, $88, $00
                        .byte $ef, $bb, $ae, $ab, $ea, $5e, $55, $15, $ae, $ab, $aa, $ea, $fa, $fe, $bf, $6c
                        .byte $85, $85, $86, $87, $87, $87, $07, $07, $55, $55, $95, $e5, $f9, $fe, $ff, $ff
                        .byte $10, $10, $10, $10, $10, $10, $20, $10, $54, $54, $54, $54, $54, $68, $7c, $7c
                        .byte $80, $80, $80, $40, $80, $4c, $40, $43, $00, $00, $30, $00, $00, $00, $08, $00
                        .byte $68, $68, $60, $6a, $68, $6a, $6a, $55, $c1, $02, $01, $f1, $01, $f1, $f1, $71
                        .byte $0e, $06, $0c, $04, $06, $06, $06, $54, $0c, $0c, $84, $8c, $84, $84, $04, $54
                        .byte $02, $00, $00, $00, $00, $00, $00, $00, $06, $05, $05, $05, $06, $07, $07, $07
                        .byte $56, $5b, $6f, $bf, $ff, $ff, $ff, $ff, $10, $20, $10, $20, $20, $20, $20, $20
                        .byte $00, $00, $00, $00, $00, $10, $00, $08, $01, $06, $01, $80, $00, $00, $01, $00
                        .byte $00, $80, $00, $00, $08, $00, $00, $00, $e9, $da, $d6, $d5, $f6, $f5, $fd, $ff
                        .byte $f2, $72, $d2, $d2, $52, $d2, $f2, $72, $00, $00, $00, $00, $00, $00, $00, $7d
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $80, $00, $00, $00, $00, $00
                        .byte $09, $09, $0d, $0d, $09, $09, $09, $09, $5a, $5a, $69, $65, $55, $5b, $6f, $bf
                        .byte $10, $30, $10, $30, $30, $30, $30, $3f, $95, $9f, $bf, $b7, $95, $95, $bf, $bf
                        .byte $52, $52, $72, $d2, $d2, $f2, $f2, $f2, $25, $16, $1a, $2a, $2a, $2a, $02, $00
                        .byte $9a, $aa, $aa, $a9, $a5, $95, $56, $5b, $5d, $77, $df, $7f, $fd, $da, $aa, $a8
                        .byte $ff, $ff, $ff, $ff, $55, $55, $11, $00, $57, $55, $55, $55, $b5, $ad, $29, $8b
                        .byte $af, $fb, $6f, $eb, $7e, $5b, $7b, $5a, $5a, $6a, $5a, $66, $5a, $56, $55, $56
                        .byte $45, $95, $45, $45, $41, $45, $41, $41, $5f, $bd, $5d, $bd, $be, $be, $7e, $7e
                        .byte $88, $a0, $80, $00, $80, $02, $00, $02, $02, $0a, $88, $00, $80, $80, $80, $00
                        .byte $55, $00, $00, $00, $00, $00, $03, $00, $f4, $30, $00, $02, $02, $02, $02, $02
                        .byte $17, $5f, $7f, $7a, $fe, $fa, $ee, $aa, $bb, $ff, $ae, $ab, $6e, $aa, $6e, $9a
                        .byte $20, $10, $20, $20, $20, $30, $20, $30, $78, $6c, $78, $6e, $7b, $6e, $6a, $6a
                        .byte $40, $40, $10, $04, $84, $a1, $a1, $b1, $00, $20, $00, $00, $00, $02, $09, $27
                        .byte $00, $00, $00, $25, $9a, $6a, $5a, $d5, $6f, $6f, $6f, $ad, $a1, $ad, $a1, $a1
                        .byte $fc, $fc, $fc, $54, $04, $06, $06, $06, $40, $40, $60, $58, $06, $81, $a0, $a8
                        .byte $00, $00, $00, $03, $03, $83, $43, $63, $1e, $7a, $6a, $ef, $eb, $af, $bb, $ff
                        .byte $66, $aa, $59, $56, $d9, $55, $d9, $75, $10, $20, $10, $10, $10, $30, $10, $30
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $20, $00, $10, $00, $00, $00, $00
                        .byte $00, $00, $02, $0b, $09, $27, $2d, $27, $aa, $fe, $7f, $df, $5d, $7f, $5d, $55
                        .byte $a0, $a0, $a2, $e2, $f2, $72, $51, $72, $00, $54, $f5, $bd, $2f, $0b, $0b, $0b
                        .byte $a0, $08, $42, $50, $54, $f5, $ff, $ff, $00, $00, $00, $80, $80, $22, $22, $22
                        .byte $09, $09, $2d, $bf, $bb, $fd, $fa, $ee, $7f, $ff, $ff, $fd, $d5, $59, $69, $9a
                        .byte $ff, $ff, $f5, $55, $96, $65, $99, $66, $ff, $ff, $57, $55, $59, $66, $59, $66
                        .byte $50, $54, $55, $fd, $fb, $ef, $fb, $ee, $a8, $08, $c8, $c8, $c8, $48, $48, $48
                        .byte $5f, $7c, $f0, $c0, $00, $00, $00, $00, $aa, $00, $00, $00, $00, $03, $01, $35
                        .byte $c0, $f0, $33, $00, $03, $03, $03, $60, $22, $0a, $02, $00, $02, $80, $00, $80
                        .byte $fa, $bd, $ba, $bd, $7d, $7d, $7e, $7e, $a2, $ab, $a2, $a2, $82, $a2, $82, $82
                        .byte $41, $41, $40, $41, $40, $40, $50, $40, $bd, $9d, $be, $9e, $9e, $af, $a7, $ab
                        .byte $c3, $03, $c3, $f3, $cf, $f3, $cf, $73, $00, $00, $00, $00, $01, $00, $00, $00
                        .byte $20, $00, $00, $30, $00, $00, $00, $00, $01, $01, $01, $01, $01, $01, $01, $01
                        .byte $55, $9b, $6e, $9b, $6e, $9b, $ae, $af, $6a, $76, $d9, $76, $d9, $f6, $f9, $f6
                        .byte $30, $30, $30, $20, $30, $20, $20, $20, $bf, $bd, $b7, $bd, $b7, $bd, $b7, $b5
                        .byte $a1, $b1, $e1, $b1, $e1, $f1, $f1, $f1, $17, $1f, $1f, $1b, $1f, $1b, $1e, $1b
                        .byte $e5, $fa, $ff, $ff, $bb, $ee, $bb, $ee, $51, $51, $a1, $f1, $f2, $e1, $b2, $e2
                        .byte $06, $05, $05, $06, $06, $07, $07, $07, $a8, $6a, $5a, $56, $95, $a5, $e9, $fa
                        .byte $13, $13, $31, $13, $31, $11, $31, $31, $55, $9b, $6e, $9b, $6e, $9b, $ae, $af
                        .byte $bf, $9b, $6e, $9b, $6e, $5b, $5e, $5b, $30, $30, $30, $10, $30, $10, $10, $10
                        .byte $00, $55, $68, $68, $68, $78, $6c, $7c, $00, $80, $80, $80, $80, $40, $80, $40
                        .byte $1f, $17, $1d, $27, $1d, $27, $25, $25, $a6, $77, $dd, $77, $dd, $7f, $df, $ff
                        .byte $a2, $e2, $b2, $e1, $b2, $e1, $b1, $e1, $09, $09, $0b, $09, $0b, $09, $0b, $0b
                        .byte $95, $a9, $ea, $7a, $de, $77, $dd, $f7, $12, $21, $12, $11, $11, $31, $10, $30
                        .byte $ff, $ff, $dd, $f7, $dd, $f7, $55, $2a, $55, $99, $65, $99, $65, $a9, $6a, $ff
                        .byte $ff, $ff, $df, $77, $dd, $55, $55, $aa, $bb, $ae, $ab, $6a, $a6, $65, $66, $65
                        .byte $ff, $df, $f7, $dd, $f5, $d5, $d0, $d2, $4c, $48, $4c, $4c, $4c, $4c, $0c, $fc
                        .byte $00, $00, $00, $00, $08, $00, $00, $04, $01, $42, $00, $00, $03, $00, $00, $80
                        .byte $00, $00, $00, $00, $00, $00, $00, $00, $41, $40, $41, $45, $51, $45, $51, $46
                        .byte $e9, $ed, $69, $6d, $6d, $a5, $b5, $95, $41, $41, $01, $41, $01, $01, $05, $01
                        .byte $50, $50, $94, $50, $94, $95, $a4, $65, $15, $05, $15, $01, $04, $01, $40, $10
                        .byte $95, $d5, $75, $dd, $f5, $3d, $cf, $33, $c0, $00, $f0, $c0, $fc, $f3, $fc, $5f
                        .byte $00, $00, $00, $00, $00, $00, $44, $51, $01, $81, $01, $01, $01, $01, $01, $01
                        .byte $9a, $62, $98, $62, $a8, $a0, $80, $20, $5a, $1a, $46, $19, $05, $01, $04, $01
                        .byte $10, $20, $10, $20, $10, $10, $10, $10, $6f, $73, $6c, $73, $7c, $70, $40, $70
                        .byte $a1, $21, $81, $21, $81, $21, $81, $01, $3a, $3a, $36, $39, $36, $39, $35, $35
                        .byte $55, $66, $99, $66, $9a, $a1, $48, $22, $a2, $a2, $a2, $a2, $62, $92, $62, $93
                        .byte $07, $07, $06, $07, $06, $06, $06, $06, $fd, $ef, $bb, $ef, $a6, $96, $46, $52
                        .byte $13, $13, $13, $13, $11, $13, $11, $11, $65, $91, $64, $91, $54, $50, $40, $10
                        .byte $f5, $35, $cd, $37, $0f, $03, $0c, $03, $10, $20, $10, $20, $10, $10, $10, $10
                        .byte $68, $78, $6c, $7b, $7c, $73, $4c, $73, $80, $c0, $30, $0c, $8c, $03, $82, $02
                        .byte $2d, $27, $2d, $27, $2f, $2f, $2c, $23, $aa, $22, $88, $22, $80, $00, $00, $00
                        .byte $a1, $a1, $e1, $b1, $f3, $31, $c3, $33, $09, $0b, $09, $0b, $0b, $0b, $08, $0b
                        .byte $a6, $2a, $88, $22, $88, $22, $08, $00, $10, $10, $30, $10, $30, $30, $20, $30
                        .byte $00, $00, $00, $00, $03, $80, $00, $00, $00, $8a, $44, $c3, $cf, $00, $00, $00
                        .byte $00, $20, $10, $30, $3c, $00, $00, $00, $9f, $b3, $9c, $b3, $bc, $b3, $80, $b0
                        .byte $f1, $f1, $c1, $32, $c2, $32, $c1, $01, $00, $00, $00, $00, $04, $00, $00, $00
                        .byte $00, $00, $30, $00, $00, $00, $00, $05, $00, $00, $0c, $00, $00, $00, $22, $8a
                        .byte $03, $00, $0f, $03, $3f, $cf, $3f, $f5, $57, $56, $59, $66, $5a, $68, $a2, $88
                        .byte $a8, $a0, $a8, $80, $20, $80, $02, $08, $05, $05, $17, $05, $17, $57, $1f, $5d
                        .byte $65, $29, $1a, $1a, $0e, $0e, $0f, $03, $44, $51, $64, $99, $a5, $e9, $ba, $ee
                        .byte $05, $00, $40, $14, $51, $54, $65, $99, $55, $45, $04, $00, $00, $50, $44, $51
                        .byte $95, $a9, $8a, $22, $00, $00, $80, $22, $f1, $b1, $a1, $21, $81, $01, $00, $20
                        .byte $00, $80, $20, $80, $20, $00, $40, $15, $08, $02, $08, $00, $02, $00, $00, $df
                        .byte $10, $10, $10, $05, $00, $00, $00, $ef, $40, $40, $60, $00, $20, $00, $00, $fd
                        .byte $01, $01, $01, $01, $01, $01, $04, $90, $2f, $1c, $23, $2c, $23, $20, $20, $2a
                        .byte $cc, $c0, $00, $c0, $00, $00, $00, $65, $a3, $a1, $21, $81, $21, $01, $01, $55
                        .byte $07, $07, $04, $07, $04, $04, $04, $05, $cf, $03, $cc, $03, $cc, $00, $00, $9a
                        .byte $32, $22, $32, $32, $32, $32, $30, $f0, $00, $40, $10, $40, $10, $00, $80, $2a
                        .byte $04, $01, $04, $00, $01, $00, $00, $65, $10, $10, $10, $15, $00, $00, $00, $fe
                        .byte $40, $42, $60, $40, $20, $00, $00, $99, $42, $01, $42, $02, $02, $02, $08, $a0
                        .byte $20, $2c, $23, $2c, $23, $20, $08, $02, $00, $00, $00, $00, $00, $00, $00, $99
                        .byte $81, $21, $82, $02, $20, $00, $00, $65, $08, $08, $11, $40, $01, $00, $00, $d6
                        .byte $04, $00, $00, $00, $00, $00, $00, $6a, $20, $20, $20, $20, $20, $20, $80, $00
                        .byte $0c, $00, $00, $00, $01, $80, $00, $00, $00, $00, $20, $01, $00, $00, $20, $30
                        .byte $00, $20, $00, $00, $00, $00, $20, $00, $80, $80, $90, $80, $90, $80, $80, $aa
                        .byte $43, $03, $02, $03, $02, $02, $08, $a0, $00, $06, $11, $04, $11, $04, $00, $00
                        .byte $ff, $5d, $d5, $54, $11, $00, $00, $04, $55, $55, $51, $44, $00, $00, $01, $44
                        .byte $55, $51, $10, $00, $00, $05, $11, $45, $50, $00, $01, $14, $45, $15, $59, $66
                        .byte $22, $8a, $2e, $bb, $af, $bd, $f7, $dd, $5d, $7c, $f4, $f4, $d0, $d0, $90, $80
 
