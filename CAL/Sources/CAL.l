/****************************************************************************/
/*                                                                          */
/* Vitlersoft CAL - Cray Assembly Language Translator                       */
/*                                                                          */
/* Zorislav Shoyat (c) 2014                                                 */
/*                                                                          */
/* V0.01 22/03/14 15:17 Zagreb, Atelier, Shanti (Gu)                        */
/* V1.00 28/03/14 0:12 Zagreb, Atelier, Shanti (Gu)                         */
/* V1.01 29/03/14 2:33 Zagreb, Atelier, Shanti (Gu)                         */
/* V1.02 30/03/14 16:45 Zagreb, Atelier, Shanti (Gu)                        */
/* V1.03 21/11/14 17:50 Zagreb, Atelier, Shanti (Moby Dick)                 */
/* V1.04 27/11/14 13:01 Zagreb, Atelier, Shanti (Home IRB)                  */
/* V1.04a 16/1/15 18:14 Zagreb, Atelier, Shanti (Home IRB)                  */
/* V1.04b 18/2/15 23:23 Zagreb, Atelier, Gu (Moby Dick)                     */
/* V1.1 25/2/15 4:26 Zagreb, Atelier, Gu                                    */
/* V1.11 27/2/15 7:33 Zagreb, Atelier, Gu                                   */
/* V1.2 2/3/15 21:10 Zagreb, Atelier, Gu                                    */
/* V1.21 3/3/15 12:05 Zagreb, Atelier, Gu                                   */
/* V1.21a 6/3/15 12:18 Zagreb, Atelier, Shanti (Gu)                         */
/*                                                                          */
/****************************************************************************/
/* Developed on Tadpole SparcBook 3GS                                       */
/*    (85Mhz MicroSparc-II, 32Mib RAM, 1.2GiB SCSI internal disk)           */
/****************************************************************************/
/*                                                                          */
/* V1.00 - implemented all Cray-1 instructions, and all major pseudo        */
/*         operations. No expressions are processed yet.                    */
/* V1.01 - A' CON, ENTRY, -x (hex file output) OK                           */
/* V1.01 - DATA                                                             */
/*         !!! symbol shall be expanded to sustain 64 bit values            */
/*         DATA shall be debugged further!                                  */
/* V1.03 - Cleaning up file handling, cleaning up strange behaviour on      */
/*         different Operating Systems, compiling on different OSs/procs    */
/* V1.04 - Found on Linux: double close of 'prn'                            */
/* V1.04a - included < and > in "" for certain flexes                       */
/* V1.04b - ASCII strings were a character too short                        */
/*          Listing slightly changed, the P_counter address is given in     */
/*          front. There is no Line number presently, due to spacing        */
/*          problems in listing.                                            */
/* V1.1 - Cray-XMP instructions added                                       */
/*        Added short descriptions for some instructions                    */
/* V1.11 - Properly aligned ENTRY on 64-parcel boundary                     */
/* V1.2 - EXCHANGE added (place after relevant ENTRY) for the VImon         */
/* V1.21 - EXCHANGE added (place after relevant ENTRY) for the VImon        */
/* V1.21a - PASS                                                            */
/*                                                                          */
/****************************************************************************/

/*                                                                          */
/* DATA: As the smallest addressable unit is a Parcel (two bytes), and the  */
/*       ... ... ...                                                        */


/* Beware:
	the W.*O is usable only in '=' for now. Please be careful when loading
	constant data into addresses that they shall be Word addresses and not
	Parcel addresses! (So use 'CONSTx = W.*O')
*/

%{

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

	int yywrap() {return 1;}

	char * version()
	{
		return ("Vitlersoft CAL\n- Cray Assembly Language Translator -\n\tby Zorislav Shoyat\n\n* V1.04 - 16/1/2015 *\n\n");
	}

#include <strings.h>

#include "symbols.h"

#define TRUE 1
#define FALSE 0
#define NIL (void *)0

	int PC;
	int Pass;
	char List = FALSE;
	char DoList = FALSE;
	char * ListLine = NIL;
	FILE * prn;
	FILE * octfile;
	FILE * hexfile = NIL;
	FILE * romfile = NIL;
	FILE * tempfile = NIL;
	char Piping = TRUE;	/* If no arguments then -i is implied */
	int Line;
#define LAST 2				/* The last pass, presently a 2 pass translator */
	char * Instr;
	char I, J, K;
	int expr;
	unsigned int datum;

	char * Ident = "";
	char * Entry = "";

	symbols * symbol_table;
	symbols * sym;
	symbols * sym1;

	/* Mode and other ENTRY values */
	unsigned char Ex_MM = 0;

	char errorline[256] = "";

	yyinput (buf, result, max_size)
		char buf[];
		int * result;
		int max_size;
   { 
		int c = getc(yyin);	
		/* Eat up separators */	
		if ((c == ' ') || (c == '\t'))	
		{	
			while ((c == ' ') || (c == '\t'))	
			{	
				c = getc(yyin);	
			}	
      	*result = (c == EOF) ? YY_NULL : (buf[0] = ' ', buf[1] = c, 2); 
			if (Piping)	
				fprintf (tempfile, "%c%c", buf[0], buf[1]);	
		}	
		else	
		{
			if (c == '\015')
				c = '\n';
	      *result = (c == EOF) ? YY_NULL : (buf[0] = c, 1); 
			if (Piping)	
				fprintf (tempfile, "%c", buf[0]);	
		}
   }

#define YY_INPUT(buf,result,max_size) yyinput(buf,&result,max_size)
#ifdef NOTYET
#define YY_INPUT(buf,result,max_size) \
   { \
		int c = getc(yyin);	\
		/* Eat up separators */	\
		if ((c == ' ') || (c == '\t'))	\
		{	\
			while ((c == ' ') || (c == '\t'))	\
			{	\
				c = getc(yyin);	\
			}	\
      	result = (c == EOF) ? YY_NULL : (buf[0] = ' ', buf[1] = c, 2); \
		}	\
		else	\
	      result = (c == EOF) ? YY_NULL : (buf[0] = c, 1); \
		if (Piping)	\
			fprintf (tempfile, "%s", result);	\
   }
#endif



	emitn ()
	{
		if (Pass == LAST)
			fprintf (octfile, "\n");
		if (List)
			fprintf (prn,"\n\t\t");
	}

	emit1 (instruction)
		char * instruction;
	{
		if (Pass == LAST)
			fprintf (octfile, "%s\n", instruction);
		if (List)
		{
			if (datum)
				fprintf (prn, "%s\n", instruction);
			else
				fprintf (prn,"%s\t\t%s", instruction, ListLine);
		}
	}

	emit2 (instruction)
		char * instruction;
	{
		if (Pass == LAST)
			fprintf (octfile, "%s\n", instruction);
		if (List)
		{
			if (datum)
				fprintf (prn, "%s\n", instruction);
			else
				fprintf (prn,"%s\t%s", instruction, ListLine);
		}
	}

	emitc (ch)
		char ch;
	{
		if (Pass == LAST)
			fprintf (octfile, "%c",ch);
		if (List)
			fprintf (prn, "%c",ch);
	}

	emit (part)
		char * part;
	{
		if (Pass == LAST)
			fprintf (octfile, "%s", part);
		if (List)
			fprintf (prn, "%s", part);
	}


	emitoct6 (number)
		unsigned int number;
	{
		if (Pass == LAST)
			fprintf (octfile, "%.2o", number & 077);
		if (List)
			fprintf (prn, "%.2o", number & 077);
	}

	emitoct9 (number)
		unsigned int number;
	{
		if (Pass == LAST)
			fprintf (octfile, "%.3o", number & 0777);
		if (List)
			fprintf (prn, "%.3o", number & 0777);
	}

	emitoct16 (number)
		unsigned int number;
	{
		if (Pass == LAST)
			fprintf (octfile, "%.6o", number & 0177777);
		if (List)
			fprintf (prn, "%.6o", number & 0177777);
	}

	emitoct22 (number)
		unsigned int number;
	{
		if (Pass == LAST)
			fprintf (octfile, "%.2o %.6o", (number >> 16) & 077, number & 0177777);
		if (List)
			fprintf (prn, "%.2o %.6o", (number >> 16) & 077, number & 0177777);
	}

	emitoct24 (number)
		unsigned int number;
	{
		if (Pass == LAST)
			fprintf (octfile, "%.3o %.6o", (number >> 16) & 0777, number & 0177777);
		if (List)
			fprintf (prn, "%.3o %.6o", (number >> 16) & 0777, number & 0177777);
	}

	emitoct32 (number)
		unsigned int number;
	{
		if (Pass == LAST)
			fprintf (octfile, "%.6o %.6o", (number >> 16) & 0177777, number & 0177777);
		if (List)
			fprintf (prn, "%.6o %.6o", (number >> 16) & 0177777, number & 0177777);
	}

	emitoct48 (numberh, numberl)
		unsigned int numberh;
		unsigned int numberl;
	{
		if (Pass == LAST)
			fprintf (octfile, "%.6o %.6o %.6o", (numberh >> 16) & 0177777, numberh & 0177777, (numberl >> 16) & 0177777, numberl & 0177777);
		if (List)
			fprintf (prn, "%.6o\n\t\t%.6o %.6o", (numberh >> 16) & 0177777, numberh & 0177777, (numberl >> 16) & 0177777, numberl & 0177777);
	}

	emitoct64 (numberh, numberl)
		unsigned int numberh;
		unsigned int numberl;
	{
		if (Pass == LAST)
			fprintf (octfile, "%.6o %.6o %.6o %.6o", (numberh >> 16) & 0177777, numberh & 0177777, (numberl >> 16) & 0177777, numberl & 0177777);
		if (List)
			fprintf (prn, "%.6o %.6o\n\t\t%.6o %.6o", (numberh >> 16) & 0177777, numberh & 0177777, (numberl >> 16) & 0177777, numberl & 0177777);
	}

	int oct2 (arg, err)
		char * arg;
		char * err;
	{
		unsigned int cc;
		int res = 0;
		for (cc = 0; cc < strlen(arg); cc = cc + 1)
		{
			res = (res << 3) | (arg[cc] & 07);		 /* ' ' results in 0! */
		}
		if (res > 077)
		{
			fprintf (stderr, "Line %d, PC %o: %s > 077!\n", Line, PC, err);
			if (List)
				fprintf (prn, "\n *** Line %d, PC %o: %s > 077!\n", Line, PC, err);
		}
		return res & 077;
	}

	int oct3 (arg, err)
		char * arg;
		char * err;
	{
		unsigned int cc;
		int res = 0;
		for (cc = 0; cc < strlen(arg); cc = cc + 1)
		{
			if (((arg[cc] < '0') || (arg[cc] > '7')) && (arg[cc] != ' '))
				break;
			res = (res << 3) | (arg[cc] & 07);		 /* ' ' results in 0! */
		}
		if (res > 0777)
		{
			fprintf (stderr, "Line %d, PC %o: %s > 0777!\n", Line, PC, err);
			if (List)
				fprintf (prn, "\n *** Line %d, PC %o: %s > 0777!\n", Line, PC, err);
		}
		return res & 0777;
	}

	int oct8 (arg, err)
		char * arg;
		char * err;
	{
		unsigned int cc;
		int res = 0;
		for (cc = 0; cc < strlen(arg); cc = cc + 1)
		{
			if (((arg[cc] < '0') || (arg[cc] > '7')) && (arg[cc] != ' '))
				break;
			res = (res << 3) | (arg[cc] & 07);		 /* ' ' results in 0! */
		}
		if (res > 077777777)
		{
			fprintf (stderr, "Line %d, PC %o: %s > 077777777!\n", Line, PC, err);
			if (List)
				fprintf (prn, "\n *** Line %d, PC %o: %s > 077777777!\n", Line, PC, err);
		}
		return res & 077777777;
	}

	int dec8 (arg, err)
		char * arg;
		char * err;
	{
		unsigned int cc;
		int res = 0;
		for (cc = 0; cc < strlen(arg); cc = cc + 1)
		{
			if (((arg[cc] < '0') || (arg[cc] > '9')) && (arg[cc] != ' '))
				break;
			res = (res * 10) + (arg[cc] & 017);		 /* ' ' results in 0! */
		}
		if (res > 077777777)
		{
			fprintf (stderr, "Line %d, PC %o: %s > 077777777!\n", Line, PC, err);
			if (List)
				fprintf (prn, "\n *** Line %d, PC %o: %s > 077777777!\n", Line, PC, err);
		}
		return res & 077777777;
	}

	void oct22 (arg, exprh, exprl, err)
		char * arg;
		unsigned int * exprh;
		unsigned int * exprl;
		char * err;
	{
		unsigned int resh, resl;
		unsigned int cc;
		resh = 0;
		resl = 0;
		for (cc = 0; cc < strlen(arg); cc = cc + 1)
		{
			if (((arg[cc] < '0') || (arg[cc] > '7')) && (arg[cc] != ' '))
				break;
			if (cc == 10)
				resh = (resl & 004000000000) >> 29;
			else
				if (cc > 10)
					resh = (resh << 3) | ((resl & 034000000000) >> 29);
			resl = (resl << 3) | (arg[cc] & 07);
		}
		* exprh = resh;
		* exprl = resl;
	}

	/* BEWARE: ONLY 32 BIT FOR NOW !!! */
	void dec20 (arg, exprh, exprl, err)
		char * arg;
		unsigned int * exprh;
		unsigned int * exprl;
		char * err;
	{
		unsigned int resh, resl;
		unsigned int cc;
		resh = 0;
		resl = 0;
		for (cc = 0; cc < strlen(arg); cc = cc + 1)
		{
			if (((arg[cc] < '0') || (arg[cc] > '9')) && (arg[cc] != ' '))
				break;
			resl = (resl * 10) + (arg[cc] & 017);		 /* ' ' results in 0! */
		}
		* exprh = resh;
		* exprl = resl;
	}

	void hex16 (arg, exprh, exprl, err)
		char * arg;
		unsigned int * exprh;
		unsigned int * exprl;
		char * err;
	{
		unsigned int resh, resl;
		unsigned int cc;
		resh = 0;
		resl = 0;
		for (cc = 0; cc < strlen(arg); cc = cc + 1)
		{
			if (((arg[cc] < '0') || ((arg[cc] > '9') && (arg[cc] < 'A')) || (arg[cc] > 'F')) && (arg[cc] != ' '))
				break;

			if (arg[cc] >= 'A')
				arg[cc] = arg[cc] - 'A' + '0' + 10;
			if (cc == 8)
				resh = (resl & 0xF0000000) >> 28;
			else
				if (cc > 8)
					resh = (resh << 4) | ((resl & 0xF0000000) >> 28);
			resl = (resl << 4) | (arg[cc] & 0xF);
		}
		* exprh = resh;
		* exprl = resl;
	}


%}

%x	ijkmexpr
%x	jkmexpr
%x	aexpr
%x	sexpr
%x	equal

sep	(" "|"\t")
nl    ("\n"|"\015"|"\n\015"|"\015\n")
sepnl ({sep}|{nl})
eln   ({sep}*{nl}|{comm}{nl})
comm	{sep}+"*".*

/*eln   {sep}+"*"?.*{nl}*/

 /* "_" is defined in CAL as a continuation letter. Not implemented yet */
letr	([A-Z]|[a-z])
symbl	({letr}|"$"|"%"|"@") 
nam   {symbl}({dec1}|{symbl})*
fname ({letr}|".")

oct1	[0|1|2|3|4|5|6|7]
dec1	[0|1|2|3|4|5|6|7|8|9]
hex1	[0|1|2|3|4|5|6|7|8|9|A|B|C|D|E|F]
h		{oct1}
i		{oct1}
j		{oct1}
k		{oct1}

