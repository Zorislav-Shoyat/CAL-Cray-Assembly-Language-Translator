/****************************************************************************/
/* Cray Assembly Language Translator symbol table                           */
/*                                                                          */
/* Zorislav Shoyat (c) 2014                                                 */
/*                                                                          */
/* V1.0 24/3/14 15:43 Zagreb, Atelier, Shanti (Gu)                          */
/* V1.1 25/3/14 15:49 Zagreb, Atelier, Shanti (Gu)                          */
/* V1.1- 21/11/14 14:48 Zagreb, Atelier, Shanti (Moby Dick)                 */
/* V1.2	2/3/15 19:57 Zagreb, Atelier, Gu                                   */
/*                                                                          */
/****************************************************************************/
/* Adapted from Virtue symbol table                                         */
/****************************************************************************/
/*                                                                          */
/* V1.1 symtab checks for reserved Cray register names, and reports a       */
/*      warning.                                                            */
/* V1.1- The above is not finished yet (see the #ifdef NOT_FINISHED below)  */
/* V1.2 !!! A VERY rare bug was found probably after more than 30 years     */
/*      (I use this algorithm already from around 1988/1989 !!!)            */
/*      - see below                                                         */
/*                                                                          */
/****************************************************************************/

#define writefarg(form,what)

#include <stdlib.h>

#include "symbols.h"

/****************************************************************************/
/*                                                                          */
/* Compare two strings... local version                                     */
/* This version is slightly faster than the strcmp()                        */
/*                                                                          */
/****************************************************************************/

int strcomp(a, b)
	char * a, * b;
{
	for (; *a == *b; b++)
		if (*a++ == 0)
			return 0;
	return *a - *b;
}

/**************************************/
/* this version returns True or False */
/**************************************/

int stringcmp(a, b)
	char * a, * b;
{
	for (; *a++ == *b;)
		if (*b++ == 0)
			return 1;
	return 0;
}

/****************************************************************************/
/*                                                                          */
/* This is the Filter/Graphic lang symbol table based on Knuth's            */
/* seminumerical algorithms.                                                */
/* BEWARE: Sinisha Marin found an error in the algorithm -- should be       */
/* checked and debugged!                                                    */
/* I am still not aware of that bug!                                        */
/* It could be the "char stcp", which makes problems on NetBSD macppc,      */
/* -- changed to "int stcp".                                                */
/* The "char a" was also changed to "int a", as NetBSD macppc (or ppc       */
/* itself) does not process signed char.                                    */
/*                                                                          */
/****************************************************************************/

#define allocate malloc
#define deallocate free

#define NIL 0

/*********************************************************/
/* Make a new symbol table                               */
/* Returns: pointer to the new empty symbol table        */
/*********************************************************/

symbols * makebintab ()
{
	symbols *t;
	
	t = (symbols *) allocate (sizeof (symbols));
	t->left = NIL;
	t->balance = 0;
	t->name = "";
	t->right = (symbols *) allocate (sizeof (symbols));
	t->right->left = t->right->right = NIL;
	t->right->balance = 0;
	t->right->name = "";
	return (t);
}

