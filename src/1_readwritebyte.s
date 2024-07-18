PORTB = $6000
PORTA = $6001
DDRB = $6002
DDRA = $6003
SR = $600A
ACR = $600B

E  = %10000000
RW = %01000000
RS = %00100000

SD_CS   = %10000000
SD_SCK  = %00001000
SD_MOSI = %00000100
SD_MISO = %00000010

PORTA_OUTPUTPINS = E | RW | RS | SD_CS | SD_SCK | SD_MOSI


  .org $e000

reset:
  ldx #$ff
  txs

  lda #%11111111          ; Set all pins on port B to output
  sta DDRB
  lda #%00000000          ; Set all pins on port A to input
  sta DDRA

  jsr lcd_init


  ; Let the SD card boot up, by pumping the clock with SD CS disabled

  lda #'I'
  jsr print_char

  ; We need to apply around 80 clock pulses with CS and MOSI high.
  ; Normally MOSI doesn't matter when CS is high, but the card is
  ; not yet is SPI mode, and in this non-SPI state it does care.

  lda #SD_CS | SD_MOSI
  ldx #160               ; toggle the clock 160 times, so 80 low-high transitions
.preinitloop:
  eor #SD_SCK
  sta PORTA
  dex
  bne .preinitloop
  
  ; Read a byte from the card, expecting $ff as no commands have been sent
  jsr sd_readbyte
  jsr print_hex

.cmd0
  ; GO_IDLE_STATE - resets card to idle state
  ; This also puts the card in SPI mode.
  ; Unlike most commands, the CRC is checked.

  lda #'c'
  jsr print_char
  lda #$00
  jsr print_hex

  lda #SD_MOSI           ; pull CS low to begin command
  sta PORTA

  ; CMD0, data 00000000, crc 95
  lda #$40
  jsr sd_writebyte
  lda #$00
  jsr sd_writebyte
  lda #$00
  jsr sd_writebyte
  lda #$00
  jsr sd_writebyte
  lda #$00
  jsr sd_writebyte
  lda #$95
  jsr sd_writebyte

  ; Read response and print it - should be $01 (not initialized)
  jsr sd_waitresult
  pha
  jsr print_hex

  lda #SD_CS | SD_MOSI   ; set CS high again
  sta PORTA

  ; Expect status response $01 (not initialized)
  pla
  cmp #$01
  bne .initfailed


  lda #'Y'
  jsr print_char

  ; loop forever
.loop:
  jmp .loop


.initfailed
  lda #'X'
  jsr print_char
  jmp .loop



sd_readbyte:
  ; Enable the card and tick the clock 8 times with MOSI high, 
  ; capturing bits from MISO and returning them

  lda PORTB                   ; Get current state of PORTB
  and #(!SD_CS)               ; Clear SD_CS bit, keep all other bits the same
  sta PORTB

  lda #$ff                    ; Pull byte to send back off stack
  sta SR                      ; Shift out byte using 6522 SR

  nop                         ; Wait for bits to be shifted out
  nop
  nop
  nop
  nop
  nop

  lda PORTB                   ; Get current state of PORTB
  ora #SD_CS                  ; Set SD_CS bit, keep all other bits the same
  sta PORTB

  lda PORTA                   ; Read recieved bytes from the 74hc595 SR

  rts


sd_writebyte:
  ; Shift out byte using the 6522's shift register
  ; SD communication is mostly half-duplex so we ignore anything it sends back here

  pha                         ; Push byte to send to stack

  lda PORTB                   ; Get current state of PORTB
  and #(!SD_CS)               ; Clear SD_CS bit, keep all other bits the same
  sta PORTB

  pla                         ; Pull byte to send back off stack
  sta SR                      ; Shift out byte using 6522 SR

  nop                         ; Wait for bits to be shifted out
  nop
  nop
  nop
  nop
  nop

  lda PORTB                   ; Get current state of PORTB
  ora #SD_CS                  ; Set SD_CS bit, keep all other bits the same
  sta PORTB

  rts


sd_waitresult:
  ; Wait for the SD card to return something other than $ff
  jsr sd_readbyte
  cmp #$ff
  beq sd_waitresult
  rts


lcd_wait:
  pha
  lda #%11110000              ; LCD data is input
  sta DDRB

lcdbusy:
  lda PORTB
  ora #SD_CS | #RW            ; Set SD_CS and RW
  sta PORTB

  ora #E                      ; Set E bit while keeping MSB set
  sta PORTB

  lda PORTB                   ; Read high nibble
  pha                         ; and put on stack since it has the busy flag

  lda PORTB
  ora #SD_CS | #RW            ; Set SD_CS and RW
  sta PORTB

  ora #E                      ; Set E bit while keeping MSB set
  sta PORTB

  lda PORTB                   ; Read low nibble
  pla                         ; Get high nibble off stack
  and #%00001000
  bne lcdbusy

  lda PORTB
  ora #SD_CS | #RW            ; Set SD_CS and RW
  sta PORTB

  lda #%11111111              ; LCD data is output
  sta DDRB
  pla
  rts

lcd_instruction:
  jsr lcd_wait
  pha
  lsr
  lsr
  lsr
  lsr                         ; Send high 4 bits
  ora #SD_CS                  ; Ensure SD_CS is set
  sta PORTB
  ora #E | #SD_CS             ; Set E bit to send instruction
  sta PORTB
  eor #E                      ; Clear E bit
  ora #SD_CS                  ; Ensure SD_CS is set
  sta PORTB
  pla
  and #%00001111              ; Send low 4 bits
  ora #SD_CS                  ; Ensure SD_CS is set
  sta PORTB
  ora #E                      ; Set E bit to send instruction
  sta PORTB
  eor #E                      ; Clear E bit
  ora #SD_CS                  ; Ensure SD_CS is set
  sta PORTB
  rts



lcd_init:
  lda #%00111000 ; Set 8-bit mode; 2-line display; 5x8 font
  jsr lcd_instruction
  lda #%00001110 ; Display on; cursor on; blink off
  jsr lcd_instruction
  lda #%00000110 ; Increment and shift cursor; don't shift display
  jsr lcd_instruction

lcd_cleardisplay:
  lda #%00000001 ; Clear display
  jmp lcd_instruction


print_char:
  jsr lcd_wait
  pha
  lsr
  lsr
  lsr
  lsr                         ; Send high 4 bits
  ora #RS | #SD_CS            ; Set RS and SD_CS (assuming RS is defined as an appropriate constant)
  ora #SD_CS                  ; Ensure SD_CS is set
  sta PORTB
  ora #E                      ; Set E bit to send instruction
  sta PORTB
  and #SD_CS                  ; Clear E bit, keep SD_CS set
  sta PORTB
  pla
  and #%00001111              ; Send low 4 bits
  ora #RS | #SD_CS            ; Set RS and SD_CS
  sta PORTB
  ora #E                      ; Set E bit to send instruction
  sta PORTB
  and #SD_CS                  ; Clear E bit, keep MSB set
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
print_nybble:
  and #15
  cmp #10
  bmi .skipletter
  adc #6
.skipletter
  adc #48
  jsr print_char
  rts

  .org $fffc
  .word reset
  .word $0000