%%
{sep}ERR		{										/* Error exit */
					emit1 ("000000");
					PC = PC + 1;
				}

{sep}ERR{sep}{oct1}+	{
									emit ("000");
									emitoct9 (oct3 (&yytext[5], "ERR exp"));
									emit1 ("");
									PC = PC + 1;
								}

{sep}PASS	{
					emit ("001000");
					PC = PC + 1;
				}

{sep}"CA,A"{j}{sep}A{k}	{
									emit ("0010");
									emit ((yytext[6]=0, &yytext[5]));
									emit1 ((yytext[9]=0, &yytext[8]));
									PC = PC + 1;
								}

{sep}"CL,A"{j}{sep}A{k}	{
									emit ("0011");
									emit ((yytext[6]=0, &yytext[5]));
									emit1 ((yytext[9]=0, &yytext[8]));
									PC = PC + 1;
								}

{sep}"CI,A"{j}		{
							emit ("0012");
							emit ((yytext[6]=0, &yytext[5]));
							emit1 ("0");
							PC = PC + 1;
						}

{sep}"MC,A"{j}		{
							emit ("0012");
							emit ((yytext[6]=0, &yytext[5]));
							emit1 ("1");
							PC = PC + 1;
						}

{sep}XA{sep}0	{
							emit1 ("001300");
							PC = PC + 1;
						}

{sep}XA{sep}A{j}	{
							emit ("0013");
							emit ((yytext[6]=0, &yytext[5]));
							emit1 ("0");
							PC = PC + 1;
						}

{sep}RT{sep}S{j}	{
							emit ("0014");
							emit ((yytext[6]=0, &yytext[5]));
							emit1 ("0");
							PC = PC + 1;
						}

{sep}CLN{sep}0		{
							emit1 ("001403");
						}

{sep}CLN{sep}1		{
							emit1 ("001413");
						}

{sep}CLN{sep}2		{
							emit1 ("001423");
						}

{sep}CLN{sep}3		{
							emit1 ("001433");
						}

{sep}PCI{sep}S{j}	{							/* Enter II register with (Sj) */
							emit ("0014");
							emit ((yytext[6]=0, &yytext[5]));
							emit1 ("4");
							PC = PC + 1;
						}

{sep}CCI		{									/* Clear PCI request */
					emit1 ("001405");
					PC = PC + 1;
				}

{sep}ECI		{									/* Enable PCI request */
					emit1 ("001406");
					PC = PC + 1;
				}

{sep}DCI		{									/* Disable PCI request */
					emit1 ("001407");
					PC = PC + 1;
				}

{sep}VL{sep}A{k}	{
							emit ("0020");
							emit ("0");
							emit1 ((yytext[6]=0, &yytext[5]));
							PC = PC + 1;
						}

{sep}VL{sep}1		{
							emit1 ("002000");
						}

{sep}EFI		{									/* Enable interrupt on FP error */
					emit1 ("002100");
					PC = PC + 1;
				}

{sep}DFI		{									/* Enable interrupt on FP error */
					emit1 ("002200");
					PC = PC + 1;
				}

{sep}ERI		{									/* Enable operand range interrupt */
					emit1 ("002300");
					PC = PC + 1;
				}

{sep}DRI		{									/* Disable operand range interrupt */
					emit1 ("002400");
					PC = PC + 1;
				}

{sep}EBM		{									/* Disable bidirectional memory */
					emit1 ("002500");
					PC = PC + 1;
				}

{sep}DBM		{									/* Enable bidirectional memory */
					emit1 ("002600");
					PC = PC + 1;
				}

{sep}CMR		{									/* Complete memory references */
					emit1 ("002700");
					PC = PC + 1;
				}

{sep}VM{sep}S{j}	{
							emit ("0030");
							emitc (yytext[5]);
							emit1 ("0");
							PC = PC + 1;
						}

{sep}VM{sep}0		{
							emit1 ("003000");
						}

{sep}CIB		{
							/* Special Cray-VI instruction: Clear Instruction Buffers */
							emit1 ("003100");
						}

{sep}SM{j}{k}{sep}1,TS	{					/* Test and set semaphore jk in SM */
							emit ("0034");
							emitc (yytext[3]);
							emitc (yytext[4]);
							emit1 ("");
							PC = PC + 1;
						}

{sep}SM{j}{k}{sep}0	{						/* Clear semaphore jk in SM */
							emit ("0036");
							emitc (yytext[3]);
							emitc (yytext[4]);
							emit1 ("");
							PC = PC + 1;
						}

{sep}SM{j}{k}{sep}1,TS	{					/* Set semaphore jk in SM */
							emit ("0037");
							emitc (yytext[3]);
							emitc (yytext[4]);
							emit1 ("");
							PC = PC + 1;
						}

{sep}EX		{
					emit1 ("004000");
					PC = PC + 1;
				}

{sep}EXIT	{								/* Alternative name */
					emit1 ("004000");
					PC = PC + 1;
				}


{sep}EX{sep}{oct1}+	{
								emit ("004");
								emitoct9 (oct3 (&yytext[4], "EX exp"));
								emit1 ("");
								PC = PC + 1;
							}

{sep}EXIT{sep}{oct1}+	{				/* Alternative name */
								emit ("004");
								emitoct9 (oct3 (&yytext[6], "EX exp"));
								emit1 ("");
								PC = PC + 1;
							}

{sep}J{sep}B{oct1}{oct1}	{
										emit ("0050");
										emit1 ((yytext[6]=0, &yytext[4]));
										PC = PC + 1;
									}

{sep}J	{
				emit("006");
				Instr = strdup (yytext);
				PC = PC + 2;
				BEGIN (ijkmexpr);
			}

{sep}R	{
				emit("007");
				Instr = strdup (yytext);
				PC = PC + 2;
				BEGIN (ijkmexpr);
			}

{sep}JAZ	{
				emit("010");
				Instr = strdup (yytext);
				PC = PC + 2;
				BEGIN (ijkmexpr);
			}

{sep}JAN	{
				emit("011");
				Instr = strdup (yytext);
				PC = PC + 2;
				BEGIN (ijkmexpr);
			}

{sep}JAP	{
				emit("012");
				Instr = strdup (yytext);
				PC = PC + 2;
				BEGIN (ijkmexpr);
			}

{sep}JAM	{
				emit("013");
				Instr = strdup (yytext);
				PC = PC + 2;
				BEGIN (ijkmexpr);
			}

{sep}JSZ	{
				emit("014");
				Instr = strdup (yytext);
				PC = PC + 2;
				BEGIN (ijkmexpr);
			}

{sep}JSN	{
				emit("015");
				Instr = strdup (yytext);
				PC = PC + 2;
				BEGIN (ijkmexpr);
			}

{sep}JSP	{
				emit("016");
				Instr = strdup (yytext);
				PC = PC + 2;
				BEGIN (ijkmexpr);
			}

{sep}JSM	{
				emit("017");
				Instr = strdup (yytext);
				PC = PC + 2;
				BEGIN (ijkmexpr);
			}

<ijkmexpr>{sep}{nam}	{
									/* Here we have to consult the symbol table */
									sym = symtab (symbol_table, strdup (&yytext[1]));
									if ((sym->address == -1) && (Pass == LAST))
									{
										fprintf (stderr, "Line %d, PC %o: ERROR: Symbol '%s' not defined!\n", Line, PC, &yytext[1]);
										if (List)
										fprintf (prn, "\n *** Line %d, PC %o: ERROR: Symbol %s not defined!\n", Line, PC, &yytext[1]);
										expr = 077777777;
									}
									else
										expr = sym->address;
									emitoct24 (expr);
									emit2 ("");
									BEGIN (INITIAL);
								}

<ijkmexpr>{sep}("O'"{oct1}+|{dec1}+)	{
														strcat (Instr, " exp");
														if (yytext[1] == 'O')
															expr = oct8 (&yytext[3], Instr);
														else
															expr = dec8 (&yytext[1], Instr);
														emitoct24 (expr);
														emit2 ("");
														BEGIN (INITIAL);
													}

{sep}A{i}	{
					/* Ai immediate is special due to 3 different instructions */
					I = yytext[2];
					BEGIN(aexpr);
				}

<aexpr>{sep}"#"?"-"?{nam}	{
									/* Here we have to consult the symbol table */
										int cc = 1;
										/* Here we have to consult the symbol table */
										if ((yytext[1] == '#') || (yytext[1] == '-'))
											cc = 2;
										if (yytext[2] == '-')
											cc = 3;
										sym = symtab (symbol_table, strdup (&yytext[cc]));
											if ((sym->address == -1) && (Pass == LAST))
											{
												fprintf (stderr, "Line %d, PC %o: ERROR: Symbol '%s' not defined!\n", Line, PC, &yytext[1]);
												if (List)
													fprintf (prn, "\n *** Line %d, PC %o: ERROR: Symbol %s not defined!\n", Line, PC, &yytext[1]);
												expr = 017777777;
											}
											else
												expr = sym->address;
											if ((sym->pc != -1) && (sym->pc <= PC) && (sym->address <= 077))
											{
												emit ("022");
												emitc (I);
												emitoct6 (expr);
												emit1 ("");
												PC = PC + 1;
												BEGIN (INITIAL);
											}
											else
												if (yytext[1] == '#')
													if (yytext[2] == '-')
														goto Ai_expnm;
													else
														goto Ai_expn;
												else
													if (yytext[1] == '-')
														goto Ai_expm;
													else
														goto Ai_exp;
								}
				
<aexpr>{sep}"#-"("O'"?{oct1}+|D'{dec1}+)	{
														if (yytext[3] == 'D')
															expr = dec8 (&yytext[5], "Ai exp");
														else
															if (yytext[3] == 'O')
																expr = oct8 (&yytext[5], "Ai #exp");
															else
																expr = oct8 (&yytext[3], "Ai #exp");
Ai_expnm:
														if (expr > 37777777) /* negative */
														/* Please CHECK! */
														{
															expr = -expr - 1;
															emit ("021");
															emitc (I);
															emitoct22 (expr);
															emit2 ("");
															PC = PC + 2;
														}
														else
														if (expr > 017777777)
														{
															fprintf (stderr, "Warning: Ai #exp > 017777777\n");
															if (List)
																fprintf (prn, "\n *** Warning: Ai #exp > 017777777\n");
														}
														emit ("020");
														emitc (I);
														emitoct22 (expr-1);
														emit2 ("");
														PC = PC + 2;
														BEGIN (INITIAL);
													}

<aexpr>{sep}"#"("O'"?{oct1}+|D'{dec1}+)	{
														if (yytext[2] == 'D')
															expr = dec8 (&yytext[4], "Ai exp");
														else
															if (yytext[2] == 'O')
																expr = oct8 (&yytext[4], "Ai #exp");
															else
																expr = oct8 (&yytext[2], "Ai #exp");
Ai_expn:
														if (expr > 37777777) /* negative */
														/* Please CHECK! */
														{
															expr = -expr - 1;
															emit ("020");
															emitc (I);
															emitoct22 (expr);
															emit2 ("");
															PC = PC + 2;
														}
														else
														if (expr > 017777777)
														{
															fprintf (stderr, "Warning: Ai #exp > 017777777\n");
															if (List)
																fprintf (prn, "\n *** Warning: Ai #exp > 017777777\n");
														}
														emit ("021");
														emitc (I);
														emitoct22 (expr);
														emit2 ("");
														PC = PC + 2;
														BEGIN (INITIAL);
													}

<aexpr>{sep}"-"("O'"?{oct1}+|D'{dec1}+)	{
														if (yytext[2] == 'D')
															expr = dec8 (&yytext[4], "Ai exp");
														else
															if (yytext[2] == 'O')
																expr = oct8 (&yytext[4], "Ai #exp");
															else
																expr = oct8 (&yytext[2], "Ai #exp");
Ai_expm:
														if (expr > 37777777) /* negative */
														/* Please CHECK! */
														{
															expr = -expr - 1;
															emit ("020");
															emitc (I);
															emitoct22 (expr);
															emit2 ("");
															PC = PC + 2;
														}
														else
														if (expr > 017777777)
														{
															fprintf (stderr, "Warning: Ai #exp > 017777777\n");
															if (List)
																fprintf (prn, "\n *** Warning: Ai #exp > 017777777\n");
														}
														emit ("021");
														emitc (I);
														emitoct22 (expr-1);
														emit2 ("");
														PC = PC + 2;
														BEGIN (INITIAL);
													}

<aexpr>{sep}("O'"?{oct1}+|D'{dec1}+)	{
												if (yytext[1] == 'D')
													expr = dec8 (&yytext[3], "Ai exp");
												else
													if (yytext[1] == 'O')
														expr = oct8 (&yytext[3], "Ai exp");
													else
														expr = oct8 (&yytext[1], "Ai exp");
													if (expr <= 077)
													{
														emit ("022");
														emitc (I);
														emitoct6 (expr);
														emit1 ("");
														PC = PC + 1;
													}
													else
Ai_exp:
														if (expr > 37777777) /* negative */
														/* Please CHECK! */
														{
															expr = -expr - 1;
															emit ("021");
															emitc (I);
															emitoct22 (expr);
															emit2 ("");
															PC = PC + 2;
														}
														else
														{
															if (expr > 017777777)
															{
																fprintf (stderr, "Warning: Ai exp > 017777777\n");
																if (List)
																	fprintf (prn, "\n *** Warning: Ai exp > 017777777\n");
															}
															emit ("020");
															emitc (I);
															emitoct22 (expr);
															emit2 ("");
															PC = PC + 2;
														}
													BEGIN (INITIAL);
												}

{sep}A{i}{sep}S{j}	{
								emit ("023");
								emitc (yytext[2]);
								emitc (yytext[5]);
								emit1 ("0");
								PC = PC + 1;
							}

{sep}A{i}{sep}B{j}{k}	{
									emit ("024");
									emitc (yytext[2]);
									emit1 ((yytext[7] = 0, &yytext[5]));
									PC = PC + 1;
								}

{sep}B{j}{k}{sep}A{i}	{
									emit ("025");
									emitc (yytext[6]);
									emit ((yytext[4] = 0, &yytext[2]));
									emit1 ("");
									PC = PC + 1;
								}

{sep}A{i}{sep}PS{j}	{					/* Population count of (Sj) to Ai */
								emit ("026");
								emitc (yytext[2]);
								emitc (yytext[6]);
								emit1 ("0");
								PC = PC + 1;
							}

{sep}A{i}{sep}QS{j}	{					/* Population count parity of (Sj) to Ai */
								emit ("026");
								emitc (yytext[2]);
								emitc (yytext[6]);
								emit1 ("1");
								PC = PC + 1;
							}

{sep}A{i}{sep}SB{j}	{					/* Transmit (SBj) to Ai */
								emit ("026");
								emitc (yytext[2]);
								emitc (yytext[6]);
								emit1 ("7");
								PC = PC + 1;
							}

{sep}A{i}{sep}ZS{j}	{
								emit ("027");
								emitc (yytext[2]);
								emitc (yytext[6]);
								emit1 ("0");
								PC = PC + 1;
							}

{sep}SB{j}{sep}A{i}	{
								emit ("027");
								emitc (yytext[3]);
								emitc (yytext[6]);
								emit1 ("7");
								PC = PC + 1;
							}

{sep}A{i}{sep}A{j}"+"A{k}	{
									emit ("030");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emitc (yytext[8]);
									emit1 ("");
									PC = PC + 1;
								}

{sep}A{i}{sep}A{k}	{
								emit ("030");
								emitc (yytext[2]);
								emit ("0");
								emitc (yytext[5]);
								emit1 ("");
								PC = PC + 1;
							}

