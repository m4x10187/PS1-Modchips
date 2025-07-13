;
; Z8 Mod Chip -- Equivlant to "V5.0" mod chip
; Written by the Old Crow on 22-FEB-97
;
; Revision history:
;
;       v1.05 on 22-FEB-97     "V5.0" program equivalent
;
;  This program demonstrates a different way of encoding the data block.
; See the data block comments below for detials.
;
; Program steps:
;
; 0) Set up microcontroller things; open-drain port, timer, etc.
; 1) approx. 50ms after reset, test gate/data buffer link.
; 2) approx. 850ms later, I/O P2-2 goes low w/314ms post-delay
; 3) Clock out datagram #1-3, below, on I/O P2-1.  (4ms/bit)
; 4) Goto step 3
;
;  Step 0: initialize the Z8
;
STACK:  EQU     80H                     ;Last RAM location+1

	ORG     0000H                   ;Start at the beginning..
;
;       Interrupt vectors
;
	DW      STEP0
	DW      STEP0
	DW      STEP0
	DW      STEP0
	DW      STEP0
	DW      TICKER                  ;Tick counter routine

STEP0:
;
;       Set up the Z8
;
	DI                              ;Disable IRQs on startup
	LD      SPL,#STACK              ;Set stack to top of RAM
	CLR     FLGS
	LD      IMR,#00100000B          ;Allow IRQ5
	LD      IPR,#00001000B          ;IRQ5 has priority
	LD      P01M,#00000101B         ;P0 input, int. stack
	LD      P3M,#00000000B          ;P3 input, P2 open-drain
	LD      P2,#11111111B           ;Make outputs high initially
	LD      P2M,#11111001B          ;P2-1 & P2-2 output, rest input
;
;       Set timer for 100us interval
;
	LD      PRE1,#2*4+3             ;Prescale modulo 2, timer modulo-N
	LD      T1,#25                  ;Timer=25 for 4MHz XTAL clock

	LD      TMR,#00001100B          ;Load and enable timer

	EI                              ;Enable interrupts
;
;  Step 1: approx. 50ms after reset, drop "data" (P2-1) low. 
;
STEP1:  CLR     R8                      ;Wait for 50ms
	LD      R9,#50
	CALL    WAITMS                  ;/

	AND     R2,#11111101B           ;Drop P2-1 "data" low
;
;  Step 2: approx. 4 seconds later, I/O P2-1 goes low.
;
STEP2:  LD      R8,#.H (850)           ;Wait for 850ms
	LD      R9,#.L (850)
	CALL    WAITMS                 ;/

	AND     R2,#11111011B          ;Drop P2-2 "gate" low

	LD      R8,#.H (314)           ;314ms
	LD      R9,#.L (314)
	CALL    WAITMS
;
;  Step 3: clock out LINE01-LINE03 datagrams listed below.  Send 
; lines serially on "pin 7" (P2-1).  Serial bit time is 4ms/bit, with  
; one start bit and two stop bits per byte.  RR14 has the starting 
; address of the data block, R13 is how many 4-byte lines to send.  
; R8,R9,R10,R11,R12 are used also.
;
STEP3:  LD      R14,#.H (LINE01)        ;Need base address of line
	LD      R15,#.L (LINE01)        ;/
	LD      R13,#3                  ;Three lines to send

__L01:  LD      R12,#4          ;Four bytes on a line

	CLR     R8              ;Delay 72ms
	LD      R9,#72          ;/
	CALL    WAITMS

__L02:  LD      R11,#8          ;Eight bits in a byte

	OR      R2,#00000010B   ;Start bit (high)

	CLR     R4
__L03:  CP      R4,#40          ;4ms
	JR      ULT,__L03

	LDC     R10,@RR14       ;Get a byte..
	COM     R10             ;Invert it..
	INCW    RR14            ;Point to next

__L04:  RR      R10             ;Get a bit..
	JR      NC,__L05        ;High or low?

	OR      R2,#00000010B   ;Set "pin 7" (P2-1) high
	JR      __L06

