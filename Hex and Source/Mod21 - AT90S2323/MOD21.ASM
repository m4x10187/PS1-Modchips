

.include "2323def.inc"
;.include "1200def.inc"

;***** Pin definitions

.equ	DataInject	=0	       ;Serial Transmit Pin PB0
.equ	DataBlock	=1      	;Blocker pin is PB1

;***** Global register variables

.def	bitcnt	=R16			;bit counter
.def	temp	=R17			;temporary storage register
.def	clock	=R18			;temporary storage register


.def	TXbyte	=R19			;Data to be transmitted
.def   	Delay1	=R20
.def   	Delay2	=R21 
.def	CharCount=R22			;Line Index 

.cseg
.org 0
;*INTERRUPT JUMP TABLE

		rjmp   reset  ;Reset
; 		reti          ;IRQ handle
;		reti          ;Timer0
		

;***** Program Execution Starts Here

reset:

       	ldi	temp,low(RAMEND)
	out	SPL,temp

	sbi	ddrb,PB0	;pin PB0--> push_pull output
;	sbi	ddrb,PB1	;pin PB1--> push_pull output
;************************************************************************
;	sbi	ddrb,PB4         ;Port PB4 (pin 3) output to check palse width
;************************************************************************
	cbi	PORTB,PB0
	cbi	PORTB,PB1	;pin PB0--> push_pull output

	ldi	clock,25	
	sbis	PINB,PB4
	ldi	clock,56
	

;*************************************************************

DemoLoop:

                Ldi Delay2,50
              	Rcall Delay_Xms         ;Το πρώτο delay 50ms
        	sbi	ddrb,PB0	;pin PB0--> push_pull output
	

                                           ;Το 2ο Delay είναι 850 ms (3*255)+85
                Ldi Delay2,255
                Rcall Delay_Xms

                Ldi Delay2,255
                Rcall Delay_Xms

                Ldi Delay2,255
                Rcall Delay_Xms


                Ldi Delay2,85
                Rcall Delay_Xms

         	sbi	ddrb,PB1	;pin PB0--> Low


                Ldi Delay2,255           ;Το 3ο Delay είναι 314 ms (255+59)
                Rcall Delay_Xms 

                Ldi Delay2,59
                Rcall Delay_Xms


ConstLoop:

;                Ldi Delay2,100
;                Rcall Delay_Xms


;***********************************************************
;This line is for test perposes only
;                sbi PortB,PB4
;***********************************************************


                Rcall SendLine

;                Ldi Delay2,100
;                Rcall Delay_Xms


;***********************************************************
;This line is for test perposes only
;                cbi PortB,PB4
;***********************************************************

		


                Rjmp ConstLoop

	
		
	

;***************************************************************


SendLine :



               Ldi ZL,Low(OutData*2)    ;Ο Ζ δείχνει στην αρχή των data
               Ldi ZH,High(OutData*2)


SendLine_InitDelay:


               Ldi Delay2,72           ;Αρχικό delay 72 ms


               Rcall Delay_Xms



               Ldi CharCount,0          ;Μηδενίζουμε και τον μετρητή χαρακτήρων  

SendLine_Loop:

               Lpm                     ;Φορτώνουμε τα περιεχόμενα της δν/σης
                                       ;που δείχνει ο Ζ στην Flash στον R0               

               Mov TxByte,R0           ;κάνουμε copy τον R0 στον buffer 
;               Ldi TxByte,$53
               Cpi Txbyte,0            ;ελέγχουμε αν φτάσαμε στο τέλος
               Breq SendLine_End       ;ναι 

               Rcall Putchar           ;και τον στέλνουμε
               
               Inc ZL
               Inc CharCount

               Cpi CharCount,4        ;Ελέγχουμε αν στείλαμε μια λέξη

               Breq SendLine_InitDelay ;αν ναι τότε delay 72ms
               Rjmp SendLine_Loop      ;αλλιώς στέλνουμε τον επόμενο χαρακτήρα

SendLine_End:
               Ret                     ;Τελειώσαμε


;**************************************************************************

Putchar:

	ldi	bitcnt,9	;1+8  StartBit +Databits
;		com	Txbyte		;Inverte everything
;		sec			;Start bit
                clc

putchar0:	brcc	putchar1	;If carry set
         	sbi	ddrb,PB1	;PB1--> Low

		rjmp	putchar2	;else	

putchar1:	cbi	DDRB,PB1	;    send a '1'
		nop

putchar2:	Ldi Delay2,4
		rcall Delay_Xms

		lsr	Txbyte		;Get next bit
		dec	bitcnt		;If not all bit sent
		brne	putchar0	;   send next
					;else


         	sbi	ddrb,PB1	;pin PB1--> low
                Ldi Delay2,8
                Rcall Delay_Xms




		ret			;   return

;************************************************



Delay_Xms :
             
              
Delay_XmsLoop:
;             Rcall Delay_1000Cycles  ;1ms Delay at 1Mhz clock


Delay_1000Cycles:
             Mov Delay1,Clock
             Rcall CycleDelay10
	     Rcall CycleDelay10 

Delay_1000Loop:
             Rcall CycleDelay10
             Dec Delay1
             nop
	     nop
             nop	
             nop
             nop
             nop
             nop
             Brne Delay_1000Loop
             


             Dec Delay2
             Brne Delay_XmsLoop              
             Ret




;Delay_1000Cycles:
;             Ldi Delay1,49
;             Rcall CycleDelay10
;             nop
;             nop
;             nop

;Delay_1000Loop:
;             Rcall CycleDelay10
;             Dec Delay1
;             nop
;	      nop
;             nop	
;             nop
;             nop
;             nop
;             nop
;             Brne Delay_1000Loop
;             Ret



CycleDelay10:
             nop
             nop
             nop
             Ret            ;4 cycles
 
 






;**************************************************************
Delay_50ms :
             Ldi Delay2,49

Delay_50msLoop:
             Rcall Delay_1000Cycles  ;1ms Delay at 1Mhz clock
             Dec Delay2
             Brne Delay_50msLoop   ;49000

             Ldi Delay2,65
 
Delay_50msLoop2:

             Rcall CycleDelay10
             Dec Delay2
             Brne Delay_50msLoop2
             nop

             Ret


OutData : .DB "S","C","E","A","S","C","E","I","S","C","E","E",$00


 