{sep}A{i}{sep}A{j}"+1"	{
									emit ("030");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emit1 ("0");
									PC = PC + 1;
								}

{sep}A{i}{sep}A{j}"-"A{k}	{
									emit ("031");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emitc (yytext[8]);
									emit1 ("");
									PC = PC + 1;
								}

{sep}A{i}{sep}"-1"{sepnl}	{
				/* A {sepnl} is used to distinguish from Ai -1xxx */
				/* beware of possible problems */
										emit ("031");
										emitc (yytext[2]);
										emit1 ("00");
										PC = PC + 1;
									}

{sep}A{i}{sep}"-"A{k}	{
									emit ("031");
									emitc (yytext[2]);
									emit ("0");
									emitc (yytext[6]);
									emit1 ("");
									PC = PC + 1;
								}

{sep}A{i}{sep}A{j}"-1"	{
									emit ("031");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emit1 ("0");
									PC = PC + 1;
								}

{sep}A{i}{sep}A{j}"*"A{k}	{
									emit ("032");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emitc (yytext[8]);
									emit1 ("");
									PC = PC + 1;
								}

{sep}A{i}{sep}"CI"	{
								emit ("033");
								emitc (yytext[2]);
								emit1 ("00");
								PC = PC + 1;
							}

{sep}A{i}{sep}"CA,A"{j}	{
									emit ("033");
									emitc (yytext[2]);
									emitc (yytext[8]);
									emit1 ("0");
									PC = PC + 1;
								}

{sep}A{i}{sep}"CE,A"{j}	{
									emit ("033");
									emitc (yytext[2]);
									emitc (yytext[8]);
									emit1 ("1");
									PC = PC + 1;
								}

{sep}B{k}",A"{i}{sep}0?",""A0"?	{
											emit ("034");
											emitc (yytext[5]);
											emitc ('0');
											emitc (yytext[2]);
											emit1 ("");
											PC = PC + 1;
										}

{sep}B{j}{k}",A"{i}{sep}0?",""A0"?	{
												emit ("034");
												emitc (yytext[6]);
												emit1 ((yytext[4] = 0, &yytext[2]));
												PC = PC + 1;
											}

{sep}","{sep}B{j}{k}",A"{i}	{
											emit ("035");
											emitc (yytext[8]);
											emitc (yytext[4]);
											emitc (yytext[5]);
											emit1 ("");
											PC = PC + 1;
										}

{sep}0?",A0"{sep}B{j}{k}",A"{i}	{
												emit ("035");
												if (yytext[1] == '0')
												{
													emitc (yytext[11]);
													emit1 ((yytext[9] = 0, &yytext[7]));
												}
												else
												{
													emitc (yytext[10]);
													emit1 ((yytext[8] = 0, &yytext[6]));
												}
												PC = PC + 1;
											}

{sep}","{sep}B{k}",A"{i}	{
										emit ("035");
										emitc (yytext[7]);
										emitc ('0');
										emitc (yytext[4]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}0?",A0"{sep}B{k}",A"{i}	{
												emit ("035");
												if (yytext[1] == '0')
												{
													emitc (yytext[10]);
													emitc ('0');
													emitc (yytext[7]);
												}
												else
												{
													emitc (yytext[9]);
													emitc ('0');
													emitc (yytext[6]);
												}
												emit1 ("");
												PC = PC + 1;
											}

{sep}T{j}{k}",A"{i}{sep}0?",""A0"?	{
													emit ("036");
													emitc (yytext[6]);
													emit1 ((yytext[4] = 0, &yytext[2]));
													PC = PC + 1;
												}

{sep}T{k}",A"{i}{sep}0?",""A0"?	{
												emit ("036");
												emitc (yytext[5]);
												emitc ('0');
												emitc (yytext[2]);
												emit1 ("");
												PC = PC + 1;
											}

{sep}","{sep}T{j}{k}",A"{i}	{
											emit ("037");
											emitc (yytext[8]);
											emitc (yytext[4]);
											emitc (yytext[5]);
											emit1 ("");
											PC = PC + 1;
										}

{sep}0?",A0"{sep}T{j}{k}",A"{i}	{
												emit ("037");
												if (yytext[1] == '0')
												{
													emitc (yytext[11]);
													emit1 ((yytext[9] = 0, &yytext[7]));
												}
												else
												{
													emitc (yytext[10]);
													emit1 ((yytext[8] = 0, &yytext[6]));
												}
												PC = PC + 1;
											}

{sep}","{sep}T{k}",A"{i}	{
										emit ("037");
										emitc (yytext[7]);
										emitc ('0');
										emitc (yytext[4]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}0?",A0"{sep}T{k}",A"{i}	{
											emit ("037");
											if (yytext[1] == '0')
											{
												emitc (yytext[10]);
												emitc ('0');
												emitc (yytext[7]);

											}
											else
											{
												emitc (yytext[9]);
												emitc ('0');
												emitc (yytext[6]);
											}
											emit1 ("");
											PC = PC + 1;
										}

{sep}S{i}	{
					/* Si immediate is special due to 2 different instructions */
					I = yytext[2];
					BEGIN(sexpr);
				}

<sexpr>{sep}"#"?"-"?{nam}	{
								int cc = 1;
								/* Here we have to consult the symbol table */
								if ((yytext[1] == '#') || (yytext[1] == '-'))
									cc = 2;
								if (yytext[2] == '-')
									cc = 3;
								sym = symtab (symbol_table, strdup (&yytext[cc]));
								if ((sym->address == -1) && (Pass == LAST))
								{
									fprintf (stderr, "Line %d, PC %o: ERROR: Symbol '%s' not defined!\n", Line, PC, &yytext[1]);
									if (List)
										fprintf (prn, "\n *** Line %d, PC %o: ERROR: Symbol %s not defined!\n", Line, PC, &yytext[1]);
									expr = 017777777;
								}
								else
									expr = sym->address;

								if (yytext[1] == '#')
									if (yytext[2] == '-')
										goto Si_expnm;
									else
										goto Si_expn;
								else
									if (yytext[1] == '-')
										goto Si_expm;
									else
										goto Si_exp;
							}
				
<sexpr>{sep}"#-"("O'"?{oct1}+|D'{dec1}+)	{
														if (yytext[3] == 'D')
															expr = dec8 (&yytext[5], "Si exp");
														else
															if (yytext[3] == 'O')
																expr = oct8 (&yytext[5], "Si exp");
															else
																expr = oct8 (&yytext[3], "Si exp");
Si_expnm:
															if (expr > 017777777)
															{
																fprintf (stderr, "Warning: Si exp > 017777777\n");
																if (List)
																	fprintf (prn, "\n *** Warning: Si exp > 017777777\n");
															}
															if (expr > 37777777) /* negative */
															/* Please CHECK! */
															{
																expr = -expr - 1;
																emit ("041");
																emitc (I);
																emitoct22 (expr);
															}
															else
															{
																emit ("040");
																emitc (I);
																emitoct22 (expr - 1);
															}
															emit2 ("");
															PC = PC + 2;
															BEGIN (INITIAL);
													}

<sexpr>{sep}"#"("O'"?{oct1}+|D'{dec1}+)	{
														if (yytext[2] == 'D')
															expr = dec8 (&yytext[4], "Si exp");
														else
															if (yytext[2] == 'O')
																expr = oct8 (&yytext[4], "Si exp");
															else
																expr = oct8 (&yytext[2], "Si exp");
Si_expn:
															if (expr > 017777777)
															{
																fprintf (stderr, "Warning: Si exp > 017777777\n");
																if (List)
																	fprintf (prn, "\n *** Warning: Si exp > 017777777\n");
															}
															if (expr > 37777777) /* negative */
															/* Please CHECK! */
															{
																expr = -expr - 1;
																emit ("040");
																emitc (I);
																emitoct22 (expr);
															}
															else
															{
																emit ("041");
																emitc (I);
																emitoct22 (expr);
															}
															emit2 ("");
															PC = PC + 2;
															BEGIN (INITIAL);
													}

<sexpr>{sep}"-"("O'"?{oct1}+|D'{dec1}+)	{
														if (yytext[2] == 'D')
															expr = dec8 (&yytext[4], "Si exp");
														else
															if (yytext[2] == 'O')
																expr = oct8 (&yytext[4], "Si exp");
															else
																expr = oct8 (&yytext[2], "Si exp");
Si_expm:
															if (expr > 017777777)
															{
																fprintf (stderr, "Warning: Si exp > 017777777\n");
																if (List)
																	fprintf (prn, "\n *** Warning: Si exp > 017777777\n");
															}
															if (expr > 37777777) /* negative */
															/* Please CHECK! */
															{
																expr = -expr - 1;
																emit ("040");
																emitc (I);
																emitoct22 (expr);
															}
															else
															{
																emit ("041");
																emitc (I);
																emitoct22 (expr - 1);
															}
															emit2 ("");
															PC = PC + 2;
															BEGIN (INITIAL);
													}

<sexpr>{sep}("O'"?{oct1}+|D'{dec1}+)	{
														if (yytext[1] == 'D')
															expr = dec8 (&yytext[3], "Si exp");
														else
															if (yytext[1] == 'O')
																expr = oct8 (&yytext[3], "Si exp");
															else
																expr = oct8 (&yytext[1], "Si exp");
Si_exp:
															if (expr > 017777777)
															{
																fprintf (stderr, "Warning: Si exp > 017777777\n");
																if (List)
																	fprintf (prn, "\n *** Warning: Si exp > 017777777\n");
															}
															if (expr > 37777777) /* negative */
															/* Please CHECK! */
															{
																expr = -expr - 1;
																emit ("041");
																emitc (I);
																emitoct22 (expr);
															}
															else
															{
																emit ("040");
																emitc (I);
																emitoct22 (expr);
															}
															emit2 ("");
															PC = PC + 2;
															BEGIN (INITIAL);
													}

<sexpr>{sep}"<"-?("O'"?{oct1}+|D'{dec1}+)	{
		/* BEWARE: Cray numbers bits from left to right, i.e.
							 bit0 = MSB, bit63 = LSB */

					/* Enter jk 1s from right into Si (relative)
						 Enter 1s to the right of bit jk into Si (absolute bit) */

					/* Indicate absolute bit by prefixing the <expr> with '-' */

															char pos = 2;
															if (yytext[2] == '-')
																pos++;
															if (yytext[pos] == 'D')
																expr = dec8 (&yytext[pos+2], "Si <exp");
															else
																if (yytext[2] == 'O')
																	expr = oct8 (&yytext[pos+2], "Si <exp");
																else
																	expr = oct8 (&yytext[pos], "Si <exp");
															if (expr == 0)
																emit ("043");
															else
																emit ("042");
															emitc (I);
															if (yytext[2] = '-')
																emitoct6 (expr);
															else
																emitoct6 (64 - expr);
															emit1 ("");
															PC = PC + 1;
															BEGIN (INITIAL);
														}

<sexpr>{sep}"#>"("O'"?{oct1}+|D'{dec1}+)	{
					/* Enter jk 0s from left into Si (relative)
						 Enter 0s from left until bit jk into Si (absolute bit) */

															if (yytext[3] == 'D')
																expr = dec8 (&yytext[5], "Si #>exp");
															else
																if (yytext[3] == 'O')
																	expr = oct8 (&yytext[5], "Si #>exp");
																else
																	expr = oct8 (&yytext[3], "Si #>exp");
															if (expr == 0)
																emit ("043");
															else
																emit ("042");
															emitc (I);
															emitoct6 (expr);
															emit1 ("");
															PC = PC + 1;
															BEGIN (INITIAL);
														}


{sep}S{i}{sep}"1"{sepnl}	{
										emit ("042");
										emitc (yytext[2]);
										emit1 ("77");
										PC = PC + 1;
									}

{sep}S{i}{sep}"-1"{sepnl}	{
										emit ("042");
										emitc (yytext[2]);
										emit1 ("00");
										PC = PC + 1;
									}

<sexpr>{sep}">"("O'"?{oct1}+|D'{dec1}+)	{
					/* Enter jk 1s from left into Si (relative)
						 Enter 1s from left until bit jk into Si (absolute bit) */

															if (yytext[2] == 'D')
																expr = dec8 (&yytext[4], "Si >exp");
															else
																if (yytext[2] == 'O')
																	expr = oct8 (&yytext[4], "Si >exp");
																else
																	expr = oct8 (&yytext[2], "Si >exp");
															if (expr == 0)
																emit ("042");
															else
																emit ("043");
															emitc (I);
															emitoct6 (expr);
															emit1 ("");
															PC = PC + 1;
															BEGIN (INITIAL);
														}

<sexpr>{sep}"#<"-?("O'"?{oct1}+|D'{dec1}+)	{
					/* Enter jk 0s from right into Si (relative)
						 Enter 0s to the right of bit jk into Si (absolute bit) */

					/* Indicate absolute bit by prefixing the <expr> with '-' */

															char pos = 3;
															if (yytext[3] == '-')
																pos++;
															if (yytext[pos] == 'D')
																expr = dec8 (&yytext[pos+2], "Si #<exp");
															else
																if (yytext[3] == 'O')
																	expr = oct8 (&yytext[pos+2], "Si #<exp");
																else
																	expr = oct8 (&yytext[pos], "Si #<exp");
															if (expr == 0)
																emit ("042");
															else
																emit ("043");
															emitc (I);
															if (yytext[3] == '-')
																emitoct6 (expr);
															else
																emitoct6 (64 - expr);
															emit1 ("");
															PC = PC + 1;
															BEGIN (INITIAL);
														}

{sep}S{i}{sep}0	{
							emit ("043");
							emitc (yytext[2]);
							emit1 ("00");
							PC = PC + 1;
						}

{sep}S{i}{sep}S{j}&S{k}	{
									emit ("044");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emitc (yytext[8]);
									emit1 ("");
									PC = PC + 1;
								}

{sep}S{i}{sep}S{j}&SB	{
									emit ("044");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emit1 ("0");
									PC = PC + 1;
								}

{sep}S{i}{sep}SB&S{j}	{
									emit ("044");
									emitc (yytext[2]);
									emitc (yytext[8]);
									emit1 ("0");
									PC = PC + 1;
								}

{sep}S{i}{sep}#S{k}&S{j}	{
										emit ("045");
										emitc (yytext[2]);
										emitc (yytext[9]);
										emitc (yytext[6]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}S{i}{sep}#SB&S{j}	{
									emit ("045");
									emitc (yytext[2]);
									emitc (yytext[9]);
									emit1 ("0");
									PC = PC + 1;
								}

{sep}S{i}{sep}S{j}\\S{k}	{
									emit ("046");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emitc (yytext[8]);
									emit1 ("");
									PC = PC + 1;
								}

{sep}S{i}{sep}S{j}\\SB	{
									emit ("046");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emit1 ("0");
									PC = PC + 1;
								}

{sep}S{i}{sep}SB\\S{j}	{
									emit ("046");
									emitc (yytext[2]);
									emitc (yytext[8]);
									emit1 ("0");
									PC = PC + 1;
								}

{sep}S{i}{sep}#S{j}\\S{k}	{
										emit ("047");
										emitc (yytext[2]);
										emitc (yytext[6]);
										emitc (yytext[9]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}S{i}{sep}#S{k}	{
								emit ("047");
								emitc (yytext[2]);
								emit ("0");
								emitc (yytext[6]);
								emit1 ("");
								PC = PC + 1;
							}

