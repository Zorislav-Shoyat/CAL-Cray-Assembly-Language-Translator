/*****************************************************************************/
/*                                                                           */
/*  The Cray Assembly Language Translator CAL                                */
/*                                                                           */
/*  (c) Zorislav Shoyat, 2014/2015                                           */
/*                                                                           */
/*****************************************************************************/

CAL is a preliminary Cray Assembly Language translator, see CAL.l for more info.

CAL is written to be compatible with the original Cray Assembly Language.

The sad story is that there is in the world no known existing example of the
original CAL translator software, as it is true for (almost) all
Cray-1/Cray-XMP series software, specifically development environment(s). 

The Vitlersoft CAL is a resurection necessary to be able to write again
software for the (FPGA/emulation) resurected Cray-1 processor(s).

At
http://grgur.irb.hr/Cray-E2LP/CAL
there is a version of the Vitlersoft CAL, and in the
'Executables' subdirectory some compiled sources and executables for different
processor/OS combinations are provided.

IMPORTANT:

For reading the Vitlersoft CAL sources use a tabstop of 3
	(in vi/vim ':se ts=3')
 
For reading the CAL Translation Listings use a tabstop of 9 or more
	(':se ts=9')


INSTALLATION:

From Executables:

- Find the appropriate subdirectory for your machine/OS combination in the
CAL/Executables subdirectory.
- Copy the executable file (CAL or CAL.exe, depending on the OS) to an appropriate
location in your $PATH
- For Windows execution (UWIN), it is possible that some of the .dll files
provided at
http://grgur.irb.hr/Virtue/Generic
will be necessary. The Windows system will complain about which file is missing.


From Sources:

To install: type 'make install' (installs in /usr/local/bin)
To compile: type 'make'
Further instructions are in the 'Makefile'

If there are problems with compilation of a specific machine (i.e. no 'cc', but
'gcc', different compilation flags etc.), please see the Makefile. The
"Makefile" shall be changed for individual compilations on different Operating
Systems. The 'makefile.COMMON' generally does not haa to be changed. It is common
to all different possible C compilation environments.

To compile you have to have flex (and C compiler, naturally) installed.

After installing, type 'CAL -h' which will give you the list of options and
arguments to the Cray Assembly Language Translator.

Vitlersoft CAL provides several types of output: the (-o) ViMON -OCTCOD-,
provided for the (in development) ViMON - the Cray-EELP System Monitor / BIOS;
the (-x) ViMON -HEXCOD-; the (-r) Verilog compatible "rom" (hexadecimal, 
beware of the byte, parcel and word order); and the (-l) Listing file.

Attached, in the directory Tests, is the file 'TST.CAL', which contains all
Cray-1 instructions and their translation. Make a 'tst.lst' file
(with '... -l tst.lst...') and compare the results of translation with the 
results in comments.

The CAL Assembly language description from Cray Research can be found at https://bitsavers.org/pdf/cray/CAL/SR-0085_Symbolic_Machine_Instructions_Jan86.pdf. Beware, presently the Vitlersoft CAL does not support
macro-instructions and other advanced Cray Assembly Language features
described in these documents.

General Cray-XMP documentation can be found at https://bitsavers.org/pdf/cray/CRAY_X-MP/

There is also a subdirectory Examples. There are several examples of vector
operations on vectors of integers, reals, complex numbers and quaternions, like
interval, addition, multiplication and division. These examples are actually
derived from operations defined by Virtue verbs SPACE (INTERVAL), ADD, MULTIPLY,
DIVIDE... (see http://grgur.irb.hr/Virtue).

Additionally the file BOOT.CAL is included, which is a preliminary test
for the E2LP Cray-1 implementation, and may be consulted as an example of
Cray Assembly Language Programme. This BOOT.CAL is actually written to boot
up any Cray-1/Cray-XMP compatible computer, however the UART part is specific
to the implementation on the E2LP board.
The TEST.CAL is a short series of tests, and it repeats a shorter text about Cray-1.

The Vitlersoft CAL Translator ERROR reporting on non-recognised constructs
(i.e. non-CAL/Cray-1 combinations, as for example V1 ,A1,1) is very primitive,
and shall be accordingly dealt with.

The ViMON -OCTCOD- is actually standard Cray octal machine translation of the
Assembly language programme, with the addition of several special indicators,
(-OCTCOD-, -ORIGIN-, -ENDCOD-) 
The default output is the OCTAL code.
