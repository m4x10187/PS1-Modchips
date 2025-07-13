;Downloaded from www.shoyle.force9.co.uk or www.modchipsuk.freeserve.co.uk
;Email steve@shoyle.force9.co.uk
;
;  code based upon rei code with stealth mods based on steves code and new connections
;  that he sussed out.....
;  uses NEW signal from game port/card connector to switch to stealth mode
;  but should not now need a switch to boot up 2nd game disk when swapped over
;
;  HEAVILY modified by "Mr BONGO"  27/2/99 - Many Thanx to Steve Hoyle
;
; code has not been tested !!!!!!!!
;
;       PIC12C508 version of the "v5.3" serial data chip emulation.
;       Written by the Old Crow (Scott Rider) on 6-JUN-97.
;
;       Revision History:
;       P1.01v5 on 19-JAN-97    ;Uses v5.0 chip data
;       P1.05   on 29-JAN-97    ;Uses ASCII version of v5.0 data
;       P1.051  on 22-FEB-97    ;Fixed tiny, unimportant timing bug
;       P1.052  on 06-JUN-97    ;Revised 5-wire version of '508 for 550x
;       P1.053  on 08-JUN-97    ;Alternating 4MHz/4.45MHz delay on 5-wire
;       P1.054  on 08-MAY-98    ;Fixed timing bug in 5-wire version
;
;	FEB'99 - LOTS OF WORK BY STEVE HOYLE AND BONGO
;
;       This version uses Microchip assembler mnemonics and the
;       Microchip MPASM assembler.
;
;                    Chip is connected in 7-wire fashion:
;   ###### DO NOT CONNECT CLOCK SIGNAL TO CHIP - USES INTERNAL RC OSCILLATOR #######
;
; ############################################
; ### NEED TO DOUBLE CHECK THE CONNECTIONS  ##
; ############################################
;
; These can be easily changed by altering #define 's lower down !!!!!!!!!!!
; 	               _______  _________
;                      |       \/       |
;              	 Vdd --+ 1 <<      >> 8 +-- Vss
;  Memory Card         |                |
;  Connector Pin 3   --+ 2 <<      >> 7 +-- signal from door (gpio0)
;                      |                |
;           Not used --+ 3         >> 6 +-- data stream (gpio1)
;                      |                |
; (gpio3) Reset Line --+ 4 <<      >> 5 +-- gate output (grio2)
;                      |                |
;                      +----------------+
;
; ############################################
; ### NEED TO DOUBLE CHECK THE CONNECTIONS  ##
; ############################################
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
	__FUSES _MCLRE_OFF & _CP_OFF & _WDT_OFF ;& _INT_OSC      ;4-wire
	cblock  0x07    ;Store variables above control registers 
		i       ;Loop counters
		j
		k       ;/
		x       ;Used by delay routine
		y       ;/
		xmit    ;Transmit data holding register
		index   ;Index register for table lookups
		loop1   ;Timer for how long chip outputs data.
		smflag  ; flag used to signal stealthmode by 1ms delay
		reflag  ; reset flag used to signal a reset by 1ms delay
	endc
; #############################################
; ### Note... pins can be swapped around by ###
; ### changing defines below now , makes it ###
; ### simpler to modify .................   ###
; ##############################################

#define	reset	GPIO,3		; whenever reset is used it is replaced
#define	door	GPIO,0		; by GPIO,3 now..... ditto for the others
#define memline	GPIO,5 		; 
#define stealthbit	smflag,0	; hope these work too....
#define resetbit	reflag,0	; hope these work too....

;##############################################

	org     0x00            ;Start of code space 
	movwf   OSCCAL          ;Set oscillator calibration reg.
	goto    start           ;Jump into main code segment

	org	0x08
	dt      ' ',' ',' ',' ',' ',' ',' ',' '	
	dt      'S','T','E','A','L','T','H','2'
	dt      ' ',' ',' ','B','Y',' ',' ',' '
	dt      ' ','S','T','E','V','E','H',' '
	dt      ' ',' ','A','N','D',' ',' ',' '
	dt      'M','R',' ','B','O','N','G','O'
	dt      ' ',' ',' ',' ',' ',' ',' ',' '

dly50   movlw   50              ;Enter here for a 50ms delay
dly_ms  movwf   x               ;/

;########################################
;## This bit has been heavily modified ##
;########################################
;
; AS THE CHIP SPENDS 99% OF ITS TIME IN HERE IT 
; MAKES SENSE TO CHECK THE MEMCARD LINE FROM IT
; GOT TO BE VERY CAREFUL TO GET THE TIMING RIGHT
;
; MEMLINE IS CHECKED WITHIN INNER LOOP
; RESET IS CHECKED WITHIN OUTER LOOP 
;
dy_0    movlw   198             ;1ms loop count (198 loops)
	movwf   y               ;/
dy_1	  	                ;Delay loop, default is 5 * 198 = 990 (we need 996 see later!!)
	btfss	memline         ; check memcard line for a logic 0 
	clrf	smflag		; clear stealth flag to 00 if 0, or skip if still 1
	decfsz  y,F
	goto    dy_1
	btfss	reset		; check the reset line here every 1ms ; 991
	clrf	reflag 		; clear reset flag if reset pressed   ; 992
	nop			; 993
	nop			; 994
	nop			; 995
	nop			; 996 

;######### end of timer mods ###########

dy_3    decfsz  x,F             ;# of 1ms delays
	goto    dy_0
	retlw   3

send1ln movlw	1		;do 1 line only - load w with 1

sendln  movwf   i               ;Do as many lines as in "w" register
sl_0    movlw   72              ;Delay 72ms
	call    dly_ms
	movlw   4               ;Do first half of line
	movwf   j               ;/