{sep}S{i}{sep}#S{j}\\SB	{
									emit ("047");
									emitc (yytext[2]);
									emitc (yytext[6]);
									if (yytext[6] == '0')
										fprintf (stderr, "Line %d, PC %o: Warning, S0 specified, the S%c sign bit will be complemented!\n", Line, PC, yytext[2]);
									emit1 ("0");
									PC = PC + 1;
								}

{sep}S{i}{sep}#SB\\S{j}	{
									emit ("047");
									emitc (yytext[2]);
									emitc (yytext[9]);
									if (yytext[9] == '0')
										fprintf (stderr, "Line %d, PC %o: Warning, S0 specified, the S%c sign bit will be complemented!\n", Line, PC, yytext[2]);
									emit1 ("0");
									PC = PC + 1;
								}

{sep}S{i}{sep}#SB	{
							emit ("047");
							emitc (yytext[2]);
							emit1 ("00");
							PC = PC + 1;
						}

{sep}S{i}{sep}S{j}!S{i}&S{k}	{
											emit ("050");
											emitc (yytext[2]);
											if (yytext[8] != yytext[2])
												fprintf (stderr, "Line %d, PC %o: Warning, Different Si in result and operand, S%c will be used!\n", Line, PC, yytext[2]);
											emitc (yytext[5]);
											emitc (yytext[11]);
											emit1 ("");
											PC = PC + 1;
										}

{sep}S{i}{sep}S{j}!S{i}&SB	{
										emit ("050");
										emitc (yytext[2]);
										if (yytext[8] != yytext[2])
											fprintf (stderr, "Line %d, PC %o: Warning, Different Si in result and operand, S%c will be used!\n", Line, PC, yytext[2]);
										emitc (yytext[5]);
										emit1 ("0");
										PC = PC + 1;
									}

{sep}S{i}{sep}S{j}!S{k}	{
										emit ("051");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[8]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}S{i}{sep}S{k}	{
								emit ("051");
								emitc (yytext[2]);
								emit ("0");
								emitc (yytext[5]);
								emit1 ("");
								PC = PC + 1;
							}

{sep}S{i}{sep}S{j}!SB	{
									emit ("051");
									emitc (yytext[2]);
									if (yytext[5] == '0')
										fprintf (stderr, "Line %d, PC %o: Warning, S0 specified, the sign bit will be entered!\n", Line, PC, yytext[2]);
									emitc (yytext[5]);
									emit1 ("0");
									PC = PC + 1;
								}

{sep}S{i}{sep}SB!S{j}	{
									emit ("051");
									emitc (yytext[2]);
									if (yytext[8] == '0')
										fprintf (stderr, "Line %d, PC %o: Warning, S0 specified, the sign bit will be entered!\n", Line, PC, yytext[2]);
									emitc (yytext[8]);
									emit1 ("0");
									PC = PC + 1;
								}

{sep}S{i}{sep}SB	{
							emit ("051");
							emitc (yytext[2]);
							emit1 ("00");
							PC = PC + 1;
						}

{sep}S{i}{sep}S{i}"<"("O'"?{oct1}+|D'{dec1}+)	{
																	I = yytext[2];
																	if (yytext[7] == 'D')
																		expr = dec8 (&yytext[9], "Si Si<exp");
																	else
																		if (yytext[7] == 'O')
																			expr = oct8 (&yytext[9], "Si Si<exp");
																		else
																			expr = oct8 (&yytext[7], "Si Si<exp");
																	if (expr > 0100)
																	{
																		fprintf (stderr, "Line %d, PC %o: Warning: expr (%o) > 0100. 0100 will be used!\n", Line, PC, I);
																		if (List)
																			fprintf (prn, "\n *** Line %d, PC %o: Warning: expr (%o) > 0100. 0100 will be used!\n", Line, PC, I);
																		expr = 0100;
																	}
																	if (I == '0')
																	{
																		if (expr == 0100)
																			emit ("0530");
																		else
																		{
																			emit ("052");
																			emitc (yytext[5]);
																		}
																	}
																	else
																	{
																		if (expr == 0100)
																			emit ("055");
																		else
																			emit ("054");
																		if (I != yytext[5])
																		{
																			fprintf (stderr, "Line %d, PC %o: Warning, Different Si in result and operand, S%c will be used!\n", Line, PC, I);
																			if (List)
																				fprintf (prn, "\n *** Line %d, PC %o: Warning, Different Si in result and operand, S%c will be used!\n", Line, PC, I);
																		}
																		emitc (I);
																	}
																	emitoct6 (expr);
																	emit1 ("");
																	PC = PC + 1;
																}

{sep}S{i}{sep}S{i}">"("O'"?{oct1}+|D'{dec1}+)	{
																	I = yytext[2];
																	if (yytext[7] == 'D')
																		expr = dec8 (&yytext[9], "Si Si>exp");
																	else
																		if (yytext[7] == 'O')
																			expr = oct8 (&yytext[9], "Si Si>exp");
																		else
																			expr = oct8 (&yytext[7], "Si Si>exp");
																	if (expr > 0100)
																	{
																		fprintf (stderr, "Line %d, PC %o: Warning: expr (%o) > 0100. 0100 will be used!\n", Line, PC, I);
																		if (List)
																			fprintf (prn, "\n *** Line %d, PC %o: Warning: expr (%o) > 0100. 0100 will be used!\n", Line, PC, I);
																		expr = 0100;
																	}
																	if (I == '0')
																	{
																		if (expr == 0)
																			emit ("0520");
																		else
																		{
																			emit ("053");
																			emitc (yytext[5]);
																		}
																	}
																	else
																	{
																		if (expr == 0)
																			emit ("054");
																		else
																			emit ("055");
																		if (I != yytext[5])
																			fprintf (stderr, "Line %d, PC %o: Warning, Different Si in result and operand, S%c will be used!\n", Line, PC, I);
																		emitc (I);
																	}
																	expr = 64 - expr;
																	emitoct6 (expr);
																	emit1 ("");
																	PC = PC + 1;
																}

{sep}S{i}{sep}S{i},S{j}"<A"{k}	{
											emit ("056");
											I = yytext[2];
											if (I != yytext[5])
												fprintf (stderr, "Line %d, PC %o: Warning, Different Si in result and operand, S%c will be used!\n", Line, PC, I);
											emitc (I);
											emitc (yytext[8]);
											emit1 (&yytext[11]);
											PC = PC + 1;
										}

{sep}S{i}{sep}S{i},S{j}"<1"	{
										emit ("056");
										I = yytext[2];
										if (I != yytext[5])
											fprintf (stderr, "Line %d, PC %o: Warning, Different Si in result and operand, S%c will be used!\n", Line, PC, I);
										emitc (I);
										emitc (yytext[8]);
										emit1 ("0");
										PC = PC + 1;
									}

{sep}S{i}{sep}S{i}"<A"{k}	{
									emit ("056");
									I = yytext[2];
									if (I != yytext[5])
										fprintf (stderr, "Line %d, PC %o: Warning, Different Si in result and operand, S%c will be used!\n", Line, PC, I);
									emitc (I);
									emitc ('0');
									emit1 (&yytext[8]);
									PC = PC + 1;
								}

{sep}S{i}{sep}S{j},S{i}>A{k}	{
											emit ("057");
											I = yytext[2];
											if (I != yytext[8])
												fprintf (stderr, "Line %d, PC %o: Warning, Different Si in result and operand, S%c will be used!\n", Line, PC, I);
											emitc (I);
											emitc (yytext[5]);
											emit1 (&yytext[11]);
											PC = PC + 1;
										}

{sep}S{i}{sep}S{j},S{i}>1	{
										emit ("057");
										I = yytext[2];
										if (I != yytext[8])
											fprintf (stderr, "Line %d, PC %o: Warning, Different Si in result and operand, S%c will be used!\n", Line, PC, I);
										emitc (I);
										emitc (yytext[5]);
										emit1 ("0");
										PC = PC + 1;
									}

{sep}S{i}{sep}S{i}>A{k}	{
									emit ("057");
									I = yytext[2];
									if (I != yytext[5])
										fprintf (stderr, "Line %d, PC %o: Warning, Different Si in result and operand, S%c will be used!\n", Line, PC, I);
									emitc (I);
									emitc ('0');
									emit1 (&yytext[8]);
									PC = PC + 1;
								}

{sep}S{i}{sep}S{j}"+S"{k}	{
										emit ("060");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emit1 (&yytext[8]);
										PC = PC + 1;
									}

{sep}S{i}{sep}S{j}-S{k}	{
									emit ("061");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emit1 (&yytext[8]);
									PC = PC + 1;
								}

{sep}S{i}{sep}-S{k}	{
								emit ("061");
								emitc (yytext[2]);
								emitc ('0');
								emit1 (&yytext[6]);
								PC = PC + 1;
							}

{sep}S{i}{sep}S{j}"+FS"{k}	{
										emit ("062");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emit1 (&yytext[9]);
										PC = PC + 1;
									}

{sep}S{i}{sep}"+FS"{k}	{
									emit ("062");
									emitc (yytext[2]);
									emitc ('0');
									emit1 (&yytext[7]);
									PC = PC + 1;
								}

{sep}S{i}{sep}S{j}-FS{k}	{
										emit ("063");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emit1 (&yytext[9]);
										PC = PC + 1;
									}

{sep}S{i}{sep}-FS{k}	{
								emit ("063");
								emitc (yytext[2]);
								emitc ('0');
								emit1 (&yytext[7]);
								PC = PC + 1;
							}

{sep}S{i}{sep}S{j}"*FS"{k}	{
										emit ("064");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emit1 (&yytext[9]);
										PC = PC + 1;
									}

{sep}S{i}{sep}S{j}"*HS"{k}	{
										emit ("065");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emit1 (&yytext[9]);
										PC = PC + 1;
									}

{sep}S{i}{sep}S{j}"*RS"{k}	{
										emit ("066");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emit1 (&yytext[9]);
										PC = PC + 1;
									}

{sep}S{i}{sep}S{j}"*IS"{k}	{
										emit ("067");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emit1 (&yytext[9]);
										PC = PC + 1;
									}

{sep}S{i}{sep}"/HS"{j}	{
									emit ("070");
									emitc (yytext[2]);
									emitc (yytext[7]);
									emit1 ("0");
									PC = PC + 1;
								}

{sep}S{i}{sep}A{k}	{
								emit ("071");
								emitc (yytext[2]);
								emit ("0");
								emit1 (&yytext[5]);
								PC = PC + 1;
							}

{sep}S{i}{sep}"+A"{k}	{
									emit ("071");
									emitc (yytext[2]);
									emit ("1");
									emit1 (&yytext[6]);
									PC = PC + 1;
								}

{sep}S{i}{sep}"+FA"{k}	{
									emit ("071");
									emitc (yytext[2]);
									emit ("2");
									emit1 (&yytext[7]);
									PC = PC + 1;
								}

{sep}S{i}{sep}"0.6"	{
								emit ("071");
								emitc (yytext[2]);
								emit1 ("30");
								PC = PC + 1;
							}

{sep}S{i}{sep}"0.4"	{
								emit ("071");
								emitc (yytext[2]);
								emit1 ("40");
								PC = PC + 1;
							}

{sep}S{i}{sep}"1."	{
								emit ("071");
								emitc (yytext[2]);
								emit1 ("50");
								PC = PC + 1;
							}

{sep}S{i}{sep}"2."	{
								emit ("071");
								emitc (yytext[2]);
								emit1 ("60");
								PC = PC + 1;
							}

{sep}S{i}{sep}"4."	{
								emit ("071");
								emitc (yytext[2]);
								emit1 ("70");
								PC = PC + 1;
							}

{sep}S{i}{sep}RT	{
							emit ("072");
							emitc (yytext[2]);
							emit1 ("00");
							PC = PC + 1;
						}

{sep}S{i}{sep}SM	{
							emit ("072");
							emitc (yytext[2]);
							emit1 ("02");
							PC = PC + 1;
						}

{sep}S{i}{sep}ST{j}	{
							emit ("072");
							emitc (yytext[2]);
							emitc (yytext[6]);
							emit1 ("3");
							PC = PC + 1;
						}

{sep}S{i}{sep}VM	{
							emit ("073");
							emitc (yytext[2]);
							emit1 ("00");
							PC = PC + 1;
						}

{sep}S{i}{sep}SR0	{
							emit ("073");
							emitc (yytext[2]);
							emit1 ("01");
							PC = PC + 1;
						}

{sep}SM{sep}S{i}	{
							emit ("073");
							emitc (yytext[5]);
							emit1 ("02");
							PC = PC + 1;
						}

{sep}ST{j}{sep}S{i}	{
							emit ("073");
							emitc (yytext[6]);
							emitc (yytext[3]);
							emit1 ("");
							PC = PC + 1;
						}

{sep}S{i}{sep}"T."{nam}	{
									char * yt = strdup (&yytext[6]);
									sym = symtab (symbol_table, yt);
									if ((sym->address == -1) && (Pass == LAST))
									{
										fprintf (stderr, "Line %d, PC %o: ERROR: Symbol '%s' not defined!\n", Line, PC, yt);
										if (List)
											fprintf (prn, "\n*** Line %d, PC %o: ERROR: Symbol '%s' not defined!\n", Line, PC, yt);
										expr = 0777;
									}
									else
										expr = sym->address;

									if (expr > 077)
									{
										fprintf (stderr, "Line %d, PC %o: Warning: expression (%o) > 077, taking lower order bits!\n", Line, PC, expr);
										if (List)
											fprintf (prn, "\n*** Line %d, PC %o: Warning: expression (%o) > 077, taking lower order bits!\n", Line, PC, expr);
									}
									emit ("074");
									emitc (yytext[2]);
									emitoct6 (expr & 077);
									emit1 ("");
									PC = PC + 1;
								}

{sep}S{i}{sep}T{k}	{
								emit ("074");
								emitc (yytext[2]);
								emitc ('0');
								emitc (yytext[5]);
								emit1 ("");
								PC = PC + 1;
							}

{sep}S{i}{sep}T{j}{k}	{
									emit ("074");
									emitc (yytext[2]);
									PC = PC + 1;
									emit1 (&yytext[5]);
								}

{sep}"T."{nam}{sep}S{i}	{
									unsigned int cc;
									char * yt = strdup (&yytext[3]);
										/* first find the ' ' */
									for (cc = 1; cc <= strlen(yt); cc++)
										if (yt[cc] == ' ')
											break;
									yt[cc] = 0;

									sym = symtab (symbol_table, yt);
									if ((sym->address == -1) && (Pass == LAST))
									{
										fprintf (stderr, "Line %d, PC %o: ERROR: Symbol '%s' not defined!\n", Line, PC, yt);
										if (List)
											fprintf (prn, "\n *** Line %d, PC %o: ERROR: Symbol '%s' not defined!\n", Line, PC, yt);
										expr = 0777;
									}
									else
										expr = sym->address;

									if (expr > 077)
									{
										fprintf (stderr, "Line %d, PC %o: Warning: expression (%o) > 077, taking lower order bits!\n", Line, PC, expr);
										if (List)
											fprintf (prn, "\n *** Line %d, PC %o: Warning: expression (%o) > 077, taking lower order bits!\n", Line, PC, expr);
									}
									emit ("075");
									emitc (yytext[(strlen(yytext)-1)]);
									emitoct6 (expr & 077);
									emit1 ("");
									PC = PC + 1;
								}

{sep}T{k}{sep}S{i}	{
								emit ("075");
								emitc (yytext[5]);
								emitc ('0');
								emitc (yytext[2]);
								emit1 ("");
								PC = PC + 1;
							}

{sep}T{j}{k}{sep}S{i}	{
									emit ("075");
									emitc (yytext[6]);
									emitc (yytext[2]);
									emitc (yytext[3]);
									emit1 ("");
									PC = PC + 1;
								}