__L05:  AND     R2,#11111101B   ;Set "pin 7" (P2-1) low

__L06:  CLR     R4              ;Clear tick count
__L07:  CP      R4,#40          ;Wait for 4ms to tick off..
	JR      ULT,__L07       ;/

	DJNZ    R11,__L04       ;Do all bits of byte
	
	AND     R2,#11111101B   ;Stop bits (low)
	
	CLR     R4
__L08:  CP      R4,#80          ;2x4ms
	JR      ULT,__L08

	DJNZ    R12,__L02       ;Do all bytes of line
	DJNZ    R13,__L01       ;Do the specified number of lines
;
;  Step 4: repeat ad infinitum.
;
STEP4:  JR      STEP3
;
;       Support routines.
;
;       WAITMS -- Wait RR8 milliseconds.
;
WAITMS: CLR     R5              ;Clear tick2 count
	CLR     R6              ;Clear ms count
	CLR     R7              ;/

__L01:  CP      R6,R8           ;Done yet?
	JR      ULT,__L01
	CP      R7,R9
	JR      ULT,__L01       ;/

	RET
;
;       TICKER -- Interrupt routine for counting 100us ticks.
;       Register R4 is used for short (25ms max.) time intervals,
;       While RR6 (supported by R5) is used for longer intervals
;       (65,500ms max.)  This routine is executed whenever the
;       T1 timer, set for 100us, generates an interrupt.
;
TICKER: INC     R4              ;Tally up 100us ticks
	INC     R5              ;Also keep a tally for longer delays
	CP      R5,#10          ;1ms ticked off?
	JR      ULT,__L01

	INCW    RR6             ;1ms ticks for longer delay requests
	CLR     R5

__L01:  IRET
;
;   Data block:
;
;   This is the ASCII represntation of the country codes.  
; The mod chip works by blocking one of the original I/O lines at the 
; point where it passes through a level-conversion op-amp buffer chain 
; ("pin 8"), then the mod chip imposes its own data stream onto the logic 
; line the open-collector buffer was driving ("pin 7").  The new data 
; look like this:
;
LINE01: DB      'SCEI'  ;Japan/NTSC

LINE02: DB      'SCEA'  ;U.S./NTSC

LINE03: DB      'SCEE'  ;European/PAL
;
;  Data conversion example:
;
;  *) A single data string transmission looks like this:
;
;    72ms delay w/"data" pin low, then serial ASCII string 'SCEA'
;
;  *) Each byte in the string will be sent serially at 250 baud
;     with 1 start bit (low) and two stop bits (high).  It looks 
;     like this in binary, from RIGHT to LEFT:
;        'A'           'E'           'C'           'S'
;    11 01000001 0 11 01000101 0 11 01000011 0 11 01010011 0 
;
;  *) Now, since the serial data is inverted from the polarilty of
;     standard asynchronous serial data at logic-levels, all the bits
;     need to be complemented:
;
;    00 10111110 1 00 10111010 1 00 10111100 1 00 10101100 1 
;
;  *) Regroup the bits in sets of 8.  The last group will only have 4,
;     so pad it with zeroes.
;
;    00101111 10100101 11010100 10111100 10010101 1001(0000)
;
;  *) Now, write the bit string in reverse.  This is needed because
;     standard serial data is sent LSB first, but the author's original
;     data is sent MSB first.  Reversing the string so that the last bit
;     becomes the first bit compensates for this:
;
;    00001001 10101001 00111101 00101011 10100101 11110100
;
;  *) Make them into hex bytes, and the conversion is complete:
;
;    09 A9 3D 2B A5 F4
;
;  This version of the data string is sent as follows:
;
;    56ms delay/w "data" pin low, then 09 A9 3D 2B A5 F4
;
;  The data is sent at 250 bits/sec with no start or stop bits added;
;  they are already there.  Data is sent MSB-first.
;
;  That's all, folks!
;
       END


