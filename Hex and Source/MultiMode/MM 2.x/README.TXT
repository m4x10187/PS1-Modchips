

This code works as a Standard 4 wire modchip (3 Wire and Link 7502 - later versions dont 
need the link) and can also be connected in Stealth mode if required



Please note that on Multimode chips Pins 2 and 7 are reversed compared the 
Stealth2.x and REI Stealth chip.

The HEX code contained is universal and should work on 508(a) and 509(a)

Version 2.0 *****BETA ONLY ***** 15/9/99
	    Total change to Multimode Code ... this code will (hopefully) run all games without
	    the need for "Dino Mode" .. it uses a completely different method to detect when to
	    send the code .. it is still under development and needs much testing.
	    This code is not compatible with PU7 board (Jap SCPH-1000 ) except in 4 wire mode.


Version 2.01
17/9/99 
	    New in Version 2.01 
	    Added Chip disable (Hold reset for 3 seconds)
	    Added Selectable 4 wire mode ( Hold reset for another 3 seconds)
	   
	    Added User Selectable "Dino Modes" (Hold reset for another 3 seconds then each time you press reset 
	    for 1 second then you change "dino Mode" ... 255 modes available BUT only the first 10 or 20 will 
	    work ... this depends on your console ....		

	    Version 2.01 was originally clased as a beta but has proved reliable.


Version 2.02 ****BETA ONLY****** 29/11/99
            New in version 2.02 ... A few people have reported problems with some
	    batches of the 12c50xA chips .. this is because these batches have 
	    slow running oscillators (3.8-3.9Mhz rather than 4Mhz) to fix this we
	    have increased the speed of the code in 2.02 beta ... it has had very 
            limited testing and should really only be used if you have problems 
            with the bad A version chips .... we currently have no information on 
            which batches are affected but they seem to be early 99 chips ..