{sep}S{i}{sep}V{j},A{k}	{
									emit ("076");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emit1 (&yytext[8]);
									PC = PC + 1;
								}

{sep}S{i}{sep}V{j},1		{
									emit ("076");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emit1 ("0");
									PC = PC + 1;
								}

{sep}V{i},A{k}{sep}S{j}	{
									emit ("077");
									emitc (yytext[2]);
									emitc (yytext[8]);
									emitc (yytext[5]);
									emit1 ("");
									PC = PC + 1;
								}

{sep}V{i},1{sep}S{j}		{
									emit ("077");
									emitc (yytext[2]);
									emitc (yytext[7]);
									emitc ("0");
									emit1 ("");
									PC = PC + 1;
								}

{sep}V{i},A{k}{sep}0	{
								emit ("077");
								emitc (yytext[2]);
								emitc ('0');
								emitc (yytext[5]);
								emit1 ("");
								PC = PC + 1;
							}

<aexpr>{sep}{nam}(,|,0|,A{h})	{
												unsigned int cc;
												emit ("10");
												if (yytext[strlen(yytext)-2] == 'A')
													emitc (yytext[strlen(yytext)-1]);
												else
													emitc ('0');
												emitc (I);
												/* Here we have to consult the symbol table */
												/* first find the ',' */
												for (cc = 1; cc <= strlen(yytext); cc++)
													if (yytext[cc] == ',')
														break;
												yytext[cc] = 0;
												sym = symtab (symbol_table, strdup (&yytext[1]));
												if ((sym->address == -1) && (Pass == LAST))
												{
													fprintf (stderr, "Line %d, PC %o: ERROR: Symbol '%s' not defined!\n", Line, PC, &yytext[1]);
													if (List)
														fprintf (prn, "\n *** Line %d, PC %o: ERROR: Symbol %s not defined!\n", Line, PC, &yytext[1]);
													expr = 017777777;
												}
												else
													expr = sym->address;
												emitoct22 (expr);
												emit2 ("");
												PC = PC + 2;
												BEGIN (INITIAL);
											}
				
<aexpr>{sep}"-"?("O'"?{oct1}+|D'{dec1}+)","(0|A{h})?	{
																			emit ("10");
																			if (yytext[strlen(yytext)-2] == 'A')
																				emitc (yytext[strlen(yytext)-1]);
																			else
																				emitc ('0');
																			emitc (I);
																			if (yytext[1] == '-')
																				if (yytext[2] == 'D')
																					expr = - dec8 (&yytext[4], "Ai exp,");
																				else
																					if (yytext[2] == 'O')
																						expr = - oct8 (&yytext[4], "Ai exp,");
																					else
																						expr = - oct8 (&yytext[2], "Ai exp,");
																			else
																				if (yytext[1] == 'D')
																					expr = dec8 (&yytext[3], "Ai exp,");
																				else
																					if (yytext[1] == 'O')
																						expr = oct8 (&yytext[3], "Ai exp,");
																					else
																						expr = oct8 (&yytext[1], "Ai exp,");
																			emitoct22 (expr);
																			emit2 ("");
																			PC = PC + 2;
																			BEGIN (INITIAL);
																		}

{sep}A{i}{sep}",A"{h}	{
									emit ("10");
									emitc (yytext[6]);
									emitc (yytext[2]);
									emitoct22 (0);
									emit2 ("");
									PC = PC + 2;
								}


{sep}{nam}(,|,0|,A{h}){sep}A{i}	{
													unsigned int cc;
													emit ("11");
													if (yytext[strlen(yytext)-5] == 'A')
														emitc (yytext[strlen(yytext)-4]);
													else
														emitc ('0');
													emitc (yytext[strlen(yytext)-1]);
													/* Here we have to consult the symbol table */
													/* first find the ',' */
													for (cc = 1; cc <= strlen(yytext); cc++)
														if (yytext[cc] == ',')
															break;
													yytext[cc] = 0;
													sym = symtab (symbol_table, strdup (&yytext[1]));
													if ((sym->address == -1) && (Pass == LAST))
													{
														fprintf (stderr, "Line %d, PC %o: ERROR: Symbol '%s' not defined!\n", Line, PC, &yytext[1]);
														if (List)
															fprintf (prn, "\n *** Line %d, PC %o: ERROR: Symbol %s not defined!\n", Line, PC, &yytext[1]);
														expr = 017777777;
													}
													else
														expr = sym->address;
													emitoct22 (expr);
													emit2 ("");
													PC = PC + 2;
												}

{sep}"-"?("O'"?{oct1}+|D'{dec1}+)","(0|A{h})?{sep}A{i}	{
																				emit ("11");
																				if (yytext[strlen(yytext)-5] == 'A')
																					emitc (yytext[strlen(yytext)-4]);
																				else
																					emitc ('0');
																				emitc (yytext[strlen(yytext)-1]);
																				if (yytext[1] == '-')
																					if (yytext[2] == 'D')
																						expr = - dec8 (&yytext[4], "Ai exp,");
																					else
																						if (yytext[2] == 'O')
																							expr = - oct8 (&yytext[4], "Ai exp,");
																						else
																							expr = - oct8 (&yytext[2], "Ai exp,");
																				else
																					if (yytext[1] == 'D')
																						expr = dec8 (&yytext[3], "Ai exp,");
																					else
																						if (yytext[1] == 'O')
																							expr = oct8 (&yytext[3], "Ai exp,");
																						else
																							expr = oct8 (&yytext[1], "Ai exp,");
																				emitoct22 (expr);
																				emit2 ("");
																				PC = PC + 2;
																				BEGIN (INITIAL);
																			}

<sexpr>{sep}{nam}(,|,0|,A{h})	{
												unsigned int cc;
												emit ("12");
												if (yytext[strlen(yytext)-2] == 'A')
													emitc (yytext[strlen(yytext)-1]);
												else
													emitc ('0');
												emitc (I);
												/* Here we have to consult the symbol table */
												/* first find the ',' */
												for (cc = 1; cc <= strlen(yytext); cc++)
													if (yytext[cc] == ',')
														break;
												yytext[cc] = 0;
												sym = symtab (symbol_table, strdup (&yytext[1]));
												if ((sym->address == -1) && (Pass == LAST))
												{
													fprintf (stderr, "Line %d, PC %o: ERROR: Symbol '%s' not defined!\n", Line, PC, &yytext[1]);
													if (List)
														fprintf (prn, "\n *** Line %d, PC %o: ERROR: Symbol %s not defined!\n", Line, PC, &yytext[1]);
													expr = 017777777;
												}
												else
													expr = sym->address;
												emitoct22 (expr);
												emit2 ("");
												PC = PC + 2;
												BEGIN (INITIAL);
											}
				
<sexpr>{sep}"-"?("O'"?{oct1}+|D'{dec1}+)","(0|A{h})?	{
																			emit ("12");
																			if (yytext[strlen(yytext)-2] == 'A')
																				emitc (yytext[strlen(yytext)-1]);
																			else
																				emitc ('0');
																			emitc (I);
																			if (yytext[1] == '-')
																				if (yytext[2] == 'D')
																					expr = - dec8 (&yytext[4], "Ai exp,");
																				else
																					if (yytext[2] == 'O')
																						expr = - oct8 (&yytext[4], "Ai exp,");
																					else
																						expr = - oct8 (&yytext[2], "Ai exp,");
																			else
																				if (yytext[1] == 'D')
																					expr = dec8 (&yytext[3], "Ai exp,");
																				else
																					if (yytext[1] == 'O')
																						expr = oct8 (&yytext[3], "Ai exp,");
																					else
																						expr = oct8 (&yytext[1], "Ai exp,");
																			emitoct22 (expr);
																			emit2 ("");
																			PC = PC + 2;
																			BEGIN (INITIAL);
																		}

{sep}S{i}{sep}",A"{h}	{
									emit ("12");
									emitc (yytext[6]);
									emitc (yytext[2]);
									emitoct22 (0);
									emit2 ("");
									PC = PC + 2;
								}

{sep}{nam}(,|,0|,A{h}){sep}S{i}	{
													unsigned int cc;
													emit ("13");
													if (yytext[strlen(yytext)-5] == 'A')
														emitc (yytext[strlen(yytext)-4]);
													else
														emitc ('0');
													emitc (yytext[strlen(yytext)-1]);
													/* Here we have to consult the symbol table */
													/* first find the ',' */
													for (cc = 1; cc <= strlen(yytext); cc++)
														if (yytext[cc] == ',')
															break;
													yytext[cc] = 0;
													sym = symtab (symbol_table, strdup (&yytext[1]));
													if ((sym->address == -1) && (Pass == LAST))
													{
														fprintf (stderr, "Line %d, PC %o: ERROR: Symbol '%s' not defined!\n", Line, PC, &yytext[1]);
														if (List)
															fprintf (prn, "\n *** Line %d, PC %o: ERROR: Symbol %s not defined!\n", Line, PC, &yytext[1]);
														expr = 017777777;
													}
													else
														expr = sym->address;
													emitoct22 (expr);
													emit2 ("");
													PC = PC + 2;
												}

{sep}"-"?("O'"?{oct1}+|D'{dec1}+)","(0|A{h})?{sep}S{i}	{
																				emit ("13");
																				if (yytext[strlen(yytext)-5] == 'A')
																					emitc (yytext[strlen(yytext)-4]);
																				else
																					emitc ('0');
																				emitc (yytext[strlen(yytext)-1]);
																				if (yytext[1] == '-')
																					if (yytext[2] == 'D')
																						expr = - dec8 (&yytext[4], "Ai exp,");
																					else
																						if (yytext[2] == 'O')
																						expr = - oct8 (&yytext[4], "Ai exp,");
																						else
																							expr = - oct8 (&yytext[2], "Ai exp,");
																				else
																					if (yytext[1] == 'D')
																						expr = dec8 (&yytext[3], "Ai exp,");
																					else
																						if (yytext[1] == 'O')
																							expr = oct8 (&yytext[3], "Ai exp,");
																						else
																							expr = oct8 (&yytext[1], "Ai exp,");
																				emitoct22 (expr);
																				emit2 ("");
																				PC = PC + 2;
																				BEGIN (INITIAL);
																			}

{sep}V{i}{sep}S{j}&V{k}	{
									emit ("140");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emitc (yytext[8]);
									emit1 ("");
									PC = PC + 1;
								}

{sep}V{i}{sep}0	{
							emit("140");
							emitc (yytext[2]);
							emit1 ("00");
							PC = PC + 1;
						}

{sep}V{i}{sep}V{j}&V{k}	{
									emit ("141");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emitc (yytext[8]);
									emit1 ("");
									PC = PC + 1;
								}

{sep}V{i}{sep}S{j}!V{k}	{
									emit ("142");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emitc (yytext[8]);
									emit1 ("");
									PC = PC + 1;
								}

{sep}V{i}{sep}V{k}	{
								emit ("142");
								emitc (yytext[2]);
								emitc ('0');
								emitc (yytext[5]);
								emit1 ("");
								PC = PC + 1;
							}

{sep}V{i}{sep}V{j}!V{k}	{
									emit ("143");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emitc (yytext[8]);
									emit1 ("");
									PC = PC + 1;
								}

{sep}V{i}{sep}S{j}\\V{k}	{
										emit ("144");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[8]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}V{j}\\V{k}	{
										emit ("145");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[8]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}0	{
							emit ("145");
							emitc (yytext[2]);
							emitc (yytext[2]);
							emitc (yytext[2]);
							emit1 ("");
							PC = PC + 1;
						}

{sep}V{i}{sep}S{j}!V{k}&VM	{
										emit ("146");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[8]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}#VM&V{k} {
									emit ("146");
									emitc (yytext[2]);
									emitc ('0');
									emitc (yytext[9]);
									emit1 ("");
									PC = PC + 1;
								}

{sep}V{i}{sep}V{j}!V{k}&VM {
										emit ("147");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[8]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}V{j}"<A"{k}	{
										emit ("150");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[8]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}V{j}"<1"	{
								emit ("150");
								emitc (yytext[2]);
								emitc (yytext[5]);
								emit1 ("0");
								PC = PC + 1;
							}

{sep}V{i}{sep}V{j}>A{k}	{
										emit ("151");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[8]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}V{j}>1	{
								emit ("151");
								emitc (yytext[2]);
								emitc (yytext[5]);
								emit1 ("0");
								PC = PC + 1;
							}

{sep}V{i}{sep}V{j},V{j}"<A"{k}	{
											emit ("152");
											emitc (yytext[2]);
											emitc (yytext[5]);
											if (yytext[5] != yytext[8])
											{
												fprintf (stderr, "Line %d, PC %o: Warning: Vj != Vj, %c will be used!\n", Line, PC, yytext[5]);
												if (List)
													fprintf (prn, "\n *** Line %d, PC %o: Warning: Vj != Vj, %c will be used!\n", Line, PC, yytext[5]);
											}
											emitc (yytext[11]);
											emit1 ("");
											PC = PC + 1;
										}

{sep}V{i}{sep}V{j},V{j}"<1"	{
										emit ("152");
										emitc (yytext[2]);
										emitc (yytext[5]);
										if (yytext[5] != yytext[8])
										{
											fprintf (stderr, "Line %d, PC %o: Warning: Vj != Vj, %c will be used!\n", Line, PC, yytext[5]);
											if (List)
												fprintf (prn, "\n *** Line %d, PC %o: Warning: Vj != Vj, %c will be used!\n", Line, PC, yytext[5]);
										}
										emit1 ("0");
										PC = PC + 1;
									}

{sep}V{i}{sep}V{j},V{j}>A{k}	{
											emit ("153");
											emitc (yytext[2]);
											emitc (yytext[5]);
											if (yytext[5] != yytext[8])
											{
												fprintf (stderr, "Line %d, PC %o: Warning: Vj != Vj, %c will be used!\n", Line, PC, yytext[5]);
												if (List)
													fprintf (prn, "\n *** Line %d, PC %o: Warning: Vj != Vj, %c will be used!\n", Line, PC, yytext[5]);
											}
											emitc (yytext[11]);
											emit1 ("");
											PC = PC + 1;
										}

{sep}V{i}{sep}V{j},V{j}>1	{
										emit ("153");
										emitc (yytext[2]);
										emitc (yytext[5]);
										if (yytext[5] != yytext[8])
										{
											fprintf (stderr, "Line %d, PC %o: Warning: Vj != Vj, %c will be used!\n", Line, PC, yytext[5]);
											if (List)
												fprintf (prn, "\n *** Line %d, PC %o: Warning: Vj != Vj, %c will be used!\n", Line, PC, yytext[5]);
										}
										emit1 ("0");
										PC = PC + 1;
									}

{sep}V{i}{sep}S{j}"+"V{k}	{
										emit ("154");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[8]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}V{j}"+"V{k}	{
										emit ("155");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[8]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}S{j}-V{k}	{
									emit ("156");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emitc (yytext[8]);
									emit1 ("");
									PC = PC + 1;
								}

{sep}V{i}{sep}-V{k}	{
								emit ("156");
								emitc (yytext[2]);
								emitc ('0');
								emitc (yytext[6]);
								emit1 ("");
								PC = PC + 1;
							}

{sep}V{i}{sep}V{j}-V{k}	{
									emit ("157");
									emitc (yytext[2]);
									emitc (yytext[5]);
									emitc (yytext[8]);
									emit1 ("");
									PC = PC + 1;
								}

