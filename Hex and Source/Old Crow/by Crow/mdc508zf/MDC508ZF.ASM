;
;       PIC12C508 version of the Z8 v1.01 serial data chip emulation.
;       Written by the Old Crow (Scott Rider) on 19-JAN-97
;
;       Revision History:
;
;       P1.01   on 19-JAN-97
;       P1.01zf on 29-JAN-97    Uses alternate data block (see below)
;
;       This version uses Microchip assembler mnemonics and the
;       Microchip MPASM assembler.  
;
;       Chip is connected in 4-wire, 5-wire or 6-wire fashion:
;
;                       _______  _______
;                      |       \/       |
;                Vdd --+ 1 <<      >> 8 +-- Vss
;                      |                |
;           GP5/OSC1 --+ 2 <*         7 +-- GP0
;                      |                |
;           GP4/OSC2 --+ 3         >> 6 +-- GP1
;                      |                |
;          GP3/!MCLR --+ 4 <#      >> 5 +-- GP2/T0CKI
;                      |                |
;                      +----------------+
;
;       4-wire: ">>" and "<<" indicated pins are connected.
;       5-wire: ">>" and "<<" and "<*" pins are connected.
;       6-wire: ">>" and "<<" and "<*" and "<#" pins connected.
;
;       4-Wire Operation: Use the following default config options
;       on the __FUSES line below: MCLRE_OFF, CP_OFF, WDT_OFF, OSC=INTRC
;
;       5-Wire Operation: Be sure to set the following config options
;       on the __FUSES line: MCLRE_OFF, CP_OFF, WDT_OFF, OSC=XT
;
;       6-Wire Operation: MCLRE_ON, CP_OFF, WDT_OFF, OSC=XT
;
;       Version P1.01 for MPASM
;
	list    p=12c508
	radix   dec
	include "p12c508.inc"
;
;       Note: uncomment only one of the __FUSES lines.
;
	__FUSES _MCLRE_OFF & _CP_OFF & _WDT_OFF & 0xFFE         ;4-wire
;       __FUSES _MCLRE_OFF & _CP_OFF & _WDT_OFF & _XT_OSC       ;5-wire
;       __FUSES _MCLRE_ON & _CP_OFF & _WDT_OFF & _XT_OSC        ;6-wire

	cblock  0x07    ;Store variables above control registers 

		i       ;Loop counters
		j
		k
		l       ;/
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
dly_ms  movwf   i               ;/

dy_0    movlw   -125            ;Preset counter (counting 125 8us ticks)
	movwf   TMR0            ;/

dy_1    movf    TMR0,W          ;Check for 1ms elapsed
	iorlw   0
	btfss   STATUS,Z
	goto    dy_1
	
	decfsz  i,F
	goto    dy_0
	
	retlw   3
;
;  sendln -- send 6-byte line(s) with a 60ms marker at head of line.
;  Enter with number of lines in w.
;
sendln  movwf   l               ;Do this many lines

sl_0    movlw   60              ;Delay 60ms
	call    dly_ms

	movlw   6               ;Do first half of line
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
	movlw   8               ;8 bit bytes
	movwf   k               ;/

sl_2    rlf     xmit,F          ;Get a bit..

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
;
;        
	incf    index,F         ;Point to next
	decfsz  j,F
	goto    sl_1

	decfsz  l,F             ;Do specified number of lines
	goto    sl_0
	
	retlw   3
;
;    Data block.
;
lines   addwf   PCL,F   ;Get index into table                 
	dt      0x09,0xA9,0x3D,0x2B,0xA5,0xF4   ;F4, Japanese/NTSC
	dt      0x09,0xA9,0x3D,0x2B,0xA5,0x74   ;74, European/PAL
	dt      0x09,0xA9,0x3D,0x2B,0xA5,0xB4   ;B4, U.S./NTSC
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
	movwf   j               ;/

s2_0    call    dly50
	decfsz  j,F
	goto    s2_0            ;/

	bcf     GPIO,2          ;Make sure it's low
	movlw   b'11111001'     ;Make rb.2 (and keep rb.1) low
	tris    GPIO            ;/
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
; (Note: do NOT overwrite factory-programmed location 0x1FF !!)
;
; That's all, folks!
;
	end


