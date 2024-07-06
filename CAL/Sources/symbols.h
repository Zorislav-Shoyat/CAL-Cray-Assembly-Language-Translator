/****************************************************************************/
/* Cray Assembly Language Translator symbol definition(s)                   */
/*                                                                          */
/* Zorislav Shoyat (c) 2014                                                 */
/*                                                                          */
/* V1.0 24/3/14 15:38 Zagreb, Atelier, Shanti (Gu)                          */
/*                                                                          */
/****************************************************************************/
/* Adapted from Virtue symbol definition(s)                                 */
/****************************************************************************/

typedef struct symbols
	{
		short int	balance;
		struct symbols * left;
		struct symbols * right;
		char * name;
		int address;
		int pc;
	} symbols;

symbols * makebintab ();
symbols * checkbin ();
symbols * bintab ();

void binmem ();
void forgetbin ();
void binwipe ();


#define makesymtab()	\
				(makebintab())
#define checksym(st,sn)	\
				(checkbin(st,sn))
#define symtab(st,sn)	\
				(bintab(st,sn))

