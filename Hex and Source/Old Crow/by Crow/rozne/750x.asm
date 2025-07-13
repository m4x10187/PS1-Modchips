;
;       PIC12C508 version of the "v5.3" serial data chip emulation.
;       Written by the Old Crow (Scott Rider) on 6-JUN-97.
;
;       *NOTE* Latest Microchip assembler is 'case-sensitive' -
;       -so check your 'include' file; to see whether it uses -
;       -the " INTRC " or " IntRC " - michaeljohn mercury.
;
;       Modified by Charles on 10-August 1998 for Model 7502
;
;       5 Wire Version.  
;
;       Boots ALL Original Games and ALL Copied games.
;
;
;       Revision History:
;
;       P1.01v5 on 19-JAN-97    ;Uses v5.0 chip data
;       P1.05   on 29-JAN-97    ;Uses ASCII version of v5.0 data
;       P1.051  on 22-FEB-97    ;Fixed tiny, unimportant timing bug
;       P1.052  on 06-JUN-97    ;Revised 5-wire version of '508 for 550x
;       P1.053  on 08-JUN-97    ;Alternating 4MHz/4.45MHz delay on 5-wire
;       P1.054  on 08-MAY-98    ;Fixed timing bug in 5-wire version
;
;       This version uses Microchip assembler mnemonics and the
;       Microchip MPASM assembler.  
;
;       Chip is connected in 5-wire fashion:
;
;                       _______  _______
;                      |       \/       |
;                Vdd --+ 1 <<      >> 8 +-- Vss
;                      |                |
;           GP5/OSC1 --+ 2         >> 7 +-- GP0
;                      |                |
;           GP4/OSC2 --+ 3         >> 6 +-- GP1
;                      |                |
;          GP3/!MCLR --+ 4 <<         5 +-- GP2/T0CKI
;                      |                |
;                      +----------------+
;
;
;       Note: change the "P509 EQU 0" to "P509 EQU 1" below to instruct
;       the assembler to make the hex object code for a PIC12C509.
;
P509    EQU     0       ;Default assembles for a PIC12C508

	IF      P509
	list    p=12c509
	include "p12c509.inc"
	ELSE
	list    p=12c508
	include "p12c508.inc"
	ENDIF
	radix   dec
;
;

	__FUSES _MCLRE_OFF & _CP_OFF & _WDT_OFF & _INT_OSC

	cblock  0x07    ;Store variables above control registers 

		i       ;Loop counters
		j
		k       ;/
		x       ;Used by delay routine
		y       ;/
		xmit    ;Transmit data holding register
		index   ;Index register for table lookups
		tstat   ;Current TRIS setting
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

dy_0    movlw   90              ;1ms loop count on 100x series
	movwf   y               ;/

dy_1    nop                     ;Delay loop, default is 11 * 90 = 990
	nop

	btfsc   GPIO,3          ;Read Input rb.3
	bsf     tstat,0         ;Set Output rb,0
	btfss   GPIO,3          ;Read Input rb.3
	bcf     tstat,0         ;Clear Output rb.0

	movf    tstat,W         ;Read TRIS State
	tris    GPIO    

	decfsz  y,F
	goto    dy_1
	
	nop                     ;Another 6 Micro's
	nop
	nop
	nop
	nop
	nop

dy_3    decfsz  x,F             ;# of 1ms delays
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

	bsf     tstat,1         ;Start bit on pin 6=1
	movf    tstat,W
	tris    GPIO

	movlw   4               ;4ms bit-time
	call    dly_ms

sl_2    rrf     xmit,F          ;Get a bit..

	movlw   b'11111000'     ;Keep port bits low when outputs
	movwf   GPIO            ;/

	btfsc   STATUS,C        ;High or low?
	bsf     tstat,1         ;Set pin 6 high via port direction control
	btfss   STATUS,C        ;High or low?
	bcf     tstat,1         ;Set pin 6 low via port direction control
	movf    tstat,W
	tris    GPIO            ;Set the port
	
	movlw   4               ;Delay 4ms
	call    dly_ms

	decfsz  k,F             ;Do all bits requested
	goto    sl_2

	bcf     tstat,1         ;Stop bits
	movf    tstat,W
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
	movwf   tstat
	tris    GPIO            ;/

;        
;  Step 1 -- approx. 50ms after reset, I/O pin 6 goes low.
;
	call    dly50           ;Delay 50ms
	
	bcf     GPIO,0          ;Make sure PIN 7 is low
	bcf     GPIO,1          ;Make sure it's low
	bcf     tstat,1         ;Make rb.1 low via port direction
	movf    tstat,W
	tris    GPIO            ;/
;
;  Step 2 -- approx. 850ms later I/O pin 5 goes low.
;        
step2   movlw   17              ;17 x 50ms = 850ms
	movwf   i               ;/

s2_0    call    dly50
	decfsz  i,F
	goto    s2_0            ;/

	bcf     GPIO,2          ;Make sure it's low
	bcf     tstat,2         ;Make rb.2 (and keep rb.1) low
	movf    tstat,W
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

