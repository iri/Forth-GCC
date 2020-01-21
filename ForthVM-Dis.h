#include "Shared.h"
#include "logger.h"

// ------------------------------------------------------------------------------------------
// The VM
// ------------------------------------------------------------------------------------------

// CELL PC = 0;		// The "program counter"
// BYTE IR = 0;		// The "instruction register"

// CELL *dsp_init = NULL;
// CELL *rsp_init = NULL;
// CELL arg1, arg2, arg3;

// CELL *RSP = NULL; // the return stack pointer
// CELL *DSP = NULL; // the data stack pointer

// bool isEmbedded = false;
// bool isBYE = false;

// ------------------------------------------------------------------------------------------
// void init_vm()
// {
// 	dsp_init = (CELL *)&the_memory[DSP_INIT];
// 	rsp_init = (CELL *)&the_memory[RSP_INIT];
// 	DSP = dsp_init;
// 	RSP = rsp_init;
// 	isBYE = false;
// 	isEmbedded = false;
// 	PC = 0;
// }

// ------------------------------------------------------------------------------------------
void dis_start(CELL start, int num, char *bytes)
{
	char x[8];
	for (int i = 0; i < num; i++)
	{
		BYTE val = the_memory[start++];
		sprintf(x, " %02x", (int)val);
		strcat(bytes, x);
	}
}

// ------------------------------------------------------------------------------------------
void dis_PC2(int num, char *bytes)
{
	char x[8];
	for (int i = 0; i < num; i++)
	{
		BYTE val = the_memory[PC++];
		sprintf(x, " %02x", (int)val);
		strcat(bytes, x);
	}
}

