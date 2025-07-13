;
;       SCEx keycard hacking project 2003
;       ---------------------------------
; 
;
;       16F84 Goldwafer version of P1.01ZF 
;       modified by Sam aka Selfboot Killer on 28-NOV-03
;       uses HEX representation of SCEx boot code
;
;       Modified for 16f84 and making RB7 as SCEx output.
;       RB1 still remain as before.
;
;
;       Formerly PIC16C84 version of the Z8 v1.01 serial data chip emulation.
;       Written by the Old Crow (Scott Rider) on 19-JAN-97
;
;       Revision History:
;
;       P1.01   on 19-JAN-97
;       P1.01B  on 28-JAN-97    ;Corrected cosmetic errors
;       P1.01ZF on 28-JAN-97    ;Uses alternate chip data (see below)
;       P2.GW   on 28-NOV-03    ;code edited for 16F84 Goldwafer smartcard
;
;
;
;       This version uses Microchip assembler mnemonics and the
;       Microchip MPASM assembler.  Default config options are set
;       on the __FUSES line below: PWRTE on, CP off, WDT off, OSC=XT
;
;
;       Chip usually is connected in 6-wire fashion, but:
;
;       The Goldwafer smartcard only needs 5 wires,
;       RB2 (orig CDs SCEx blocking) is not in use,
;       simply exctract keycard if orig CD is used.
;
;
;                     +-----+----------+
;   Pin14  VCC  +5V --+ 1   |        5 +-- Gnd  VSS  Pin05
;                     +-----+    +-----+
;   Pin04  MCLR Rst --+ 2   |    |   6 +-- nc.  N/C
;                     +-----+    +-----+
;   Pin16  RB6  Clk --+ 3   |    |   7 +-- I/O  RB7  Pin13 (SCEx output)
;                     +-----+    +-----+
;          N/C    4 --+ 4   |    |   8 +-- 8    N/C
;                     +-----+----+-----+
;
;
;                       _______  _______
;                      |       \/       |
;                RA2 --+ 1           18 +-- RA1
;                      |                |
;                RA3 --+ 2           17 +-- RA0
;                      |                |
;               RTCC --+ 3         >>16 +-- OSC1/CLKIN    C3
;                      |                |
;         C2   !MCLR --+ 4 <<        15 +-- OSC2/CLKOUT
;                      |                |
;         C5     Vss --+ 5 <<      >>14 +-- Vdd           C1
;                      |                |
;                RB0 --+ 6         >>13 +-- RB7           C7
;                      |                |
;                RB1 --+ 7 (<<)      12 +-- RB6
;                      |                |
;                RB2 --+ 8 (<<)      11 +-- RB5
;                      |                |
;                RB3 --+ 9           10 +-- RB4
;                      |                |
;                      +----------------+
;
;       "(<<)" indicates still connected pins, but not in use with Goldwafer
;       ">>" and "<<" indicate connected pins.  Refer to PC board diagrams
; available on the internet for further details.
;
;       Version P2.GW for MPASM
;
	list    p=16f84
	radix   dec
	include "p16f84.inc"

	__FUSES _CP_OFF & _WDT_OFF & _XT_OSC & _PWRTE_ON

	cblock  0x0C    ;Store variables above control registers 

		i       ;Loop counters
		j
		k
		l       ;/
		xmit    ;Transmit data holding register
		index   ;Index register for table lookups
	endc

	org     0x00            ;Start of code space 
	goto    start
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
;  sendln -- send 6-byte line(s) with a 60ms marker at head of line.
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
;  the port bit to be an input floats the I/O pin, and the xternal
;  pullup creates the high.  This allows open-collector operation of
;  the port bits.
;
	movlw   8               ;8 bits to send
	movwf   k               ;/

sl_2    rlf     xmit,F          ;Get a bit..

	movlw   b'01111001'     ;Keep port bits low when outputs
	movwf   PORTB           ;/

	btfsc   STATUS,C        ;High or low?
	movlw   b'11111011'     ;Set pin 7 high via port direction control
	btfss   STATUS,C        ;High or low?
	movlw   b'01111001'     ;Set pin 7 low via port direction control

	bsf     STATUS,RP0      ;TRISB in upper data page
	movwf   TRISB
	bcf     STATUS,RP0      ;Back to normal

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
	
	retlw   3               ;Preload w with default for next pass
;
;    Data block.  This data block was determined by Zohmann Friedrich
;    and Johannes Scholler.
;
lines   addwf   PCL,F   ;Get index into table                 
	dt      0x09,0xA9,0x3D,0x2B,0xA5,0xF4   ;Japanese/NTSC
	dt      0x09,0xA9,0x3D,0x2B,0xA5,0x74   ;European/PAL     
	dt      0x09,0xA9,0x3D,0x2B,0xA5,0xB4   ;U.S./NTSC
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
;        
;  Step 1 -- approx. 50ms after reset, I/O pin 7 goes low.
;
	call    dly50           ;Delay 50ms
	
	bcf     PORTB,1         ;Make sure it's low
	bcf     PORTB,7         ;Make sure it's low
	movlw   b'01111101'     ;Make rb.1 low via port direction
	bsf     STATUS,RP0      ;TRISB in upper data page
	movwf   TRISB
	bcf     STATUS,RP0      ;Back to normal
;
;  Step 2 -- approx. 850ms later I/O pin 8 goes low.
;        
step2   movlw   17              ;17 x 50ms = 850ms
	movwf   j               ;/

s2_0    call    dly50
	decfsz  j,F
	goto    s2_0            ;/

	bcf     PORTB,2         ;Make sure it's low
	movlw   b'01111001'     ;Make rb.2 (and keep rb.1) low
	bsf     STATUS,RP0      ;TRISB in upper data page
	movwf   TRISB
	bcf     STATUS,RP0      ;Back to normal
;
;  Step 3 -- wait approx. 314ms
;
step3   movlw   6               ;6 x 50ms = 300ms
	movwf   j               ;/

s3_0    call    dly50
	decfsz  j,F
	goto    s3_0            ;/

	movlw   14              ;Final 14ms
	call    dly_ms          ;Returns with w=3 for step 4
;
;  Step 4 -- clock out all three datagrams on rb.1 ad infinitum.
;
step4   clrf    index           ;Start at beginning of 1st line
	call    sendln          ;Returns with w=3 for each pass
	goto    step4
;
; That's all, folks!
;
	end

