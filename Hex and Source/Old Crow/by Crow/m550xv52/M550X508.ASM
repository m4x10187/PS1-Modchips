;
;       PIC12C508 version of the "v5.2" serial data chip emulation.
;       Written by the Old Crow (Scott Rider) on 6-JUN-97.
;
;       NOTE: 5-wire version of this code is for 550X series machines ONLY.
;
;       Revision History:
;
;       P1.01v5 on 19-JAN-97    ;Uses v5.0 chip data
;       P1.05   on 29-JAN-97    ;Uses ASCII version of v5.0 data
;       P1.051  on 22-FEB-97    ;Fixed tiny, unimportant timing bug
;       P1.052  on 06-JUN-97    ;Revised 5-wire version of '508 for 550x
;
;       This version uses Microchip assembler mnemonics and the
;       Microchip MPASM assembler.  
;
;       Chip is connected in 4-wire or 5-wire fashion:
;
;                       _______  _______
;                      |       \/       |
;                Vdd --+ 1 <<      >> 8 +-- Vss
;                      |                |
;           GP5/OSC1 --+ 2 <*         7 +-- GP0
;                      |                |
;           GP4/OSC2 --+ 3         >> 6 +-- GP1
;                      |                |
;          GP3/!MCLR --+ 4         >> 5 +-- GP2/T0CKI
;                      |                |
;                      +----------------+
;
;       4-wire: ">>" and "<<" indicated pins are connected.
;       5-wire: ">>" and "<<" and "<*" pins are connected.
;
;       4-Wire Operation: Be sure to set the following config options
;       on the __FUSES line below: MCLRE_OFF, CP_OFF, WDT_OFF, OSC=INTRC
;
;       5-Wire Operation: (DEFAULT) Be sure to set the following config 
;       options on the __FUSES line: MCLRE_OFF, CP_OFF, WDT_OFF, OSC=XT
;
	list    p=12c508
	radix   dec
	include "p12c508.inc"
;
;       Note: change the "550X EQU 1" to "550X EQU 0" below to instruct
;       the assembler to make a 4-wire chip which works on all models.
;
M550X    EQU     1       ;Default assembles to 5-wire for 550x series

	IF      M550X
	__FUSES _MCLRE_OFF & _CP_OFF & _WDT_OFF & _XT_OSC       ;5-wire
	ELSE
	__FUSES _MCLRE_OFF & _CP_OFF & _WDT_OFF & 0xFFE         ;4-wire
	ENDIF

	cblock  0x07    ;Store variables above control registers 

		i       ;Loop counters
		j
		k       ;/
		x       ;Used by delay routine
		y       ;/
		xmit    ;Transmit data holding register
		index   ;Index register for table lookups
	endc

	org     0x00            ;Start of code space 
	
	movwf   OSCCAL          ;Set oscillator calibration reg.
	goto    start           ;Jump into main code segment
;
;  Support routines
;
;  dly50  -- entry for 50ms delay
;  dly_ms -- entry with number of ms in w (1 to 255)
;
dly50   movlw   50              ;Enter here for a 50ms delay
dly_ms  movwf   x               ;/

	IF      M550X
dy_0    movlw   222             ;1ms loop count on 550x series
	ELSE
dy_0    movlw   249             ;1ms loop count on 100x series
	ENDIF
	movwf   y               ;/

dy_1    nop                     ;Delay loop, default is 4 * 249 = 996
	
	IF      M550X
	nop                     ;Delay is 5 * 222 = 1110 for 550x series
	ENDIF

	decfsz  y,F
	goto    dy_1
	
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