{sep}V{i}{sep}S{j}"*FV"{k}	{
										emit ("160");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[9]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}V{j}"*FV"{k}	{
										emit ("161");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[9]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}S{j}"*HV"{k}	{
										emit ("162");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[9]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}V{j}"*HV"{k}	{
										emit ("163");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[9]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}S{j}"*RV"{k}	{
										emit ("164");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[9]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}V{j}"*RV"{k}	{
										emit ("165");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[9]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}S{j}"*IV"{k}	{
										emit ("166");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[9]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}V{j}"*IV"{k}	{
										emit ("167");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[9]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}S{j}"+FV"{k}	{
										emit ("170");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[9]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}"+FV"{k}	{
								emit ("170");
								emitc (yytext[2]);
								emitc ('0');
								emitc (yytext[7]);
								emit1 ("");
								PC = PC + 1;
							}

{sep}V{i}{sep}V{j}"+FV"{k}	{
										emit ("171");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[9]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}S{j}-FV{k}	{
										emit ("172");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[9]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}-FV{k}	{
								emit ("172");
								emitc (yytext[2]);
								emitc ('0');
								emitc (yytext[7]);
								emit1 ("");
								PC = PC + 1;
							}

{sep}V{i}{sep}V{j}-FV{k}	{
										emit ("173");
										emitc (yytext[2]);
										emitc (yytext[5]);
										emitc (yytext[9]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep}"/HV"{j}	{
								emit ("174");
								emitc (yytext[2]);
								emitc (yytext[7]);
								emit1 ("0");
								PC = PC + 1;
							}

{sep}V{i}{sep}PV{j}	{						/* Population count of (Vj) to Vi */
								emit ("174");
								emitc (yytext[2]);
								emitc (yytext[7]);
								emit1 ("1");
								PC = PC + 1;
							}

{sep}V{i}{sep}Qv{j}	{						/* Population count parities (Vj) to Vi*/
								emit ("174");
								emitc (yytext[2]);
								emitc (yytext[7]);
								emit1 ("2");
								PC = PC + 1;
							}

{sep}VM{sep}V{j},Z	{
								emit ("1750");
								emitc (yytext[5]);
								emit1 ("0");
								PC = PC + 1;
							}

{sep}VM{sep}V{j},N	{
								emit ("1750");
								emitc (yytext[5]);
								emit1 ("1");
								PC = PC + 1;
							}

{sep}VM{sep}V{j},P	{
								emit ("1750");
								emitc (yytext[5]);
								emit1 ("2");
								PC = PC + 1;
							}

{sep}VM{sep}V{j},M	{
								emit ("1750");
								emitc (yytext[5]);
								emit1 ("3");
								PC = PC + 1;
							}

{sep}V{i},VM{sep}V{j},Z	{	/* VM=1 and (Vi) element index of V{j} if 0 */
								emit ("175");
								emitc (yytext[2]);
								emitc (yytext[8]);
								emit1 ("4");
								PC = PC + 1;
							}

{sep}V{i},VM{sep}V{j},N	{	/* VM=1 and (Vi) element index of V{j} if not 0 */
								emit ("175");
								emitc (yytext[2]);
								emitc (yytext[8]);
								emit1 ("5");
								PC = PC + 1;
							}

{sep}V{i},VM{sep}V{j},P	{	/* VM=1 and (Vi) element index of V{j} if positive */
								emit ("175");
								emitc (yytext[2]);
								emitc (yytext[8]);
								emit1 ("6");
								PC = PC + 1;
							}

{sep}V{i},VM{sep}V{j},M	{	/* VM=1 and (Vi) element index of V{j} negative */
								emit ("175");
								emitc (yytext[2]);
								emitc (yytext[8]);
								emit1 ("7");
								PC = PC + 1;
							}

{sep}V{i}{sep},(A0)?,A{k}	{
										emit ("176");
										emitc (yytext[2]);
										emitc ('0');
										emitc (yytext[strlen(yytext)-1]);
										emit1 ("");
										PC = PC + 1;
									}

{sep}V{i}{sep},(A0)?,1	{
									emit ("176");
									emitc (yytext[2]);
									emit1 ("00");
									PC = PC + 1;
								}

{sep}V{i}{sep},(A0)?,V{k}	{
										emit ("176");
										emitc (yytext[2]);
										emitc ('1');
										emitc (yytext[strlen(yytext)-1]);
										emit1 ("");
										PC = PC + 1;
									}

{sep},(A0)?,A{k}{sep}V{j}	{
										emit ("1770");
										emitc (yytext[strlen(yytext) - 1]);
										emitc (yytext[strlen(yytext) - 4]);
										emit1 ("");
										PC = PC + 1;
									}

{sep},(A0)?,1{sep}V{j}	{
										emit ("1770");
										emitc (yytext[strlen(yytext) - 1]);
										emit1 ("0");
										PC = PC + 1;
									}

{sep},(A0)?,V{k}{sep}V{j}	{
										emit ("1771");
										emitc (yytext[strlen(yytext) - 1]);
										emitc (yytext[strlen(yytext) - 4]);
										emit1 ("0");
										PC = PC + 1;
									}

{sep}EXCHANGE	{
						emit ("-XCHPKG-");
						emitn ();
						emitoct64 (0, PC+16);
						emitn();

						if (List)
							fprintf (prn,"\t\t%s", ListLine);
					}

{sep}ENTRY{sep}{nam}(",M")*	{
	/* Set up the Exchange package:

		ENTRY <name>

		later we will add all the necessary fields.
	*/
								unsigned int exprh;
								unsigned int exprl;
								int pc;

								/* The Monitor Mode Flag */
								if (yytext[strlen(yytext)- 1] == 'M')
								{
									Ex_MM = 1;
									yytext[strlen(yytext) - 2] = (char) 0;
								}
								else
									Ex_MM = 0;

								exprh = 0;
								exprl = 0;
								pc = PC;
								sym1 = symtab (symbol_table, strdup (&yytext[7]));
								PC = (PC + 3) & (~ 03);
								pc = PC - pc;
								if (pc == 3)
									emitoct48 (0,0);
								else
									if (pc == 2)
										emitoct32 (0);
									else
										if (pc == 1)
											emitoct16 (0);
								if (pc > 0)
								{
										emitn();
								}
								pc = PC;
								PC = (PC + 63) & (~ 63); /* Must be on 16 word boundary */
								pc = PC - pc;
								while (pc)
									{
										emitoct64 (0,0);
										pc = pc - 4;
										emitn();
									}
								emitn();
								if (sym)
								{
									sym->address = PC / 4; /* Word address for START */
									sym->pc = PC;
								}
/* Exchange Package positions */
/* According to 2240004 - Cray-1 */


/* Word 0 */
#define EX1_E	(64 - 2)		/* Error type */
#define EX1_S	(64 - 10)		/* Syndrome bits */
#define EX1_R	(64 - 12)		/* Read mode */
#define EX1_B	(64 - 16)		/* Bank */
#define EX1_P	(64 - 40)		/* Program Address register */

/* Word 1 */
#define EX1_RA	(64 - 16)	/* Read address for error (Bank = EX_B) */
#define EX1_BA	(64 - 36)	/* Base Address */

/* Word 2 */
#define EX1_LA	(64 - 36)	/* Limit Address */
#define EX1_M	(64 - 40)		/* Mode */

/* Word 3 */
#define EX1_XA	(64 - 24)	/* Exchange address */
#define EX1_VL	(64 - 31)	/* Vector length */
#define EX1_F	(64 - 40)		/* Flags */

/* According to HR-0097 - Cray-XMP */

/* Word 0 */
#define EX_PN	(64 - 2)		/* Processor number */
#define EX_E	(64 - 4)		/* Error type */
#define EX_S	(64 - 12)		/* Syndrome bits */
#define EX_P	EX1_P			/* Program Address register */

/* Word 1 */
#define EX_R	(64 - 2)		/* Read Mode */
#define EX_CS	(64 - 6)		/* Read Address (with EX_B) */
#define EX_B	(64 - 12)		/* Read Adress (with EX_CS) */
#define EX_IBA	(64 - 34)	/* Instruction Base Address */
#define EX_M1	(64 - 40)	/* Mode (part 1) */

/* Word 2 */
#define EX_VNU	(64 - 1)		/* Vector not used */
#define EX_ILA	(64 - 34)	/* Instruction Limit Address */
#define EX_M	EX1_M			/* Mode (part 2) */

/* Word 3 */
#define EX_ESVL (64 - 1)	/* Enable Second Vector Logical */
#define EX_F1	(64 - 16)	/* Flags (part 1) */
#define EX_XA	EX1_XA		/* Exchange Address */
#define EX_VL	EX1_VL		/* Vector Length */
#define EX_F	EX1_F		/* Flags (part 2) */

/* Word 4 */
#define EX_EAM	(64 - 1)		/* Enhanced Addressing Mode */
#define EX_DBA (64 - 34)	/* Daba Base Address */
#define EX_PS	(64 - 35)	/* Processor State */
#define EX_CLN	(64 - 38)	/* Cluster Number */

/* Word 5 */
#define EX_DLA (64 - 34)

/* Cray-1/XMP */
/* Words 0 - 7 */
#define EX_Ax (64 - 64)

/* Words 8 - 15 */
#define EX_Sx (64 - 64)

/* IMPORTANT: For now we allow all programmes to execute in full range (ILA, DLA).
	A MONITOR/EXECUTIVE shall do the real assignments! */

#define Ex_ILA 0xFFFFFF
#define Ex_DLA 0xFFFFFF

									/* Word 0 */
								exprh = 0 << (EX_PN - 32);
								exprh |= 0 << (EX_E - 32);
								exprh |= 0 << (EX_S - 32);
								exprh |= sym1->address >> (32 - EX_P);
								exprl = sym1->address << EX_P;
								exprl |= 0 << EX_Ax;
								emitoct64 (exprh, exprl);
								emitn();

									/* Word 1 */
								exprh = 0 << (EX_R - 32);
								exprh |= 0 << (EX_CS - 32);
								exprh |= 0 << (EX_B - 32);
								exprh |= 0 >> (32 - EX_IBA);
								exprl = 0 << EX_IBA;
								exprl |= 0 << EX_M1;
								exprl |= 0 << EX_Ax;
								emitoct64 (exprh, exprl);
								emitn();

									/* Word 2 */
								exprh = 0 << (EX_VNU - 32);
								exprh |= Ex_ILA >> (32 - EX_ILA);
								exprl = Ex_ILA << EX_ILA;
								exprl |= Ex_MM << (EX_M);
								exprl |= 0 << EX_Ax;
								emitoct64 (exprh, exprl);
								emitn();

									/* Word 3 */
								exprh = 0 << (EX_ESVL - 32);
								exprh |= 0 << (EX_F1 - 32);
								exprh |= 0 << (EX_XA - 32);
								exprh |= 0 << (EX_VL - 32);
								exprh |= 0 >> (32 - EX_F);
								exprl = 0 << EX_F;
								exprl |= 0 << EX_Ax;
								emitoct64 (exprh, exprl);
								emitn();

									/* Word 4 */
								exprh = 0 << (EX_EAM - 32);
								exprh |= 0 >> (32 - EX_IBA);
								exprl = 0 << EX_ILA;
								exprl |= 0 << EX_PS;
								exprl |= 0 << EX_CLN;
								exprl |= 0 << EX_Ax;
								emitoct64 (exprh, exprl);
								emitn();

									/* Word 5 */
								exprh = Ex_DLA >> (32 - EX_DLA);
								exprl = Ex_DLA << EX_DLA;
								exprl |= 0 << EX_Ax;
								emitoct64 (exprh, exprl);
								emitn();


								/* For now just emit empty all the rest */

									/* Word 6 */
								emitoct64 (0,0);
								emitn();

									/* Word 7 */
								emitoct64 (0,0);
								emitn();

									/* Word 8 */
								emitoct64 (0,0);
								emitn();

									/* Word 9 */
								emitoct64 (0,0);
								emitn();

									/* Word 10 */
								emitoct64 (0,0);
								emitn();

									/* Word 11 */
								emitoct64 (0,0);
								emitn();

									/* Word 12 */
								emitoct64 (0,0);
								emitn();

									/* Word 13 */
								emitoct64 (0,0);
								emitn();

									/* Word 14 */
								emitoct64 (0,0);
								emitn();

									/* Word 15 */
								emitoct64 (0,0);

								emit2 ("");
								PC = PC + 16 * 4;

							}

{sep}ALIGN	{
					int pc = PC;
					PC = (PC + 3) & (~ 03);
					pc = PC - pc;
					if (pc == 3)
					{
						emitoct48 (0,0);
						emit2 ("");
					}
					else
						if (pc == 2)
						{
							emitoct32 (0);
							emit2 ("");
						}
						else
							if (pc == 1)
							{
								emitoct16 (0);
								emit1 ("");
							}
					if (sym)
					{
						sym->address = PC;
						sym->pc = PC;
					}
/*					if (List)
						fprintf (prn,"\t\t%s", ListLine);
*/				}

{sep}BSS(Z)?{sep}{nam}	{
								int pc = PC;
								if (yytext[4] == 'Z')
									sym1 = symtab (symbol_table, strdup (&yytext[6]));
								else
									sym1 = symtab (symbol_table, strdup (&yytext[5]));
								if ((sym1->address == -1) && (Pass == LAST))
								{
									fprintf (stderr, "Line %d, PC %o: ERROR: Symbol '%s' not defined!\n", Line, PC, &yytext[1]);
									if (List)
										fprintf (prn, "\n *** Line %d, PC %o: ERROR: Symbol %s not defined!\n", Line, PC, &yytext[5]);
									expr = 017777777;
								}
								else
									expr = sym1->address;
								PC = (PC + 3) & (~ 03);
								pc = PC - pc;
								if (pc == 3)
									emitoct48 (0,0);
								else
									if (pc == 2)
										emitoct32 (0);
									else
										if (pc == 1)
											emitoct16 (0);
								if (pc > 0)
									emitn();
								if (sym)
								{
									sym->address = PC / 4; /* Word address for BSS(Z) */
									sym->pc = PC;
								}
								if (yytext[4] == 'Z')
									for (pc = expr; pc > 0; pc--)
									{
										emitoct64 (0, 0);
										if (pc > 1)
											emitn ();
									}
								else
									for (pc = expr; pc > 0; pc--)
									{
										emit ("044111"); /* 2240000B - ' S1 S1&S1' */
										emit (" 044111");
										emitn ();
										emit ("044111");
										emit (" 044111");
										if (pc > 1)
											emitn ();
									}
								emit2 ("");
								PC = PC + expr * 4;
							}

{sep}BSS(Z)?{sep}("O'"?{oct1}+|D'{dec1}+)	{
															int pc = PC;
															PC = (PC + 3) & (~ 03);
															pc = PC - pc;
															if (pc == 3)
																emitoct48 (0,0);
															else
																if (pc == 2)
																	emitoct32 (0);
																else
																	if (pc == 1)
																		emitoct16 (0);
															if (pc > 0)
																emitn();
															if (sym)
															{
																sym->address = PC / 4; /* Word address for BSS(Z) */
																sym->pc = PC;
															}
															if (yytext[4] == 'Z')
																if (yytext[6] == 'D')
																	expr =  dec8 (&yytext[8], "Ai exp,");
																else
																	if (yytext[6] == 'O')
																		expr =  oct8 (&yytext[8], "Ai exp,");
																	else
																		expr =  oct8 (&yytext[6], "Ai exp,");
															else
																if (yytext[5] == 'D')
																	expr =  dec8 (&yytext[7], "Ai exp,");
																else
																	if (yytext[5] == 'O')
																		expr =  oct8 (&yytext[7], "Ai exp,");
																	else
																		expr =  oct8 (&yytext[5], "Ai exp,");
															if (yytext[4] == 'Z')
																for (pc = expr; pc > 0; pc--)
																{
																	emitoct64 (0, 0);
																	if (pc > 1)
																		emitn ();
																}
															else
																for (pc = expr; pc > 0; pc--)
																{
																	emit ("044111"); /* 2240000B - ' S1 S1&S1' */
																	emit (" 044111");
																	emitn ();
																	emit ("044111");
																	emit (" 044111");
																	if (pc > 1)
																		emitn ();
																}
															emit2 ("");
															PC = PC + expr * 4;
														}

{sep}DATA{sep}{nam}	{
								int pc = PC;
								sym1 = symtab (symbol_table, strdup (&yytext[6]));
								if ((sym1->address == -1) && (Pass == LAST))
								{
									fprintf (stderr, "Line %d, PC %o: ERROR: Symbol '%s' not defined!\n", Line, PC, &yytext[1]);
									if (List)
										fprintf (prn, "\n *** Line %d, PC %o: ERROR: Symbol %s not defined!\n", Line, PC, &yytext[5]);
									expr = 017777777;
								}
								else
									expr = sym1->address;
								if (sym)
								{
									if (datum)
									{
										emitoct16 (datum);
										datum = 0;
										PC = PC + 1;
									}
									PC = (PC + 3) & (~ 03);
									pc = PC - pc;
									if (pc == 3)
										emitoct48 (0,0);
									else
										if (pc == 2)
											emitoct32 (0);
										else
											if (pc == 1)
												emitoct16 (0);
									if (pc > 0)
										emitn();

									sym->address = PC / 4; /* Word address for DATA */
									sym->pc = PC;
								}
								goto dataexprl;
							}

{sep}DATA{sep}("O'"?{oct1}+|D'{dec1}+|H'{hex1}+)	{
														unsigned int exprh, exprl;
														int pc = PC;
														if (sym)
														{
															if (datum)
															{
																emitoct16 (datum);
																datum = 0;
																PC = PC + 1;
															}
															PC = (PC + 3) & (~ 03);
															pc = PC - pc;
															if (pc == 3)
																emitoct48 (0,0);
															else
																if (pc == 2)
																	emitoct32 (0);
																else
																if (pc == 1)
																		emitoct16 (0);
															if (pc > 0)
																emitn();

															sym->address = PC / 4;
															sym->pc = PC;
														}
														if (yytext[5] == 'D')
															dec20 (&yytext[8], &exprh, &exprl, "DATA expr");
														else
															if (yytext[6] == 'O')
																oct22 (&yytext[8], &exprh, &exprl, "DATA expr");
															else
																if (yytext[6] == 'H')
																	hex16 (&yytext[8], &exprh, &exprl, "DATA expr");
																else
																	oct22 (&yytext[6], &exprh, &exprl, "DATA expr");

														if ((exprh > 0xFFFFFF) && datum)
														{
															emitoct16((datum << 8) | (exprh >> 8));
															datum = exprl & 0xFF;
															exprl = (exprl >> 8) | ((exprh & 0xFF) << 24);
															exprh >>= 8;
															PC = PC + 1;
														}
														if (exprh < 0x1000000)
															if (exprh < 0x10000)
																if (exprh == 0)
dataexprl:
																	if (exprl < 0x1000000)
																		if (exprl < 0x10000)
																			if (exprl < 0x100)
																			{
																				if (datum)
																				{
																					emitoct16((datum << 8) | exprl);
																					datum = 0;
																					PC = PC + 1;
																				}
																				else
																					datum = exprl;
																				emit1 ("      ");
																			}
																			else /* 0x10000 > exprl > 0xFF */
																			{
																				if (datum)
																				{
																					emitoct16((datum << 8) | (exprl >> 8));
																					datum = exprl & 0xFF;
																					emitn();
																				}
																				else
																				{
																					emitoct16 (exprl);
																					emit1 ("");
																				}
																				PC = PC + 1;
																			}
																		else /* 0x1000000 > exprl > 0xFFFF */
																		{
																			if (datum)
																			{
																				emitoct16((datum << 24) | exprl);
																				datum = 0;
																				emit1 ("");
																			}
																			else
																			{
																				emitoct16(exprl >> 8);
																				datum = exprl & 0xFF;
																				emitn();
																			}
																			PC = PC + 1;
																		}
																	else /* exprl > 0xFFFFFF */
																	{
																		if (datum)
																		{
																			emitoct32 ((datum << 24) | (exprl >> 8));
																			datum = exprl & 0xFF;
																			emitn ();
																		}
																		else
																		{
																			emitoct32 (exprl);
																			emit2 ("");
																		}
																		PC = PC + 2;
																	}
																else /* 0x10000 > exprh > 0  */
																	if (exprh < 0x100)
																		if (datum)
																		{
																			emitoct16 ((datum << 8) | exprh);
																			emitoct16 (exprl);
																			emit2 ("");
																			PC = PC + 2;
																		}
																		else
																		{
																			emitoct16 ((exprh << 8) | (exprl >> 24));
																			datum = exprl & 0xFF;
																			emitn();
																			PC = PC + 1;
																		}
																	else /* 0x10000 > exprh > 0xFF */
																	{
																		if (datum)
																		{
																			emitoct16 ((datum << 8) | (exprh >> 8));
																			emitn();
																			emitoct32 (((exprh & 0xFF) << 24) | (exprl >> 8));
																			emitn();
																			datum = exprl & 0xFF;
																		}
																		else
																		{
																			emitoct16 (exprh);
																			emitn ();
																			emitoct32 (exprl);
																			emit2 ("");
																		}
																		PC = PC + 3;
																	}
															else /* 0x1000000 > exprh > 0xFFFF */
																if (datum)
																{
																	emitoct32 ((datum << 24) | exprh);
																	emitn();
																	emitoct32 (exprl);
																	emit2 ("");
																	PC = PC + 4;
																}
																else
																{
																	emitoct32 ((exprh << 8) | (exprl >> 24));
																	emitn ();
																	emitoct16 (exprl >> 8);
																	emitn ();
																	datum = exprl & 0xFF;
																	PC = PC + 3;
																}
														else /* exprh > 0x1000000 */
														{
															if (datum)
															{
																emitoct32 ((datum << 24) | (exprh >> 8));
																emitn();
																emitoct32 ((exprh << 24) | (exprl >> 8));
																datum = exprl & 0xFF;
																emit2 ("");
															}
															else
															{
																emitoct64 (exprh, exprl);
																emit2 ("");
															}
															PC = PC + 4;
														}
													}

{sep}DATA{sep}A'.*'	{
										unsigned int cc;
										char * ascstr;
										int pc = PC;
										if (sym)
										{	/* Align only if named location */
											if (datum)
											{
												emitoct16 (datum);
												datum = 0;
												PC = PC + 1;
											}
											PC = (PC + 3) & (~ 03);
											pc = PC - pc;
											if (pc == 3)
												emitoct48 (0,0);
											else
												if (pc == 2)
													emitoct32 (0);
												else
													if (pc == 1)
														emitoct16 (0);
											if (pc > 0)
												emitn();

											sym->address = PC / 4;
											sym->pc = PC;
										}
										yytext[strlen(yytext)-1] = 0;
										ascstr = strdup (&yytext[8]);
										for (cc = 0; cc < (strlen (ascstr)); cc = cc + 1)
											if (datum)
											{
												emitoct16 ((datum << 8) | ascstr[cc]);
												if (!(cc & 03))
													emitn();
												else
													emit (" ");
												datum = 0;
												PC = PC + 1;
											}
											else
												datum = ascstr[cc];
										free (ascstr);
									}

{sep}CON{sep}{nam}	{
								int pc = PC;
								sym1 = symtab (symbol_table, strdup (&yytext[5]));
								if ((sym1->address == -1) && (Pass == LAST))
								{
									fprintf (stderr, "Line %d, PC %o: ERROR: Symbol '%s' not defined!\n", Line, PC, &yytext[1]);
									if (List)
										fprintf (prn, "\n *** Line %d, PC %o: ERROR: Symbol %s not defined!\n", Line, PC, &yytext[5]);
									expr = 017777777;
								}
								else
									expr = sym1->address;
								PC = (PC + 3) & (~ 03);
								pc = PC - pc;
								if (pc == 3)
									emitoct48 (0,0);
								else
									if (pc == 2)
										emitoct32 (0);
									else
										if (pc == 1)
											emitoct16 (0);
								if (pc > 0)
									emitn();
								if (sym)
								{
									sym->address = PC / 4; /* Word address for CON */
									sym->pc = PC;
								}
								emitoct64 (0, expr);
								emit2 ("");
								PC = PC + 4;
							}

{sep}CON{sep}("O'"?{oct1}+|D'{dec1}+|H'{hex1}+)	{
														unsigned int exprh, exprl;
														int pc = PC;
														PC = (PC + 3) & (~ 03);
														pc = PC - pc;
														if (pc == 3)
															emitoct48 (0,0);
														else
															if (pc == 2)
																emitoct32 (0);
															else
																if (pc == 1)
																	emitoct16 (0);
														if (pc > 0)
															emitn();
														if (sym)
														{
															sym->address = PC / 4;
															sym->pc = PC;
														}
														if (yytext[5] == 'D')
															dec20 (&yytext[7], &exprh, &exprl, "CON expr");
														else
															if (yytext[5] == 'O')
																oct22 (&yytext[7], &exprh, &exprl, "CON expr");
															else
																if (yytext[5] == 'H')
																	hex16 (&yytext[7], &exprh, &exprl, "CON expr");
																else
																	oct22 (&yytext[5], &exprh, &exprl, "CON expr");
														emitoct64 (exprh, exprl);
														emit2 ("");
														PC = PC + 4;
													}

{sep}CON{sep}A'.*'	{
										unsigned int cc;
										char * ascstr;
										int pc = PC;
										PC = (PC + 3) & (~ 03);
										pc = PC - pc;
										if (pc == 3)
											emitoct48 (0,0);
										else
											if (pc == 2)
												emitoct32 (0);
											else
												if (pc == 1)
													emitoct16 (0);
										if (pc > 0)
											emitn();
										if (sym)
										{
											sym->address = PC / 4;
											sym->pc = PC;
										}
										yytext[strlen(yytext)-1] = 0;
										ascstr = strdup (&yytext[7]);
										ascstr = (char *) realloc (ascstr, strlen(ascstr) + 9);
										strcat (ascstr, "        ");
										for (cc = 0; cc < (strlen (ascstr)-8); cc = cc + 8)
										{
											emitoct64 (	ascstr[cc+0] << 24 |
															ascstr[cc+1] << 16 |
															ascstr[cc+2] << 8 |
															ascstr[cc+3],
															ascstr[cc+4] << 24 |
															ascstr[cc+5] << 16 |
															ascstr[cc+6] << 8 |
															ascstr[cc+7] );
											PC = PC + 4;
											if ((cc + 8) <= (strlen (ascstr) - 8))
												emitn();
										}
										free (ascstr);
										emit2 ("");
									}

{sep}ORG{sep}{nam}	{
								sym = symtab (symbol_table, strdup (&yytext[5]));
								if ((sym->address == -1) && (Pass == 1))
								{
									fprintf (stderr, "Line %d, PC %o: ERROR: Symbol '%s' not defined, ORG can not be used with forward referenced symbols!\n", Line, PC, &yytext[1]);
									if (List)
										fprintf (prn, "\n *** Line %d, PC %o: ERROR: Symbol %s not defined, ORG can not be used with forward referenced symbols!\n", Line, PC, &yytext[5]);
									expr = 017777777;
								}
								else
									expr = sym->address;
								if (expr != PC)
									{
										char list = List;
										int pc = PC;
										List = 0;
										PC = (PC + 3) & (~ 03);
										pc = PC - pc;
										if (pc == 3)
										{
											emitoct48 (0,0);
											emitn ();
										}
										else
											if (pc == 2)
											{
												emitoct32 (0);
												emitn ();
											}
											else
												if (pc == 1)
												{
													emitoct16 (0);
													emitn ();
												}
										fprintf (octfile, "\n");
										emit ("-ORIGIN-\n");
										emitoct64 (0, expr);
										List = list;
									}
								PC = expr;
								emit1 ("");
							}

{sep}ORG{sep}("O'"?{oct1}+|D'{dec1}+)	{
												if (yytext[5] == 'D')
													expr = dec8 (&yytext[7], "ORG expr");
												else
													if (yytext[5] == 'O')
														expr = oct8 (&yytext[7], "ORG expr");
													else
														expr = oct8 (&yytext[5], "ORG expr");
												if (expr != PC)
												{
													unsigned int pc = PC;
													char list = List;
													List = 0;
													PC = (PC + 3) & (~ 03);
													pc = PC - pc;
													if (pc == 3)
													{
														emitoct48 (0,0);
														emitn ();
													}
													else
														if (pc == 2)
														{
															emitoct32 (0);
															emitn ();
														}
														else
															if (pc == 1)
															{
																emitoct16 (0);
																emitn ();
															}
													fprintf (octfile, "\n");
													emit ("-ORIGIN-\n");
													emitoct64 (0, expr);
													List = list;
												}
												PC = expr;
												emit1 ("");
											}

^{nam}{sep}SET	{
						unsigned int cc;
						/* first find the ' ' */
						for (cc = 1; cc <= strlen(yytext); cc++)
							if (yytext[cc] == ' ')
								break;
						yytext[cc] = 0;
						sym = symtab (symbol_table, strdup (yytext));
						sym->pc = PC;
						BEGIN (equal);
					}

^{nam}{sep}"="	{
						unsigned int cc;
						/* first find the ' ' */
						for (cc = 1; cc <= strlen(yytext); cc++)
							if (yytext[cc] == ' ')
								break;
						yytext[cc] = 0;
						sym = symtab (symbol_table, strdup (yytext));
						if ((sym->address != -1) && (Pass == 1))
						{
							fprintf (stderr, "Line %d, PC %o: Warning: symbol '%s' redefined, new value will be used further!\n", Line, PC, yytext);
							if (List)
								fprintf (prn, "\n *** Line %d, PC %o: Warning: symbol '%s' redefined, new value will be used further!\n", Line, PC, yytext);
						}
						sym->pc = PC;
						BEGIN (equal);
					}

<equal>{sep}"W.*O"	{
	/* BEWARE: the address generated is the address in which this parcel
				  resides. It does not ALIGN the origin ! */
							sym->address = PC / 4;
							if (List)
								fprintf (prn,"\t\t%s", ListLine);
							BEGIN (INITIAL);
						}

<equal>{sep}"*O"	{
							sym->address = PC;
							if (List)
								fprintf (prn,"\t\t%s", ListLine);
							BEGIN (INITIAL);
						}

<equal>{sep}{nam}	{
								sym1 = symtab (symbol_table, strdup (&yytext[1]));
								if ((sym1->address == -1) && (Pass == LAST))
								{
									fprintf (stderr, "Line %d, PC %o: ERROR: Symbol '%s' not defined!\n", Line, PC, &yytext[1]);
									if (List)
										fprintf (prn, "\n *** Line %d, PC %o: ERROR: Symbol %s not defined!\n", Line, PC, &yytext[1]);
									sym->address = 017777777;
								}
								else
									sym->address = sym1->address;
								if (List)
									fprintf (prn,"\t\t%s", ListLine);
								BEGIN (INITIAL);
							}

<equal>{sep}("O'"?{oct1}+|D'{dec1}+|H'{hex1}+)	{
														unsigned int exprh = 0;
														unsigned int exprl = 0;
														if (yytext[1] == 'D')
															dec20 (&yytext[3], &exprh, &exprl, "=/SET expr");
														else
															if (yytext[1] == 'O')
																oct22 (&yytext[3], &exprh, &exprl, "=/SET expr");
															else
																if (yytext[1] == 'H')
																	hex16 (&yytext[3], &exprh, &exprl, "=/SET expr");
																else
																	oct22 (&yytext[1], &exprh, &exprl, "=/SET expr");
														if (exprh != 0)
														{
															fprintf (stderr, "Line %d, PC %o: ERROR: Expression value too big, will be truncated to %d!\n", Line, PC, exprl);
															if (List)
																fprintf (prn, "\n *** Line %d, PC %o: ERROR: Expression value too big, will be truncated to %d!\n", Line, PC, exprl);
														}
														sym->address = exprl;
														if (List)
															fprintf (prn,"\t\t%s", ListLine);
														BEGIN (INITIAL);
													}


{sep}LISTFILE{sep}{fname}+	{
										if (Pass == LAST)
											prn = fopen (&yytext[10], "w");
										if (List)
											fprintf (prn,"\t\t%s", ListLine);
									}

{sep}LIST	{
					if (Pass == LAST)
						List = TRUE;
					if (List)
						fprintf (prn,"\t\t%s", ListLine);
				}

{sep}NOLIST	{
					if (Pass == LAST)
						List = FALSE;
					if (List)
						fprintf (prn,"\t\t%s", ListLine);
				}

{sep}IDENT{sep}{nam}	{
								Ident = strdup (&yytext[7]);
								if (List)
									fprintf (prn,"\t\t%s", ListLine);
							}

{sep}END		{
					int pc = PC;
					PC = (PC + 3) & (~ 03);
					pc = PC - pc;
					if (pc == 3)
					{
						emitoct48 (0,0);
						emitn ();
					}
					else
						if (pc == 2)
						{
							emitoct32 (0);
							emitn ();
						}
						else
							if (pc == 1)
							{
								emitoct16 (0);
								emitn ();
							}
					if (Pass == LAST)
						fprintf (octfile, "\n-ENDCOD-\n");
					if (List)
						fprintf (prn, "         \t\t%s", ListLine);
					return 0;
				}



^{nam}	{
				sym = symtab (symbol_table, strdup (yytext));
				if ((sym->address != -1) && (Pass == 1))
				{
					fprintf (stderr, "Line %d, PC %o: Warning: symbol '%s' redefined, new value will be used further!\n", Line, PC, yytext);
					if (List)
						fprintf (prn, "\n *** Line %d, PC %o: Warning: symbol '%s' redefined, new value will be used further!\n", Line, PC, yytext);
				}
				sym->address = PC;
				sym->pc = PC;
			}


^"*".*{nl}	{ /* Comment */
					Line = Line + 1;
					if (List)
						fprintf (prn, "\t\t\t\t%s", yytext);
				}

{eln}	{ /* COMMENT or no */
			if (strlen (errorline) && (Pass == 2))
				/* There was an unrecognisable token */
			{
				fprintf (stderr,
						"Line %d, PC %d: Unrecognisable CAL expression: '%s'\n",
							Line, PC, errorline);
				if (List)
					fprintf (prn,
						"\n *** Line %d, PC %d: Unrecognisable CAL expression: '%s'\n",
								Line, PC, errorline);
				errorline[0] = 0;
			}
		}

.	{
		if ((strlen(yytext) == 1) && ((yytext[0] == ' ') | (yytext[0] == '\t')))
		{
			if (strlen (errorline))
				strcat (errorline, yytext);
		}
		else
		{
			strcat (errorline, yytext);
		}
		BEGIN (INITIAL);
	}

^{nl}	{
					if (List)
						fprintf (prn, "\n");
				}

^{sep}+{nl}	{
					if (List)
						fprintf (prn, "\n");
				}

^.*{nl}	{
				unsigned int cc, cd;
				sym = NIL;
				if (datum)
				{
					/* DATA wanted to emit only one byte, making it a Parcel */
					if (!strstr (yytext, "DATA"))
					{
						emitoct16 (datum << 8);
						datum = 0;
						PC = PC + 1;
						emit2 ("");
					}
					else
						if (List)
							emit1 ("	      ");
				}
				free (ListLine);
				ListLine = strdup (yytext);
				Line = Line + 1;
				if (List)
				{
					char parc;
					switch (PC & 03)
					{
						case 0:
							parc = 'a';
							break;
						case 1:
							parc = 'b';
							break;
						case 2:
							parc = 'c';
							break;
						case 3:
							parc = 'd';
							break;
					}
					/* fprintf (prn, "%7d: %06o%c\t", Line, PC / 4, parc); */
					fprintf (prn, "%7o| %06o% c%\t", PC, PC / 4, parc);
					/* Expand spaces into tabs */
					for (cc = 0; cc < strlen(ListLine); cc++)
					{
						if ((yytext[cc] == 'A') && (yytext[cc+1] == '\''))
							break;
						if (ListLine[cc] == '*')
							break;
						if (ListLine[cc] == ' ')
							ListLine[cc] = '\t';
					}
				}
				/* Mark default comments (after 3rd space) */
				cd = 1;
				for (cc = 0; cc < strlen(yytext)-1; cc++)
				{
					if ((yytext[cc] == 'A') && (yytext[cc+1] == '\''))	/* Ascii string */
						break;
					if ((yytext[cc] == ' ') | (yytext[cc] == '\t'))
						if (cd++ == 3)
						{
							yytext[cc+1] = ' ';
							yytext[cc+2] = '*';
							break;
						}
				}
				sym = sym1 = NIL;
				REJECT;
			}


%%

#ifdef NOTYET

<jkmexpr>{sep}{nam}	{
									/* Here we have to consult the symbol table */
									emit1 (& yytext[1]);
									BEGIN (INITIAL);
								}
				
<jkmexpr>{sep}("O'"{oct1}+|{dec1}+)	{
													strcat (Instr, " exp");
													if (yytext[1] == 'O')
														expr = oct8 (&yytext[3], Instr);
													else
														expr = dec8 (&yytext[1], Instr);
													emitoct22 (expr);
													emit1 ("");
													BEGIN (INITIAL);
												}

#endif


main (argc, argv)
	int argc;
	char ** argv;
{
	char * arg;
	int args;
	unsigned char c;
	unsigned char dash = FALSE;	/* For options, they have to be preceded
												by dash */
	prn = stdout;
	octfile = stdout;

	/* Check the arguments */
   ++argv, --argc;  /* skip over program name */
	args = 0;
	while (args < argc)
		{
			dash = FALSE;
			arg = (char *) argv [args++];
			while ('\0' != (c = *arg++))
				switch(c)
					{
						case '-':
							dash = TRUE;
							break;
			         case 'h': /* HELP. */
							if (dash)
							{
								printf ("\nUsage: %s", argv[0]);
								printf (" -h -v -i -p -l <listfile> -o <octfile> -r <romfile> -x <hexfile> <filename>\n"); 
								/*
								printf (" -h -v -i -p -l <listfile> -o <octfile> -r <romfile> -x <hexfile> -b <binfile> <filename>\n"); 
								*/
								printf ("\t-h \tThis usage message\n");
								printf("\t-v \tPrint version information.\n");
								printf("\t-i \tInteractive/Pipe mode:\n\t\t\tread from stdin and write to stdout\n");
								printf("\t-p \tPrint lististing to standard output\n");
								printf("\t-l \tPrint lististing to <listfile>\n");
								printf("\t-o <octfile>:\n\t\t\toutput octal ViMON object <octfile>\n");
								printf("\t-r <romfile>:\n\t\t\toutput a simple hexadecimal ASCII linear translation to <romfile>\n");
								printf("\t-x <hexfile>:\n\t\t\toutput hexadecimal ViMON object <hexfile>\n");
								printf("\t<filename> \tThe name of the file to be Translated\n");
								printf("\n\nWithout input or output arguments '-i' is implied\n");
								printf ("\n");
								printf ("Return values:");
								printf ("\n\t0: Clean exit");
								printf ("\n\t1: The Cray Assembly Language file could not be opened for translation");
								printf ("\n\t2: Listing file could not be opened");
								printf ("\n\t3: ViMON -OCTCOD- file could not be opened");
								printf ("\n\t4: ViMON -HEXCOD- file could not be opened");
								printf ("\n\t5: Verilog compatible ROM file could not be opened");
								printf ("\n\t6: A temporary file needed for tranlation could not be opened");

								printf ("\n");
								exit (0);
							}
							else
								goto els;
						case 'l': /* LIST */
							if (dash)
							{
								DoList = TRUE;
								if (!(prn = fopen(argv [args++], "w+")))
								{
									fprintf (stderr, "ERROR: Can not open the file '%s' for listing!\n", argv[--args]);
									exit (2);
								}
								dash = FALSE;
								goto NextArg;
							}
							else
								goto els;
						case 'v': /* VERSION. */
							if (dash)
							{
								printf ("\n%s", version());

								/*
								printf ("\n Compiled on: %s\n\n\n",
											system_architecture());
								if (*arg == 'v')
									internals();
								*/

								exit (0);
							}
							else
								goto els;
						case 'i': /* PIPE */
							if (dash)
							{
								Piping = TRUE;
	   						yyin = stdin;
								octfile = stdout;
								dash = FALSE;
								goto NextArg;
							}
							else
								goto els;
						case 'o': /* OUTPUT FILE (octal) */
							if (dash)
							{
								if (!(octfile = fopen(argv [args++], "w+")))
								{
									fprintf (stderr, "ERROR: Can not open the file '%s' for ViMON -OCTCOD- output!\n", argv[--args]);
									exit (3);
								}
								dash = FALSE;
								goto NextArg;
							}
							else
								goto els;
						case 'r': /* OUTPUT FILE (hexadecimal) */
							if (dash)
							{
								if (!(romfile = fopen(argv [args++], "w")))
								{
									fprintf (stderr, "ERROR: Can not open the Verilog compatible ROM file '%s'!\n", argv[--args]);
									exit (5);
								}
								dash = FALSE;
								goto NextArg;
							}
							else
								goto els;
						case 'x': /* OUTPUT FILE (hexadecimal) */
							if (dash)
							{
								if (!(hexfile = fopen(argv [args++], "w")))
								{
									fprintf (stderr, "ERROR: Can not open the file '%s' for ViMON -HEXCOD- output!\n", argv[--args]);
									exit (4);
								}
								dash = FALSE;
								goto NextArg;
							}
							else
								goto els;
						default:
els:
							if (! dash)
							{
								Piping = FALSE;
								if (!(yyin = fopen(argv [args - 1], "r")))
								{
									fprintf (stderr, "ERROR: Can not open the Cray Assembly Language file '%s' for translation!\n", argv[args - 1]);
									exit (1);
								}
							}
							dash = FALSE;
							goto NextArg;
					}
NextArg:	;
		}

	symbol_table = makesymtab();

   printf ("Pass 1\n");

	if (hexfile || romfile)
		if (octfile == stdout)
			if (!(octfile = (FILE *) tmpfile()))
			{
NoTempFile:
				fprintf (stderr, "ERROR: Can not open a temporary file for translation - must abort.\n", argv[--args]);
				exit (6);
			}

	if (Piping)
		if (!(tempfile = (FILE *) tmpfile()))
			goto NoTempFile;

	PC = 0;
	Pass = 1;
	Line = 0;
	datum = 0;

	yylex ();

   printf ("Pass 2\n");

	errorline[0] = 0;

	if (Piping)
	{
		rewind (tempfile);
		yyin = tempfile;
	}
	else
		rewind (yyin);
	Piping = FALSE;

	if (DoList)
		List = TRUE;

	PC = 0;
	Pass = LAST;
	Line = 0;
	datum = 0;

	fprintf (octfile, "-OCTCOD-\n");
	yylex ();

	if (List)
	{
		fprintf (prn,"\n");
		fclose (prn);
	}

	if (hexfile || romfile)
	{
		unsigned int parcel;
		unsigned int parcelhi, parcelmh, parcelml, parcello;
		char spaces[32]; /* buffer overkill */
		char command[8];
		char cnt = 0;

		fflush (octfile);
		rewind (octfile);

		if (hexfile)
			fprintf (hexfile, "-HEXCOD-\n");

		while (!feof (octfile))
		{
			PC = 0;
			/* The following part of programme was originally written with the
				fscanf functions according to the ISO specification. However,
				on UWIN using Microsoft C, the fscanf format specification
				does not support the whole standard. Therefore the following
				fscanf(s) is/are replaced by a less elegant solution, which
				nonetheless, works on all systems */
			/* fscanf (octfile, "%[!-/ \n]", spaces); */
			spaces[1] = c = 0;
			do 
			{
				spaces[0] = c;
				c = fgetc (octfile);
			}
			while ((c >= '!') && (c <= '/') || (c == ' ') || (c == '\n'));

			command[0] = c;

			/* BEWARE: This is very simple decoding. If more Commands are
				to be added, the case '-' shall be having a switch(command[0])! */

			switch (spaces[strlen(spaces)-1])
			{
				case '-':
					/*fscanf (octfile, "%[!-/A-Z]", command);*/
					fscanf (octfile, "%s", &command[1]);
					if (command[0] == 'E')
					{
						if (hexfile)
							fprintf (hexfile, "\n-%s\n", command);
						goto Continue;
					}

					if (command[0] == 'C')
					/* -CHKSUM- */
					{
						break;
					}
	
					if (command[1] == 'C')
					/* -OCTCOD- */
					{
						goto Continue;
					}
	
					/* -ORIGIN- */
					fscanf (octfile, "%[ \n]", spaces);
					fscanf (octfile, "%o", &parcelhi);
					fscanf (octfile, "%[ \n]", spaces);
					fscanf (octfile, "%o", &parcelmh);
					fscanf (octfile, "%[ \n]", spaces);
					fscanf (octfile, "%o", &parcelml);
					fscanf (octfile, "%[ \n]", spaces);
					fscanf (octfile, "%o", &parcello);

					if (romfile)
						fprintf (stderr, "At absolute address %d: WARNING -- romfile format does not allow for ORIGIN changes!\n",
									parcello | (parcelml << 16)); /* 32-bit address */
	
	
					if (hexfile)
					{
						fprintf (hexfile, "\n-%s\n", command);
						PC = (parcelml << 16) | parcello;
						fprintf (hexfile, "%08X", (parcelhi << 16) | parcelmh);
						fprintf (hexfile, "%08X", PC);
						fprintf (hexfile, "\n");
					}
					goto Continue;

				default:
					break;
			}
			fscanf (octfile, "%o", &parcel);

			/* As for UWIN changes, we have to check for the command[0] */
			if (command[0] == '1')
				parcel += 0x8000;

			PC = 0;
			if (!feof (octfile))
			{
				if (hexfile)
					fprintf (hexfile, "%04X", parcel);
				if (romfile)
					fprintf (romfile, "%04X", parcel);
				if (!(cnt = (cnt + 1) & 3))
				{
					PC = PC + 4;
					if (hexfile)
						fprintf (hexfile, "\n");
					if (romfile)
						fprintf (romfile, "\n");
				}
			}
Continue:	;
		}
	/*
		while (cnt-- > 0)
		{
			fprintf (hexfile, "%04X", 0);
		}
	*/
		if (hexfile)
		{
			fprintf (hexfile, "\n");
			fclose (hexfile);
		}
		if (romfile)
		{
			fprintf (romfile, "\n");
			fclose (romfile);
		}
	}

	fclose (octfile);

	if (tempfile)
		fclose (tempfile);
	else
		fclose (yyin);

}

#ifdef NOTDEF
^{nl}	{	/* Empty line */
					Line = Line + 1;
					if (List) 				/* Actually LF, but honour also CR */
						fprintf (prn, "\n", yytext);
			}
#endif
