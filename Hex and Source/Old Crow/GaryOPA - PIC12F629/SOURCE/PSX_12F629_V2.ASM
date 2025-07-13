; PSX Model Mod-Chip design
;
; Version 2.01.070910
; Designed by garyOPA
; Developed by Phoenix 2001
; Manufacted by Oasis Pensive Abacutors
; Based on designs by Old Crow (Scott Rider)
;
; NOTES:
;
; * Re-Written to use the same chip as Wii now: 12F629
; * Instead of original code which was for the: 12C508
; * Reason for this new verison of code 10 years later
;
;       This version uses Microchip assembler mnemonics and the
;       Microchip MPASM assembler.  
;
;       Chip is connected in 4-wire fashion:
;
;                       _______  _______
;                      |       \/       |
;                Vdd --+ 1 <<      >> 8 +-- Vss
;                      |                |
;           GP5/OSC1 --+ 2            7 +-- GP0
;                      |                |
;           GP4/OSC2 --+ 3         >> 6 +-- GP1
;                      |                |
;          GP3/!MCLR --+ 4         >> 5 +-- GP2/T0CKI
;                      |                |
;                      +----------------+
;
;       4-wire: ">>" and "<<" indicated pins are connected.
;
;       4-Wire Operation: Be sure to set the following config options
;       on the __FUSES line below: MCLRE_OFF, CP_OFF, WDT_OFF, OSC=INTRC
;
	list    p=12f629
	include "p12f629.inc"
	radix   dec
	errorlevel  -302              ; suppress message 302 from list file;

	__FUSES _MCLRE_OFF & _CP_OFF & _WDT_OFF & _INTRC_OSC_NOCLKOUT    ;4-wire

	cblock  0x27    ;Store variables above control registers 

		i       ;Loop counters
		j       ;/
		k       ;/
		x       ;Used by delay routine
		y       ;/
		xmit    ;Transmit data holding register
		index   ;Index register for table lookups
		mode    ;Cheap counter used to toggle delay mode on original 5-wire
		mode1   ;Cheap counter used to toggle delay to toggle between 249/233
			;in 1msec delay, this is to allow for the errors in the 12c508
			;internal RC osc. (Might not be needed on the newer 12F629)
		loops	;number of times to send 3 blocks of data

	endc
;
;***** VARIABLE DEFINITIONS
;
w_temp        EQU     0x20        ; variable used for context saving 
status_temp   EQU     0x21        ; variable used for context saving
;
;**********************************************************************
;
		ORG     0x000             ; processor reset vector
		goto    main              ; go to beginning of program
;
; (12F629) = Interrupt Code (not used)
;
		ORG     0x004             ; interrupt vector location
		movwf   w_temp            ; save off current W register contents
		movf	STATUS,w          ; move status register into W register
		movwf	status_temp       ; save off contents of STATUS register
;
; isr code can go here or be located as a call subroutine elsewhere
;
		movf    status_temp,w     ; retrieve copy of STATUS register
		movwf	STATUS            ; restore pre-isr STATUS register contents
		swapf   w_temp,f
		swapf   w_temp,w          ; restore pre-isr W register contents
		retfie                    ; return from interrupt
;
; these first 4 instructions are not required if the internal oscillator is not used
;
main
		bsf	STATUS,RP0	  ; bank 1
		movlw	b'10000110'       ; Disable T0CKI on Pin 5
		movwf	OPTION_REG	  ; Set it!
		call    0x3FF             ; retrieve factory calibration value
		movwf   OSCCAL            ; update register with factory cal value 
		bcf     STATUS,RP0        ; set file register bank to 0
		clrf	GPIO		  ; Clear all the pins
;
; (12F629) = Goto to main PSX code
;
	goto    start           ;Jump into main code segment
;
;  Support routines
;
;  dly50  -- entry for 50ms delay
;  dly_ms -- entry with number of ms in w (1 to 255)
;
dly50   movlw   50              ;Enter here for a 50ms delay
dly_ms  movwf   x               ;/

dy_0    movlw   249             ;1ms loop count on 100x series (pre-SAN batch code or 5-wire)

	btfss	mode1,0		;differnt delay for post-SAN batch code?
	movlw	233		;yes, give it a whirl!

store_in_y
	movwf   y               ;/

dy_1    nop                     ;Delay loop, default is 4 * 249 = 996 for pre-SAN
				;and 			4 * 233 = 932 for post-SAN
				
	decfsz  y,F
	goto    dy_1

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

start
	movlw   b'11000010'     ;Set TMR0 prescaler = 1:8 (f_osc=4MHz)     
	option                  ;/

	movlw   b'11111111'     ;Make all port bits inputs initially
	tris    GPIO            ;/

	movlw	40		;move 40 to w (# of times to loop)
	movwf	loops		;load register
		
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
	incf    mode1,F         ;Toggle delay length for 1ms delay (4-wire version)
	decfsz	loops,F		;decrease loop (# of times to send data)	
	goto    step4		;not zero, send next lot

	movlw   b'11111111'     ;Make rb.1 input (allow normal data to go through)
	tris    GPIO            ;/

loop_4_ever
	goto	loop_4_ever	;guess!
;
; (12F629) = initialize eeprom locations
;
		ORG	0x2100
		DE	0x00, 0x01, 0x02, 0x03
;
; (Note: do NOT overwrite factory-programmed location 0x3FF !!)
;
; That's all, folks!
;
	end


