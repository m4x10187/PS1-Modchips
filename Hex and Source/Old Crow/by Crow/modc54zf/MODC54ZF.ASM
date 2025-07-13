;
;       PIC16C54 version of the Z8 v1.01 serial data chip emulation.
;       Written by the Old Crow (Scott Rider) on 19-JAN-97
;
;       Revision History:
;
;       P1.01   on 19-JAN-97
;       P1.01ZF on 29-JAN-97    Uses Zohmann & Johannes'data block
;
;       This version uses Microchip assembler mnemonics and the
;       Microchip MPASM assembler.  Default config options are set
;       in the __FUSES line below: CP off, WDT off, OSC=XT.
;
;       Version P1.01ZF for MPASM
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
; available on the internet.
;
	list    p=16c54
	radix   dec
	include "p16c5x.inc"

	__FUSES _CP_OFF & _WDT_OFF & _XT_OSC    ;Set default config

	cblock  0x08    ;Store variables above control registers 

		i       ;Loop counters
		j
		k
		l       ;/
		xmit    ;Transmit data holding register
		index   ;Index register for table lookups
	endc

	org     0x00            ;Start of code space 
;
;  Support routines
;
;  dly50  -- entry for 50ms delay
;  dly_ms -- entry with number of ms in w (1 to 255)
;
dly50   movlw   50              ;Enter here for a 50ms delay
dly_ms  movwf   i               ;/

dy_0    movlw   -125            ;Preset counter (counting 125 8us ticks)
	movwf   TMR0            ;/

dy_1    movf    TMR0,W          ;Check for 1ms elapsed
	iorlw   0
	btfss   STATUS,Z
	goto    dy_1
	
	decfsz  i,F
	goto    dy_0
	
	retlw   3               ;w=3 default for sendln
;
;  sendln -- send 6-byte line(s) with a 60ms at head of line.
;  Enter with number of lines in w.
;
sendln  movwf   l               ;Do this many lines

sl_0    movlw   60              ;Delay 60ms
	call    dly_ms

	movlw   6               ;Do 6-byte line
	movwf   j               ;/

sl_1    movf    index,W         ;Restore index
	call    lines           ;Get a data byte..
	movwf   xmit            ;..into xmit buffer
;
;       Send a byte on rb.1.  MSB first, 4ms/bit.  Instead of setting
;  and clearing the port bit, the port's direction is changed instead.  
;  The actual port register is set to zero, so that when the port bit 
;  is directed to be an output, it automatically goes low.  Directing 
;  the port bit to be an input floats the I/O pin, and the external 
;  pullup creates the high.  This allows open-collector operation of 
;  the port bits.
;
	movlw   8               ;Call here for 8 bits
	movwf   k               ;# of bits

sl_2    rlf     xmit,F          ;Get a bit..

	movlw   b'11111001'     ;Keep port bits low when outputs
	movwf   PORTB           ;/

	btfsc   STATUS,C        ;High or low?
	movlw   b'11111011'     ;Set pin 7 high via port direction control
	btfss   STATUS,C        ;High or low?
	movlw   b'11111001'     ;Set pin 7 low via port direction control

	tris    PORTB           ;Set the port
	
	movlw   4               ;Delay 4ms
	call    dly_ms

	decfsz  k,F             ;Do all bits requested
	goto    sl_2
;
;
	incf    index,F         ;Point to next
	decfsz  j,F
	goto    sl_1

	decfsz  l,F             ;Do specified number of lines
	goto    sl_0
	
	retlw   3
;
;    Data block.  This data was determined by Zohmann Friedrich and
;    Johannes Scholler.  (I determined which line affected which machine.)   
;
lines   addwf   PCL,F   ;Get index into table                 
	dt      0x09,0xA9,0x3D,0x2B,0xA5,0xF4   ;F4, Japanese/NTSC
	dt      0x09,0xA9,0x3D,0x2B,0xA5,0x74   ;74, European/PAL
	dt      0x09,0xA9,0x3D,0x2B,0xA5,0xB4   ;B4, U.S./NTSC
;
; Main program loop.
;
	org     0x0100

start   movlw   b'00000010'     ;Set TMR0 prescaler = 1:8 (f_osc=4MHz)     
	option                  ;/

	movlw   b'11111111'     ;Make all port bits inputs initially
	tris    PORTA
	tris    PORTB           ;/

;        
;  Step 1 -- approx. 50ms after reset, I/O pin 7 goes low.
;
	call    dly50           ;Delay 50ms
	
	bcf     PORTB,1         ;Make sure it's low
	movlw   b'11111101'     ;Make rb.1 low via port direction
	tris    PORTB           ;/
;
;  Step 2 -- approx. 850ms later I/O pin 8 goes low.
;        
step2   movlw   17              ;17 x 50ms = 850ms
	movwf   j               ;/

s2_0    call    dly50
	decfsz  j,F
	goto    s2_0            ;/

	bcf     PORTB,2         ;Make sure it's low
	movlw   b'11111001'     ;Make rb.2 (and keep rb.1) low
	tris    PORTB           ;/
;
;  Step 3 -- wait approx. 314ms
;
step3   movlw   6               ;6 x 50ms = 300ms
	movwf   j               ;/

s3_0    call    dly50
	decfsz  j,F
	goto    s3_0            ;/

	movlw   14              ;Final 14ms
	call    dly_ms
;
;  Step 4 -- clock out all three datagrams on rb.1 ad infinitum.
;
step4   clrf    index           ;Do first line
	call    sendln
	goto    step4
;
;  Reset vector.  (16C5x only!)
;
	org     0x01FF
	goto    start
;
; That's all, folks!
;
	end

