#
# Makefile for the Vitlersoft Cray Assembly Language Translator
#
# Zorislav Shoyat, 24/3/2014, 16:17, Atelier, Shanti (Gu)
#
#    Makefile targets:
#
#       - make: make the objects/executables for the mach/OS combination present
#       - make just_source: clean everything except source files
#       - make distribution: clean all compilation files, except executables
#       - make clean: clean the compilation on present architecture
#       - make install: compile and install in the INSTDIR
#       - make tar: make a tar file in the parent directory, including just
#                   the sources, Examples and Test
#                   ('../CAL.tar') 
#       - make tarit: tar the whole distribution into a gzipped file, including
#                     all Executables and Cray.docs
#
# V1.1 28/3/2014, 12:13, Atelier Shanti
#      added multi-os support
#
# V1.2 21/11/2014, 16:44, Kut Shanti
#      added tar for *.CAL files and Cray.docs
#
# V1.3 27/11/2014, 12:47, Atelier Home & Melior
#      comments and cleanup for distribution
#
# V1.4 4/12/2014, 13:24, Atelier Grgur
#      reorganisation of the directory structure, makefile targets
#
# V1.41 16/1/2015, 14:29, Atelier Grgur
#       changes for make tar
#       added make tarit (see description above(
#

#
# To make and install, type "make install"
#

SYS = Executables/`uname -m`.`uname -s`

#
# INSTDIR - the installation directory. Please change if necessary/required
#
# Official installation directory
INSTDIR = /usr/local/bin
# Possible instalation directory for non-root installation
#INSTDIR = ~/usr/local/bin

#
# SRCDIR - the Sources directory. Do not change, if not reorganising
# the directory structure
#
SRCDIR = Sources

#
# LEX - CAL necessitates flex (on some system called also lex)
#
LEX = flex
#LEX = lex

#
# CC - the C compiler. Any K&R cc will (most probably) do
#    - it is important that the flex/cc combination is compatible, which
#      it generally is whenever installed on machine/OS
# Compilation verified on:
#    - SunOS cc
#    - Solaris SUNWspro cc
#    - gcc
#    - Microsoft C
CC = cc -w
# If the compiler is not called cc, or more than one compiler is installed
#CC = gcc -w

#
# CCFLAGS - compilation flags, may be adapted according to machine/OS
#
# Generally:
CCFLAGS = -O3
# For Sun3 cc: (the -J flag expands computed GOTO range (i.e. switch range))
#CCFLAGS = -O -J
# For SUNWspro cc:
#CCFLAGS = -xO3
# If something goes wrong, use the -g (or -ggdb) flag for dbx/gdb
#CCFLAGS = -g

#
# LDFLAGS - linker flags, may be needed in (rare) occasions
#
LDFLAGS =

#
# LDLIBS - additional preinstalled libraries
# -- CAL needs the lex/flex library
#
# Commonly the library is liblex
LDLIBS = -ll
# On certain machine/OS implementations of flex the library is libflex
#LDLIBS = -lfl

#
# The actual make rules, calling the makefile.COMMON
#  -- The division on Makefile and makefile.COMMON allows more different
#     Makefiles with different flags. The makefile.COMMON has to change only
#     if adding, renaming or deleting sources
#

${INSTDIR}/CAL: ${SRCDIR}/CAL.l ${SRCDIR}/symbols.h ${SRCDIR}/symtab.c
	cd ${SRCDIR}; ${MAKE} -f makefile.COMMON SYS="../${SYS}" CCFLAGS="${CCFLAGS}" LDFLAGS="${LDFLAGS}" LDLIBS="${LDLIBS}" CC="${CC}" LEX="${LEX}" INSTDIR=${INSTDIR} SRCDIR="../${SRCDIR}"

install:
	cd ${SRCDIR}; ${MAKE} -f makefile.COMMON SYS="../${SYS}" CCFLAGS="${CCFLAGS}" LDFLAGS="${LDFLAGS}" LDLIBS="${LDLIBS}" CC="${CC}" LEX="${LEX}" INSTDIR=${INSTDIR} SRCDIR="../${SRCDIR}" install

clean:
	rm -f ${SYS}/*; rm -rf ${SYS}; rm -f *.i; rm -f ${SYS}/*.pdb; rm -f *.pdb

tar:
	cd ..; tar -cf CAL.src.tar CAL/*akefile* CAL/README CAL/${SRCDIR} CAL/Examples CAL/Test

tarit:
	cd ..; rm -f CAL.tar.gz; tar -cf - CAL | gzip > CAL.tar.gz

just_source:
	rm -r Executables/*;		\
	mv Tests/*.CAL /tmp; 	\
	rm Tests/*;					\
	mv /tmp/*.CAL Tests

distribution:
	cd Executables; make.distribution

