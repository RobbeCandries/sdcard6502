; LCD interfacing, minor modifications to Ben Eater's code

lcd_wait:
  pha
  lda #%11110000  ; LCD data is input
  sta DDRB
.busy:
  lda #LCD_RW
  sta PORTB
  lda #(LCD_RW | LCD_E)
  sta PORTB
  lda PORTB       ; Read high nibble
  pha             ; and put on stack since it has the busy flag
  lda #LCD_RW
  sta PORTB
  lda #(LCD_RW | LCD_E)
  sta PORTB
  lda PORTB       ; Read low nibble
  pla             ; Get high nibble off stack
  and #%00001000
  bne .busy

  lda #LCD_RW
  sta PORTB
  lda #%11111111  ; LCD data is output
  sta DDRB
  pla
  rts

lcd_instruction:
  jsr lcd_wait
  pha
  lsr
  lsr
  lsr
  lsr            ; Send high 4 bits
  sta PORTB
  ora #LCD_E         ; Set E bit to send instruction
  sta PORTB
  eor #LCD_E         ; Clear E bit
  sta PORTB
  pla
  and #%00001111 ; Send low 4 bits
  sta PORTB
  ora #LCD_E         ; Set E bit to send instruction
  sta PORTB
  eor #LCD_E         ; Clear E bit
  sta PORTB
  rts


lcd_init:
  lda #%00000010 ; Set 4-bit mode
  jsr lcd_instruction
  lda #%00101000 ; Set 4-bit mode; 2-line display; 5x8 font
  jsr lcd_instruction
  lda #%00001110 ; Display on; cursor on; blink off
  jsr lcd_instruction
  lda #%00000110 ; Increment and shift cursor; don't shift display
  jsr lcd_instruction

lcd_cleardisplay:
  lda #%00000001 ; Clear display
  jmp lcd_instruction

lcd_setpos_startline0:
  lda #%10000000
  jmp lcd_instruction

lcd_setpos_startline1:
  lda #%11000000
  jmp lcd_instruction

lcd_setpos_xy:
  txa
  asl
  asl
  cpy #1  ; set carry if Y >= 1
  ror
  sec
  ror
  jmp lcd_instruction


print_char:
  jsr lcd_wait
  pha
  lsr
  lsr
  lsr
  lsr             ; Send high 4 bits
  ora #LCD_RS         ; Set RS
  sta PORTB
  ora #LCD_E          ; Set E bit to send instruction
  sta PORTB
  eor #LCD_E          ; Clear E bit
  sta PORTB
  pla
  and #%00001111  ; Send low 4 bits
  ora #LCD_RS         ; Set RS
  sta PORTB
  ora #LCD_E          ; Set E bit to send instruction
  sta PORTB
  eor #LCD_E          ; Clear E bit
  sta PORTB
  rts

print_hex:
  pha
  ror
  ror
  ror
  ror
  jsr print_nybble
  pla
  pha
  jsr print_nybble
  pla
  rts
print_nybble:
  and #15
  cmp #10
  bmi .skipletter
  adc #6
.skipletter
  adc #48
  jsr print_char
  rts

