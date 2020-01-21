#ifndef __FORTH_SHARED__
#define __FORTH_SHARED__

// ************************************************************************************************
// The VM's instruction set
// ************************************************************************************************
#define LITERAL    1	// 01
#define FETCH      2	// 02
#define STORE      3	// 03
#define SWAP       4	// 04
#define DROP       5	// 05
#define DUP        6	// 06
#define SLITERAL   7	// 07
#define JMP        8	// 08
#define JMPZ       9	// 09
#define JMPNZ     10	// 0A
#define CALL      11	// 0B
#define RET       12	// 0C
#define ZTYPE     13	// 0D
#define CLITERAL  14	// 0E
#define CFETCH    15	// 0F
#define CSTORE    16	// 10
#define ADD       17	// 11
#define SUB       18	// 12
#define MUL       19	// 13
#define DIV       20	// 14
#define LT        21	// 15
#define EQ        22	// 16
#define GT        23	// 17
#define DICTP     24	// 18
#define EMIT      25	// 19
#define OVER      26	// 1A
#define COMPARE   27	// 1B  ( addr1 addr2 -- bool )
#define FOPEN     28	// 1C  ( name mode -- fp status ) - mode: 0 = read, 1 = write
#define FREAD     29	// 1D  ( addr num fp -- count ) - fp == 0 means STDIN
#define FREADLINE 30	// 1E  ( addr fp -- count )
#define FWRITE    31	// 1F  ( addr num fp -- ) - fp == 0 means STDIN
#define FCLOSE    32	// 20  ( fp -- )
#define DTOR      33	// 21  >R (Data To Return)
#define RFETCH    34	// 22  R@
#define RTOD      35	// 23  R> (Return To Data)
#define ONEPLUS   36	// 24
#define PICK      37	// 25
#define DEPTH     38	// 26
#define GETCH     39	// 27
#define LSHIFT    40	// 28
#define RSHIFT    41	// 29
#define AND       42	// 2A
#define OR		  43	// 2B
#define BRANCH    44	// 2C
#define BRANCHZ   45	// 2D
#define BRANCHNZ  46	// 2E
#define COMPAREI  47	// 2F ( addr1 addr2 -- bool )
#define BREAK    253	// FD
#define RESET    254	// FE
#define BYE      255	// FF

// ************************************************************************************************
// ************************************************************************************************
// ************************************************************************************************

typedef unsigned char BYTE;
typedef long CELL;				// Use long for a 32-bit implementation, short for a 16-bit
// #define CELL long;				// Use long for a 32-bit implementation, short for a 16-bit
typedef int bool;
typedef char *String;

typedef struct {
	char *asm_instr;
	BYTE opcode;
	char *forth_prim;
} OPCODE_T;

// flags is a bit field:
#define IS_IMMEDIATE 0x01
#define IS_INLINE    0x02
#define IS_OPCODE    0x04

typedef struct {
	CELL next, XT;
	BYTE flags;
	BYTE len;
	char name[30];
} DICT_T;

#undef NULL
#define NULL (0)
#define CELL_SZ (sizeof(CELL))

#define DSTACK_SZ (CELL_SZ * 64)
#define RSTACK_SZ (CELL_SZ * 64)

#define STACK_BUF_CELLS 2
#define STACK_BUF_SZ (STACK_BUF_CELLS * CELL_SZ)

#define ADDR_CELL   7
#define ADDR_HERE  16
#define ADDR_LAST  20
#define ADDR_BASE  24

#define ONE_KB (1024)
#define ONE_MB (ONE_KB * ONE_KB)
#define MEM_SZ (16*ONE_KB)

#define RSP_BASE (MEM_SZ - RSTACK_SZ)				// Start address of the return stack
#define RSP_INIT (MEM_SZ - STACK_BUF_SZ)			// Initial value of the return stack pointer

#define DSP_BASE ((MEM_SZ) - RSTACK_SZ - DSTACK_SZ)	// Start address of the data stack
#define DSP_INIT (DSP_BASE + STACK_BUF_SZ)			// Initial value of the data stack pointer