sl_1    movf    index,W         ;Restore index
	call    lines           ;Get a data byte..
	movwf   xmit            ;..into xmit buffer
	comf    xmit,F          ;Invert for sending
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
	incf    index,F         ;Point to next
	decfsz  j,F
	goto    sl_1
	decfsz  i,F             ;Do specified number of lines
	goto    sl_0
	retlw   3		; THIS 3 DICTATES HOW MANY LINES OF DATA TO SEND 

;    Data block.
lines   addwf   PCL,F   ;Get index into table   
	dt      'S','C','E','E' ;European/PAL
	dt      'S','C','E','I' ;Japanese/NTSC
	dt      'S','C','E','A' ;U.S./NTSC

;	org     0x0100		; not needed

start   movlw   b'11000010'     ;Set TMR0 prescaler = 1:8 (f_osc=4MHz)     
	option                  ;/
restart
	movlw   b'11111111'     ;Make all port bits inputs initially
	tris    GPIO            ;/
	call    dly50           ;Delay 50ms
	bcf     GPIO,1          ;Make sure it's low
	movlw   b'11111101'     ;Make rb.1 low via port direction
	tris    GPIO            ;/
step2   movlw   17              ;17 x 50ms = 850ms
	movwf   i               ;/
s2_0    call    dly50
	decfsz  i,F
	goto    s2_0            ;/
	bcf     GPIO,2          ;Make sure it's low
	movlw   b'11111001'     ;Make rb.2 (and keep rb.1) low
	tris    GPIO            ;/
step3   movlw   6               ;6 x 50ms = 300ms
	movwf   i               ;/
s3_0    call    dly50
	decfsz  i,F
	goto    s3_0            ;/
	movlw   14              ;Final 14ms
	call    dly_ms
;
; #########################################################
; This is similar to normal code except it goes to stealth
; mode as soon as disk has booted
; #########################################################

	movlw	255	    ; ARM the smflag, this is used in the delay routine
	movwf	smflag      ; if the delay routine spots the memcard line dropping to 0
			    ; the it clears this byte to 00, indicating it spotted the signal 
	movwf	reflag	    ; ditto for reset

; ##################################################################################
; THE FOLLOWING CODE SENDS OUT THE DATA STREAMS UNTIL THE 1msDELAY ROUTINE SPOTS THE
; MEMCARD LINE GOING LOW - (INDICATING MACHINE HAS NOW BOOTED) WHEN THE 'send1ln'
; HAS FINISHED TRANSMITTING WE THEN PASS CONTROL TO THE STEALTH SECTION OF CODE
; ##################################################################################

step4   clrf    index       ;reset index pointer to start of first line
	btfss   stealthbit  ;check if machine has booted 	 
	goto	stealth	
	call    send1ln	    ; send first line (scee) (uses send1ln instead of sendln)
	btfss   stealthbit  ;check smflag and goto stealth if 0	 
	goto	stealth	
	call    send1ln	    ; send second line (scei) 
	btfss   stealthbit  ;check smflag and goto stealth if 0	 
	goto	stealth
	call    send1ln	    ; send last line (scea) 
	btfss	resetbit
	goto	restart	    ; check reset flag and restart if required
	goto    step4

; #######################################################################
; THE FOLLOWING CODE MAKES THE CHIP ENTER STEALTH MODE BY FLOATING INPUTS
; AND IT THEN WAITS FOR A RESET OR DOOR OPEN
; #######################################################################

stealth				; THIS IS THE MAGICAL STEALTH MODE
	movlw	b'11111111'	;Enter Stealth mode all pins floating inputs
        tris    GPIO
waitopen		
	btfss	reset		; check the reset line
	goto	restart
	btfss   door	  	;Wait for door to open
        goto    waitopen

	movlw   255      ; wait for just over 1/2 second  
	call    dly_ms	 ; to allow door to be opened properly
	movlw	255
	call    dly_ms
;###############################################################
; THE DOOR HAS BEEN OPENED BY THE USER, NOW WAIT FOR IT TO CLOSE
;###############################################################

waitclose
	btfsc   door	; Check for Door Closing only now
        goto    waitclose ; Dont want to check reset switch if door is still open

;################################################################################
; THIS BIT IS CHEEKY, IT COMES OUT OF STEALTH MODE FOR A BIT AND OUTPUTS THE DATA
; TO TRY TO BOOT THE SECOND DISK, THEN IT GOES BACK TO STEALTH MODE AGAIN
; IT ALSO KEEPS AN EYE ON THE RESET LINE FOR GOOD MEASURE
;################################################################################

	movlw	39   ;  #####   MAY HAVE TO EXPERIMENT WITH THIS VALUE HERE !!!!!!!!

	movwf	loop1       ; Store value in loop1 register    
	movlw	255	    ; ARM the reset flag
	movwf	reflag	    ; with all 11111111's

cheeky  clrf    index           ;reset index ponter to 1st line of data
	btfss   resetbit    	;check reset flag, restart if reset	 
	goto	restart		
	call	send1ln
	btfss   resetbit    	;check reset flag, restart if reset	 
	goto	restart		
	call	send1ln
	btfss   resetbit    	;check reset flag, restart if reset	 
	goto	restart		
	call	send1ln
	decfsz	loop1,F		;decrement loop1 and skip when zero (o/p timer)
	goto    cheeky
	goto	stealth

;
; (Note: do NOT overwrite factory-programmed location 0x1FF !!)
;
;Downloaded from www.shoyle.force9.co.uk or www.modchipsuk.freeserve.co.uk
;email  steve@shoyle.force9.co.uk
;That's all, folks!
;
	end
