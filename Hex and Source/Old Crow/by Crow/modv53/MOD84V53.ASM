;
;       PIC16C84 version of the "v5.2" serial data chip emulation.
;       Written by the Old Crow (Scott Rider) on 06-JUN-97
;
;       Revision History:
;
;       P1.01v5 on 28-JAN-97    ;Uses v5.0 chip data
;       P1.05   on 22-FEB-97    ;Uses ASCII version of v5.0 data
;       P1.051  on 14-APR-97    ;Fixed tiny timing error
;       P1.052  on 06-JUN-97    ;This version uses 4.45MHz clock
;       P1.053  on 08-JUN-97    ;Alternating 4MHz/4.45MHz ref.
;
;       This version uses Microchip assembler mnemonics and the
;       Microchip MPASM assembler.  Default config options are set
;       on the __FUSES line below: PWRTE on, CP off, WDT off, OSC=XT
;
;       Chip is connected in 6-wire fashion:
;
;                       _______  _______
;                      |       \/       |
;                RA2 --+ 1           18 +-- RA1
;                      |                |
;                RA3 --+ 2           17 +-- RA0
;                      |                |
;               RTCC --+ 3         >>16 +-- OSC1/CLKIN
;                      |                |
;              !MCLR --+ 4 <<        15 +-- OSC2/CLKOUT
;                      |                |
;                Vss --+ 5 <<      >>14 +-- Vdd
;                      |                |
;                RB0 --+ 6           13 +-- RB7
;                      |                |
;                RB1 --+ 7 <<        12 +-- RB6
;                      |                |
;                RB2 --+ 8 <<        11 +-- RB5
;                      |                |
;                RB3 --+ 9           10 +-- RB4
;                      |                |
;                      +----------------+
;
;       ">>" and "<<" indicate connected pins.  Refer to PC board diagrams
; available on the internet for further details.
;
	list    p=16c84
	radix   dec
	include "p16c84.inc"
;
	__FUSES _CP_OFF & _WDT_OFF & _XT_OSC & _PWRTE_ON

	cblock  0x0C    ;Store variables above control registers 

		i       ;Loop counters
		j
		k       ;/
		x       ;Used by delay routine
		y       ;/
		xmit    ;Transmit data holding register
		index   ;Index register for table lookups
		mode    ;Cheap counter used to toggle delay mode
	endc

	org     0x00            ;Start of code space 
	goto    start
;
;  Support routines
;
;  dly50  -- entry for 50ms delay
;  dly_ms -- entry with ms in w (1 to 255), based on 4.00MHz clock
;
dly50   movlw   50              ;Enter here for a 50ms delay
dly_ms  movwf   x               ;/

dy_0    movlw   249             ;1ms loop count @4.00Mhz
	movwf   y               ;/

dy_1    nop

	decfsz  y,F
	goto    dy_1
	
	decfsz  x,F             ;# of loops
	goto    dy_0

	btfss   mode,0          ;Which delay mode, 1000 or 1113?
	retlw   3               ;w=3 default for sendln
;
;  Waste another 112 cycles for the 4.45MHz case.
;
	movlw   36
	movwf   y

dy_2    decfsz  y,F             ;Waste 'em
	goto    dy_2

	retlw   3               ;w=3 default for sendln
;
;  sendln -- send 4-byte line(s) with a 72ms marker at head of line.
;  Enter with number of lines in w.
;
sendln  movwf   i               ;Do this many lines

sl_0    movlw   72              ;Delay 72ms
	call    dly_ms

	movlw   4               ;Do 4-byte line
	movwf   j               ;/

sl_1    movf    index,W         ;Restore index
	call    lines           ;Get a data byte..
	movwf   xmit            ;..into xmit buffer
	comf    xmit,F          ;Invert for sending
;        
;       Send a byte on rb.1.  LSB first, 4ms/bit (250 bps) with one
;  start bit and two stop bits per byte.  Instead of setting and 
;  clearing the port bit, the port's direction is changed.  The actual 
;  port register is set to zero, so that when the port bit is directed 
;  to be an output, it automatically goes low.  Directing the port bit 
;  to be an input floats the I/O pin, and the external pullup creates
;  the high.  This allows open-collector operation of the port bits.
;
	movlw   8               ;8 bits to send
	movwf   k               ;/

	movlw   b'11111011'     ;Start bit on pin 7=1
	bsf     STATUS,RP0
	movwf   TRISB           ;Set pin 7 high via port directon control
	bcf     STATUS,RP0

	movlw   4               ;4ms bit-time
	call    dly_ms

