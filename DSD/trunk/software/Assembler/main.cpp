// ============================================================================
//        __
//   \\__/ o\    (C) 2016  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// A64 - Assembler
//  - 64 bit CPU
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                                                                          
// ============================================================================
//
#include "stdafx.h"

#define MAX_PASS  6

int gCpu = 888;
int verbose = 1;
int debug = 1;
int listing = 1;
int binary_out = 1;
int verilog_out = 1;
int elf_out = 1;
int rel_out = 0;
int coe_out = 0;
int code_bits = 32;
int data_bits = 32;
int pass;
int lineno;
char *inptr;
char *stptr;
int token;
int phasing_errors;
int bGen = 0;
char fSeg = 0;
int segment;
int segprefix = -1;
int segmodel = 0;
int64_t code_address;
int64_t data_address;
int64_t bss_address;
int64_t start_address;
FILE *ofp, *vfp;
int regno;
char first_org = 1;
char current_label[500];

char buf[10000];
char masterFile[10000000];
char segmentFile[10000000];
int NumSections = 12;
clsElf64Section sections[12];
NameTable nmTable;
char codebuf[10000000];
char rodatabuf[10000000];
char databuf[10000000];
char bssbuf[10000000];
char tlsbuf[10000000];
uint8_t binfile[10000000];
int binndx;
int64_t binstart;
int mfndx;
int codendx;
int datandx;
int rodatandx;
int tlsndx;
int bssndx;
SYM *lastsym;
int isInitializationData;
int num_bytes;
int num_insns;
HTBLE hTable[100000];
int htblmax;
int processOpt;
int expandedBlock;
int expand_flag;
int compress_flag;
void emitCode(int cd);
void emitAlignedCode(int cd);
void process_shifti(int oc,int fn);
void processFile(char *fname, int searchincl);
void bump_address();
extern void Table888_bump_address();
extern void searchenv(char *filename, char *envname, char **pathname);
extern void Table888mmu_processMaster();
extern void Friscv_processMaster();
extern void FISA64_processMaster();
extern void Thor_processMaster();
extern void dsd6_processMaster();
extern void dsd7_processMaster();
extern void SymbolInit();

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

void displayHelp()
{
     printf("a64 [options] file\r\n");
     printf("    +v      = verbose output\r\n");
     printf("    +r      = relocatable output\r\n");
     printf("    -s      = non-segmented\r\n");
     printf("    +g[n]   = cpu version 8=Table888, 9=Table888mmu V=RISCV 6=FISA64 T=Thor\r\n");
     printf("                          D=DSD6 7=DSD7\r\n");
     printf("    -o[bvlc] = suppress output file b=binary, v=verilog, l=listing, c=coe\r\n");
}

