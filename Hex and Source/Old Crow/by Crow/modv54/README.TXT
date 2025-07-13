
Files included in this archive:

  MD508V54.ASM -- Source code for 4 *or* 5-wire v5.4 chip for PIC12C508/9
  M508V544.HEX -- Ready-to-use hex object code file for 12C508 *4-WIRE*
  M508V545.HEX -- Ready-to-use hex object code file for 12C508 *5-WIRE*
  M509V544.HEX -- Ready-to-use hex object code file for 12C509 *4-WIRE*
  M509V545.HEX -- Ready-to-use hex object code file for 12C509 *5-WIRE*

  MOD54V54.ASM -- Source code for 6-wire v5.4 chip for PIC16C54
  MOD54V54.HEX -- Ready-to-use hex object code file for 16C54 *6-WIRE*

  MOD84V54.ASM -- Source code for 6-wire v5.4 chip for PIC16F84
  MOD84V54.HEX -- Ready-to-use hex object code file for 16F84 *6-WIRE*

  Quick notes:

  *) Use .HEX files with chip programmer!  (Should be obvious, but...)
  *) Make sure config bits of your chip are properly set!  DO NOT COUNT ON
THE PROGRAMMER TO BE SMART ENOUGH TO DO THIS!  A Microchip PICStart-Plus
*is* capable of doing this.

  Chip type:         Proper Config:
  ----------         --------------
   16C54             WDT=off, OSC=XT, CP=don't care
   16F84             WDT=off, OSC=XT, CP=don't care, MCLRE=OFF
   12C508/9 (5-wire) WDT=off, OSC=XT, CP=don't care, MCLRE=OFF
   12C508/9 (4-wire) WDT=off, OSC=INT_RC, CP=don't care, MCLRE=OFF

  Pay attention when doing 4-wire 12C508!

  *) To use a 12C509, change the following line in the MD508V53.ASM file:

P509    EQU     0

to:

P509    EQU     1

  Then be sure to re-assemble the source file using MPASM.

  *) If you need MPASM, download mpasm.zip from
http://www.aeug.org/~chip/src/mpasm.zip

  *) Command line for assembling a file with MPASM:

MPASM filename

  --don't type the '.ASM'

/**/