// ------------------------------------------------------------------------------------------
// Where all the work is done
// ------------------------------------------------------------------------------------------
CELL dis_one(char *bytes, char *desc)
{
	IR = the_memory[PC];
	sprintf(bytes, "%04lx: %02x", PC, (int)IR);
	++PC;

	switch (IR)
	{
	case LITERAL:
		arg1 = GETAT(PC);
		// PC += CELL_SZ;
		// push(arg1);
		dis_PC2(CELL_SZ, bytes);
		sprintf(desc, "PUSH %ld (%0lx)", arg1, arg1);
		return CELL_SZ;

	case CLITERAL:
		arg1 = the_memory[PC];
		// PC++;
		// push(arg1);
		dis_PC2(1, bytes);
		sprintf(desc, "CPUSH %ld", arg1);
		return 1;

	case FETCH:
		// arg1 = GETTOS();
		// arg2 = GETAT(arg1);
		// SETTOS(arg2);
		sprintf(desc, "FETCH");
		return 0;

	case STORE:
		// arg1 = pop();
		// arg2 = pop();
		// SETAT(arg1, arg2);
		sprintf(desc, "STORE");
		return 0;

	case SWAP:
		// arg1 = GET2ND();
		// arg2 = GETTOS();
		// SET2ND(arg2);
		// SETTOS(arg1);
		sprintf(desc, "SWAP");
		return 0;

	case DROP:
		// arg1 = pop();
		sprintf(desc, "DROP");
		return 0;

	case DUP:
		// arg1 = GETTOS();
		// push(arg1);
		sprintf(desc, "DUP");
		return 0;

	case OVER:
		// arg1 = GET2ND();
		// push(arg1);
		sprintf(desc, "OVER");
		return 0;

	case PICK:
		// arg1 = pop();
		// arg2 = *(DSP - arg1);
		// push(arg2);
		sprintf(desc, "PICK");
		return 0;

	case JMP:
		// PC = GETAT(PC);
		arg1 = GETAT(PC);
		sprintf(desc, "JMP %04lx", arg1);
		if (the_memory[arg1] == DICTP)
		{
			arg2 = GETAT(arg1+1);
			DICT_T *dp = (DICT_T *)&(the_memory[arg2]);
			sprintf(desc, "JMP %s (%04lx)\n;", dp->name, arg1);
		}
		dis_PC2(CELL_SZ, bytes);
		return CELL_SZ;

	case JMPZ:
		// if (pop() == 0)
		// {
		// 	PC = GETAT(PC);
		// }
		// else
		// {
		// 	PC += CELL_SZ;
		// }
		sprintf(desc, "JMPZ %04lx", GETAT(PC));
		dis_PC2(CELL_SZ, bytes);
		return CELL_SZ;

	case JMPNZ:
		sprintf(desc, "JMPNZ %04lx", GETAT(PC));
		dis_PC2(CELL_SZ, bytes);
		// arg1 = pop();
		// if (arg1 != 0)
		// {
		// 	PC = GETAT(PC);
		// }
		// else
		// {
		// 	PC += CELL_SZ;
		// }
		return CELL_SZ;

	case BRANCH:
		// PC += GETAT(PC);
		arg1 = GETAT(PC);
		sprintf(desc, "BRANCH %04lx", arg1);
		dis_PC2(CELL_SZ, bytes);
		return CELL_SZ;

	case BRANCHZ:
		// arg1 = GETAT(PC);
		// if (pop() == 0)
		// {
		// 	arg1 = GETAT(PC);
		// 	PC += arg1;
		// }
		// else
		// {
		// 	PC += CELL_SZ;
		// }
		sprintf(desc, "BRANCHZ %04lx", GETAT(PC));
		dis_PC2(CELL_SZ, bytes);
		return CELL_SZ;

	case BRANCHNZ:
		arg1 = GETAT(PC);
		// if (pop() != 0)
		// {
		// 	arg1 = GETAT(PC);
		// 	PC += arg1;
		// }
		// else
		// {
		// 	PC += CELL_SZ;
		// }
		// isBYE = true;
		sprintf(desc, "BRANCHNZ %04lx", arg1);
		dis_PC2(CELL_SZ, bytes);
		return CELL_SZ;

	case CALL:
		arg1 = GETAT(PC);
		// PC += CELL_SZ;
		// rpush(PC);
		// PC = arg1;
		arg2 = GETAT(arg1+1);
		DICT_T *dp = (DICT_T *)&(the_memory[arg2]);
		sprintf(desc, "CALL %s (%04lx)", dp->name, arg1);
		dis_PC2(CELL_SZ, bytes);
		return CELL_SZ;

	case RET:
		// if (RSP == rsp_init)
		// {
		// 	if (isEmbedded)
		// 	{
		// 		isBYE = true;
		// 	}
		// 	else
		// 	{
		// 		PC = 0;
		// 	}
		// }
		// else
		// {
		// 	PC = rpop();
		// }
		sprintf(desc, "RET");
		if (the_memory[PC] == DICTP)
		{
			strcat(desc, "\n;");
		}
		return 0;

	case COMPARE:
		// arg2 = pop();
		// arg1 = pop();
		// {
		// 	char *cp1 = (char *)&the_memory[arg1];
		// 	char *cp2 = (char *)&the_memory[arg2];
		// 	arg3 = strcmp(cp1, cp2) ? 0 : 1;
		// 	push(arg3);
		// }
		// isBYE = true;
		sprintf(desc, "COMPARE");
		return 0;

	case COMPAREI:
		// arg2 = pop();
		// arg1 = pop();
		// {
		// 	char *cp1 = (char *)&the_memory[arg1];
		// 	char *cp2 = (char *)&the_memory[arg2];
		// 	arg3 = _strcmpi(cp1, cp2) ? 0 : 1;
		// 	push(arg3);
		// }
		// isBYE = true;
		sprintf(desc, "COMPAREI");
		return 0;

	case SLITERAL:
		// count, bytes, NULL - NULL delimited counted string
		// 0100 0101 0102 0103 0104 0105
		//   07   03   65   66   67   00
		// SLIT   03    A    B    C   00
		// PC starts at 0101, should be set to 0106

		arg1 = the_memory[PC]; // count-byte (and the beginning of the counted string)
		arg2 = arg1 + 2;  // count-byte + count + NULL
		// PC += arg2;
		// push(arg1);
		sprintf(desc, "SLITERAL (%04lx) [%s]", PC+1, (char *)&the_memory[PC+1]);
		dis_PC2(arg2, bytes);
		return PC-arg1;

	case CFETCH:
		// arg1 = GETTOS();
		// SETTOS(the_memory[arg1]);
		sprintf(desc, "CFETCH");
		return 0;

	case CSTORE:
		// arg1 = pop();
		// arg2 = pop();
		// the_memory[arg1] = (BYTE)arg2;
		sprintf(desc, "CSTORE");
		return 0;

	case ADD:
		// arg1 = pop();
		// arg2 = pop();
		// push(arg2 + arg1);
		sprintf(desc, "ADD");
		return 0;

	case SUB:
		// arg1 = pop();
		// arg2 = pop();
		// push(arg2 - arg1);
		sprintf(desc, "SUB");
		return 0;

	case MUL:
		// arg1 = pop();
		// arg2 = pop();
		// push(arg2 * arg1);
		sprintf(desc, "MUL");
		return 0;

	case DIV:
		// arg1 = pop();
		// arg2 = pop();
		// push(arg2 / arg1);
		sprintf(desc, "DIV");
		return 0;

	case LT:
		// arg1 = pop();
		// arg2 = pop();
		// push(arg2 < arg1 ? 1 : 0);
		sprintf(desc, "LT");
		return 0;

	case EQ:
		// arg1 = pop();
		// arg2 = pop();
		// push(arg2 == arg1 ? 1 : 0);
		sprintf(desc, "EQ");
		return 0;

	case GT:
		// arg1 = pop();
		// arg2 = pop();
		// push(arg2 > arg1 ? 1 : 0);
		sprintf(desc, "GT");
		return 0;

	case DICTP:
		arg1 = GETAT(PC);
		// PC += CELL_SZ;
		sprintf(desc, "DICTP %s (%04lx)", &(the_memory[arg1+10]), arg1);
		dis_PC2(CELL_SZ, bytes);
		return CELL_SZ;

	case EMIT:
		// arg1 = pop();
		// putchar(arg1);
		sprintf(desc, "EMIT");
		return 0;

	case ZTYPE:
		// TOS is addr of a NULL terminated string, NO count
		// arg1 = pop();
		// {
		// 	char *cp = (char *)&the_memory[arg1];
		// 	printf("%s", cp);
		// }
		sprintf(desc, "ZTYPE");
		return 0;

	case FOPEN:
		// ( name mode -- fp status ) - mode: 0 = read, 1 = write
		// arg2 = pop();
		// arg1 = pop();
		// {
		// 	char *fileName = (char *)&the_memory[arg1 + 1];
		// 	char mode[4];
		// 	sprintf(mode, "%cb", arg2 == 0 ? 'r' : 'w');
		// 	FILE *fp = fopen(fileName, mode);
		// 	push((int)fp);
		// 	push(fp != NULL ? 0 : 1);
		// }
		sprintf(desc, "FOPEN");
		return 0;

	case FREAD:			// ( addr num fp -- count ) - fp == 0 means STDIN
		// arg3 = pop(); -- FP
		// arg2 = pop(); -- NUM
		// arg1 = pop(); -- ADDR
		// {
		// 	BYTE *pBuf = (BYTE *)&the_memory[arg1 + 1];
		// 	int num = fread(pBuf, sizeof(BYTE), arg2, (arg3 == 0) ? stdin : (FILE *)arg3);
		// 	push(num);
		// }
		sprintf(desc, "FREAD");
		return 0;

	case FREADLINE:
		// Puts a counted string at addr
		// ( addr num fp -- count )
		// arg3 = pop(); -- FP (0 means STDIN)
		// arg2 = pop(); -- NUM
		// arg1 = pop(); -- ADDR
		// {
		// 	char *pBuf = (char *)&the_memory[arg1 + 1];
		// 	FILE *fp = arg3 ? (FILE *)arg3 : stdin;
		// 	if (fgets(pBuf, arg2, fp) != pBuf)
		// 	{
		// 		*pBuf = (char)NULL;
		// 	}
		// 	arg2 = (CELL)strlen(pBuf);
		// 	// Strip off any trailing newline
		// 	if ((arg2 > 0) && (pBuf[arg2 - 1] == '\n'))
		// 	{
		// 		pBuf[--arg2] = (char)NULL;
		// 	}
		// 	*(--pBuf) = (char)arg2;
		// 	push(arg2);
		// }
		sprintf(desc, "FREADLINE");
		return 0;

	case FWRITE:
		// ( addr num fp -- count ) - fp == 0 means STDOUT
		// arg3 = pop();
		// arg2 = pop();
		// arg1 = pop();
		// {
		// 	BYTE *pBuf = (BYTE *)&the_memory[arg1];
		// 	int num = fwrite(pBuf, sizeof(BYTE), arg2, arg3 == 0 ? stdin : (FILE *)arg3);
		// 	push(num);
		// }
		sprintf(desc, "FWRITE");
		return 0;

	case FCLOSE:
		// arg1 = pop();
		// if (arg1 != 0)
		// {
		// 	fclose((FILE *)arg1);
		// }
		sprintf(desc, "FCLOSE");
		return 0;

	case GETCH:
		// arg1 = getchar();
		// push(arg1);
		sprintf(desc, "GETCH");
		return 0;

	case DTOR:
		// arg1 = pop();
		// rpush(arg1);
		sprintf(desc, "DTOR");
		return 0;

	case RFETCH:
		// push(*RSP);
		sprintf(desc, "RFETCH");
		break;

	case RTOD:
		// arg1 = rpop();
		// push(arg1);
		sprintf(desc, "RTOD");
		return 0;

	case ONEPLUS:
		// (*DSP)++;
		sprintf(desc, "ONEPLUS");
		return 0;

	case DEPTH:
		// arg1 = DSP - dsp_init;
		// push(arg1);
		sprintf(desc, "DEPTH");
		return 0;

	case LSHIFT:
		// arg1 = pop();
		// arg2 = pop();
		// push(arg2 << arg1);
		sprintf(desc, "LSHIFT");
		return 0;

	case RSHIFT:
		// arg1 = pop();
		// arg2 = pop();
		// push(arg2 >> arg1);
		sprintf(desc, "RSHIFT");
		return 0;

	case AND:
		// arg1 = pop();
		// arg2 = pop();
		// push(arg2 & arg1);
		sprintf(desc, "AND");
		return 0;

	case OR:
		// arg1 = pop();
		// arg2 = pop();
		// push(arg2 | arg1);
		sprintf(desc, "OR");
		return 0;

	case BREAK:
	// {
	// 	arg1 = the_memory[ADDR_HERE];
	// 	arg2 = the_memory[ADDR_LAST];
	// 	arg3 = arg2 - arg1;
	// }
		sprintf(desc, "BREAK");
		return 0;

	case BYE:
		// isBYE = true;
		sprintf(desc, "BYE");
		return 0;

	case RESET:
	default:
		// DSP = dsp_init;
		// RSP = rsp_init;
		// PC = 0;
		// isBYE = isEmbedded;
		sprintf(desc, "RESET");
		return 0;
	}
	return 0;
}