int hcmp(const void *a1, const void *b1)
{
    HTBLE *a = (HTBLE *)a1;
    HTBLE *b = (HTBLE *)b1;
    return (a->count < b->count) ? 1 : (a->count==b->count) ? 0 : -1;
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

void DumphTable()
{
    int nn;
    HTBLE *pt;

   pt = (HTBLE *)hTable;

   // Sort the table (already sorted)
//   qsort(pt, htblmax, sizeof(HTBLE), hcmp);
    
    fprintf(ofp, "%d compressable instructions\n", htblmax);
    fprintf(ofp, "The top 1024 are:\n", htblmax);
    fprintf(ofp, "Comp  Opcode  Count\n"); 
    for (nn = 0; nn < htblmax && nn < 1024; nn++) {
        fprintf(ofp, " %03X %08X %d\n", nn, hTable[nn].opcode, hTable[nn].count);
    }
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

int processOptions(int argc, char **argv)
{
    int nn, mm;

    segmodel = 0;    
    nn = 1;
    do {
        if (nn >= argc-1)
           break;
        if (argv[nn][0]=='-') {
           if (argv[nn][1]=='o') {
               mm = 2;
               while(argv[nn][mm] && !isspace(argv[nn][mm])) {
                   if (argv[nn][mm]=='b')
                       binary_out = 0;
                   else if (argv[nn][mm]=='l')
                       listing = 0;
                   else if (argv[nn][mm]=='v')
                       verilog_out = 0;
                   else if (argv[nn][mm]=='e')
                       elf_out = 0;
               }
           }
           if (argv[nn][1]=='s')
               fSeg = 0;
           nn++;
        }
        else if (argv[nn][0]=='+') {
           mm = 2;
           if (argv[nn][1]=='r') {
               rel_out = 1;
           }
           if (argv[nn][1]=='s')
               fSeg = 1;
           if (argv[nn][1]=='g') {
              if (argv[nn][2]=='9') {
                 gCpu=889;
                 fSeg = 1;
              }
              if (argv[nn][2]=='V') {
                 gCpu = 5;
              }
              if (argv[nn][2]=='6') {
                 gCpu = 64;
              }
              if (argv[nn][2]=='7') {
                 gCpu = 7;
              }
              if (argv[nn][2]=='T') {
                 gCpu = 4;
                 if (argv[nn][3]=='2') {
                   segmodel = 2;
                 }
              }
              if (argv[nn][2]=='D') {
                 gCpu = 14;
              }
           }
           nn++;
        }
        else break;
    } while (1);
    return nn;
}

// ---------------------------------------------------------------------------
// Emit a byte, for DSD7 a byte is 16 bits.
// ---------------------------------------------------------------------------

void emitByte(int64_t cd)
{
     if (segment < 5) {
		 if (gCpu==7)
			sections[segment].AddChar(cd);
		 else
			sections[segment].AddByte(cd);
	 }
    if (segment == codeseg || segment == rodataseg) {
		if (gCpu==7) {
			binfile[binndx] = cd & 255LL;
			binndx++;
			binfile[binndx] = (cd >> 8) & 255LL;
			binndx++;
		}
		else {
			binfile[binndx] = cd & 255LL;
			binndx++;
		}
    }
    if (segment==bssseg) {
       bss_address++;
    }
    else if (segment==dataseg)
         data_address++;
    else
        code_address++;
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

void emitChar(int64_t cd)
{
     emitByte(cd & 255LL);
     emitByte((cd >> 8) & 255LL);
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

void emitHalf(int64_t cd)
{
	if (gCpu==7) {
		emitByte(cd & 65535LL);
		emitByte((cd >> 16) & 65535LL);
	}
  else if (gCpu==5) {
     emitByte(cd & 255LL);
     emitByte((cd >> 8) & 255LL);
  }
  else {
     emitChar(cd & 65535LL);
     emitChar((cd >> 16) & 65535LL);
  }
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

void emitWord(int64_t cd)
{
  if (gCpu==5) {
     emitHalf(cd & 0xFFFFLL);
     emitHalf((cd >> 16) & 0xFFFFLL);
  }
  else {
     emitHalf(cd & 0xFFFFFFFFLL);
     emitHalf((cd >> 32) & 0xFFFFFFFFLL);
  }
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------

void emitCode(int cd)
{
     emitByte(cd);
}

// ----------------------------------------------------------------------------
// Process a public declaration.
//     public code myfn
// ----------------------------------------------------------------------------

void process_public()
{
    SYM *sym;
    int64_t ca;

    NextToken();
    if (token==tk_code) {
        segment = codeseg;
    }
    else if (token==tk_rodata) {
         segment = rodataseg;
    }
    else if (token==tk_data) {
         if (isInitializationData)
             segment = rodataseg;
         else
             segment = dataseg;
    }
    else if (token==tk_bss) {
         segment = bssseg;
    }
    else
        prevToken();
    bump_address();
//    if (segment==bssseg)
//        ca = bss_address;
//    else
//        ca = code_address;
    switch(segment) {
    case codeseg:
         ca = code_address;
         ca = sections[0].address;
         break;
    case rodataseg:
         ca = sections[1].address;
         break;
    case dataseg:
         ca = sections[2].address;
         break;
    case bssseg:
         ca = sections[3].address;
         break;
    case tlsseg:
         ca = sections[4].address;
         break;
    }
    NextToken();
    if (token != tk_id) {
        printf("Identifier expected. Token %d\r\n", token);
        printf("Line:%.60s", stptr);
    }
    else {
         if (isInitializationData) {
             ScanToEOL();
             inptr++;
             return;
         }
        sym = find_symbol(lastid);
        if (pass == 4) {
            if (sym) {
                if (sym->defined)
                    printf("Symbol (%s) already defined.\r\n", lastid);
            }
            else {
                sym = new_symbol(lastid);
            }
            if (sym) {
                sym->defined = 1;
                sym->value = ca;
                sym->segment = segment;
                sym->scope = 'P';
            }
        }
        else if (pass > 4) {
			if (!sym)
			    printf("Symbol (%s) not defined.\r\n", lastid);
			else {
	            if (sym->value != ca) {
	                phasing_errors++;
	                sym->phaserr = '*';
	                 if (bGen) printf("%s=%06I64x ca=%06I64x\r\n", nmTable.GetName(sym->name),  sym->value, code_address);
	            }
	            else
	                 sym->phaserr = ' ';
	            sym->value = ca;
        	}
        }
        strcpy_s(current_label, sizeof(current_label), lastid);
    }
    ScanToEOL();
    inptr++;
}

// ----------------------------------------------------------------------------
// extern somefn
// ----------------------------------------------------------------------------

void process_extern()
{
    SYM *sym;

//    printf("<process_extern>");
    NextToken();
    if (token != tk_id)
        printf("Expecting an identifier.\r\n");
    else {
        sym = find_symbol(lastid);
        if (pass == 4) {
            if (sym) {
            
            }
            else {
                sym = new_symbol(lastid);
            }
            if (sym) {
                sym->defined = 0;
                sym->value = 0;
                sym->segment = segment;
                sym->scope = 'P';
                sym->isExtern = 1;
            }
        }
        else if (pass > 4) {
        }
        NextToken();
        if (token==':') {
           NextToken();
           if (sym)
               sym->bits = (int)expr();
        }
        else {
//    printf("J:sym=%p lastid=%s", sym, lastid);
           prevToken();
            if (sym)
               sym->bits = 32;
        }
    }
    ScanToEOL();
    inptr++;
//    printf("</process_extern>\r\n");
}

// ----------------------------------------------------------------------------
// .org $23E200
// .org is ignored for relocatable files.
// ----------------------------------------------------------------------------

void process_org()
{
    int64_t new_address;
	int mul = 1;

	if (gCpu==7)
		mul = 2;
    NextToken();
    new_address = expr();
    if (!rel_out) {
        if (segment==dataseg) {
            data_address = new_address*mul;
            sections[segment].address = new_address*mul;
        }
        else if (segment==bssseg || segment==tlsseg) {
            bss_address = new_address*mul;
            sections[segment].address = new_address*mul;
        }
        else {
            if (first_org && segment==codeseg) {
               code_address = new_address;
               start_address = new_address*mul;
               sections[0].address = new_address*mul;
               first_org = 0;
            }
            else {
                 // Ignore the org directive in initialized data area of rodata
                 if (!isInitializationData)
                while(sections[0].address < new_address*mul)
                    emitByte(0x00);
            }
        }
    }
    ScanToEOL();
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

void process_align()
{
    int64_t v;
    
    NextToken();
    v = expr();
    if (segment == codeseg || segment == rodataseg || segment == dataseg || segment==bssseg || segment==tlsseg) {
        while (sections[segment].address % v)
            emitByte(0x00);
    }
//    if (segment==bssseg) {
//        while (bss_address % v)
//            emitByte(0x00);
//    }
//    else {
//        while (code_address % v)
//            emitByte(0x00);
//    }
}

// ----------------------------------------------------------------------------
//	hint #1
//
// Process a compiler hint. Normally these instructions don't make it through
// the compile stage, but in case one does... It is just ignored.
// ----------------------------------------------------------------------------

void process_hint()
{
    int64_t v;
    
    NextToken();
    v = expr();
}

// ----------------------------------------------------------------------------
// code 0x8000 to 0xFFFF
// code 24 bits
// code
// ----------------------------------------------------------------------------

void process_code()
{
    int64_t st, nd;

    segment = codeseg;
    NextToken();
    if (token==tk_eol) {
        prevToken();
        return;
    }
    st = expr();
    if (token==tk_bits) {
        code_bits = (int)st;
        return;
    }
    if (token==tk_to) {
        NextToken();
        nd = expr();
        code_bits = (int)log((double)nd+1)/log(2.0);    // +1 to round up a little bit
    }
}

// ----------------------------------------------------------------------------
// data 0x8000 to 0xFFFF
// data 24 bits
// data
// ----------------------------------------------------------------------------

void process_data(int seg)
{
    int64_t st, nd;

    segment = seg;
    NextToken();
    if (token==tk_eol) {
        prevToken();
        return;
    }
    st = expr();
    if (token==tk_bits) {
        data_bits = (int)st;
        return;
    }
    if (token==tk_to) {
        NextToken();
        nd = expr();
        data_bits = (int)log((double)nd+1)/log((double)2.0);    // +1 to round up a little bit
    }
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

void process_db()
{
    int64_t val;

    SkipSpaces();
    //NextToken();
    while(token!=tk_eol) {
        SkipSpaces();
        if (*inptr=='\n') break;
        if (*inptr=='"') {
            inptr++;
            while (*inptr!='"') {
                if (*inptr=='\\') {
                    inptr++;
                    switch(*inptr) {
                    case '\\': emitByte('\\'); inptr++; break;
                    case 'r': emitByte(0x13); inptr++; break;
                    case 'n': emitByte(0x0A); inptr++; break;
                    case 'b': emitByte('\b'); inptr++; break;
                    case '"': emitByte('"'); inptr++; break;
                    default: inptr++; break;
                    }
                }
                else {
                    emitByte(*inptr);
                    inptr++;
                }
            }
            inptr++;
        }
/*
        else if (*inptr=='\'') {
            inptr++;
            emitByte(*inptr);
            inptr++;
            if (*inptr!='\'') {
                printf("Missing ' in character constant.\r\n");
            }
        }
*/
        else {
            NextToken();
            val = expr();
            emitByte(val & 255);
            prevToken();
        }
        SkipSpaces();
        if (*inptr!=',')
            break;
        inptr++;
    }
    ScanToEOL();
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

void process_dc()
{
    int64_t val;

    SkipSpaces();
    while(token!=tk_eol) {
        SkipSpaces();
        if (*inptr=='"') {
            inptr++;
            while (*inptr!='"') {
                if (*inptr=='\\') {
                    inptr++;
                    switch(*inptr) {
                    case '\\': emitChar('\\'); inptr++; break;
                    case 'r': emitChar(0x13); inptr++; break;
                    case 'n': emitChar(0x0A); inptr++; break;
                    case 'b': emitChar('\b'); inptr++; break;
                    case '"': emitChar('"'); inptr++; break;
                    default: inptr++; break;
                    }
                }
                else {
                    emitChar(*inptr);
                    inptr++;
                }
            }
            inptr++;
        }
        else if (*inptr=='\'') {
            inptr++;
            emitChar(*inptr);
            inptr++;
            if (*inptr!='\'') {
                printf("Missing ' in character constant.\r\n");
            }
        }
        else {
             NextToken();
            val = expr();
            emitChar(val);
            prevToken();
        }
        SkipSpaces();
        if (*inptr!=',')
            break;
        inptr++;
    }
    ScanToEOL();
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

void process_dh()
{
    int64_t val;

    SkipSpaces();
    while(token!=tk_eol) {
        SkipSpaces();
        if (*inptr=='"') {
            inptr++;
            while (*inptr!='"') {
                if (*inptr=='\\') {
                    inptr++;
                    switch(*inptr) {
                    case '\\': emitHalf('\\'); inptr++; break;
                    case 'r': emitHalf(0x13); inptr++; break;
                    case 'n': emitHalf(0x0A); inptr++; break;
                    case 'b': emitHalf('\b'); inptr++; break;
                    case '"': emitHalf('"'); inptr++; break;
                    default: inptr++; break;
                    }
                }
                else {
                    emitHalf(*inptr);
                    inptr++;
                }
            }
            inptr++;
        }
        else if (*inptr=='\'') {
            inptr++;
            emitHalf(*inptr);
            inptr++;
            if (*inptr!='\'') {
                printf("Missing ' in character constant.\r\n");
            }
        }
        else {
             NextToken();
            val = expr();
            emitHalf(val);
            prevToken();
        }
        SkipSpaces();
        if (*inptr!=',')
            break;
        inptr++;
    }
    ScanToEOL();
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

void process_dh_htbl()
{
	int nn;
  
	if (gCpu==7)
		emitByte(htblmax > 1024 ? 1024 : htblmax);
	else
		emitHalf(htblmax > 1024 ? 1024 : htblmax);
	for (nn = 0; nn < htblmax && nn < 1024; nn++) {
		emitHalf(hTable[nn].opcode);
	}
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

void process_dw()
{
    int64_t val;

    SkipSpaces();
    while(token!=tk_eol) {
        SkipSpaces();
        if (*inptr=='"') {
            inptr++;
            while (*inptr!='"') {
                if (*inptr=='\\') {
                    inptr++;
                    switch(*inptr) {
                    case '\\': emitWord('\\'); inptr++; break;
                    case 'r': emitWord(0x13); inptr++; break;
                    case 'n': emitWord(0x0A); inptr++; break;
                    case 'b': emitWord('\b'); inptr++; break;
                    case '"': emitWord('"'); inptr++; break;
                    default: inptr++; break;
                    }
                }
                else {
                    emitWord(*inptr);
                    inptr++;
                }
            }
            inptr++;
        }
        else if (*inptr=='\'') {
            inptr++;
            emitWord(*inptr);
            inptr++;
            if (*inptr!='\'') {
                printf("Missing ' in character constant.\r\n");
            }
        }
        else {
             NextToken();
            val = expr();
    // A pointer to an object might be emitted as a data word.
    if (bGen && lastsym)
    if( lastsym->segment < 5)
    sections[segment+7].AddRel(sections[segment].index,((int64_t)(lastsym->ord+1) << 32) | 6 | (lastsym->isExtern ? 128 : 0));
            emitWord(val);
            prevToken();
        }
        SkipSpaces();
        if (*inptr!=',')
            break;
        inptr++;
    }
    ScanToEOL();
}

// ----------------------------------------------------------------------------
// fill.b 252,0x00
// ----------------------------------------------------------------------------

void process_fill()
{
    char sz = 'b';
    int64_t count;
    int64_t val;
    int64_t nn;

    if (*inptr=='.') {
        inptr++;
        if (strchr("bchwBCHW",*inptr)) {
            sz = tolower(*inptr);
            inptr++;
        }
        else
            printf("Illegal fill size.\r\n");
    }
    SkipSpaces();
    NextToken();
    count = expr();
    prevToken();
    need(',');
    NextToken();
    val = expr();
    prevToken();
    for (nn = 0; nn < count; nn++)
        switch(sz) {
        case 'b': emitByte(val); break;
        case 'c': emitChar(val); break;
        case 'h': emitHalf(val); break;
        case 'w': emitWord(val); break;
        }
}

// ----------------------------------------------------------------------------
// Bump up the address to the next aligned code address.
// ----------------------------------------------------------------------------

void bump_address()
{
     if (gCpu==888 || gCpu==889)
        Table888_bump_address();
}

// ----------------------------------------------------------------------------
// label:
// ----------------------------------------------------------------------------

void process_label()
{
    SYM *sym;
    static char nm[500];
    int64_t ca;
    int64_t val=0;
    int isEquate;
    int shft = 0;

	if (gCpu==7)
		shft = 1;

//    printf("<process_label>");
    isEquate = 0;
    // Bump up the address to align it with a valid code address if needed.
    bump_address();
    switch(segment) {
    case codeseg:
         ca = code_address >> shft;
         ca = sections[0].address >> shft;
         break;
    case rodataseg:
         ca = sections[1].address >> shft;
         break;
    case dataseg:
         ca = sections[2].address >> shft;
         break;
    case bssseg:
         ca = sections[3].address >> shft;
         break;
    case tlsseg:
         ca = sections[4].address >> shft;
         break;
    }
//    if (segment==bssseg)
//       ca = bss_address;
//    else
//        ca = code_address;
    if (lastid[0]=='.') {
        sprintf_s(nm, sizeof(nm), "%s%s", current_label, lastid);
    }
    else { 
        strcpy_s(current_label, sizeof(current_label), lastid);
        strcpy_s(nm, sizeof(nm), lastid);
    }
    if (strcmp("end_init_data", nm)==0)
       isInitializationData = 0;
    NextToken();
//    SkipSpaces();
    if (token==tk_equ || token==tk_eq) {
        NextToken();
        val = expr();
        isEquate = 1;
    }
    else prevToken();
//    if (token==tk_eol)
//       prevToken();
    //else if (token==':') inptr++;
    // ignore the labels in initialization data
    if (isInitializationData)
       return;
    sym = find_symbol(nm);
    if (pass==4) {
        if (sym) {
            if (sym->defined) {
                if (sym->value != val) {
                    printf("Label %s already defined.\r\n", nm);
                    printf("Line %d: %.60s\r\n", lineno, stptr);
                }
            }
            sym->defined = 1;
            if (isEquate) {
                sym->value = val;
                sym->segment = constseg;
                sym->bits = (int)ceil(log(fabs((double)val)+1) / log(2.0))+1;
            }
            else {
                sym->value = ca;
                sym->segment = segment;
                if (segment==codeseg)
                   sym->bits = code_bits;
                else
                    sym->bits = data_bits;
            }
        }
        else {
            sym = new_symbol(nm);    
            sym->defined = 1;
            if (isEquate) {
                sym->value = val;
                sym->segment = constseg;
                sym->bits = (int)ceil(log(fabs((double)val)+1) / log(2.0))+1;
            }
            else {
                sym->value = ca;
                sym->segment = segment;
                if (segment==codeseg)
                   sym->bits = code_bits;
                else
                    sym->bits = data_bits;
            }
        }
    }
    else if (pass>4) {
         if (!sym) {
            printf("Internal error: SYM is NULL.\r\n");
            printf("Couldn't find <%s>\r\n", nm);
         }
         else {
             if (isEquate) {
                 sym->value = val;
             }
             else {
                 if (sym->value != ca) {
                     phasing_errors++;
                     sym->phaserr = '*';
                     if (bGen) printf("%s=%06llx ca=%06llx\r\n", nmTable.GetName(sym->name),  sym->value, code_address);
                 }
                 else
                     sym->phaserr = ' ';
                 sym->value = ca;
             }
         }
    }
    if (strcmp("begin_init_data", nm)==0)
       isInitializationData = 1;
//    printf("</process_ label>\r\n");
}

// ----------------------------------------------------------------------------
// Group and reorder the segments in the master file.
//     code          placed first
//     rodata        followed by
//     data
//     tls
// ----------------------------------------------------------------------------

void processSegments()
{
    char *pinptr;
    int segment = codeseg;
    int inComment;
    
    if (verbose)
       printf("Processing segments.\r\n");
    inptr = &masterFile[0];
    pinptr = inptr;
    codendx = 0;
    datandx = 0;
    rodatandx = 0;
    tlsndx = 0;
    bssndx = 0;
    memset(codebuf,0,sizeof(codebuf));
    memset(databuf,0,sizeof(databuf));
    memset(rodatabuf,0,sizeof(rodatabuf));
    memset(tlsbuf,0,sizeof(tlsbuf));
    memset(bssbuf,0,sizeof(bssbuf));
    inComment = 0;

    while (*inptr) {
        SkipSpaces();
        if (*inptr==';')
        	goto j1;
        if (inptr[0]=='/' && inptr[1]=='/')
        	goto j1;
//        if (inptr[0]=='/' && inptr[1]=='*') {
//        	inComment = 1;
//        	goto j1;
//		}
//		if (inComment && inptr[0]=='*' && inptr[1]=='/')
//			inComment = 0;
//		if (inComment)
//			goto j1;
        if (*inptr=='.') inptr++;
        if ((strnicmp(inptr,"code",4)==0) && !isIdentChar(inptr[4])) {
            segment = codeseg;
        }
        else if ((strnicmp(inptr,"data",4)==0) && !isIdentChar(inptr[4])) {
            segment = dataseg;
        }
        else if ((strnicmp(inptr,"rodata",6)==0) && !isIdentChar(inptr[6])) {
            segment = rodataseg;
        }
        else if ((strnicmp(inptr,"tls",3)==0) && !isIdentChar(inptr[3])) {
            segment = tlsseg;
        }
        else if ((strnicmp(inptr,"bss",3)==0) && !isIdentChar(inptr[3])) {
            segment = bssseg;
        }
j1:
        ScanToEOL();
        inptr++;
        switch(segment) {
        case codeseg:   
             strncpy(&codebuf[codendx], pinptr, inptr-pinptr);
             codendx += inptr-pinptr;
             break;
        case dataseg:
             strncpy(&databuf[datandx], pinptr, inptr-pinptr);
             datandx += inptr-pinptr;
             break;
        case rodataseg:
             strncpy(&rodatabuf[rodatandx], pinptr, inptr-pinptr);
             rodatandx += inptr-pinptr;
             break;
        case tlsseg:
             strncpy(&tlsbuf[tlsndx], pinptr, inptr-pinptr);
             tlsndx += inptr-pinptr;
             break;
        case bssseg:
             strncpy(&bssbuf[bssndx], pinptr, inptr-pinptr);
             bssndx += inptr-pinptr;
             break;
        }
        pinptr = inptr;
    }
    memset(masterFile,0,sizeof(masterFile));
    strcat(masterFile, codebuf);
    strcat(masterFile, rodatabuf);
    strcat(masterFile, "\r\n\trodata\r\n");
    strcat(masterFile, "\talign 8\r\n");
    strcat(masterFile, "begin_init_data:\r\n");
    strcat(masterFile, databuf);
    strcat(masterFile, "\r\n\trodata\r\n");
    strcat(masterFile, "\talign 8\r\n");
    strcat(masterFile, "end_init_data:\r\n");
    strcat(masterFile, databuf);
    strcat(masterFile, bssbuf);
    strcat(masterFile, tlsbuf);
    if (debug) {
        FILE *fp;
        fp = fopen("a64-segments.asm", "w");
        if (fp) {
                fwrite(masterFile, 1, strlen(masterFile), fp);
                fclose(fp);
        }
    }
}

// ----------------------------------------------------------------------------
// Look for .include directives and include the files.
// ----------------------------------------------------------------------------

void processLine(char *line)
{
    char *p;
    int quoteType;
    static char fnm[300];
    char *fname;
    int nn;
    int lb;

    p = line;
    while(isspace(*p)) p++;
    if (!*p) goto addToMaster;
    // see if the first thing on the line is an include directive
    if (*p=='.') p++;
    if (strnicmp(p, "include", 7)==0 && !isIdentChar(p[7]))
    {
        p += 7;
        // Capture the file name
        while(isspace(*p)) p++;
        if (*p=='"') { quoteType = '"'; p++; }
        else if (*p=='<') { quoteType = '>'; p++; }
        else quoteType = ' ';
        nn = 0;
        do {
           fnm[nn] = *p;
           p++; nn++;
           if (quoteType==' ' && isspace(*p)) break;
           else if (*p == quoteType) break;
           else if (*p=='\n') break;
        } while(nn < sizeof(fnm)/sizeof(char));
        fnm[nn] = '\0';
        fname = strdup(fnm);
        lb = lineno;
        lineno = 1;
        processFile(fname,1);
        lineno = lb;
        free(fname);
        return;
    }
    // Not an include directive, then just copy the line to the master buffer.
addToMaster:
    strcpy(&masterFile[mfndx], line);
    mfndx += strlen(line);
}

// ----------------------------------------------------------------------------
// Build a aggregate of all the included files into a single master buffer.
// ----------------------------------------------------------------------------

void processFile(char *fname, int searchincl)
{
     FILE *fp;
     char *pathname;

     if (verbose)
        printf("Processing file:%s\r\n", fname);
     pathname = (char *)NULL;
     fp = fopen(fname, "r");
     if (!fp) {
         if (searchincl) {
             searchenv(fname, "INCLUDE", &pathname);
             if (strlen(pathname)) {
                 fp = fopen(pathname, "r");
                 if (fp) goto j1;
             }
         }
         printf("Can't open file <%s>\r\n", fname);
         goto j2;
     }
j1:
     while (!feof(fp)) {
         fgets(buf, sizeof(buf)/sizeof(char), fp);
         processLine(buf);
     }
     fclose(fp);
j2:
     if (pathname)
         free(pathname);
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

int checksum(int32_t *val)
{
    int nn;
    int cs;

    cs = 0;
    for (nn = 0; nn < 32; nn++)
        cs ^= (*val & (1 << nn))!=0;
    return cs;
}


int checksum64(int64_t *val)
{
    int nn;
    int cs;

    cs = 0;
    for (nn = 0; nn < 64; nn++)
        cs ^= (*val & (1LL << nn))!=0;
    return cs;
}


// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

void processMaster()
{
    expandedBlock = 0;
    if (gCpu==888)
       Table888_processMaster();
    else if (gCpu==889)
        Table888mmu_processMaster();
    else if (gCpu==64)
        FISA64_processMaster();
    else if (gCpu==5)
        Friscv_processMaster();
    else if (gCpu==4)
        Thor_processMaster();
    else if (gCpu==14)
        dsd6_processMaster();
    else if (gCpu==7)
        dsd7_processMaster();
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

int64_t Round512(int64_t n)
{
    return (n + 511LL) & 0xFFFFFFFFFFFFFE00LL;
}

int64_t Round4096(int64_t n)
{
    return (n + 4095LL) & 0xFFFFFFFFFFFFF000LL;
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

void WriteELFFile(FILE *fp)
{
    int nn;
    Elf64Symbol elfsym;
    clsElf64File elf;
    SYM *sym,*syms;
    int64_t start;

    sections[0].hdr.sh_name = nmTable.AddName(".text");
    sections[0].hdr.sh_type = clsElf64Shdr::SHT_PROGBITS;
    sections[0].hdr.sh_flags = clsElf64Shdr::SHF_ALLOC | clsElf64Shdr::SHF_EXECINSTR;
    sections[0].hdr.sh_addr = rel_out ? 0 : sections[0].start;
    sections[0].hdr.sh_offset = 512;  // offset in file
    sections[0].hdr.sh_size = sections[0].index;
    sections[0].hdr.sh_link = 0;
    sections[0].hdr.sh_info = 0;
    sections[0].hdr.sh_addralign = 16;
    sections[0].hdr.sh_entsize = 0;

    sections[1].hdr.sh_name = nmTable.AddName(".rodata");
    sections[1].hdr.sh_type = clsElf64Shdr::SHT_PROGBITS;
    sections[1].hdr.sh_flags = clsElf64Shdr::SHF_ALLOC;
    sections[1].hdr.sh_addr = sections[0].hdr.sh_addr + sections[0].index;
    sections[1].hdr.sh_offset = sections[0].hdr.sh_offset + sections[0].index; // offset in file
    sections[1].hdr.sh_size = sections[1].index;
    sections[1].hdr.sh_link = 0;
    sections[1].hdr.sh_info = 0;
    sections[1].hdr.sh_addralign = 8;
    sections[1].hdr.sh_entsize = 0;

    sections[2].hdr.sh_name = nmTable.AddName(".data");
    sections[2].hdr.sh_type = clsElf64Shdr::SHT_PROGBITS;
    sections[2].hdr.sh_flags = clsElf64Shdr::SHF_ALLOC | clsElf64Shdr::SHF_WRITE;
    sections[2].hdr.sh_addr = sections[1].hdr.sh_addr + sections[1].index;
    sections[2].hdr.sh_offset = sections[1].hdr.sh_offset + sections[1].index; // offset in file
    sections[2].hdr.sh_size = sections[2].index;
    sections[2].hdr.sh_link = 0;
    sections[2].hdr.sh_info = 0;
    sections[2].hdr.sh_addralign = 8;
    sections[2].hdr.sh_entsize = 0;

    sections[3].hdr.sh_name = nmTable.AddName(".bss");
    sections[3].hdr.sh_type = clsElf64Shdr::SHT_PROGBITS;
    sections[3].hdr.sh_flags = clsElf64Shdr::SHF_ALLOC | clsElf64Shdr::SHF_WRITE;
    sections[3].hdr.sh_addr = sections[2].hdr.sh_addr + sections[2].index;
    sections[3].hdr.sh_offset = sections[2].hdr.sh_offset + sections[2].index; // offset in file
    sections[3].hdr.sh_size = 0;
    sections[3].hdr.sh_link = 0;
    sections[3].hdr.sh_info = 0;
    sections[3].hdr.sh_addralign = 8;
    sections[3].hdr.sh_entsize = 0;

    sections[4].hdr.sh_name = nmTable.AddName(".tls");
    sections[4].hdr.sh_type = clsElf64Shdr::SHT_PROGBITS;
    sections[4].hdr.sh_flags = clsElf64Shdr::SHF_ALLOC | clsElf64Shdr::SHF_WRITE;
    sections[4].hdr.sh_addr = sections[3].hdr.sh_addr + sections[3].index;;
    sections[4].hdr.sh_offset = sections[2].hdr.sh_offset + sections[2].index; // offset in file
    sections[4].hdr.sh_size = 0;
    sections[4].hdr.sh_link = 0;
    sections[4].hdr.sh_info = 0;
    sections[4].hdr.sh_addralign = 8;
    sections[4].hdr.sh_entsize = 0;

    sections[5].hdr.sh_name = nmTable.AddName(".strtab");
    // The following line must be before the name table is copied to the section.
    sections[6].hdr.sh_name = nmTable.AddName(".symtab");
    sections[7].hdr.sh_name = nmTable.AddName(".reltext");
    sections[8].hdr.sh_name = nmTable.AddName(".relrodata");
    sections[9].hdr.sh_name = nmTable.AddName(".reldata");
    sections[10].hdr.sh_name = nmTable.AddName(".relbss");
    sections[11].hdr.sh_name = nmTable.AddName(".reltls");
    sections[5].hdr.sh_type = clsElf64Shdr::SHT_STRTAB;
    sections[5].hdr.sh_flags = 0;
    sections[5].hdr.sh_addr = 0;
    sections[5].hdr.sh_offset = 512 + sections[0].index + sections[1].index + sections[2].index; // offset in file
    sections[5].hdr.sh_size = nmTable.length;
    sections[5].hdr.sh_link = 0;
    sections[5].hdr.sh_info = 0;
    sections[5].hdr.sh_addralign = 1;
    sections[5].hdr.sh_entsize = 0;
    memcpy(sections[5].bytes, nmTable.text, nmTable.length);

    sections[6].hdr.sh_type = clsElf64Shdr::SHT_SYMTAB;
    sections[6].hdr.sh_flags = 0;
    sections[6].hdr.sh_addr = 0;
    sections[6].hdr.sh_offset = Round512(512 + sections[0].index + sections[1].index + sections[2].index) + nmTable.length; // offset in file
    sections[6].hdr.sh_size = (numsym + 1) * 24;
    sections[6].hdr.sh_link = 5;
    sections[6].hdr.sh_info = 0;
    sections[6].hdr.sh_addralign = 1;
    sections[6].hdr.sh_entsize = 24;

    for(nn = 7; nn < 12; nn++) {
        sections[nn].hdr.sh_type = clsElf64Shdr::SHT_REL;
        sections[nn].hdr.sh_flags = 0;
        sections[nn].hdr.sh_addr = 0;
        sections[nn].hdr.sh_offset = sections[nn-1].hdr.sh_offset + sections[nn-1].hdr.sh_size; // offset in file
        sections[nn].hdr.sh_size = sections[nn].index;
        sections[nn].hdr.sh_link = 6;
        sections[nn].hdr.sh_info = 0;
        sections[nn].hdr.sh_addralign = 1;
        sections[nn].hdr.sh_entsize = 16;
    }

    nn = 1;
    // The first entry is an NULL symbol
    elfsym.st_name = 0;
    elfsym.st_info = 0;
    elfsym.st_other = 0;
    elfsym.st_shndx = 0;
    elfsym.st_value = 0;
    elfsym.st_size = 0;
    sections[6].Add(&elfsym);
    syms = (SYM*)HashInfo.table;
    for (nn = 0; nn < HashInfo.size; nn++) {
        // Don't output the constants
//        if (syms[nn].segment < 5) {
          if (syms[nn].name) {
            elfsym.st_name = syms[nn].name;
            elfsym.st_info = syms[nn].scope == 'P' ? STB_GLOBAL << 4 : 0;
            elfsym.st_other = 0;
            elfsym.st_shndx = syms[nn].segment;
            elfsym.st_value = syms[nn].value;
            elfsym.st_size = 8;
            sections[6].Add(&elfsym);
//        }
        }
    }

    elf.hdr.e_ident[0] = 127;
    elf.hdr.e_ident[1] = 'E';
    elf.hdr.e_ident[2] = 'L';
    elf.hdr.e_ident[3] = 'F';
    elf.hdr.e_ident[4] = clsElf64Header::ELFCLASS64;   // 64 bit file format
    elf.hdr.e_ident[5] = clsElf64Header::ELFDATA2LSB;  // little endian
    elf.hdr.e_ident[6] = 1;        // header version always 1
    elf.hdr.e_ident[7] = 255;      // OS/ABI indentification, 255 = standalone
    elf.hdr.e_ident[8] = 255;      // ABI version
    elf.hdr.e_ident[9] = 0;
    elf.hdr.e_ident[10] = 0;
    elf.hdr.e_ident[11] = 0;
    elf.hdr.e_ident[12] = 0;
    elf.hdr.e_ident[13] = 0;
    elf.hdr.e_ident[14] = 0;
    elf.hdr.e_ident[15] = 0;
    elf.hdr.e_type = rel_out ? 1 : 2;
    elf.hdr.e_machine = 888;         // machine architecture
    elf.hdr.e_version = 1;
    sym = find_symbol("start");
    if (sym)
        start = sym->value;
    else
        start = 0xC00200;
    elf.hdr.e_entry = start;
    elf.hdr.e_phoff = 0;
    elf.hdr.e_shoff = sections[11].hdr.sh_offset + sections[11].index;
    elf.hdr.e_flags = 0;
    elf.hdr.e_ehsize = Elf64HdrSz;
    elf.hdr.e_phentsize = 0;
    elf.hdr.e_phnum = 0;
    elf.hdr.e_shentsize = Elf64ShdrSz;
    elf.hdr.e_shnum = 0;              // This will be incremented by AddSection()
    elf.hdr.e_shstrndx = 5;           // index into section table of string table header

    for (nn = 0; nn < 12; nn++)
        elf.AddSection(&sections[nn]);    
    elf.Write(fp);

}

int IHChecksum(char *ibuf, int payloadCount)
{
    char buf[20];
    int nn;
    int ii;
    int sum;

    sum = 0;
    for (nn = 0; nn < payloadCount +4; nn++) {
        buf[0] = ibuf[nn*2+1];
        buf[1] = ibuf[nn*2+2];
        buf[2] = '\0';        
        ii = strtoul(buf,NULL,16);
        sum = sum + ii;
    }
    sum = -sum;
    sprintf(&ibuf[(payloadCount+4) * 2+1],"%02X\n", sum & 0xFF);
	return sum;
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

int64_t getbit(int n, int bit)
{
	return (n >> bit) & 1;
}

// ----------------------------------------------------------------------------
// Compute 38 bit ECC (32+6 bits EDC).
// ----------------------------------------------------------------------------

int checkbits(unsigned int i)
{
/*
	unsigned int p0,p1,p2,p3,p4,p5,p;
	unsigned int t1,t2,t3;

	p0 = u ^ (u >> 2);
	p0 = p0 ^ (p0 >> 4);
	p0 = p0 ^ (p0 >> 8);
	p0 = p0 ^ (p0 >> 16);
	
	t1 = u ^ (u >> 1);
	p1 = t1 ^ (t1 >> 4);
	p1 = p1 ^ (p1 >> 8);
	p1 = p1 ^ (p1 >> 16);
	
	t2 = t1 ^ (t1 >> 2);
	p2 = t2 ^ (t2 >> 8);
	p2 = p2 ^ (p2 >> 16);
	
	t3 = t2 ^ (t2 >> 4);
	p3 = t3 ^ (t3 >> 16);
	
	p4 = t3 ^ (t3 >> 8);

	p5 = p4 ^ (p4 >> 16);

	p = ((p0 >> 1)&1) | ((p1 >> 1)&2) | ((p2>>2)&4) | 
		((p3 >> 5)&8) | ((p4 >> 12)&16) | ((p5 & 1)<<5);
	
	p = p ^ (-(u & 1)&0x3f);	// now account for u[0]
	return p;
*/

	static int8_t g1[18] = {0,1,3,4,6,8,10,11,13,15,17,19,21,23,25,26,28,30};
	static int8_t g2[18] = {0,2,3,5,6,9,10,12,13,16,17,20,21,24,25,27,28,31};
	static int8_t g4[18] = {1,2,3,7,8,9,10,14,15,16,17,22,23,24,25,29,30,31};
	static int8_t g8[15] = {4,5,6,7,8,9,10,18,19,20,21,22,23,24,25};
	static int8_t g16[15] = {11,12,13,14,15,16,17,18,19,20,21,22,23,24,25};
	static int8_t g32[6] = {26,27,28,29,30,31};
	unsigned int p1,p2,p4,p8,p16,p32,pg,b,o;
	int nn;
	
	p1 = 0;
	for (nn = 0; nn < 18; nn++) {
		b = getbit(i,g1[nn]);
		p1 = p1 ^ b;				
	}
	p2 = 0;
	for (nn = 0; nn < 18; nn++) {
		b = getbit(i,g2[nn]);
		p2 = p2 ^ b;
	}
	p4 = 0;
	for (nn = 0; nn < 18; nn++) {
		b = getbit(i,g4[nn]);
		p4 = p4 ^ b;
	}
	p8 = 0;
	for (nn = 0; nn < 15; nn++) {
		b = getbit(i,g8[nn]);
		p8 = p8 ^ b;
	}
	p16 = 0;
	for (nn = 0; nn < 15; nn++) {
		b = getbit(i,g16[nn]);
		p16 = p16 ^ b;
	}
	p32 = 0;
	for (nn = 0; nn < 6; nn++) {
		b = getbit(i,g32[nn]);
		p32 = p32 ^ b;
	}
/*
	o = p1|(p2<<1)|(getbit(i,0)<<2)|(p4<<3);
	o = o | (getbit(i,1)<<4)| (getbit(i,2)<<5)| (getbit(i,3)<<6)|(p8<<7);
	for (nn = 4; nn <= 10; nn++)
		o = o | (getbit(i,nn)<<(nn+4));
	o = o | (p16 << 15);
	for (nn = 11; nn <= 25; nn++)
		o = o | (getbit(i,nn)<<(nn+5));
	o = o | (p32 << 31);
	for (nn = 26; nn <= 31; nn++)
		o = o | (getbit(i,nn)<<(nn+6));
*/
	pg = checksum((int32_t*)&i)^p1^p2^p4^p8^p16^p32;
//	o = i | (p32<<37)|(p16<<36)|(p8<<35)|(p4<<34)|(p2<<33)|(p1<<32) | (pg << 38);
	o = (p32<<5)|(p16<<4)|(p8<<3)|(p4<<2)|(p2<<1)|p1|(pg<<6);
	return o;	
}

// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------

int main(int argc, char *argv[])
{
    int nn,qq,kk;
    static char fname[500];
    static char hexbuf[500];
    char *p;
    uint64_t lsa;      // last start address
    double bpi;
    int64_t i64;
    uint32_t u32;

    processOpt = 1;
	sections[bssseg].storebyte = 0;
    ofp = stdout;
    nn = processOptions(argc, argv);
    if (nn > argc-1) {
       displayHelp();
       return 0;
    }
    SymbolInit();
    strcpy(fname, argv[nn]);
    mfndx = 0;
    start_address = 0;
    code_address = 0;
    bss_address = 0;
    data_address = 0;
    isInitializationData = 0;
    for (qq = 0; qq < 12; qq++)
        sections[qq].Clear();
    nmTable.Clear();
    memset(masterFile,0,sizeof(masterFile));
    if (verbose) printf("Pass 1 - collect all input files.\r\n");
    processFile(fname,0);   // Pass 1, collect all include files
    if (debug) {
        FILE *fp;
        fp = fopen("a64-master.asm", "w");
        if (fp) {
                fwrite(masterFile, 1, strlen(masterFile), fp);
                fclose(fp);
        }
    }
    if (verbose) printf("Pass 2 - group and reorder segments\r\n");
    first_org = 1;
    processSegments();     // Pass 2, group and order segments

    pass = 3;
    processMaster();       // Pass 3 collect up opcodes
    printf("Qsorting\r\n");
    qsort((HTBLE*)hTable, htblmax, sizeof(HTBLE), hcmp);
   
    pass = 4;
    if (verbose) printf("Pass 4 - get all symbols, set initial values.\r\n");
    first_org = 1;
    processMaster();
    pass = 5;
    phasing_errors = 0;
    if (verbose) printf("Pass 5 - assemble code.\r\n");
    first_org = 1;
    processMaster();
    if (verbose) printf("Pass 6: phase errors: %d\r\n", phasing_errors);
    pass = 6;
    while (phasing_errors && pass < 40) {
        phasing_errors = 0;
        num_bytes = 0;
        num_insns = 0;
	    first_org = 1;
        processMaster();
        if (verbose) printf("Pass %d: phase errors: %d\r\n", pass, phasing_errors);
        pass++;
    }
    //processMaster();
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Output listing file.
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    ofp = (FILE *)NULL;
    if (listing) {
        if (verbose) printf("Generating listing file %s.\r\n", argv[nn]);
        strcpy(fname, argv[nn]);
        p = strrchr(fname,'.');
        if (p) {
            *p = '\0';
        }
        strcat(fname, ".lst");
        ofp = fopen(fname,"w");
        if (!ofp)
           printf("Can't open output file <%s>\r\n", fname);
        bGen = 1;
    }
    processOpt = 2;
    processMaster();
    DumpSymbols();
    DumphTable();
    fprintf(ofp, "\nnumber of bytes: %d\n", num_bytes);
    fprintf(ofp, "number of instructions: %d\n", num_insns);
    bpi = (double)num_bytes/(double)num_insns;
    fprintf(ofp, "%0.6f bytes (%d bits) per instruction\n", bpi, (int)(bpi*8));

/*
    chksum = 0;
    for (nn = 0; nn < binndx; nn+=4) {
        chksum += binfile[nn] +
                  (binfile[nn+1] << 8) + 
                  (binfile[nn+2] << 16) + 
                  (binfile[nn+3] << 24) 
                  ;
    }

    fprintf(ofp, "\r\nChecksum: %08X\r\n", chksum);
*/
    if (listing)
        fclose(ofp);
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Output binary file.
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    if (binary_out) {
        if (verbose) printf("Generating binary file.\r\n");
        strcpy(fname, argv[nn]);
        p = strrchr(fname,'.');
        if (p) {
            *p = '\0';
        }
        strcat(fname, ".bin");
        ofp = fopen(fname,"wb");
        if (ofp) {
            fwrite((void*)sections[0].bytes,sections[0].index,1,ofp);
            fwrite((void*)sections[1].bytes,sections[1].index,1,ofp);
            //fwrite((void*)sections[2].bytes,sections[2].index,1,ofp);
            //fwrite(binfile,binndx,1,ofp);
            fclose(ofp);    
        }
        else
            printf("Can't create .bin file.\r\n");
    }
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Output ELF file.
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    if (elf_out) {
        if (verbose) printf("Generating ELF file.\r\n");
        strcpy(fname, argv[nn]);
        p = strrchr(fname,'.');
        if (p) {
            *p = '\0';
        }
        if (rel_out)
            strcat(fname, ".rel");
        else
            strcat(fname, ".elf");
        ofp = fopen(fname,"wb");
        if (ofp) {
            WriteELFFile(ofp);
            fclose(ofp);    
        }
        else
            printf("Can't create .elf file.\r\n");
    }
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Output coe file
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    if (coe_out) {
	    if (verbose) printf("Generating COE file.\r\n");
	    strcpy(fname, argv[nn]);
	    p = strrchr(fname,'.');
	    if (p) {
	        *p = '\0';
	    }
	    strcat(fname, ".coe");
	    vfp = fopen(fname, "w");
	    if (vfp) {
	    	fprintf(vfp, "memory_initialization_radix=16;\r\n");
	    	fprintf(vfp, "memory_initialization_vector=\r\n");
	        for (kk = 0;kk < binndx; kk+=4) {
	        	u32 = (binfile[kk+3]<<24)|(binfile[kk+2]<<16)|(binfile[kk+1]<<8)|binfile[kk];
	            i64 = ((uint64_t)checkbits(u32) << 32)|(uint64_t)u32;
	            fprintf(vfp, "%010I64X,\r\n", i64);
	        }
	        fprintf(vfp,"000000;\r\n");
	        fclose(vfp);
		}
	}

    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Output Verilog memory declaration
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    if (verilog_out) {
        if (verbose) printf("Generating Verilog file.\r\n");
        strcpy_s(fname, sizeof(fname), argv[nn]);
        p = strrchr(fname,'.');
        if (p) {
            *p = '\0';
        }
        strcat_s(fname, sizeof(fname), ".ve0");
        vfp = fopen(fname, "w");
        if (vfp) {
            if (gCpu==64) {
                for (kk = 0; kk < binndx; kk+=8) {
                    fprintf(vfp, "\trommem0[%d] = 65'h%01d%02X%02X%02X%02X%02X%02X%02X%02X;\n", 
                        (((0+kk)/8)%16384), checksum64((int64_t *)&binfile[kk]),
                        binfile[kk+7], binfile[kk+6], binfile[kk+5], binfile[kk+4], 
                        binfile[kk+3], binfile[kk+2], binfile[kk+1], binfile[kk]);
                }
            }
            else if (gCpu==5) {
                for (kk = 0;kk < binndx; kk+=4) {
                	u32 = (binfile[kk+3]<<24)|(binfile[kk+2]<<16)|(binfile[kk+1]<<8)|binfile[kk];
                    i64 = (uint64_t)u32;
                    fprintf(vfp, "\trommem[%d] = 32'h%08I64X;\n", 
                        (((start_address+kk)/4)%32768), i64);
                }
            }
            else {
                for (kk = 0;kk < binndx; kk+=4) {
                	u32 = (binfile[kk+3]<<24)|(binfile[kk+2]<<16)|(binfile[kk+1]<<8)|binfile[kk];
                    i64 = ((uint64_t)checkbits(u32) << 32)|(uint64_t)u32;
                    fprintf(vfp, "\trommem0[%d] = 39'h%010I64X;\n", 
                        (int)(((0+kk)/4)%32768), i64);
                }
            }
            fclose(vfp);
        }
        else
            printf("Can't create .ver file.\r\n");
        strcpy_s(fname, sizeof(fname), argv[nn]);
        p = strrchr(fname,'.');
        if (p) {
            *p = '\0';
        }
        strcat_s(fname, sizeof(fname), ".ve1");
        vfp = fopen(fname, "w");
        if (vfp) {
            if (gCpu==64) {
                for (kk = 0; kk < binndx; kk+=8) {
                    fprintf(vfp, "\trommem1[%d] = 65'h%01d%02X%02X%02X%02X%02X%02X%02X%02X;\n", 
                        (((0+kk)/8)%16384), checksum64((int64_t *)&binfile[kk]),
                        binfile[kk+7]^0xAA, binfile[kk+6], binfile[kk+5], binfile[kk+4], 
                        binfile[kk+3], binfile[kk+2], binfile[kk+1], binfile[kk]);
                }
            }
            else {
                for (kk = 0;kk < binndx; kk+=4) {
                    fprintf(vfp, "\trommem1[%d] = 32'h%02X%02X%02X%02X;\n", 
                        (((start_address+kk)/4)%32768), binfile[kk+3]^0xAA, binfile[kk+2]^0xAA, binfile[kk+1]^0xAA, binfile[kk]^0xAA);
                }
            }
            fclose(vfp);
        }
        else
            printf("Can't create .ver file.\r\n");
        strcpy_s(fname, sizeof(fname), argv[nn]);
        p = strrchr(fname,'.');
        if (p) {
            *p = '\0';
        }
        strcat_s(fname, sizeof(fname), ".ve2");
        vfp = fopen(fname, "w");
        if (vfp) {
            if (gCpu==64) {
                for (kk = 0; kk < binndx; kk+=8) {
                    fprintf(vfp, "\trommem2[%d] = 65'h%01d%02X%02X%02X%02X%02X%02X%02X%02X;\n", 
                        (((0+kk)/8)%16384), checksum64((int64_t *)&binfile[kk]),
                        binfile[kk+7]^0x55, binfile[kk+6], binfile[kk+5], binfile[kk+4], 
                        binfile[kk+3], binfile[kk+2], binfile[kk+1], binfile[kk]);
                }
            }
            else {
                for (kk = 0;kk < binndx; kk+=4) {
                    fprintf(vfp, "\trommem2[%d] = 32'h%02X%02X%02X%02X;\n", 
                        (((start_address+kk)/4)%32768), binfile[kk+3]^0x55, binfile[kk+2]^0x55, binfile[kk+1]^0x55, binfile[kk]^0x55);
                }
            }
            fclose(vfp);
        }
        else
            printf("Can't create .ver file.\r\n");
    }
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Output Verilog memory declaration
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        if (verbose) printf("Generating Text file.\r\n");
        strcpy_s(fname, sizeof(fname), argv[nn]);
        p = strrchr(fname,'.');
        if (p) {
            *p = '\0';
        }
        strcat_s(fname, sizeof(fname), ".txt");
        printf("fname:%s\r\n", fname);
        vfp = fopen(fname, "w");
        if (vfp) {
            if (gCpu==64) {
                for (kk = 0; kk < binndx; kk+=4) {
                    fprintf(vfp, "%06X,%02X%02X%02X%02X\n", 
                        (((start_address+kk))),
                        binfile[kk+3], binfile[kk+2], binfile[kk+1], binfile[kk]);
                }
            }
            fclose(vfp);
        }
        else
            printf("Can't create .txt file.\r\n");
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // Output Intel hex file
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        if (verbose) printf("Generating Hex file.\r\n");
        strcpy_s(fname, sizeof(fname), argv[nn]);
        p = strrchr(fname,'.');
        if (p) {
            *p = '\0';
        }
        lsa = 0;
        strcat_s(fname, sizeof(fname), ".hex");
        printf("fname:%s\r\n", fname);
        vfp = fopen(fname, "w");
        if (vfp) {
            if (gCpu==64) {
                for (kk = 0; kk < binndx; kk+=4) {
                    if (lsa != (start_address + kk) >> 16) {
                        sprintf_s(hexbuf, sizeof(hexbuf), ":02000004%04X00\n", (int)((start_address+kk) >> 16));
                        IHChecksum(hexbuf, 2);
                        fprintf(vfp, hexbuf);
                        lsa = (start_address+kk) >> 16;
                    }
                    sprintf_s(hexbuf, sizeof(hexbuf), ":%02X%04X00%02X%02X%02X%02X%02X\n",
                        4, (start_address + kk) & 0xFFFF,
                        binfile[kk], binfile[kk+1], binfile[kk+2], binfile[kk+3]
                    );
                    IHChecksum(hexbuf, 4);
                    fprintf(vfp, hexbuf);
                }
            }
            else if (gCpu==4) {
                for (kk = 0; kk < binndx; kk+=8) {
                    if (lsa != (start_address + kk) >> 16) {
                        sprintf_s(hexbuf, sizeof(hexbuf), ":02000004%04X00\n", (int)((start_address+kk) >> 16));
                        IHChecksum(hexbuf, 2);
                        fprintf(vfp, hexbuf);
                        lsa = (start_address+kk) >> 16;
                    }
                    sprintf_s(hexbuf, sizeof(hexbuf), ":%02X%04X00%02X%02X%02X%02X%02X%02X%02X%02X\n",
                        8, (start_address + kk) & 0xFFFF,
                        binfile[kk], binfile[kk+1], binfile[kk+2],binfile[kk+3],
                        binfile[kk+4],binfile[kk+5],binfile[kk+6],binfile[kk+7]
                    );
                    IHChecksum(hexbuf, 8);
                    fprintf(vfp, hexbuf);
                }
            }
            fprintf(vfp, ":00000001FF\n%c",26);        // end of file record
            fclose(vfp);
        }
        else
            printf("Can't create .hex file.\r\n");
    return 0;
}
