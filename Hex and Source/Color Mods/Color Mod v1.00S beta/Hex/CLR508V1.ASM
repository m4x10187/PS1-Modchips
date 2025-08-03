;
;       COLORMOD version 1.00S Beta (Single-chip solution)
;       See http://www.aeug.org/~chip/color/color.html for more
;       information.
;
;       PIC12C508 version of the "v5.3" serial data chip emulation.
;       This version uses an external crystal for system clock.
;       Written by the Old Crow (Scott Rider) on 28-NOV-97.
;       (Do not remove this header!)
;
;       Revision History:
;
;       1.00S  on 28-NOV-97    ;"Colormod" one-chip version
;
;       This version uses Microchip assembler mnemonics and the
;       Microchip MPASM assembler.  
;
;       A small circuit board is used to implement this circuit.
;       Module is connected in a 5-wire fashion:
;
; NTSC: XXX=3.579545MHz  
;  PAL: XXX=4.433619MHz  _______  _______
;                       |       \/       |
;             +5v=Vdd --+ 1 <<      >> 8 +-- Vss=Gnd
;     22p               |                |
;   +--)|-----+---------+ 2            7 +-- GP0
;   | 22p    XXX        |                |
;   +--)|-----+---------+ 3         >> 6 +-- GP1 "data"
;  _|_        |         |                |
;  \_/        |  GP3/ --+ 4         >> 5 +-- GP2/T0CKI "gate"
;             | !MCLR   |                |
;             |         +----------------+
;             |     2k2
;             +----/\/\/----> to CXA1645 pin 6 "SC"
;
;
;       ">>" and "<<" indicated pins connected to mainboard in addition 
;       to resistor connection.  Vdd can be either +3.5v or +5v.  Use
;       a 10uF cap and a 0.1uF cap close to the Vdd/Vss pins of the PIC
;       for decoupling. (Recommended)
;
	list    p=12c508
	radix   dec
	include "p12c508.inc"
;
;       Note: change the "NTSCPAL EQU 1" to "NTSCPAL EQU 0" below to 
;       instruct the assembler to make a chip for use with a 3.579545MHz
;       crystal (needed for NTSC colorburst via the 2k2 resistor into the
;       CXA1645).  Default is for a 4.433619MHz crystal, which is needed
;       for the PAL colorburst frequency.  Be sure to use the correct
;       crystal.
;
NTSCPAL EQU     1       ;Default assembles to PAL version

	__FUSES _MCLRE_OFF & _CP_OFF & _WDT_ON & _XT_OSC

	cblock  0x07    ;Store variables above control registers 

		i       ;Loop counters
		j
		k       ;/
		x       ;Used by delay routine
		y       ;/
		xmit    ;Transmit data holding register
		index   ;Index register for table lookups
	endc

	org     0x00            ;First location executed after 0x1FE
	goto    start

	org     0x40            ;Start of code space 
;
;  Support routines
;
;  dly50  -- entry for 50ms delay
;  dly_ms -- entry with number of ms in w (1 to 255)
;
dly50   movlw   50              ;Enter here for a 50ms delay
dly_ms  movwf   x               ;/  (this cycle counted below)

dy_0    movlw   222             ;XTAL=3.58MHz, cycle=1.1175us
	movwf   y               ;/

dy_1    clrwdt                  ;Delay loop, 4*222*1.1175us=992.34us.
	decfsz  y,F             ;   (PAL)         *0.9022us=801.15us.
	goto    dy_1

	IF      NTSCPAL         ;For PAL mode, 212 more cycles needed
	movlw   53              ;(4*53)-1=211
	movwf   y

dy_2    clrwdt                  ;211*0.9022=190.3642us
	decfsz  y,F
	goto    dy_2
	ENDIF
	
	decfsz  x,F             ;# of 1ms delays
	goto    dy_0
	
	retlw   3
;
;  sendln -- send 4-byte line(s) with a 72ms marker at head of line.
;  Enter with number of lines in w.
;
sendln  movwf   i               ;Do this many lines

sl_0    movlw   72              ;Delay 72ms
	call    dly_ms

	movlw   4               ;Do first half of line
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
	movlw   8               ;8 bit bytes
	movwf   k               ;/

	movlw   b'11111011'     ;Start bit on pin 7=1
	tris    GPIO

	movlw   4               ;4ms bit-time
	call    dly_ms

sl_2    rrf     xmit,F          ;Get a bit..

	movlw   b'11111001'     ;Keep port bits low when outputs
	movwf   GPIO            ;/

	btfsc   STATUS,C        ;High or low?
	movlw   b'11111011'     ;Set pin 7 high via port direction control
	btfss   STATUS,C        ;High or low?
	movlw   b'11111001'     ;Set pin 7 low via port direction control

	tris    GPIO            ;Set the port
	
	movlw   4               ;Delay 4ms
	call    dly_ms

	decfsz  k,F             ;Do all bits requested
	goto    sl_2

	movlw   b'11111001'     ;Stop bits
	tris    GPIO

	movlw   8               ;Two 4ms bit-times
	call    dly_ms
;
;        
	incf    index,F         ;Point to next
	decfsz  j,F
	goto    sl_1

	decfsz  i,F             ;Do specified number of lines
	goto    sl_0
	
	retlw   3
;
;    Data block.
;
lines   addwf   PCL,F   ;Get index into table                 
	dt      'S','C','E','I' ;Japanese/NTSC
	dt      'S','C','E','A' ;U.S./NTSC
	dt      'S','C','E','E' ;European/PAL
;
; Main program loop.
;
	org     0x0100

start   movlw   b'11000010'     ;Set TMR0 prescaler = 1:8 (f_osc=4MHz)     
	option                  ;/

	movlw   b'11111111'     ;Make all port bits inputs initially
	tris    GPIO            ;/
;        
;  Step 1 -- approx. 50ms after reset, I/O pin 7 goes low.
;
	call    dly50           ;Delay 50ms
	
	bcf     GPIO,1          ;Make sure it's low
	movlw   b'11111101'     ;Make rb.1 low via port direction
	tris    GPIO            ;/
;
;  Step 2 -- approx. 850ms later I/O pin 8 goes low.
;        
step2   movlw   17              ;17 x 50ms = 850ms
	movwf   i               ;/

s2_0    call    dly50
	decfsz  i,F
	goto    s2_0            ;/

	bcf     GPIO,2          ;Make sure it's low
	movlw   b'11111001'     ;Make rb.2 (and keep rb.1) low
	tris    GPIO            ;/
;
;  Step 3 -- wait approx. 314ms
;
step3   movlw   6               ;6 x 50ms = 300ms
	movwf   i               ;/

s3_0    call    dly50
	decfsz  i,F
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
; (Note: do NOT overwrite factory-programmed location 0x1FF !!)
;
; That's all, folks!
;
	end


