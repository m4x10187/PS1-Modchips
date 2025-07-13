

This code works as a Standard 4 wire modchip (3 Wire and Link 7502 - later versions dont 
need the link) and can also be connected in Stealth mode if required



Please note that on Multimode chips Pins 2 and 7 are reversed compared the 
Stealth2.x and REI Stealth chip.

The HEX code contained is universal and should work on 508(a) and 509(a)

Version 1.0 First Release

Version 1.1 added Flawfixing and temperature compensation.

Version 1.2 added Action Replay/ PS Hacker cheat cartridge detection , if a cartridge
	    is detected then chip will send data as a standard mod chip (no Stealth).
	    Version 1.2 can be programmed into a blank chip or into a version 1.1
            chip to upgrade from 1.1 to 1.2 !

Version 1.3 added Stealth mode when used with many Cheat Carts


	    added optional LED display drive on Pin3 , you need to fit a Resistor with the
	    LED to limit current.

	    added chip disable feature , press the reset button for at least 3 seconds and
	    the chip will be totally disabled until you power cycle the machine. (Only Available
	    when the chip is used in 7 wire Mode).

Version 1.4 This is the first version of the no-link code , works the same as
	    Multimode 1.3  but you dont need to fit the link on the 7502/9002 ,
	    instead you simply connect pin 5 to the left hand link point
	    (the furthest link point from Pin6) and pin 1,8,6  etc connect as normal.
	    If you have any problems getting "no-link" mode to work then you can always
	    disconnect Pin 5 and fit the link as before .

Version 1.5 exactly the same as MM1.4 except for the following .....
	    We have had to remove flawfixing/Temp Compensation , We have had to create
	    seperate HEX files for the 3 different regions and we have added the new
	    "Dino Mode".
	    Dino Mode has 10 levels all accessed from the reset button .. press and hold
	    the reset button for at least 3 seconds to enter "Dino Mode1" , press reset again
	    to move to "Dino Mode2" , press again for "Dino Mode3" ...pressing
	    reset 11 times disables the chip until you power cycle the machine.
	    It should be possible to get all Antimod games to play by selecting the
	    correct "Dino Mode" for that game and that Model .. infact if you just connect
	    the normal 4 wires and add the 5th wire for reset this chip should be capable
	    of playing all games BUT "Dino Mode" has only been actually tested on 5 Anti-Mod
	    games so far including of course "Dino Crisis".
	    It's probabily better to connect all 7 wires where "Dino Mode" is currently only
	    required for Dino Crisis ... this way you know that all games will load ...