#ifdef NOT_FINISHED
/*********************************************************/
/* Cray Assembly Language Translator                     */
/* Before invoking the bintab(), check if the symbol     */
/* name is one of the reserved register names            */
/*********************************************************/
symbols * symtab (symbol_table, symbol_name)
	symbols * symbol_table;
	char * symbol_name;
{
	char * cc;
	int sl;
	if ((sl = strlen(symbol_name) > 1) && (sl <= 4)) /*Cray XMP SMnn */
		switch (cc = symbol_name)
		{
			case 'A':
				if ((sl == 2) && (++cc >= '0') && (cc <= '7')
					goto Warning;
				break;
			case 'F':
				if ((sl == 3) && (
						(++cc == 'A') || (cc == 'S') || (cc == 'V'))
						&& (++cc >= '0') && (cc <= '7'))
					goto Warning;
				break;
			case 'B':
				if ((sl <= 3) && (++cc >= '0') && (cc <= '7'))
					if ((sl == 2))
						goto Warning;
					else
						if ((sl == 3) && (++cc >= '0') && (cc <= '7'))
							goto Warning;
				break;
			case 'S':
				break;
			case 'P':
				break;
			case 'Z':
				break;
			case 'Q':
				break;
			case 'T':
				break;
			case 'V':
				break;
			case 'R':
				break;
			case 'C':
				break;
			case 'X':
				break;
			case 'M':
					if ((sl == 2) && (++cc == 'C'))
					{
Warning:
						return (NIL); /* Or somethine else, like a special address */
					}
					else
				break;
			default:
		}
	return bintab (symbol_table, symbol_name);
}
#endif

/*********************************************************/
/* Remenber a symbol in the table                        */
/* Returns: pointer to the symbol                        */
/*          a new symbol will have address and pc -1     */
/*********************************************************/

/* A very slightly optimmized version of the original Knuth/Filtru symbol table.
	There was an experiment with strcomp which returned the position of the
	last equal character, (ppos, spos...) but it did not 
	succeed, due to the fact that we can not know how similar/dissimilar
	two node names of the tree are! With a lot of effort we could probably save
	the differing character index in the table node, for left and right no.
	of equal chars... To much trouble! */

symbols * bintab (symbol_table, symbol_name)
	symbols * symbol_table;
	char * symbol_name;
{
	symbols	*t, *s, *p, *q, *r;
	int		stcp;
	int		a;

	writefarg ("\nbintab: '%s'", symbol_name);

	for (t = symbol_table, p = s = symbol_table->right;;)
	{
		if ((stcp = strcomp (symbol_name, p->name)) == 0)
		{
			/* We use the original allocation for symbol_name.
				Therefore we have to free it if the symbol was found. */
			deallocate (symbol_name);
			return (p);
		}
		else
			if (stcp < 0)
			{
				if (NIL == (q = p->left))
				{
					p->left = q = (symbols *) allocate (sizeof (symbols));

					q->balance = 0;
					q->address = -1;
					q->pc = -1;

					break;
				}
				if (q->balance)
				{
					t = p;
					s = q;
				}
				p = q;
			}
			else /* if (stcp > 0) */
			{
				if (NIL == (q = p->right))
				{
					p->right = q = (symbols *) allocate (sizeof (symbols));

					q->address = -1;
					q->pc = -1;

					break;
				}
				if (q->balance)
				{
					t = p;
					s = q;
				}
				p = q;
			}
	}

	/* A new symbol */

	/* We use the original allocation for symbol_name. Therefore we have to
		free it if the symbol was found. */
	/* q->name = stringdup (symbol_name); */
	q->name = symbol_name;
	q->right = q->left = NIL;
	q->balance = 0;
	if (strcomp (symbol_name, s->name) < 0)
	{
		p = s->left;
		a = -1;
	}
	else
	{
		p = s->right;
		a = 1;
	}
	r = p;
	while (p != q)
		if ((stcp = strcomp (symbol_name, p->name)) < 0)
		{
			p->balance = -1;
			p = p->left;
		}
		else
			if (stcp > 0)
			{
				p->balance = 1;
				p = p->right;
			};
	if (s->balance == 0)
	{
		s->balance = a;
		return (q);
	}
	if (s->balance == -a)
	{
		s->balance = 0;
		return (q);
	}
	else
		if (r->balance == a)
		{
			p = r;
			switch (a)
			{
				case	1 :
					s->right = r->left;
					r->left = s;
					break;
				case -1 :
					s->left = r-> right;
					r->right = s;
					break;
			}
			s->balance = r->balance = 0;
		}
		else
		{
			/* ZS 3/4/2015, 19:57 found a VERY rare bug, the if (r->balance)
				was missing for, I suppose, at least 30 years! */
			if (r->balance == -a)
				switch (a)
				{
					case	1 :
						p = r->left;
						r->left = p->right;
						p->right = r;
						s->right = p->left;
						p->left = s;
						break;
					case -1 :
						p = r->right;
						r->right = p->left;
						p->left = r;
						s->left = p->right;
						p->right = s;
						break;
				}
			if (p->balance == 0)
				s->balance = r->balance = 0;
			else
				if (p->balance = a)
				{
					s->balance = -a;
					r->balance = 0;
				}
				else
				{
					s->balance = 0;
					r->balance = a	;
				}
			p->balance = 0;
		}
	if (s == t->right)
		t->right = p;
	else
		t->left = p;
	
	return (q);	
}


/******************************/
/* Not used in CAL Translator */
/******************************/
#undef USED
#ifdef USED

/*********************************************************/
/* Check the symbol table without inserting a new symbol */
/* Returns: NIL for non-defined symbols                  */
/*          pointer to the symbol for defined symbols    */
/*********************************************************/

symbols * checkbin (symbol_table, symbol_name)
	symbols * symbol_table;
	char * symbol_name;
{
	symbols	*t, *s, *p, *q, *r;
	int		stcp;
	int		a;

	writefarg ("\nbintab: '%s'", symbol_name);

	for (t = symbol_table, p = s = symbol_table->right;;)
	{
		if ((stcp = strcomp (symbol_name, p->name)) == 0)
			return (p);
		else
			if (stcp < 0)
			{
				if (NIL == (q = p->left))
					return NIL;
				if (q->balance)
				{
					t = p;
					s = q;
				}
				p = q;
			}
			else /* if (stcp > 0) */
			{
				if (NIL == (q = p->right))
					return NIL;
				if (q->balance)
				{
					t = p;
					s = q;
				}
				p = q;
			}
	}
	return NIL;
}
#endif /* USED */