#define GETAT(loc) *(CELL *)(&the_memory[loc])
#define SETAT(loc, val) *(CELL *)(&the_memory[loc]) = val

#define GETTOS() *(DSP)
#define GET2ND() *(DSP-1)
#define SETTOS(val) *(DSP) = (val)
#define SET2ND(val) *(DSP-1) = (val)

#define push(val) *(++DSP) = (CELL)(val)
#define pop() *(DSP--)

#define rpush(val) *(--RSP) = (CELL)(val)
#define rpop() *(RSP++)

#define _T(x) x

#define true 1
#define false 0

#define LPCTSTR char *

OPCODE_T opcodes[] = {
	{ _T("RESET"), RESET, _T("RESET") }
	, { _T("PUSH"), LITERAL, _T("") }
	, { _T("CPUSH"), CLITERAL, _T("") }
	, { _T("FETCH"), FETCH, _T("@") }
	, { _T("STORE"), STORE, _T("!") }
	, { _T("SWAP"), SWAP, _T("SWAP") }
	, { _T("DROP"), DROP, _T("DROP") }
	, { _T("DUP"), DUP, _T("DUP") }
	, { _T("OVER"), OVER, _T("OVER") }
	, { _T("JMP"), JMP, _T("JMP") }
	, { _T("JMPZ"), JMPZ, _T("JMPZ") }
	, { _T("JMPNZ"), JMPNZ, _T("JMPNZ") }
	, { _T("BRANCH"), BRANCH, _T("BRANCH") }
	, { _T("BRANCHZ"), BRANCHZ, _T("BRANCHZ") }
	, { _T("BRANCHNZ"), BRANCHNZ, _T("BRANCHNZ") }
	, { _T("CALL"), CALL, _T("") }
	, { _T("RET"), RET, _T("LEAVE") }
	, { _T("COMPARE"), COMPARE, _T("COMPARE") }
	, { _T("COMPAREI"), COMPAREI, _T("COMPAREI") }
	, { _T("CFETCH"), CFETCH, _T("C@") }
	, { _T("CSTORE"), CSTORE, _T("C!") }
	, { _T("ADD"), ADD, _T("+") }
	, { _T("SUB"), SUB, _T("-") }
	, { _T("MUL"), MUL, _T("*") }
	, { _T("DIV"), DIV, _T("/") }
	, { _T("LT"), LT, _T("<") }
	, { _T("EQ"), EQ, _T("=") }
	, { _T("GT"), GT, _T(">") }
	, { _T("DICTP"), DICTP, _T("DICTP") }
	, { _T("EMIT"), EMIT, _T("EMIT") }
	, { _T("ZTYPE"), ZTYPE, _T("ZTYPE") }
	, { _T("FOPEN"), FOPEN, _T("FOPEN") }
	, { _T("FREAD"), FREAD, _T("FREAD") }
	, { _T("FREADLINE"), FREADLINE, _T("FREADLINE") }
	, { _T("FWRITE"), FWRITE, _T("FWRITE") }
	, { _T("FCLOSE"), FCLOSE, _T("FCLOSE") }
	, { _T("SLITERAL"), SLITERAL, _T("") }
	, { _T("DTOR"), DTOR, _T(">R") }
	, { _T("RFETCH"), RFETCH, _T("R@") }
	, { _T("RTOD"), RTOD, _T("R>") }
	, { _T("ONEPLUS"), ONEPLUS, _T("1+") }
	, { _T("PICK"), PICK, _T("PICK") }
	, { _T("DEPTH"), DEPTH, _T("DEPTH") }
	, { _T("LSHIFT"), LSHIFT, _T("<<") }
	, { _T("RSHIFT"), RSHIFT, _T(">>") }
	, { _T("AND"), AND, _T("AND") }
	, { _T("OR"), OR, _T("OR") }
	, { _T("GETCH"), GETCH, _T("GETCH") }
	, { _T("BREAK"), BREAK, _T("BREAK") }
	, { _T("BYE"), BYE, _T("BYE") }
	, { _T(""), 0, _T("") }
};

#endif