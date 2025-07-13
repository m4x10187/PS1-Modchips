;
;       PIC12C508 version of the Z8 v1.01 serial data chip emulation.
;       Written by the Old Crow (Scott Rider) on 19-JAN-97
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
;	4-wire: ">>" and "<<" indicated pins are connected.
;	5-wire: ">>" and "<<" and "<*" pins are connected.
;	6-wire: ">>" and "<<" and "<*" and "<#" pins connected.
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
;	Note: uncomment only one of the __FUSES lines.
;
	__FUSES	_MCLRE_OFF & _CP_OFF & _WDT_OFF & 0xFFE		;4-wire
;	__FUSES	_MCLRE_OFF & _CP_OFF & _WDT_OFF & _XT_OSC	;5-wire
;	__FUSES	_MCLRE_ON & _CP_OFF & _WDT_OFF & _XT_OSC	;6-wire

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
	
	retlw   0
;
;  sendln -- send 12-byte line(s) with a 64ms marker before each half.
;  Enter with number of lines in w.
;
sendln  movwf   l               ;Do this many lines

sl_0    movlw   64              ;Delay 64ms
	call    dly_ms

	movlw   6               ;Do first half of line
	movwf   j               ;/

sl_1    movf    index,W         ;Restore index
	call    lines           ;Get a data byte..
	movwf   xmit            ;..into xmit buffer
	call    serial8         ;Send byte
	incf    index,F         ;Point to next
	decfsz  j,F
	goto    sl_1

	movlw   64              ;Delay 64ms
	call    dly_ms

	movlw   5               ;Do rest of line minus one byte
	movwf   j               ;/


sl_2    movf    index,W         ;Deja vu..
	call    lines
	movwf   xmit
	call    serial8
	incf    index,F
	decfsz  j,F
	goto    sl_2

	movf    index,W         ;Do upper 4 bits of last byte
	call    lines
	movwf   xmit
	movlw   4               ;Send 4 bits
	call    serialn         ;/
	incf    index,F
	movlw   b'11111001'     ;Set rb.1 (and keep rb.2) low at line end
	movwf   GPIO
	tris    GPIO

	decfsz  l,F             ;Do specified number of lines
	goto    sl_0
	
	retlw   0

;
;  serial8 -- send a byte on rb.1.  MSB first, 4ms/bit.  Instead of
;  setting and clearing the port bit, the port's direction is changed
;  instead.  The actual port register is set to zero, so that when the
;  port bit is directed to be an output, it automatically goes low.
;  Directing the port bit to be an input floats the I/O pin, and the
;  external pullup creates the high.  This allows open-collector
;  operation of the port bits.
;
;  Enter at serial8 for 8-bit bytes.
;  Enter at serialn with number of bits in w.
;
serial8 movlw   8               ;Call here for 8 bits
serialn movwf   k               ;# of bits

so_0    rlf     xmit,F          ;Get a bit..

	movlw   b'11111001'     ;Keep port bits low when outputs
	movwf   GPIO            ;/

	btfsc   STATUS,C        ;High or low?
	movlw   b'11111011'     ;Set pin 7 high via port direction control
	btfss   STATUS,C        ;High or low?
	movlw   b'11111001'     ;Set pin 7 low via port direction control

	tris    GPIO            ;Set the port
;
;  In-line delay (since 2 calls already nested)
;
	movlw   4               ;Delay 4ms
	movwf   i               ;/

so_1    movlw   -125            ;Preset counter (counting 125 8us ticks)
	movwf   TMR0            ;/

so_2    movf    TMR0,W          ;Check for 1ms elapsed
	iorlw   0               ;/
	btfss   STATUS,Z
	goto    so_2

	decfsz  i,F
	goto    so_1

	decfsz  k,F             ;Do all bits requested
	goto    so_0

	retlw   0
;
;    Data block.
;
lines   addwf   PCL,F   ;Get index into table                 
	dt      0xff,0x41,0x3d,0x2b,0xa6,0x20,0x26,0xa4,0xf4,0xae,0x96,0xd0
	dt      0x09,0xa9,0x3d,0x2b,0xa5,0xf4,0x3a,0x87,0x2c,0xae,0x97,0xd0
	dt      0x0d,0x09,0x74,0x2b,0xa5,0x74,0x26,0xa4,0xf4,0xae,0x95,0xd0
	dt      0x09,0xa9,0x3d,0x2b,0xa5,0xf4,0x2f,0xa5,0x98,0xf8,0x15,0xd0
	dt      0x0a,0xe9,0xb8,0x27,0xa5,0xd8,0x26,0xa4,0xf4,0xae,0x96,0xd0
	dt      0x00,0x09,0x3d,0x2b,0xa5,0xf4,0x2f,0xa4,0x30,0xcd,0x95,0xd0
	dt      0x00,0x09,0x3d,0x2b,0xa7,0x6c,0x26,0xa4,0xf4,0xae,0x96,0xd0
	dt      0x00,0x09,0x3d,0x2b,0xa5,0xf4,0x35,0xe6,0xe4,0xae,0x97,0xd0
	dt      0x0e,0xc9,0xc2,0x2b,0xa5,0x74,0x26,0xa4,0xf4,0xae,0x95,0xd0
	dt      0x00,0x09,0x3d,0x2b,0xa5,0xf4,0x2e,0xa7,0xa8,0xbe,0x95,0xd0
	dt      0x00,0x09,0x8d,0x2b,0xa5,0x00,0x26,0xa4,0xf4,0xae,0x96,0xd0
	dt      0x00,0x09,0x3d,0x2b,0xa5,0xf4,0x20,0x46,0x5c,0xae,0x97,0xd0
	dt      0x0f,0x41,0x3d,0x2b,0xa6,0x20,0x26,0xa4,0xf4,0xae,0x96,0xd0
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
;  Step 2 -- approx. 850ms later I/O pin 7 goes high & I/O pin 8 goes low.
;        
step2   movlw   17              ;17 x 50ms = 850ms
	movwf   j               ;/

s2_0    call    dly50
	decfsz  j,F
	goto    s2_0            ;/

	bcf     GPIO,2          ;Make sure it's low
	movlw   b'11111011'     ;Make rb.1 float and rb.2 low
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
;  Step 4 -- clock out first datagram on rb.1
;
step4   clrf    index           ;Do first line
	movlw   1               ;One line to do
	call    sendln
;
;  Step 5 -- clock out datagrams 2 through 13 on rb.1
;
step5   movlw   12
	movwf   index           ;Start at beginning of 2nd line
	call    sendln
;
;  Step 6 -- goto step 5
;
	goto    step5
;
; (Note: do NOT overwrite factory-programmed location 0x1FF !!)
;
; That's all, folks!
;
	end