sl_2    rrf     xmit,F          ;Get a bit..

	movlw   b'11111001'     ;Keep port bits low when outputs
	movwf   PORTB           ;/

	btfsc   STATUS,C        ;High or low?
	movlw   b'11111011'     ;Set pin 7 high via port direction control
	btfss   STATUS,C        ;High or low?
	movlw   b'11111001'     ;Set pin 7 low via port direction control

	bsf     STATUS,RP0      ;TRISB in upper data page
	movwf   TRISB
	bcf     STATUS,RP0      ;Back to normal

	movlw   4               ;4ms bit-time
	call    dly_ms

	decfsz  k,F             ;Do all bits requested
	goto    sl_2
;
	movlw   b'11111001'     ;Stop bits
	bsf     STATUS,RP0
	movwf   TRISB           ;Set pin 7 low via port direction control
	bcf     STATUS,RP0

	movlw   8               ;Two 4ms stop bit times
	call    dly_ms
;
;
	incf    index,F         ;Point to next
	decfsz  j,F
	goto    sl_1

	decfsz  i,F             ;Do specified number of lines
	goto    sl_0
	
	retlw   3               ;Preload w with default for next pass
;
;    Data block.  This data block was determined by Zohmann Friedrich
;    and Johannes Scholler from a "v5.0" PIC16C54 mod chip and was
;    originally written in its MSB-first start/stop bits-embedded form:
;    9 A9 3D 2B A5 and a final byte of B4 (SCEI), F4 (SCEA) or 74 (SCEE).
;
lines   addwf   PCL,F   ;Get index into table                 
	dt      'S','C','E','I' ;Japanese/NTSC
	dt      'S','C','E','A' ;U.S./NTSC     
	dt      'S','C','E','E' ;European/PAL
;
; Main program loop.
;
start   bsf     STATUS,RP0      ;OPTION and TRISx are in upper data page

	movlw   b'00000010'     ;Set TMR0 prescaler = 1:8 (f_osc=4MHz)     
	movwf   OPTION_REG      ;/

	movlw   b'11111111'     ;Make all port bits inputs initially
	movwf   TRISA
	movwf   TRISB           ;/

	bcf     STATUS,RP0      ;Back to normal

	clrf    mode            ;Clear toggle counter
;        
;  Step 1 -- approx. 50ms after reset, I/O pin 7 goes low.
;
	call    dly50           ;Delay 50ms
	
	bcf     PORTB,1         ;Make sure it's low
	movlw   b'11111101'     ;Make rb.1 low via port direction
	bsf     STATUS,RP0      ;TRISB in upper data page
	movwf   TRISB
	bcf     STATUS,RP0      ;Back to normal
;
;  Step 2 -- approx. 850ms later I/O pin 8 goes low.
;        
step2   movlw   17              ;17 x 50ms = 850ms
	movwf   i               ;/

s2_0    call    dly50
	decfsz  i,F
	goto    s2_0            ;/

	bcf     PORTB,2         ;Make sure it's low
	movlw   b'11111001'     ;Make rb.2 (and keep rb.1) low
	bsf     STATUS,RP0      ;TRISB in upper data page
	movwf   TRISB
	bcf     STATUS,RP0      ;Back to normal
;
;  Step 3 -- wait approx. 314ms
;
step3   movlw   6               ;6 x 50ms = 300ms
	movwf   i               ;/

s3_0    call    dly50
	decfsz  i,F
	goto    s3_0            ;/

	movlw   14              ;Final 14ms
	call    dly_ms          ;Returns with w=3 for step 4
;
;  Step 4 -- clock out all three datagrams on rb.1 ad infinitum.
;
step4   clrf    index           ;Start at beginning of 1st line
	call    sendln          ;Returns with w=3 for each pass
	incf    mode,F          ;Toggle delay mode flag
	goto    step4
;
; That's all, folks!
;
	end

