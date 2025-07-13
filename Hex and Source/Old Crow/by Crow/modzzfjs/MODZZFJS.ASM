;
; Program to do what a PIC16C54 "mod chip" does.
; Written by the Old Crow on 20-DEC-96
;
; Revision history:
;
;       v1.00 on 20-DEC-96      Inital no-frills version
;       v1.01 on 24-DEC-96      Space-optimized code
;       vZFJS on 29-JAN-97      Uses different data block (see below)
;
; Note: this program runs on a Z8 microcontroller as I don't have any
; blank PIC chips.  This code works just like a "6-wire" PIC mod chip,
; but only needs 5 wires to operate.
;
; Program steps:
;
; 0) Set up microcontroller things; open-drain port, timer, etc.
; 1) approx. 50ms after reset, I/O P2-1 (pin 7 on PIC) goes low.
; 2) approx. 850ms later, I/O P2-1 goes high and I/O P2-2 goes low.
; 3) wait 314ms.                                      \-(pin 8 on PIC)
; 4) Clock out datagram #1-3, below, on I/O P2-1.  (4ms/bit)
; 5) Goto step 4
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
;  Step 1: approx. 50ms after reset, I/O pin 7 goes low.
;
STEP1:  CLR     R8                      ;Wait for 50ms
	LD      R9,#50
	CALL    WAITMS                  ;/

	AND     R2,#11111101B           ;Drop P2-1 ("pin 7") low
;
;  Step 2: approx. 850ms later, I/O P2-1 goes hi, I/O P2-2 goes low
;
STEP2:  LD      R8,#.H (850)            ;Wait for 850ms
	LD      R9,#.L (850)
	CALL    WAITMS                  ;/

	AND     R2,#11111011B           ;Drop P2-2 ("pin 8") low
;        OR      R2,#00000010B           ;Raise pin P2-1 ("pin 7") high
;
;  Step 3: wait approx. 314ms
;
STEP3:  LD      R8,#.H (314)            ;Wait for 314ms
	LD      R9,#.L (314)
	CALL    WAITMS                  ;/
;
;  Step 4: clock out LINE01-LINE03 datagrams listed below.  Send 
; lines serially on "pin 7" (P2-1).  Serial bit time is 4ms/bit.  
; RR14 has the starting address of the data block, R13 is how many 
; 6-byte lines to send.  R8,R9,R10,R11,R12 are used also.
;
STEP4:  LD      R14,#.H (LINE01)        ;Need base address of line
	LD      R15,#.L (LINE01)        ;/
	LD      R13,#3                  ;Three lines to send

__L01:  LD      R12,#6          ;Six bytes on a line

	CLR     R8              ;Delay 60ms
	LD      R9,#60          ;/
	CALL    WAITMS

__L02:  LD      R11,#8          ;Eight bits in a byte

	LDC     R10,@RR14       ;Get a byte..
	INCW    RR14            ;Point to next

__L03:  RL      R10             ;Get a bit..
	JR      NC,__L04        ;High or low?

	OR      R2,#00000010B   ;Set "pin 7" (P2-1) high
	JR      __L05

__L04:  AND     R2,#11111101B   ;Set "pin 7" (P2-1) low

__L05:  CLR     R4              ;Clear tick count
__L06:  CP      R4,#40          ;Wait for 4ms to tick off..
	JR      ULT,__L06       ;/

	DJNZ    R11,__L03       ;Do all bits of byte
	DJNZ    R12,__L02       ;Do all bytes of line (except last one)
	DJNZ    R13,__L01       ;Do the specified number of lines
;
;  Step 5: repeat ad infinitum.
;
STEP5:  JR      STEP4
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
;   This data was determined by Zohmann Friedrich and Johannes Scholler.  
; The mod chip works by blocking one of the original I/O lines at the 
; point where it passes through a level-conversion op-amp buffer chain 
; ("pin 8"), then the mod chip imposes its own data stream onto the logic 
; line the open-collector buffer was driving ("pin 7").  The new data 
; look like this:
;
LINE01: DB      09h,0a9h,3dh,2bh,0a5h,0F4h      ;F4, Japanese/NTSC

LINE02: DB      09h,0a9h,3dh,2bh,0a5h,74h       ;74, European/PAL

LINE03: DB      09h,0a9h,3dh,2bh,0a5h,0B4h      ;B4, U.S./NTSC
;
; That's all, folks!
;
;       DB       ' Distribute like crazy!!! --The Old Crow '
       END