// ------------------------------------------------------------------------------------------
void dis_dict(FILE *write_to, CELL dict_addr)
{
	char bytes[128], desc[128];
	DICT_T *dp = (DICT_T *)&the_memory[dict_addr];
	DICT_T *next_dp = (DICT_T *)&the_memory[dp->next];
	CELL addr = dict_addr;

	if (dp->next == 0)
	{
		sprintf(bytes, "%04lx:", addr);
		dis_start(addr, CELL_SZ, bytes);
		fprintf(write_to, "%-32s ; End.\n", bytes);
		return;
	}

	// Next
	sprintf(bytes, "%04lx:", addr);
	dis_start(addr, CELL_SZ, bytes);
	sprintf(desc, "%s - (next: %04lx %s)", dp->name, dp->next, (next_dp->next > 0) ? next_dp->name : "<end>");
	fprintf(write_to, "%-32s ; %s\n", bytes, desc);
	addr += CELL_SZ;

	// XT, Flags
	sprintf(bytes, "%04lx:", addr);
	dis_start(addr, CELL_SZ+1, bytes);
	sprintf(desc, "XT=%04lx, flags=%02x", dp->XT, dp->flags);
	fprintf(write_to, "%-32s ; %s\n", bytes, desc);
	addr += CELL_SZ+1;

	// Name
	sprintf(bytes, "%04lx: %02x", addr++, dp->len);
	dis_start(addr, dp->len+1, bytes);
	sprintf(desc, "%d, %s", (int)dp->len, dp->name);
	fprintf(write_to, "%-32s ; %s\n;\n", bytes, desc);
}

// ------------------------------------------------------------------------------------------
void dis_vm(FILE *write_to)
{
	int here = GETAT(ADDR_HERE);
	char bytes[128], desc[128];

	// Initial JMP
	PC = 0;
	dis_one(bytes, desc);
	fprintf(write_to, "%-32s ; %s\n", bytes, desc);

	PC = 32;
	// Code
	while (PC < here)
	{
		dis_one(bytes, desc);
		fprintf(write_to, "%-32s ; %s\n", bytes, desc);
	}

	fprintf(write_to, ";\n; End of code, Dictionary:\n;\n");

	// Dictionary
	PC = GETAT(ADDR_LAST);
	while (PC > 0)
	{
		dis_dict(write_to, PC);
		PC = GETAT(PC);
	}
}
